# Godot 4.7 Test Runner Failure Detection

`tools/invoke_godot_test.ps1` is the generic blocking runner for one Godot
script or scene gate. Existing calls remain valid: requiring a completion marker
is opt-in.

## Default safety contract

- Uses the Godot 4.7 GUI executable, never the console wrapper.
- Redirects `APPDATA` and `LOCALAPPDATA` into the run evidence directory before
  starting either import or test processes. Therefore `user://` does not resolve
  to the player's normal profile.
- Rejects a concurrent headless/game process for the same absolute project and
  executable.
- Applies a finite timeout.
- On timeout, stops only the process tree it started after verifying the
  configured executable and absolute project path.
- Any post-exit cleanup is limited to verified Godot descendants of that started
  process. It never enumerates another worktree as a cleanup target.
- Retains stdout, stderr, Godot log and `result.json` outside the repository.

## False-green prevention

The runner audits stdout, stderr and the Godot log after the process exits.

These diagnostics fail the run even if Godot returned exit code `0`:

- `SCRIPT ERROR`
- `Parse Error` / `Parser Error`
- `Runtime Error`
- Godot failures to load or parse a script

An optional literal completion marker can be required:

```powershell
pwsh -File tools/invoke_godot_test.ps1 `
  -TestScript res://tests/smoke_test.gd `
  -ExpectedCompletionMarker "SMOKE_TEST_COMPLETE" `
  -TimeoutSeconds 600
```

If `-ExpectedCompletionMarker` is omitted, old calls keep their previous
exit-code behavior while still gaining script-error detection and user-data
isolation.

## Runner exit codes

| Code | Meaning |
| ---: | --- |
| Godot nonzero code | The completed Godot process failed normally. |
| `0` | Godot exited zero, no audited script error occurred, and any required marker was found. |
| `124` | Timeout. |
| `125` | A verified descendant runtime was found after completion and cleaned, or remained. |
| `126` | Import/bootstrap could not produce a usable result. |
| `127` | Godot exited zero but emitted an audited script/parser/runtime error. |
| `128` | Godot exited zero but the required completion marker was absent. |

Every machine-readable result contains the stable summary fields:

- `status`
- `exit_code`
- `timed_out`
- `script_error_count`
- `marker_found`
- `duration`

The detailed result also retains `process_exit_code`, `runner_exit_code`,
`first_script_error`, log paths, isolated profile paths, cleanup PIDs and any
remaining verified descendant PIDs.

## Focused proof

The following fixtures are intentionally tiny and contain no game production
logic:

- `tests/fixtures/godot_test_runner/script_error_exit_zero.gd`
- `tests/fixtures/godot_test_runner/missing_marker.gd`
- `tests/fixtures/godot_test_runner/normal_with_marker.gd`

Run:

```powershell
pwsh -File tools/invoke_godot_test_failure_detection_self_test.ps1 `
  -GodotPath "C:\path\to\Godot_v4.7-stable_win64.exe"
```

The expected result is fail / fail / pass:

1. Script error plus a real Godot exit `0` becomes runner exit `127`.
2. Missing required marker becomes runner exit `128`.
3. Normal completion becomes runner exit `0`.

The self-test also compares the player's campaign/current-run save fingerprints
before and after, verifies isolated profile paths, and verifies that every case
leaves zero scoped Godot processes.
