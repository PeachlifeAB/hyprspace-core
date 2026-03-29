# Hyprspace Release Runbook

## Repo layout for new contributors

| Path | What it is |
|------|-----------|
| `patches/series` | Ordered list of all Hyprspace patches over AeroSpace |
| `patches/hyprspace/` | Patch files (Swift, shell, config changes) |
| `AeroSpace/` | Ephemeral upstream checkout — rebuilt by `refresh-workspace.sh`, never treated as the long-term source of truth |
| `tests/` | Integration and release verification scripts |
| `devutils/` | Local build, install, and helper scripts |
| `script/` | Release automation, validation, and distribution scripts |
| `docs/public/` | Canonical source-owned public README/legal/release-note templates |
| `script/public-release-surface-manifest.json` | Authoritative mapping from canonical source files to public destinations |
| `product.conf` | Canonical identity constants (GitHub repo, tap repo, tag prefix) |
| `version.txt` | Hyprspace release version (semver e.g. `0.1.0`) — bump before releasing |
| `revision.txt` | Short AeroSpace base commit hash — written automatically by `refresh-workspace.sh` |
| `aerospace_version.txt` | AeroSpace base version (e.g. `0.20.3-Beta`) — update when rebasing upstream |
| `../homebrew-hyprspace/` | Public Homebrew tap sibling repo clone |
| `../hyprspace-releases/` | Public releases sibling repo clone |

## Public authority map

External users cannot read the private source repo. Public authority therefore lives on these surfaces:

| Surface | Audience purpose | Authority |
|---------|------------------|-----------|
| `homebrew-hyprspace/README.md` | Install / update / uninstall | Public Homebrew landing page |
| `homebrew-hyprspace/Casks/hyprspace.rb` | Install metadata | Generated from the published zip |
| `hyprspace-releases/README.md` | Manual downloads and release landing page | Public releases repo root README |
| `hyprspace-releases/LEGAL.md` | Legal disclosure and signing status | Public releases repo root legal page |
| `hyprspace-releases/LICENSE` | Public license text | Public releases repo root LICENSE |
| GitHub release body | Version-specific announcement | Generated release notes rendered from `docs/public/release-notes.md`, aligned with `CHANGELOG.md` |
| Release zip `README.md` / `docs/legal.md` / `legal/*` | Offline inspection | Bundled public payload |

## Flows at a glance

| Who | Goal | Command |
|-----|------|---------|
| Developer | Build and install locally | `./devutils/install-local.sh` |
| Developer | Refresh AeroSpace checkout with patches | `./utils/refresh-workspace.sh` |
| Maintainer | Sync local public surfaces into sibling repos | `python3 ./script/validate-public-release-surface.py --phase local-sync` |
| Maintainer | Read-only validation of the full release pipeline | `./script/publish-hyprspace-release.sh --validate-only` |
| Maintainer | Publish a new release | `./script/publish-hyprspace-release.sh` |

## Before any release — legal gate

- [ ] `LICENSE` exists at repo root
- [ ] `docs/legal.md` documents fork attribution, third-party notices, and signing/notarization status
- [ ] `docs/public/` templates reflect the current public disclosure model
- [ ] Any new Hyprspace-specific dependencies are recorded in `docs/legal.md`

## Version scheme

| Context | Format | Example |
|---------|--------|---------|
| Release tag | `version.txt` only | `0.1.0` |
| Dev/local build | `version.txt-<hyprspace-git-short-hash>` | `0.1.0-a3f9b2c` |
| `hyprspace --version` | dev version + AeroSpace base | `Hyprspace v0.1.0-a3f9b2c (AeroSpace 0.20.3-Beta)` |

Release version is always read from `version.txt` on the public release path. Do not add or rely on a version flag for stable release publication.

## Stable-only policy

Only the `hyprspace` stable cask is published. `hyprspace-dev` is not part of the public stable release flow.

## Publishing a release

### Required local clones

```bash
git clone git@github.com:PeachlifeAB/homebrew-hyprspace.git ../homebrew-hyprspace
git clone git@github.com:PeachlifeAB/hyprspace-releases.git ../hyprspace-releases
```

### Dry run

```bash
./script/publish-hyprspace-release.sh --validate-only
```

This is the read-only release validation path. The script owns the detailed preflight and artifact-freshness checks.

### Local public-surface sync

```bash
python3 ./script/validate-public-release-surface.py --phase local-sync
```

This materializes the canonical public surfaces into the sibling public repos for review or pre-publish prep.

### Real publish

```bash
./script/publish-hyprspace-release.sh
```

This is the only maintainer-facing release command. For the exact release sequence, see the script and the public release-surface manifest.

### Guardrails

- The public release path must remain script-owned; avoid manual copying or ad hoc edits in sibling repos.
- `./script/publish-hyprspace-release.sh --validate-only` must remain the read-only validation path.
- The release is not considered successful unless `./script/publish-hyprspace-release.sh` completes.

## Development-only local artifact cask rehearsal

The final public release flow does **not** use a `file://` cask URL. If you need a local-only rehearsal while developing release automation, keep it clearly separate from the public release path and never commit a local file URL into the public tap repo.

## Repo layout (three repos)

| Repo | Visibility | Purpose |
|------|-----------|---------|
| `PeachlifeAB/hyprspace-core` | **Private** | Source code, docs, canonical templates, release automation, and patches |
| `PeachlifeAB/hyprspace-releases` | **Public** | Public README / legal / license surfaces and versioned release zips |
| `PeachlifeAB/homebrew-hyprspace` | **Public** | Public Homebrew tap README and generated cask |

Identity constants live in `product.conf` and are the only place repo names should be changed during a migration.

## Contributor install

Contributors install locally via `./devutils/install-local.sh` — see [`docs/installing-from-source.md`](installing-from-source.md).
