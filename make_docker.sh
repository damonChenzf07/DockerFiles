#! /usr/bin/env bash

BASE_IMAGE="ubuntu:22.04"

MY_IMAGE_OUT="$1"

docker build \
-t "${MY_IMAGE_OUT}" \
--build-arg BASE_IMAGE="${BASE_IMAGE}" \
-f Dockerfile .
