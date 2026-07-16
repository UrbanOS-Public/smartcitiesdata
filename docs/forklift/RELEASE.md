# forklift Release Notes

## 23.19.30 (pending release — not yet tagged)
- Added support for multiple datasets per ingestion and an ingestion field selector
- Added event logs for ingestion-started and validations-complete, plus dead letter queue status updates
- Column names with hyphens are now supported (converted to underscores automatically)
- Added the ability to delete data, and now tracks table compactions per dataset/ingestion
- Fixed a data reader re-initialization issue on extract start and a Kafka error handling issue
- Upgraded Trino (CVE fix) and the Alpine base image
