#!/bin/bash

# set -o errexit -o nounset -o pipefail


apt-get update
apt-get install -y \
    libasio-dev \
    libtinyxml2-dev \
    libssl-dev \
    libp11-dev \
    softhsm2 \
    libengine-pkcs11-openssl \
    doxygen \
    graphviz 

# install XML schema library for Python
pip install xmlschema

#install colcon and vcstool
pip3 install -U colcon-common-extensions vcstool