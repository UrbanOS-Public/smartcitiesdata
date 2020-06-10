#!/usr/bin/env bash
set -eo pipefail

source ./scripts/lib_common.sh

DOCKER_COMPOSE_VERSION=1.23.1

app="$1"
force_run_test="${2:-false}"

if ([[ "${force_run_test}" == "false" ]] && app_does_not_need_built "${app}" "${TRAVIS_COMMIT_RANGE}") || [[ -n "${TRAVIS_TAG}" ]]; then
  echo "Application ${app} was not changed, skipping tests"
  exit 0
fi

# before_install
sudo rm /usr/local/bin/docker-compose
curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > docker-compose
chmod +x docker-compose
sudo mv docker-compose /usr/local/bin
sudo service postgresql stop

# script
cd apps/$app
mix test.integration --max-failures 1
