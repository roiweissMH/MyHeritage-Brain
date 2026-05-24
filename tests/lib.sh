#!/usr/bin/env bash
# Shared assertion helpers for shell-based tests.
# Tests should `source` this file and use the helpers below.

set -euo pipefail

TESTS_RUN=0
TESTS_FAILED=0

assert_eq() {
  local actual="$1" expected="$2" msg="${3:-}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "$actual" != "$expected" ]]; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: ${msg:-(no message)}"
    echo "    expected: $expected"
    echo "    actual:   $actual"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "$haystack" != *"$needle"* ]]; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: ${msg:-(no message)}"
    echo "    needle not found: $needle"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "$haystack" == *"$needle"* ]]; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: ${msg:-(no message)}"
    echo "    needle should be absent: $needle"
  fi
}

assert_file_exists() {
  local path="$1" msg="${2:-}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ ! -f "$path" ]]; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: ${msg:-file missing}: $path"
  fi
}

assert_file_absent() {
  local path="$1" msg="${2:-}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ -e "$path" ]]; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: ${msg:-file should not exist}: $path"
  fi
}

test_summary() {
  local name="${1:-tests}"
  echo "  $name: $TESTS_RUN run, $TESTS_FAILED failed"
  if [[ "$TESTS_FAILED" -gt 0 ]]; then
    exit 1
  fi
}
