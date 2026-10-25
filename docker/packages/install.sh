#!/bin/bash
# Installs the apt packages of one image stage (base, robot, desktop, full):
# <stage>.txt, then <stage>.<distro>.txt and <stage>.<distro>.<arch>.txt when present.
# One package per line, "#" starts a comment, "@name" means ros-<distro>-name.
set -euo pipefail

stage=$1
dir=$(dirname "$0")
arch=$(dpkg --print-architecture)
packages=()
for list in "$dir/$stage.txt" "$dir/$stage.$ROS_DISTRO.txt" "$dir/$stage.$ROS_DISTRO.$arch.txt"; do
    [ -f "$list" ] || continue
    while read -r name _; do
        name=${name%%#*}
        if [ -n "$name" ]; then packages+=("${name/#@/ros-$ROS_DISTRO-}"); fi
    done < "$list"
done

apt-get update
apt-get install -y --no-install-recommends "${packages[@]}"
