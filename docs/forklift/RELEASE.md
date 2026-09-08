# forklift Release Notes

## 25.19.31

First tagged forklift release on the OTP 25 branch.

**Versioning note:** from here on, forklift's version number tracks otp23's
scheme (`25.x.y` mirroring otp23's `23.x.y`) instead of restarting its own
`25.0.x` count, so the two branches' forklift releases stay easy to compare
release-for-release. This release brings otp25's forklift up to par with
otp23's `forklift@23.19.31`.

- Fixed a crash-loop bug where a missing/expired Redis cache key for a dataset's expected message count would crash ingestion-complete bookkeeping instead of falling back gracefully, repeatedly stalling that dataset's consumer at the same Kafka offset with no progress (ported from otp23 `forklift@23.19.31`)
- Fixed a duplicate-record risk in the Presto/Hive migration job: an extraction already migrated with the expected row count is now skipped instead of re-inserted, and any partial rows from an earlier failed attempt are cleared before retrying, so consumer offset resets/pod restarts/retries no longer double up data
- Forklift now detects and skips empty/blank Kafka messages (logging a warning) instead of failing to parse them
- Fixed the `OVERWRITE_MODE` environment variable not being honored
- No longer starts consuming Valkyrie's output topic before messages have been validated
- Migrated forklift's build and deploy to Elixir's built-in `mix release` (replacing the deprecated Distillery) as part of the underlying Erlang/OTP 25 + Elixir upgrade, including fixes to S3/Kafka client environment variable handling and libcluster/Kubernetes env var wiring for the new release format
