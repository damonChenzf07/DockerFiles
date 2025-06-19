#!/usr/bin/env bash

CURR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${CURR_DIR}/docker_base.sh"

CACHE_ROOT_DIR="${DOCKERFILE_ROOT_DIR}/.cache"

DOCKER_REPO="fastddstest"
DEF_DOCKER_IMAGE_VERSION=${DOCKER_REPO}:1.0.0


DEV_IMAGE_VERSION=${DEF_DOCKER_IMAGE_VERSION}

DEV_CONTAINER="j6_tros_${USER}"
DEV_INSIDE="in-dev-docker"

SUPPORTED_ARCHS=(x86_64 aarch64)
TARGET_ARCH="$(uname -m)"

USER_VERSION_OPT=

FAST_MODE="no"

GEOLOC=

USE_LOCAL_IMAGE=1
CUSTOM_DIST=
USER_AGREED="no"

VOLUME_VERSION="latest"
SHM_SIZE="2G"

EXTRA_VOLUME_MAP=""

function show_usage() {
    cat <<EOF
Usage: $0 [options] ...
OPTIONS:
    -h, --help             Display this help and exit.
    -f, --fast             Fast mode without pulling all map volumes.
    -g, --geo <us|cn|none> Pull docker image from geolocation specific registry mirror.
    -l, --local            Use local docker image.
    -t, --tag <TAG>        Specify docker image with tag <TAG> to start.
    -d, --dist             Specify Zark distribution(stable/testing)
    --shm-size <bytes>     Size of /dev/shm . Passed directly to "docker run"
    -v,                    Map extra path into docker
    -n, --name             Specify the docker Name
    stop                   Stop all running zark containers.
EOF
}

function parse_arguments() {
    local custom_version=""
    local custom_dist=""
    local shm_size=""
    local geo=""

    while [ $# -gt 0 ]; do
        local opt="$1"
        shift
        case "${opt}" in
            -t | --tag)
                if [ -n "${custom_version}" ]; then
                    warning "Multiple option ${opt} specified, only the last one will take effect."
                fi
                custom_version="$1"
                shift
                optarg_check_for_opt "${opt}" "${custom_version}"
                ;;

            -d | --dist)
                custom_dist="$1"
                shift
                optarg_check_for_opt "${opt}" "${custom_dist}"
                ;;

            -h | --help)
                show_usage
                exit 1
                ;;

            -f | --fast)
                FAST_MODE="yes"
                ;;

            -g | --geo)
                geo="$1"
                shift
                optarg_check_for_opt "${opt}" "${geo}"
                ;;
            -n | --name)
                DEV_CONTAINER="$1_${USER}"
                shift
                ;;
            -l | --local)
                USE_LOCAL_IMAGE=1
                ;;
            --shm-size)
                shm_size="$1"
                shift
                optarg_check_for_opt "${opt}" "${shm_size}"
                ;;

            -y)
                USER_AGREED="yes"
                ;;
            -v)
                echo "map exter path: $1"
                EXTRA_VOLUME_MAP="-v $1:$1 ${EXTRA_VOLUME_MAP}"
                shift
                ;;
            stop)
                info "Now, stop all zark containers created by ${USER} ..."
                stop_all_zark_containers "-f"
                exit 0
                ;;
            *)
                warning "Unknown option: ${opt}"
                exit 2
                ;;
        esac
    done # End while loop

    [[ -n "${geo}" ]] && GEOLOC="${geo}"
    [[ -n "${custom_version}" ]] && USER_VERSION_OPT="${custom_version}"
    [[ -n "${custom_dist}" ]] && CUSTOM_DIST="${custom_dist}"
    [[ -n "${shm_size}" ]] && SHM_SIZE="${shm_size}"
}

function determine_dev_image() {

    # TODO： add version support
    DEV_IMAGE="$DEV_IMAGE_VERSION"
}

function check_host_environment() {
    if [[ "${HOST_OS}" != "Linux" ]]; then
        warning "Running zark dev container on ${HOST_OS} is UNTESTED, exiting..."
        exit 1
    fi
}

function check_target_arch() {
    local arch="${TARGET_ARCH}"
    for ent in "${SUPPORTED_ARCHS[@]}"; do
        if [[ "${ent}" == "${TARGET_ARCH}" ]]; then
            return 0
        fi
    done
    error "Unsupported target architecture: ${TARGET_ARCH}."
    exit 1
}

