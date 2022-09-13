#!/usr/bin/env bash
set -eo pipefail

DOCKER_COMPOSE_VERSION=1.29.2

app="$1"

sudo rm /usr/local/bin/docker-compose
curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > docker-compose
chmod +x docker-compose
sudo mv docker-compose /usr/local/bin
sudo service postgresql stop

cd apps/$app
mix test.integration --max-failures 1
