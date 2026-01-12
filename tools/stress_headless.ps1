$runs = 20
$report = "test_runs/stress_report.txt"
if (-not (Test-Path "test_runs")) { New-Item -ItemType Directory -Path "test_runs" | Out-Null }
if (Test-Path $report) { Remove-Item $report }
for ($i=1; $i -le $runs; $i++) {
    Write-Host "Stress run $i/$runs"
    # Run the batch which writes results to test_output.txt
    cmd /c .\test_runner.bat
    Start-Sleep -Milliseconds 200
    # Read output
    $txt = Get-Content test_output.txt -Raw -ErrorAction SilentlyContinue
    if ($txt -match "WARNING: ObjectDB instances leaked" -or $txt -match "resources still in use") {
        Write-Host "Leak detected on run $i"
        $out = "test_runs/leak_run_{0:00}.txt" -f $i
        $txt | Out-File -FilePath $out -Encoding utf8
        "LEAK DETECTED on run $i. Output saved to $out" | Out-File -FilePath $report -Append -Encoding utf8
        break
    }
    if ($txt -match "HEADLESS: All tests passed." -and -not ($txt -match "WARNING: ObjectDB instances leaked")) {
        ("Run {0}: OK" -f $i) | Out-File -FilePath $report -Append -Encoding utf8
    } else {
        ("Run {0}: FAIL or warnings present" -f $i) | Out-File -FilePath $report -Append -Encoding utf8
    }
}
Write-Host "Stress run complete. Report: $report"