#!/usr/bin/env bash

set -e

app="${1}"
version="${2}"

echo "Logging into DockerHub..."
echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin

docker push smartcitiesdata/$app:$version

echo "Logging into Quay..."
echo "${QUAY_PASSWORD}" | docker login -u "${QUAY_USERNAME}" --password-stdin quay.io

docker push quay.io/urbanos/$app:$version
