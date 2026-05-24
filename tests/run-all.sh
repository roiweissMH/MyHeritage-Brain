#!/usr/bin/env bash
# Runs every test-*.sh in this directory. Exits non-zero if any test fails.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_FAILED=0

shopt -s nullglob
for test_file in "$TESTS_DIR"/test-*.sh; do
  echo "Running: $(basename "$test_file")"
  if ! bash "$test_file"; then
    TOTAL_FAILED=$((TOTAL_FAILED + 1))
  fi
  echo
done

if [[ "$TOTAL_FAILED" -gt 0 ]]; then
  echo "FAILED: $TOTAL_FAILED test file(s) reported failures."
  exit 1
fi
echo "All test files passed."
