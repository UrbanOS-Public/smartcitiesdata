#!/usr/bin/env bash
set -e

app="$1"

cd apps/$app
mix format --check-formatted
mix credo
mix sobelow
