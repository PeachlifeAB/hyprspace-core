#!/bin/sh

NAME="${NAME:-docker}"
DOCKER_BIN="${DOCKER_BIN:-docker}"

resolve_docker_bin() {
    if command -v "$DOCKER_BIN" >/dev/null 2>&1; then
        printf "%s" "$DOCKER_BIN"
        return 0
    fi

    for candidate in /opt/homebrew/bin/docker /usr/local/bin/docker; do
        if [ -x "$candidate" ]; then
            printf "%s" "$candidate"
            return 0
        fi
    done

    return 1
}

docker_bin="$(resolve_docker_bin)" || {
    sketchybar --set "$NAME" label="●" label.color=0xffff0000
    exit 0
}

statuses="$($docker_bin ps --format '{{.Status}}' 2>/dev/null)"
rc=$?

if [ "$rc" -ne 0 ]; then
    sketchybar --set "$NAME" label="⚠" label.color=0xffff0000
    exit 0
fi

if [ -z "$statuses" ]; then
    sketchybar --set "$NAME" label="●" label.color=0xff00ff00
    exit 0
fi

unhealthy_count="$(printf "%s\n" "$statuses" | grep -c '(unhealthy)' || true)"
starting_count="$(printf "%s\n" "$statuses" | grep -c '(health: starting)' || true)"

if [ "$unhealthy_count" -gt 0 ] || [ "$starting_count" -gt 0 ]; then
    sketchybar --set "$NAME" label="●" label.color=0xffff0000
else
    sketchybar --set "$NAME" label="●" label.color=0xff00ff00
fi
