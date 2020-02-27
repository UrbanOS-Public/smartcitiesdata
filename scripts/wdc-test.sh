#!/usr/bin/env bash

set -e

source ./scripts/lib_common.sh
app="discovery_api"

if ( app_does_not_need_built "${app}" "${TRAVIS_COMMIT_RANGE}") || [[ -n "${TRAVIS_TAG}" ]]; then
  echo "Application ${app} was not changed, skipping tests"
  exit 0
fi

cd apps/discovery_api/priv/static/tableau

npm install
npm run es-check
npm test
