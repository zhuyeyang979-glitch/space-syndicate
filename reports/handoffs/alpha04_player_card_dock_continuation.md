# Alpha 0.4-A Player Card Dock continuation

Updated: 2026-07-29 08:40 (Asia/Tokyo)

## Outcome

`STATUS=PARTIAL`.

The production Player Card Dock, direct commodity claim interaction, commodity
art, focused tests, production capture, semantic registry, and Godot MCP launch
are complete and pushed. The task cannot be marked GREEN because the one
authorized formal FullRun ended `INCOMPLETE` before sale, victory, settlement,
or terminal quiescence. It was not rerun.

- Draft PR: https://github.com/zhuyeyang979-glitch/space-syndicate/pull/72
- Draft base: `codex/v07-table-shell-orbit-retirement-e19eb4a` (PR #71 head)
- Merge to main: forbidden until a separately authorized terminal FullRun is
  green and the prerequisite stack has landed.

## Resume and preservation

- `TASK_ID=ALPHA_0_4_A_PLAYER_CARD_DOCK_CONTINUATION_DIRECT_COMMODITY_CLAIM_AND_ART`
- `RESUME_MODE=EXISTING_DIRTY_TASK_WORKTREE`
- `EFFECTIVE_BASE_SHA=e6dc983be8154908e77d3a11bdee353a1b705152`
- `EFFECTIVE_BRANCH=codex/alpha04-production-player-card-dock-cde98ae`
- `EFFECTIVE_WORKTREE=E:/SpaceSyndicateWorkspace/worktrees/alpha04-production-player-card-dock-cde98ae`
- `UNCOMMITTED_TASK_WORK_PRESERVED=true`
- `REPEATED_PREVIOUS_WORK=false`

The continuation recovered the task-owned dirty worktree without reset, stash,
clean, or replacement. Twenty-three pre-existing untracked UID files and five
obsolete supplemental screenshots remain untracked and were deliberately
excluded from every commit.

## Atomic checkpoints

1. `9b2efd8 chore(continuation): recover Alpha 0.4 card dock task state`
2. `b6430d6 art(commodities): add abstract illustration coverage`
3. `a815b31 feat(ui): cut over card dock and direct commodity claims`
4. `b230833 test(playability): prove production card dock and direct claims`

All four checkpoints are pushed to
`origin/codex/alpha04-production-player-card-dock-cde98ae`.

## Production implementation

- `PlayerCardDockProjectionV1`, its projection service, and the viewer query
  port provide one authorized pure-data projection.
- Production `GameScreen` owns exactly one `PlayerCardDock` containing normal
  cards, owned commodity cards, and an honestly empty bound-action section.
- Normal and commodity actions enter the existing typed Action Spine. The Dock
  owns no gameplay state, inventory mutation, Save data, or RNG.
- The legacy PlayerBoard HandRack action surface and RightInspector card-play
  actions are disconnected, leaving one card-submission surface.
- Production capacity remains `SHARED_V06`; the UI shows one combined 5-card
  cap instead of claiming the future V0.7 independent 5+5 rule.
- `dock_mini` is a dedicated CardUI density mode. RightInspector remains for
  non-card details and is scroll-contained at compact resolutions.

## Direct commodity claim

The source item contains no visible or hidden Button. Mouse single-click,
keyboard Enter/Space, and controller confirm all enter the scene-owned
CommoditySushiTrack Application Flow.

Exact-once protection combines:

- stable slot/card/snapshot/belt/visibility source identity;
- viewer and request revision binding;
- an atomic pending identity before the claim signal escapes;
- accepted-success identity retention until authoritative source refresh;
- rapid source-advance cooldown;
- explicit suppression of the second OS double-click pair;
- source-card-scoped pointer capture, release, drag deadzone, and same-card
  release checks.

Double-click suppression now runs only after a source-card hit test; it does not
swallow clicks over the map, Dock, or unrelated buttons. Full capacity, stale
source, already claimed, invisible, unavailable, authorization, session,
duplicate, and collision failures retain typed codes and render feedback on the
source surface. Failures never mutate source or inventory presentation.

## Commodity art

There are 12 active commodity types, 12 active card families, 48 ranked card
IDs, and 12 unique authored SVG assets:

| Commodity | Abstract visual theme |
| --- | --- |
| 蓝潮藻 | asymmetric tidal algae ribbon held by a hex cargo seal |
| 深海菌毯 | layered abyssal mycelium shelf and luminous pore towers |
| 梦境香氛 | faceted ampoule releasing braided impossible dream vapor |
| 重力陶瓷 | ceramic pylons bending violet gravity orbits |
| 活体芯片 | leaf-shaped biochip with branching neural contacts |
| 光合凝胶 | nutrient droplet with rotating chloroplast lenses |
| 环晶电池 | segmented crystal ring around captive plasma |
| 太阳鳞片 | overlapping stellar scales around a solar ember |
| 星鲸罐头 | orbital canister with a streamlined star-whale seal |
| 风暴珍珠 | iridescent pearl containing a coiled electrical storm |
| 钛壳贝 | armored bivalve around a cold industrial pearl |
| 轨迹墨水 | navigation inkwell crossed by computed orbital paths |

Every rank in a family resolves the same opaque illustration key. Both the
public source track and owned inventory consume that catalog key through the
existing illustration layer. The assets contain no scripts, remote resources,
player text, rules, AI inputs, Save fields, or RNG calls.

## Validation

### Focused regression

Thirteen suites passed: `948 checks / 0 failures`.

- commodity art coverage: 403
- direct claim: 53
- public-track real interaction: 22
- Dock layout: 38
- production cutover: 27
- Dock audit: 20
- projection v1: 37
- real three-pool production: 30
- Alpha 0.4 invariants: 65
- Alpha 0.4 target: 5
- target-mode GameScreen integration: 10
- commodity target selection: 18
- FullRun driver contract: 220

The semantic action protocol separately passed `119 / 119`. Main architecture
remains `219` checks green. Focused privacy, Save/RNG ownership, UI text, and
FullRun policy/component gates are green. Stale global fixture baselines were
not claimed green.

### Production capture

`tests/alpha04_player_card_dock_production_capture.gd` instantiated the real
`res://scenes/main.tscn`, installed an isolated QA Save path before entering
the tree, and used `root.push_input` for menus, mouse, wheel, drag, keyboard,
and controller-style input.

Result: `PASS 176 / 176`, `failures=[]`, player default Save unchanged.
Direct claim-service calls, gameplay-state injection, and private pointer calls
are all zero. Single click, double click, and keyboard each produced exactly
one request, one success, one inventory addition, one belt revision, and one
source removal. Full-capacity failure produced one request and one typed
`shared_hand_capacity_full` failure with zero source, belt, or inventory
mutation.

The five recorded p95 values were:

- source render: 26.537 ms
- inventory render: 15.858 ms
- hover: 165.248 ms
- single click to intent: 0.467 ms
- receipt to inventory refresh: 95.823 ms

The exact eight committed screenshots are:

- `production_commodity_source_abstract_art.png`
- `production_commodity_hover.png`
- `production_commodity_single_click_claim.png`
- `production_commodity_inventory_art.png`
- `production_normal_and_commodity_cards.png`
- `production_commodity_claim_failure.png`
- `production_card_dock_1366x768.png`
- `production_card_dock_1920x1080.png`

### Godot MCP

Godot MCP launched `res://scenes/main.tscn` on
`4.7.stable.official.5b4e0cb0f` with Forward+. Debug output contained no
runtime errors. Existing static warnings and Unicode/NUL import warnings remain
outside this slice. MCP stopped cleanly. The Windows GPU-captured window
returned blank/background content, so it was not used as interaction evidence;
the real headed production capture above is the interaction oracle.

## One formal FullRun

Command:

```text
godot --headless --path . --script res://scripts/tools/full_run_quality_driver.gd -- --seed-index 0 --observation-seconds 150 --max-wall-seconds 180
```

- formal command count: 1
- formal rerun count: 0
- seed: `900626424`
- exit: 1
- status: `INCOMPLETE`
- failure: `observation_window_elapsed_before_settlement`
- process wall/session wall/world: `166.235 / 153.906 / 55.647202` seconds
- actions attempted/progressed/invalid: `134 / 130 / 0`
- facilities/sales: `1 / 0`
- victory sequence: `idle`
- final settlement: 0
- terminal quiescent frames: 0
- terminal world/RNG deltas: not observed (`-1 / -1`)

All newly added player-surface gates were green in that same run:

- normal and commodity cards visible;
- source and inventory art visible;
- direct commodity claim succeeded;
- claim request count 1;
- duplicate commodity claims 0;
- claim Buttons 0;
- duplicate card submissions 0;
- all five performance metrics had samples and positive values.

The direct claim did not cause this failure through `SHARED_V06` capacity.
A full-hand purchase would have emitted
`district_supply_pending_discard`; the run recorded no such reason and zero
invalid actions. Claiming changed the shared count from roughly 1/5 to 2/5 but
does not install facilities, alter production or demand, or create a sale.

The observed economy mismatch was a shipping factory with production 20 versus
the largest anonymous demand gap, energy 70. The continuation planner selected
`energy / missing_matching_factory` and did not obtain and play that factory
before timeout, so no same-commodity matched row formed. This is not yet
evidence of a Dock adapter regression: the Dock path successfully submitted the
first facility card, 130 of 134 actions progressed with zero invalid actions,
and the mapped fields match the planner contract.

The strongest classification is wall-time/throughput confounding before the
historical first-sale window. This run advanced only 55.647 world seconds in
153.906 session-wall seconds (about 0.36x), while same-seed historical traces
first sold around world 62.486 and 70.596 seconds at roughly 1.18-1.20x
throughput. A pre-existing orphan
`district_supply_purchase_projection_receipt_test.gd` Godot process had been
running since 03:17 and had accumulated about 3500 CPU seconds while the formal
run executed. It was stopped afterward and the final Godot process count is
zero. This is a material environment confound, not proof of external causation;
it does not turn the formal result into a pass or authorize a rerun.

## Invariants

- gameplay value changes: 0
- commodity rule changes: 0
- capacity rule changes: 0
- AI policy changes: 0
- new Save owners/sections: 0 / 0
- Save schema changed: false
- new RNG owners/draw points: 0 / 0
- presentation RNG draw delta: 0
- new Main responsibilities: 0
- `scripts/main.gd`, `scenes/main.tscn`, and `project.godot` diff: 0

## Next single task

`ALPHA_0_4_A_FULL_RUN_ECONOMY_CONTINUATION_DIAGNOSIS`

Use only non-Formal probes:

1. compare old Hand DTO and Dock rows from the same real hand source and require
   identical planner selection, availability, reason, and offer fingerprint;
2. advance seed `900626424` to 75-80 world seconds instead of a wall-time
   budget and prove a first sale with Dock plus early commodity claim;
3. A/B early claim on that short fixed-world probe and compare facility, first
   sale, rack search, and discard trace;
4. measure 10-20 seconds of clean-process throughput for hidden Main versus
   visible Main plus per-frame Dock observation.

Also add the missing
`claim -> purchase/discard -> facility -> matched sale` integration test. A
new terminal FullRun requires explicit separate authorization because this
task's one formal run has already been consumed.

After that gate is green, the next product boundary remains
`ALPHA_0_4_B_PRODUCTION_ROSTER_REGION_POPUP_AND_RIGHT_INSPECTOR_RETIREMENT`.
