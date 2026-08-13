# reaper Release Notes

## 23.0.47 (pending release — not yet tagged)
- Fixed ingestion downloads failing with certificate errors against internal/private HTTPS endpoints, by trusting the image's system CA bundle instead of the client's built-in default
- Added internal diagnostic tooling to step through a failing ingestion's extract steps and surface the real underlying error, instead of a generic "unable to process step" message

## 23.0.46 (pending release — not yet tagged)
- Added support for multiple datasets per ingestion and an ingestion field selector
- Added ingestion-started and validations-complete event logs, plus improved error handling
- Fixed a schema case-sensitivity bug and removed unnecessary GeoJSON formatting
- Upgraded Trino (CVE fix) and the Alpine base image
