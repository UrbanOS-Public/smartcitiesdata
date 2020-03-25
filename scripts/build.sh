#!/usr/bin/env bash

set -e

app="${1}"
version="${2}"
rebuild_build_image="${3:-true}"

if [[ ! -d apps/$app ]]; then
  echo "Directory apps/$app does not exist. Please check the app name you provided."
  exit 1
fi

if ([[ "$(docker images -q smartcitiesdata:build 2> /dev/null)" == "" ]] || $rebuild_build_image ); then
  docker rmi -f smartcitiesdata:build
  docker build -t smartcitiesdata:build .
fi

docker build -t smartcitiesdata/$app:$version apps/$app
