#!/usr/bin/env bash
set -eou pipefail

apps=$(find apps -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)

for app in ${apps[*]}; do
    rm -rf _build/{dev,test,integration}/lib/$app/
done
