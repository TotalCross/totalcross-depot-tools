FROM arm64v8/ubuntu:bionic
# 

# TotalCross
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
        ninja-build \
        build-essential \
        libfontconfig1-dev \
# SDL2 
        libtool \
        libasound2-dev \
        libpulse-dev \
        libaudio-dev \
        libx11-dev \
        libxext-dev \
        libxrandr-dev \
        libxcursor-dev \
        libxi-dev \
        libxinerama-dev \
        libxxf86vm-dev \
        libxss-dev \
        libgl1-mesa-dev \
# Lastly available on Xenial, deprecated for Bionic
#       libesd0-dev \
        libdbus-1-dev \
        libudev-dev \
        libgles2-mesa-dev \
        libegl1-mesa-dev \
        libibus-1.0-dev \
        fcitx-libs-dev \
        libsamplerate0-dev \
        libsndio-dev \
# Wayland
        libwayland-dev \
        libxkbcommon-dev \
        wayland-protocols \
        rsync; \
    apt-get install -y libglvnd-dev || apt-get -f install; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/SDL-mirror/SDL.git \
        --branch=release-2.0.10 \
        --single-branch \
        --depth=1 \
    && cd SDL \
    && mkdir build; cd build \
    && CFLAGS="-O3 -fPIC" \
    cmake ../ -G Ninja \
        -DSDL_SHARED=0 \
        -DSDL_AUDIO=0 \
        -DVIDEO_VIVANTE=ON \
        -DVIDEO_WAYLAND=ON \
        -DWAYLAND_SHARED=ON; \
    ninja install

# clean up
RUN rm -r /SDL  

ENV BUILD_FOLDER /build

WORKDIR ${BUILD_FOLDER}
