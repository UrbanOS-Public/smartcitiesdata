#!/usr/bin/env bash

set -e

app="${1}"

./scripts/build.sh $app development false
./scripts/publish.sh $app development
