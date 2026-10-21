#!/bin/bash
# DDS <-> Zenoh bridge (ROS_TRANSPORT=bridge). Listens on tcp/7447; ZENOH_CONNECT is a
# comma-separated list of remote bridges/routers, ZENOH_NAMESPACE prefixes every
# topic, service and action leaving this host (e.g. /bot1).
args=(--domain "${ROS_DOMAIN_ID:-0}")

IFS=',' read -ra endpoints <<< "${ZENOH_CONNECT// /}"
for endpoint in "${endpoints[@]}"; do
    args+=(--connect "${endpoint}")
done
if [ -n "${ZENOH_NAMESPACE}" ]; then
    args+=(--namespace "${ZENOH_NAMESPACE}")
fi
if [ "${ROS_LOCALHOST_ONLY:-0}" = 1 ]; then
    args+=(--ros-localhost-only)
fi

exec zenoh-bridge-ros2dds "${args[@]}"
