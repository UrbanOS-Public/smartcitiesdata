#!/usr/bin/env bash

set -e

git clone https://github.com/smartcitiesdata/smartcitiesdata.git -b $TRAVIS_PULL_REQUEST_BRANCH

cd smartcitiesdata

source ./scripts/lib_common.sh

apps=$(apps_needing_built "${TRAVIS_COMMIT_RANGE}")
if [[ -z ${apps} ]]; then
    echo "No apps need to be published with a development tag. Exiting."
    exit 0
fi

for app in $apps; do
    temp="${app}_BUILD"
    echo $temp
    printf -v $temp true
    export "$temp=true"
    sh -c "echo \$$temp"
done