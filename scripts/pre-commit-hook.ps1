Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Pre-commit checks for this repo (PowerShell variant)
# - gdformat --check
# - gdlint
# - no direct print() calls in scripts/ and apps/

if (-not (Get-Command gdformat -ErrorAction SilentlyContinue)) {
    Write-Error "gdformat not found; install via pip (pip install gdformat)"
    exit 1
}
Write-Host "Running gdformat --check..."
if (-not (& gdformat --check .)) {
    Write-Error "gdformat failed"
    exit 1
}

if (-not (Get-Command gdlint -ErrorAction SilentlyContinue)) {
    Write-Error "gdlint not found; install via pip (pip install gdlint)"
    exit 1
}
Write-Host "Running gdlint..."
if (-not (& gdlint .)) {
    Write-Error "gdlint failed"
    exit 1
}

Write-Host "Scanning for direct print() uses in scripts/ and apps/..."
$found = Get-ChildItem -Path .\scripts, .\apps -Recurse -Filter *.gd -ErrorAction SilentlyContinue | Select-String -Pattern 'print\(' -SimpleMatch
if ($found) {
    $found | ForEach-Object { Write-Error $_.ToString() }
    Write-Error "Direct print() calls found; use Log.* instead"
    exit 1
}

Write-Host "Pre-commit checks passed"