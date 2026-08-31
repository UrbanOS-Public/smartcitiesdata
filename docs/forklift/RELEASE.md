# forklift Release Notes

## 23.19.31
- Fixed a crash-loop bug where a missing/expired Redis cache key for a dataset's expected message count would crash ingestion-complete bookkeeping instead of falling back gracefully, repeatedly stalling that dataset's consumer at the same Kafka offset with no progress

## 23.19.30
- Added support for multiple datasets per ingestion and an ingestion field selector
- Added event logs for ingestion-started and validations-complete, plus dead letter queue status updates
- Column names with hyphens are now supported (converted to underscores automatically)
- Added the ability to delete data, and now tracks table compactions per dataset/ingestion
- Fixed a data reader re-initialization issue on extract start and a Kafka error handling issue
- Upgraded Trino (CVE fix) and the Alpine base image
