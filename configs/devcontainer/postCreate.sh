#!/bin/bash

# IMPORTANT: ---------------------------------------------------------- #
# This script is executed on the CONTAINER machine after                #
# creating/recreating the Docker container                              #
# --------------------------------------------------------------------- #

#source /opt/ros/$ROS_DISTRO/setup.bash

mkdir -p /home/ubuntu/ros2_ws/src
# Only the workspace: a recursive chown of the home would copy the whole venv
# into the container layer
sudo chown -R "$(id -u):$(id -g)" /home/ubuntu/ros2_ws

cd /home/ubuntu/ros2_ws/

sudo apt-get update
rosdep install --from-paths /home/ubuntu/ros2_ws/src --ignore-src --rosdistro humble -y

# symlink-install, Release and ccache come from ~/.colcon/defaults.yaml
MAKEFLAGS="-j6" colcon build