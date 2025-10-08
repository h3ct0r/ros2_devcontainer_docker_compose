#!/bin/bash -i

# IMPORTANT: ---------------------------------------------------------- #
# This script is executed on the HOST machine before calling any        #
# Docker/docker-compose commands and on every recreation                #
# --------------------------------------------------------------------- #

# The `|| true` command allows to ignore any errors (MacOS does not have native X server, for example)
xhost + || true
echo "[initializeCommand] xhost +"

# Create automatic environment variables such as `localWorkspaceFolder` 
# used for the docker compose mount configuration

ENV_FILEPATH=".env"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

echo "[initializeCommand] ENV_FILEPATH=$ENV_FILEPATH"
echo "[initializeCommand] localWorkspaceFolder=$SCRIPT_DIR"

# Create .devcontainer/.env if it does not already exists
if [ ! -e "$ENV_FILEPATH" ]; then
    echo "[initializeCommand] '$ENV_FILEPATH' does not exist, creating it"
    touch $ENV_FILEPATH
fi 

source $ENV_FILEPATH

# Set localWorkspaceFolder environment variable if not already set
if [ -z "${localWorkspaceFolder}" ]; then 
    echo -e "\nlocalWorkspaceFolder=$SCRIPT_DIR/../\n" >> $ENV_FILEPATH
fi