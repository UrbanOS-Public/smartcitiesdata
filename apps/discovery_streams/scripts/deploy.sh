#!/bin/bash

echo "Logging into Dockerhub ..."
echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin

echo "Determining image tag for ${TRAVIS_BRANCH} build ..."

if [[ $TRAVIS_BRANCH =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    export TAGGED_IMAGE="smartcitiesdata/discovery_streams:${TRAVIS_BRANCH}"
    export SMOKE_TEST_IMAGE="smartcitiesdata/discovery_streams_smoke_test:${TRAVIS_BRANCH}"
elif [[ $TRAVIS_BRANCH == "master" ]]; then
    export TAGGED_IMAGE="smartcitiesdata/discovery_streams:development"
    export SMOKE_TEST_IMAGE="smartcitiesdata/discovery_streams_smoke_test:development"
else
    echo "Branch should not be pushed to Dockerhub"
    exit 0
fi

echo "Pushing to Dockerhub with tag ${TAGGED_IMAGE} ..."

docker tag discovery_streams:build "${TAGGED_IMAGE}"
docker push "${TAGGED_IMAGE}"

docker tag discovery_streams_smoke_test:build "${SMOKE_TEST_IMAGE}"
docker push "${SMOKE_TEST_IMAGE}"
