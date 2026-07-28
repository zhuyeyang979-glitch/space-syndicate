# Alpha 0.4 Player-Visible Table Shell and Card Dock Cutover

Status: `PARTIAL`

Integration base: `aea16c917b812bbfea8ccdffe5308285116d40b3`

Branch: `codex/alpha04-player-visible-shell-integration`

The integration contains the terminal-green lineage from PR #69, the V0.7
three-layer reference from PR #70, and the shell/orbit-seat reference cleanup
from PR #71. All three required commits are ancestors of the integration base.

## Structural production cutovers completed

- `PlayerCardDockViewerQueryPort` provides one viewer-authorized V0.6
  projection with separate normal, commodity, and bound-action arrays.
- `PlayerCardDock` is the only production card surface. It renders real
  `CardFace` nodes and emits only typed `GameActionOfferV1` requests.
- Capacity remains truthful: `capacity_mode=SHARED_V06`; the UI does not claim
  the future independent V0.7 5+5 rule.
- `PlayerRosterViewerQueryPort` and `PlayerRoster` replace production orbit
  seats with one left-side column for 3–4 players and two columns for 5–8.
- `RegionSupplyPopup` replaces the fixed district rack. Quote and purchase
  actions use the typed Application Flow and `DistrictSupplyActionPort`.
- `ContextDetailPopup`, `PlayerInspectionPopup`, `NonBlockingToast`, and
  `CardDockActionFeedback` cover the former fixed inspector responsibilities.
- The typed resolution overlay consumes V0.6 resolution facts honestly. Main's
  overlay builder/timer/right-rail path and the orphan countdown surface are
  removed.
- Production `RightInspector`, `HandRack`, `RoleSeatLayerHost`, `BackSeatLayer`,
  and `FrontSeatLayer` are absent. Main has no replacement card/popup/roster
  state or callback.

## Main reduction

| Metric | Integration base | Current candidate |
| --- | ---: | ---: |
| Physical lines | 5,664 | 5,249 |
| Nonblank lines | 4,671 | 4,300 |
| Methods | 440 | 417 |
| Top-level fields | 46 | 36 |
| Constants | 44 | 44 |
| Preloads | 6 | 6 |

No new Main caller, fallback, Save owner, Save section, RNG owner, or RNG draw
point was added.

## Real production evidence

- A real starter monster card is visible in the production Dock and submits
  through `GameScreen -> GameActionIntentV1 -> Application Flow`.
- A real regional rack quote/purchase enters the normal-card pool exactly once.
- A real sushi-track claim enters the commodity pool exactly once; replaying
  the same claim adds no second card and consumes no presentation RNG.
- Rival viewers cannot query the local player's Dock. Public/roster/popup
  projections omit rival cash, hands, discards, hidden owners, AI plans, future
  racks, and future track order.

The original normal-hand failure class was
`HAND_SOURCE_NORMALIZATION_DROPPED`: the V0.6 catalog adapter normalized only
facility machine cards, so other shipped machine-card identities could not
complete the private hand source -> card presentation -> Dock projection
chain. The adapter now normalizes every non-empty shipped V0.6 machine card;
the authority, capacity and effect owners are unchanged.

## Bound-action production blocker

The bound-action target and projection contract are ready, including source-UID
filtering, zero capacity cost, stale/duplicate rejection, and privacy tests.
Production acquisition is not ready:

1. The current atomic starter-monster profile explicitly provides
   `bound_skill_patch={}`, so a legally played starter monster grants no bound
   action.
2. A military card can be legally bought and displayed, but submitting
   `deploy_or_upgrade_military` through the V0.6 Action Spine fails closed with
   `v06_card_effect_route_unavailable`.

The focused production gate proves this failure and preserves the military card
without injecting a bound action. It does not call legacy grant helpers or a
domain owner directly. Adding the missing route would be a gameplay capability
change and is outside this presentation-only cutover.

Therefore:

