# alchemist Release Notes

## 0.2.57 (pending release — not yet tagged)
- Added support for multiple datasets per ingestion
- Added event logging for transformation start/completion and validation steps, with improved error handling and logging levels
- Fixed a schema case-sensitivity bug and null-type handling in the Constant transform
- Fixed a nested list-of-list transform bug and improved regex extraction
- Datetime format fields are now only validated when a static or target value is present
- Updated the Alpine base image and dependencies for security patches
