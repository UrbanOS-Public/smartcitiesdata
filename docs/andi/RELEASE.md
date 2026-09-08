# andi Release Notes

## 25.7.14

First tagged andi release on the OTP 25 branch.

**Versioning note:** from here on, andi's version number tracks otp23's
scheme (`25.x.y` mirroring otp23's `23.x.y`) instead of restarting its own
`25.0.x` count, so the two branches' andi releases stay easy to compare
release-for-release. This release brings otp25's andi up to par with
otp23's `andi@23.7.14` (the larger Postgres-fallback/Redis-recovery work
from otp23's earlier `23.7.13` has not been ported to otp25 yet and is
not included here).

- Fixed the dataset/ingestion source "Test" button failing with certificate errors against internal/private HTTPS endpoints, by trusting the image's system CA bundle instead of a hardcoded default; also added a 30-second connect timeout to outbound HTTP requests so a hung or unreachable host no longer stalls a URL test indefinitely (ported from otp23 `andi@23.7.14`)
- Fixed login failing in deployed environments: Phoenix's WebSocket `check_origin` configuration now allows the actual configured host (via `ANDI_HOST`) instead of only matching a hardcoded demo domain
- Added diagnostic logging around Auth0/Ueberauth configuration and login failures to make future authentication issues easier to diagnose
- Migrated andi's build and deploy to Elixir's built-in `mix release` as part of the underlying Erlang/OTP 25 + Elixir upgrade
