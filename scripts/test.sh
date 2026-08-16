#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/heart-rate-menu-test.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT INT TERM

swiftc \
  "$ROOT/Sources/HeartRateMenu/HeartRateMeasurement.swift" \
  "$ROOT/Tests/main.swift" \
  -o "$TEST_ROOT/measurement-tests"
"$TEST_ROOT/measurement-tests"
