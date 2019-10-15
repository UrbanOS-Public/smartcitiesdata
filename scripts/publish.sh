#!/usr/bin/env bash

set -e

app="${1}"
version="${2}"

echo "Logging into DockerHub..."
echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin

docker push smartcitesdata/$app:$version
