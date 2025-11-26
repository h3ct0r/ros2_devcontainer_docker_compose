#!/bin/bash

# IMPORTANT: ---------------------------------------------------------- #
# This script is executed on the HOST machine after attaching to the    #
# Docker container                                                      #
# --------------------------------------------------------------------- #

# touch postattach_script_executed_$(date '+%Y-%m-%d_%H-%M-%S')

find /tmp/.X11-unix/ -maxdepth 1 -type f -name '*' -delete
rm /tmp/.X11-unix/X2