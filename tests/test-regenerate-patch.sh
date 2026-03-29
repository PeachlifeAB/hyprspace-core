#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
source "$root_dir/tests/_common.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
fixture_root="$(make_temp_dir)"
register_cleanup_path "$fixture_root"
trap cleanup_paths_on_exit EXIT

fixture_repo="$fixture_root/repo"
mkdir -p "$fixture_repo/devutils" "$fixture_repo/patches/test" "$fixture_repo/patches" "$fixture_repo/AeroSpace/src"

cp "$root_dir/devutils/regenerate-patch.sh" "$fixture_repo/devutils/regenerate-patch.sh"
chmod +x "$fixture_repo/devutils/regenerate-patch.sh"

cat >"$fixture_repo/aerospace_version.txt" <<'EOF'
fixture-base
EOF

cat >"$fixture_repo/patches/series" <<'EOF'
test/001-alpha.patch
test/002-beta.patch
EOF

cat >"$fixture_repo/patches/test/001-alpha.patch" <<'EOF'
# Summary: alpha baseline

diff --git a/src/keep.txt b/src/keep.txt
index 1111111..2222222 100644
--- a/src/keep.txt
+++ b/src/keep.txt
@@ -1 +1 @@
-base keep
+-alpha keep

diff --git a/src/delete-me.txt b/src/delete-me.txt
index 3333333..4444444 100644
--- a/src/delete-me.txt
+++ b/src/delete-me.txt
@@ -1 +1 @@
-delete me
+-delete me later
EOF

cat >"$fixture_repo/patches/test/002-beta.patch" <<'EOF'
# Summary: beta add file

diff --git a/src/add-later.txt b/src/add-later.txt
new file mode 100644
--- /dev/null
+++ b/src/add-later.txt
@@ -0,0 +1 @@
+beta file
EOF

cat >"$fixture_repo/AeroSpace/src/keep.txt" <<'EOF'
base keep
EOF

cat >"$fixture_repo/AeroSpace/src/delete-me.txt" <<'EOF'
delete me
EOF

cat >"$fixture_repo/AeroSpace/src/add-later.txt" <<'EOF'
beta file
EOF

git init "$fixture_repo/AeroSpace" >/dev/null 2>&1
git -C "$fixture_repo/AeroSpace" config user.name fixture >/dev/null
git -C "$fixture_repo/AeroSpace" config user.email fixture@example.com >/dev/null
git -C "$fixture_repo/AeroSpace" add src/keep.txt src/delete-me.txt
git -C "$fixture_repo/AeroSpace" commit -m "fixture base" >/dev/null 2>&1
git -C "$fixture_repo/AeroSpace" tag vfixture-base

cat >"$fixture_root/expected-alpha.patch" <<'EOF'
# Summary: alpha baseline

diff --git a/src/keep.txt b/src/keep.txt
--- a/src/keep.txt
+++ b/src/keep.txt
@@ -1 +1 @@
-base keep
+alpha keep updated

diff --git a/src/delete-me.txt b/src/delete-me.txt
deleted file mode 100644
--- a/src/delete-me.txt
+++ /dev/null
@@ -1 +0,0 @@
-delete me

diff --git a/src/new-owned.txt b/src/new-owned.txt
new file mode 100644
--- /dev/null
+++ b/src/new-owned.txt
@@ -0,0 +1 @@
+new alpha file
EOF

cat >"$fixture_repo/AeroSpace/src/keep.txt" <<'EOF'
alpha keep updated
EOF
rm "$fixture_repo/AeroSpace/src/delete-me.txt"
cat >"$fixture_repo/AeroSpace/src/new-owned.txt" <<'EOF'
new alpha file
EOF

before_head="$(git -C "$fixture_repo/AeroSpace" rev-parse HEAD)"
before_status="$(git -C "$fixture_repo/AeroSpace" status --short)"

echo "[step] unrelated edits are rejected by default"
cat >"$fixture_repo/AeroSpace/src/unrelated.txt" <<'EOF'
unrelated edit
EOF
if REGENERATE_PATCH_ROOT="$fixture_repo" bash "$fixture_repo/devutils/regenerate-patch.sh" 001-alpha --add-file src/new-owned.txt >"$fixture_root/unrelated.out" 2>&1; then
    echo "[fail] regenerate-patch unexpectedly accepted unrelated edits"
    exit 1
fi
grep -q "unrelated edits outside the allowed patch surface" "$fixture_root/unrelated.out"
rm "$fixture_repo/AeroSpace/src/unrelated.txt"

echo "[step] ownership collisions are rejected"
if REGENERATE_PATCH_ROOT="$fixture_repo" bash "$fixture_repo/devutils/regenerate-patch.sh" 001-alpha --add-file src/add-later.txt >"$fixture_root/collision.out" 2>&1; then
    echo "[fail] regenerate-patch unexpectedly accepted an ownership collision"
    exit 1
fi
grep -q "already owned by" "$fixture_root/collision.out"

echo "[step] generated artifact noise is ignored"
mkdir -p "$fixture_repo/AeroSpace/.deps/bin" "$fixture_repo/AeroSpace/.shell-completion/zsh"
cat >"$fixture_repo/AeroSpace/.deps/bin/tool" <<'EOF'
generated helper
EOF
cat >"$fixture_repo/AeroSpace/.shell-completion/zsh/_fixture" <<'EOF'
generated completion
EOF

echo "[step] regenerate patch with explicit added file"
REGENERATE_PATCH_ROOT="$fixture_repo" bash "$fixture_repo/devutils/regenerate-patch.sh" 001-alpha --add-file src/new-owned.txt >"$fixture_root/regenerate.out" 2>&1
diff -u "$fixture_root/expected-alpha.patch" "$fixture_repo/patches/test/001-alpha.patch"

echo "[step] unchanged regeneration reports no-op"
REGENERATE_PATCH_ROOT="$fixture_repo" bash "$fixture_repo/devutils/regenerate-patch.sh" 001-alpha --add-file src/new-owned.txt >"$fixture_root/noop.out" 2>&1
grep -q '^patch unchanged$' "$fixture_root/noop.out"

after_head="$(git -C "$fixture_repo/AeroSpace" rev-parse HEAD)"
after_status="$(git -C "$fixture_repo/AeroSpace" status --short)"
test "$before_head" = "$after_head"
test "$before_status" = "$after_status"

echo "[ok] regenerate-patch regression test passed"
