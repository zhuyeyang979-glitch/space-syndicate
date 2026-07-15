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
| `scripts/main.gd` physical lines | 18,972 | 18,829 | -143 |
| `scripts/main.gd` `func` declarations | 1,097 | 1,087 | -10 |
| Full layout failure labels | 52 | 42 | -10 |
| Full smoke retired Main calls | 71 (`31` capture, `40` apply) | 67 (`29` capture, `38` apply) | -4 |

The current Main reduction comes from the Product Codex public-source sceneization.
Test-only migrations do not count as Main reduction.

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
- The latest integrated full layout run completed in 100.284 seconds with ExitCode 1,
  42 remaining assertion labels, no timeout, and zero remaining project processes.
  Evidence run: `20260715-074535-593-layout_scene_smoke_test-f8c1a82b`.
- The current Main composition gate passes. The latest role-focused gate and smoke
  `--check-only` also exit 0.
- The real `FullRunQualityDriver` capability preflight exits `3` by design instead of
  starting a match it cannot restore. Run
  `20260715-080855-341-full_run_quality_driver-2b5172c0` reported `6/18`
  transactional sections, `12` unsupported sections, incomplete RNG/player
  continuation, `failure_code=restore_capability_incomplete`, no timeout, and zero
  remaining project processes.
- `PlayerManaRuntimeController` is now the sixth transactional save owner. Its focused
  gate restores private asset pools, active reservations, terminal receipts, game
  time, and revision exactly; detached registry preflight normalizes the same payload,
  while invalid revisions fail without mutating live state.

## Open production risks

### Full match and save-resume

A trustworthy `FullRunQualityDriver` is not yet allowed to claim success. The v0.6
save registry currently has only 6 of 18 required transactional sections. The shared
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

The complete smoke test still times out. The most recent diagnostic run passed Role
Codex, random-role, and role-budget blocks before reaching a Military variant-facts
assertion and an AI military-command block that still called a retired Main snapshot
wrapper. Migration is proceeding one ownership block at a time. The check-only result
does not substitute for a complete run.

### Action feedback

The first ActionResult slice is in development. Audit found that the old clickable
fixed priority-bid path calls an API the current Queue owner deliberately removed.
That dead UI is being retired rather than wrapped as a false success. The first real
consumer will be the existing card-group ready action. Buy, play, target, wager,
military, route, contract, and weather actions remain outside this first slice.

### 1280x720

The historical layout gate mixes a 1706x960 logical canvas with a 1280x720 physical
window, so its out-of-bounds labels are not sufficient evidence by themselves. Real
captures also found a genuine map-density problem. A production-only presentation
pass is currently validating deterministic clear, forecast, active, and dual-weather
states at 1280x720, 1600x960, and 1920x1080. No result is accepted unless the scene
tree, complete PNG pixels, console, save isolation, and process cleanup all pass.

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

The 42 current labels include:

- RightInspector why/availability restoration;
- current card-group/BidBoard contract drift;
- environment-only MCP configuration checks;
- historical Main hash and old characterization contracts;
- scenario phase-count drift;
- Victory and capacity owner oracles;
- corrected 1280 coordinate and real-pixel coverage;
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
| Is 1280x720 proven playable? | Not yet; real deterministic matrix is in progress. |
| Are all major failures specific and actionable? | Not yet; ActionResult coverage is only beginning. |
| Are AI personalities publicly readable without cheating? | Not yet. |
| Can settlement explain the match from authoritative receipts? | Not yet. |
| Has Main continued to shrink? | Yes, by 143 physical lines and 10 functions from baseline. |

## Next highest priorities

1. Continue smoke/layout contract migration until the first remaining failures are
   current production behavior rather than retired entry points.
2. Land the fail-closed FullRunQualityDriver preflight, then make v3 save continuation
   transactional owner by owner.
3. Complete the deterministic 1280 production matrix and fix only demonstrated visual
   defects.
4. Land ActionResult for a real action and remove the dead priority-bid controls.
5. Introduce sanitized public receipts before claiming observable AI strategy or an
   explanatory settlement.

No stage has been pushed to GitHub from this report. Local integration remains the
review and regression boundary until the evidence is coherent.
