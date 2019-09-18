#!/usr/bin/env bash
set -eou pipefail

# before_install
sudo rm /usr/local/bin/docker-compose
curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > docker-compose
chmod +x docker-compose
sudo mv docker-compose /usr/local/bin

# install
mix local.rebar --force
mix local.hex --force
mix deps.get
mix hex.outdated || true

# script
mix test
mix format --check-formatted
mix credo
mix sobelow
mix test.integration
