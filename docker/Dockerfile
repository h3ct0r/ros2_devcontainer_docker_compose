# syntax=docker/dockerfile:1
#
# ROS 2 Humble development image for amd64 and arm64, built as stacked targets:
#
#   base     headless dev tools, ssh, Zenoh, Python venv
#   robot    base + robot drivers and navigation stack (deploy this on the robot)
#   desktop  robot + rviz/rqt, lean XFCE over VNC/noVNC, code-server
#   full     desktop + simulation (default)
#
# Build with `docker buildx bake <target>` (see docker-bake.hcl) or through the
# compose files, which select the target with TARGET=<target>.

ARG ROS_BASE_IMAGE=ros:humble-ros-base-jammy@sha256:566b87e6dfc48392189a9c32e594e84060fa9948de93b04e536f39475a1f6963
ARG TARGETARCH

# zenoh-bridge-ros2dds standalone release, pinned per architecture.
# Bumping the version means updating both checksums (GitHub release asset digests).
ARG ZENOH_BRIDGE_VERSION=1.10.1
ARG ZENOH_BRIDGE_SHA256_AMD64=f3ea8ac4345be22716925269bfd3e350e7cb36a8f056e835468c8299341d29b0
ARG ZENOH_BRIDGE_SHA256_ARM64=fdb64d942d4b6beccbe9b1f8a359a01a2fca95a023c27535bf97b233603fad5f

# code-server .deb, pinned the same way
ARG CODE_SERVER_VERSION=4.104.2
ARG CODE_SERVER_SHA256_AMD64=d4c1a0603ab0294be09a1d8ec07f0bda975d1344cb98a2ba1f4ecdd3c68ae15d
ARG CODE_SERVER_SHA256_ARM64=618cb27960e5500a21cc1cd7c9d7b396222c6fe5242e01340312da18cea9945c

FROM scratch AS zenoh-bridge-amd64
ARG ZENOH_BRIDGE_VERSION
ARG ZENOH_BRIDGE_SHA256_AMD64
ADD --checksum=sha256:${ZENOH_BRIDGE_SHA256_AMD64} \
    https://github.com/eclipse-zenoh/zenoh-plugin-ros2dds/releases/download/${ZENOH_BRIDGE_VERSION}/zenoh-plugin-ros2dds-${ZENOH_BRIDGE_VERSION}-x86_64-unknown-linux-gnu-standalone.zip \
    /zenoh-bridge.zip

FROM scratch AS zenoh-bridge-arm64
ARG ZENOH_BRIDGE_VERSION
ARG ZENOH_BRIDGE_SHA256_ARM64
ADD --checksum=sha256:${ZENOH_BRIDGE_SHA256_ARM64} \
    https://github.com/eclipse-zenoh/zenoh-plugin-ros2dds/releases/download/${ZENOH_BRIDGE_VERSION}/zenoh-plugin-ros2dds-${ZENOH_BRIDGE_VERSION}-aarch64-unknown-linux-gnu-standalone.zip \
    /zenoh-bridge.zip

FROM zenoh-bridge-${TARGETARCH} AS zenoh-bridge

FROM scratch AS code-server-amd64
ARG CODE_SERVER_VERSION
ARG CODE_SERVER_SHA256_AMD64
ADD --checksum=sha256:${CODE_SERVER_SHA256_AMD64} \
    https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server_${CODE_SERVER_VERSION}_amd64.deb \
    /code-server.deb

FROM scratch AS code-server-arm64
ARG CODE_SERVER_VERSION
ARG CODE_SERVER_SHA256_ARM64
ADD --checksum=sha256:${CODE_SERVER_SHA256_ARM64} \
    https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server_${CODE_SERVER_VERSION}_arm64.deb \
    /code-server.deb

FROM code-server-${TARGETARCH} AS code-server

# Livox SDK2, built apart so only the installed files reach the robot target
FROM ${ROS_BASE_IMAGE} AS livox-build
ARG MAKE_JOBS=4
COPY third_party_pkgs/livox_sdk_v1.2.5.zip /tmp/livox_sdk.zip
RUN python3 -m zipfile -e /tmp/livox_sdk.zip /tmp/livox_src \
    && cmake -S /tmp/livox_src/Livox-SDK2-1.2.5 -B /tmp/livox_build \
    && make -C /tmp/livox_build -j"${MAKE_JOBS}" \
    && make -C /tmp/livox_build install DESTDIR=/out

# ---------------------------------------------------------------------------
FROM ${ROS_BASE_IMAGE} AS base
ARG TARGETARCH
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    USERNAME=ubuntu \
    ROS_DISTRO=humble \
    ROS_WORKSPACE=/home/ubuntu/ros2_ws \
    COLCON_HOME=/home/ubuntu/.colcon \
    AMENT_CPPCHECK_ALLOW_SLOW_VERSIONS=1

