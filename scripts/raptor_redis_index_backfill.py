#!/usr/bin/env python3
"""
raptor_redis_index_backfill.py - write the Elixir scripts and print the oc
commands needed to backfill Raptor's new Redis secondary-index sets
(raptor:*:index:<id>) from ANDI's Postgres, the authoritative source for
user/dataset/access-group relations.

Background: Raptor's UserAccessGroupRelationStore, UserOrgAssocStore, and
DatasetAccessGroupRelationStore now maintain a Redis SET per user/dataset
(SADD on persist, SREM on delete) so get_all_by_user/get_all_by_dataset can
do an O(1) SMEMBERS instead of a keyspace-wide SCAN - at ~2.2M keys in the
dev Redis instance, that SCAN was taking multiple seconds per call and
timing out discovery-api's 5s HTTPoison request to Raptor's
/listAccessGroups. See apps/raptor/lib/raptor/services/{user_access_group_
relation_store,user_org_assoc_store,dataset_access_group_relation_store}.ex.

This new index only gets populated going forward, from live
user_access_group_associate / dataset_access_group_associate /
user_organization_associate Kafka events. Existing relations already in
Redis (and in Postgres) need a one-time backfill.

Why two pods: Raptor has no Postgres/Ecto dependency at all (it's a pure
Kafka-event-sourced Redis read model), so it can't query ANDI's database.
ANDI has Ecto/Postgres but its only Redis usage is Brook.Storage.Redis's
*internal* connection (namespace "andi:view"), not a stable named process
safe to piggyback raw SADD calls onto. Raptor already has its own named
Redix connection (Raptor.Application.redis_client/0, registered as
:raptor_redix) pointed at the correct instance by construction - so the
extraction (step 1) runs where Postgres access already lives (ANDI), and
the write (step 2) runs where the target Redis connection already lives
(Raptor).

Why files instead of console paste: `oc exec -it ... -- /opt/app/bin/<app>
remote` opens an IEx shell over a TTY that doesn't support bracketed paste,
so multi-line statements (anything with a `|>` chain spanning lines) get
delivered to IEx line-by-line and can be misevaluated - a longstanding
annoyance in this repo's operational history that's previously been worked
around by hand-condensing scripts to one line. This script avoids that
entirely two ways instead:
  - Step 1 (ANDI) runs non-interactively via `bin/andi rpc "$(cat FILE)"` -
    the file's contents go over as a single shell argument, never through
    TTY paste, so the file itself can stay normally formatted.
  - Step 2 (Raptor) reads its input from a file already placed on the pod
    via `oc cp`, rather than requiring you to paste a data blob into a
    console. It also runs via `bin/raptor rpc "$(cat FILE)"` - no
    interactive console needed at all, and the dry-run script includes an
    automatic spot-check (confirms one extracted {user_id, access_group_id}
    pair already has a matching exact-key relation in Redis) instead of
    requiring a separate manual paste step.

The ID mappings baked into andi_extract.exs (user_id = users.subject_id,
org_id = user_organizations.organization_id, access_group_id =
*.access_group_id, dataset_id = dataset_access_groups.dataset_id) are
inferred from apps/andi/lib/andi/schemas/{user,user_organization,
user_access_group,dataset_access_group}.ex and apps/andi/lib/andi/services/
user_organization_associate_service.ex, not verified against live data -
that's exactly what the dry-run script's automatic spot-check is for. Don't
run raptor_apply.exs until a dry run's spot-check reports FOUND.

Usage:
    scripts/raptor_redis_index_backfill.py
    scripts/raptor_redis_index_backfill.py --namespace mdot-ride-dev-ns \\
        --andi-pod andi-abc123 --raptor-pod raptor-def456
    scripts/raptor_redis_index_backfill.py --out-dir /tmp/backfill

Writes andi_extract.exs, raptor_dry_run.exs, and raptor_apply.exs to
--out-dir (default: /tmp/raptor_redis_index_backfill-$USER - deliberately
outside this repo, since a real run's extracted data can contain real
user/org IDs and must never end up committed), and prints the exact
oc/shell commands to run them in order.
"""

import argparse
import getpass
import os

ANDI_EXTRACT = """\
alias Andi.Repo
alias Andi.Schemas.{User, UserAccessGroup, UserOrganization, DatasetAccessGroup}
import Ecto.Query

user_access_groups =
  from(uag in UserAccessGroup,
    join: u in User, on: u.id == uag.user_id,
    select: {u.subject_id, uag.access_group_id}
  )
  |> Repo.all()

dataset_access_groups =
  from(dag in DatasetAccessGroup, select: {dag.dataset_id, dag.access_group_id})
  |> Repo.all()

user_orgs =
  from(uo in UserOrganization,
    join: u in User, on: u.id == uo.user_id,
    select: {u.subject_id, uo.organization_id}
  )
  |> Repo.all()

data = %{
  user_access_groups: user_access_groups,
  dataset_access_groups: dataset_access_groups,
  user_orgs: user_orgs
}

IO.puts(
  "row counts - user_access_groups: #{length(user_access_groups)}, " <>
  "dataset_access_groups: #{length(dataset_access_groups)}, " <>
  "user_orgs: #{length(user_orgs)}"
)

IO.puts("BACKFILL_DATA=" <> (data |> :erlang.term_to_binary() |> Base.encode64()))
"""

