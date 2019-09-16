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
    local tag="$2"
    docker push smartcitiesdata/${app}:${tag}
}

if [[ $release_type == "release" ]]; then
    for app_name in ${apps[*]}; do
        # This is a stop gap until all services are moved to the umbrella. At that point, we should
        # release the entire platform under a coherent version. We can use $TRAVIS_BRANCH to get
        # the platform version at that time.
        app_version=$(mix cmd --app $app_name mix app.version | tail -1)
        build_image ${app_name} ${app_version}
        push_image ${app_name} ${app_version}
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