# apt downloads and lists live in BuildKit cache mounts, never in image layers.
# docker-clean stays removed so apt-get completion works inside the container.
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
    && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

RUN --mount=type=cache,id=apt-cache-${TARGETARCH},target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lists-${TARGETARCH},target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    gosu \
    supervisor \
    openssh-server \
    openssh-client \
    bash-completion \
    less \
    nano \
    vim \
    tmux \
    htop \
    tree \
    unzip \
    wget \
    curl \
    ca-certificates \
    gnupg2 \
    lsb-release \
    locales \
    tzdata \
    iputils-ping \
    iproute2 \
    net-tools \
    usbutils \
    build-essential \
    cmake \
    gdb \
    ccache \
    git \
    python3-pip \
    python3-venv \
    python3-argcomplete \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-vcstool \
    libgl1 \
    libgomp1 \
    ros-humble-ament-lint-auto \
    ros-humble-ament-lint-common \
    ros-humble-rmw-cyclonedds-cpp \
    ros-humble-rmw-zenoh-cpp

RUN --mount=type=bind,from=zenoh-bridge,source=/zenoh-bridge.zip,target=/tmp/zenoh-bridge.zip \
    unzip -q -o /tmp/zenoh-bridge.zip zenoh-bridge-ros2dds -d /usr/local/bin \
    && chmod 755 /usr/local/bin/zenoh-bridge-ros2dds

# Dev user with passwordless sudo and access to serial, camera and USB devices
RUN groupadd --gid "${USER_GID}" "${USERNAME}" \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" -m -s /bin/bash -G sudo,dialout,video,plugdev "${USERNAME}" \
    && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}" \
    && chmod 0440 "/etc/sudoers.d/${USERNAME}"

# sshd on port 3022 (started by supervisor); rootless mode allows root logins at startup
RUN mkdir -p /var/run/sshd /var/log/supervisor /etc/supervisor/available \
    && printf 'PermitRootLogin prohibit-password\n' > /etc/ssh/sshd_config.d/ros-dev.conf

COPY configs/supervisord/supervisord.conf configs/supervisord/base.conf /etc/supervisor/conf.d/
COPY configs/supervisord/zenoh-router.conf configs/supervisord/zenoh-bridge.conf /etc/supervisor/available/
COPY --chmod=755 configs/zenoh/zenoh_router_run.sh configs/zenoh/zenoh_bridge_run.sh /usr/local/bin/
COPY configs/bash/ros_dev.bashrc /etc/ros_dev.bashrc
COPY --chmod=755 docker/entrypoint.sh /entrypoint.sh
COPY --chmod=755 configs/devcontainer/onCreate.sh /onCreate.sh
COPY --chmod=755 configs/devcontainer/postCreate.sh /postCreate.sh
COPY --chmod=755 configs/devcontainer/postAttach.sh /postAttach.sh

USER ${USERNAME}

COPY --chown=${USERNAME}:${USERNAME} configs/devcontainer/vscode /home/ubuntu/.vscode
COPY --chown=${USERNAME}:${USERNAME} configs/colcon/defaults.yaml /home/ubuntu/.colcon/defaults.yaml

# Shell setup lives in /etc/ros_dev.bashrc. The default "return if not interactive"
# guard is commented out so non-interactive shells (VS Code tasks, bash -c) get ROS too.
RUN sed -i -e '/case $- in/,+3 s/^/#/g' /home/ubuntu/.bashrc \
    && echo 'source /etc/ros_dev.bashrc' >> /home/ubuntu/.bashrc \
    && touch /home/ubuntu/.Xauthority \
    && mkdir -p "${ROS_WORKSPACE}/src" \
    && rosdep update --rosdistro "${ROS_DISTRO}"

# Python venv that still sees the apt and ROS Python packages (needed by colcon
# and rosidl while the venv is active). Wheels are cached outside the image.
RUN --mount=type=cache,id=pip-${TARGETARCH},target=/tmp/pip-cache,uid=${USER_UID},gid=${USER_GID} \
    python3 -m venv --system-site-packages /home/ubuntu/.py3 \
    && PIP_CACHE_DIR=/tmp/pip-cache /home/ubuntu/.py3/bin/pip install \
    ros2_unbag \
    colcon-top-level-workspace \
    pyserial \
    open3d \
    scipy

