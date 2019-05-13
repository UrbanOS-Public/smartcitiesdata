#!/usr/bin/env bash
set -e
current_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GIT_COMMIT_HASH=${1:-latest}
ENVIRONMENT=${2:-dev}
OVERRIDE_FILE="${current_directory}/values_prod.yaml"

if [ -f "${current_directory}/values_$ENVIRONMENT.yaml" ]; then
  OVERRIDE_FILE="${current_directory}/values_$ENVIRONMENT.yaml"
fi

helm init --client-only
helm upgrade --install flair \
  ${current_directory}/../chart \
  --namespace=streaming-services \
  --set image.tag="$GIT_COMMIT_HASH" \
  --values "${OVERRIDE_FILE}"
