#!/bin/sh

# Show available disk space as PERCENT FREE for the Data volume.
# We intentionally use native macOS `df` output so it matches tools like `ds`.

# Prefer the Data volume on modern macOS; fallback to /.
mount_point="/System/Volumes/Data"
if [ ! -d "$mount_point" ]; then
    mount_point="/"
fi

# df -k format: Filesystem 1K-blocks Used Available Capacity iused ifree %iused Mounted on
# We want Capacity column (e.g. 99%) and convert to percent-free.
# Capacity = used%, free% = 100 - used%
used_pct_raw="$(/bin/df -k "$mount_point" | /usr/bin/awk 'NR==2 { gsub(/%/,"",$5); print $5 }')"
if ! echo "$used_pct_raw" | grep -Eq '^[0-9]+$'; then
    sketchybar --set disk_free label="err"
    exit 0
fi
used_pct="$((used_pct_raw))"
free_pct=$((100 - used_pct))

if [ "$free_pct" -lt 0 ]; then free_pct=0; fi
if [ "$free_pct" -gt 100 ]; then free_pct=100; fi

sketchybar --set disk_free label="${free_pct}%"