function setup_devices_and_mount_local_volumes() {
    local __retval="$1"

    [ -d "${CACHE_ROOT_DIR}" ] || mkdir -p "${CACHE_ROOT_DIR}"

    source "${DOCKERFILE_ROOT_DIR}/scripts/zark_base.sh"
    # setup_device

    local volumes="-v $DOCKERFILE_ROOT_DIR:/zark"

    local os_release="$(lsb_release -rs)"
    case "${os_release}" in
        16.04)
            warning "[Deprecated] Support for Ubuntu 16.04 will be removed" \
                "in the near future. Please upgrade to ubuntu 18.04+."
            volumes="${volumes} -v /dev:/dev"
            ;;
        18.04 | 20.04 | *)
            volumes="${volumes} -v /dev:/dev"
            ;;
    esac
    # local tegra_dir="/usr/lib/aarch64-linux-gnu/tegra"
    # if [[ "${TARGET_ARCH}" == "aarch64" && -d "${tegra_dir}" ]]; then
    #    volumes="${volumes} -v ${tegra_dir}:${tegra_dir}:ro"
    # fi
    volumes="${volumes} -v /media:/media \
                        -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
                        -v /etc/localtime:/etc/localtime:ro \
                        -v /usr/src:/usr/src \
                        -v /lib/modules:/lib/modules"
    volumes="$(tr -s " " <<<"${volumes}")"
    eval "${__retval}='${volumes}'"
}

function docker_pull() {
    local img="$1"
    if [[ "${USE_LOCAL_IMAGE}" -gt 0 ]]; then
        if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${img}"; then
            info "Local image ${img} found and will be used."
            return 0
        fi
        warning "Image ${img} not found locally although local mode enabled. Trying to pull from remote registry."
    fi
    if [[ -n "${GEO_REGISTRY}" ]]; then
        img="${GEO_REGISTRY}/${img}"
    fi

    info "Start pulling docker image ${img} ..."
    if ! docker pull "${img}"; then
        error "Failed to pull docker image : ${img}"
        exit 1
    fi
}

function docker_restart_volume() {
    local volume="$1"
    local image="$2"
    local path="$3"
    info "Create volume ${volume} from image: ${image}"
    docker_pull "${image}"
    docker volume rm "${volume}" >/dev/null 2>&1
    docker run -v "${volume}":"${path}" --rm "${image}" true
}

function main() {
    check_host_environment
    check_target_arch

    parse_arguments "$@"

    determine_dev_image "${USER_VERSION_OPT}"
    geo_specific_config "${GEOLOC}"

    if [[ "${USE_LOCAL_IMAGE}" -gt 0 ]]; then
        info "Start docker container based on local image : ${DEV_IMAGE}"
    fi

    if ! docker_pull "${DEV_IMAGE}"; then
        error "Failed to pull docker image ${DEV_IMAGE}"
        exit 1
    fi

    info "Remove existing Zark Development container ..."
    remove_container_if_exists ${DEV_CONTAINER}

    info "Determine whether host GPU is available ..."
    determine_gpu_use_host
    info "USE_GPU_HOST: ${USE_GPU_HOST}"

    # local local_volumes=
    # setup_devices_and_mount_local_volumes local_volumes

    info "Starting Docker container \"${DEV_CONTAINER}\" ..."

    local local_host="$(hostname)"
    local display="${DISPLAY:-:0}"
    local user="${USER}"
    local uid="$(id -u)"
    local group="$(id -g -n)"
    local gid="$(id -g)"

    set -x

    ${DOCKER_RUN_CMD} -itd \
        --privileged \
        --name "${DEV_CONTAINER}" \
        -e DISPLAY="${display}" \
        -e DOCKER_USER="${user}" \
        -e USER="${user}" \
        -e DOCKER_USER_ID="${uid}" \
        -e DOCKER_GRP="${group}" \
        -e DOCKER_GRP_ID="${gid}" \
        -e DOCKER_IMG="${DEV_IMAGE}" \
        -e USE_GPU_HOST="${USE_GPU_HOST}" \
        -e NVIDIA_VISIBLE_DEVICES=all \
        -e NVIDIA_DRIVER_CAPABILITIES=compute,video,graphics,utility \
        -e TENSORRT_VERSION=8.4.3 \
        --net host \
        -v ${DOCKERFILE_ROOT_DIR}:${DOCKERFILE_ROOT_DIR} \
        -w ${DOCKERFILE_ROOT_DIR} \
        --add-host "${DEV_INSIDE}:127.0.0.1" \
        --add-host "${local_host}:127.0.0.1" \
        --hostname "${DEV_INSIDE}" \
        --shm-size "${SHM_SIZE}" \
        --pid=host \
        -v /dev/null:/dev/raw1394 \
        ${EXTRA_VOLUME_MAP} \
        "${DEV_IMAGE}" \
        /bin/bash

    if [ $? -ne 0 ]; then
        error "Failed to start docker container \"${DEV_CONTAINER}\" based on image: ${DEV_IMAGE}"
        exit 1
    fi
    set +x

    postrun_start_user "${DEV_CONTAINER}"

    ok "Congratulations! You have successfully finished setting up Zark Dev Environment."
    ok "To login into the newly created ${DEV_CONTAINER} container, please run the following command:"
    ok "  bash scripts/docker/dev_into.sh"
    ok "Enjoy!"
}

main "$@"