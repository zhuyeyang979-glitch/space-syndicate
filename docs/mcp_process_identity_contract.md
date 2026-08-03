# MCP Godot process identity contract

`RoleGodotProcessIdentityV3` binds one MCP editor session to live Windows process evidence. `RoleGodotMcpConnectionV4` stores that identity without any authoritative JSON date value or unsafe integer.

## Creation-time wire root cause

The failed V2 revalidation started with this exact value:

```text
2026-08-03T10:55:34.9642428Z
```

PowerShell 7.6.4 preserves the value across `ConvertTo-Json` and `ConvertFrom-Json` as a UTC `System.DateTime`: ticks remain `639213513349642428` and FILETIME remains `134302281349642428`. The failure occurred when the deserialized value was cast to `[string]`; default culture formatting removed the fractional seconds and UTC designator, and later parsing could reinterpret the displayed value in the local time zone.

Windows PowerShell 5.1 has a separate incompatibility. Serializing the `DateTime` produces `\/Date(1785754534964)\/`, and the round trip changes FILETIME from `134302281349642428` to `134302281349640000`. It loses 2,428 100-nanosecond ticks. A raw ISO date is therefore unsafe even though the original PowerShell 7 failure was display-format loss rather than actual tick loss.

## Lossless creation-time tag

V3 has one authoritative creation-time field:

```json
{
  "codec": "windows_filetime_utc_decimal_v1",
  "value": "134302281349642428",
  "source": "system_diagnostics_process_start_time"
}
```

`codec`, `value`, and `source` must each be actual JSON strings; coercible arrays, booleans, and numbers are rejected. `value` is a canonical decimal string, never a JSON number. Current FILETIME values are already above JavaScript's exact integer limit. The decoder requires `^(0|[1-9][0-9]*)$`, parses it as invariant `Int64`, and validates the .NET FILETIME range with `DateTime.FromFileTimeUtc`. Signs, whitespace, leading zeroes, decimals, exponents, unknown codecs, missing fields, and unknown sources fail closed.

Both initial capture and every revalidation read `System.Diagnostics.Process.StartTime` and convert it to FILETIME. `Win32_Process.CreationDate` remains useful for finding executable path and command line evidence, but never participates in creation-time comparison: CIM time has only microsecond precision and cannot exactly represent FILETIME's final 100-nanosecond digit. No tolerance comparison or lower-precision fallback is permitted.

Readable report timestamps, when retained in `connection.json`, use a `display_utc:` prefix so `ConvertFrom-Json` cannot materialize them as `System.DateTime`. They never participate in identity verification or hashing.

## Required identity evidence

The persisted V3 identity contains:

- exact schema version, role, and MCP session ID;
- PID and the tagged process creation time;
- separately retained expected and observed executable paths and the live path source;
- SHA-256 of the command line from the creation-time-matched live process record;
- canonical project path and project HEAD identity;
- endpoint address and endpoint-owner PID;
- explicit verification result and failure reason;
- a SHA-256 identity fingerprint generated from a fixed ordered field list.

The fingerprint includes the tag's `codec`, `value`, and `source` and all normative identity fields. Schema and normative string fields are type-checked before canonicalization, so a coercible one-element JSON array cannot be silently accepted. It never hashes `PSCustomObject.ToString()`, dictionary enumeration order, a display timestamp, or a culture-formatted value. Stored and regenerated live fingerprints must both match.

The observed executable path is resolved from live evidence in this order:

1. `Win32_Process.ExecutablePath`;
2. the guarded `System.Diagnostics.Process.Path` adapter;
3. guarded `Process.MainModule` plus a checked `FileName` property.

`Process.StartInfo.FileName` is auxiliary launch information and can never verify identity by itself. The command line must contain exactly one `--path` binding equal to the canonical project path and the exact `--role-godot-mcp-session-id=<session>` token. Endpoint acceptance requires a stable owner PID equal to the already verified editor PID.

## V2 and fail-closed behavior

V2 identity files are never guessed or migrated. `Test-McpProcessIdentity` returns `process_identity_schema_v2_not_supported`; a new session must generate V3/V4 metadata. A live process whose legacy identity cannot be verified is not killed as if it were a verified target. Cleanup also requires a valid tagged creation time: a missing or malformed token refuses both graceful close and forced termination.

Typed V3 failures include:

- `process_creation_time_tag_missing`;
- `process_creation_time_codec_invalid`;
- `process_creation_time_value_invalid`;
- `process_creation_time_value_out_of_range`;
- `process_creation_time_source_invalid`;
- `process_creation_time_source_changed`;
- `process_creation_time_source_unavailable`;
- `process_creation_time_mismatch`;
- `process_identity_fingerprint_mismatch`;
- the existing process-exit, executable-path, command-line, endpoint-owner, and incomplete-identity failures.

## Offline verification

Run:

```powershell
.\tools\test_role_godot_creation_time_wire.ps1
.\tools\test_role_godot_process_identity.ps1
```

The creation-time suite covers the codec, strict failures, UTC/local/unspecified and DST-adjacent values, culture-independent fingerprints, PowerShell 7 and Windows PowerShell 5.1 JSON matrices, source pinning, V2 rejection, PID reuse simulations, command-line changes, and complete V3 identities. The process suite retains the 41-case live/synthetic process, path, PID reuse, endpoint binding, and cleanup contract.
