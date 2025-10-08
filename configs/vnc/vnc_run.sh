#!/bin/sh

# Workaround for issue when image is created with "docker commit".
# Thanks to @SaadRana17
# https://github.com/Tiryoh/docker-ros2-desktop-vnc/issues/131#issuecomment-2184156856

if [ -e /tmp/.X2-lock ]; then
    rm -f /tmp/.X2-lock
fi
if [ -e /tmp/.X11-unix/X2 ]; then
    rm -f /tmp/.X11-unix/X2
fi

if [ $(uname -m) = "aarch64" ]; then
    LD_PRELOAD=/lib/aarch64-linux-gnu/libgcc_s.so.1 vncserver :2 -fg -geometry 1920x1080 -depth 24
else
    vncserver :2 -fg -geometry 1920x1080 -depth 24
fi