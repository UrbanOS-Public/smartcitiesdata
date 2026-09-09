# alchemist Release Notes

## 25.2.18

First tagged alchemist release on the OTP 25 branch.

**Versioning note:** this release jumps otp25 alchemist's version from
its prior `25.0.x` line to `25.2.18`. It does not mirror an otp23
alchemist release — otp23's alchemist is still on its own independent
`0.2.x` line, currently `0.2.57`. A separate otp23 `alchemist@23.3.18`
release is planned for later.

- Migrated alchemist's build and deploy to Elixir's built-in `mix release` (replacing the deprecated Distillery) as part of the underlying Erlang/OTP 25 + Elixir upgrade
- Migrated alchemist's test suite from Placebo to Mock/Mox, including a fix for a `TelemetryEvent.Mock` process lifecycle issue that was causing `noproc` errors
- Disabled automatic clustering via libcluster due to FQDN/short-name conflicts in Kubernetes; node distribution/cookie configuration (`rel/env.sh.eex`, `runtime.exs`) and `:pg` process-group startup verification were kept in place so clustering can be safely re-enabled later
- Fixed pipeline messages with an empty or nil value causing a JSON-parse error; they are now skipped with a warning log instead of failing the message
- Added the running version number and node/distribution diagnostics (node name, `HOSTNAME`/`RELEASE_NODE`/`RELEASE_DISTRIBUTION` env vars) to startup logging
