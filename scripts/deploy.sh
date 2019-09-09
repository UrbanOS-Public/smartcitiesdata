#!/usr/bin/env bash

set -e

apps=(andi)
release_type="${1}"

echo "Logging into DockerHub..."
echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin

echo "Building base compilation image..."
docker build -t smartcitiesdata:build .

function build_image() {
    local app="$1"
    local tag="$2"
    docker build -t smartcitiesdata/${app}:${tag} apps/${app}
}

function push_image() {
    local app="$1"
    local tag="$@"
    docker push smartcitiesdata/${app}:${tag}
}

if [[ $release_type == "release" ]]; then
    for app_name in ${apps[*]}; do
        build_image ${app_name} ${TRAVIS_BRANCH}
        push_image ${app_name} ${TRAVIS_BRANCH}
    done
elif [[ $release_type == "master" ]]; then
    for app_name in ${apps[*]}; do
        build_image ${app_name} development
        push_image ${app_name} development
    done
else
    echo "Branch should not be published. Exiting..."
    exit 0
fi
