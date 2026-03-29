# Hyprspace {{VERSION}}

All notable changes for this release are documented using the Keep a Changelog format.

## Added
- Non-prompting `--accessibility-status` self-checks for both the installed app and CLI/runtime surfaces.
- Versioned release zip: {{ZIP_URL}}

## Changed
- Release validation now proves patch-stack input state and Accessibility approval state from the same repo-state surface.
- Workspace refresh now prints patch-input preflight before replaying the patch stack.

## Fixed
- Local install/release validation now catches malformed accessibility-status patch replay before the install boundary.
- Runtime validation for `app-menu` and `new-window-or-open Terminal.app` is reproven against the current release artifacts.

## Documentation
- Releases README: {{RELEASES_README_URL}}
- Legal disclosure: {{RELEASES_LEGAL_URL}}
- License: {{RELEASES_LICENSE_URL}}

## Notes
- Hyprspace releases are currently not code-signed or notarized by Apple.
