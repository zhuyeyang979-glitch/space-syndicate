# Game Quality Report

Status: work in progress; no release or full-match claim

Date: 2026-07-15

Frozen baseline: `fdb62bd2896dd19d01c8660a2a39cd541de2553b`

Local integration branch: `codex/a-v06-local-integration`

This report separates verified production evidence from migrated historical tests and
unverified player-experience hypotheses. It will remain explicitly incomplete until a
real four-seat match can save, reload, reach the authoritative victory audit, and show
the production settlement exactly once.

## Current source delta

| Metric | Frozen baseline | Current local integration | Delta |
|---|---:|---:|---:|
| `scripts/main.gd` physical lines | 18,972 | 18,631 | -341 |
| `scripts/main.gd` `func` declarations | 1,097 | 1,075 | -22 |
| Full layout failure labels | 52 | 30 | -22 |
| Full smoke retired Main references | 71 (`31` capture, `40` apply) | 61 (`27` capture, `34` apply) | -10 |

The current Main reduction comes from the Product Codex public-source sceneization and
the physical retirement of the non-authoritative priority-bid UI path. Test-only
migrations do not count as Main reduction.

## Verified progress

- The Role Codex public contract passes `159/159` and no longer depends on a retired
  Main save wrapper.
- The role-selection and budget smoke block now restores only its explicit setup
  fields. Its focused contract and script check pass.
- The Human First Table gate passes `26/26` after removing the retired private-discard
  rescue oracle and using the real starter-card -> card-resolution -> Monster owner
  path for optional summon.
- Product Codex browser/detail facts now come from a scene-owned public source service.
  The old Main formatter/source cluster is physically absent, and focused private-state
  invariance gates pass.
- Layout ownership checks now use the current Military, CommodityFlow,
  RegionInfrastructure, RouteNetwork, and non-owning bridge boundaries. The full
  layout run has no parser or invalid-method failure.
- The latest integrated full layout run completed in 51.554 seconds with ExitCode 1,
  30 remaining assertion labels, no parser/API error, no timeout, and zero remaining
  project processes. The fixed priority-bid fixtures and assertions are now physically
  retired: the current gate verifies planning confirmation, both public-track pointers,
  bid-board/public-track hover in both directions, stable selection, RightInspector
  preview, and the single `card_group_ready` action. Evidence run:
  `20260715-085651-117-layout_scene_smoke_test-a500ae37`.
- The current Main composition gate passes. The latest role-focused gate and smoke
  `--check-only` also exit 0.
- The real `FullRunQualityDriver` capability preflight exits `3` by design instead of
  starting a match it cannot restore. Run
  `20260715-083927-711-full_run_quality_driver-231ccc6f` completed in 7.464 seconds and
  reported `7/18`
  transactional sections, `11` unsupported sections, incomplete RNG/player
  continuation, `failure_code=restore_capability_incomplete`, no timeout, and zero
  remaining project processes.
- `PlayerManaRuntimeController` is now the sixth transactional save owner. Its focused
  gate restores private asset pools, active reservations, terminal receipts, game
  time, and revision exactly; detached registry preflight normalizes the same payload,
  while invalid revisions fail without mutating live state.
- `BankruptcyNeutralEstateRuntimeController` is the seventh transactional owner. Its
  lifecycle and neutral-rent journals restore exactly, while strict input allowlists
  reject private participant fields and invalid last-survivor references atomically.

## Open production risks

### Full match and save-resume

A trustworthy `FullRunQualityDriver` is not yet allowed to claim success. The v0.6
save registry currently has only 7 of 18 required transactional sections. The shared
RNG and complete authoritative player cash/card continuation are also not covered.
The driver must therefore fail capability preflight instead of reviving
`_capture_run_state`, simulating reload, forcing planet destruction, or directly
applying a victory receipt.

Required before the 20-seed release gate:

1. All 18 save owners support strict capture, preflight, apply, and rollback.
2. RNG and complete player continuation have one authoritative owner path.
3. A fresh Main instance loads the v3 envelope and continues the same public timeline.
4. One seed reaches the real qualification, audit, final recheck, session finish, and
   settlement path without a forced outcome.
5. Four presubmit seeds and then all 20 fixed release seeds complete without softlock.

Current status: **not verified and not shippable**.

The fail-closed preflight itself is now independently reproduced on the local
integration branch. It is evidence of the capability gap, not a completed-match
result.

### Full smoke

The complete smoke test still times out. Both the AI military-command and force-deploy
blocks now use current Region, Route, AI, and Military owner facts; the focused
Military gate passes `49/49`. Run `20260715-083750-404-smoke_test-dcb8655b` reached the
300.309-second hard limit with both target blocks passing and no remaining process. It
moved the next retired Main snapshot error to `_verify_direct_player_interaction_cards`.
Before that wrapper, the same run reports active assertion failures in role weather
benefits and card-strategy/development-route coverage; those still require production
versus stale-contract classification. Migration is proceeding one ownership block at
a time. The check-only result does not substitute for a complete run.

### Action feedback

