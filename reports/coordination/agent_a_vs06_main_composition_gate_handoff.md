# Agent A - VS06 Main Composition Gate Handoff

## Status

VS06-A4 is complete at focused-evidence level. The main composition gate now describes the current production graph instead of requiring retired owners, and the monster starter binding query now reads the frozen Monster owner API without re-entering the world bridge.

## Changed files

- `tests/main_runtime_composition_test.gd`
- `scripts/main.gd`
- `reports/coordination/agent_a_vs06_main_composition_gate_handoff.md`

## Composition gate update

The gate now verifies the active production topology:

- `RegionInfrastructureRuntimeController` and its non-owning world bridge.
- `RouteNetworkRuntimeController` and its non-owning world bridge.
- `CommodityFlowRuntimeController` and its non-owning world bridge.
- `PlayerManaRuntimeController`.
- `CommodityCardInventoryRuntimeController`.
- `CardPlayerStateProductionAdapterV06` as the only v0.6 card state port.
- `CoreEconomicCardRuntimeAdapterV06` behind the shared CardFlow transaction authority.
- The legacy v0.4 catalog remains the primary legacy namespace; v0.6 cards are reached only through the Coordinator facade.
- Post-seat v0.6 actor binding and strict readiness are observable in the Coordinator debug snapshot.
- Victory, Save, and AI retain one reachable production owner path.

Removed assertions were stale requirements for retired CityDevelopment, EconomyCashflow, GdpFormula, and IndustryCapacity owners, historical sprint text/hash gates, `main._capture_run_state`, and the deleted main-owned runtime composition snapshot. Save coverage now uses the active CardResolution save API plus the Coordinator district-purchase compatibility snapshot. No retired owner or compatibility function was restored.

## Monster starter recursion fix

`main.monster_deploy_rule_snapshot_v06(actor_id)` now calls the direct owner query:

```text
MonsterRuntimeController.monster_starter_state_snapshot_v06(actor_id)
```

The main binding rule no longer calls `monster_private_snapshot_v06`, so it cannot re-enter `MonsterRuntimeWorldBridge` and recurse back into main. The existing successful binding-rule fields remain unchanged; the bridge still owns successful snapshot fingerprint generation.

Fail-closed behavior:

- missing owner/API -> `monster_starter_state_owner_unavailable`
- non-Dictionary receipt -> `monster_starter_state_snapshot_invalid`
- owner `available=false` or `state=legacy_unknown` -> unavailable with the owner reason
- any unknown state -> `monster_starter_state_snapshot_invalid`
- `starter_consumed` is true only when the authoritative state is `summoned`

No private monster dictionary or world-bridge callback is read by this query.

## Minimal evidence

- Isolated `godot --headless --path . --script res://tests/main_runtime_composition_test.gd`: PASS.
- Isolated `godot --headless --path . --script res://tests/monster_deploy_atomic_lifecycle_v06_test.gd`: PASS, `61/61`, failures `0`.
- `APPDATA` was redirected to `%TEMP%/space_syndicate_vs06_a4_appdata` for both runs.
- No full regression, default `user://`, MCP/headed run, staging, commit, push, or merge was performed.

## Remaining integration acceptance

The coordinator should rerun the isolated tomorrow-playable vertical slice and confirm that both human and AI first summons reach the same CardFlow -> units adapter/router -> `MonsterRuntimeController` four-stage path, finalize once, and never reach the legacy v0.4 summon writer. Cross-module privacy, save isolation, countdown, recap, and headed interaction remain coordinator-owned acceptance.

## Lessons for other agents

- **invariant:** a composition gate must verify the active production owner graph, not preserve retired scene names or historical helper symbols.
- **failed approach:** querying a private snapshot through the world bridge from a world callback creates a bridge -> main -> bridge recursion loop.
- **stable API:** `MonsterRuntimeController.monster_starter_state_snapshot_v06(actor_id)` is the only starter-state read for v0.6 binding rules.
- **test oracle:** main composition PASS plus Monster deploy lifecycle `61/61` proves parse/load, direct-owner availability, and frozen lifecycle behavior for this slice.
- **integration trap:** `legacy_unknown` is not equivalent to `not_summoned`; treating it as entitlement would reopen duplicate starter deployment.
- **reusable pattern:** world adapters may combine public facts, but owner-local lifecycle state must be read directly from the authoritative controller and fail closed.
- **stale evidence:** `_capture_run_state`, main-owned composition snapshots, and retired City/GDP controller assertions no longer describe production.
- **next dependency:** coordinator vertical-slice acceptance must prove the human and AI production dispatches consume this binding snapshot without a legacy summon fallback.
