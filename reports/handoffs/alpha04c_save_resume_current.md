# Alpha 0.4-C Save/Resume current handoff

Status: `BLOCKED_BY_PROCESS_A_COMPLETION_REHEARSAL`.

PR #77 remains Draft. Alpha 0.4-C is not GREEN and may not merge to
`main`. The newly authorized official retry was not consumed.

## Baseline and scope

This continuation started from exact remote PR #77 HEAD
`f4350d7425f69cdd2d7ee14f3a3dd25f5345dd6a`. Main constitution commit
`6b5568429b82ddab3400ee0d5076ac6ac3411a20` remains an ancestor.

The card-inventory repair is committed at
`aadbba39f9d564fc59dea8e99f27ae36c52ea8a1`. The non-official rehearsal
ran from `5f52b600da9eb653af2dc3d3746039cfc6a1a509`. Five production files
changed, but no Save section, RNG owner, RNG draw point, Main responsibility,
V0.7 constitution content, or V0.7 runtime was added. Production remains V0.6.

## Diagnostic run 1

The first non-official run established the timeout classification
`NORMAL_CARD_SEARCH_DOMINANT`. It used the fixed depth-1, seed-900626424,
one-local-plus-three-AI scenario, exited naturally in about 63.9 seconds, and
showed that the two legal normal-card acquisition intervals dominated the old
60-second budget. Save I/O was not the dominant phase.

That run atomically installed a 605,513-byte Save, but readback failed because
`card_inventory.owner_state` was empty. This was a historical production
capture defect, not a completion-signaling deadlock.

## Repair evidence

The repair binds district quotes to the selected slot revision, performs all
19 semantic owner preflights before envelope composition, rejects invalid
capture before write authorization, refreshes Route attestation after facility
topology changes, omits ordinary expired quotes, and preserves expired quotes
that already belong to a pending-discard transaction.

Focused evidence is green:

- district purchase revision binding `7/7`
- card inventory composite `30/30`
- production Registry transaction `53/53`
- market clock and Save production `32/32`
- Save confirmation `13/13`
- fork parity `14/14`
- cold-restore source contract `122/122`
- Godot MCP GDScript check: 486 files, 0 script errors

The real `main.tscn` MCP run found exactly one Facility Queue Adapter, Queue,
Execution service, Save Registry, Route Controller, and Route WorldBridge.
The Queue Adapter and Route Controller were configured, the Registry exposed
19 bindings, and the run stopped cleanly with zero task-owned Godot processes.
Six inherited `Unexpected NUL character` log entries remain disclosed; they
did not produce a script error or a fatal runtime stack.

## Completion rehearsal

The second and final permitted non-official Process A run was
`alpha04c-process-a-rehearsal-5f52b600`. It used the same fixed scenario and a
bounded 180-second parent timeout. Attempt 1's claim was unchanged before and
after the run.

| Phase | Duration | Result |
|---|---:|---|
| child bootstrap | 0.003 s | OK |
| scene load | 3.837 s | OK |
| session start | 1.578 s | OK |
| commodity claim | 0.100 s | OK |
| normal-card acquisition | 16.857 s | OK |
| facility economy | 0.890 s | OK |
| first Sale Receipt | 0.125 s | OK |
| AI non-default qualification | 21.122 s | OK |
| Queue commit | 0.165 s | OK |
| Restore Barrier | 0.003 s | OK |
| Save intent submission | 0.004 s | OK |
| Save capture call | 0.901 s | owner capture rejected |
| envelope encode | 0.004 s | skipped after failure |
| atomic write | 0.004 s | skipped after failure |
| Save readback | 0.004 s | skipped after failure |
| failure manifest | 0.009 s | written |
| Child Completion | 0.011 s | structurally valid failure proof |
| runtime cleanup | 0.133 s | OK |
| quit request | 0.008 s | OK |

The child timeline covered 46.621 seconds and the child result reported
46.385 seconds. The observed parent command took about 52.55 seconds.

The product verdict is `owner_capture_failed`. No Save file was written, so
Save GREEN is false. The Card Inventory probe itself was captured and its
combined preflight was accepted; the tested Harness did not attest the next
failing Registry section or internal reason. QA-only propagation for that
internal section/reason was added after the rehearsal and is covered by the
122/122 source contract, but no third Process A run is permitted.

Child Completion is structurally valid, but it records
`qualification_green=false` and `save_written=false`; therefore Child GREEN is
false. Parent Exit is GREEN: exit code 0, no timeout, no parent termination,
and zero task-owned processes after exit.

## Remaining gates

- Both permitted non-official Process A runs have been consumed.
- The exact remaining Registry owner-capture failure needs a new authorized
  continuation; it cannot be guessed from the public Save receipt.
- The private quote allocator cursor is not fully persisted when later expired
  quotes are omitted. A complete fix requires an explicitly authorized Save
  payload field; no such field was added here.
- `ColdRestoreRoleTimeoutPolicyV1` is not implemented. A/B/C still share the
  legacy child-timeout parameter.
- Attempt 2 still has no independent claim path and the current official path
  still names Attempt 1. Official execution is prohibited.

Attempt 1 remains the only claim: 1,133 bytes, SHA-256
`80979cf3089e46ebff6025253126b57c1dd4e522cc5f858be8d4f5915ed17458`,
last written `2026-07-30T06:09:56.4387012Z`. No Attempt 2 claim or claim temp
file exists. Process B and Process C were not run. Official count remains one.

## Preserved boundaries

- `TRANSACTIONAL_SAVE_OWNER_COUNT=19`
- `UNSUPPORTED_SAVE_OWNER_COUNT=0`
- `PRODUCTION_CODE_CHANGE_COUNT=5`
- `PRODUCTION_SAVE_COMPLETION_SIGNALING_CHANGE_COUNT=0`
- `NEW_SAVE_SECTION_COUNT=0`
- `NEW_RNG_OWNER_COUNT=0`
- `NEW_RNG_DRAW_POINT_COUNT=0`
- `THIRD_FORMAL_RUN_PERFORMED=false`
- `FULL_SMOKE=false`
- `V07_CONSTITUTION_CONTENT_CHANGE_COUNT=0`

Next exact task:

`ALPHA_0_4_C_PRODUCTION_SAVE_COMPLETION_DEFECT_REPAIR`

It must identify and repair the remaining Owner capture failure, explicitly
authorize any required Save payload change, preserve the quote allocator
cursor exactly, then earn a new completion-rehearsal allowance before role
timeouts or an independent Attempt 2 claim can be used.
