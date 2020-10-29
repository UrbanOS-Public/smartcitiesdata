#!/usr/bin/env bash

set -e

REF=${1}

if [[ ! -z "$REF" ]]; then
    tag=${REF#refs/tags/}
    app=$(echo "$tag" | cut -d@ -f1)
    vsn=$(echo "$tag" | cut -d@ -f2)
    mix_vsn=$(mix cmd --app $app mix app.version | tail -1)

    if [[ ! $vsn == $mix_vsn ]]; then
        echo "Tag version '$vsn' does not match mix version '$mix_vsn'"
        exit 1
    fi

    echo "Building smartcitiesdata/${app:?COULD NOT DETERMINE APP}:${vsn:?COULD NOT DETERMINE VERSION}"

    ./scripts/build.sh $app $vsn
    ./scripts/publish.sh $app $vsn
else
    echo "Ref $REF should not be released. Exiting."
    exit 0
fi
