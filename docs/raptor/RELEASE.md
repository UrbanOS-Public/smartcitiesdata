# raptor Release Notes

## 25.3.6

First tagged raptor release on the OTP 25 branch.

**Versioning note:** from here on, raptor's version number tracks otp23's
scheme (`25.x.y` mirroring otp23's `23.x.y`) instead of restarting its own
`25.0.x` count, so the two branches' raptor releases stay easy to compare
release-for-release. This release brings otp25's raptor up to par with
otp23's `raptor@23.3.6`.

- Fixed `/listAccessGroups` and access-group-gated `/authorize` requests timing out under high Redis key volumes; the dataset/user/access-group stores now maintain a Redis index instead of a full-keyspace `SCAN` for per-user/per-dataset lookups, and remaining exact-key lookups use `GET` instead of the blocking `KEYS` command (ported from otp23 `raptor@23.3.6` and `23.3.5`)
- Raptor no longer goes down on a malformed or unrecognized Kafka event: unparseable/unhandled events are now discarded with a debug log line instead of crashing the event handler, and an unexpected Brook crash is logged instead of taking the app down
- Startup logging now includes the running version number, and Auth0/dead-letter-queue configuration logging was clarified to make misconfiguration easier to spot at boot
- Migrated raptor's build and deploy to Elixir's built-in `mix release` (replacing the deprecated Distillery) as part of the underlying Erlang/OTP 25 + Elixir upgrade

**Deployment note:** after deploying this version to an environment, run
`scripts/raptor_redis_index_backfill.py` (see its docstring for the full
oc-command walkthrough) to backfill the new Redis index keys from that
environment's Postgres. Until the backfill runs, existing relations won't
appear via `get_all_by_user`/`get_all_by_dataset` — only relations created
after this deploy (via live Kafka events) will be visible. Skippable only
if the environment's `user_access_groups`/`dataset_access_groups`/
`user_organizations` tables are confirmed empty.
