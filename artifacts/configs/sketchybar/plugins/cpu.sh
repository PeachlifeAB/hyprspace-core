#!/bin/sh

# Minimal CPU usage plugin (overall CPU).
# Uses the instantaneous aggregate CPU usage from `top`.
# NOTE: This yields 0-100% for overall machine utilization.

cpu_line="$(top -l 1 -n 0 2>/dev/null | awk '/CPU usage/ { print; exit }')"

# Example: "CPU usage: 7.82% user, 6.85% sys, 85.31% idle"
# Parse user+sys robustly by splitting on spaces/commas/%.
percent="$(printf '%s' "$cpu_line" | awk -F'[% ,]+' '
  /CPU usage/ {
    u=$3; s=$5;
    if (u=="" || u ~ /[^0-9.]/) u=0;
    if (s=="" || s ~ /[^0-9.]/) s=0;
    v=u+s;
    if (v<0) v=0;
    if (v>100) v=100;
    printf "%.0f", v;
    exit
  }
')"

case "$percent" in
'' | *[!0-9]*) percent=0 ;;
esac

if [ "$percent" -lt 0 ]; then percent=0; fi
if [ "$percent" -gt 100 ]; then percent=100; fi

sketchybar --set cpu_usage label="${percent}%"
