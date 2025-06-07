FROM ubuntu:22.04
MAINTAINER DamonChen
# Disable Prompt During Packages Installation
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y python2-minimal python3 python3-pip
RUN apt-get update && apt-get install -y cmake make gcc g++ git net-tools libtool autoconf
RUN apt-get update && apt-get install -y wget curl
RUN apt-get update && apt-get install -y vim
RUN pip3 install conan==1.60.0
RUN apt-get update && apt-get -y install sudo
# all user use sudo donn't password
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

COPY docker_start_user.sh  /opt/scripts/
COPY rcfiles /opt/rcfiles

CMD ["echo", "Welcome to Zdrive.AI"]
