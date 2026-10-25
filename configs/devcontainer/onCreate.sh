#!/bin/bash

# IMPORTANT: ---------------------------------------------------------- #
# This script is executed on the CONTAINER machine.                     #
# This command is the first of three (along with updateContentCommand   #
# and postCreateCommand) that finalizes container setup when a dev      #
# container is created. It and subsequent commands execute inside the   #
# container immediately after it has started for the first time.        #
# --------------------------------------------------------------------- #

# touch oncreate_script_executed_$(date '+%Y-%m-%d_%H-%M-%S')