#!/bin/bash


# Overcome limitation of mounting local file paths with podman-remote
# odin's docker scipt will choose to use distrobox-host-exec if appropriate.
# distrobox-host-exec

# Use "start" to run the container with the volume mounted.
# From another terminal run this script again with the "copy" command to copy the necessary files.

method=$1
 
case $method in

    start)

         docker volume create my-init-test-vol
         docker run --name=rtd_init -v my-init-test-vol:/test -it alpine:3.16.0
         ;;

    copy)

	container_id=$(docker ps --filter "name=rtd_init" --quiet)

	if [ ! -z "$container_id" ] ; then
            docker cp test/setup.sh $container_id:/test/
	    echo "Copied 1 file to /test"
	fi;
	;;

esac

