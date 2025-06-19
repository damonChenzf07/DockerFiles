ARG BASE_IMAGE
FROM ${BASE_IMAGE}
MAINTAINER DamonChen

# Disable Prompt During Packages Installation
ARG DEBIAN_FRONTEND=noninteractive

# COPY INSTALL shell script to /opt/install_deps
# user can add extra install dep shell script to this folder
COPY install_deps/ /opt/install_deps/

RUN bash /opt/install_deps/base_tools.sh
RUN bash /opt/install_deps/fastdds_deps.sh

RUN pip3 install conan==1.60.0
RUN apt-get update && apt-get -y install sudo
# all user use sudo donn't password
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

COPY docker_start_user.sh  /opt/scripts/
COPY rcfiles /opt/rcfiles

CMD ["echo", "Welcome to Zdrive.AI"]
