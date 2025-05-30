#!/bin/bash

#
# For the purposes of this exercise we will pretend that the code below is commented.
#

pushd $(dirname $0) >/dev/null 2>&1

export OUTPUT_PATH="/mnt/singularity"
export IMAGE_NAME='puppet-server'

export PUPPET_OPTIONS="${@:1}"

if [[ -z ${PUPPET_OPTIONS} ]]; then
  PUPPET_OPTIONS="-c enc.sh -e production -w -a -p openvox -s puppet"
fi

sudo singularity build \
  --fix-perms \
  --force \
  --build-arg PUPPET_OPTIONS="${PUPPET_OPTIONS}" \
  ${OUTPUT_PATH}/${IMAGE_NAME}.simg \
  ${IMAGE_NAME}-sing.def
