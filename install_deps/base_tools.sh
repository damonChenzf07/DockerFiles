#!/bin/bash

# set -o errexit -o nounset -o pipefail


apt-get update

apt-get install -y \
    openjdk-8-jdk \
    python2-minimal \
    python3 \
    python3-pip \
    cmake \
    make \
    gcc \
    g++ \
    git \
    net-tools \
    libtool \
    autoconf \
    wget \
    curl \
    vim \
    unzip


