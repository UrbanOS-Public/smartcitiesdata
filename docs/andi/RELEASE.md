# andi Release Notes

## 23.7.12 (pending release — not yet tagged)

- Added support for multiple datasets per ingestion, including an ingestion field/selector picker
- Added a "greater than or equal to" conditional validation option and data dictionary invalid-character validation
- Event logs: added ingestion-started events, auto-delete of events older than 7 days, and general logging polish
- Fixed several form bugs: nested field bug, data dictionary checkbox, header bug, schema case-sensitivity, ingestion selector defaulting, and dead letter queue status logic
- Added custom icon selection and keywords/access-level fields on report generation
- Upgraded Trino (security/CVE fix — requires a connection name update) and bumped the Alpine base image
