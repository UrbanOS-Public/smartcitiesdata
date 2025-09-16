#!/bin/bash
set -e

echo "Initializing Trino configuration..."

# Create the catalog directory
mkdir -p /etc/trino/catalog

# Copy the hive configuration
cp /opt/test/hive.properties /etc/trino/catalog/hive.properties

echo "Configuration files copied:"
ls -la /etc/trino/catalog/

echo "Starting Trino..."
exec /usr/lib/trino/run-trino