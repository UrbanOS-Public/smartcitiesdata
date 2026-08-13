# raptor Release Notes

## 23.3.5 (pending release — not yet tagged)
- Fixed Redis `KEYS` full-keyspace scans in the dataset/user/access-group stores that could stall Redis under high key volume; exact lookups now use `GET`, prefix lookups use cursor-based `SCAN`

## 1.3.4 (pending release — not yet tagged)
- Added support for multiple datasets per ingestion
- Renamed Auth0 client ID configuration variables to match updated naming
- General logging improvements
- Updated the Alpine base image
