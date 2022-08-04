#!/usr/bin/env bash
# =============================================================================
# run-tests.sh -- Entry point for the test suite.
#
# Usage:
#   bash tests/run-tests.sh            # run all suites
#   bash tests/run-tests.sh version   # run only suites whose filename matches
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="$REPO_ROOT/tests"
FILTER="${1:-}"

TOTAL_SUITES=0
FAILED_SUITES=0
FAILED_NAMES=()

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║       gh-actions-toolkit test suite          ║"
echo "╚══════════════════════════════════════════════╝"

for TEST_FILE in "$TESTS_DIR"/test-*.sh; do
  BASENAME="$(basename "$TEST_FILE")"

  if [[ -n "$FILTER" && "$BASENAME" != *"$FILTER"* ]]; then
    continue
  fi

  echo ""
  echo "┌─ Running: $BASENAME"

  TOTAL_SUITES=$((TOTAL_SUITES + 1))
  set +e
  bash "$TEST_FILE"
  EXIT_CODE=$?
  set -e

  if [[ $EXIT_CODE -eq 0 ]]; then
    printf "└─ \033[32mPASSED\033[0m\n"
  else
    printf "└─ \033[31mFAILED\033[0m (exit %d)\n" "$EXIT_CODE"
    FAILED_SUITES=$((FAILED_SUITES + 1))
    FAILED_NAMES+=("$BASENAME")
  fi
done

echo ""
echo "══════════════════════════════════════════════"
printf "  Suites run: %d\n" "$TOTAL_SUITES"
if [[ $FAILED_SUITES -eq 0 ]]; then
  printf "  \033[32mAll suites passed.\033[0m\n"
else
  printf "  \033[31m%d suite(s) failed:\033[0m\n" "$FAILED_SUITES"
  for NAME in "${FAILED_NAMES[@]}"; do
    printf "    - %s\n" "$NAME"
  done
fi
echo "══════════════════════════════════════════════"
echo ""

if [[ $FAILED_SUITES -gt 0 ]]; then
  exit 1
fi
