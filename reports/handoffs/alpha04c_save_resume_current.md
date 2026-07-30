# Alpha 0.4-C Save/Resume current handoff

Status: `BLOCKED_BY_OWNER_DIAGNOSTIC_PRE_AUDIT_FAILURE`.

PR #77 remains Draft. Alpha 0.4-C remains PARTIAL and may not merge to
`main`. Official Attempt 2 was not created, its authorization remains
unconsumed, and Process B/C were not started.

## Scope and baseline

This task started from PR #77 HEAD
`12691a8bc7ad2c5a9f4c175c95a8c214ea346a74` in the isolated branch
`codex/alpha04c-owner-capture-attestation-12691a8`.

The Queue bridge, Action routing, facility gameplay, AI policy, Main, RNG draw
points, and V0.7 constitution were not changed. The task added only Save
allocator continuity, redacted Owner diagnostics, role timeout/heartbeat
supervision, and non-official rehearsal evidence contracts.

## Completed implementation

The production Card Inventory section is now version 3 and strictly persists
`next_quote_sequence`. Legacy version 2 fails closed with
`allocator_cursor_missing_requires_backup`; no field is silently defaulted.
Expired quote bodies may be omitted while consumed identity space remains
authoritative.

Allocator evidence is GREEN:

- cursor contract `34/34`
- closure contract `13/13`
- legacy v2 backup gate `6/6`
- quote/listing/transaction identity parity `21/21`
- restored quote/listing/transaction reuse count `0/0/0`

The targeted diagnostic now has a fixed scenario identity, redacted 19-Owner
rows, Process A timeline and heartbeat, launch PID/creation-tick binding, and
Child/Parent completion contracts. The Process A rehearsal admission and
terminal outcome are exact-once and atomically published. Admission source
revalidation runs only after the caller owns the committed admission, and a
primary failure cannot be replaced by a secondary outcome-write failure.

## Authorized targeted diagnostic

The one newly authorized invocation ran exactly once from:

`7fa859dd7ab19dceb1e8036105a689c7e141a8e3`

Run ID:

`alpha04c-owner-capture-diagnostic-7fa859dd7ab1`

Observed result:

- wall time `1.427s`
- orchestrator exit code `1`
- failure code `orchestrator_internal_failure`
- quota ledger not created
- evidence root not created
- isolated user-data root created with zero files
- Godot not launched
- Child Completion not written
- Parent Exit not written
- Owner audit not started
- task-owned process count after `0`
- Save file count `0`

The targeted postcondition evaluated `.Count` on an empty unrolled
collection under PowerShell StrictMode. That native exception replaced the
original typed pre-quota reason with `orchestrator_internal_failure`.
Because the invocation never reached quota publication, no machine timeline
or Child/Parent artifacts exist from which the original reason can be
reconstructed.

This is a pre-audit harness failure, not an Owner capture result:

- `SCENARIO_IDENTITY_ATTESTED=false`
- `OWNER_AUDIT_STARTED=false`
- `OWNER_AUDIT_COMPLETED=false`
- `FAILING_SECTION_ID=NOT_ATTESTED`
- `FAILING_OWNER_ID=NOT_ATTESTED`
- `FAILING_REASON_CODE=NOT_ATTESTED`

The invocation is still the single authorized attempt for this task. It was
not retried.

## Process A rehearsal

The diagnostic admission gate did not become GREEN, so the authorized new
Process A rehearsal was not consumed or started. No Save, readback, manifest,
Child Completion, or Parent Exit result is claimed for a new rehearsal.

The role policy remains contract-GREEN:

- targeted diagnostic: absolute `120s`, no-progress `30s`
- Process A: absolute `180s`, no-progress `60s`
- Process B: absolute `360s`, no-progress `60s`
- Process C: absolute `180s`, no-progress `30s`

These bounded values were not used to start Process B/C.

## Focused verification

- production Registry transaction `59/59`
- production capture/readback `25/25`
- targeted diagnostic V2 `193/193`
- Process A admission `115/115`
- Process A terminal outcome `93/93`
- admission strict integers `65/65`
- diagnostic chain binding `60/60`
- evidence binding `17/17`
- launch authorization `55/55`
- vertical slice contract `139/139`
- Wrapper supervision `76/76`, three consecutive fixed-hash runs
- Alpha 0.4-A `66/66`
- Alpha 0.4-B static contracts `76/76` and `60/60`
- smoke engine `--check-only` PASS

No Formal run or full Smoke was executed.

## Godot MCP

The isolated endpoint was `http://127.0.0.1:8815/`. Real
`res://scenes/main.tscn` loaded and played. Static/runtime inspection found
one Registry, Queue, Execution service, Facility Queue adapter, Save
coordinator, and Save/Continue flow.

The full scan checked 986 scripts and found two unchanged inherited error
files. Task-introduced debug and runtime error counts are both zero. Play mode
and the editor exited normally; the task-owned Godot process count is zero.

## Preserved authority

Attempt 1 remains immutable at SHA-256
`80979cf3089e46ebff6025253126b57c1dd4e522cc5f858be8d4f5915ed17458`.
The prior targeted diagnostic ledger remains immutable at SHA-256
`2dba183fe0e354370802d0f886bf40a88b7e1c0b39ddb0df18ee110821e957a1`.

- official cold-restore count: `1`
- Attempt 2 claim: absent
- new official authorization consumed: `false`
- new Process A rehearsal count: `0`
- Process B/C started: `false/false`
- transactional Save Owners: `19`
- unsupported Save Owners: `0`
- third Formal: `false`
- full Smoke: `false`
- V0.7 constitution content changes: `0`

## Next boundary

Next exact task:

`ALPHA_0_4_C_OWNER_DIAGNOSTIC_SCENARIO_IDENTITY_CONTINUATION`

It requires a new explicit targeted-diagnostic authorization. It must first
fix and test the pre-quota/postcondition error-reporting path, then execute one
new diagnostic to reach the 19-Owner audit. No Owner may be changed until that
run attests a concrete section, Owner, and reason. Only a 19/19 diagnostic may
admit the still-unconsumed Process A rehearsal.
