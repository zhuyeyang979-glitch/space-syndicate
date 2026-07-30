# Alpha 0.4-C Save/Resume current handoff

Status: `BLOCKED_BY_UNATTESTED_OWNER_CAPTURE_FAILURE`.

PR #77 remains Draft. Alpha 0.4-C is still PARTIAL and may not merge to
`main`. The new official retry authorization remains unconsumed. Attempt 2,
Process B, and Process C were not started.

## Scope and baseline

This task started from exact remote PR #77 HEAD
`0240dae2d03581791a27826a8472576b5b543502` in the isolated branch
`codex/alpha04c-production-save-completion-repair-0240dae`. Main constitution
commit `6b5568429b82ddab3400ee0d5076ac6ac3411a20` remains unchanged.

The Queue bridge, Action routing, gameplay values, AI policy, Main, scenes,
RNG ownership, and V0.7 constitution were not changed. The production changes
before the diagnostic are limited to the Registry capture failure boundary and
redacted Save readback diagnostics. No Owner payload or section version was
changed.

## Completed pre-diagnostic work

`SaveOwnerCaptureFailureV1` now reports a closed, redacted tuple containing
section, Owner, reason, observed state version, and payload fingerprint. The
production Save path and `capture_all_sections_detailed()` share one capture
worker. Raw Owner state, the Registry plan, and section payloads do not cross
the public evidence boundary.

Focused gates passed before the one authorized diagnostic:

- Save Owner capture failure contract `63/63`
- Registry wrapper `12/12`
- production Registry transaction `59/59`
- production 19-Owner capture, v3 encode, atomic write, readback, and preflight `20/20`
- Child Completion contract `19/19`
- cold-restore contract `131/131`
- Wrapper attestation `68/68`
- PowerShell parse `3/3`

The production capture bench proves 19/19 capture and readback in a real
`main.tscn` composition, but it does not identify the separate nontrivial
Process A failure.

## One targeted diagnostic

The exact-once quota ledger consumed its only transition `0 -> 1` for:

`alpha04c-owner-capture-diagnostic-de24ab322a2a`

The run was non-official and non-formal. It used a 180-second parent timeout,
exited in about 17.676 seconds, wrote no Save, touched no official claim, and
left no task-owned process.

The child exited 0 with a structurally valid Child Completion attestation.
Parent Exit was GREEN: observed exit, no timeout, no parent termination, and
zero task-owned processes. The 19-row phase timeline closed through
`quit_requested`.

However, the run failed during `session_started` before the first Owner audit:

`targeted_owner_capture_observed_scenario_mismatch`

The QA observer read `challenge_depth` from `GameSession`'s intentionally
reduced setup summary. That summary stores player count, AI count, difficulty,
and mission title, but not challenge depth, so the observer saw `-1` and
rejected the otherwise valid fixed scenario. This was a diagnostic contract
defect, not a production Owner result.

Therefore:

- `TARGETED_OWNER_CAPTURE_DIAGNOSTIC_COUNT=1`
- `OWNER_AUDIT_COUNT=0/8`
- `FIRST_PHASE_WITH_CAPTURE_FAILURE=NOT_ATTESTED`
- `FAILING_SECTION_ID=NOT_ATTESTED`
- `FAILING_OWNER_ID=NOT_ATTESTED`
- `FAILING_REASON_CODE=NOT_ATTESTED`

No second diagnostic was run. No Owner was modified by guess.

## Diagnostic contract repair

After preserving the failed run, the QA scenario identity was repaired to use
the exact setup draft validated and committed by
`SessionStartTransactionCoordinator`. Runtime actor and AI counts remain an
independent 1-local-plus-3-AI observation. Parent failures now retain a bounded
child setup code, while mismatch paths and scalar values remain hashed.

This repair was verified without another diagnostic:

- cold-restore contract `133/133`
- Wrapper attestation `68/68`
- Driver contract-only `PASS`
- PowerShell parse `PASS`
- git diff check `PASS`

These checks validate the repaired contract but do not replace the missing
eight-phase Owner evidence.

## Godot MCP

An isolated role-local Funplay MCP endpoint ran at
`http://127.0.0.1:8805/` with separate APPDATA and LOCALAPPDATA. It reported
the exact task worktree, loaded and played real `res://scenes/main.tscn`, and
found the runtime Main, V06 Save Registry, Facility Queue Adapter, Queue,
Execution service, and Save/Continue Flow at their production paths.

MCP validation reported zero diagnostics for each of the five changed
production/diagnostic GDScript files and zero runtime error-log lines. The
full-project scanner found one unchanged tool bench with two type-inference
diagnostics; it is outside this task diff. Play mode and the editor were
stopped through the role-local tools, port 8805 closed, and the final Godot
process count was zero.

The affected Save evidence privacy assertions are `2/2`. Two broader inherited
privacy suites remain disclosed: card-market public quote privacy is `3/5`,
and player-facing privacy is blocked by an unchanged test parse error. Neither
failure path is in this task's production diff, so no pricing, authorization,
or retired test contract was changed here.

## Allocator cursor

The ownership ledger identifies `CardMarketPricingRuntimeController` as the
quote identity authority. The required Save location is
`card_inventory.district_purchase.district_purchase_runtime.next_quote_sequence`.
Expired quote payloads may be omitted, but their consumed identity range may
not be forgotten.

The focused specification currently passes `24/34`; the ten red assertions
correctly show that cursor persistence, old-payload fail-closed behavior,
rollback parity, and next quote ID parity are not implemented. Because the
task requires the actual failing Owner to be attested before any production
Owner change, no cursor field or section version was added.

## Preserved authority

Attempt 1 remains immutable at 1,133 bytes with SHA-256
`80979cf3089e46ebff6025253126b57c1dd4e522cc5f858be8d4f5915ed17458`.
The official cold-restore count remains one. Attempt 2 does not exist, and the
new official authorization remains unconsumed.

- `TRANSACTIONAL_SAVE_OWNER_COUNT=19`
- `UNSUPPORTED_SAVE_OWNER_COUNT=0`
- `NEW_SAVE_SECTION_COUNT=0`
- `OWNER_SECTION_VERSION_CHANGED=false`
- `ENVELOPE_SCHEMA_VERSION_CHANGED=false`
- `NEW_RNG_OWNER_COUNT=0`
- `NEW_RNG_DRAW_POINT_COUNT=0`
- `THIRD_FORMAL_RUN_PERFORMED=false`
- `FULL_SMOKE=false`
- `V07_CONSTITUTION_CONTENT_CHANGE_COUNT=0`

## Next boundary

Next exact task:

`ALPHA_0_4_C_OWNER_CAPTURE_ATTESTATION_CONTINUATION`

It needs an explicit new diagnostic authorization. It should run the repaired
eight-phase contract exactly once, identify the real section, Owner, and
reason, then repair only that Owner plus the independently ledgered quote
allocator cursor. Only after 19/19 production capture and readback are green
may a new Process A completion rehearsal be consumed.
