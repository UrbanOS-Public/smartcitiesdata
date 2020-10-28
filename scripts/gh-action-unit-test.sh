#!/usr/bin/env bash
set -e

app="$1"
cd apps/$app
mix test
