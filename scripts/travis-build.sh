#!/usr/bin/env bash
set -eou pipefail

mix format --check-formatted
mix test
mix credo
mix sobelow -i Config.HTTPS --skip --compact --exit low
mix test.integration
mix test.e2e
