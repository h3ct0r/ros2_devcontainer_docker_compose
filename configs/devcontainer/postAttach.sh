#!/bin/bash

# IMPORTANT: ---------------------------------------------------------- #
# This script is executed in the CONTAINER every time VS Code attaches  #
# to it (postAttachCommand).                                            #
# --------------------------------------------------------------------- #

# Nothing to do yet: a hook for your own setup. Stale VNC lock and socket
# files are removed by /usr/local/bin/vnc_run.sh before the VNC server starts.

# touch postattach_script_executed_$(date '+%Y-%m-%d_%H-%M-%S')
