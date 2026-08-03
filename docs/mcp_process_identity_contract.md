# MCP Godot process identity contract

`RoleGodotProcessIdentityV2` binds one MCP editor session to live Windows process evidence. It replaces the earlier PID/start-time/path tuple that dereferenced `Process.MainModule.FileName` immediately after `Start-Process`.

## Root cause

`Start-Process -PassThru` returns `System.Diagnostics.Process`. Under `Set-StrictMode -Version Latest`, a transiently null `Process.MainModule` makes `$Process.MainModule.FileName` fail with `PropertyNotFoundStrict`, even though a stable `System.Diagnostics.ProcessModule` does expose `FileName`.

The V2 reader never accesses `Process.FileName` or chains `MainModule.FileName`. Every optional or throwing property is isolated and converted to a typed failure reason.

## Required identity evidence

The persisted identity contains:

- schema version, role, and MCP session ID;
- PID and exact process creation timestamp;
- separately retained expected and observed executable paths;
- the live executable-path source;
- SHA-256 of the creation-time-matched CIM command line;
- canonical project path and project HEAD identity;
- endpoint address and endpoint-owner PID;
- an explicit verification result and failure reason.

The observed executable path is resolved from live evidence in this order:

1. `Win32_Process.ExecutablePath`;
2. the guarded `System.Diagnostics.Process.Path` adapter;
3. guarded `Process.MainModule` plus a checked `FileName` property.

`Process.StartInfo.FileName` is recorded only as auxiliary launch information and can never verify identity by itself.

The command line must contain exactly one `--path` binding equal to the canonical project path and the exact `--role-godot-mcp-session-id=<session>` token. Endpoint acceptance requires a stable owner PID equal to the already verified editor PID.

## Fail-closed reasons

The contract returns typed failures including:

- `process_exited_before_identity`;
- `process_exited_during_identity`;
- `process_creation_time_mismatch`;
- `process_executable_path_unavailable`;
- `process_executable_path_mismatch`;
- `process_command_line_unavailable`;
- `process_command_line_mismatch`;
- `endpoint_owner_pid_missing`;
- `endpoint_owner_pid_mismatch`;
- `process_identity_incomplete`.

No missing path, unavailable CIM record, endpoint response, process name, or PID-only observation is accepted as identity proof.

## Offline verification

Run:

```powershell
.\tools\test_role_godot_process_identity.ps1
```

The suite covers real `Start-Process`, `Get-Process`, and `Win32_Process` objects plus synthetic fault injection for property races, disposed processes, path normalization, PID reuse, stale CIM data, command-line mismatch, connection-envelope mismatch, endpoint-owner changes, cleanup identity guards, and missing live path sources. The required result is 41/41 with zero unhandled PowerShell exceptions and zero direct `FileName` access across the related launcher, invoke, stop, and common tooling.
