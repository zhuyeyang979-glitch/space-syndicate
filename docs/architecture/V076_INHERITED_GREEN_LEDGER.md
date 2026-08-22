# V0.7.6 inherited green ledger

Candidate: `2a365d465f199481da7fa1ef8f734e7525a136f5` / tree
`0a7c885023b75bb3f67d892b79fb8914ef87da6c`, Draft PR #93.

`POINT_INERTIA=ACTIVE`

`HISTORICAL_REUSE=ACTIVE`

`CHANGE_CLASS=TOOLING_ONLY+DOCS_ONLY`

`FULL_REPROOF_PERFORMED=false`

This ledger preserves exact previously recorded evidence. This documentation
change did not run Godot and does not turn inherited evidence into a new full
proof.

| Stage | Ledger status | Unique owner | Exact inherited/current evidence | Boundary |
|---|---|---|---|---|
| Stage 1 deterministic kernel | `INHERITED_GREEN` | `V076DeterministicKernel` | Origin `57/57`, 2,000 replay, 0 mismatch; Stage 3 Kernel V2 direct-owner regression `74/74`, 2,000 replay, 0 mismatch | Stage 3 changed Kernel/replay bytes. This is a revalidated direct Owner delta, not an unchanged-byte claim. |
| Stage 2 shared half-edge sphere | `INHERITED_GREEN` | `V076SharedHalfEdgePartitionV1` | `90/90`; 2,000 distinct seeds plus 2,000 fresh same-seed generations; generation/validation/partition/terrain mismatch and float-authority counts all 0 | Generator, topology, validator, and codec are unchanged. Only the map reducer received the Kernel V2 ABI adaptation; `90/90` is the current sentinel. |
| Stage 3 Monster L1 geodesic move | `CURRENT_DELTA_GREEN` | `V076MonsterL1ReducerV1` | `47/47`; 1,000 seeds x 2 replay, 0 mismatch; isolated warning-clean Bench PASS with `errors=[]` | Bench is diagnostic-only, production cutover is false, and `human_golden_step_06_09=false`. |

The Stage 2 topology remains bound to
`5cbd98e4027bc2cfd058c857e1a24a5f7c8c61291f1cb7ae7336bcf6851f6452`.
The Stage 3 aggregate replay receipt is
`bc3ebb6c182e5ee49a8aa7437562482447bfd232d9f46fd2fc765f0a4fcabca8`.

No row claims a production composition cutover, human playtest pass, or
repository-wide reproof. A future change to an Owner byte or a bound dependency
must replace inheritance with a scoped sentinel or a new proof.

## Canonical PR status and merge ratchet

The JSON ledger is the sole machine source for the PR #93 status block. It
records Stage 1/2/3 as isolated green, Golden counts `4/0/0`, production
cutover `false`, and Stage 4 as pending owner registration. The required check
name is exactly `V076 Reuse and Point-Inertia Gate`.

The gate was queued without interrupting the active task and activated after
the preserved PR90 Tooling V19 atomic boundary
`a80ad3e107491d03e8a1ccf5379fcb44c705f951`. Once the current-Head check is
green, development resumes at `V076_STAGE_4_PENDING_OWNER_REGISTRATION`.

Ready, merge, release-tag, and production-cutover actions are forbidden until
that exact check succeeds for the current PR Head. This governance delta does
not alter any Stage evidence subject SHA and does not promote diagnostic
evidence to production or human green.
