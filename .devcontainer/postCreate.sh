#!/bin/bash

# IMPORTANT: ---------------------------------------------------------- #
# This script is executed on the CONTAINER machine after                #
# creating/recreating the Docker container                              #
# --------------------------------------------------------------------- #

#source /opt/ros/$ROS_DISTRO/setup.bash

mkdir -p /home/ubuntu/ros2_ws/src
sudo chown -R $(whoami) /home/ubuntu/

cd /home/ubuntu/ros2_ws/

rosdep install --from-paths /home/ubuntu/ros2_ws/src --ignore-src --rosdistro humble

#MAKEFLAGS="-j6" colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release