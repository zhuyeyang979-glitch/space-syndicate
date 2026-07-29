# Shared Commodity Track Three-Layer Semantics Handoff

```text
STATUS=COMMODITY_TRACK_THREE_LAYER_SEMANTICS_PARTIAL

CURRENT_TASK_INTERRUPTED=false
CURRENT_WORK_DISCARDED=false
CONSTITUTION_AMENDMENT_RECORDED=true

REPOSITORY_CURRENT_VERSION=NO_APPLICATION_VERSION_FIELD; ACTIVE_RULESET=v0.6; CONTENT=alpha01
TARGET_RULE_VERSION=V0.7
RUNTIME_RULE_VERSION=v0.6
FULL_V0_7_CUTOVER=false

NORMAL_CARD_HAND_LIMIT=5
COMMODITY_CARD_HAND_LIMIT=5
HAND_POOLS_ARE_INDEPENDENT=true
NORMAL_FULL_DOES_NOT_BLOCK_COMMODITY=true
COMMODITY_FULL_DOES_NOT_BLOCK_NORMAL=true

CORE_SEMANTICS_READY=false
AI_SEMANTICS_READY=false
PLAYER_SEMANTICS_READY=false

SHARED_TRACK_AUTHORITY_READY=false
SHARED_COMMODITY_TRACK_READY=false
LOCAL_TRACK_VISIBILITY_READY=false
GDP_SUPPLY_BASELINE_READY=false
MARKET_CYCLE_180S_READY=false
PUBLIC_STANCE_HIDDEN_WEIGHT_READY=false
PUBLIC_STANCES_HIDDEN_WEIGHTS_READY=false
PUBLIC_STANCES_READY=false
HIDDEN_WEIGHT_READY=false
HIDDEN_LEAD_IDENTITY_READY=false
FIXED_HIDDEN_LEAD_ORDER_READY=false
REVERSED_MACRO_ROUND_READY=false
SEPARATE_COMMODITY_HAND_READY=false
NORMAL_HAND_LIMIT_5_READY=false
COMMODITY_EXTRA_LIMIT_5_READY=false
LINEAR_COMMODITY_UPGRADE_READY=false
COMPLETE_MACRO_ROUND_END_GATE_READY=false

AI_INFORMATION_FIREWALL_READY=false
AI_MARKET_DECISION_READY=false
AI_COMMODITY_DECISION_READY=false
PLAYER_UI_PROJECTION_READY=false
PLAYER_INFORMATION_PROJECTION_READY=false

OLD_RULE_AUTHORITY_DISABLED=false
OLD_RULE_WRITE_PATHS_DISABLED=false
FULL_RULE_CUTOVER=false
SINGLE_RUNTIME_AUTHORITY=true
DETERMINISTIC_TESTS_GREEN=false
SAVE_LOAD_SEMANTICS_GREEN=false
```

The requested `READY` fields describe production readiness, so they remain
false. `HAND_POOLS_ARE_INDEPENDENT=true` above records the approved V0.7
constitution and executable reference, not current production behavior; the
v0.6 runtime still uses one mixed hand. The corresponding nonproduction
reference gates for independent capacity, GDP distribution, 180-second cycle,
hidden weighting/order, linear merge, nested privacy, AI decisions and player
projection are green, but cannot be promoted to production-ready until the
actual runtime consumers and Save schema migrate and the old writers are
deleted.

## Delivered semantics

### Core reference

- stable six-color IDs and exact 10,000bp initial apportionment;
- parameterized GDP baseline and deterministic fixed-point normalization;
- 180-second simulation-time precommit, lock, simultaneous reveal and
  multi-boundary traversal;
- ordinary `300bp` and current hidden lead `600bp`, with public receipt
  redaction;
- one detached seeded hidden order and alternating forward/reverse macro
  rounds for 3-8 seats;
