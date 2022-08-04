#!/usr/bin/env bash
# =============================================================================
# test-version-bump.sh -- Tests for scripts/version-bump.sh
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/version-bump.sh"

source "$REPO_ROOT/tests/test-harness.sh"

# ---------------------------------------------------------------------------
# Helper: create a temp workspace with package.json, package-lock.json, and
# an initialised git repo. Returns the workspace path.
#
# We set core.autocrlf=false and core.eol=lf so that git add behaves
# consistently on both Linux and Windows MSYS.
# ---------------------------------------------------------------------------
make_workspace() {
  local version="${1:-1.2.3}"
  local dir
  dir="$(mktemp -d)"

  printf '{"name":"test-pkg","version":"%s"}\n' "$version" > "$dir/package.json"
  printf '{"lockfileVersion":3,"packages":{}}\n'            > "$dir/package-lock.json"

  git -C "$dir" init -q
  git -C "$dir" config user.email "test@test.com"
  git -C "$dir" config user.name "Test"
  git -C "$dir" config core.autocrlf false
  git -C "$dir" config core.eol lf
  git -C "$dir" add package.json package-lock.json
  git -C "$dir" commit -q -m "init"

  echo "$dir"
}

# ---------------------------------------------------------------------------
# Run version-bump.sh inside a given directory.
# Sets globals: OUT RC
# ---------------------------------------------------------------------------
run_bump() {
  local dir="$1" bump="${2:-}"
  pushd "$dir" > /dev/null
  set +e
  OUT=$(bash "$SCRIPT" "$bump" 2>&1)
  RC=$?
  set -e
  popd > /dev/null
}

# Read the version field from package.json in a portable way (works on Windows
# and Linux — avoids node path resolution issues with /tmp on MSYS).
read_version() {
  local dir="$1"
  (cd "$dir" && node -p "require('./package.json').version")
}

# ---------------------------------------------------------------------------
# Suite 1 – Argument validation
# ---------------------------------------------------------------------------
suite "Argument validation"

TMP="$(make_workspace)"
run_bump "$TMP" ""
assert_exit_code "$RC" 1 "exits 1 when no argument provided"
assert_contains "$OUT" "Usage:" "prints usage hint when no argument given"
rm -rf "$TMP"

TMP="$(make_workspace)"
run_bump "$TMP" "hotfix"
assert_exit_code "$RC" 1 "exits 1 for invalid bump type 'hotfix'"
assert_contains "$OUT" "Invalid bump type" "prints error message for invalid type"
rm -rf "$TMP"

for TYPE in patch minor major; do
  TMP="$(make_workspace 1.0.0)"
  run_bump "$TMP" "$TYPE"
  assert_exit_code "$RC" 0 "'$TYPE' exits 0"
  rm -rf "$TMP"
done

# ---------------------------------------------------------------------------
# Suite 2 – Version computation
# ---------------------------------------------------------------------------
suite "Version computation"

TMP="$(make_workspace 1.2.3)"
run_bump "$TMP" "patch"
assert_eq "$(read_version "$TMP")" "1.2.4" "patch bump: 1.2.3 → 1.2.4"
rm -rf "$TMP"

TMP="$(make_workspace 1.2.3)"
run_bump "$TMP" "minor"
assert_eq "$(read_version "$TMP")" "1.3.0" "minor bump: 1.2.3 → 1.3.0"
rm -rf "$TMP"

TMP="$(make_workspace 1.2.3)"
run_bump "$TMP" "major"
assert_eq "$(read_version "$TMP")" "2.0.0" "major bump: 1.2.3 → 2.0.0"
rm -rf "$TMP"

TMP="$(make_workspace 2.1.0)"
run_bump "$TMP" "patch"
assert_eq "$(read_version "$TMP")" "2.1.1" "patch bump when patch is 0: 2.1.0 → 2.1.1"
rm -rf "$TMP"

TMP="$(make_workspace 0.9.8)"
run_bump "$TMP" "minor"
assert_eq "$(read_version "$TMP")" "0.10.0" "minor bump resets patch: 0.9.8 → 0.10.0"
rm -rf "$TMP"

TMP="$(make_workspace 3.4.5)"
run_bump "$TMP" "major"
assert_eq "$(read_version "$TMP")" "4.0.0" "major bump resets minor+patch: 3.4.5 → 4.0.0"
rm -rf "$TMP"

# ---------------------------------------------------------------------------
# Suite 3 – Git integration
# ---------------------------------------------------------------------------
suite "Git integration"

TMP="$(make_workspace 1.0.0)"
run_bump "$TMP" "patch"
COMMIT_MSG=$(git -C "$TMP" log -1 --pretty=%s)
assert_eq "$COMMIT_MSG" "chore: bump version to v1.0.1" "git commit message is correct"
TAG=$(git -C "$TMP" describe --tags --abbrev=0)
assert_eq "$TAG" "v1.0.1" "git tag v1.0.1 created"
rm -rf "$TMP"

TMP="$(make_workspace 2.3.4)"
run_bump "$TMP" "minor"
TAG=$(git -C "$TMP" describe --tags --abbrev=0)
PKG_VER=$(read_version "$TMP")
assert_eq "$TAG" "v$PKG_VER" "git tag matches package.json version"
rm -rf "$TMP"

# ---------------------------------------------------------------------------
# Suite 4 – Output messages
# ---------------------------------------------------------------------------
suite "Output messages"

TMP="$(make_workspace 1.0.0)"
run_bump "$TMP" "patch"
assert_contains "$OUT" "Current version: v1.0.0" "prints current version"
assert_contains "$OUT" "New version:     v1.0.1" "prints new version"
rm -rf "$TMP"

TMP="$(make_workspace 0.1.0)"
run_bump "$TMP" "major"
assert_contains "$OUT" "v1.0.0" "output contains the new major version"
rm -rf "$TMP"

# ---------------------------------------------------------------------------
# Suite 5 – Edge cases
# ---------------------------------------------------------------------------
suite "Edge cases"

TMP="$(make_workspace 0.0.1)"
run_bump "$TMP" "patch"
assert_eq "$(read_version "$TMP")" "0.0.2" "patch bump from 0.0.1 → 0.0.2"
rm -rf "$TMP"

TMP="$(make_workspace 99.99.99)"
run_bump "$TMP" "patch"
assert_eq "$(read_version "$TMP")" "99.99.100" "patch bump from 99.99.99 → 99.99.100"
rm -rf "$TMP"

test_summary
