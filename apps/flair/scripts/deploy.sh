#!/bin/bash

RELEASE_TYPE=$1
echo "Logging into Dockerhub ..."
echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin

echo "Determining image tag for ${TRAVIS_BRANCH} build ..."

if [[ $RELEASE_TYPE == "release" ]]; then
  export TAGGED_IMAGE="smartcitiesdata/flair:${TRAVIS_BRANCH}"
elif [[ $RELEASE_TYPE == "master" ]]; then
  export TAGGED_IMAGE="smartcitiesdata/flair:development"
else
    echo "Branch should not be pushed to Dockerhub"
    exit 0
fi

echo "Pushing to Dockerhub with tag ${TAGGED_IMAGE} ..."

docker tag flair:build "${TAGGED_IMAGE}"
docker push "${TAGGED_IMAGE}"
