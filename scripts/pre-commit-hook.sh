#!/usr/bin/env bash
set -euo pipefail

# Pre-commit checks for this repo
# Prefer installing `gdtoolkit` which provides `gdformat` and `gdlint`
# - gdformat --check
# - gdlint
# - no direct print() calls in scripts/ and apps/

if ! command -v gdformat >/dev/null 2>&1; then
  echo "gdformat not found; please install (pip install \"gdtoolkit==4.*\")"
  exit 1
fi

echo "Running gdformat --check..."
if ! gdformat --check .; then
  echo "gdformat --check failed"
  exit 1
fi

if ! command -v gdlint >/dev/null 2>&1; then
  echo "gdlint not found; please install (pip install \"gdtoolkit==4.*\")"
  exit 1
fi

echo "Running gdlint..."
if ! gdlint .; then
  echo "gdlint failed"
  exit 1
fi

echo "Scanning for direct print() uses in scripts/ and apps/..."
if grep -R --line-number --exclude-dir=debug --include="*.gd" "print(" scripts apps >/dev/null 2>&1; then
  echo "Direct print() found in scripts/apps. Use Log.* instead."
  grep -R --line-number --exclude-dir=debug --include="*.gd" "print(" scripts apps || true
  exit 1
fi

echo "Pre-commit checks passed"