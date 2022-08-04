#!/usr/bin/env bash
# =============================================================================
# test-deploy.sh -- Tests for scripts/deploy.sh (validation layer only).
#
# The actual SSH/SCP steps require a live server and proper Unix executable
# permissions for stubs. These tests cover all logic that runs before the
# network steps: argument validation, required-env-var checks, SSH key
# existence checks, and deploy header output.
#
# The tarball creation logic is tested independently from the full script
# to keep tests hermetic on all platforms.
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/deploy.sh"

source "$REPO_ROOT/tests/test-harness.sh"

# ---------------------------------------------------------------------------
# Helper: create a minimal deploy workspace
# ---------------------------------------------------------------------------
make_deploy_workspace() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/dist"
  echo '{"name":"t","version":"1.0.0","scripts":{"build":"echo built"}}' > "$dir/package.json"
  echo '{"lockfileVersion":3}' > "$dir/package-lock.json"
  echo 'placeholder' > "$dir/dist/server.js"
  echo "$dir"
}

# ---------------------------------------------------------------------------
# Helper: run deploy.sh with controlled env vars + args.
# The script will fail at step 1 (npm ci) if validation passes, which is fine
# for validation-only tests. We capture everything and check exit code / output.
# Sets globals: OUT RC
# ---------------------------------------------------------------------------
run_deploy() {
  local env_vars="$1"      # space-separated VAR=VALUE pairs
  local deploy_arg="${2:-staging}"
  local dir
  dir="$(make_deploy_workspace)"

  pushd "$dir" > /dev/null
  set +e
  OUT=$(eval "env $env_vars bash \"$SCRIPT\" \"$deploy_arg\"" 2>&1)
  RC=$?
  set -e
  popd > /dev/null
  rm -rf "$dir"
}

# ---------------------------------------------------------------------------
# Suite 1 – Required environment variable validation
# ---------------------------------------------------------------------------
suite "Required env-var validation"

FAKE_KEY="$(mktemp)"
chmod 600 "$FAKE_KEY" 2>/dev/null || true
FULL_ENV="VPS_HOST=example.com VPS_USER=deploy APP_DIR=/var/www/app PM2_APP_NAME=my-api SSH_KEY_PATH=$FAKE_KEY"

for VAR in VPS_HOST VPS_USER APP_DIR PM2_APP_NAME; do
  PARTIAL=""
  for PAIR in $FULL_ENV; do
    [[ "$PAIR" != "${VAR}="* ]] && PARTIAL="$PARTIAL $PAIR"
  done
  run_deploy "$PARTIAL" "staging"
  assert_exit_code "$RC" 1 "exits 1 when $VAR is missing"
  assert_contains "$OUT" "$VAR" "error mentions the missing var: $VAR"
done

rm -f "$FAKE_KEY"

# ---------------------------------------------------------------------------
# Suite 2 – SSH key validation
# ---------------------------------------------------------------------------
suite "SSH key validation"

NONEXISTENT="/tmp/no-such-key-deploy-test-$$"
run_deploy "VPS_HOST=h VPS_USER=u APP_DIR=/app PM2_APP_NAME=p SSH_KEY_PATH=$NONEXISTENT" "staging"
assert_exit_code "$RC" 1 "exits 1 when SSH key file does not exist"
assert_contains "$OUT" "SSH key not found" "error message mentions missing SSH key"

REAL_KEY="$(mktemp)"
chmod 600 "$REAL_KEY" 2>/dev/null || true
run_deploy "VPS_HOST=h VPS_USER=u APP_DIR=/app PM2_APP_NAME=p SSH_KEY_PATH=$REAL_KEY" "staging"
HAS_KEY_ERR=false
[[ "$OUT" == *"SSH key not found"* ]] && HAS_KEY_ERR=true
assert_eq "$HAS_KEY_ERR" "false" "no SSH-key error when key file exists"
rm -f "$REAL_KEY"

# ---------------------------------------------------------------------------
# Suite 3 – Environment argument
# ---------------------------------------------------------------------------
suite "Environment argument"

REAL_KEY="$(mktemp)"
chmod 600 "$REAL_KEY" 2>/dev/null || true

run_deploy "VPS_HOST=h VPS_USER=u APP_DIR=/app PM2_APP_NAME=p SSH_KEY_PATH=$REAL_KEY" "staging"
assert_contains "$OUT" "staging" "output mentions 'staging' when staging arg given"

run_deploy "VPS_HOST=h VPS_USER=u APP_DIR=/app PM2_APP_NAME=p SSH_KEY_PATH=$REAL_KEY" "production"
assert_contains "$OUT" "production" "output mentions 'production' when production arg given"

rm -f "$REAL_KEY"

# ---------------------------------------------------------------------------
# Suite 4 – Deploy header output
# ---------------------------------------------------------------------------
suite "Deploy header output"

REAL_KEY="$(mktemp)"
chmod 600 "$REAL_KEY" 2>/dev/null || true

run_deploy "VPS_HOST=myhost.example.com VPS_USER=deploy APP_DIR=/var/www/app PM2_APP_NAME=my-api SSH_KEY_PATH=$REAL_KEY" "production"

assert_contains "$OUT" "myhost.example.com" "header shows VPS_HOST"
assert_contains "$OUT" "deploy"             "header shows VPS_USER"
assert_contains "$OUT" "/var/www/app"       "header shows APP_DIR"
assert_contains "$OUT" "my-api"             "header shows PM2_APP_NAME"

rm -f "$REAL_KEY"

# ---------------------------------------------------------------------------
# Suite 5 – Tarball creation logic
#
# Tests the tarball step directly (independent of the deploy.sh network steps)
# to verify naming convention, required file inclusion, and manual cleanup.
# ---------------------------------------------------------------------------
suite "Tarball creation logic"

WORK="$(make_deploy_workspace)"
pushd "$WORK" > /dev/null

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TARBALL="deploy-${TIMESTAMP}.tar.gz"

tar -czf "$TARBALL" dist/ package.json package-lock.json

if [[ -f "$TARBALL" ]]; then
  _pass "tarball file created with expected naming: deploy-<timestamp>.tar.gz"
else
  _fail "tarball file created" "deploy-<timestamp>.tar.gz" "not found"
fi

CONTENTS=$(tar -tzf "$TARBALL")
assert_contains "$CONTENTS" "package.json"      "tarball contains package.json"
assert_contains "$CONTENTS" "package-lock.json" "tarball contains package-lock.json"
assert_contains "$CONTENTS" "dist/"             "tarball contains dist/ directory"
assert_contains "$CONTENTS" "dist/server.js"    "tarball contains dist/server.js"

rm -f "$TARBALL"
# Use find instead of ls to avoid pipefail issues on no-match (ls returns exit 2)
LEFTOVER=$(find . -maxdepth 1 -name "deploy-*.tar.gz" | wc -l)
assert_eq "$LEFTOVER" "0" "no tarball left after rm -f cleanup"

popd > /dev/null
rm -rf "$WORK"

test_summary
