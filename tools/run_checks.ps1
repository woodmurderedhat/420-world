Write-Host "Starting Quality Checks..." -ForegroundColor Cyan

# Check for gdtoolkit
if (-not (Get-Command "gdlint" -ErrorAction SilentlyContinue)) {
    Write-Warning "gdlint not found. Install via 'pip install gdtoolkit'"
    # exit 1 # Soft fail for now as user might not have it
} else {
    Write-Host "Running gdlint..." -ForegroundColor Green
    gdlint .
    if ($LASTEXITCODE -ne 0) { 
        Write-Error "Linting failed."
        exit 1 
    }
}

# Check for gdformat
if (Get-Command "gdformat" -ErrorAction SilentlyContinue) {
    Write-Host "Checking formatting (dry-run)..." -ForegroundColor Green
    gdformat . --check
    if ($LASTEXITCODE -ne 0) { 
        Write-Warning "Formatting issues found. Run 'gdformat .' to fix."
        # exit 1
    }
}

Write-Host "Static checks completed." -ForegroundColor Cyan