RAPTOR_DRY_RUN = """\
data =
  "/tmp/backfill_data.b64"
  |> File.read!()
  |> String.trim()
  |> Base.decode64!()
  |> :erlang.binary_to_term([:safe])

IO.puts(
  "would backfill #{length(data.user_access_groups)} user-access-group, " <>
  "#{length(data.dataset_access_groups)} dataset-access-group, " <>
  "#{length(data.user_orgs)} user-org index entries (dry run, nothing written)"
)

IO.puts("sample user_access_groups: #{inspect(Enum.take(data.user_access_groups, 5))}")
IO.puts("sample dataset_access_groups: #{inspect(Enum.take(data.dataset_access_groups, 5))}")
IO.puts("sample user_orgs: #{inspect(Enum.take(data.user_orgs, 5))}")

case data.user_access_groups do
  [{user_id, access_group_id} | _] ->
    key = "raptor:user_access_group_relation:#{user_id}:#{access_group_id}"
    existing = Redix.command!(Raptor.Application.redis_client(), ["GET", key])

    verdict =
      if existing,
        do: "FOUND - mapping looks correct, safe to run raptor_apply.exs",
        else: "NOT FOUND - mapping may be wrong, do NOT run raptor_apply.exs yet"

    IO.puts("spot-check #{key} -> #{verdict}")

  [] ->
    IO.puts("spot-check skipped - no user_access_groups rows extracted")
end
"""

RAPTOR_APPLY = """\
data =
  "/tmp/backfill_data.b64"
  |> File.read!()
  |> String.trim()
  |> Base.decode64!()
  |> :erlang.binary_to_term([:safe])

redix = Raptor.Application.redis_client()

for {user_id, access_group_id} <- data.user_access_groups do
  Redix.command!(redix, [
    "SADD",
    "raptor:user_access_group_relation:index:" <> user_id,
    access_group_id
  ])
end

for {dataset_id, access_group_id} <- data.dataset_access_groups do
  Redix.command!(redix, [
    "SADD",
    "raptor:dataset_access_group_relation:index:" <> dataset_id,
    access_group_id
  ])
end

for {user_id, org_id} <- data.user_orgs do
  Redix.command!(redix, ["SADD", "raptor:user_org_assoc:index:" <> user_id, org_id])
end

IO.puts(
  "backfilled #{length(data.user_access_groups)} user-access-group, " <>
  "#{length(data.dataset_access_groups)} dataset-access-group, " <>
  "#{length(data.user_orgs)} user-org index entries"
)
"""


def main():
    parser = argparse.ArgumentParser(
        description="Write the Elixir scripts and print the oc commands to backfill Raptor's Redis index sets from ANDI's Postgres.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--namespace", default="mdot-ride-dev-ns", help="OpenShift namespace (default: mdot-ride-dev-ns)")
    parser.add_argument("--andi-pod", default="<andi-pod>", help="ANDI pod name (default: placeholder to fill in)")
    parser.add_argument("--raptor-pod", default="<raptor-pod>", help="Raptor pod name (default: placeholder to fill in)")
    parser.add_argument(
        "--out-dir",
        default=None,
        help="Directory to write the .exs files and extracted data to (default: a per-user /tmp "
        "directory, NOT this repo - the extracted data can contain real user/org IDs and "
        "must never end up committed)",
    )
    args = parser.parse_args()

    out_dir = args.out_dir or os.path.join("/tmp", f"raptor_redis_index_backfill-{getpass.getuser()}")
    os.makedirs(out_dir, exist_ok=True, mode=0o700)

    files = {
        "andi_extract.exs": ANDI_EXTRACT,
        "raptor_dry_run.exs": RAPTOR_DRY_RUN,
        "raptor_apply.exs": RAPTOR_APPLY,
    }
    paths = {}
    for name, content in files.items():
        path = os.path.join(out_dir, name)
        with open(path, "w") as f:
            f.write(content)
        paths[name] = path

    ns = args.namespace
    andi_pod = args.andi_pod
    raptor_pod = args.raptor_pod

    print(f"# Wrote:")
    for name, path in paths.items():
        print(f"#   {path}")
    print()
    print("# --- Step 1: extract from ANDI's Postgres (non-interactive, no TTY paste) ---")
    print(
        f'oc exec -n {ns} {andi_pod} -- /opt/app/bin/andi rpc "$(cat {paths["andi_extract.exs"]})" '
        f"| tee {out_dir}/andi_extract_output.txt"
    )
    print()
    print("# Check the row counts printed above look sane, then extract just the data payload:")
    print(
        f"grep '^BACKFILL_DATA=' {out_dir}/andi_extract_output.txt | cut -d= -f2- "
        f"> {out_dir}/backfill_data.b64"
    )
    print()
    print("# --- Step 2: copy the data and scripts onto the Raptor pod ---")
    print(f"oc cp {out_dir}/backfill_data.b64 {ns}/{raptor_pod}:/tmp/backfill_data.b64")
    print(f"oc cp {paths['raptor_dry_run.exs']} {ns}/{raptor_pod}:/tmp/raptor_dry_run.exs")
    print(f"oc cp {paths['raptor_apply.exs']} {ns}/{raptor_pod}:/tmp/raptor_apply.exs")
    print()
    print("# --- Step 3: dry run + automatic spot-check (non-interactive) ---")
    print(f'oc exec -n {ns} {raptor_pod} -- /opt/app/bin/raptor rpc "$(cat {paths["raptor_dry_run.exs"]})"')
    print()
    print("# --- Step 4: only if step 3's spot-check said FOUND, apply for real ---")
    print(f'oc exec -n {ns} {raptor_pod} -- /opt/app/bin/raptor rpc "$(cat {paths["raptor_apply.exs"]})"')


if __name__ == "__main__":
    main()
