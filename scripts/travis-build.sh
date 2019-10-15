#!/usr/bin/env bash
set -eou pipefail

app="$1"

cd apps/$app
mix verify
mix test
mix test.integration
cd -
