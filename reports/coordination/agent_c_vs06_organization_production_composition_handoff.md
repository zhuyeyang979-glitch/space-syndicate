# VS06-C15 Organization Production Composition Handoff

## Status

C15 production composition is complete within the assigned files. The Coordinator scene owns exactly one `PlayerOrganizationRuntimeController`; `install_organization_upgrade` routes by catalog effect field through the existing CoreEconomic adapter, Inventory, and single CardFlow transaction. Production organization play remains intentionally fail-closed because four business consumers are not yet connected.

The frozen B7 Monster provider API is composed successfully through a stateless delegate. No Monster file was modified.

## Files

- `scenes/runtime/GameRuntimeCoordinator.tscn`
- `scripts/runtime/game_runtime_coordinator.gd`
- `scripts/cards/v06/production/core_economic_card_effect_router_v06.gd`
- `scripts/cards/v06/production/core_economic_card_runtime_adapter_v06.gd`
- `scripts/cards/v06/production/organization_production_port_v06.gd`
- `tests/organization_production_composition_v06_test.gd`
- `scripts/tools/organization_production_composition_v06_bench.gd`
- `scenes/tools/OrganizationProductionCompositionV06Bench.tscn`
- `docs/organization_production_composition_v06_contract.md`
- this handoff

Frozen organization owner/adapter, main, Queue/Profile/Validator, Monster, PlayerMana, Inventory, Military, AI, UI, catalog, prices, and formulas were not modified.

## Public integration API

Coordinator now exposes:

- `player_organization_runtime_controller()`
- `organization_consumer_readiness_snapshot()`
- `organization_public_receipt(receipt)`
- `player_organization_checkpoint_status()`
- `player_organization_to_save_data()`
- `apply_player_organization_save_data(data)`

The CoreEconomic adapter accepts the organization owner and actual consumer nodes as optional final `configure` arguments, preserving existing five-argument callers. It exposes the readiness, checkpoint, public snapshot, and public receipt projections.

The Monster delegate implements the frozen B7 provider boundary:

- `current_monster_binding_window_snapshot_v06()` reads the live CardResolutionQueue owner snapshot.
- `monster_binding_caps(actor_id, window_sequence)` forwards to the unique organization owner.
- `monster_binding_caps_for_target_owner(actor_id, window_sequence)` forwards to the same owner.

It caches no window or capability facts and does not inspect request readiness fields.

## Production readiness

| Consumer | Current production result | Probe |
|---|---:|---|
| asset_recovery | false | real PlayerMana declaration + functional method absent |
| hand_limit | false | real player-state declaration + functional method absent |
| card_window | false | real Queue consumer declaration + functional method absent |
| monster_binding | true | B7 provider configure method accepted the stateless delegate |
| military_command | false | real Military declaration + functional method absent |

Any missing domain yields `organization_consumer_capabilities_incomplete` before the existing CardFlow owner reserves or commits player resources. A request cannot forge readiness. Reference objects work only because tests inject objects that pass the same declaration-and-method probes; they do not affect production composition.

Future consumers may satisfy the current probe with `organization_consumer_capabilities_v06(domain)` plus their domain method (`apply_organization_asset_recovery_terms_v06`, `apply_organization_hand_limit_terms_v06`, `apply_organization_card_window_submission_capability_v06`, or `apply_organization_military_command_caps_v06`). Business owners remain the only mutation authorities.

## Evidence

- Godot 4.7 isolated focused composition: `PASS`, 31/31 checks.
- Existing CoreEconomic router regression: `PASS`, 76/76 checks, including facility/commodity/global routes.
- Direct `--check-only`: organization port and CoreEconomic adapter both exit 0.
- `git diff --check`: pass.
- Godot 4.7 MCP production Bench: `PASS`, 11/11 checks. Runtime evidence reports exactly one organization owner; route `core_economic_card_runtime` with `effect_kind=install_organization_upgrade`; five readiness domains; B7 Monster provider ready; shared CardFlow true; second owner/journal false; aggregate production readiness false as required.
- MCP runtime error count and C15-owned warning count are both zero. `stop_project` succeeded. The MCP `errors`/`finalErrors` arrays still contain four pre-existing dependency warnings outside the C15 write boundary: three in Contract runtime and one in RegionInfrastructure. They were not suppressed or modified.

The focused gate proves incomplete-readiness zero consumption; reference-complete prepare/commit/finalize, outer-commit rollback, duplicate replay, save/load, checkpoint gating, field route rejection, forged-readiness rejection, public privacy, and exactly one CardFlow journal. It does not claim the four missing consumers are production-ready.

## Known risks / next wiring

- Main save orchestration is outside C15 and does not yet call the new Coordinator organization save wrappers.
- Organization cards must remain unavailable until all five readiness rows are true.
- Queue window readiness must be added by the Queue owner without accepting request-provided sequence or limits.
- PlayerMana, hand state, and Military must ingest terms without moving their business truth into the organization port.
- The repository-wide MCP warning array is not empty until the Contract and RegionInfrastructure owners clear their four existing warnings; C15 itself emits none.

## Lessons for other agents

- **Invariant:** one outer CardFlow transaction consumes player resources; the organization owner owns only organization state and its lifecycle journal.
- **Failed approach:** treating a request readiness dictionary or a reference consumer as production capability would allow a consumed card with no business effect.
- **Stable API:** route only `effect_kind=install_organization_upgrade`; terminal stages use the prepare-time transaction association, not receipt-reported type.
- **Test oracle:** incomplete readiness keeps player/card/organization byte-equivalent; complete reference flow removes one card, installs once, finalizes once, and replays without mutation.
- **Integration trap:** reconfiguring the organization owner during repeated player binding would erase installed state; Coordinator preserves the owner when actor IDs are unchanged.
- **Reusable pattern:** declaration + real functional method + prepare-time fail-closed gate, followed by a stateless forwarding delegate to the single owner.
- **Stale evidence:** an initial focused run failed because B7 briefly had two parse defects; after B fixed its owner, C15 composition passed 31/31. Catalog/runtime 140/140 alone never proved production routing.
- **Next dependency:** PlayerMana, player hand state, Queue, and Military owners must implement their narrow consumer contracts; main save composition must then include the Coordinator organization save bundle.
