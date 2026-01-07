# Contributing

Thanks for contributing! A few quick notes to set up your development environment and ensure a smooth workflow.

## Required dev tools
- Python + pip (for `gdformat` and `gdlint`; prefer installing `gdtoolkit` which provides both)
- pre-commit
- Godot 4.5+ (for running headless tests)

Install tools (example):
- pip install pre-commit "gdtoolkit==4.*"
- pre-commit install

## Pre-commit hooks
We use pre-commit to run formatting and lint checks before commits. The hooks will:
- Run `gdformat --check` (ensure code is formatted)
- Run `gdlint` (static linting for GDScript)
- Verify there are no direct `print()` calls in `scripts/` or `apps/` (use `Log.info()`/`Log.warn()`/`Log.error()` instead)

If a hook fails locally, fix the reported issue and re-run `pre-commit run --all-files` to verify.

## Running tests locally
- Windows (PowerShell): set `GODOT_BIN` if Godot isn't on PATH, then run `.










Thanks — we appreciate your contributions!- Link the PR to an issue or `tasklist.md` entry when appropriate.- Include tests for behavior changes (add tests under `tests/` and update the headless suite if needed).- Keep PRs small and focused. We prefer one logical change per PR.## Making PRsThe test runner will run `gdformat --check`, `gdlint`, an optional `verify_parse` pass, and the Godot headless test suite.- Linux/macOS (Bash): `export GODOT_BIN=/path/to/godot` then `./scripts/run_tests.sh`un_tests.ps1`