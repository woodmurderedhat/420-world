#!/usr/bin/env bash
set -euo pipefail

# scripts/run_tests.sh
# Usage: export GODOT_BIN=/path/to/godot ; ./scripts/run_tests.sh

GODOT_BIN="${GODOT_BIN:-godot}"

if ! command -v "$GODOT_BIN" &> /dev/null; then
  echo "Godot binary not found; set GODOT_BIN env var to the Godot executable"
  exit 1
fi

if ! command -v gdformat >/dev/null 2>&1; then
  echo "gdformat not found; please install (pip install \"gdtoolkit==4.*\")"
  exit 1
fi

echo "Running gdformat --check..."
if ! gdformat --check . ; then
  echo "gdformat failed"
  exit 1
fi

if ! command -v gdlint >/dev/null 2>&1; then
  echo "gdlint not found; please install (pip install \"gdtoolkit==4.*\")"
  exit 1
fi

echo "Running gdlint..."
if ! gdlint . ; then
  echo "gdlint failed"
  exit 1
fi

if [ -f "tests/verify_parse.gd" ]; then
  echo "Running Godot parse/scene verification..."
  "$GODOT_BIN" --headless --path . --script res://tests/verify_parse.gd > verify_stdout.txt 2> verify_stderr.txt || { echo "Parse verification failed"; exit 1; }
fi

echo "Running Godot headless tests..."
"$GODOT_BIN" --headless --path . --headless-tests > test_stdout.txt 2> test_stderr.txt || exit $?
