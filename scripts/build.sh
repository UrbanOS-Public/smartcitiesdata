#!/usr/bin/env bash

set -e

app="${1}"
version="${2}"

docker rmi -f smartcitiesdata:build
docker build -t smartcitiesdata:build .
docker build -t smartcitiesdata/$app:$version apps/$app
