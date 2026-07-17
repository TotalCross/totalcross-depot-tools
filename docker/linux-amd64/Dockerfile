# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
FROM ubuntu:bionic

MAINTAINER Allan César "acmlira@gmail.com"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        gnupg \
        wget && \
    wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc | apt-key add - && \
    echo 'deb https://apt.kitware.com/ubuntu/ bionic main' > /etc/apt/sources.list.d/kitware.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ccache \
        cmake \
        curl \
        git \
        build-essential \
        libsdl2-dev \
        libfontconfig1-dev \
        ninja-build \
        rsync && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
ENV BUILD_FOLDER /build

WORKDIR ${BUILD_FOLDER}
