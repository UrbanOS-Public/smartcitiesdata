#!/bin/bash

bash set-up.sh

bin/discovery_api migrate
bin/discovery_api foreground
