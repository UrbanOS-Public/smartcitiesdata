#!/bin/bash

rm -f stdout.log
rm -f stderr.log

podman compose -f docker-compose.yml up  > >(tee -a stdout.log) 2> >(tee -a stderr.log >&2)
