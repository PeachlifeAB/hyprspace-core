#!/bin/bash
set -euo pipefail

ensure_gum_available() {
    if command -v gum >/dev/null 2>&1; then
        return 0
    fi

    echo "ERROR: gum is required for hyprspace deinit interactive mode. Install it and rerun hyprspace deinit." >&2
    return 1
}

render_banner() {
    if command -v gum >/dev/null 2>&1; then
        gum style --bold --foreground "#FAFAFA" --background "#E05252" --padding "0 1" "hyprspace deinit"
        gum style --foreground "#626262" "teardown and cleanup"
    else
        echo "hyprspace deinit"
        echo "teardown and cleanup"
    fi
}

render_section_header() {
    local title="$1"
    if command -v gum >/dev/null 2>&1; then
        gum style --bold --foreground "#E05252" "$title"
    else
        printf '%s\n' "$title"
    fi
}

render_bulleted_list() {
    local lines="$1"
    local line
    local printed=0

    if [ -z "$lines" ]; then
        printf '  • None\n'
        return 0
    fi

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        printf '  • %s\n' "$line"
        printed=1
    done <<<"$lines"

    if [ "$printed" -eq 0 ]; then
        printf '  • None\n'
    fi
}

render_summary() {
    local selected_optional="$1"

    render_section_header "Selected for removal"
    render_bulleted_list "$selected_optional"
    echo
    render_section_header "Always removed"
    printf '  • Hyprspace.app and AeroSpace.app\n'
    printf '  • CLI binaries and shell completions\n'
    printf '  • Launch agents and runtime sockets\n'
    printf '  • Homebrew packages (hyprspace, aerospace)\n'
    printf '  • Menu bar visibility restored\n'
}

render_completion() {
    echo
    render_section_header "Teardown complete"
    printf '  • Hyprspace and selected components have been removed\n'
    printf '  • Config backups saved to ~/hyprspace-backup.zip\n'
    printf '    (hidden copy at ~/hyprspace-backup.zip)\n'
}
