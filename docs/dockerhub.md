# ROS 2 development images

Ready-to-use ROS 2 environments for **Humble, Jazzy and Lyrical**, on **amd64 and arm64**:
- a desktop in your browser;
- VS Code devcontainers and code-server;
- SSH and Zenoh;
- support for rootless Docker.

Source, setup script and documentation: **[github.com/h3ct0r/ros2_devcontainer_docker_compose](https://github.com/h3ct0r/ros2_devcontainer_docker_compose)**

![The Jazzy desktop in a browser: a terminal running ros2 topic hz and rviz2 showing a robot arm and its laser scan](https://raw.githubusercontent.com/h3ct0r/ros2_devcontainer_docker_compose/main/docs/images/desktop.webp)

## Quick start

The repo's `dev.sh` detects your host (macOS, Linux, NVIDIA, rootless Docker) and starts the right container:

```bash
git clone https://github.com/h3ct0r/ros2_devcontainer_docker_compose.git
cd ros2_devcontainer_docker_compose
./dev.sh up
```

Then open http://localhost:3080/?autoconnect=true for the desktop, or http://localhost:3081 for code-server.

To run an image directly:

```bash
docker run -d --name ros2 -p 3080:3080 -p 3081:3081 -p 3022:3022 --shm-size 1g h3ct0rdcc/ros2_dev:jazzy-desktop
```

## Tags

`<distro>-<target>`, for example `jazzy-desktop`. Every tag is multi-arch (amd64 + arm64).

| Target | Adds |
|---|---|
| `base` | ROS 2 base, build and debug tools, SSH, Zenoh, Python venv |
| `robot` | perception, Nav2, SLAM Toolbox, robot_localization, RealSense, Livox, Dynamixel, CAN |
| `desktop` | rviz2, rqt, XFCE desktop over noVNC, code-server |
| `full` | `desktop-full`, Gazebo (ros_gz), MuJoCo, TurtleBot3 |

| Distro | Ubuntu | Tags |
|---|---|---|
| Humble | 22.04 | `humble-base`, `humble-robot`, `humble-desktop`, `humble-full` (= `humble`) |
| Jazzy | 24.04 | `jazzy-base`, `jazzy-robot`, `jazzy-desktop`, `jazzy-full` (= `jazzy`, `latest`) |
| Lyrical | 26.04 | `lyrical-base`, `lyrical-robot`, `lyrical-desktop`, `lyrical-full` (= `lyrical`) |

The same images are on `ghcr.io/h3ct0r/ros2_dev`.

## Services

| Port | Service | Targets |
|---|---|---|
| 3080 | desktop in the browser (noVNC) | `desktop`, `full` |
| 3081 | code-server | `desktop`, `full` |
| 3022 | SSH (user `ubuntu`, password from `DEV_PASSWORD`, default `ubuntu`) | all |
| 7447 | Zenoh, with `ROS_TRANSPORT=zenoh` or `bridge` | all |

The desktop and code-server have no password unless `VNC_PASSWORD` and `CODE_SERVER_PASSWORD` are set.

## Documentation

- [Getting started](https://github.com/h3ct0r/ros2_devcontainer_docker_compose/blob/main/docs/getting-started.md)
- [Configuration](https://github.com/h3ct0r/ros2_devcontainer_docker_compose/blob/main/docs/configuration.md)
- [Networking and Zenoh](https://github.com/h3ct0r/ros2_devcontainer_docker_compose/blob/main/docs/networking.md)
- [Running on a robot](https://github.com/h3ct0r/ros2_devcontainer_docker_compose/blob/main/docs/robot.md)
- [Hosts and hardware](https://github.com/h3ct0r/ros2_devcontainer_docker_compose/blob/main/docs/hosts.md)
- [Images](https://github.com/h3ct0r/ros2_devcontainer_docker_compose/blob/main/docs/images.md)

License: MIT.
