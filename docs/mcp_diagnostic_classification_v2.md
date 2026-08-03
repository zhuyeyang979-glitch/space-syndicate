# MCP Diagnostic Classification V2

`McpDiagnosticClassificationV2` is the only acceptance authority for stderr
diagnostics produced by the role-scoped Godot MCP workflow. Console rendering,
`get_console_logs`, message substring counts, and a fixed allowed-error count are
not acceptance evidence.

## Raw capture contract

`tools/role_godot_mcp_diagnostics.ps1` reads a fixed file-length snapshot with
`FileStream` and `FileShare.ReadWrite`. It never uses a replacement decoder as
the source of truth. Every non-empty raw record preserves:

- zero-based, end-exclusive message and framed byte ranges;
- the SHA-256 of the message bytes and of the actual newline-framed record;
- raw Base64 and the exact line-ending bytes;
- strict UTF-8 validity, literal U+FFFD count, decoder-inserted replacement
  count, and raw NUL count;
- stream, stage, neighboring event categories, paths, and parse/load/runtime
  correlations.

An empty log is valid evidence and has the standard SHA-256
`e3b0c442...b855`. A raw NUL or invalid UTF-8 never crashes the extractor.

On Windows, `launch_role_godot_mcp.ps1` binds the capture environment to
`start_process_win32_inherited_file_handle_v1`. The connection record also
captures Godot executable SHA, Godot version, editor/recovery argument hashes,
PowerShell version/edition, locale, UI locale, renderer, and schema versions.

## Fingerprints and multiplicity

The environment fingerprint binds Godot executable/version, the code-only
Tooling runtime build, addon tree, normalized argument template, locale,
PowerShell, capture backend, renderer, timeouts, and fresh-cache layout.

Two diagnostic fingerprints are used:

1. The core fingerprint binds raw bytes, stream, stage, direct association and
   failure flags. Its multiset is used only to count truly additional target
   events.
2. The strict fingerprint also binds the neighboring non-diagnostic event
   categories. Only a strict fingerprint with stable multiplicity can become
   `baseline_engine_import_diagnostic`.

If a core fingerprint exists in a baseline but its strict context changes, the
event remains `unclassified` and blocks acceptance. It is never silently
accepted as baseline.

Editor and recovery stderr are compared as separate source streams and then
combined for the matrix gate. The independent Godot log is retained as a mirror
and is never double-counted. Raw NUL and invalid UTF-8 records are always
diagnostics even when their decoded text contains no error keyword.

## Classification order

Each event is classified into exactly one of:

- `project_script_parse_error`
- `project_resource_load_error`
- `project_runtime_error`
- `changed_file_error`
- `task_introduced_error`
- `baseline_engine_import_diagnostic`
- `wrapper_decode_artifact`
- `informational`
- `unclassified`

Changed-file, parse, load, and runtime evidence take precedence over baseline
matching. `wrapper_decode_artifact` requires invalid raw UTF-8, explicit wrapper
decode proof, and no corresponding Godot diagnostic. Missing, corrupt,
non-ancestor, environment-mismatched, or context-mismatched baseline evidence
fails closed.

## Acceptance gate

GREEN requires all of the following to be zero:

- real project errors;
- changed-file errors;
- task-introduced errors;
- runtime errors;
- unclassified diagnostics.

Baseline diagnostics are allowed only through an integrity-checked manifest
whose exact fingerprints, multiplicities, source commits, environment, and
target HEAD/tree and deltas are recorded. A red comparison may emit a
`forensic_partial` manifest for explanation, but the formal gate accepts only
an `acceptance` manifest with exact observed multiplicity and every matrix
error/delta at zero. The implementation contains no global
`Unicode parsing error` allowlist and no `allowed_error_count=6` rule.

## Verification

Run:

```powershell
pwsh -NoProfile -File tools/test_role_godot_mcp_diagnostics.ps1
pwsh -NoProfile -File tools/test_mcp_diagnostic_tooling_minimal.ps1
```

The offline suite covers classification, baseline integrity, changed-file
correlation, and false-negative guards. The external minimal project proves a
zero-diagnostic launch and clean endpoint stop without changing production
project files.