- actor-local projection from one shared fixture sequence;
- separate `normal_card_count/limit` and `commodity_slot_count/limit` state;
- deterministic add/overflow transactions proving 5+0, 0+5, legal 5+5 and
  independent sixth-card failures;
- linear merge reducer that releases one commodity slot without changing the
  normal hand, plus pure reference persistence round-trip;
- ordinary pending-end/revalidation reducer.

### AI reference

- core/query-owned `SharedCommodityTrackSemanticQuerySourceReference` is the
  only reference object that accepts complete authority fixtures;
- owner-bound `CommodityMarketObservation` with exact nested allowlists;
- Easy/Normal/Hard/Expert market stance interpretation;
- local claim and L2/L3/L4 accumulation decisions;
- identical `MarketStanceIntent` schema for AI and human actors;
- cross-seat impersonation rejection and hostile nested Save/RNG/lead/weight
  stripping across demand, history, stance and inventory rows;
- no full track, hidden order, other private stance/inventory, contribution,
  RNG or Save access.

### Player reference

- core-provided six-color final/baseline/trend rows and cycle timer;
- public revealed stance list;
- actor-local track, own hidden next stance/lock and private lead notice;
- separate `普通手牌 x/5` / `商品库存 x/5` labels, acquisition permissions,
  precise pool-specific full reasons and linear upgrade ladder;
- pending-end and final-validation messages from core gate state;
- no UI-side distribution, lead-weight or game-end calculation.

## Why production remains blocked

The active rulebook and runtime still require the v0.6 static belt, shared hand,
same-rank merge, 10/20/40/80 installation rates, existing AI assumptions and
current Victory finalization. The new direction has not yet approved:

- track length/window/movement/stock/refill/expiry/claim tie-break;
- missing stance/bootstrap default;
- eliminated/disconnected/restored macro-round roster;
- same-product versus same-color merge and linear rate mapping;
- full-inventory reject/discard/replace behavior (manual merge is now frozen as
  the V0.7 target until a later explicit rule changes it);
- irreversible special outcomes at the macro-round gate;
- GDP smoothing/floor/ceiling/cap/player scaling balance IDs;
- production Save migration and restore order.

Connecting a new owner now would create competing authority, so no production
file was modified or wired.

## Verification

```text
THREE_LAYER_FOCUSED=PASS 135/135
SEMANTIC_BENCH_CLI=PASS 13/13
SEMANTIC_BENCH_GODOT_MCP=PASS 13/13
SEAT_VECTORS=PASS 3/4/5/6/7/8
JSON_PARSE=PASS 4/4
COMMODITY_SUSHI_TRACK_BASELINE=PASS
MAIN_RUNTIME_COMPOSITION=PASS
UI_TEXT_SMOKE=PASS
VISUAL_SNAPSHOT=PASS
SMOKE_CHECK_ONLY=PASS
PRODUCTION_FILE_CHANGE_COUNT=0
RUNTIME_RULE_CHANGE_COUNT=0
SAVE_SCHEMA_CHANGE_COUNT=0
MAIN_CHANGE_COUNT=0
```

The existing `commodity_card_inventory_runtime_test.gd` remains red at
`17/43` (`26` failed assertions) on the unchanged production sources. Its
failures concern the pre-existing v0.6 fixture/source transaction setup; this
reference phase does not alter or restore that old rule path and does not claim
the baseline suite green.

Godot MCP used `4.7.stable`, loaded the new tools scene, emitted
`SHARED_COMMODITY_TRACK_THREE_LAYER_SEMANTICS_BENCH|status=PASS|checks=13`, and
reported no new-script warnings or errors. The only warning was the existing
`RunRngService.seed` name warning. The Bench exited by itself with no residual
project process.

## Next minimum task

```text
NEXT_TASK=SHARED_COMMODITY_TRACK_RULE_DECISION_FREEZE
```

Approve only the unresolved policy IDs above. After those decisions, promote
the reference to Phase B pure simulation and Save-identity tests before any
production owner, AI, UI, or legacy-path cutover.
