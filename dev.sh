#!/usr/bin/env bash
# Runs the ROS 2 development container with the right setup for this machine.
#
#   ./dev.sh [command] [options]
#
# Commands:
#   up         start the container (default)
#   down       stop and remove it (build volumes are kept)
#   shell      open a shell in the running container
#   status     show the selected settings and why
#   logs       follow the container's logs
#   build      build the image locally instead of pulling it
#   configure  only record the selection in .env, or with --output FILE write the
#              merged compose file there (used by the devcontainers)
#
# Settings come from .env (see .env.example), then the environment, then options.
# GPU, MODE, NETWORK and DEVICES default to "auto", which detects this machine:
#   --distro humble|jazzy|lyrical     --target base|robot|desktop|full
#   --gpu auto|none|nvidia|jetson     --mode auto|rootful|rootless
#   --network auto|host|bridge        --devices auto|none|all
#   --platform native|linux/amd64|linux/arm64
#   --compose-extra FILE[:FILE...]    overlays of your own, appended after the selected ones
#
# ROS_DISTRO is only taken from .env and --distro: a ROS setup sourced on the host
# exports its own ROS_DISTRO, which must not pick the container's distro.
set -euo pipefail

cd "$(dirname "$0")"

BLOCK_START="# >>> written by ./dev.sh"
BLOCK_END="# <<< written by ./dev.sh"
SETTINGS="ROS_DISTRO TARGET GPU MODE NETWORK DEVICES PLATFORM COMPOSE_EXTRA"
EXTRA_KEYS="NOVNC_PORT CODE_SERVER_PORT SSH_PORT"

die() {
    echo "dev.sh: $*" >&2
    exit 1
}

usage() {
    sed -n '2,25p' "$0" | sed -E 's/^# ?//'
}

# Sets a setting and remembers where it came from: set_value NAME VALUE SOURCE
set_value() {
    printf -v "val_$1" '%s' "$2"
    printf -v "src_$1" '%s' "$3"
}
get() { eval "printf '%s' \"\${val_$1:-}\""; }
source_of() { eval "printf '%s' \"\${src_$1:-}\""; }

# --- 1. defaults, .env, environment, options ----------------------------------
set_value ROS_DISTRO jazzy default
set_value TARGET desktop default
for name in GPU MODE NETWORK DEVICES; do set_value "$name" auto default; done
set_value PLATFORM native default
set_value COMPOSE_EXTRA "" default

if [ -f .env ]; then
    in_block=0
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            "$BLOCK_START"*) in_block=1; continue ;;
            "$BLOCK_END"*) in_block=0; continue ;;
        esac
        [ "$in_block" = 1 ] && continue
        line=${line%%#*}
        case "$line" in *=*) ;; *) continue ;; esac
        key=$(printf '%s' "${line%%=*}" | tr -d '[:space:]')
        value=$(printf '%s' "${line#*=}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g; s/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/')
        case " $SETTINGS $EXTRA_KEYS " in
            *" $key "*) [ -n "$value" ] && set_value "$key" "$value" .env ;;
        esac
    done < .env
fi

for name in $SETTINGS $EXTRA_KEYS; do
    [ "$name" = ROS_DISTRO ] && continue
    if [ -n "${!name:-}" ]; then set_value "$name" "${!name}" environment; fi
done

command=up
output=""
while [ $# -gt 0 ]; do
    case "$1" in
        up | down | shell | status | logs | build | configure) command=$1 ;;
        -h | --help | help) usage; exit 0 ;;
        --distro | --target | --gpu | --mode | --network | --devices | --platform | --compose-extra | --output)
            [ $# -ge 2 ] || die "$1 needs a value"
            case "$1" in
                --distro) set_value ROS_DISTRO "$2" option ;;
                --target) set_value TARGET "$2" option ;;
                --gpu) set_value GPU "$2" option ;;
                --mode) set_value MODE "$2" option ;;
                --network) set_value NETWORK "$2" option ;;
                --devices) set_value DEVICES "$2" option ;;
                --platform) set_value PLATFORM "$2" option ;;
                --compose-extra) set_value COMPOSE_EXTRA "$2" option ;;
                --output) output=$2 ;;
            esac
            shift ;;
        *) die "unknown argument '$1' (see ./dev.sh --help)" ;;
    esac
    shift
done

check() {
    local name=$1 allowed=" $2 "
    case "$allowed" in
        *" $(get "$name") "*) ;;
        *) die "$name='$(get "$name")' from $(source_of "$name") is not one of:$allowed" ;;
    esac
}
check ROS_DISTRO "humble jazzy lyrical"
check TARGET "base robot desktop full"
check GPU "auto none nvidia jetson"
check MODE "auto rootful rootless"
check NETWORK "auto host bridge"
check DEVICES "auto none all"
check PLATFORM "native linux/amd64 linux/arm64"