```text
NORMAL_CARD_PRODUCTION_VISIBILITY_GREEN=true
COMMODITY_CARD_PRODUCTION_VISIBILITY_GREEN=true
BOUND_ACTION_PRODUCTION_VISIBILITY_GREEN=false
FULL_V0_7_RUNTIME_CUTOVER=false
MERGE_TO_MAIN_ALLOWED=false
```

## Focused validation

- Player Card Dock projection: 37/37 pass.
- Player Card Dock target mode: 11/11 pass.
- Real production reachability/blocker gate: 27/27 characterized; bound route
  remains explicitly blocked.
- District purchase/projection/receipt: 65/65 pass.
- Player-facing privacy: 48/48 pass.
- Single-side Roster and contextual detail: 30/30 pass, including the 3/4/5/8
  one-column/two-column matrix and stable public order.
- Region Popup target: 21/21 pass; typed Action Spine lifecycle: 19/19 pass.
- Legacy player-surface retirement Bench: 27/27 pass.
- Card-resolution typed pipeline: 47/47 pass.
- Table presentation parity: 106/106 pass.
- FullRun driver contract: 197/197 pass.
- Main runtime composition: pass.
- Main architecture gate: 234 checks pass.
- UI text, visual contract, smoke `--check-only`, and `git diff --check`: pass.
- Broad `layout_scene_smoke_test`: still fails historical non-Alpha fixtures.
  Its production HandRack, RightInspector, overlap, PlayerBoard-hand, and Main
  drawer assertions were migrated and no longer appear in its failure list.

## Current candidate FullRun

The exact Alpha 0.4 candidate does not yet repeat the PR #69 terminal result,
so the presentation shell is recorded as structurally cut over but not
accepted for merge.

- Run `20260728-201751-988-full_run_quality_driver-760fb582` used the formal
  seed-0 `150/180` contract.
- It acquired and installed two real facilities through the typed Popup/Dock
  path, produced 21 public Sale Receipts, reached Top-K GDP `1678/108`,
  controlled `4/3` regions, entered `idle -> qualification -> audit`, and
  recorded zero invalid actions.
- It exceeded the observation window before `resolved`, FinalSettlement and
  eight-frame quiescence. Result: `FULL_RUN_REGRESSION=fail`.
- The run exposed two retired-fixture assumptions (the old drawer signal name
  and underscore-form UI reason IDs). Both were migrated to the typed Popup
  signal and wire-safe Dock reason IDs; the focused FullRun contract remains
  197/197 and facility policy remains 62/62.

The already-integrated PR #69 acceptance run
`20260728-153746-194-full_run_quality_driver-652209fd` remains valid historical
baseline evidence, but it is not substituted for a passing exact-candidate
run.

## Godot MCP and visual evidence

An independent Funplay endpoint at `http://127.0.0.1:8835/` reported the exact
integration worktree and Godot `4.7-stable`. It opened and ran production
`main.tscn`, production `GameScreen.tscn`, and the production
`PlayerCardDock.tscn`; the runtime Dock was visible at `1568x190` and owned the
three expected pools. Runtime/script error count was zero and play/editor
stopped cleanly. Six existing post-stop NUL diagnostics remain separately
classified as repository baseline warnings.

The required named production screenshot set is not committed. In particular,
`production_bound_actions_visible.png` cannot be captured truthfully because
the production acquisition route does not exist. No fixture or injected bound
action image is used as a substitute.

Therefore:

```text
PRODUCTION_PRESENTATION_SHELL_STRUCTURAL_CUTOVER=true
PRODUCTION_PRESENTATION_SHELL_CUTOVER=false
FULL_RUN_TO_SETTLEMENT_GREEN=false
VISUAL_EVIDENCE_SET_COMPLETE=false
```

## Next atomic boundary

`V06_BOUND_ACTION_TYPED_ACQUISITION_LIFECYCLE_CUTOVER`

It must add one typed gameplay acquisition route with exact-once grant/revoke,
rollback, checkpoint/Save, privacy, deterministic RNG, source departure, and
human/AI shared-intent gates. It must not restore the legacy monster grant path
or create a parallel inventory owner. After that boundary, rerun this Alpha 0.4
gate and capture the final real three-pool production evidence.
