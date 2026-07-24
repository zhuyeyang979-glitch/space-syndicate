# AI Actor Economy Facts Typed-Port Migration

## Status

`STATUS=AI_ACTOR_ECONOMY_FACTS_TYPED_PORT_MIGRATION_VALIDATED_CANDIDATE`

This is one completed atomic domain inside the active `P0-AI-WORLD-TYPED-PORTS-CUTOVER`. It does not claim the parent P0, a complete match, full-run resume, or Alpha 0.3 completion.

## Rule Authority

- `RULE_AUTHORITY_GATE=GREEN`
- Mechanic status: `MIGRATION_ONLY`
- AI semantic owner: `AiRuntimeController`
- Total cash, cooldown, and training-counter owner: `WorldSessionState`
- Wager-commitment owner: `MonsterRuntimeController`
- Session identity owner: `GameSessionRuntimeController`
- Public AI-seat authorization source: `AiActorStatePort`
- New gameplay owner: none
- New save field or section: none

Training continues to use signed total ledger cash, including legal pre-elimination debt. Affordability continues to use non-negative cash available after unresolved monster-wager commitments. A positive action cooldown continues to block only play, buy, and counter candidates.

## Production Contract

The production composition owns exactly one `AiActorEconomyFactsQueryPort` and creates exactly one opaque `AiActorEconomyFactsCapability` before child lifecycle callbacks. `AiRuntimeController.controller_ready` now requires both the actor-state and actor-economy boundaries. A hostile early bind, missing boundary, human seat, eliminated AI, forged capability, stale session, malformed cash/commitment, malformed cooldown, or malformed training counter fails closed.

The QueryPort exposes two detached schema-v1 snapshots:

### Decision Facts

`schema_version, session_id, session_revision, source_revision, fingerprint, visibility_scope, actor_index, available_cash_cents, available_cash_units, action_cooldown_seconds, action_ready`

### Training Economy Facts

`schema_version, session_id, session_revision, source_revision, fingerprint, visibility_scope, actor_index, total_cash_cents, total_cash_units, cities_built, total_city_income_units, total_card_income_units, total_role_income_units, total_card_spend_units, total_build_spend_units, total_business_spend_units`

Both use `visibility_scope=actor_private`, contain pure data only, and bind session identity plus WorldSession restore epoch. They contain no hand, slots, discard, city inference, AI memory, opponent fact, Node, Object, Callable, UI, Main, or save payload.

`MonsterWagerCashCommitmentQueryPort.private_cash_availability_projection()` is the literal zero-diagnostic-mutation projection used inside this capability boundary. Its existing counted snapshot API remains unchanged for existing consumers.

## Consumer Cutover

The AI controller no longer holds the wager cash query directly. Cash, cooldown, and economy-counter reads in the frozen consumer set now pass through the actor-economy port. Total-cash learning and reward semantics are kept separate from spendable-cash decision semantics.

The mixed hand functions remain mixed only for hand/slot data. They no longer read cash or cooldown from mutable player dictionaries. `_ensure_player_runtime_defaults` remains a deferred mutation path and was not disguised as a query.

## Privacy And State

- Rival exact cash exposure: 0
- Rival wager exposure: 0
- Hand/inventory exposure: 0
- City-inference exposure: 0
- AI-memory exposure: 0
- Query RNG delta: 0
- Query world mutation: 0
- Query wager mutation: 0
- Query diagnostic-counter mutation: 0
- New Save section count: 0
- Second cash owner count: 0
- Second WorldSession owner count: 0
- Main route count: 0

## Main Budget

`scripts/main.gd` is unchanged by this atomic slice.

| Metric | Before | After | Delta |
| --- | ---: | ---: | ---: |
| Physical lines | 6440 | 6440 | 0 |
| Nonblank lines | 5421 | 5421 | 0 |
| Methods | 470 | 470 | 0 |
| Fields | 46 | 46 | 0 |
| Constants | 45 | 45 | 0 |
| Preloads | 7 | 7 | 0 |
| External caller files | 103 | 103 | 0 |

The budget tool still reports the inherited absolute threshold `103 > 102`; this task adds no caller and leaves the three production reference files unchanged.

## Verification

- Focused actor-economy migration: `81/81 PASS`
  - Run ID: `20260724-160719-934-ai_actor_economy_facts_typed_port_migration_test-ca8a03fa`
  - Covers signed debt through training snapshot, live observation, decision recording, and reward finalization.
- Production scene Bench: `19/19 PASS`
  - Run ID: `20260724-160737-316-AiActorEconomyFactsTypedPortMigrationBench-c7429e36`
  - Marker: `available_cents=80000|total_cents=100000`
- Public-player facts: `128/128 PASS`
- Actor-state facts: `93/93 PASS`
- Actor-state production Bench: `37/37 PASS`
- City inference: `48/48 PASS`
- Typed-world boundary: `83/83 PASS`
- AI business architecture: `37/37 PASS`
- AI typed cash: `72/72 PASS`
- Formal four-player `main.tscn`: `28/28 PASS`
- Card cooldown owner: `23/23 PASS`
- Setup transaction: `133/133 PASS`
- WorldSession: `44/44 PASS`
- Save Registry: `12/12 PASS`
- Envelope runtime: `60/60 PASS`
- Contract retirement: `114/114 PASS`
- Main architecture: `217/217 PASS`
- Main composition: `PASS`
- Smoke `--check-only`: `PASS`
- Godot MCP direct main-scene boot: `PASS`
  - `/root/Main` visible at `1600x960`
  - formal actor-economy port capability revision `1`
  - capability bind rejection count `0`
  - product error log lines `0`
  - play mode stopped cleanly
- MCP production-runtime script diagnostics: `232 checked, 0 errors`
- Six changed GDScript files: `0 errors`
- Repository-wide scan: `986 checked`, with only the three already-recorded stale fixture files failing; no changed production or focused-test file is among them.

## Godot MCP Write Safety Prerequisite

The recurring “Files have been modified outside Godot” prompt was caused by Funplay MCP disk writers scanning an externally changed open scene before reloading the editor copy. Commit `f0c2058` introduced the base fix; follow-up commit `57483a6` applies the same contract to text writes, patching, bulk refactors, PackedScene writes, copy/move/delete, and scene creation:

1. An open scene with unsaved editor changes is rejected before any target write.
2. Delete or move refuses an open source scene.
3. A clean open target is activated, reloaded, and verified by open state, clean state, and exact scene identity before filesystem refresh.
4. Reload or previous-tab restoration failure returns an error and suppresses filesystem refresh instead of reporting a false success.
5. Text tools reject binary `.scn`; scene creation refuses accidental overwrite.
6. Bulk refactor closes every handle, verifies every affected scene reload, then scans once.

The source lifecycle test is `15/15 PASS`. Live verification wrote the clean, separately open `GameRuntimeCoordinator.tscn` while `main.tscn` was active and returned `scene_reloaded=true`, `scene_identity_verified=true`, and `previous_scene_restored=true`. An unsaved write was rejected while preserving both SHA-256 and mtime. No delayed external-change dialog was produced.

## Deferred Boundary

The next recommended atomic domain is `AI_ACTOR_HAND_INVENTORY_TYPED_PORT_MIGRATION`. It owns the largest remaining `players` residue and must not be folded into this cash/cooldown change.