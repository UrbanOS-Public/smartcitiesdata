#!/bin/bash

IP=$(hostname -I)
COOKIE="SNKF9lrm67a9LvQ0w/UusA=="
elixir --name "cota-streaming-consumer@${IP}" --cookie "${COOKIE}"  -S mix phx.server
