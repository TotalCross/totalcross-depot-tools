FROM ubuntu:bionic

MAINTAINER Allan César "acmlira@gmail.com"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        cmake \
        curl \
        git \
        gnupg \
        libsdl2-dev \
        libfontconfig1-dev \
        ninja-build \
        rsync \
        wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
ENV BUILD_FOLDER /build

WORKDIR ${BUILD_FOLDER}
