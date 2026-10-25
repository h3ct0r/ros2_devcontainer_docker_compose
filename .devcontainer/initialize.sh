#!/usr/bin/env bash
# Runs on the host before VS Code starts a devcontainer (initializeCommand). Writes the
# merged compose file for the distro given as $1, with the same selection as ./dev.sh:
# .env, the environment, then auto-detection (see ./dev.sh status).
set -euo pipefail
cd "$(dirname "$0")/.."
exec ./dev.sh configure --distro "$1" --output ".devcontainer/.generated/$1/compose.yaml"
