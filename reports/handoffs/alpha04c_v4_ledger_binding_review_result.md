# Alpha 0.4-C V4 ledger binding review result

Lane A is GREEN for evidence review and canonical binding repair. PR #77 must
remain Draft; this result does not authorize or execute V5.

## Root cause

The retained ledger path, exact 2517 bytes, raw SHA-256, field set, run, HEAD,
scenario, timeout policy, nonces, ticks, and official boundaries are coherent.
The first legacy mismatch is `schema_version` runtime type:

```text
PowerShell value       System.Int32
JSON wire token        4
Godot parsed Variant   float(4.0)
Legacy requirement     TYPE_INT
```

Godot 4.7 materializes JSON numbers as floating-point Variants. The legacy
validator rejected `schema_version` before inspecting later values. The four
quota counters and orchestrator PID had the same latent incompatibility.

## Repair

One machine-readable binding contract now owns the 32-field order, wire types,
authorization values, child-option bindings, fixed historical values, path,
integer, hex, nonce, boolean, and per-field failure rules. The PowerShell
publisher, orchestrator builder, Process A admission consumer, and GDScript
child validator all consume that contract.

`json_integer_number` means an integral CLR number on the publisher side and an
`int` or finite integral JSON-safe `float` on the Godot side. Orchestrator
creation ticks remain a decimal string, so their value is not rounded through
JSON floating-point transport.

Private QA failures now include only field name, typed reason, expected/actual
runtime types, and safe fingerprints. The public reason remains
`targeted_owner_capture_ledger_binding_invalid`.

## Non-consuming replay

The runner copied the exact retained V4 ledger bytes to a temporary isolated
directory and called the same validator used by child bootstrap. It reproduced
the legacy `schema_version` rejection, then passed the canonical matrix at
`35/35`. Corruption tests cover every identity boundary, six semantic integer
fields, Windows Chinese/space paths, POSIX paths, SHA, nonce, scenario,
authorization ID, and integer/ticks boundaries.

Replay deltas are all zero: diagnostic count, quota claims, Sessions, Save
writes, and Owner captures. No V5 authorization, Process A rehearsal, Attempt 2
claim, Process B, or Process C was created or started.

## Next gate

The next Alpha 0.4-C task may request one explicit `4_TO_5` authorization:

```text
ALPHA_0_4_C_REAUTHORIZED_TARGETED_OWNER_DIAGNOSTIC_V5_AND_PROCESS_A_REHEARSAL
```

That future task must still freeze a clean remote code head before consuming a
new quota. This replay is readiness evidence, not a diagnostic result.
