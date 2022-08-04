#!/usr/bin/env bash
# =============================================================================
# test-harness.sh -- Minimal bash test framework.
# =============================================================================

PASS=0
FAIL=0
SKIP=0
_CURRENT_SUITE=""

suite() {
  _CURRENT_SUITE="$1"
  echo ""
  echo "── $1 ──────────────────────────────────────"
}

_pass() {
  PASS=$((PASS + 1))
  printf "  \033[32m✓\033[0m %s\n" "$1"
}

_fail() {
  FAIL=$((FAIL + 1))
  printf "  \033[31m✗\033[0m %s\n" "$1"
  printf "      expected: %s\n" "$2"
  printf "      got:      %s\n" "$3"
}

skip() {
  SKIP=$((SKIP + 1))
  printf "  \033[33m-\033[0m %s (skipped: %s)\n" "$1" "${2:-no reason}"
}

assert_eq() {
  local got="$1" expected="$2" label="$3"
  if [[ "$got" == "$expected" ]]; then
    _pass "$label"
  else
    _fail "$label" "$expected" "$got"
  fi
}

assert_not_empty() {
  local got="$1" label="$2"
  if [[ -n "$got" ]]; then
    _pass "$label"
  else
    _fail "$label" "<non-empty>" "(empty)"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    _pass "$label"
  else
    _fail "$label" "contains '$needle'" "$haystack"
  fi
}

assert_exit_code() {
  local got="$1" expected="$2" label="$3"
  if [[ "$got" -eq "$expected" ]]; then
    _pass "$label"
  else
    _fail "$label" "exit $expected" "exit $got"
  fi
}

assert_file_exists() {
  local path="$1" label="$2"
  if [[ -f "$path" ]]; then
    _pass "$label"
  else
    _fail "$label" "file exists: $path" "not found"
  fi
}

test_summary() {
  local total=$((PASS + FAIL + SKIP))
  echo ""
  echo "════════════════════════════════════════════"
  printf "  Tests: %d  |  " "$total"
  printf "\033[32mPassed: %d\033[0m  |  " "$PASS"
  if [[ $FAIL -gt 0 ]]; then
    printf "\033[31mFailed: %d\033[0m  |  " "$FAIL"
  else
    printf "Failed: %d  |  " "$FAIL"
  fi
  printf "Skipped: %d\n" "$SKIP"
  echo "════════════════════════════════════════════"
  echo ""

  if [[ $FAIL -gt 0 ]]; then
    exit 1
  fi
}
