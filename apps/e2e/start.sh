#!/bin/bash

MIX_ENV=integration mix docker.start | tee e2e.log
#MIX_ENV=integration mix test.integration --max-failures 50 | tee e2e.log

# teardown
# MIX_ENV=integration mix docker.kill
