# syntax=docker/dockerfile:1
#
# ROS 2 development image (Humble, Jazzy or Lyrical) for amd64 and arm64, built as
# stacked targets:
#
#   base     headless dev tools, ssh, Zenoh, Python venv
#   robot    base + robot drivers and navigation stack (deploy this on the robot)
#   desktop  robot + rviz/rqt, lean XFCE over VNC/noVNC, code-server
#   full     desktop + simulation
#
# ROS_DISTRO picks the distro; apt packages per stage live in docker/packages/.
# Build with `docker buildx bake <distro>-<target>` (see docker-bake.hcl, which also
# pins each base image by digest) or through compose / dev.sh.

ARG ROS_DISTRO=jazzy
ARG BASE_IMAGE=ros:${ROS_DISTRO}-ros-base
ARG TARGETARCH

# zenoh-bridge-ros2dds standalone release, pinned per architecture.
# Bumping the version means updating both checksums (GitHub release asset digests).
# 1.10.x amd64 builds need glibc 2.38 (Ubuntu 22.04 has 2.35): check a new version with
# `objdump -T zenoh-bridge-ros2dds | grep GLIBC_` before bumping.
ARG ZENOH_BRIDGE_VERSION=1.9.0
ARG ZENOH_BRIDGE_SHA256_AMD64=91aa0d569fffd57e7ebb1a591b97789891c543b1ff0a1658413ce6cbbba34a9e
ARG ZENOH_BRIDGE_SHA256_ARM64=e3eb1fd4459e4b877653419b1c25eaf92418d70fe53ee767eca005f1a19443dc

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
FROM ${BASE_IMAGE} AS livox-build
ARG MAKE_JOBS=4
COPY third_party_pkgs/livox_sdk_v1.2.5.zip /tmp/livox_sdk.zip
# GCC 13+ (Noble, Resolute) no longer pulls in <cstdint> transitively, and CMake 4
# (Resolute) refuses the SDK's old cmake_minimum_required without a policy floor
RUN python3 -m zipfile -e /tmp/livox_sdk.zip /tmp/livox_src \
    && cmake -S /tmp/livox_src/Livox-SDK2-1.2.5 -B /tmp/livox_build \
        -DCMAKE_CXX_FLAGS="-include cstdint" -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    && make -C /tmp/livox_build -j"${MAKE_JOBS}" \
    && make -C /tmp/livox_build install DESTDIR=/out

# ---------------------------------------------------------------------------
FROM ${BASE_IMAGE} AS base
ARG TARGETARCH
ARG ROS_DISTRO
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    USERNAME=ubuntu \
    ROS_DISTRO=${ROS_DISTRO} \
    ROS_WORKSPACE=/home/ubuntu/ros2_ws \
    COLCON_HOME=/home/ubuntu/.colcon \
    AMENT_CPPCHECK_ALLOW_SLOW_VERSIONS=1

# apt downloads and lists live in BuildKit cache mounts, never in image layers.
# docker-clean stays removed so apt-get completion works inside the container.
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
    && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

RUN --mount=type=cache,id=apt-cache-${ROS_DISTRO}-${TARGETARCH},target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lists-${ROS_DISTRO}-${TARGETARCH},target=/var/lib/apt/lists,sharing=locked \
    --mount=type=bind,source=docker/packages,target=/tmp/packages \
    /tmp/packages/install.sh base

RUN --mount=type=bind,from=zenoh-bridge,source=/zenoh-bridge.zip,target=/tmp/zenoh-bridge.zip \
    unzip -q -o /tmp/zenoh-bridge.zip zenoh-bridge-ros2dds -d /usr/local/bin \
    && chmod 755 /usr/local/bin/zenoh-bridge-ros2dds

