#!/bin/bash
set -euo pipefail

ensure_gum_available() {
    if command -v gum >/dev/null 2>&1; then
        return 0
    fi

    echo "ERROR: gum is required for hyprspace init interactive mode. Install it and rerun hyprspace init." >&2
    return 1
}

render_banner() {
    if command -v gum >/dev/null 2>&1; then
        gum style --bold --foreground "#FAFAFA" --background "#7D56F4" --padding "0 1" "hyprspace init"
        gum style --foreground "#626262" "first-run setup"
    else
        echo "hyprspace init"
        echo "first-run setup"
    fi
}

render_welcome() {
    render_section_header "Welcome"
    printf '%s\n' "Hyprspace uses macOS Accessibility features under the hood to manage windows."
    printf '%s\n' "Follow the macOS prompts during setup to enable any permissions Hyprspace requests in System Settings."
}

render_section_header() {
    local title="$1"
    if command -v gum >/dev/null 2>&1; then
        gum style --bold --foreground "#7D56F4" "$title"
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
    local mandatory="$2"
    local terminal_app="$3"
    local music_app="$4"
    local browser_app="$5"
    local apply_flags="$6"

    render_section_header "Optional integrations"
    render_bulleted_list "$selected_optional"
    echo
    render_section_header "Mandatory steps"
    render_bulleted_list "$mandatory"
    echo
    render_section_header "App preferences"
    printf '  • Terminal: %s\n' "$terminal_app"
    printf '  • Music: %s\n' "$music_app"
    printf '  • Browser: %s\n' "$browser_app"

    if [ -n "$apply_flags" ]; then
        echo
        render_section_header "Apply flags"
        render_bulleted_list "$apply_flags"
    fi
}

render_completion() {
    echo
    render_section_header "Setup complete"
    printf '  • Hyprspace.app is running\n'
    printf '  • Config: %s\n' "${HOME}/.config/hyprspace/config.toml"
}
