#!/bin/sh
set -e
echo "Beginning setup"
rm -rf /minio/trino-hive-storage || true
mkdir /minio/trino-hive-storage
echo "Setup complete"
ls minio