# Alpha 0.4-A audit-tail disposition and clean landing

## Decision

`ALPHA_0_4_A_COMPONENT_ACCEPTANCE=GREEN`.

The second authorized Formal remains **INCOMPLETE**. It entered an active
Victory audit but the bounded observation window ended before `resolved`.
Alpha 0.4-A is accepted only under the strict component-landing contract:
the settled terminal-green ancestor is unchanged, terminal-critical owners have
zero diff, the Formal-traversed component path is semantically equivalent in
the clean extraction, and the exact clean candidate passes its bounded
component gates.

This decision does not claim an exact-head terminal Formal or release
acceptance:

```text
EXACT_FORMAL_HEAD_FULL_RUN_TO_TERMINAL_PROVEN=false
FULL_RUN_TO_SETTLEMENT_GREEN=false
RELEASE_LEVEL_FULL_RUN_DEFERRED=true
```

No third Formal, renamed Formal equivalent, extended audit probe, full smoke,
or Alpha 0.4-B implementation was run.

## Baseline and evidence chain

- Repository: `zhuyeyang979-glitch/space-syndicate`
- Main baseline at extraction: `b5763bbfb96994aa55ab36ae4335db332d9818a8`
- Settled terminal-green ancestor:
  `b5d5682072fd9ff02be700ce9d5503d1df996641`
- Frozen source: Draft PR #72 at
  `54095570fa4783fda7e3386cde5fa2a16be761b8`
- Second Formal production head:
  `30a6d87c545df2d8de3c369dec5fb2b3d57a1e92`
- Formal evidence commit:
  `b4b1475153dee6e3d6e3efbbd73e47a65b34eb06`
- Clean landing branch: `codex/alpha04a-clean-landing-b5d568`
- Clean production checkpoint:
  `dbc5ae6eb6fed354fe8d00825a105780ba0ae84b`

The source branch matches its remote at 0/0 divergence. From the Formal
production head to the frozen source head, production-code diff count is zero.
The original source worktree has no tracked or staged mutation; its 28 known
untracked local artifacts were preserved and were not used by the extraction.

## Formal history retained verbatim

There were two Formal commands in total and one separately authorized rerun.
No third run is authorized or performed.

Formal 2 ended with
`observation_window_elapsed_before_settlement` after 181.437 driver wall
seconds, 174.654 session wall seconds, and 185.634705 world seconds. It had:

- two facilities and two production installations;
- 22 Sale Receipts, first at world second 62.391742;
- a real matched `磁核榴莲` / `energy` chain at 10 production, 10 demand,
  five settled, and five transported units;
- four controlled regions against three required, Top-K GDP 1612 against 108,
  eligibility true, and zero post-eligibility installation delta;
- zero invalid actions and zero nonfinite values;
- `idle -> qualification -> audit`, but no `resolved`;
- zero FinalSettlement, presentation, public-log, or terminal-quiescent frames;
- terminal world and RNG deltas of `-1`, meaning unobserved, not zero; and
- 159/159 authoritative active steps, last progress
  `victory_timer_audit`, zero steps since progress, and no stall.

Player Card Dock evidence in that Formal was green: normal and commodity cards,
source and inventory artwork, direct single-click claim, zero duplicate claim,
zero visible/hidden claim button, zero duplicate submission, 675 refreshes, and
all five performance measurements were observed.

The correct audit-tail classification is:

```text
AUDIT_TAIL_CLASSIFICATION=BOUNDED_WINDOW_ENDED_DURING_ACTIVE_AUTHORIZED_AUDIT
```

## Terminal-critical owner audit

Owner discovery covered Victory eligibility and timers, FinalSettlement runtime
and presentation composition, the final public log, RuntimeLoop terminal
freeze, WorldEffectiveClock, RunRngService, GameSession terminal state, Save
coordination, rollback, quiescence, and post-terminal mutation. Against the
terminal-green ancestor:

| Gate | Diff count |
| --- | ---: |
| Terminal runtime owners | 0 |
| Victory rules | 0 |
| Victory timers | 0 |
| FinalSettlement runtime | 0 |
| RuntimeLoop terminal behavior | 0 |
| World-effective clock formula | 0 |
| Terminal RNG | 0 |
| Terminal Save | 0 |
| Terminal state injection | 0 |

The one QA diff is observation-only in `full_run_quality_driver.gd`. It adds
Dock observation, a commodity claim, presentation gates, performance samples,
and report fields; it does not write Victory state or time, invoke settlement,
inject terminal state, bypass RuntimeLoop, add RNG draws, or alter rules.

