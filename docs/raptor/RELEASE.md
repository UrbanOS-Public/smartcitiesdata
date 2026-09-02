# raptor Release Notes

## 23.3.6
- Fixed `/listAccessGroups` and access-group-gated `/authorize` requests timing out under high Redis key volumes; the dataset/user/access-group stores now maintain a Redis index instead of a full-keyspace `SCAN` for per-user/per-dataset lookups
- Requires a one-time backfill of the new index keys from Postgres before existing relations are visible via the new lookup path (see `scripts/raptor_redis_index_backfill.py`)

## 23.3.5
- Fixed Redis `KEYS` full-keyspace scans in the dataset/user/access-group stores that could stall Redis under high key volume; exact lookups now use `GET`, prefix lookups use cursor-based `SCAN`

## 1.3.4 (pending release — not yet tagged)
- Added support for multiple datasets per ingestion
- Renamed Auth0 client ID configuration variables to match updated naming
- General logging improvements
- Updated the Alpine base image
