# ros2_devcontainer_docker_compose
## _A simple way to run ROS2 Humble for *DEVELOPMENT* using https://containers.dev/_

This repo contains a simple way to delevop locally in a ROS2 Humble docker container using the VScode [devcontainers](https://containers.dev/). 
A  `development container` (or dev container for short) allows you to use a container as a full-featured development environment. It can be used to run an application, to separate tools, libraries, or runtimes needed for working with a codebase, and to aid in continuous integration and testing.

<details>
<summary> Details of the services in this container </summary>

- ROS2 humble with a base workspace `/home/ubuntu/ros2_ws/`;
- Support for arm64 (jetson orin nano) and amd64 architectures;
- Support for NVIDIA Docker runtime for linux hosts;
- VNC server that allows direct browser access (http://localhost:3080/), so nothing is required to install and use it;
- A `ssh` server, to allow direct access from outside (`ssh ubuntu@localhost -p 3022`);
- A web `vscode` server for easy remote access when deploying it on the robot (http://localhost:3081/);
- Automatic `xcode +` command executed on each attachment for local X forwarding;
- Custom environment and VScode configurations:
  - Open split terminals on launch;
  - Setup all environments variables automatically for running ROS;
  - Automatically open the VNC interface in a ROS tab;
  - Custom PS1 (terminal shell);
</details>

<div align="center">
  <img src="https://github.com/user-attachments/assets/6c085018-0b43-4f0e-9316-20bac5d0d4c1" alt="Fully loaded interface with the VNC client and multiple terminals on the bottom panel" style="text-align:center; width:70%">
  <br>
 Fully loaded interface with the VNC client and multiple terminals on the bottom panel.
</div>

## How to use?

### To develop locally, using `devcontainers` (local VScode)

<details>
<summary> Recommended for local development, with X11 sharing, etc.</summary>

- `git clone git@github.com:h3ct0r/ros2_devcontainer_docker_compose.git`
- Verify the compose file used in the container used in `.devcontainer/devcontaoiner.json`, given your operative system:
  ```json
  "dockerComposeFile": [
        "../compose_linux_host.yaml"
    ],
  ```
  - Can also be `../compose_macos_host.yaml` if you use MacOS
- Open folder with VScode using the dev containers plugin (https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
  - `control + shift + p`
  - Write `Dev Containers: Reopen in Container` or  `Dev Containers: Rebuild and Reopen in Container`

<div align="center">
  <img src="https://github.com/user-attachments/assets/784b06f7-8225-4be8-a2b7-e6e96b8cc376" alt="Fully loaded interface with the VNC client and multiple terminals on the bottom panel" style="text-align:center; width:70%">
  <br>
 How to open the repo using the Dev Containers plugin in VScode.
</div>
</details>


### Headless run with `docker compose` (remote Jetson headless)

<details>
  <summary>Recommended for remote development, as for example, deploying a dev machine on the robot.</summary>
  
- `git clone git@github.com:h3ct0r/ros2_devcontainer_docker_compose.git`
- `cd ros1_devcontainer_docker_compose`
- `BUILDKIT_PROGRESS=plain docker compose -f compose_jetson_host.yaml up --build`

`BUILDKIT_PROGRESS=plain` helps to visualize step by step output of each of the commands.
</details>

### Access to services

Once the container is up, the you can access the services via:

- VNC: http://localhost:3080
- VScode: http://localhost:3081
- SSH: `ssh ubuntu@localhost -p 3022`
  - user: `ubuntu`
  - pass: `ubuntu`
 
## Know issues

- The live preview opens a terminal with a message "cannot find shell for command XXXX". This can be safely ignored.
- The live preview will show a small box with a message "Please reopen the preview". This is fixed in the newest version of the live preview plugin.

## Links/References:

- https://www.youtube.com/watch?v=dihfA7Ol6Mw
- https://github.com/Tiryoh/docker-ros-desktop-vnc/
- https://github.com/atinfinity/nvidia-egl-desktop-ros2/
- https://www.reddit.com/r/ROS/comments/1gsoebe/dev_using_docker_containers/
- https://github.com/elkuno213/ros2-ws-template
- https://github.com/devrt/ros-devcontainer-vscode/

## License

MIT

**Free Software, Hell Yeah!**
