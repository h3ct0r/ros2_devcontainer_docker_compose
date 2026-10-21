#!/bin/bash -e
#
# Container entrypoint:
#   1. picks the dev user (root under rootless Docker/Podman, ubuntu otherwise)
#   2. applies runtime settings: passwords and the ROS middleware (ROS_TRANSPORT)
#   3. runs the command with ROS sourced, from the workspace

ROS_DISTRO=${ROS_DISTRO:-humble}
ROS_WORKSPACE=${ROS_WORKSPACE:-/home/ubuntu/ros2_ws}
DEV_HOME=/home/ubuntu

# Privileged steps: direct when started as root, through sudo when started as ubuntu
as_root() {
    if [ "$(id -u)" = 0 ]; then "$@"; else sudo "$@"; fi
}

# Rootless Docker/Podman: the container's root is the host user and every other
# uid maps to a subordinate host uid, so files "ubuntu" writes to bind mounts would
# not belong to the host user. Detected as a user namespace plus a workspace owned
# by container root. ROOTLESS=1/0 forces the result.
is_rootless() {
    case "${ROOTLESS:-auto}" in
        1 | true | yes) return 0 ;;
        0 | false | no) return 1 ;;
    esac
    if awk '$1 == 0 && $2 == 0 && $3 == 4294967295 { found = 1 } END { exit !found }' /proc/self/uid_map; then
        return 1
    fi
    [ "$(stat -c %u "$ROS_WORKSPACE" 2>/dev/null)" = 0 ]
}

if is_rootless; then
    DEV_USER=root
    # root shares ubuntu's home: bashrc, venv, VS Code and VNC settings
    as_root sed -i -E 's#^(root:[^:]*:0:0:[^:]*):[^:]*:#\1:/home/ubuntu:#' /etc/passwd
    printf 'PermitRootLogin yes\nStrictModes no\n' | as_root tee /etc/ssh/sshd_config.d/ros-dev.conf >/dev/null
    if [ "$(id -u)" != 0 ]; then
        echo "entrypoint: rootless mode detected; run the container with 'user: root' so shells and" \
            "'docker exec' write files as your host user" >&2
    fi
else
    DEV_USER=ubuntu
fi
export DEV_USER DEV_HOME

echo "${DEV_USER}:${DEV_PASSWORD:-ubuntu}" | as_root chpasswd

# ROS middleware. The Zenoh router and the DDS bridge both listen on TCP 7447,
# so only one of them runs.
as_root rm -f /etc/supervisor/conf.d/zenoh-router.conf /etc/supervisor/conf.d/zenoh-bridge.conf
case "${ROS_TRANSPORT:=dds}" in
    dds) ;;
    zenoh)
        export RMW_IMPLEMENTATION=rmw_zenoh_cpp
        as_root cp /etc/supervisor/available/zenoh-router.conf /etc/supervisor/conf.d/
        ;;
    bridge)
        export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
        as_root cp /etc/supervisor/available/zenoh-bridge.conf /etc/supervisor/conf.d/
        ;;
    *)
        echo "entrypoint: unknown ROS_TRANSPORT='${ROS_TRANSPORT}' (use dds, zenoh or bridge)" >&2
        exit 1
        ;;
esac
export ROS_TRANSPORT

# SSH sessions do not inherit the container environment: keep the resolved
# values in a file that /etc/ros_dev.bashrc loads.
{
    for var in ROS_DISTRO ROS_WORKSPACE COLCON_HOME ROS_DOMAIN_ID ROS_LOCALHOST_ONLY RMW_IMPLEMENTATION \
        ROS_TRANSPORT ZENOH_CONNECT ZENOH_NAMESPACE ZENOH_CONFIG_OVERRIDE TZ; do
        if [ -n "${!var}" ]; then printf '%s=%q\n' "$var" "${!var}"; fi
    done
} | as_root tee /etc/ros_dev.env >/dev/null

source "/opt/ros/${ROS_DISTRO}/setup.bash"
if [ -f "${ROS_WORKSPACE}/install/setup.bash" ]; then
    source "${ROS_WORKSPACE}/install/setup.bash" || echo "entrypoint: could not source the workspace overlay" >&2
fi
cd "${ROS_WORKSPACE}" 2>/dev/null || true

# Started as root with ubuntu as dev user: drop privileges (the default command
# gets root back through sudo, as when the container starts as ubuntu).
if [ "$(id -u)" = 0 ] && [ "${DEV_USER}" != root ]; then
    exec gosu "${DEV_USER}" "$@"
fi
exec "$@"
