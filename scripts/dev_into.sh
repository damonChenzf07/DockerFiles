#!/usr/bin/env bash

DOCKER_USER="${USER}"
DEV_CONTAINER="$1_${USER}"

xhost +local:root 1>/dev/null 2>&1

# docker exec \
#     -u "${DOCKER_USER}" \
#     -e HISTFILE=/zark/.dev_bash_hist \
#     -it "${DEV_CONTAINER}" \
#     /bin/bash

docker exec \
    -u "${DOCKER_USER}" \
    -it "${DEV_CONTAINER}" \
    /bin/bash

xhost -local:root 1>/dev/null 2>&1
