# Your workspace

This folder is mounted in the container as `~/ros2_ws` (`/home/ubuntu/ros2_ws`). If you can read this file from inside the container, the mount works.

- Put your ROS 2 packages in `src/`. Edit them on the host or in the container; they're the same files.
- `build/`, `install/` and `log/` are Docker volumes per distro (`ros2_dev_<distro>_build`, …), not folders here. Builds of different distros never mix.
- Your shell history is kept here as `.bash_history`.

Git ignores everything in this folder except this file. Keep your packages in their own repositories.

See [Getting started](../docs/getting-started.md#your-workspace) for building.
