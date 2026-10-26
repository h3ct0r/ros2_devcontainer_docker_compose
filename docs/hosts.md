# Hosts and hardware

`./dev.sh status` shows what was detected on your machine. This page covers each kind of host.

| Host | Network | Devices | GPU | Notes |
|---|---|---|---|---|
| macOS (Docker Desktop) | bridge | none | none | GUI apps open on the browser desktop |
| Linux, rootful Docker | host | all (`/dev`, privileged) | NVIDIA if available | GUI apps can use your own screen |
| Linux, rootless Docker | host on 29.5+, else bridge | none until udev rules are installed | NVIDIA through CDI | files stay owned by you |
| Jetson | host | all | `jetson` (experimental) | arm64 images |

## macOS

Works with Docker Desktop on Apple Silicon (native arm64 images) and Intel Macs.

- **Bridge networking.** DDS can't leave Docker Desktop's VM, so ROS traffic to other machines goes through [Zenoh](networking.md#zenoh).
- **GUI apps** started from a terminal, code-server or VS Code open on the browser desktop at http://localhost:3080, because the overlay sets `DISPLAY=:2`.
- **Graphics** are rendered in software (llvmpipe). rviz2 runs at about 30 FPS and Gazebo at 30–40 % of real time on an M-series Mac.
- **USB devices.** `DEVICES=all` passes the `/dev` of Docker Desktop's Linux VM, not the Mac's. USB serial adapters and cameras need USB/IP or a Linux host.
- **Emulating amd64.** `PLATFORM=linux/amd64` runs the amd64 image under Rosetta or QEMU. It's slower, but useful for amd64-only packages.

## Linux

With rootful Docker Engine, `./dev.sh` uses host networking and passes the host's devices:

- DDS discovery reaches the LAN and ROS nodes running on the host directly;
- SocketCAN interfaces (`can0`) are visible;
- `/dev/ttyUSB*`, cameras and other devices work inside the container, which runs privileged.

To leave the devices out, set `DEVICES=none`.

**Your screen.** GUI apps open on the host display by default. `./dev.sh` hands over the display and its X11 cookie, so no `xhost +` is needed, and this also works on Wayland desktops through XWayland. When the shell or VS Code has no `DISPLAY` or `XAUTHORITY` (an SSH session, some launchers), `./dev.sh` takes them from the logged-in desktop session; `./dev.sh status` shows which display it uses. The cookie is kept in `~/.cache/ros2_dev/Xauthority` and refreshed on every `./dev.sh` run, including when VS Code opens a devcontainer. Use `DISPLAY=:2` to send an app to the browser desktop instead.

## NVIDIA GPU

Install the NVIDIA driver and the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html), then configure Docker:

```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

`GPU=auto` then finds it, and `nvidia-smi` works in the container.

| Where the app draws | How to use the GPU |
|---|---|
| Your own screen (`DISPLAY=:0`) | Works directly. On hybrid laptops whose desktop runs on the integrated GPU, use `prime-run rviz2`. |
| Browser desktop (`DISPLAY=:2`) | Renders in software by default; `prime-run rviz2` moves rendering to the GPU, at about 30 FPS at 1080p. |
| Headless: CUDA, Gazebo sensors, Open3D | Uses the GPU directly. |

To test without the GPU on an NVIDIA machine, set `GPU=none`.

## Jetson

`GPU=jetson` is picked on a Jetson (`/etc/nv_tegra_release`) and uses JetPack's `nvidia` runtime. It's **experimental**: the images are plain Ubuntu, not L4T, so CUDA inside the container hasn't been tested. The `base` and `robot` targets run normally on the Jetson's CPU.

For a headless robot:

```bash
./dev.sh up --target robot
```

[Running on a robot](robot.md) covers copying the image without internet, starting on boot and connecting VS Code.

## Rootless Docker and Podman

[Rootless Docker](https://docs.docker.com/engine/security/rootless/) runs the daemon as your user. Set it up once:

```bash
dockerd-rootless-setuptool.sh install
```

`MODE=auto` detects it, and `./dev.sh` adapts:

- **Files stay yours.** The container's root is your host user, so the session runs as `root` with `/home/ubuntu` as its home. Files it writes to `local_mount` belong to you. SSH logs in as `root` with `DEV_PASSWORD`.
- **Network.** Host networking reaches the real host network only on Docker Engine 29.5 or newer. On older engines `./dev.sh` falls back to bridge networking; use [Zenoh](networking.md#zenoh) to reach other machines.
- **Devices.** Host groups such as `dialout` don't carry into a rootless container. Install the udev rules, then set `DEVICES=all`:

  ```bash
  sudo cp configs/udev/99-ros-dev.rules /etc/udev/rules.d/
  sudo udevadm control --reload-rules && sudo udevadm trigger
  ```

  They open USB serial adapters, Intel RealSense cameras and similar devices to all users. Read the file before installing it.
- **NVIDIA.** Works through the CDI spec that the NVIDIA Container Toolkit generates: `sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml`.

**Podman** works the same way when rootless. Alternatively, `--userns=keep-id:uid=1000,gid=1000` maps your user to `ubuntu`.

## USB and serial devices

| Host | What to do |
|---|---|
| Rootful Linux | nothing; `DEVICES=all` is the default |
| Rootless Linux | install [99-ros-dev.rules](../configs/udev/99-ros-dev.rules), then set `DEVICES=all` |
| macOS | not supported by Docker Desktop; use a Linux machine or the robot |

Devices plugged in after the container starts appear too, because the whole `/dev` is mounted.
