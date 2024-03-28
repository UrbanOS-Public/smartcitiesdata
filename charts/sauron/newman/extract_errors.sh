#!/bin/bash

RESULTS_FILE=$1
if [[ $RESULTS_FILE == "" ]]; then
  echo "Empty results file location. Please provide the location of a results file when running this script. EX: ./extract_errors.sh /sauron/results_123.json"
  exit 1
fi
ERROR_OUTPUT_FILE=${RESULTS_FILE}_errors.json

TOTAL_TESTS=$(jq .run.stats.assertions.total "$RESULTS_FILE")
echo "Total E2E TEST: $TOTAL_TESTS"
FAILURES=$(jq .run.stats.assertions.failed "$RESULTS_FILE")
if [[ $FAILURES -gt 0 ]]; then
  cat "$RESULTS_FILE" | jq '.run.executions | map(.assertions) | flatten(2) | map(select(.error != null))' > "$ERROR_OUTPUT_FILE"

  cat "$ERROR_OUTPUT_FILE"
  echo "E2E TEST FAILURES: $FAILURES"
else
  echo "All E2E Tests Passed!"
fi


