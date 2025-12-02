#!/bin/sh

# Workaround for issue when image is created with "docker commit".
# Thanks to @SaadRana17
# https://github.com/Tiryoh/docker-ros2-desktop-vnc/issues/131#issuecomment-2184156856

sudo find /tmp -maxdepth 1 -type f -name '.X*' -delete
sudo find /tmp/.X11-unix/ -maxdepth 1 -type f -name '*' -delete

#touch vnc_script_executed_$(date '+%Y-%m-%d_%H-%M-%S')

if [ $(uname -m) = "aarch64" ]; then
    LD_PRELOAD=/lib/aarch64-linux-gnu/libgcc_s.so.1 vncserver :2 -fg -geometry 1920x1080 -depth 24 -localhost no
else
    vncserver :2 -fg -geometry 1920x1080 -depth 24 -localhost no -SecurityTypes None --I-KNOW-THIS-IS-INSECURE
fi