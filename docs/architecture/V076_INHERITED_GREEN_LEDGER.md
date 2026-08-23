# V0.7.6 inherited green ledger

Candidate: `9c5eb2be7a76a9035672fbcf3adadbd8b5f254e6` / tree
`07b967e89a3edb362dad1ee06df8a84077dc5e24`, Draft PR #93.

`POINT_INERTIA=ACTIVE`

`HISTORICAL_REUSE=ACTIVE`

`CHANGE_CLASS=CROSS_DOMAIN_INTEGRATION`

`FULL_REPROOF_PERFORMED=false`

This ledger preserves exact previously recorded evidence and adds only the
focused Stage 4 proof. It does not turn focused or inherited evidence into a
new full-world proof.

| Stage | Ledger status | Unique owner | Exact inherited/current evidence | Boundary |
|---|---|---|---|---|
| Stage 1 deterministic kernel | `INHERITED_GREEN` | `V076DeterministicKernel` | Origin `57/57`, 2,000 replay, 0 mismatch; Stage 3 Kernel V2 direct-owner regression `74/74`, 2,000 replay, 0 mismatch | Stage 3 changed Kernel/replay bytes. This is a revalidated direct Owner delta, not an unchanged-byte claim. |
| Stage 2 shared half-edge sphere | `INHERITED_GREEN` | `V076SharedHalfEdgePartitionV1` | `90/90`; 2,000 distinct seeds plus 2,000 fresh same-seed generations; generation/validation/partition/terrain mismatch and float-authority counts all 0 | Generator, topology, validator, and codec are unchanged. Only the map reducer received the Kernel V2 ABI adaptation; `90/90` is the current sentinel. |
| Stage 3 Monster L1 geodesic move | `CURRENT_DELTA_GREEN` | `V076MonsterL1ReducerV1` | `47/47`; 1,000 seeds x 2 replay, 0 mismatch; isolated warning-clean Bench PASS with `errors=[]` | Bench is diagnostic-only, production cutover is false, and `human_golden_step_06_09=false`. |
| Stage 4 private military Direct Action | `CURRENT_DELTA_GREEN` | `V076PrivateDirectActionInputOwnerV1` | Crosswalk `48/48`; Owner `7/7`; integration `25/25`; Kernel `74/74`; partition `90/90`; Monster `47/47`; four V075 military contracts; Gate self-test `114/114`; MCP Bench PASS and clean stop | STEP10 remains isolated green. All 28 identities close, 12 exact-map, and 16 remain `REAUTHOR_REQUIRED`; production/human green are false. |
| Stage 4 Profile authoring + physical ETA infrastructure | `CURRENT_DELTA_GREEN` | `V076MilitaryUnitProfileAuthority`; `V076MilitaryPhysicalEtaOwnerV1` | Profile `59/59`; Crosswalk `52/52`; ETA `48/48`, 1,000 seeds / 2,000 replays / 0 mismatch / 0 teleport; Owner `7/7`; Bench `26/26`; inherited sentinels green; MCP clean stop with new-file warnings 0 and hard errors 0 | `INFRASTRUCTURE` evidence augments the same STEP10. 28/28 exact-map, but tick-driven lifecycle, production composition, human play, and card certification remain pending. |
| Stage 4 arrive/execute-once/withdraw lifecycle infrastructure | `CURRENT_DELTA_GREEN` | `V076PrivateDirectActionInputOwnerV1` through `V076PrivateDirectActionReducerV1` | Lifecycle `29/29`; Owner `7/7`; Bench `30/30`; root/derived/execution `1/2/3`; exact ticks `5/6/7`; same-tick/replay/tamper mismatch 0; inherited focused sentinels green; MCP PASS, changed-file warnings 0, hard errors 0, clean stop, scoped processes 0 | `INFRASTRUCTURE` evidence augments the same STEP10. No new Owner, per-tick unit position, production typed damage sink, production/human green, or card certification is claimed. |

The Stage 2 topology remains bound to
`5cbd98e4027bc2cfd058c857e1a24a5f7c8c61291f1cb7ae7336bcf6851f6452`.
The Stage 3 aggregate replay receipt is
`bc3ebb6c182e5ee49a8aa7437562482447bfd232d9f46fd2fc765f0a4fcabca8`.

No row claims a production composition cutover, human playtest pass, or
repository-wide reproof. A future change to an Owner byte or a bound dependency
must replace inheritance with a scoped sentinel or a new proof.

## Canonical PR status and merge ratchet

The JSON ledger is the sole machine source for the PR #93 status block. It
records Stage 1/2/3 as isolated green and the Stage 4 military mission lifecycle
slice as the latest completed stage, with Golden counts `5/0/0` and production
cutover `false`.
The required check name is exactly `V076 Reuse and Point-Inertia Gate`.

The gate was queued without interrupting the active task and activated after
the preserved PR90 Tooling V19 atomic boundary
`a80ad3e107491d03e8a1ccf5379fcb44c705f951`. Once the current-Head check is
green, development resumes at
`V076_STAGE4_MILITARY_TYPED_DAMAGE_INTENT_SINK_INTEGRATION`.

Ready, merge, release-tag, and production-cutover actions are forbidden until
that exact check succeeds for the current PR Head. This Stage 4 evidence does
not promote diagnostic evidence to production or human green.
