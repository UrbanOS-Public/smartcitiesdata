# discovery_streams Release Notes

## 25.0.2

First tagged discovery_streams release on the OTP 25 branch.

**Versioning note:** unlike most other apps in this migration,
discovery_streams never adopted otp23's `23.x.y` version scheme (otp23's
discovery_streams is still on its own independent `3.0.x` line, currently
`3.0.25`), so there's no otp23 version to mirror here — this release
continues otp25's own `25.0.x` count from `25.0.1`.

- Startup logging now includes the running version number
- Fixed Kubernetes pod environment variable reading issues affecting deployment
- Fixed a couple of dependency-compatibility breaks from the underlying Erlang/OTP 25 + Elixir upgrade (Kafka topic/source-context construction)
- Migrated discovery_streams' test suite from Placebo to Mox, with dependency injection added for Brook/Elsa/RaptorService, as part of the OTP 25 upgrade