Therefore `TERMINAL_RUNTIME_REGRESSION_FOUND=false`.

## Strict clean-extraction equivalence

The second Formal head and clean candidate are sibling descendants of the
terminal-green base; the Formal head is not falsely described as a candidate
ancestor. The Formal supplies only component-path observation. Terminal-green
status comes only from the real ancestor.

The extraction map is exhaustive. V0.7 reference commits `e19eb4a`,
`2c841a2`, and `cde98ae` are excluded; merge `e6dc983` is replaced by the
direct `b5d5682` base. Source task-state `9b2efd8`, stale handoff `c0b2108`,
and source program-state commits `30a6d87`/`5409557` are classified omissions
and regenerated where required. Product/evidence mappings are
`b6430d6 -> baf00c1`, `a815b31 -> 214638c`,
`b230833 -> 9f95a80` (registry regenerated without reference-ready state),
`9ed2bb6 -> ac166ce` (long world probe excluded), and
`b4b1475 -> bd51858`. The last source-derived extraction destination is
`bd51858`, a real candidate ancestor; unmapped source commit count is zero.
Clean-only successors `92e0d8d` and `dbc5ae6` add the strict contract and the
enumerated nonsemantic normalization.

All 68 Alpha 0.4 production-required paths exist on both sides. Sixty-two are
byte-identical. The remaining six differ only by enumerated EOF whitespace
normalization:

- `scenes/runtime/presentation/PlayerCardDockViewerQueryPort.tscn`
- `scripts/presentation/player_card_dock_projection_service.gd.uid`
- `scripts/presentation/player_card_dock_projection_v1.gd.uid`
- `scripts/presentation/player_card_dock_viewer_query_port.gd.uid`
- `scripts/ui/table/card_dock_action_feedback.gd.uid`
- `scripts/ui/table/player_card_dock.gd.uid`

Behavior-bearing mismatch, terminal-critical mismatch, unclassified
difference, and post-extraction behavior-change counts are all zero. This is a
component dependency-closure equivalence claim, not a whole-tree equivalence
claim.

## Product scope retained

The clean candidate retains the production Player Card Dock and its normal,
commodity, and honestly empty bound-action pools. PlayerBoard's legacy HandRack
entry and RightInspector's card-play entry are retired while other inspector
duties remain. Action Spine is the only card submission path.

Commodity cards support mouse, keyboard, controller, drag deadzone, and
exact-once double-click behavior. A card-face click performs a source-bound,
identity-bound claim with structured failure and no visible or hidden “click to
get” button. Twelve distinct abstract commodity illustrations cover all 48
level card IDs, and source/inventory use the same illustration key.

The viewer-private projection exposes no rival, future, RNG, or hidden-owner
data. No new Main responsibility, Save owner, RNG owner, or RNG draw point was
introduced.

Production capacity remains V0.6 shared capacity:

```text
RUNTIME_CAPACITY_MODE=SHARED_V06
NORMAL_AND_COMMODITY_SHARED_LIMIT=5
FULL_V07_INDEPENDENT_5_PLUS_5=false
```

## Reference-only exclusions

The clean extraction includes none of the PR #70/#71 V0.7 Card Batch runtime,
semantic, AI, UI, Bench, test, screenshot, orbit, or roster reference stack.

```text
REFERENCE_ONLY_RUNTIME_FILE_COUNT_IN_LANDING=0
REFERENCE_ONLY_UI_FILE_COUNT_IN_LANDING=0
REFERENCE_ONLY_BENCH_FILE_COUNT_IN_LANDING=0
REFERENCE_ONLY_TEST_FILE_COUNT_IN_LANDING=0
UNRESOLVED_REFERENCE_DEPENDENCY_COUNT=0
```

The raw PR #70/#71 path-set intersection is four:
`docs/development_log.md`, the semantic registry JSON/MD, and
`tests/game_action_semantic_protocol_v1_test.gd`. Their landing hunks are clean
regeneration or selective Alpha 0.4 evidence, not reference-only content. The
classified 92-path reference-only E-set intersection is zero. At production
checkpoint `dbc5ae6`, all 96 new `res://` references resolve; after final
contract, registry, ratchet, and handoff documentation, the full candidate has
110/110 resolved references. V0.7 remains the highest development constitution,
but no full V0.7 runtime cutover, independent 5+5 inventory, Card Batch
production owner, commodity-track Core cutover, Save migration, or AI Card
Batch cutover is included.

## Exact clean-candidate validation

