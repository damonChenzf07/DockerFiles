#!/usr/bin/env bash

# TOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${TOP_DIR}/scripts/base.bashrc"

unset TOP_DIR

export HOST_ARCH="$(uname -m)"
export HOST_OS="$(uname -s)"

GEO_REGISTRY=
function geo_specific_config() {
    local geo="$1"
    if [[ -z "${geo}" ]]; then
        info "Use default GeoLocation settings"
        return
    fi
    info "Setup geolocation specific configurations for ${geo}"
    if [[ "${geo}" == "cn" ]]; then
        info "GeoLocation settings for Mainland China"
        GEO_REGISTRY="registry.baidubce.com"
    else
        info "GeoLocation settings for ${geo} is not ready, fallback to default"
    fi
}

DOCKER_RUN_CMD="docker run"
USE_GPU_HOST=0

function determine_gpu_use_host() {
    if [[ "${HOST_ARCH}" == "aarch64" ]]; then
        if lsmod | grep -q "^nvgpu"; then
            USE_GPU_HOST=1
        fi
    elif [[ "${HOST_ARCH}" == "x86_64" ]]; then
        if [[ ! -x "$(command -v nvidia-smi)" ]]; then
            warning "No nvidia-smi found. CPU will be used"
        elif [[ -z "$(nvidia-smi)" ]]; then
            warning "No GPU device found. CPU will be used."
        else
            USE_GPU_HOST=1
        fi
    else
        error "Unsupported CPU architecture: ${HOST_ARCH}"
        exit 1
    fi

    local nv_docker_doc="https://github.com/NVIDIA/nvidia-docker/blob/master/README.md"
    if [[ "${USE_GPU_HOST}" -eq 1 ]]; then
        if [[ -x "$(which nvidia-container-toolkit)" ]]; then
            local docker_version
            docker_version="$(docker version --format '{{.Server.Version}}')"
            if dpkg --compare-versions "${docker_version}" "ge" "19.03"; then
                DOCKER_RUN_CMD="docker run --gpus all"
            else
                warning "Please upgrade to docker-ce 19.03+ to access GPU from container."
                USE_GPU_HOST=0
            fi
        elif [[ -x "$(which nvidia-docker)" ]]; then
            DOCKER_RUN_CMD="nvidia-docker run"
        else
            USE_GPU_HOST=0
            warning "Cannot access GPU from within container. Please install latest Docker" \
                "and NVIDIA Container Toolkit as described by: "
            warning "  ${nv_docker_doc}"
        fi
    fi
}

function remove_container_if_exists() {
    local container="$1"
    if docker ps -a --format '{{.Names}}' | grep -q "${container}"; then
        info "Removing existing container: ${container}"
        docker stop "${container}" >/dev/null
        docker rm -v -f "${container}" 2>/dev/null
    fi
}

function postrun_start_user() {
    local container="$1"
    if [ "${USER}" != "root" ]; then
        docker exec -u root "${container}" \
            bash -c '/opt/scripts/docker_start_user.sh'
    fi
}

function stop_all_zark_containers() {
    local force="$1"
    local running_containers
    running_containers="$(docker ps -a --format '{{.Names}}')"
    for container in ${running_containers[*]}; do
        if [[ "${container}" =~ zark_.*_${USER} ]]; then
            info "Now stop container ${container} ..."
            if docker stop "${container}" >/dev/null; then
                if [[ "${force}" == "-f" || "${force}" == "--force" ]]; then
                    docker rm -f "${container}" 2>/dev/null
                fi
                info "Done."
            else
                warning "Failed."
            fi
        fi
    done
}


export -f geo_specific_config
export -f determine_gpu_use_host
export -f stop_all_zark_containers remove_container_if_exists
export USE_GPU_HOST
export DOCKER_RUN_CMD
export GEO_REGISTRY
