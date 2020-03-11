#!/usr/bin/env bash

set -e

app="${1}"
version="${2}"

if [[ ! -d apps/$app ]]; then
  echo "Directory apps/$app does not exist. Please check the app name you provided."
  exit 1
fi

docker rmi -f smartcitiesdata:build
docker build -t smartcitiesdata:build .
docker build -t smartcitiesdata/$app:$version apps/$app
