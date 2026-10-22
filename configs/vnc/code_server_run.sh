#!/bin/sh
# code-server on :3081. CODE_SERVER_PASSWORD set: password login, empty: no auth.
if [ -n "${CODE_SERVER_PASSWORD}" ]; then
    export PASSWORD="${CODE_SERVER_PASSWORD}"
    auth=password
else
    auth=none
fi

exec /usr/bin/code-server --auth "${auth}" --disable-telemetry --disable-update-check --bind-addr 0.0.0.0:3081
