#!/bin/bash
set -e
set -o pipefail

tempfile=$(mktemp)
kubectl --namespace cluster-infra get configmap aws-properties -o json \
  | jq --raw-output '.data."aws.props"' > $tempfile

set -o allexport
source $tempfile
set +o allexport

export INGRESS_SCHEME=internal
export IMAGE_TAG=latest
set +e