# --- 2. resolve "auto" ------------------------------------------------------------
command -v docker >/dev/null || die "docker is not installed"
engine=$(docker version --format '{{.Server.Version}}' 2>/dev/null) || die "the Docker daemon isn't reachable"
os=$(uname -s)

version_at_least() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]; }

resolve() {  # resolve NAME VALUE REASON
    set_value "$1" "$2" "auto: $3"
}

if [ "$(get MODE)" = auto ]; then
    case "$(docker info --format '{{.SecurityOptions}}' 2>/dev/null)" in
        *rootless*) resolve MODE rootless "docker info lists rootless" ;;
        *) resolve MODE rootful "Docker runs as root" ;;
    esac
fi

if [ "$(get NETWORK)" = auto ]; then
    if [ "$os" = Darwin ]; then
        resolve NETWORK bridge "Docker Desktop on macOS"
    elif [ "$(get MODE)" = rootless ] && ! version_at_least 29.5 "$engine"; then
        resolve NETWORK bridge "rootless Docker $engine can't share the host network (needs 29.5+)"
    else
        resolve NETWORK host "Linux"
    fi
fi

if [ "$(get DEVICES)" = auto ]; then
    if [ "$os" = Darwin ]; then
        resolve DEVICES none "macOS"
    elif [ "$(get MODE)" = rootless ]; then
        resolve DEVICES none "rootless (set DEVICES=all after installing configs/udev/99-ros-dev.rules)"
    else
        resolve DEVICES all "rootful Linux"
    fi
fi

