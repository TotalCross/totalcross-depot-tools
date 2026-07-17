# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
FROM ubuntu:bionic

MAINTAINER Allan César "acmlira@gmail.com"

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    apt-transport-https ca-certificates gnupg wget && \
    wget -qO- https://apt.kitware.com/keys/kitware-archive-latest.asc | apt-key add - && \
    echo 'deb https://apt.kitware.com/ubuntu/ bionic main' > /etc/apt/sources.list.d/kitware.list && \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential ca-certificates ccache cmake curl git ninja-build rsync && \
    rm -rf /var/lib/apt/lists/*
ENV BUILD_FOLDER /build

WORKDIR ${BUILD_FOLDER}
