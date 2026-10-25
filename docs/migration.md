# Migration

This repo replaced two earlier setups:
- [h3ct0r/ros2_humble_docker_vnc_dev](https://github.com/h3ct0r/ros2_humble_docker_vnc_dev), which built the Humble image. It's archived now, and its history lives here.
- The per-host compose files and the single devcontainer that this repo had before.

## Commands

| Before | Now |
|---|---|
| `docker compose -f compose_linux.yaml up -d` | `./dev.sh up` |
| `compose_linux_nvidia.yaml` | `./dev.sh up`; the GPU is detected |
| `compose_rootless*.yaml` | `./dev.sh up`; rootless Docker is detected |
| `compose_macos.yaml` | `./dev.sh up` |
| `compose_linux_arm.yaml` | `./dev.sh up`; images are native arm64 |
| `TARGET=robot docker compose -f compose_linux.yaml up -d` | `./dev.sh up --target robot` |
| one `.devcontainer/devcontainer.json` | `.devcontainer/{humble,jazzy,lyrical}` |
| `ROS_LOCALHOST_ONLY=1` | `ROS_DISCOVERY=localhost` (the old variable is still accepted) |

## Images

| Before | Now |
|---|---|
| `h3ct0rdcc/ros2_humble_development:full` | `h3ct0rdcc/ros2_dev:humble-full` |
| `h3ct0rdcc/ros2_humble_development:<target>` | `h3ct0rdcc/ros2_dev:humble-<target>` |
| `h3ct0rdcc/ros2_humble_development:amd64` / `:arm64` | `h3ct0rdcc/ros2_dev:humble-full` (multi-arch) |

The old tags keep receiving updates until Humble's end of life (May 2027).

## Changed defaults

| | Before | Now | To keep the old behavior |
|---|---|---|---|
| Distro | Humble | Jazzy | `ROS_DISTRO=humble` in `.env`, or open **ROS 2 Humble** in VS Code |
| Image | `full` | `desktop` | `TARGET=full` |
| ROS domain (devcontainer) | 42 | 0 | `ROS_DOMAIN_ID=42` |
| Discovery (devcontainer) | localhost only | subnet | `ROS_DISCOVERY=localhost` |
| Container name | `ros2_humble_devel` | `ros2_dev_<distro>` | – |
| Build output | `local_mount/build`, `install`, `log` | Docker volumes per distro | – |
| `/dev` on macOS | added by hand to `compose_macos.yaml` | `DEVICES=all` | note: it's the Docker VM's `/dev`, not the Mac's |

## Moving an existing checkout

```bash
git stash          # if you changed one of the old compose files
git pull
./dev.sh up
```

Your sources in `local_mount/src` stay where they are. The old `local_mount/build`, `install` and `log` folders aren't used anymore. Builds now go to Docker volumes, so you can delete those folders.

The first build in the new layout starts from scratch.

## Moving a workspace from Humble to Jazzy or Lyrical

Packages that build on Humble usually build on Jazzy. What tends to need changes:
- Gazebo Classic (`gazebo_ros`, `gazebo_plugins`) doesn't exist after Humble. Use `ros_gz` and Gazebo Harmonic (Jazzy) or Jetty (Lyrical).
- `ROS_LOCALHOST_ONLY` is replaced by `ROS_AUTOMATIC_DISCOVERY_RANGE`; this setup handles it through `ROS_DISCOVERY`.
- Newer compilers (GCC 13 on Jazzy, GCC 15 on Lyrical) and CMake 4 on Lyrical are stricter: missing `#include <cstdint>` and old `cmake_minimum_required` versions are the usual errors.

Run both side by side while you move: `./dev.sh up --distro humble` and `./dev.sh up --distro jazzy` use separate build volumes.
