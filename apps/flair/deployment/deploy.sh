#!/usr/bin/env bash
set -e

GIT_COMMIT_HASH=${1:-latest}
ENVIRONMENT=${2:-dev}

helm init --client-only
helm upgrade --install flair \
  ./chart \
  --namespace=streaming-services \
  --set image.tag="$GIT_COMMIT_HASH" \
  --values values_$ENVIRONMENT.yaml
