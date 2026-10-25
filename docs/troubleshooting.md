# Troubleshooting

Start with these two commands: they show what was selected and what the container is doing.

```bash
./dev.sh status
./dev.sh logs
```

## rosdep: "Unable to locate package"

```text
E: Unable to locate package ros-jazzy-joint-state-publisher-gui
```

The image ships without apt package lists, to stay small. Refresh them first:

```bash
sudo apt-get update
rosdep install --from-paths src --ignore-src -y
```

The VS Code devcontainer does this for you when it creates the container.

## rosdep: "Cannot locate rosdep definition for [...]"

The key doesn't exist for this distro. Common causes when moving a workspace to Jazzy or Lyrical:
- Gazebo Classic keys (`gazebo_ros`, `gazebo_plugins`): Gazebo Classic isn't available after Humble. Port to `ros_gz`.
- A typo or a metapackage name that isn't a rosdep key, e.g. `nav2` instead of `nav2_bringup` or `navigation2`.

Add `-r` to install the rest anyway: `rosdep install --from-paths src --ignore-src -y -r`.

## Port already in use

```text
Bind for 0.0.0.0:3080 failed: port is already allocated
```

Another container or program uses the port. Often it's a second distro, or a container from the old setup. Either stop it:

```bash
docker ps --format '{{.Names}}\t{{.Ports}}'
```

or give this one other ports in `.env` (`NOVNC_PORT`, `CODE_SERVER_PORT`, `SSH_PORT`, `VNC_PORT`, `ZENOH_PORT`).

## The desktop is black or doesn't connect

- Wait a few seconds after `./dev.sh up`; the desktop starts after the container.
- Check that you started a `desktop` or `full` image: `./dev.sh status` shows `TARGET`.
- Check the VNC service: `docker exec -u root ros2_dev_jazzy supervisorctl status` should show `vnc-workers:vnc` as `RUNNING`. If it doesn't, `./dev.sh logs` shows why.
- If you set `VNC_PASSWORD`, noVNC asks for it.

## GUI apps don't appear

- **macOS:** apps open on the browser desktop (http://localhost:3080), not on the Mac's screen.
- **Linux, host screen:** check that `DISPLAY` is set in the shell you ran `./dev.sh up` from, and that `$XAUTHORITY` points to a file. Then recreate the container with `./dev.sh up`.
- **Linux, browser desktop:** start the app with `DISPLAY=:2`.

## No ROS topics from another machine

- **Bridge networking** (macOS, older rootless Docker) keeps DDS inside Docker. Use [Zenoh](networking.md#zenoh).
- Check that both sides use the same `ROS_DOMAIN_ID`, and that `ROS_DISCOVERY` isn't `localhost`.
- Wi-Fi networks often block multicast. Use Zenoh there too.

## Rootless Docker: no host network

```text
NETWORK     bridge         (auto: rootless Docker 29.4.0 can't share the host network (needs 29.5+))
```

Rootless Docker before Engine 29.5 can't use the host's network. Update Docker, or use Zenoh to reach other machines.

## Rootless Docker: serial port "Permission denied"

Host groups such as `dialout` don't carry into a rootless container. Install [configs/udev/99-ros-dev.rules](../configs/udev/99-ros-dev.rules) and set `DEVICES=all`; see [Hosts](hosts.md#rootless-docker-and-podman).

## The wrong distro starts

`ROS_DISTRO` is read only from `.env` and `--distro`, never from your shell. Check `ROS_DISTRO=` in `.env`, outside the block written by `dev.sh`.

Plain `docker compose` is different: it does use a `ROS_DISTRO` exported by a host shell that sourced ROS. Use `./dev.sh`, or a shell without ROS sourced.

## Build errors after switching distro or image

Each distro has its own build volumes, so distros never mix. Within one distro, stale CMake caches can still break a build after big changes. Start that distro's build from scratch:

```bash
./dev.sh down
docker volume rm ros2_dev_jazzy_build ros2_dev_jazzy_install ros2_dev_jazzy_log
./dev.sh up
```

## Old image after an update

`./dev.sh up` uses the image already on your machine. To fetch the newest one:

```bash
docker compose pull && ./dev.sh up
```
