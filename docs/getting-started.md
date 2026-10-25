# Getting started

This guide takes you from a fresh clone to a built ROS 2 workspace.

## What you need

| Host | Install |
|---|---|
| macOS (Apple Silicon or Intel) | [Docker Desktop](https://docs.docker.com/desktop/setup/install/mac-install/) |
| Linux | [Docker Engine](https://docs.docker.com/engine/install/) with the Compose plugin (`docker compose version`) |
| Linux with an NVIDIA GPU | the NVIDIA driver and the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) |
| VS Code (optional) | the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension |

Rootless Docker and Podman work too; see [Hosts and hardware](hosts.md#rootless-docker-and-podman).

The `desktop` image is about 2–2.6 GB to download, so the first start takes a few minutes.

## First run

```bash
git clone https://github.com/h3ct0r/ros2_devcontainer_docker_compose.git
cd ros2_devcontainer_docker_compose
./dev.sh up
```

`./dev.sh up` shows what it detected, starts the container and prints where to connect. On a Mac it looks like this:

```text
  ROS_DISTRO  jazzy          (default)
  TARGET      desktop        (default)
  GPU         none           (auto: macOS)
  MODE        rootful        (auto: Docker runs as root)
  NETWORK     bridge         (auto: Docker Desktop on macOS)
  DEVICES     none           (auto: macOS)
  PLATFORM    native         (default)
  compose     compose.yaml compose/net-bridge.yaml compose/macos.yaml
 ✔ Container ros2_dev_jazzy  Started

  desktop      http://localhost:3080/?autoconnect=true
  code-server  http://localhost:3081
  ssh          ssh -p 3022 ubuntu@localhost
  shell        ./dev.sh shell
```

The first run also creates `.env` from [.env.example](../.env.example). That file holds every setting; see [Configuration](configuration.md).

## Connecting

| Tool | How | Notes |
|---|---|---|
| Desktop | open http://localhost:3080/?autoconnect=true | XFCE in the browser. No password unless `VNC_PASSWORD` is set. |
| code-server | open http://localhost:3081 | VS Code in the browser. No password unless `CODE_SERVER_PASSWORD` is set. |
| SSH | `ssh -p 3022 ubuntu@localhost` | Password `ubuntu` (`DEV_PASSWORD`). |
| Terminal | `./dev.sh shell` | A login shell with ROS and the workspace sourced. |
| VS Code | **Dev Containers: Reopen in Container** | Pick the distro; see [VS Code](vscode.md). |
| VNC client | `localhost:5902` | Any VNC viewer; same password as the desktop. |

The desktop and code-server have no password by default. Set `VNC_PASSWORD` and `CODE_SERVER_PASSWORD` in `.env` before running on a shared network.

GUI apps started from any of these (code-server, SSH or `./dev.sh shell`) open on the desktop at `:3080` on macOS. On Linux they open on your own screen; start them with `DISPLAY=:2` to send them to the browser desktop instead.

## Your workspace

The container's workspace is `~/ros2_ws` (`/home/ubuntu/ros2_ws`):

| Container path | Lives in | Why |
|---|---|---|
| `~/ros2_ws/src` | `local_mount/src` on the host | your code, edited with any tool |
| `~/ros2_ws/build`, `install`, `log` | Docker volumes `ros2_dev_<distro>_build`, `_install`, `_log` | builds of different distros never mix, and they're fast on macOS |
| `~/.cache/ccache` | Docker volume `ros2_dev_<distro>_ccache` | compiler cache, kept across container rebuilds |

To use a folder other than `local_mount`, set `WORKSPACE=/path/to/ws` in `.env`. That folder is mounted as `~/ros2_ws`, so put packages in its `src/`.

Clone your packages on the host:

```bash
git clone https://github.com/ros/ros_tutorials.git -b jazzy local_mount/src/ros_tutorials
```

## Building

Inside the container (`./dev.sh shell`):

```bash
cd ~/ros2_ws
sudo apt-get update                       # the image ships without apt package lists
rosdep install --from-paths src --ignore-src -y
colcon build
source install/setup.bash
```

colcon defaults come from [configs/colcon/defaults.yaml](../configs/colcon/defaults.yaml): symlink install, Release, ccache and `compile_commands.json`. A second build of unchanged code mostly hits the cache.

The VS Code devcontainer runs the same `apt-get update`, `rosdep install` and `colcon build` when it creates the container.

New shells source `install/setup.bash` on their own.

## Stopping and updating

```bash
./dev.sh down          # stop and remove the container; build volumes stay
docker compose pull    # fetch the newest image for the last selection
./dev.sh up            # start again with the new image
```

To start a distro's build from scratch, remove its volumes while the container is down:

```bash
docker volume rm ros2_dev_jazzy_build ros2_dev_jazzy_install ros2_dev_jazzy_log
```

## Next steps

- [Configuration](configuration.md): choose the distro, image, GPU and network.
- [Networking and Zenoh](networking.md): talk to a robot or another machine.
- [Troubleshooting](troubleshooting.md): if something doesn't start.
