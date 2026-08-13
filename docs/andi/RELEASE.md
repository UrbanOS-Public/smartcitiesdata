# andi Release Notes

## 23.7.14 (pending release — not yet tagged)
- Fixed the dataset/ingestion source "Test" button failing with certificate errors against internal/private HTTPS endpoints, by trusting the image's system CA bundle instead of a hardcoded default
- Added a 30-second connect timeout to outbound HTTP requests so a hung or unreachable host no longer stalls a URL test indefinitely

## 23.7.13 (pending release — not yet tagged)
- ANDI now recovers automatically from a Redis cache reset: harvesting, organization lookups during ingestion publish, and the org dropdown on dataset/ingestion forms all fall back to Postgres when Redis has no record yet, instead of silently failing
- Added a "Resync Orgs to Redis" button on the Organizations page to manually replay organization data back onto the event bus after a Redis reset
- Added scripts to replay datasets, ingestions, organizations, and access group memberships from Postgres back onto the event bus for recovery after infrastructure incidents, paced to avoid overwhelming downstream services
- Dataset and ingestion publishing now catch and log conversion errors instead of raising unhandled exceptions
- Added internal diagnostic tooling to help track down why a dataset or ingestion fails to publish

## 23.7.12 (pending release — not yet tagged)

- Added support for multiple datasets per ingestion, including an ingestion field/selector picker
- Added a "greater than or equal to" conditional validation option and data dictionary invalid-character validation
- Event logs: added ingestion-started events, auto-delete of events older than 7 days, and general logging polish
- Fixed several form bugs: nested field bug, data dictionary checkbox, header bug, schema case-sensitivity, ingestion selector defaulting, and dead letter queue status logic
- Added custom icon selection and keywords/access-level fields on report generation
- Upgraded Trino (security/CVE fix — requires a connection name update) and bumped the Alpine base image
