#!/bin/bash

BIND_PATHS="--bind "
BIND_PATHS="${BIND_PATHS} /etc/puppetlabs/code/environments/hvsk:/etc/puppetlabs/code/environments/production"
BIND_PATHS="${BIND_PATHS},/etc/puppetlabs/code/classifiers:/etc/puppetlabs/code/classifiers"
BIND_PATHS="${BIND_PATHS},/etc/puppetlabs/code/hiera:/etc/puppetlabs/code/hiera"

export BIND_PATHS
export LOCAL_PATH="$(dirname $0)"
export IMAGE_NAME='puppet-server'
export OVERLAY_PATH="/tmp/${IMAGE_NAME}-overlay"
export CONTAINER_PATH="/mnt/singularity/${IMAGE_NAME}.simg"

if [[ ! -r "${CONTAINER_PATH}" ]]; then
  echo "Unable to find readable [${IMAGE_NAME}] container at [${CONTAINER_PATH}], exiting."
  exit 1
fi

sudo singularity exec \
  --writable-tmpfs \
  ${BIND_PATHS} \
  ${CONTAINER_PATH} \
  /bin/bash

