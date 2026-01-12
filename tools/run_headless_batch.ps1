$dir = "test_runs"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
$exe = "C:\Program Files\Godot\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64.exe"
for ($i=1; $i -le 20; $i++) {
    $n = "{0:00}" -f $i
    $out = "$dir\run_$n.txt"
    $err = "$dir\run_$n.err.txt"
    Write-Host "Starting run $i -> $out"
    & $exe --headless --path "C:\Users\Stephanus\Documents\420-world" --headless-tests 2>&1 | Out-File -FilePath $out -Encoding utf8
    Write-Host "Completed run $i"
    Start-Sleep -Milliseconds 200
}
Write-Host "Batch finished. Outputs: $dir\run_*.txt"