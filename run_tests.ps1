Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve Godot binary (use GODOT_BIN env var if set)
$godotPath = $env:GODOT_BIN
if (-not $godotPath) {
    $godotPath = "C:\Program Files\Godot\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64.exe"
}
if (-not (Test-Path $godotPath)) {
    Write-Error "Godot binary not found; set the GODOT_BIN environment variable to the Godot executable"
    exit 1
}

# Run format check
Write-Host "Running gdformat --check..."
try {
    & gdformat --check . | Out-Null
} catch {
    Write-Error "gdformat failed: $_"
    exit 1
}

# Run linter
Write-Host "Running gdlint..."
try {
    & gdlint . | Out-Null
} catch {
    Write-Error "gdlint failed: $_"
    exit 1
}

# Optional parse/scene verification (if script exists)
$verifyScript = "res://tests/verify_parse.gd"
if (Test-Path ".\tests\verify_parse.gd") {
    Write-Host "Running Godot parse/scene verification..."
    $argsVerify = "--headless --path . --script $verifyScript"
    $pVerify = Start-Process -FilePath $godotPath -ArgumentList $argsVerify -NoNewWindow -Wait -PassThru -RedirectStandardOutput verify_stdout.txt -RedirectStandardError verify_stderr.txt
    if ($pVerify.ExitCode -ne 0) {
        Write-Error "Parse verification failed (see verify_stderr.txt)"
        exit $pVerify.ExitCode
    }
}

# Run headless tests
Write-Host "Running Godot headless tests..."
$args = "--headless --path . --headless-tests"
$p = Start-Process -FilePath $godotPath -ArgumentList $args -NoNewWindow -Wait -PassThru -RedirectStandardOutput test_stdout.txt -RedirectStandardError test_stderr.txt
Write-Host "Exit Code: $($p.ExitCode)"
exit $p.ExitCode
