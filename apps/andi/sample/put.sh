#!/bin/bash

env=$1
file=$2

curl -X PUT -H "Content-Type: application/json" https://andi.$env.internal.smartcolumbusos.com/api/v1/dataset -d @$file
