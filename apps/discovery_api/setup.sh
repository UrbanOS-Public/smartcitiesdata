#!/bin/bash
tempfile=$(mktemp)
kubectl --namespace cluster-infra get configmap aws-properties -o json \
  | jq --raw-output '.data."aws.props"' > $tempfile

set -o allexport
source $tempfile
set +o allexport