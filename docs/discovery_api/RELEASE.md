# discovery_api Release Notes

## 23.3.22 (pending release — not yet tagged)
- Fixed the root cause of a multi-day memory climb that ended in periodic OOMKills: calls to Raptor for API-key and authorization checks had no timeout and ran on an unbounded shared connection pool, so a slow/degraded Raptor made every request hold a connection open for ~5s instead of failing quickly — now bounded to a dedicated pool with a short, explicit timeout, so a bad Raptor period can no longer accumulate unreclaimable memory
- Added a short-lived (30s) cache in front of the dataset catalog lookup used by every `/query` request, which previously re-fetched the entire catalog from Redis on every single request; cuts Redis load substantially and no longer crashes the request if that fetch times out
- Added periodic logging of BEAM memory, process/port/atom counts, and the Raptor connection pool's live stats, to make it possible to pinpoint which resource is growing if a similar memory issue recurs

## 23.3.21
- Fixed a Redis `KEYS` full-keyspace scan in `Persistence.get_keys/1` (dataset stats, recommendations) that could stall Redis under high key volume; replaced with cursor-based `SCAN`
- Raptor API-key validation now URL-encodes the key and logs it (quoted) on failure, fixing malformed requests for keys containing spaces or reserved URL characters

## 23.3.20 (pending release — not yet tagged)
- Added support for multiple datasets per ingestion
- Query endpoint: added case-sensitive casting, fixed a schema case-sensitivity bug, and column names with hyphens are now supported (converted to underscores automatically, including in preview queries)
- Applied general security updates and upgraded Trino to resolve CVEs
- General logging improvements
