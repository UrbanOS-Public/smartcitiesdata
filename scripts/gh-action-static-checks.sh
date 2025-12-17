#!/usr/bin/env bash
set -e

app="$1"

cd apps/$app
mix format --check-formatted

if mix help credo >/dev/null 2>&1; then
    mix credo; exit 0
fi

if mix help sobelow >/dev/null 2>&1; then
    mix sobelow
fi
