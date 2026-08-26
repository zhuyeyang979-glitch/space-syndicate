# Commercial Presentation Milestone 1 — fixture-green and production-main automated hard-stop checkpoint

`STATUS=TRUE_HARD_STOP_REQUIRING_USER_DECISION`

`COMMERCIAL_M1_GREEN=false`

`READY_FOR_NEXT_CONSOLIDATED_HUMAN_PLAYTEST=false`

Asset-license, static-continuity, formal Phase 7 performance, production-main
Card-table automation, headed-capture automation, and independent fixture
visual review are green in their own scopes. Commercial Presentation M1 as a
whole is **not green**: the latest evaluated committed-product-head
Reuse/Point-Inertia validation has 569 failures, and the currently authorized
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

- Focused showcase test: `1043/1043 PASS`, latest run
  `20260826-080153-777-vertical_slice_showcase_test-83ecb20c`.
- Latest headed finality capture: run
  `20260826-081646-474-showcase_frame_capture-5963edd5`, 13 episodes, 39 PNGs,
  1600x960. All 13 episode evidence files reached final `PASS`; process exit,
  runner exit, script errors, diagnostics, task-introduced errors, and residual
  project processes are all zero.
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
- Evidence: [showcase_headed_finality/20260826-081645-855-ae71c1dc5841/showcase_capture_manifest.json](showcase_headed_finality/20260826-081645-855-ae71c1dc5841/showcase_capture_manifest.json),
  [showcase_headed_finality/20260826-081645-855-ae71c1dc5841/capture_runner_report.json](showcase_headed_finality/20260826-081645-855-ae71c1dc5841/capture_runner_report.json),
  and the independent [visual_review.json](visual_review.json). The finality
  bundle remains `PRESENTATION_FIXTURE` and does not replace visual review.

## Automated production-main Card-table sentinel

- `1067/1067 PASS`, run
  `20260826-081712-139-v076_alpha07_card_table_flow_readiness_test-a5c91e41`.
- Runtime duration: 126.266 seconds; both runner and Godot exited zero.
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

- Godot MCP ran the real `res://scenes/main.tscn` with
  `4.7.stable.official.5b4e0cb0f`, observed no task-introduced hard runtime
  error, retained the disclosed existing warnings, and stopped cleanly.
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
- Four natural production Cue proof: `243/243 PASS`, zero failures; card-table
  run `20260826-081712-139-v076_alpha07_card_table_flow_readiness_test-a5c91e41`
  and Victory run
  `20260826-081921-586-v076_production_victory_audit_readiness_test-e1a48a75`.
  Both runs have zero script errors, diagnostics, task-introduced errors, and
  residual project processes.

## Natural production headed bundle

- `PASS_AUTOMATED_NATURAL_PRODUCTION_HEADED_ONLY`, recorded_at_utc
  `2026-08-26T08:14:26.6190418Z`, evidence head
  `12019fdf5ff78733a36b3f0e889fecd1fcfb227c`.
- Headed card-table run:
  `20260826-081007-297-v076_production_natural_card_table_headed_capture-f92cd67f`,
  9 frames, `exact_window_match=true`, `diagnostic_count=0`,
  `task_introduced_error_count=0`, `residual_process_count=0`.
- Headed final-settlement run:
  `20260826-081220-684-v076_production_natural_final_settlement_headed_capture-d1f35eb5`,
  3 frames, `exact_window_match=true`, `diagnostic_count=0`,
  `task_introduced_error_count=0`, `residual_process_count=0`.
- For each of `CARD_SELECT`, `CARD_PLAY_PUBLIC`, and
  `CARD_RESOLUTION_FOCUS`, the capture, queued cue, finished cue, queue/finish
  envelopes, and start/finish bridge evidence bind to the same non-empty
  receipt; Director queue and finish counts are exactly one. All 12 frame PNGs
  are non-empty 1600x960 files whose SHA-256 values match the manifest.
- The bundle is `natural_gameplay_automation=true`, `human_executed=false`,
  `human_confirmed=false`, `human_green=false`, `production_green=false`,
  `commercial_m1_green=false`, with `STEP13_STATUS=PENDING`,
  `STEP14_STATUS=PENDING`, and `STEP15_STATUS=PENDING`.
- Evidence: [natural_production_cue_proof.json](natural_production_cue_proof.json),
  [production_natural_headed/20260826-081006-934-12bb685a3d67/manifest.json](production_natural_headed/20260826-081006-934-12bb685a3d67/manifest.json),
  and [production_natural_headed/20260826-081006-934-12bb685a3d67/runner_report.json](production_natural_headed/20260826-081006-934-12bb685a3d67/runner_report.json).

## Reuse/Point-Inertia hard stop

- Selftest: `120/120 PASS`, false-green count 0.
- Full clean-worktree validation at product/evidence source HEAD
  `12019fdf5ff78733a36b3f0e889fecd1fcfb227c`, using explicit PR base
  `770d741f05964facda4afcbddcdeb3e7f40571d5` and inertia/gate base
  `f6fe547e1e1db57a8bb3a12eab1d9225d4abdca5`: `FAIL`, 569 failures, 510
  historical failures, 67 transitions. The first failure is
  `DYNAMIC_REFERENCE_UNRESOLVED:FileAccess.get_file_as_string:path:scripts/presentation/v076_presentation_animation_director.gd`.
- The prior 445/407 audit established a lower bound of at least 22 failures that
  cannot be resolved by the existing append-only correction mechanisms. The
  new grouped commits do not create an authorized correction path, so that
  lower bound remains valid even though the current totals are higher.
- A blanket exception, scan weakening, fabricated correction, history rewrite,
  or new governance task is not permitted.
- No new governance task is authorized by this checkpoint. The correct status
  is therefore `TRUE_HARD_STOP_REQUIRING_USER_DECISION`.

The report/handoff and evidence files remain an uncommitted worktree delta above
that evaluated source HEAD, so the 569/510/67 counts describe the committed
product/evidence source only. A post-commit exact-HEAD rerun remains mandatory
before any release action.

## Next allowed step

Obtain an explicit decision for the failures outside the existing correction
mechanism. The fixture visual lane is accepted, but only after the full
Reuse/Point-Inertia validation is green may the milestone be re-audited for
`READY_FOR_NEXT_CONSOLIDATED_HUMAN_PLAYTEST=true`. Even then, Human Green and
Steps 13-15 remain pending until a real human completes the required playtest.
