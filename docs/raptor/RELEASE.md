# raptor Release Notes

## 23.3.6
- Fixed `/listAccessGroups` and access-group-gated `/authorize` requests timing out under high Redis key volumes; the dataset/user/access-group stores now maintain a Redis index instead of a full-keyspace `SCAN` for per-user/per-dataset lookups

**Deployment note:** after deploying this version to an environment, run `scripts/raptor_redis_index_backfill.py` (see its docstring for the full oc-command walkthrough) to backfill the new Redis index keys from that environment's Postgres. Until the backfill runs, existing relations won't appear via `get_all_by_user`/`get_all_by_dataset` — only relations created after this deploy (via live Kafka events) will be visible. Skippable only if the environment's `user_access_groups`/`dataset_access_groups`/`user_organizations` tables are confirmed empty (as dev's were at release time).

## 23.3.5
- Fixed Redis `KEYS` full-keyspace scans in the dataset/user/access-group stores that could stall Redis under high key volume; exact lookups now use `GET`, prefix lookups use cursor-based `SCAN`

## 1.3.4 (pending release — not yet tagged)
- Added support for multiple datasets per ingestion
- Renamed Auth0 client ID configuration variables to match updated naming
- General logging improvements
- Updated the Alpine base image
