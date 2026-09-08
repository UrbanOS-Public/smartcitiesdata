# valkyrie Release Notes

## 25.7.42

First tagged valkyrie release on the OTP 25 branch.

**Versioning note:** from here on, valkyrie's version number tracks
otp23's scheme (`25.x.y` mirroring otp23's `23.x.y`) instead of restarting
its own `25.0.x` count, so the two branches' valkyrie releases stay easy
to compare release-for-release. otp23's matching `valkyrie@23.7.42` entry
covers unrelated ingestion/Kafka work not applicable here — this release
instead brings otp25's valkyrie up to date with a validation fix and a
few fixes found undocumented in this branch's own history.

- Fixed schema validation rejecting a `"map"`-typed field that has no `subSchema` defined; such fields are now passed through as-is instead of failing validation (ported from otp23 `48a34455`)
- Valkyrie now skips empty/nil Kafka messages gracefully (with a warning log) instead of crashing while trying to parse them
- Fixed a potential crash when logging a message that itself failed to decode as JSON — that error path now uses a safe decode instead of one that could raise again
- Truncated oversized payloads in error/dead-letter log lines to avoid memory bloat from very large messages
- Migrated valkyrie's build and deploy to Elixir's built-in `mix release` as part of the underlying Erlang/OTP 25 + Elixir upgrade
