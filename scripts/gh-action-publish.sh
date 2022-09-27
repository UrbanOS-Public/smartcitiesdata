#!/usr/bin/env bash

set -e

app="${1}"
echo "app:"
printf "%s \n\n" "$app"

tag_as_development="${2:-true}"
echo "tag_as_development:"
printf "%s \n\n" "$tag_as_development"

mix_vsn=$(mix cmd --app $app mix app.version | tail -1)
echo "mix_vsn:"
printf "%s \n\n" "$mix_vsn"

./scripts/build.sh $app $mix_vsn false
./scripts/publish.sh $app $mix_vsn

if [[ $tag_as_development == true ]]; then
  docker tag smartcitiesdata/$app:$mix_vsn smartcitiesdata/$app:development
  ./scripts/publish.sh $app development
fi
