#!/usr/bin/env bash

set -e

source ./scripts/lib_common.sh

if [[ ! -z "$TRAVIS_TAG" ]]; then
    app=$(echo "$TRAVIS_TAG" | cut -d@ -f1)
    vsn=$(echo "$TRAVIS_TAG" | cut -d@ -f2)
    mix_vsn=$(mix cmd --app $app mix app.version | tail -1)

    if [[ ! $vsn == $mix_vsn ]]; then
        echo "Tag version '$vsn' does not match mix version '$mix_vsn'"
        exit 1
    fi

    echo "Building smartcitiesdata/${app:?COULD NOT DETERMINE APP}:${vsn:?COULD NOT DETERMINE VERSION}"

    ./scripts/build.sh $app $vsn
    ./scripts/publish.sh $app $vsn
elif [[ "$TRAVIS_BRANCH" == "master" ]]; then
    apps=$(apps_needing_builds "${TRAVIS_COMMIT_RANGE}")

    for app in $apps; do
        ./scripts/build.sh $app development
        ./scripts/publish.sh $app development
    done
else
    echo "Branch $TRAVIS_BRANCH should not be published. Exiting."
    exit 0
fi
