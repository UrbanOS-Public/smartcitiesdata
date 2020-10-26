#!/usr/bin/env bash
set -e

mix format --check-formatted
mix credo
mix sobelow_andi
mix sobelow_discovery_api
