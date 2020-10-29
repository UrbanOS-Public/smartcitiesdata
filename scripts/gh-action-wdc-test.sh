#!/usr/bin/env bash

set -e

cd apps/discovery_api/priv/static/tableau

npm install
npm run es-check
npm test
