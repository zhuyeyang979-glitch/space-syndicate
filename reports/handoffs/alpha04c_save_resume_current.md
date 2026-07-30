# Alpha 0.4-C Save/Resume current handoff

Status: `BLOCKED_BY_PRODUCTION_SAVE_COMPLETION_DEFECT_OUTSIDE_AUTHORIZATION`.

PR #77 remains Draft. Alpha 0.4-C is not GREEN and may not merge to `main`.
The newly authorized official retry was not consumed.

## Baseline and scope

The task started from exact remote PR #77 HEAD
`d75fcec3793fe8a92b82e2376ab3b3122503c3e2`. Main constitution commit
`6b5568429b82ddab3400ee0d5076ac6ac3411a20` is an ancestor. The diff from
tested Queue-bridge head `ca3b7cf4222a6145bed81606fc4f04b7076ae0d9`
contains seven documentation/report files and zero production, Queue, or Save
behavior changes, so the lawful Queue qualification remains applicable.

V0.7 constitution content and runtime were not changed. Production remains
V0.6.

## Process A diagnosis

One non-official diagnostic ran from instrumentation head
`c2f74154433bcc1471b1239d0cbdf65f91d93abc` with the authorized scenario:
depth 1, seed `900626424`, one local player, three AI players, real
`main.tscn`, the production Action Spine, and the real facility Queue bridge.
Its user data was isolated below a `non_official` root. It did not read, create,
or mutate an official claim.

The run used a bounded 180-second parent timeout and exited naturally in about
63.9 seconds. Parent exit and Child Completion attestations were valid, exit
code was zero, the parent did not terminate it, and task-owned process count
returned to zero.

The recovered phase timeline shows:

| Phase | Duration |
|---|---:|
| scene load | 4.451 s |
| session start | 1.729 s |
| first legal normal-card search | 18.642 s |
| first facility action | 0.998 s |
| first Sale Receipt | 0.131 s |
| second legal normal-card acquisition plus AI check | 23.685 s |
| Queue commit | 0.184 s |
| Save flow call | 2.606 s |

The two legal normal-card acquisition intervals dominate the run. Product
setup reaches Save close to the old 60-second parent boundary; Save I/O itself
is not dominant. The formal timeout classification is therefore
`NORMAL_CARD_SEARCH_DOMINANT`.

## Blocking Save defect

The diagnostic did more than explain the timeout. It installed a 605,513-byte
Save with SHA-256
`50c6703eda09e4870a65406a9f76a989fd84968b548e79916fe0c3eca4da6259`.
The typed Save intent returned and the file was atomically installed, so this
is not a completion-signal deadlock.

The following driver readback and 19-owner Registry preflight failed with
`card_inventory_v2_invalid`. The envelope contains exactly one empty owner
state: `sections.card_inventory.owner_state={}`. The other 18 owner states are
nonempty. Repairing that capture changes a production Save owner/section
contract and is explicitly outside this task's authorization, which permits at
most completion signaling after a valid write.

The Harness now preserves failed-role phase evidence with safe reason codes;
that correction is covered by source and timeline contracts. The product
defect itself was not changed.

## Official authorization

Attempt 1 remains immutable at SHA-256
`80979cf3089e46ebff6025253126b57c1dd4e522cc5f858be8d4f5915ed17458`
and last-write time `2026-07-30T06:09:56.4387012Z`. Its original `0 -> 1`
claim, failed Process A, and absence of B/C remain intact.

No completion rehearsal was run because production Save readback is not green.
No Attempt 2 claim was created, the new authorization was not consumed, and
Process B/C were not started. Official cold-restore count remains one.

## Preserved boundaries

- `TRANSACTIONAL_SAVE_OWNER_COUNT=19`
- `UNSUPPORTED_SAVE_OWNER_COUNT=0`
- `PRODUCTION_CODE_CHANGE_COUNT=0`
- `NEW_SAVE_SECTION_COUNT=0`
- `NEW_RNG_OWNER_COUNT=0`
- `NEW_RNG_DRAW_POINT_COUNT=0`
- `THIRD_FORMAL_RUN_PERFORMED=false`
- `FULL_SMOKE=false`
- `V07_CONSTITUTION_CONTENT_CHANGE_COUNT=0`

Next exact task:

`ALPHA_0_4_C_PRODUCTION_SAVE_COMPLETION_DEFECT_REPAIR`

That task must repair and prove the `card_inventory` capture/preflight contract
before a fresh completion rehearsal or any official retry can be considered.
