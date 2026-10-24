# ros2_devcontainer_docker_compose

ROS 2 development containers for **Humble, Jazzy and Lyrical**, on amd64 and arm64:
- a browser desktop (XFCE over noVNC);
- code-server and SSH;
- VS Code Dev Containers;
- Zenoh;
- rootless Docker.

They're meant for developing on a laptop and for early testing on the robot. Images are published as `h3ct0rdcc/ros2_dev:<distro>-<target>`.

## Quick start

```bash
git clone git@github.com:h3ct0r/ros2_devcontainer_docker_compose.git
cd ros2_devcontainer_docker_compose
./dev.sh up                    # Jazzy desktop; ./dev.sh up --distro humble for another distro
```

`./dev.sh up` prints where to connect:
- the desktop at http://localhost:3080/?autoconnect=true;
- code-server at http://localhost:3081;
- SSH with `ssh -p 3022 ubuntu@localhost` (password `ubuntu`).

`./dev.sh shell` opens a terminal in the container.

Your code goes in `local_mount/src`, which the container sees as `~/ros2_ws/src`.

**VS Code:** open this folder, run "Dev Containers: Reopen in Container", and pick **ROS 2 Humble**, **ROS 2 Jazzy** or **ROS 2 Lyrical**.

## Choosing the distro, image and host setup

Settings live in `.env`; copy [.env.example](.env.example) to start, and `./dev.sh` creates it if missing. A variable in your shell overrides `.env`, and a `./dev.sh` option overrides both. The host settings default to `auto`, and any other value wins over the detection.

| Setting | Values | `auto` picks |
|---|---|---|
| `ROS_DISTRO` | humble, jazzy, lyrical | – (default `jazzy`; in VS Code the config you open decides) |
| `TARGET` | base, robot, desktop, full | – (default `desktop`) |
| `GPU` | auto, none, nvidia, jetson | `nvidia` if Docker has the NVIDIA runtime or an NVIDIA CDI spec, `jetson` on a Jetson, otherwise `none` |
| `MODE` | auto, rootful, rootless | whichever kind of Docker is running |
| `NETWORK` | auto, host, bridge | `host` on Linux, `bridge` with published ports on macOS and on rootless Docker older than 29.5 |
| `DEVICES` | auto, none, all | `all` (`/dev`, privileged) on rootful Linux, `none` on macOS and rootless |
| `PLATFORM` | native, linux/amd64, linux/arm64 | `native`; the other one runs emulated |

```bash
./dev.sh status                          # what each setting resolved to, and why
GPU=none ./dev.sh up                     # NVIDIA machine, but test without the GPU
./dev.sh up --distro lyrical --target full
TARGET=robot MODE=rootless DEVICES=all ./dev.sh up   # Jetson robot, rootless, headless
```

| Command | Does |
|---|---|
| `./dev.sh up` | start the container (default command) |
| `./dev.sh down` | stop and remove it (build volumes are kept) |
| `./dev.sh shell` | open a shell in it |
| `./dev.sh status` | show the resolved settings |
| `./dev.sh logs` | follow its logs |
| `./dev.sh build` | build the image locally instead of pulling it |

`./dev.sh` turns the settings into a list of compose files: [compose.yaml](compose.yaml) plus one overlay per concern from [compose/](compose). It records that list at the end of `.env`, so plain `docker compose ps`, `logs` or `down` follow the last selection. Run ROS commands from a host shell that sourced ROS through `./dev.sh`, not plain `docker compose`: such shells export their own `ROS_DISTRO`, which plain compose would use.

Several distros can run side by side. Each one is its own compose project (`ros2_dev_<distro>`). With bridge networking, give each its own host ports in `.env` (`NOVNC_PORT`, `CODE_SERVER_PORT`, `SSH_PORT`, `VNC_PORT`, `ZENOH_PORT`).

## Images

One Dockerfile ([docker/Dockerfile](docker/Dockerfile)) builds four stacked targets per distro; each one contains the previous one:

