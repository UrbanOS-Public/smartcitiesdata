set -e

app="${1}"
version="${2}"

echo "Logging into Quay..."
echo "${QUAY_PASSWORD}" | docker login -u "${QUAY_USERNAME}" --password-stdin quay.io

docker tag smartcitiesdata/$app:$version quay.io/urbanos/$app:$version
docker push quay.io/urbanos/$app:$version
