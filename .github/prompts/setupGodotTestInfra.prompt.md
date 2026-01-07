---
name: setupGodotTestInfra
description: Sets up file-backed logging and headless testing infrastructure for Godot.
argument-hint: Ensure you have the Godot CLI available for running tests
---
Set up a robust logging and headless testing infrastructure for this Godot 4.x project.

IMPORTANT: after understanding the scope of the project run the tests and fix the errors. If you're not seeing any errors then you're not testing everything.

1. **LogManager**:

   - Create a `scripts/log_manager.gd` autoload that writes logs to timestamped files in `res://debug/logs`.
   - Implement `info`, `warn`, and `error` methods that mirror to the console and to disk.
   - Register it in `project.godot` (as the first autoload).
2. **Error Handling**:

   - Refactor key system scripts (managers, core runtime) to use this `LogManager` (e.g., `Log.error()`) instead of `push_error()` to ensure critical failures are persisted.
3. **Headless Test Suite**:

   - Create a single comprehensive test script (`tests/comprehensive_headless.gd`) that validates:
     - Service registration (Autoloads).
     - Core systems (EventBus, Save system, Settings).
     - UI Managers (if applicable in headless mode).
   - Ensure the script can be triggered via a custom CLI argument (e.g., `--headless-tests`).
   - The script must exit with code 0 for success and 1 for failure.
4. **Documentation**:

   - Write `docs/headless-tests.md` documenting the exact PowerShell/Shell command to run these tests using the Godot executable path (e.g., from `.vscode/settings.json`).
