# Commercial Presentation Milestone 1 — fixture-green and production-main automated hard-stop checkpoint

`STATUS=TRUE_HARD_STOP_REQUIRING_USER_DECISION`

`COMMERCIAL_M1_GREEN=false`

`READY_FOR_NEXT_CONSOLIDATED_HUMAN_PLAYTEST=false`

Asset-license, static-continuity, formal Phase 7 performance, production-main
Card-table automation, headed-capture automation, and independent fixture
visual review are green in their own scopes. Commercial Presentation M1 as a
whole is **not green**: the latest evaluated committed-history
Reuse/Point-Inertia validation has 565 failures, and the currently authorized
correction mechanisms still cannot resolve the previously proven lower bound
of at least 22 failures without a new decision.

## Frozen truth boundary

- `HUMAN_RETEST_DEFERRED=true`
- `HUMAN_GREEN=false`
- `FULL_PRODUCT_PRODUCTION_GREEN=false`
- `STEP13_STATUS=PENDING`
- `STEP14_STATUS=PENDING`
- `STEP15_STATUS=PENDING`
- `PR93_IS_DRAFT=true`
- The showcase is a presentation fixture, not natural gameplay, human evidence,
  or production-green evidence.

## Asset/reference registry

- The canonical registry contains 61 entries: 11 internal, 41 used in
  production, and 20 reference-only.
- 35 entries have direct commercial-use verification and 9 require attribution.
- Unregistered production assets, unknown-license production use,
  reference-only production imports, and missing required attribution are all
  zero.
- `ASSET_LICENSE_GATE=PASS` and `ASSET_REGISTRY_QUERY_SELFTEST=PASS`.
- Evidence: [asset_registry_report.json](asset_registry_report.json).

## Presentation fixture and visual review

- Focused showcase test: `984/984 PASS`, latest run
  `20260826-034634-965-vertical_slice_showcase_test-2b8a02e7`.
- Headed capture: run
  `20260826-030019-680-showcase_frame_capture-db746429`, 13 episodes, 39 PNGs,
  1600x960, with zero runner errors, diagnostics, or residual processes.
- Independent frame-by-frame review: `13/13 PASS`, `39/39` frame hashes match
  the manifest, and `VISUAL_REVIEW=PASS_FIXTURE_ONLY`.
- The fixture banner `PRESENTATION_FIXTURE — NOT NATURAL GAMEPLAY / NOT HUMAN GREEN`
  remains visible on all 39 frames.
- The visible state chains now include acquire 12→13, shuffle 7+12→19, draw
  19→18 with hand 4/5→5/5, the three-card public row, ordered public
  resolution, facility growth, monster impact, sushi-track slot movement, and
  three distinct Final Settlement phases.
- Military identity is unambiguous: Fleet Alpha follows the geodesic from the
  unique `R07` origin to the unique `R12` target, resolves armor 4→2, and
  withdraws after one mission.
- Visual blocker counts are zero: numeric contradiction 0, duplicate identity
  0, blocking occlusion 0, and missing required entity change 0.
- The 30/18/06 countdown values remain explicitly identified as fixture samples.
- Scoped result: `PASS_FIXTURE_ONLY`; it is not natural gameplay, Human Green,
  production green, or Commercial M1 Green.
- Evidence: [showcase_capture_manifest.json](showcase_capture_manifest.json),
  [capture_runner_report.json](capture_runner_report.json), and
  [visual_review.json](visual_review.json).

## Automated production-main Card-table sentinel

- `892/892 PASS`, run
  `20260826-033556-831-v076_alpha07_card_table_flow_readiness_test-5889d5cb`.
- Startup: 2.446 seconds; first AI Action Feed visibility: 3.724 seconds.
- Three authoritative track handoffs, four action windows, a second commodity
  acquisition, and 43 public resolutions complete through the existing
  production composition.
- Presentation source/queue/start/finish counts are `102/102/102/102`; the
  director saw 138 receipts and drained to zero queued cues.
- Presentation collisions, rejections, script errors, diagnostics,
  task-introduced errors, and residual processes are all zero.
- The high-water authority guard remained byte-stable at
  `ac0610885498f721a208c9c717b3aebc248089a7e0e4540245d7a61911e02bc3`
  with public-resolution source high-water 43.
- Evidence: [automated_card_table_flow_receipt.json](automated_card_table_flow_receipt.json).

This headless production-main result removes the last Card-table automation
failure only. It is not a headed visual review, natural human run, Human Green,
production green, or Commercial M1 Green.

## Runtime and performance evidence

- Godot MCP ran the final showcase scene with Godot 4.7, observed zero hard
  runtime errors, retained 155 existing warning headers, and stopped cleanly.
  This direct MCP run emitted no runner run ID and does not establish Human or
  production green.
- Production-main human-playability readiness automation: `266/266 PASS`, run
  `20260826-034651-563-v076_alpha07_human_playability_readiness_test-ad67a5ed`,
  with zero fixture-state injection, zero direct-method false green, zero
  diagnostics, and zero residual processes.
- Formal Phase 7 performance gate: `949/949 PASS`, run
  `20260826-014734-735-v076_phase7_sound_motion_performance_gate-4f9136fb`.
- Formal p95 values: idle 9.442 ms, animation 6.901 ms, card response 0.576 ms,
  and menu response 25.204 ms; stalls: 0.
- Showcase capture measurements include screenshot I/O and are informational
  only (`CAPTURE_IO_INCLUDED_INFORMATIONAL`). They are neither the milestone
  threshold source nor evidence for a production performance claim.
- Version continuity selftest: `105/105 PASS`; gate: `PASS_STATIC` with zero
  failures.

## Reuse/Point-Inertia hard stop

- Selftest: `120/120 PASS`, false-green count 0.
- Full validation through committed predecessor
  `362d65a1e03550800d68cb95b13f4425ee54e868`: `FAIL`, 565 failures, 509
  historical failures, 62 transitions.
- The prior 445/407 audit established a lower bound of at least 22 failures that
  cannot be resolved by the existing append-only correction mechanisms. The
  new grouped commits do not create an authorized correction path, so that
  lower bound remains valid even though the current totals are higher.
- A blanket exception, scan weakening, fabricated correction, history rewrite,
  or new governance task is not permitted.
- No new governance task is authorized by this checkpoint. The correct status
  is therefore `TRUE_HARD_STOP_REQUIRING_USER_DECISION`.

The final report/handoff commit necessarily follows the evaluated predecessor;
it does not claim its own transition was included in the 565/509/62 counts. The
final remote-head totals are published only after a second complete rerun.

## Next allowed step

Obtain an explicit decision for the failures outside the existing correction
mechanism. The fixture visual lane is accepted, but only after the full
Reuse/Point-Inertia validation is green may the milestone be re-audited for
`READY_FOR_NEXT_CONSOLIDATED_HUMAN_PLAYTEST=true`. Even then, Human Green and
Steps 13-15 remain pending until a real human completes the required playtest.