# Dev user with passwordless sudo and access to serial, camera and USB devices.
# Ubuntu 24.04+ base images already have "ubuntu" (uid 1000): reuse it, adjusting ids.
RUN if id -u "${USERNAME}" >/dev/null 2>&1; then \
        groupmod --gid "${USER_GID}" "${USERNAME}" \
        && usermod --uid "${USER_UID}" --gid "${USER_GID}" --shell /bin/bash "${USERNAME}"; \
    else \
        groupadd --gid "${USER_GID}" "${USERNAME}" \
        && useradd --uid "${USER_UID}" --gid "${USER_GID}" -m -s /bin/bash "${USERNAME}"; \
    fi \
    && usermod -aG sudo,dialout,video,plugdev "${USERNAME}" \
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
    && mkdir -p "${ROS_WORKSPACE}/src" "${ROS_WORKSPACE}/build" "${ROS_WORKSPACE}/install" "${ROS_WORKSPACE}/log" \
        /home/ubuntu/.cache/ccache \
    && rosdep update --rosdistro "${ROS_DISTRO}"

# Python venv that still sees the apt and ROS Python packages (needed by colcon
# and rosidl while the venv is active). numpy stays on the system's major version:
# ROS's compiled extensions (cv_bridge, ...) break across numpy 1 / 2. Wheels are
# cached outside the image.
RUN --mount=type=cache,id=pip-${ROS_DISTRO}-${TARGETARCH},target=/tmp/pip-cache,uid=${USER_UID},gid=${USER_GID} \
    --mount=type=bind,source=docker/python,target=/tmp/python \
    python3 -m venv --system-site-packages /home/ubuntu/.py3 \
    && numpy_major=$(python3 -c 'import numpy; print(numpy.__version__.split(".")[0])') \
    && echo "numpy>=${numpy_major},<$((numpy_major + 1))" > /tmp/numpy-constraint.txt \
    && PIP_CACHE_DIR=/tmp/pip-cache PIP_CONSTRAINT=/tmp/numpy-constraint.txt /home/ubuntu/.py3/bin/pip install \
        -r /tmp/python/requirements.txt -r "/tmp/python/requirements.${ROS_DISTRO}.txt" \
    && rm /tmp/numpy-constraint.txt

