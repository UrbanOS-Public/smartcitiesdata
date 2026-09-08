# discovery_api Release Notes

## 25.3.21

First tagged discovery_api release on the OTP 25 branch.

**Versioning note:** from here on, discovery_api's version number tracks
otp23's scheme (`25.x.y` mirroring otp23's `23.x.y`) instead of restarting
its own `25.0.x` count, so the two branches' discovery_api releases stay
easy to compare release-for-release. This release brings otp25's
discovery_api up to par with otp23's `discovery_api@23.3.21` for the
Redis fix below (the other otp23 `23.3.21` fix, Raptor API-key URL
encoding in the shared `raptor_service` library, has not been ported to
otp25 yet and is not included here).

- Fixed a Redis `KEYS` full-keyspace scan in `Persistence.get_keys/1` (used by dataset stats, recommendations, and most other Redis reads) that could stall Redis under high key volume; replaced with cursor-based `SCAN` (ported from otp23 `discovery_api@23.3.21`)
- discovery_api now fails fast at startup with a clear error if `RAPTOR_URL` isn't configured, instead of coming up in a broken state
- Query failures now log a table/model mismatch diagnostic (which tables Trino was queried for vs. which dataset models are known) to make "table doesn't exist" failures easier to root-cause, plus improved error logging on the multi-dataset query endpoint
- Migrated discovery_api's build and deploy to OTP 25's release process, including several rounds of fixes to how `RAPTOR_URL`, `PRESTO_URL`, and other Kubernetes-provided environment variables are read at runtime
