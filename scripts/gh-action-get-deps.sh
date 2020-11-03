#!/usr/bin/env bash
set -e

mix local.rebar --force
mix local.hex --force
mix deps.get
