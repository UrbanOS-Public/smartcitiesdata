#!/bin/bash
set -eou pipefail

docker build -t discovery_api:build .

# Install Integration Testing Dependencies
sudo rm /usr/local/bin/docker-compose
curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > docker-compose
chmod +x docker-compose
sudo mv docker-compose /usr/local/bin

# Install Mix Dependencies
mix local.rebar --force;
mix local.hex --force
mix deps.get
mix format --check-formatted
mix credo
mix sobelow -i Config.HTTPS --skip --compact --exit low
mix test.integration