WORKDIR ${ROS_WORKSPACE}
ENTRYPOINT ["/entrypoint.sh"]
CMD ["sudo", "-E", "/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]

# ---------------------------------------------------------------------------
FROM base AS robot
ARG TARGETARCH
USER root

RUN --mount=type=cache,id=apt-cache-${TARGETARCH},target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lists-${TARGETARCH},target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-perception \
    ros-humble-librealsense2 \
    ros-humble-realsense2-camera \
    ros-humble-realsense2-camera-msgs \
    ros-humble-realsense2-description \
    ros-humble-dynamixel-sdk \
    ros-humble-dynamixel-sdk-custom-interfaces \
    ros-humble-dynamixel-workbench \
    ros-humble-dynamixel-workbench-msgs \
    ros-humble-dynamixel-workbench-toolbox \
    ros-humble-can-msgs \
    ros-humble-ros2-socketcan \
    can-utils \
    ros-humble-twist-mux \
    ros-humble-teleop-twist-keyboard \
    ros-humble-robot-localization \
    ros-humble-slam-toolbox \
    ros-humble-navigation2 \
    ros-humble-nav2-bringup \
    ros-humble-spatio-temporal-voxel-layer \
    ros-humble-pointcloud-to-laserscan \
    libtbb-dev \
    libopenvdb-dev \
    libcgal-dev \
    libompl-dev \
    libasio-dev \
    libspdlog-dev

COPY --from=livox-build /out/usr/local/ /usr/local/
RUN ldconfig

USER ${USERNAME}

# ---------------------------------------------------------------------------
FROM robot AS desktop
ARG TARGETARCH
USER root

# Lean XFCE (no goodies, no recommends) + TigerVNC + noVNC + rviz/rqt
RUN --mount=type=cache,id=apt-cache-${TARGETARCH},target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lists-${TARGETARCH},target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-desktop \
    ros-humble-rqt-tf-tree \
    ros-humble-nav2-rviz-plugins \
    xfce4-session \
    xfwm4 \
    xfce4-panel \
    xfdesktop4 \
    xfce4-settings \
    thunar \
    greybird-gtk-theme \
    elementary-xfce-icon-theme \
    librsvg2-common \
    dbus-x11 \
    at-spi2-core \
    terminator \
    xterm \
    tigervnc-standalone-server \
    tigervnc-tools \
    websockify \
    mesa-utils \
    libxcb-cursor0 \
    libxcb-shape0 \
    libxcb-icccm4 \
    libxcb-keysyms1 \
    libxkbcommon-x11-0

RUN --mount=type=bind,from=code-server,source=/code-server.deb,target=/tmp/code-server.deb \
    dpkg -i /tmp/code-server.deb

# noVNC fork with clipboard support, pinned to a commit, without its .git
ADD --keep-git-dir=false https://github.com/AtsushiSaito/noVNC.git#24dbf21474ca88928c5a7d63b39fc950240591f7 /usr/lib/novnc
RUN ln -s vnc.html /usr/lib/novnc/index.html \
    && sed -i "s/UI.initSetting('resize', 'off');/UI.initSetting('resize', 'remote');/g" /usr/lib/novnc/app/ui.js

COPY configs/supervisord/desktop.conf /etc/supervisor/conf.d/desktop.conf
COPY --chmod=755 configs/vnc/vnc_run.sh configs/vnc/code_server_run.sh /usr/local/bin/
COPY configs/xfce/xfce4_defaults /usr/share/xfwm4/defaults
COPY configs/xfce/helpers.rc /etc/xdg/xfce4/helpers.rc

# Panel: drop plugins that are not installed, so XFCE does not ask to remove them
RUN sed -i -E '/power-manager-plugin|pulseaudio|notification-plugin|statusnotifier/d' /etc/xdg/xfce4/panel/default.xml

USER ${USERNAME}

COPY --chown=${USERNAME}:${USERNAME} --chmod=755 configs/vnc/xstartup /home/ubuntu/.vnc/xstartup
COPY --chown=${USERNAME}:${USERNAME} configs/xfce/xfce4-screensaver.xml /home/ubuntu/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml
# Seed the panel config so the "first start of the panel" dialog never shows
RUN cp /etc/xdg/xfce4/panel/default.xml /home/ubuntu/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml

# ---------------------------------------------------------------------------
FROM desktop AS full
ARG TARGETARCH
USER root

# Simulation: Gazebo Fortress via ros_gz (packages.ros.org); TurtleBot3 Gazebo
# Classic simulations only exist for amd64.
RUN --mount=type=cache,id=apt-cache-${TARGETARCH},target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lists-${TARGETARCH},target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-desktop-full \
    ros-humble-ros-gz \
    ros-humble-turtlebot3 \
    ros-humble-turtlebot3-msgs \
    $([ "${TARGETARCH}" = amd64 ] && echo ros-humble-turtlebot3-simulations) \
    ffmpeg \
    pcl-tools

USER ${USERNAME}
