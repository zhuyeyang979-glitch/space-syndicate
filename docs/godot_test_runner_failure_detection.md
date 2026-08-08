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
- Captures stdout and stderr from the process byte streams before decoding,
  retains both `*.raw.bin` files, their SHA-256/length metadata, normalized text
  logs, the Godot log, and `result.json` outside the repository.

## False-green prevention

The runner audits stdout, stderr and the Godot log after the process exits. Raw
stdout/stderr must both complete. UTF-8 is decoded strictly; UTF-16 LE/BE is
accepted only with its BOM and then normalized to UTF-8 text. A decoding error,
decoded U+0000, or U+FFFD replacement evidence fails closed. Structural zero
bytes in a valid UTF-16 stream are recorded but are not mistaken for decoded
NUL characters.

These diagnostics fail the run even if Godot returned exit code `0`:

- `SCRIPT ERROR`
- `Parse Error` / `Parser Error`
- `Runtime Error`
- Godot failures to load or parse a script
- generic Godot `ERROR:` diagnostics
- every unclassified `WARNING:`, including an invalid UID warning

The Godot log is treated as an independent mirror. Identical diagnostics in
stdout/stderr and the Godot log are fingerprinted and counted once rather than
silently ignored or double-counted.

An optional literal completion marker can be required:

```powershell
pwsh -File tools/invoke_godot_test.ps1 `
  -TestScript res://tests/smoke_test.gd `
  -ExpectedCompletionMarker "SMOKE_TEST_COMPLETE" `
  -TimeoutSeconds 600
```

If `-ExpectedCompletionMarker` is omitted, marker absence is not a failure. All
raw-capture, decoding, error, warning, user-data isolation, timeout, and process
cleanup gates still apply.

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
| `129` | Raw capture was incomplete, strict decoding failed, or decoded NUL/U+FFFD evidence was present. |
| `130` | Godot exited zero but emitted an unclassified warning. |

Every machine-readable result contains the stable summary fields:

- `status`
- `exit_code`
- `timed_out`
- `script_error_count`
- `diagnostic_count`
- `task_introduced_error_count`
- `unclassified_diagnostic_count`
- `invalid_uid_unclassified_count`
- `stdout_capture` / `stderr_capture` (raw path, byte length, SHA-256,
  encoding, strict-decode result, raw/decoded NUL counts, replacement count,
  and capture-complete flag)
- `raw_capture_failure`
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
- `tests/fixtures/godot_test_runner/unicode_raw.gd`
- `tests/fixtures/godot_test_runner/raw_nul.gd`
- `tests/fixtures/godot_test_runner/unclassified_warning.gd`
- `tests/fixtures/godot_test_runner/generic_error.gd`
- `tests/fixtures/godot_test_runner/invalid_uid_warning.gd`
- `tests/fixtures/godot_test_runner/mirrored_warning.gd`

Run:

```powershell
pwsh -File tools/invoke_godot_test_failure_detection_self_test.ps1 `
  -GodotPath "C:\path\to\Godot_v4.7-stable_win64.exe"
```

The expected result is `9/9` with these exact outcomes:

1. Script error plus a real Godot exit `0` becomes runner exit `127`.
2. Missing required marker becomes runner exit `128`.
3. Normal completion becomes runner exit `0`.
4. Strict Unicode output remains exact and exits `0`.
5. A NUL that Godot reports as U+FFFD/replacement evidence becomes `129`.
6. An unclassified warning becomes `130`.
7. A generic error becomes `127`.
8. An invalid UID warning becomes `130` and increments the invalid-UID count.
9. A warning mirrored into the Godot log becomes `130` and is counted once.

The self-test also compares the player's campaign/current-run save fingerprints
before and after, verifies isolated profile paths, and verifies that every case
leaves zero scoped Godot processes.

The byte decoder has a separate six-case proof:

```powershell
pwsh -File tools/invoke_godot_test_raw_decoder_self_test.ps1
```

It covers empty input, strict UTF-8 with non-ASCII text, UTF-16 LE/BE with BOM,
decoded NUL, and invalid UTF-8. It also locks the SHA-256 of the empty stream and
the distinction between valid UTF-16 structural zero bytes and a decoded NUL.
