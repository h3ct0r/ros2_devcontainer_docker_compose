#!/bin/bash
# rmw_zenoh router (ROS_TRANSPORT=zenoh). Listens on tcp/7447; ZENOH_CONNECT is a
# comma-separated list of other routers to join, e.g. tcp/192.168.1.50:7447.
source "/opt/ros/${ROS_DISTRO}/setup.bash"

if [ -n "${ZENOH_CONNECT}" ]; then
    IFS=',' read -ra endpoints <<< "${ZENOH_CONNECT// /}"
    list=$(printf '"%s",' "${endpoints[@]}")
    export ZENOH_CONFIG_OVERRIDE="connect/endpoints=[${list%,}]${ZENOH_CONFIG_OVERRIDE:+;${ZENOH_CONFIG_OVERRIDE}}"
fi

exec ros2 run rmw_zenoh_cpp rmw_zenohd
