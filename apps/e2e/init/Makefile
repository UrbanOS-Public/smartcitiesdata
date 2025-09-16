build:
	podman build -t rtd-urbanos-init:latest -f Dockerfile .

run:
	podman run --rm -it --name rtd-init -v ../test:/workdir -v minio:/minio rtd-urbanos-init:latest
