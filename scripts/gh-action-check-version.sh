#!/usr/bin/env bash
set -e

function _list_apps {
    find apps -name mix.exs | xargs -L1 dirname | grep -vw "apps/tasks"
}

(
    cd apps/tasks
    mix compile >/dev/null 2>&1
)

git fetch --tags

for app in $(_list_apps); do
    (
        cd $app
        if ! mix help app.updated >/dev/null 2>&1; then
            continue
        fi

        if ! mix app.updated; then
            continue
        fi

        mix app.tag_exists || true
    )
done
