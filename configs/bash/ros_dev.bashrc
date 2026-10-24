# ROS 2 development shell, sourced from ~/.bashrc.

# Rootless Docker starts `docker exec` sessions with umask 0000 (world-writable files)
[ "$(umask)" = 0000 ] && umask 022

# Values resolved at container start by /entrypoint.sh (middleware, domain, Zenoh).
# They only fill in what is not already set, so an explicit export still wins.
if [ -r /etc/ros_dev.env ]; then
    while IFS='=' read -r _key _value; do
        [ -n "$_key" ] && [ -z "${!_key+x}" ] && eval "export ${_key}=${_value}"
    done < /etc/ros_dev.env
    unset _key _value
fi
export ROS_DISTRO=${ROS_DISTRO:-humble}
export ROS_WORKSPACE=${ROS_WORKSPACE:-/home/ubuntu/ros2_ws}

source "/opt/ros/${ROS_DISTRO}/setup.bash"
[ -f "${ROS_WORKSPACE}/install/setup.bash" ] && source "${ROS_WORKSPACE}/install/setup.bash"
[ -f /usr/share/colcon_cd/function/colcon_cd.sh ] && source /usr/share/colcon_cd/function/colcon_cd.sh
[ -f /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash ] && source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash
export _colcon_cd_root="${ROS_WORKSPACE}"

# Gazebo Classic (full target): its own models and plugins. Without them gzserver looks
# up model://sun in the online model database and stalls at startup.
[ -f /usr/share/gazebo/setup.sh ] && source /usr/share/gazebo/setup.sh

# Python venv created with --system-site-packages, so apt and ROS modules stay visible
[ -f /home/ubuntu/.py3/bin/activate ] && source /home/ubuntu/.py3/bin/activate
export PATH="${HOME}/.local/bin:${PATH}"

# Compiler cache kept in the mounted workspace, so it survives container rebuilds
export CCACHE_DIR="${ROS_WORKSPACE}/.ccache"

# History kept in the mounted workspace
HISTFILE="${ROS_WORKSPACE}/.bash_history"
HISTSIZE=9999
HISTFILESIZE=99999
HISTCONTROL=ignoredups:erasedups

export LESS='-R'
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

PS1='\[\e[38;5;216m\]\u\[\e[38;5;160m\]@\[\e[38;5;202m\]\h \[\e[38;5;131m\]\w \[\033[0m\]$ '
