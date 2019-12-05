#!/usr/bin/env bash

mix format --check-formatted
mix credo
mix sobelow
