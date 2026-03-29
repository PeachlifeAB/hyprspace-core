#!/bin/sh

# RAM usage plugin.
# Displays percent used as an integer 0-100.

# macOS vm_stat reports page counts; compute used% = (active+wired+compressed) / (total) * 100
page_size="$(/usr/bin/vm_stat | /usr/bin/awk '/page size of/ { gsub(/\./, "", $8); print $8; exit }')"
if [ -z "$page_size" ]; then page_size=4096; fi

stats="$(/usr/bin/vm_stat)"

pages_free="$(printf '%s' "$stats" | /usr/bin/awk '/Pages free/ { gsub(/\./, "", $3); print $3; exit }')"
pages_active="$(printf '%s' "$stats" | /usr/bin/awk '/Pages active/ { gsub(/\./, "", $3); print $3; exit }')"
pages_inactive="$(printf '%s' "$stats" | /usr/bin/awk '/Pages inactive/ { gsub(/\./, "", $3); print $3; exit }')"
pages_speculative="$(printf '%s' "$stats" | /usr/bin/awk '/Pages speculative/ { gsub(/\./, "", $3); print $3; exit }')"
pages_wired="$(printf '%s' "$stats" | /usr/bin/awk '/Pages wired down/ { gsub(/\./, "", $4); print $4; exit }')"
pages_compressed="$(printf '%s' "$stats" | /usr/bin/awk '/Pages occupied by compressor/ { gsub(/\./, "", $5); print $5; exit }')"

# Default missing fields to 0
for v in pages_free pages_active pages_inactive pages_speculative pages_wired pages_compressed; do
    eval "val=\${$v}"
    case "$val" in
    '' | *[!0-9]*) eval "$v=0" ;;
    esac
done

# total pages includes all categories
pages_total=$((pages_free + pages_active + pages_inactive + pages_speculative + pages_wired + pages_compressed))
if [ "$pages_total" -le 0 ]; then
    sketchybar --set ram_usage label="0%"
    exit 0
fi

pages_used=$((pages_active + pages_wired + pages_compressed))
used_pct=$(((pages_used * 100) / pages_total))

if [ "$used_pct" -lt 0 ]; then used_pct=0; fi
if [ "$used_pct" -gt 100 ]; then used_pct=100; fi

sketchybar --set ram_usage label="${used_pct}%"
