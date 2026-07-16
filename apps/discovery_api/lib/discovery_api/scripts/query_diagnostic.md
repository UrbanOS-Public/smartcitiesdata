# Query Diagnostic Tool

Diagnostic tool that walks the discovery-api query pipeline step-by-step, reporting exactly where a dataset fails to be queryable and why.

Useful after Redis key evictions that cause Brook view-state loss.

## Prerequisites

Attach an IEx console to the running discovery-api node:

```bash
kubectl exec -it <discovery-api-pod> -- bin/discovery_api remote
```

## Usage

### By Trino system name

```elixir
DiscoveryApi.Scripts.QueryDiagnostic.run("org__datasetname")
```

### By dataset UUID

```elixir
DiscoveryApi.Scripts.QueryDiagnostic.run({:id, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"})
```

### By URL path segments (org name and dataset name)

```elixir
DiscoveryApi.Scripts.QueryDiagnostic.run({:path, "my_org", "my_dataset"})
```

### Scan all datasets

Compare Redis vs ETS state across every known dataset. Identifies datasets that will become unqueryable after a pod restart (missing from Redis) and orphaned Redis keys (in Redis but not in ETS).

```elixir
DiscoveryApi.Scripts.QueryDiagnostic.scan_all()
```

## What it checks

The tool runs five steps in sequence, stopping at the first blocking failure:

| Step | What is checked |
|------|-----------------|
| 1. Identity resolution | SystemNameCache (Cachex) or Brook ETS lookup |
| 2. Brook Redis state | `discovery-api:view:state:models:<dataset_id>` key exists |
| 3. Brook ETS state | Dataset is live in-memory right now |
| 4. Organization (Postgres) | Owning org exists — required for `dataset_update` events to be accepted |
| 5. Trino query | `SELECT MAX(FROM_UNIXTIME(_extraction_start_time)), COUNT(1) FROM <table> LIMIT 200` |

## Recommendations

At the end of a failed run the tool prints color-coded recommendations. The most common fix for missing Redis keys is to republish dataset events from Andi:

```elixir
# Run from an IEx console attached to the andi node
Andi.Scripts.ResendEvents.resend_dataset_events()
```

This sources from Postgres and works even after a full Redis flush. If the organization is also missing from Postgres, run the org/user association events first:

```elixir
Andi.Scripts.ResendEvents.resend_user_org_assoc_events()
Andi.Scripts.ResendEvents.resend_dataset_events()
```

## Redis key reference

Brook stores model view-state under:

```
discovery-api:view:state:models:<dataset_id>
```

> **Note:** The pattern `brook:discovery_api:view_state:models:*` does **not** exist — using it in `KEYS` will return nothing.
