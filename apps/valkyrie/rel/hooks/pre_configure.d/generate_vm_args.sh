#!/usr/bin/env bash

if [[ -z "${RUN_IN_KUBERNETES}"  ]]; then
    export ERLANG_NAME="127.0.0.1"
else
    POD_A_RECORD=$(echo ${NODE_IP} | sed 's/\./-/g')
    export ERLANG_NAME="${POD_A_RECORD}.${NAMESPACE}.pod.cluster.local"
fi

