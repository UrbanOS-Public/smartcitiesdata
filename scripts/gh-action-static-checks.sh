#!/usr/bin/env bash
set -e

app="$1"

cd apps/$app
mix format --check-formatted
mix credo

if mix help sobelow >/dev/null 2>&1; then
    mix sobelow
fi
