# discovery_api Release Notes

## 23.3.21 (pending release — not yet tagged)
- Fixed a Redis `KEYS` full-keyspace scan in `Persistence.get_keys/1` (dataset stats, recommendations) that could stall Redis under high key volume; replaced with cursor-based `SCAN`
- Raptor API-key validation now URL-encodes the key and logs it (quoted) on failure, fixing malformed requests for keys containing spaces or reserved URL characters

## 23.3.20 (pending release — not yet tagged)
- Added support for multiple datasets per ingestion
- Query endpoint: added case-sensitive casting, fixed a schema case-sensitivity bug, and column names with hyphens are now supported (converted to underscores automatically, including in preview queries)
- Applied general security updates and upgraded Trino to resolve CVEs
- General logging improvements
