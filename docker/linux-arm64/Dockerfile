# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
FROM arm64v8/ubuntu:bionic
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential ca-certificates ccache cmake curl git ninja-build rsync && \
    rm -rf /var/lib/apt/lists/*

ENV BUILD_FOLDER /build

WORKDIR ${BUILD_FOLDER}