Forty-four unique bounded suites passed. These cover:

- Alpha 0.4 projection, Dock audit/layout/cutover, real pools, target
  selection, GameScreen integration, direct claim, all commodity art, public
  track, claim-to-sale forced capacity, Dock/Planner parity, and invariants;
- the card semantic protocol, Action Spine application flow, actor
  authorization, identity/privacy boundaries, exact-once submission, duplicate
  surface prevention, and regenerated global registry;
- Victory split precision and transition order, qualification/audit timers,
  audit-to-resolved, FinalSettlement/presentation/public-log exact-once,
  RuntimeLoop freeze, eight-frame quiescence, terminal world/RNG zero,
  post-eligibility guard, settlement composition, Save checkpoint, static
  FullRun Driver contract, and authoritative stepper policy; and
- Main architecture/composition/dependencies, Save and RNG invariants,
  simulation determinism, card illustration, semantic architecture scan, UI
  text, visual snapshot, and smoke `--check-only`.

The refreshed structural semantic lock passes at 575 production scripts,
30,894 literal accesses, 4,674 distinct keys, 26,697 signatures, and 470
matched files. `git diff --check` is green.

Three inherited fixture debts are explicitly excluded, not reported as green:

- `commodity_card_inventory_runtime_test`: already 17/43 at `b5d5682`;
- `player_facing_privacy_boundary_test`: a pre-b5 retired-Main-API oracle; and
- `session_envelope_save_owner_test`: an unchanged 92/93 Main string oracle.

Alpha 0.4 changes none of the failure-causing stale fixture/oracle targets, and
no retired compatibility wrapper was restored. Active privacy, Save, RNG, and
Main gates are green.

Every terminal validation here is a bounded component fixture:

```text
COMPONENT_TEST_ONLY=true
FORMAL_FULL_RUN=false
END_TO_END_TERMINAL_PROOF=false
FULL_SMOKE=false
SMOKE_CHECK_ONLY=true
```

## Player-visible evidence

The committed production capture has 176/176 checks, zero failures, and eight
screenshots, including readable 1366×768 and 1920×1080 layouts. Its result file
SHA-256 is
`2758e351a4336a7d2a7a8384159e34cd4bec58b84922e4bd898e8e128865281b`.

One exact-clean headed recapture was attempted, as permitted. It produced three
frames but ended incomplete with two harness failures among 77 checks when the
forced production action was not clickable and the control was subsequently
freed. It found no new script/runtime regression, was not retried, its partial
outputs were removed, and it does not supersede the committed 176/176 evidence.

`PLAYER_VISIBLE_PRODUCTION_CAPTURE_GREEN=true` is based on that committed real
production evidence, the verified 68-path behavior equivalence, exact-candidate
functional gates, and manual review of both required layouts—not on a false
claim that the exact-clean recapture completed.

## Godot MCP and runtime composition

Godot MCP started the real `res://scenes/main.tscn` under Godot 4.7. There were
zero new script or runtime errors. Static scene composition contains exactly one
each of PlayerCardDock, TopCommoditySushiTrack, PlanetBoard, PlayerBoard, and
RightInspector. The project was stopped and the final Godot process count is
zero.

## Semantic and program boundaries

The regenerated registry has 28 domains: 21 Core-ready, one AI-ready, 12
Player-ready, one ready across all three layers, 12 Main-dependent, and 28
production-surface domains. Global three-layer completion remains false.
Player Card Dock is Core/Player ready, AI contract-only, and bound-action
blocked.

The production ruleset remains V0.6. V0.7 remains the target constitution.
Full presentation-shell cutover, Save/Resume readiness, global three-layer
completion, and full V0.7 runtime cutover remain false.

## PR lifecycle

Clean landing PR #73 targets `main` from
`codex/alpha04a-clean-landing-b5d568`. It is Ready and may be merged only while
the remote main baseline and every gate above remain valid. A merge commit is
preferred so the terminal-green ancestor and Alpha 0.4 extraction remain
auditable.

PR #72 remains the frozen Draft Formal evidence source and must not be rebased,
retargeted, marked Ready, or merged directly. After the clean PR lands, PR #69
and PR #72 may be closed as superseded. PR #70 and PR #71 remain open Draft
reference-only work and are neither merged nor presented as production.

The next product boundary, and only after clean landing, is
`ALPHA_0_4_B_PRODUCTION_ROSTER_REGION_POPUP_AND_RIGHT_INSPECTOR_RETIREMENT`.
No part of that boundary is implemented here.
