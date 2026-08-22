# V0.7.6 inherited green ledger

Candidate: `bb9e9f60e6a3d34fa2faabba96c9a1ae181bfee4` / tree
`3133d8c4f00ee5110336b8b8efb7f8fe60523d15`, Draft PR #93.

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
| Stage 4 private military Direct Action | `CURRENT_DELTA_GREEN` | `V076PrivateDirectActionInputOwnerV1` | Owner `7/7`; integration `19/19`; Kernel `74/74`; partition `90/90`; Monster `47/47`; four V075 military contracts; Gate `114/114`; MCP Bench PASS and clean stop | Only STEP10 isolated green. Production/human green are false and all 28 military card mappings remain unverified. |

The Stage 2 topology remains bound to
`5cbd98e4027bc2cfd058c857e1a24a5f7c8c61291f1cb7ae7336bcf6851f6452`.
The Stage 3 aggregate replay receipt is
`bc3ebb6c182e5ee49a8aa7437562482447bfd232d9f46fd2fc765f0a4fcabca8`.

No row claims a production composition cutover, human playtest pass, or
repository-wide reproof. A future change to an Owner byte or a bound dependency
must replace inheritance with a scoped sentinel or a new proof.

## Canonical PR status and merge ratchet

The JSON ledger is the sole machine source for the PR #93 status block. It
records Stage 1/2/3 as isolated green, the Stage 4 isolated capability as the
latest completed stage, Golden counts `5/0/0`, and production cutover `false`.
The required check name is exactly `V076 Reuse and Point-Inertia Gate`.

The gate was queued without interrupting the active task and activated after
the preserved PR90 Tooling V19 atomic boundary
`a80ad3e107491d03e8a1ccf5379fcb44c705f951`. Once the current-Head check is
green, development resumes at `V076_STAGE_4_EXACT_MILITARY_CARD_MAPPING_PENDING`.

Ready, merge, release-tag, and production-cutover actions are forbidden until
that exact check succeeds for the current PR Head. This Stage 4 evidence does
not promote diagnostic evidence to production or human green.
