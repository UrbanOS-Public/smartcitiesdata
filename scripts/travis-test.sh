#!/usr/bin/env bash
set -eou pipefail

DOCKER_COMPOSE_VERSION=1.23.1

app="$1"

# before_install
sudo rm /usr/local/bin/docker-compose
curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > docker-compose
chmod +x docker-compose
sudo mv docker-compose /usr/local/bin
# sudo service postgresql stop

# script
cd apps/$app
mix test.integration
