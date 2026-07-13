# AI Runtime Ownership Contract

## Sprint 41 Boundary

`AiRuntimeController` is the only runtime owner for AI state, personality policy, candidate generation, scoring, ranking, tie-breaks, fallback order, turn plans, response plans, learning records, and AI save/load data.

`AiRuntimeWorldBridge` is stateless. It binds the controller to the real `Main` world, exposes world facts required by the migrated algorithms, and routes stable intents. It must not score candidates, select actions, keep private AI state, or create an RNG.

`main.gd` may retain only narrow adapters:

- locate and call the scene-owned controller;
- provide public world revision/count facts;
- apply supported world intents through existing rule owners;
- forward public AI events;
- expose existing constants and the existing shared RNG object to the bridge.

## Policy Source

The runtime policy source is `res://resources/ai/ai_policy_profile_v1.tres`. Its `runtime_owner_script` is `res://scripts/runtime/ai_runtime_controller.gd` and `runtime_cutover_enabled` is `true`.

There is no `main.gd` AI constant or personality-catalog fallback. Resource load or validation failure leaves the controller unconfigured and reports an explicit error.

## Preserved Behavior

The migrated functions retain their pre-cutover bodies and call order. This includes card play and purchase candidates, auction/counter/contract responses, intel, monster wagers, military, weather, city/product/route/monster strategy, online learning, and public audit reports.

World legality and mutation remain with their existing owners. The controller asks the bridge for those facts or actions; it does not duplicate card, economy, city, route, monster, military, weather, contract, queue, or execution rules.

## RNG Contract

The controller receives the existing `main.gd` `RandomNumberGenerator` instance through the world bridge. It never constructs a second RNG. Migrated function bodies therefore consume the same generator in the same decision order. Save version 1 continues to persist the world RNG state in its existing envelope.

## Privacy Contract

AI plans, opponent-hand knowledge, hidden owners, private targets, private discards, and learning samples may exist in controller-private state or save data. They must not appear in public debug snapshots, UI snapshots, QA manifests, reports, or bridge events.

`debug_snapshot(-1)` exposes only controller readiness, policy identity, timer state, AI count, receipt count, and shared-RNG status. The bridge emits sanitized intent and receipt summaries without `player_index` or private payload data.

## Deletion Gate

The hard cutover is invalid if `main.gd` again defines any non-adapter `_ai_*`, `_auto_ai_*`, `_update_ai_decisions`, `_record_ai_decision`, or `_finalize_ai_*` function, or restores an AI policy constant/catalog copy.

Focused QA is the expanded `AiPolicyResourceBench` gate. The legacy all-in-one `smoke_test.gd` is not a reason to restore deleted AI methods; its known field-monster stall is tracked separately.
