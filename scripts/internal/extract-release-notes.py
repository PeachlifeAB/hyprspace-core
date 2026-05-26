#!/usr/bin/env python3
import re
import sys

def extract_release_notes(version, changelog_path='CHANGELOG.md'):
    with open(changelog_path) as f:
        changelog = f.read()

    pattern = r'## \[' + re.escape(version) + r'\][^\n]*\n(.*?)(?=\n## \[|\Z)'
    match = re.search(pattern, changelog, re.DOTALL)

    if not match:
        print(f"error: version {version} not found in {changelog_path}", file=sys.stderr)
        sys.exit(1)

    return match.group(1).strip()

if __name__ == '__main__':
    version = sys.argv[1] if len(sys.argv) > 1 else None
    changelog = sys.argv[2] if len(sys.argv) > 2 else 'CHANGELOG.md'

    if not version:
        print("usage: extract-release-notes.py <version> [changelog]", file=sys.stderr)
        sys.exit(1)

    print(extract_release_notes(version, changelog))
