#!/usr/bin/env bash

# sewardr1's convenience script to find potential errors before pushing to github


set -e

project="$(pwd)"
app="$1"

if [ -z "$app" ] ; then
    echo "Please specify a microservice to test!"
    read x
    batcat $0
fi

cd apps/$app
appdir="$(pwd)"
mix compile
mix format
mix format --check-formatted

#if mix help credo >/dev/null 2>&1; then
#    mix credo
#fi

if mix help sobelow >/dev/null 2>&1; then
    mix sobelow
fi

set -euo pipefail

set -x
#mix test --max-failures=1
#MIX_ENV=test mix test

./test.sh

cd $project
bash scripts/gh-action-unit-test.sh $app
#bash scripts/gh-action-integration-test.sh $app

