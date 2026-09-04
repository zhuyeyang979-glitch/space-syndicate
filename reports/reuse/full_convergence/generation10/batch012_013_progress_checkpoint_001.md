# Batch012 / Batch013 continuation checkpoint — 2026-09-05

Status: **PARTIAL_CONVERGENCE; NOT REQUIRED_GATE_GREEN**.

Checkpoint code Head: `8bf23bdbdbd2564a2ee9a2b1b0b2abde9ba0710d`.
Tree: `eedb4dc5edc0b8f14c780c7b7dbae75130e0db37`.
Worktree: `D:/ss-v076-generation9-platform-qualification-7a2e10c7-001`.
Branch: `codex/v076-generation9-platform-qualification-7a2e10c7-001`.

## Completed

Batch012's eight reviewed documents were checked against the external materialized
stage (8/8 exact bytes) and committed at
`a4223356bf790003c2ea3c12da757ee0019f3eac`. Both full-chain readers found 12 batches
and 478 new fingerprints. Neither reader reported any of the 39 Batch012
fingerprints or a Batch012-specific error. This is a batch-local acceptance,
not a whole-chain green: primary remained FAIL (741 top-level failures), and
independent remained NO_GO (521 P0 / 0 P1), on earlier HDM, subject-projection,
post-touch and related current-blob evidence.

Batch013 membership is independently reconstructed as `501 - 478 - 12 = 11`,
with five source paths. The two review receipts and membership seal are committed
under `dynamic_batch013_membership_001/` at
`74ce1f99f361ee6b5fd10ab5e5cafe5c9690de47`.
Exact membership set SHA256:
`44c6c9b08c2ea58f59beab10ffa0cd64bc5280909dc79f14741c129c63459532`.

The four missing dynamic proofs now have a reviewed, **non-authoritative**
candidate under `dynamic_batch013_binding_proposal_001/`. It binds four frozen
Raw fingerprints, three pinned source blobs, two existing Owner rows and blobs,
43 target blobs, 83 symbol references, four membership inputs, three frozen Raw
inputs, and eight static dependencies. Card art resolves 40 static callsites,
39 literal calls, 38 distinct literal constants, an eight-key dictionary,
47 expanded invocations and 41 unique targets. Animation binds the existing
`9f8659c8e3745c4f0c6bc398030c289e4291db31` repair, its direct parent, historical
dynamic site and current fixed path. Showcase keeps its existing single
constant call. Monster's two manifest rows and Alpha01's five v4 bindings are
unchanged and are not duplicated in this candidate.

Candidate Head: `e460096976ab188593ad59048929b2ca35277fc6`.
File SHA256: `6d4d1030d14a0cb4f967b69665bba5cb0ca1ce9aa0fbb9f80b1aa7db5ffbb5c4`.
Payload SHA256: `c1b57b561215f96f8c0a17b7139725e803aaf74f3926d08634f2ebb1854f7792`.
Both reviews are `GO_FOR_CANDIDATE_ONLY`; `trusted_fingerprint_count=0`.
No Batch013 correction record or new Gate waiver has been activated.

The independent review also found and verified a narrow existing resolver bug:
the caller selected one implementation trust row, then the Raw identity helper
looked up the fingerprint inside that row again, discarding it. Commit
`8bf23bdbdbd2564a2ee9a2b1b0b2abde9ba0710d` forwards that exact selected row.
New case131 failed before the fix and passed after it, checking valid/empty/None
rows and preservation of both projection and Raw identity failures. It does not
expand the trusted fingerprint set.

## Verification evidence

| Check | Result | External receipt SHA256 |
| --- | --- | --- |
| Candidate builder | 32/32, including 25 negative cases; false green 0 | Reviewed builder `bf50bb4cab41901a7faf32e23aeac631e48d60a8a0b0d8bd4010f2b65f268f55` |
| Existing inertia selftest, before forwarding fix | 163/163; false green 0 | `7779a1c1809c46424a0e1a8f7bf63c25cc1f875639388bc535dbc521ccdad87a` |
| Legacy correction selftest, before forwarding fix | 118/118; false green 0 | `e8c9a04e81b9778b1855823f3087970d1c4f35b9e73e4575a0d4cc43303169f0` |
| Full-convergence selftest, after forwarding fix | 131/131; legacy record/seal mutations 0 | `d5c9a33b448913eef7079366d0d55188420fbebfccff919e8c7255248510a28c` |

External generated receipts (preserve, do not overwrite):

- `D:/ss-v076-generation10-batch012-full-validator-002-20260905/primary.json`, SHA256 `8f9f2e69913dc86dd8bc99b5a34a3b04c3a0147e0bc029e0e2904bd673a00834`.
- `D:/ss-v076-generation10-batch012-independent-001-20260905/reports/reuse/correction_v2/audit_full_convergence_batch.json`, SHA256 `27230e3acbb0100a89d0fac58bd5f6adccb7afff3b62755c0d4d234f57145046`.
- `D:/ss-v076-generation10-batch013-tooling-regression-001-20260905/inertia-selftest.json`.
- `D:/ss-v076-generation10-batch013-correction-regression-001-20260905/correction-selftest.json`.
- `D:/ss-v076-generation10-batch013-forwarding-regression-001-20260905/full-convergence-selftest.json`.

No Godot launch, formal execution, product-source change, rule change, pagefile
change, reboot, deletion, PR transition or merge was performed in this continuation.
The 296 pre-existing untracked `.uid` files remain untracked and untouched.
Prior frozen formal attempts and Required Gate failures remain historical evidence.
`HUMAN_GREEN=false`; `FULL_PRODUCT_PRODUCTION_GREEN=false`.

## Next atomic work

Implement and independently test a **changed-file caller/dispatch proof** before
activating the four-fingerprint binding. Reuse the Gate's exact
`snapshot_changed_paths` and reference-closure facilities. New direct calls,
`call`, `callv`, `Callable`, deferred/signal dispatch, constructed method names,
unknown receivers/arguments and new production entrypoints must not be silently
covered by an old four-fingerprint correction. An unresolved relevant new call
must remain a precise current-delta failure. Unrelated changes should not require
reproving Kernel, map, military, assets or the entire game.

The candidate's fixed `SOURCE_TREES` is only a cold-snapshot proof. Do not promote
it to a permanent whole-source-tree equality rule, and do not remove it and grant
inheritable trust based only on a symbol grep. Keep zero trust until the narrow
incremental proof and its independent negative tests are reviewed.

Then append a fixed-hash four-fingerprint authority contract, integrate primary
and independent validators without inheriting Alpha01's special Registry-path
exemptions, and materialize the exact eleven Batch013 records using the existing
constructors. Keep the five Alpha01 and two monster proofs as their existing
owners. Refresh stale current-subject / HDM / subject-projection / post-touch
successors append-only, validate the complete chain, and only then run the next
authorized Required Gate. Commercial work and human-final-game qualification
remain gated; this checkpoint is not their approval.
