#!/usr/bin/env bash
set -e
current_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GIT_COMMIT_HASH=${1:-latest}
ENVIRONMENT=${2:-dev}

helm init --client-only
helm upgrade --install flair \
  ${current_directory}/../chart \
  --namespace=streaming-services \
  --set image.tag="$GIT_COMMIT_HASH" \
  --values ${current_directory}/values_$ENVIRONMENT.yaml