ActionResult v1 is now integrated for the existing card-group ready action. Its strict
public result carries success, failure code, title, explanation, consequence,
suggested action, focus target, cost, requirement, and affected public entity IDs
through a scene-owned presentation service. The old clickable fixed priority-bid path
had no current Queue authority, so its executable UI, Main dispatch, synthetic bid
state, and twelve Main helpers were physically retired instead of wrapped as a false
success. Buy, play, target, wager, military, route, contract, and weather actions remain
outside this first slice.

On integrated commit `20328b8`, `action_result_v1_test.gd`
(`20260715-082427-665-action_result_v1_test-7d73062b`),
`main_runtime_composition_test.gd`
(`20260715-082446-508-main_runtime_composition_test-d549930b`), UI text
(`20260715-082501-006-ui_text_smoke_test-bae3831f`), and smoke `--check-only`
(`20260715-082509-582-smoke_test-7b9be643`) all returned ExitCode 0 with no timeout or
remaining project runtime process.

### 1280x720

The historical layout gate mixes a 1706x960 logical canvas with a 1280x720 physical
window, so its out-of-bounds labels are not sufficient evidence by themselves. Real
captures also found a genuine map-density problem: the original 1280 frame contained
262 hard label/token overlaps and 6 district collisions. The production presentation
pass has now reduced both counts to zero without changing Main, rules, owners, save
state, or private data.

The deterministic production matrix covers clear, forecast, active, and dual-weather
states at 1280x720, 1600x960, and 1920x1080. All 12 real `main.tscn` captures pass the
scene-tree, stable-frame, PNG pixel, public weather, machine-identifier, save-isolation,
console, and process-cleanup gates. The complete evidence is in
`reports/ui/production_acceptance/e_1280_table_readability_v2/after_acceptance.md`.
This proves the scoped table and map presentation is readable at 1280. It does not yet
prove that every first-run interaction, temporary decision window, economy workflow,
countdown, and settlement can be completed at that resolution. Top-bar ellipsis and
the economy overview's text density remain active findings.

On local integration `14836e0`, Codex A independently reopened the final 1280
dual-weather PNG at original resolution and reran `ui_text_smoke_test.gd`
(`20260715-082220-876-ui_text_smoke_test-fdd60f6e`), `visual_snapshot.gd`
(`20260715-082228-844-visual_snapshot-9052b0cf`), and `smoke_test.gd --check-only`
(`20260715-082237-374-smoke_test-d715d595`). All three returned ExitCode 0 without a
timeout or remaining project runtime process.

## AI and settlement evidence

Six internal AI tendencies exist, but their private scores, plans, targets, learning
samples, and hidden actor facts cannot be copied into player-facing logs. Production
settlement currently has strong public Victory GDP/control facts and authorized cash,
but several requested explanations are zero-filled, caller-authored, or lack a durable
public receipt ledger.

The safe direction is an append-only, sanitized public receipt journal in the existing
session owner, followed by actorless observable-tendency aggregation and settlement
evidence that cites receipt IDs. Until those owner handoffs exist, the game must say
that evidence is unavailable rather than invent a turning point or expose AI weights.

## Remaining layout groups

The 30 current labels include:

- RightInspector why/availability restoration;
- one historical v0.5 SharedCardGroupWindow phase-duration contract;
- environment-only MCP configuration checks;
- historical Sprint 40 formula-dispatch and AI policy registry contracts;
- historical 1280 coordinate assertions that still need migration to the now-green
  real-pixel production evidence;
- live map, public-track, card play, and market purchase flows;
- Card Codex/RightInspector presentation details.

Each old oracle must be replaced with point-for-point current-owner evidence. Failure
counts may not be reduced through ignore lists or by deleting a test without a new
gate.

## Quality verdict

| Question | Current answer |
|---|---|
| Can a player enter a real game? | Yes, focused and headed captures prove the production scene starts. |
| Can the first-table core path run? | Focused `26/26`; full-match continuity remains unverified. |
| Can a complete match be proven to finish? | No. |
| Can save, exit, reload, and continue to settlement be proven? | No; capability preflight is incomplete. |
| Is 1280x720 proven playable? | The real table/map readability matrix is green; complete first-run interaction at 1280 is not yet proven. |
| Are all major failures specific and actionable? | Not yet; ActionResult coverage is only beginning. |
| Are AI personalities publicly readable without cheating? | Not yet. |
| Can settlement explain the match from authoritative receipts? | Not yet. |
| Has Main continued to shrink? | Yes, from 18,972 lines / 1,097 functions to 18,631 / 1,075: net -341 lines / -22 functions. |

## Next highest priorities

1. Continue smoke/layout contract migration until the first remaining failures are
   current production behavior rather than retired entry points.
2. Land the fail-closed FullRunQualityDriver preflight, then make v3 save continuation
   transactional owner by owner.
3. Exercise the complete first-run, economy, decision-window, countdown, and settlement
   interaction path at 1280; fix only defects demonstrated by those real runs.
4. Expand ActionResult from card-group ready to the remaining major player actions,
   one authoritative owner at a time.
5. Introduce sanitized public receipts before claiming observable AI strategy or an
   explanatory settlement.

No stage has been pushed to GitHub from this report. Local integration remains the
review and regression boundary until the evidence is coherent.
