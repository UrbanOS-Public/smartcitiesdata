#!/usr/bin/env bash

function app_does_not_need_built {
  local -r app=${1}
  local -r commit_range=${2}

  local -r apps=$(apps_needing_built "${commit_range}")

  ! echo -e "${apps}" | grep -x "${app}" -q
}

function apps_needing_built {
  local -r commit_range=${1}

  if should_build_all "${commit_range}"; then
    all_apps
  else
    apps_that_have_changed "${commit_range}"
  fi
}

function apps_needing_published {
  local -r commit_range=${1}

  if should_build_all "${commit_range}"; then
    all_publishable_apps
  else
    publishable_apps_that_have_changed "${commit_range}"
  fi
}

function publishable_apps_that_have_changed {
  local -r commit_range=${1}

  comm -12 <(apps_that_have_changed "${commit_range}" | sort) <(all_publishable_apps | sort)
}

function should_build_all {
  local -r commit_range=${1}

  ! git diff --exit-code --quiet ${commit_range} -- mix.lock apps/pipeline apps/dead_letter apps/providers
}

function apps_that_have_changed {
  local -r commit_range=${1}

  elixir \
    -r scripts/version_differ.exs \
    -e "VersionDiffer.get_changed_apps(${commit_range:+\"${commit_range}\"}) |> Enum.join(\"\n\") |> IO.puts()"
}

function all_apps {
  find apps -name mix.exs | awk -F/ '{print $2}'
}

function all_publishable_apps {
  find apps -name Dockerfile | awk -F/ '{print $2}'
}