| Target | Adds | Use it for |
|---|---|---|
| `base` | ROS 2 base, build and debug tools (colcon, rosdep, gdb, ccache), SSH, Zenoh, Python venv `~/.py3` | headless development, CI |
| `robot` | perception, RealSense, Livox SDK2, Dynamixel, CAN, Nav2, SLAM Toolbox, robot_localization | running on the robot |
| `desktop` | rviz2/rqt, a lean XFCE desktop over VNC/noVNC, code-server | development with a GUI |
| `full` | `desktop-full`, Gazebo (ros_gz), TurtleBot3 | simulation |

| Distro | Ubuntu | Python | Gazebo | Supported until |
|---|---|---|---|---|
| Humble | 22.04 | 3.10 | Fortress | May 2027 |
| Jazzy | 24.04 | 3.12 | Harmonic | May 2029 |
| Lyrical | 26.04 | 3.14 | Jetty | May 2031 |

**Tags** are on Docker Hub, mirrored to `ghcr.io/h3ct0r/ros2_dev`:
- `h3ct0rdcc/ros2_dev:<distro>-<target>`, e.g. `jazzy-desktop`;
- `:<distro>` for that distro's `full`;
- `:latest` for `jazzy-full`.

Until Humble's end of life, the Humble images also keep the old names `h3ct0rdcc/ros2_humble_development:{base,robot,desktop,full,latest,amd64,arm64}`.

**Per-distro differences** (apt packages are listed per stage in [docker/packages/](docker/packages)):
- **Lyrical** has no `turtlebot3` metapackage yet; its simulations are installed. `ros2_unbag` is left out because it pins numpy 1.26, which has no Python 3.14 wheels.
- **Humble:** the TurtleBot3 Gazebo Classic simulations are only packaged for amd64. On arm64, pip installs `ros2_unbag` 1.0.x, because newer releases need glibc 2.39.
- **Python venv:** numpy stays on the system's major version (1 on Humble and Jazzy, 2 on Lyrical), so ROS's compiled extensions such as `cv_bridge` keep working inside it.

## Workspace

`local_mount/` is mounted as `~/ros2_ws`. `build/`, `install/` and `log/`, plus the ccache, live in per-distro Docker volumes (`ros2_dev_<distro>_build`, `_install`, `_log`, `_ccache`):
- builds of different distros never mix;
- a recreated container keeps its build;
- builds on macOS are much faster than on a bind mount.

colcon builds use symlink-install, Release, ccache and `compile_commands.json` by default ([configs/colcon/defaults.yaml](configs/colcon/defaults.yaml)). To start a distro's build from scratch:

```bash
docker volume rm ros2_dev_jazzy_build ros2_dev_jazzy_install ros2_dev_jazzy_log
```

## Access and passwords

The container sets these passwords at startup:
- `DEV_PASSWORD` for SSH, default `ubuntu`. The user is `ubuntu`, or `root` in rootless mode.
- `VNC_PASSWORD` for the VNC/noVNC desktop.
- `CODE_SERVER_PASSWORD` for code-server.

The desktop and code-server are open while their passwords are empty. Set them before using the robot on a shared network.

## ROS discovery and Zenoh

`ROS_DISCOVERY=subnet|localhost` sets the discovery range in the form each distro understands: `ROS_LOCALHOST_ONLY` on Humble, `ROS_AUTOMATIC_DISCOVERY_RANGE` on Jazzy and Lyrical.

Zenoh is off by default. `ROS_TRANSPORT` picks the middleware:

| `ROS_TRANSPORT` | ROS nodes use | Also started | When |
|---|---|---|---|
| `dds` (default) | Fast DDS | – | one machine, or a LAN where DDS discovery works |
| `zenoh` | `rmw_zenoh_cpp` | Zenoh router on TCP 7447 | every node on every machine uses Zenoh |
| `bridge` | CycloneDDS | `zenoh-bridge-ros2dds` on TCP 7447 | DDS stays local; only Zenoh crosses the network |

