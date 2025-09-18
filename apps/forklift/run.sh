#!/bin/bash

if [ -d test/unit/forklimit ] ; then
    mix test test/unit/forklift/reproduce_mailbox_error_test.exs --exclude skip
fi

MIX_ENV=integration iex -S mix
