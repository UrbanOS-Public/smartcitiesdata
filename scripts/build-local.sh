#!/usr/bin/env bash
# Build OTP23 microservice images locally with podman and optionally push to quay.io.
# Workaround for broken GitHub CI (ubuntu-20.04 deprecation).
set -euo pipefail

PODMAN="${HOME}/bin/podman"
REPO="quay.io/urbanos"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Apps with Dockerfiles that have recent local changes
CHANGED_APPS=(andi discovery_api forklift reaper valkyrie)

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [APP...]

Build OTP23 microservice container images with podman and optionally push to ${REPO}.

If no APP names are given, builds all apps with recent local changes:
  ${CHANGED_APPS[*]}

OPTIONS:
  --rebuild-base    Force rebuild of the smartcitiesdata:build base image
                    (auto-built on first run or when not found)
  --push            Push images to ${REPO} after building
  --no-cache        Pass --no-cache to podman build
  -h, --help        Show this help

EXAMPLES:
  $(basename "$0")                          # build all changed apps
  $(basename "$0") discovery_api forklift   # build specific apps
  $(basename "$0") --push discovery_api     # build and push discovery_api
  $(basename "$0") --rebuild-base --push    # rebuild everything and push all

AVAILABLE APPS WITH DOCKERFILES:
  alchemist  andi  discovery_api  discovery_streams
  estuary    flair forklift       raptor  reaper  valkyrie
EOF
}

REBUILD_BASE=false
PUSH=false
NO_CACHE=""
APPS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rebuild-base) REBUILD_BASE=true; shift ;;
    --push)         PUSH=true;         shift ;;
    --no-cache)     NO_CACHE="--no-cache"; shift ;;
    -h|--help)      usage; exit 0 ;;
    -*)             echo "Unknown option: $1"; usage; exit 1 ;;
    *)              APPS+=("${1//-/_}"); shift ;;
  esac
done

[[ ${#APPS[@]} -eq 0 ]] && APPS=("${CHANGED_APPS[@]}")

app_version() {
  local app="$1"
  grep 'version:' "${SCRIPT_DIR}/../apps/${app}/mix.exs" 2>/dev/null \
    | head -1 | grep -oP '"[^"]+"' | tr -d '"'
}

build_base() {
  local existing
  existing="$($PODMAN images -q smartcitiesdata:build 2>/dev/null || true)"
  if $REBUILD_BASE || [[ -z "$existing" ]]; then
    echo "==> Building smartcitiesdata:build base image..."
    $PODMAN build $NO_CACHE -t smartcitiesdata:build "${SCRIPT_DIR}/.."
    echo "==> Base image built."
  else
    echo "==> smartcitiesdata:build already present — skipping (use --rebuild-base to force)"
  fi
}

build_app() {
  local app="$1"
  local app_dir="${SCRIPT_DIR}/../apps/${app}"

  if [[ ! -d "$app_dir" ]]; then
    echo "ERROR: apps/${app} directory not found" >&2
    return 1
  fi
  if [[ ! -f "${app_dir}/Dockerfile" ]]; then
    echo "ERROR: apps/${app}/Dockerfile not found" >&2
    return 1
  fi

  local vsn
  vsn="$(app_version "$app")"
  if [[ -z "$vsn" ]]; then
    echo "ERROR: could not determine version for ${app}" >&2
    return 1
  fi

  local local_tag="smartcitiesdata/${app}:${vsn}"
  local remote_tag="${REPO}/${app}:${vsn}"

  echo
  echo "==> [$app] Building ${local_tag}..."
  $PODMAN build $NO_CACHE -t "$local_tag" "$app_dir"

  echo "==> [$app] Tagging  ${remote_tag}..."
  $PODMAN tag "$local_tag" "$remote_tag"

  if $PUSH; then
    echo "==> [$app] Pushing  ${remote_tag}..."
    $PODMAN push "$remote_tag"
    echo "==> [$app] Pushed."
  else
    echo "==> [$app] Done (run with --push to push to ${REPO})"
  fi
}

# ---- main ----

echo "================================================================"
echo " Apps:          ${APPS[*]}"
echo " Rebuild base:  $REBUILD_BASE"
echo " Push:          $PUSH"
echo "================================================================"

build_base

FAILED=()
for app in "${APPS[@]}"; do
  if ! build_app "$app"; then
    FAILED+=("$app")
    echo "!!! Build FAILED for ${app} — continuing with remaining apps"
  fi
done

echo
echo "================================================================"
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo " FAILED: ${FAILED[*]}"
  exit 1
else
  echo " All builds succeeded: ${APPS[*]}"
  if ! $PUSH; then
    echo " Re-run with --push to push images to ${REPO}"
  fi
fi
echo "================================================================"
