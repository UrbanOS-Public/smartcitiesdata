#!/usr/bin/env bash

set -e

if [ ! -z "$TRAVIS_TAG" ]; then
    app=$(echo "$TRAVIS_TAG" | cut -d: -f1)
    vsn=$(echo "$TRAVIS_TAG" | cut -d: -f2)

    echo "Building smartcitiesdata/${app:?COULD NOT DETERMINE APP}:${vsn:?COULD NOT DETERMINE VERSION}"

    ./scripts/build.sh $app $vsn
    ./scripts/publish.sh $app $vsn
elif [[ "$TRAVIS_BRANCH" == "master" ]]; then
    for app in $(find apps -name Dockerfile | awk -F/ '{print $2}'); do
        ./scripts/build.sh $app development
        ./scripts/publish.sh $app development
    done
else
    echo "Branch $TRAVIS_BRANCH should not be published. Exiting."
    exit 0
fi
