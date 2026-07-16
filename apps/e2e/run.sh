#!/bin/bash

MIX_ENV=integration mix docker.start
#MIX_ENV=integration mix test.integration --max-failures 1

# teardown
#MIX_ENV=integration mix docker.kill
