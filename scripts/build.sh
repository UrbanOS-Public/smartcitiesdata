#!/usr/bin/env bash
cd "$(dirname ${BASH_SOURCE[0]})"
cd ".."

nl=$'\n'

if [[ $1 == "" || $1 == "help" || $2 == "" ]]; then
  echo "build {app_name} {image_tag} {rebuild_build_image} {repository}${nl}"
  echo "  Defaults:"
  echo "  - rebuild_build_image: true"
  echo "  - repository: smartcitiesdata/{app_name}${nl}"
  echo "  Flags:"
  echo "   --push: Runs docker push on the built image"
  echo "  Note: build_image is *all* of the elixir apps compiled."
  echo "        Only needs to be rebuilt once for changes across multiple apps.${nl}"
  exit 1
fi

set -e

app="${1}"
tag="${2}"
rebuild_build_image="${3:-true}"
repository="${4:-smartcitiesdata/$app}"

if [[ ! -d apps/$app ]]; then
  echo "Directory apps/$app does not exist. Please check the app name you provided."
  exit 1
fi

if ([[ "$(docker images -q smartcitiesdata:build 2> /dev/null)" == "" ]] || $rebuild_build_image ); then
  echo "Rebuilding elixir build image..."
  docker rmi -f smartcitiesdata:build 2> /dev/null
  docker build -t smartcitiesdata:build .
fi

echo "Building $repository:$tag"
docker build -t $repository:$tag apps/$app

echo "${nl}Built ${repository}:${tag}$"

if [[ $* == *--push* ]]; then
  echo "Pushing ${repository}:${tag}"
  docker push "${repository}:${tag}"
fi

echo "Done ${nl}"