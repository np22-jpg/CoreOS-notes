#! /usr/bin/bash

CONTAINER_NAME=$1
TO_BUILD=$2

if [ -z ${CONTAINER_NAME} ]; then
  echo Please name an image to build!
  exit 1
fi

source .env

source promises.sh
init_promises # Equivalent to set -eq1

# Check if packages are installed
required_packages="podman buildah qemu-user-static jq curl git wget"
if [[ ! "$EUID" == 1 || ! "$EUID" == 0 ]]; then
  sudo="sudo -k"
fi

if [ $(which dnf 2>/dev/null) ]
then
  if [ rpm -qi $required_packages 2>/dev/null ]; then
    echo Missing DNF packages, installing.
    $sudo dnf install --assumeyes $required_packages
  else
    echo "Podman available!"
  fi
elif [ $(which apt 2>/dev/null) ]; then
  echo Debian-based system detected.
  $sudo apt update -y
  $sudo apt install -y $required_packages
else
  echo "Podman available! (Or apt/DNF aren\'t)"
fi

if [ $CLEAN == 1 ]; then
  echo Cleaning images...
  podman image rm $CONTAINER_NAME 2>/dev/null || true
  buildah manifest rm $CONTAINER_NAME-manifest 2>/dev/null || true
fi

if [ $PULL == 1 ]; then
  echo Retrieving images...
  podman pull quay.io/almalinuxorg/9-base 2>/dev/null
  podman pull quay.io/almalinuxorg/9-micro 2>/dev/null
fi

echo Creating manifest
buildah manifest create $CONTAINER_NAME-manifest

# Build target if specified.
# Otherwise, build everything in Release file
source $CONTAINER_NAME/Release
if [[ ! -z $TO_BUILD ]]; then
  CHANNELS=$TO_BUILD
  echo Building $CHANNELS
else
  echo Building $CHANNELS
fi

for platforms in $PLATFORM; do
  log_name=$(echo $platforms | tr '/' '-')
  for releases in $CHANNELS; do
    common_build="--jobs=0 \
    --platform=$platforms \
    --manifest=$CONTAINER_NAME-manifest \
    --target=$releases \
    --layers=true \
    --build-arg=REPO=$REPO \
    1>"logs/$CONTAINER_NAME-$log_name-$releases.log" 2>&1 "
    echo Making $releases image for $platforms
    if [[ $releases == git ]]; then
      TAG=$(git ls-remote https://github.com/$REPO.git | head -1 | sed "s/HEAD//" | cut -c1-7)
      promise_run buildah bud --file=$CONTAINER_NAME/Containerfile \
        --tag=$CONTAINER_NAME:bleeding \
        --tag=$CONTAINER_NAME:$TAG \
        $common_build
    elif [[ $releases == release ]]; then
      TAG=$(curl https://api.github.com/repos/$REPO/releases/latest 2>/dev/null | jq -r .tag_name)
      promise_run buildah bud --file=$CONTAINER_NAME/Containerfile \
        --tag=$CONTAINER_NAME:latest \
        --tag=$CONTAINER_NAME:$TAG \
        --tag=$CONTAINER_NAME:$(date +"%m%d%Y") \
        $common_build
    else
      TAG=$(curl https://api.github.com/repos/$REPO/releases/latest 2>/dev/null | jq -r .tag_name)
      promise_run buildah bud --file=$CONTAINER_NAME/Containerfile \
        --tag=$CONTAINER_NAME:$releases-latest \
        --tag=$CONTAINER_NAME:$releases-$TAG \
        --tag=$CONTAINER_NAME:$releases-$(date +"%m%d%Y") \
        $common_build
    fi
  done
done

await_promises

podman image ls

# buildah manifest inspect ultraviolet-app-manifest:latest
# podman push $CONTAINER_NAME dir:out
