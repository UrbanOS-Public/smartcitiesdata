
# Overcome limitation of mounting local file paths with podman-remote

distrobox-host-exec podman volume create my-init-test-vol
distrobox-host-exec podman run --name=rtd_init -v my-init-test-vol:/test -it alpine:3.16.0