if [ "$(get GPU)" = auto ]; then
    if [ "$os" = Darwin ]; then
        resolve GPU none "macOS"
    elif [ -f /etc/nv_tegra_release ]; then
        resolve GPU jetson "Jetson (/etc/nv_tegra_release)"
    elif docker info --format '{{json .Runtimes}}' 2>/dev/null | grep -q '"nvidia"'; then
        resolve GPU nvidia "Docker has the nvidia runtime"
    elif grep -qs 'nvidia.com/gpu' /etc/cdi/* /var/run/cdi/*; then
        resolve GPU nvidia "NVIDIA CDI spec found"
    else
        resolve GPU none "no NVIDIA runtime or CDI spec"
    fi
fi

# --- 3. compose files ---------------------------------------------------------
files="compose.yaml"
if [ "$(get NETWORK)" = host ]; then
    files="$files:compose/net-host.yaml"
    [ "$(get MODE)" = rootful ] && files="$files:compose/host-pid.yaml"
else
    files="$files:compose/net-bridge.yaml"
fi
[ "$(get DEVICES)" = all ] && files="$files:compose/devices.yaml"
[ "$(get MODE)" = rootless ] && files="$files:compose/rootless.yaml"
case "$(get GPU)" in
    nvidia) files="$files:compose/gpu-nvidia.yaml" ;;
    jetson) files="$files:compose/gpu-jetson.yaml" ;;
esac
if [ "$os" = Darwin ]; then files="$files:compose/macos.yaml"; else files="$files:compose/x11-host.yaml"; fi
[ "$(get PLATFORM)" != native ] && files="$files:compose/platform.yaml"

# Overlays of your own (COMPOSE_EXTRA, colon-separated, relative to this directory) go last
IFS=: read -ra extra <<< "$(get COMPOSE_EXTRA)"
for file in ${extra[@]+"${extra[@]}"}; do  # empty-array safe under set -u in bash < 4.4
    [ -n "$file" ] || continue
    [ -f "$file" ] || die "COMPOSE_EXTRA from $(source_of COMPOSE_EXTRA): '$file' is not a file (paths are relative to $PWD)"
    files="$files:$file"
done

export COMPOSE_FILE="$files" COMPOSE_PATH_SEPARATOR=":"
export ROS_DISTRO="$(get ROS_DISTRO)" TARGET="$(get TARGET)"
if [ "$(get PLATFORM)" != native ]; then export PLATFORM="$(get PLATFORM)"; else unset PLATFORM; fi

# --- 4. host display (Linux) -------------------------------------------------------
# GUI apps on the host screen need its DISPLAY and X11 cookie. A shell without them (ssh,
# some launchers, a VS Code started elsewhere) borrows the logged-in desktop session's.
# The cookie is copied to a fixed path, rewritten in place on every run: the session's
# file gets a new name at each login, and a container restarted after a reboot would
# otherwise point to a file that no longer exists.
display_source=""
if [ "$os" != Darwin ]; then
    display_source=environment
    session_env=$(systemctl --user show-environment 2>/dev/null || true)
    for var in DISPLAY XAUTHORITY; do
        if [ -z "${!var:-}" ]; then
            value=$(printf '%s\n' "$session_env" | sed -n "s/^$var=//p")
            if [ -n "$value" ]; then
                export "$var=$value"
                display_source="desktop session"
            fi
        fi
    done
    if [ -z "${XAUTHORITY:-}" ] && [ -r "$HOME/.Xauthority" ]; then export XAUTHORITY="$HOME/.Xauthority"; fi
    [ -n "${DISPLAY:-}" ] || display_source="none found, using :0"

    export X11_COOKIE="$HOME/.cache/ros2_dev/Xauthority"
    mkdir -p "$(dirname "$X11_COOKIE")"
    if [ -n "${XAUTHORITY:-}" ] && [ -r "$XAUTHORITY" ]; then
        cat "$XAUTHORITY" > "$X11_COOKIE"
    elif [ ! -f "$X11_COOKIE" ]; then
        : > "$X11_COOKIE"
    fi

    # Fallback for a stale or missing cookie (e.g. after logging out and in): let processes
    # of this host user in without one. Reaches the container's ubuntu (uid 1000) when this
    # user is uid 1000, and root under rootless Docker. Lasts until the X server restarts.
    case "$command" in
        up | configure)
            if [ -n "${DISPLAY:-}" ] && command -v xhost >/dev/null; then
                xhost "+SI:localuser:$(id -un)" >/dev/null 2>&1 || true
            fi ;;
    esac
fi

# Records the selection at the end of .env (created from .env.example if missing),
# so plain `docker compose` commands use it too
write_env() {
    [ -f .env ] || cp .env.example .env
    local tmp
    tmp=$(mktemp)
    awk -v start="$BLOCK_START" -v end="$BLOCK_END" '
        index($0, start) == 1 { skip = 1; next }
        index($0, end) == 1 { skip = 0; next }
        !skip' .env > "$tmp"
    {
        cat "$tmp"
        echo "$BLOCK_START: the last selection, for plain docker compose (do not edit) >>>"
        echo "COMPOSE_FILE=$COMPOSE_FILE"
        echo "COMPOSE_PATH_SEPARATOR=:"
        echo "ROS_DISTRO=$ROS_DISTRO"
        echo "TARGET=$TARGET"
        [ -n "${PLATFORM:-}" ] && echo "PLATFORM=$PLATFORM"
        [ -n "${X11_COOKIE:-}" ] && echo "X11_COOKIE=$X11_COOKIE"
        echo "$BLOCK_END <<<"
    } > .env
    rm -f "$tmp"
}

print_status() {
    local name
    for name in $SETTINGS; do
        printf '  %-13s %-14s %s\n' "$name" "$(get "$name")" "($(source_of "$name"))"
    done
    [ -n "$display_source" ] && printf '  %-13s %-14s %s\n' "display" "${DISPLAY:-:0}" "($display_source)"
    printf '  %-13s %s\n' "compose" "${COMPOSE_FILE//:/ }"
}

print_access() {
    local novnc=3080 code=3081 ssh=3022 user=ubuntu
    if [ "$(get NETWORK)" = bridge ]; then
        novnc=$(get NOVNC_PORT); novnc=${novnc:-3080}
        code=$(get CODE_SERVER_PORT); code=${code:-3081}
        ssh=$(get SSH_PORT); ssh=${ssh:-3022}
    fi
    [ "$(get MODE)" = rootless ] && user=root
    echo
    case "$TARGET" in
        desktop | full)
            echo "  desktop      http://localhost:$novnc/?autoconnect=true"
            echo "  code-server  http://localhost:$code" ;;
    esac
    echo "  ssh          ssh -p $ssh $user@localhost"
    echo "  shell        ./dev.sh shell"
}

# --- 5. run -----------------------------------------------------------------------
case "$command" in
    status)
        echo "ROS $ROS_DISTRO, image ${IMAGE:-h3ct0rdcc/ros2_dev}:$ROS_DISTRO-$TARGET, Docker $engine on $os"
        print_status ;;
    configure)
        if [ -n "$output" ]; then
            mkdir -p "$(dirname "$output")"
            docker compose config > "$output"
            echo "dev.sh: wrote $output"
        else
            write_env
        fi
        print_status ;;
    up)
        write_env
        print_status
        docker compose up -d
        print_access ;;
    down) docker compose down ;;
    logs) docker compose logs -f ;;
    shell) docker compose exec ros2 bash -l ;;
    build)
        platform=$(get PLATFORM)
        [ "$platform" = native ] && platform="linux/$(docker version --format '{{.Server.Arch}}')"
        docker buildx bake --load --set "*.platform=$platform" "$ROS_DISTRO-$TARGET" ;;
esac