WORKDIR ${ROS_WORKSPACE}
ENTRYPOINT ["/entrypoint.sh"]
CMD ["sudo", "-E", "/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]

# ---------------------------------------------------------------------------
FROM base AS robot
ARG TARGETARCH
ARG ROS_DISTRO
USER root

RUN --mount=type=cache,id=apt-cache-${ROS_DISTRO}-${TARGETARCH},target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lists-${ROS_DISTRO}-${TARGETARCH},target=/var/lib/apt/lists,sharing=locked \
    --mount=type=bind,source=docker/packages,target=/tmp/packages \
    /tmp/packages/install.sh robot

COPY --from=livox-build /out/usr/local/ /usr/local/
RUN ldconfig

USER ${USERNAME}

# ---------------------------------------------------------------------------
FROM robot AS desktop
ARG TARGETARCH
ARG ROS_DISTRO
USER root

# Lean XFCE (no goodies, no recommends) + TigerVNC + noVNC + rviz/rqt
RUN --mount=type=cache,id=apt-cache-${ROS_DISTRO}-${TARGETARCH},target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lists-${ROS_DISTRO}-${TARGETARCH},target=/var/lib/apt/lists,sharing=locked \
    --mount=type=bind,source=docker/packages,target=/tmp/packages \
    /tmp/packages/install.sh desktop

RUN --mount=type=bind,from=code-server,source=/code-server.deb,target=/tmp/code-server.deb \
    dpkg -i /tmp/code-server.deb

# noVNC fork with clipboard support, pinned to a commit, without its .git
ADD --keep-git-dir=false https://github.com/AtsushiSaito/noVNC.git#24dbf21474ca88928c5a7d63b39fc950240591f7 /usr/lib/novnc
RUN ln -s vnc.html /usr/lib/novnc/index.html \
    && sed -i "s/UI.initSetting('resize', 'off');/UI.initSetting('resize', 'remote');/g" /usr/lib/novnc/app/ui.js

COPY configs/supervisord/desktop.conf /etc/supervisor/conf.d/desktop.conf
COPY --chmod=755 configs/vnc/vnc_run.sh configs/vnc/code_server_run.sh configs/nvidia/prime-run /usr/local/bin/
# vnc_run.sh copies it into ~/.vnc or ~/.config/tigervnc, depending on the TigerVNC version
COPY --chmod=755 configs/vnc/xstartup /usr/local/share/ros_dev/vnc_xstartup
COPY configs/xfce/xfce4_defaults /usr/share/xfwm4/defaults
COPY configs/xfce/helpers.rc /etc/xdg/xfce4/helpers.rc

# Panel: drop plugins and launchers that are not installed, so XFCE does not ask to
# remove them. Edited as XML: deleting lines breaks the nesting and loses the dock.
RUN python3 - <<'EOF'
import os
import shutil
import xml.etree.ElementTree as ET


def launchable(item):
    # Without a browser the web browser launcher only opens an empty "preferred
    # application" chooser
    if item == "xfce4-web-browser.desktop" and not shutil.which("x-www-browser"):
        return False
    return os.path.exists(f"/usr/share/applications/{item}")


path = "/etc/xdg/xfce4/panel/default.xml"
tree = ET.parse(path)
plugins = tree.find("property[@name='plugins']")
dropped = set()
for plugin in list(plugins):
    items = [v.get("value") for v in plugin.findall("property[@name='items']/value")]
    if not os.path.exists(f"/usr/share/xfce4/panel/plugins/{plugin.get('value')}.desktop") or (
        items and not any(launchable(i) for i in items)
    ):
        plugins.remove(plugin)
        dropped.add(plugin.get("name").removeprefix("plugin-"))
for ids in tree.iterfind("property[@name='panels']/property/property[@name='plugin-ids']"):
    for value in list(ids):
        if value.get("value") in dropped:
            ids.remove(value)
tree.write(path, encoding="UTF-8", xml_declaration=True)
EOF

USER ${USERNAME}

COPY --chown=${USERNAME}:${USERNAME} configs/xfce/xfce4-screensaver.xml /home/ubuntu/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml
# Seed the panel config so the "first start of the panel" dialog never shows
RUN cp /etc/xdg/xfce4/panel/default.xml /home/ubuntu/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml

# xfdesktop 4.20+ (Lyrical) sets no wallpaper for the VNC screen (VNC-0) and shows black;
# older versions fall back to their default wallpaper on their own
RUN if dpkg --compare-versions "$(dpkg-query -W -f='${Version}' xfdesktop4)" ge 4.20; then \
        workspaces=""; \
        for n in 0 1 2 3; do \
            workspaces="${workspaces}<property name=\"workspace${n}\" type=\"empty\"><property name=\"image-style\" type=\"int\" value=\"5\"/><property name=\"last-image\" type=\"string\" value=\"/usr/share/backgrounds/xfce/xfce-shapes.svg\"/></property>"; \
        done; \
        printf '<?xml version="1.0" encoding="UTF-8"?>\n<channel name="xfce4-desktop" version="1.0"><property name="backdrop" type="empty"><property name="screen0" type="empty"><property name="monitorVNC-0" type="empty">%s</property></property></property></channel>\n' "${workspaces}" \
            > /home/ubuntu/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml; \
    fi

# ---------------------------------------------------------------------------
FROM desktop AS full
ARG TARGETARCH
ARG ROS_DISTRO
USER root

# Simulation: Gazebo through ros_gz (Fortress, Harmonic or Jetty, from packages.ros.org)
RUN --mount=type=cache,id=apt-cache-${ROS_DISTRO}-${TARGETARCH},target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lists-${ROS_DISTRO}-${TARGETARCH},target=/var/lib/apt/lists,sharing=locked \
    --mount=type=bind,source=docker/packages,target=/tmp/packages \
    /tmp/packages/install.sh full

USER ${USERNAME}
