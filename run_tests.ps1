$godotPath = "c:\Program Files\Godot\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64.exe"
$args = "--headless --path . --headless-tests"
Write-Host "Running Godot tests..."
$p = Start-Process -FilePath $godotPath -ArgumentList $args -NoNewWindow -Wait -PassThru -RedirectStandardOutput test_stdout.txt -RedirectStandardError test_stderr.txt
Write-Host "Exit Code: $($p.ExitCode)"
