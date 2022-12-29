#! /usr/bin/bash

set -e

if ! rpm -qi podman 1>/dev/null; 
then
  echo Missing podman, installing.
  sudo -k dnf --assumeyes install podman
fi

podman run -it --rm --privileged \
  --tmpfs /tmp \
  -v ./:/root \
  --name dev \
  quay.io/almalinuxorg/9-base \
  /root/Ultraviolet/build.sh