#!/bin/sh
# TigerVNC on display :2 (port 5902), served in the browser by noVNC on :3080.
# VNC_PASSWORD empty: no VNC authentication. Set it to require a password.

# Stale lock and socket of display :2 (crash, or an image made with "docker commit")
if [ "$(id -u)" = 0 ]; then
    rm -f /tmp/.X2-lock /tmp/.X11-unix/X2
else
    sudo -n rm -f /tmp/.X2-lock /tmp/.X11-unix/X2
fi

mkdir -p "${HOME}/.vnc"
if [ -n "${VNC_PASSWORD}" ]; then
    echo "${VNC_PASSWORD}" | tigervncpasswd -f > "${HOME}/.vnc/passwd"
    chmod 600 "${HOME}/.vnc/passwd"
    set -- -SecurityTypes VncAuth
else
    set -- -SecurityTypes None --I-KNOW-THIS-IS-INSECURE
fi

# Jetson/arm64: preload libgcc_s, otherwise Xvnc aborts on pthread_cancel
if [ "$(uname -m)" = "aarch64" ]; then
    export LD_PRELOAD=/lib/aarch64-linux-gnu/libgcc_s.so.1
fi

exec vncserver :2 -fg -geometry 1920x1080 -depth 24 -localhost no "$@"
