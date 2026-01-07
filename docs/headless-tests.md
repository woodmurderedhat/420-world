# Headless Testing Infrastructure

The project uses a comprehensive headless test suite to verify core systems without instantiating a windowed environment. This ensures CI/CD compatibility and rapid validation of logic.

## Running Tests

### Option 1: PowerShell Script (Recommended)
Use the included helper script which handles output redirection and exit codes:
```powershell
./run_tests.ps1
```

### Option 2: Manual Command
To run the tests manually, point the Godot executable to the project path with the `--headless` and `--headless-tests` arguments.

**PowerShell:**
```powershell
& "c:\Program Files\Godot\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64.exe" --headless --path . --headless-tests
```
*Note: Adjust the Godot executable path to match your installation.*

## Test Suite Scope
The suite (`tests/comprehensive_headless.gd`) verifies:
1. **Service Registration**: Ensures strict initialization order of Autoloads.
2. **EventBus**: Pub/Sub mechanics and signal decoupling.
3. **SaveManager**: JSON serialization, schema versioning, and persistence.
4. **SettingsManager**: Configuration overrides and type safety.
5. **AppRegistry**: Manifest parsing and app discovery.
6. **ThemeManager**: Signal propagation for theming.
7. **WindowManager & UI**: Headless verification of window creation, focus management, and Taskbar/StartMenu logic.
8. **Memory Leaks**: Basic node count monitoring during window operations.

## Troubleshooting
- **Exit Code 0**: Success.
- **Exit Code 1**: Failure. Check `test_stderr.txt` for specific error messages (logged via `Log.error`).
- **Logs**: Detailed execution logs are mirrored to `res://debug/logs/` (e.g., `debug/logs/log_<timestamp>.txt`).
