#!/usr/bin/env bash

function app_needs_build {
  local -r app=${1}
  local -r commit_range=${2}

  local -r apps=$(apps_needing_builds "${commit_range}")

  echo -e "${apps}" | grep -x "${app}" -q
}

function apps_needing_builds {
  local -r commit_range=${1}

  if should_build_all "${commit_range}"; then
    all_apps
  else
    apps_that_have_changed "${commit_repo}"
  fi
}

function should_build_all {
  local -r commit_range=${1}

  ! git diff --exit-code --quiet ${commit_range} mix.lock
}

function apps_that_have_changed {
  local -r commit_range=${1}

  elixir \
    -r scripts/version_differ.exs \
    -e "VersionDiffer.get_changed_apps(${commit_range:+\"${commit_range}\"}) |> Enum.join(\"\n\") |> IO.puts()"
}

function all_apps {
  find apps -name Dockerfile | awk -F/ '{print $2}'
}

