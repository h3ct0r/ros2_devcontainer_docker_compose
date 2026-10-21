# ros2_humble_docker_vnc_dev
The sources of the base ROS2 Humble Docker image for development with devcontainers. It covers local development and testing on the robot: VNC and code-server in the browser, SSH, Zenoh, and rootless Docker support.

<details>
<summary> Details of the services in this container </summary>

- ROS2 humble with a base workspace `/home/ubuntu/ros2_ws/`;
- Native amd64 and arm64 (Jetson Orin Nano, Apple Silicon) images from one Dockerfile;
- Support for NVIDIA Docker runtime for linux hosts;
- VNC server that allows direct browser access (http://localhost:3080/), so nothing is required to install and use it;
- A `ssh` server, to allow direct access from outside (`ssh ubuntu@localhost -p 3022`);
- A web `vscode` server for easy remote access when deploying it on the robot (http://localhost:3081/);
- Zenoh: `rmw_zenoh` and `zenoh-bridge-ros2dds`, switched on with one variable;
- Rootless Docker/Podman support;
- Fast rebuilds: `ccache` and `colcon` defaults (symlink install, Release, `compile_commands.json`);
- Custom environment and VScode configurations:
  - Open split terminals on launch;
  - Setup all environments variables automatically for running ROS;
  - Automatically open the VNC interface in a ROS tab;
  - Custom PS1 (terminal shell);
</details>

### Images

One Dockerfile ([docker/Dockerfile](docker/Dockerfile)) builds four stacked targets. Each one contains the previous one:

| Target | Contents | Use it for | Compressed size amd64 / arm64 |
|---|---|---|---|
| `base` | ROS 2 base, build/debug tools (colcon, rosdep, gdb, ccache), ssh, Zenoh, Python venv `~/.py3` | headless development, CI | 1.22 / 0.78 GB |
| `robot` | + perception, RealSense, Livox SDK2, Dynamixel, CAN, Nav2, SLAM toolbox, robot_localization | running on the robot (SSH / VS Code Remote-SSH) | 2.02 / 1.54 GB |
| `desktop` | + rviz2/rqt, lean XFCE desktop over VNC/noVNC, code-server | development with a GUI | 2.26 / 1.79 GB |
| `full` | + `ros-humble-desktop-full`, Gazebo (ros_gz), TurtleBot3 | everything, the default | 2.51 / 1.92 GB |

Choose one with `TARGET=<target>` in front of the compose command, or in a `.env` file (see [.env.example](.env.example)).

For reference, the previous single image was 3.53 GB compressed (amd64), even without Open3D and Zenoh.

The Python venv (Open3D, ros2_unbag with PySide6, SciPy) is about 2.1 GB unpacked on amd64, and it's in every target.

### Dev Containers

For a complete tutorial on how to use this repo using devcontainers VScode check: 
- https://github.com/h3ct0r/ros2_devcontainer_docker_compose

### Headless run with `docker compose`

<details>
  <summary>Recommended for remote development, as for example, deploying a dev machine on the robot.</summary>
  
- `git clone git@github.com:h3ct0r/ros2_humble_docker_vnc_dev.git`
- `cd ros2_humble_docker_vnc_dev`
- `BUILDKIT_PROGRESS=plain docker compose -f compose_linux.yaml up --build`

`BUILDKIT_PROGRESS=plain` helps to visualize step by step output of each of the commands.
</details>

| Host | Command |
|---|---|
| Linux (workstation or robot, rootful Docker) | `docker compose -f compose_linux.yaml up -d` |
| Linux with NVIDIA GPU | `docker compose -f compose_linux_nvidia.yaml up -d` |
| macOS (Docker Desktop) | `docker compose -f compose_macos.yaml up -d` |
| Linux, rootless Docker/Podman | `docker compose -f compose_rootless.yaml up -d` |
| Robot, rootless Docker | `docker compose -f compose_rootless_robot.yaml up -d` |

On the robot, use the lean headless target: `TARGET=robot docker compose -f compose_linux.yaml up -d`.

The architecture is picked automatically, so Apple Silicon Macs and the Jetson run native arm64 images without emulation. `compose_linux_arm.yaml` is gone: use `compose_linux.yaml` on arm64 too.

### Access to services

Once the container is up, the you can access the services via:

- VNC: http://localhost:3080 (`desktop` and `full`)
- VScode: http://localhost:3081 (`desktop` and `full`)
- SSH: `ssh ubuntu@localhost -p 3022`
  - user: `ubuntu` (`root` in rootless mode)
  - pass: `ubuntu`

Passwords are set when the container starts, from `DEV_PASSWORD` (ssh, default `ubuntu`), `VNC_PASSWORD` and `CODE_SERVER_PASSWORD`. When the VNC and code-server passwords are empty, those services are open. Set them when the robot is on a shared network.

### Zenoh

Zenoh is off by default. `ROS_TRANSPORT` picks the middleware when the container starts:

| `ROS_TRANSPORT` | ROS nodes use | Also started | When |
|---|---|---|---|
| `dds` (default) | Fast DDS | – | one machine, or a LAN where DDS discovery works |
| `zenoh` | `rmw_zenoh_cpp` | Zenoh router (`rmw_zenohd`) on TCP 7447 | every node on every machine uses Zenoh |
| `bridge` | CycloneDDS | `zenoh-bridge-ros2dds` on TCP 7447 | DDS stays local on each machine; only Zenoh crosses the network |

To connect a laptop to the robot, run the robot with `ROS_TRANSPORT=zenoh` (or `bridge`). Then on the laptop set the same transport and point it at the robot:

```
ROS_TRANSPORT=zenoh ZENOH_CONNECT=tcp/<robot-ip>:7447 docker compose -f compose_macos.yaml up -d
```

- `ZENOH_CONNECT` takes a comma-separated list of endpoints.
- With `bridge`, `ZENOH_NAMESPACE=/bot1` on a robot prefixes everything it publishes, which keeps several robots apart.
- Only one outbound TCP connection is needed, so this works through NAT, Docker bridge networks and rootless Docker, where DDS multicast does not.
- The chosen middleware is applied to every shell: SSH, VNC terminals, code-server and `docker exec`.

### Rootless Docker

Set up rootless Docker with `dockerd-rootless-setuptool.sh install` (see the [Docker docs](https://docs.docker.com/engine/security/rootless/)), then use `compose_rootless.yaml` or `compose_rootless_robot.yaml`.

- **Files stay yours.** In rootless mode the container's root user is your host user. The entrypoint detects rootless Docker (a user namespace, plus a workspace owned by container root) and runs the session as `root`, with `/home/ubuntu` as its home. Files written to `local_mount/` are then owned by you on the host. Log in over SSH as `root` with `DEV_PASSWORD`. Set `ROOTLESS=1` or `ROOTLESS=0` to override the detection.
- **Devices.** Host groups such as `dialout` don't reach a rootless container. Install [configs/udev/99-ros-dev.rules](configs/udev/99-ros-dev.rules) on the host for serial adapters (Dynamixel) and RealSense cameras.
- **Network.** In rootless Docker, `network_mode: host` reaches the real host network only on Engine 29.5 or newer. That's what `compose_rootless_robot.yaml` needs for DDS discovery and SocketCAN. On older engines use `compose_rootless.yaml` with `ROS_TRANSPORT=zenoh` or `bridge`.
- **Dev Containers.** Set `"remoteUser": "root"` in `devcontainer.json`.
- **Podman.** Rootless Podman works the same way. Alternatively, `--userns=keep-id:uid=1000,gid=1000` maps your user to `ubuntu`.

### Build and Push

Builds both architectures for every target with [docker-bake.hcl](docker-bake.hcl):

- `docker buildx bake --push release` pushes `:base`, `:robot`, `:desktop`, `:full`/`:latest` (amd64 + arm64), and the old single-arch `:amd64` and `:arm64` tags.
- `CACHE=1 docker buildx bake --push release` also pushes a registry build cache.
- `docker buildx bake --load --set '*.platform=linux/arm64' desktop` builds one local image.

Notes:
- On arm64, pip installs `ros2_unbag` 1.0.x. Newer releases pin PySide6 6.9, whose arm64 wheels need glibc 2.39, and Ubuntu 22.04 has 2.35.
- TurtleBot3 Gazebo simulations are only packaged for amd64.
