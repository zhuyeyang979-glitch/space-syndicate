# Alpha 0.4-C Save/Resume current handoff

Status: `BLOCKED_BY_V5_PRE_OWNER_REPOSITORY_HEAD_BINDING`.

PR #77 remains Draft. Alpha 0.4-C remains PARTIAL and may not merge to
`main`. Official Attempt 2 was not created, its authorization remains
unconsumed, and Process B/C were not started. V5 consumed the exact `4 -> 5`
diagnostic quota once; Process A was not started.

## Latest V5 result

V5 ran once at `604264b0af9a10ca07db58851e8a2d00171dd2f3`.
Godot launched, but child bootstrap rejected `repository_head` before scenario
identity, Registry binding, or Owner Audit. The ledger contains the correct
HEAD string; the validator's expected safe fingerprint is the fingerprint of
canonical JSON `null`. Owner Capture therefore remains `0/19`, with no
attested failing section or Owner.

The V5 ledger is consumed at SHA-256
`b7e6c66852540c2b3066f86cd6e9c9d9454c185c4e8ed17d168c6b0dbf466742`.
Parent observed exit code `2`, no timeout, no parent termination, and zero
remaining task processes. Child Completion is absent. Process A, Attempt 2,
Process B, and Process C were not started. No V6 authorization exists.

Canonical details and evidence fingerprints are in
`alpha04c_v5_owner_diagnostic_result.json` and its Markdown companion. Older
diagnostic sections below remain historical evidence and are not the latest
run.

## Scope and baseline

This continuation started from PR #77 HEAD
`e9d5726250664c15c4c53f12b3a9ff0b4dd15dbc` in the isolated branch
`codex/alpha04c-owner-diagnostic-continuation-e9d5726`.

The Queue bridge, Action routing, facility gameplay, AI policy, Main, RNG draw
points, and V0.7 constitution were not changed. The task added only Save
allocator continuity, redacted Owner diagnostics, role timeout/heartbeat
supervision, and non-official rehearsal evidence contracts.

## Continuation checkpoint

Harness repair commit `708122b6ab413037ec1db812d8f73b389e30415c`
closes the two defects that obscured the previous run:

- the entire Save-artifact conditional is now array-stable under PowerShell
  StrictMode, including an empty result;
- targeted diagnostic execution preserves its primary typed failure over a
  secondary postcondition failure, while still running the postcondition once.

The synthetic guard is GREEN at `28/28`. It covers empty artifacts, primary
failure with successful postconditions, simultaneous primary/postcondition
failure, postcondition-only failure, the real pre-quota run-id gate, exact
allowlisted failure projection, and zero quota/evidence/Godot side effects.

No new targeted diagnostic ran in this continuation. Historical invocation
count remains `2`; the absent V2 ledger does not make that invocation reusable.
A third attempted diagnostic requires a new explicit `2 -> 3` authorization,
a fresh authorization ID, and a fresh exact-once ledger path.

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
- targeted postcondition guard `28/28`
- targeted launch authorization `43/43`
- targeted Owner failure projection `91/91`
- terminal evidence helper/driver `75/75` and `27/27`
- Wrapper supervision `92/92`, three consecutive fixed-hash runs
- Alpha 0.4-A `66/66`
- Alpha 0.4-B static contracts `76/76` and `60/60`
- smoke engine `--check-only` PASS

No Formal run or full Smoke was executed.

## Godot MCP

The prior task's isolated endpoint was `http://127.0.0.1:8815/`. Real
`res://scenes/main.tscn` loaded and played. Static/runtime inspection found
one Registry, Queue, Execution service, Facility Queue adapter, Save
coordinator, and Save/Continue flow.

The full scan checked 986 scripts and found two unchanged inherited error
files. Task-introduced debug and runtime error counts are both zero. Play mode
and the editor exited normally; the task-owned Godot process count is zero.

No Godot MCP endpoint was callable in this continuation's tool context.
Bounded isolated CLI runners instead revalidated the changed Harness contracts
with zero script/runtime errors and zero remaining task-owned processes; this
does not replace or restate the prior MCP scene evidence.

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

`ALPHA_0_4_C_POST_CANONICAL_PRE_OWNER_FAILURE_ARCHITECTURE_REVIEW`

The next task must inspect why the real child-bootstrap expected
`repository_head=null` while the V5 ledger and launch attestation both bind
the correct HEAD. It may not infer an Owner failure, run Process A, or create
an automatic V6 authorization.
