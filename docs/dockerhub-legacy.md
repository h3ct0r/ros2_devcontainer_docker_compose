# Moved to h3ct0rdcc/ros2_dev

These Humble images are now built from **[github.com/h3ct0r/ros2_devcontainer_docker_compose](https://github.com/h3ct0r/ros2_devcontainer_docker_compose)** and published as **[h3ct0rdcc/ros2_dev](https://hub.docker.com/r/h3ct0rdcc/ros2_dev)**, together with Jazzy and Lyrical.

The tags here keep receiving the same Humble images until Humble's end of life (May 2027):

| Tag here | Same image as |
|---|---|
| `base`, `robot`, `desktop`, `full` | `h3ct0rdcc/ros2_dev:humble-<target>` |
| `latest` | `h3ct0rdcc/ros2_dev:humble-full` |
| `amd64`, `arm64` | `h3ct0rdcc/ros2_dev:humble-full`, one architecture |

Please switch to `h3ct0rdcc/ros2_dev:humble-<target>`.