To connect a laptop to a robot, start the robot with `ROS_TRANSPORT=zenoh` (or `bridge`), then run this on the laptop:

```bash
ROS_TRANSPORT=zenoh ZENOH_CONNECT=tcp/<robot-ip>:7447 ./dev.sh up
```

- With `bridge`, `ZENOH_NAMESPACE=/bot1` on a robot prefixes everything it publishes. `/bot1/cmd_vel` on the laptop is `/cmd_vel` on the robot.
- Only one outbound TCP connection is needed, so this works through NAT, bridge networks and rootless Docker.
- rmw_zenoh ignores the discovery-range variables.

## NVIDIA GPU

Needs the NVIDIA driver and `nvidia-container-toolkit` on the host; `GPU=auto` then finds it.

- **Host display:** start apps with `DISPLAY=:0`. The X11 cookie is handed over, so no `xhost` is needed. On laptops whose desktop runs on the integrated GPU, use `prime-run` (`DISPLAY=:0 prime-run rviz2`).
- **VNC:** apps render in software. `prime-run` moves them to the GPU, but at about 30 FPS at 1080p.
- **Headless rendering and CUDA** (Gazebo sensors, Open3D) use the GPU directly.
- **Jetson:** `GPU=jetson` is experimental; the images are plain Ubuntu, not L4T.

## Rootless Docker

Set it up with `dockerd-rootless-setuptool.sh install` (see the [Docker docs](https://docs.docker.com/engine/security/rootless/)); `MODE=auto` then detects it.

- **Files stay yours.** The container's root is your host user, so the session runs as `root` with `/home/ubuntu` as its home, and files in `local_mount/` belong to you. VS Code connects as that user automatically.
- **Devices.** Host groups such as `dialout` don't reach a rootless container. Install [configs/udev/99-ros-dev.rules](configs/udev/99-ros-dev.rules) on the host, then set `DEVICES=all`.
- **Network.** Host networking reaches the real host network only on rootless Docker Engine 29.5 or newer; `NETWORK=auto` falls back to bridge on older engines. Use Zenoh to reach other machines from there.
- **NVIDIA.** Works through the CDI spec generated by `nvidia-container-toolkit`.
- **Podman.** Rootless Podman works the same way. Alternatively, `--userns=keep-id:uid=1000,gid=1000` maps your user to `ubuntu`.

## Building and publishing

[CI](.github/workflows/ci.yml) builds and tests every distro on GitHub's amd64 and arm64 runners for each pull request. On `main` it also publishes all tags to Docker Hub and GHCR. That needs the repository secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` (a Docker Hub access token with write access).

Locally, [docker-bake.hcl](docker-bake.hcl) builds any of them; each distro's base image is pinned by digest there:

```bash
./dev.sh build --distro lyrical --target desktop                        # one image, this machine's arch
docker buildx bake --load --set '*.platform=linux/arm64' jazzy-desktop  # the same with bake
docker buildx bake jazzy                                                 # all of Jazzy's targets
```

## Coming from the previous setup

The image sources from [h3ct0r/ros2_humble_docker_vnc_dev](https://github.com/h3ct0r/ros2_humble_docker_vnc_dev) now live here, with their history.

| Before | Now |
|---|---|
| `docker compose -f compose_linux.yaml up -d` | `./dev.sh up` |
| `compose_linux_nvidia.yaml` / `compose_rootless*.yaml` | `./dev.sh up`; GPU and rootless are detected |
| `compose_macos.yaml` | `./dev.sh up` |
| `TARGET=robot docker compose -f compose_linux.yaml up -d` | `./dev.sh up --target robot` |
| one `.devcontainer/devcontainer.json` (macOS) | `.devcontainer/{humble,jazzy,lyrical}` on any host |
| `ROS_LOCALHOST_ONLY=1` | `ROS_DISCOVERY=localhost` |
| `h3ct0rdcc/ros2_humble_development:full` | `h3ct0rdcc/ros2_dev:humble-full` |
