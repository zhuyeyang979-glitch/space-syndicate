# Agent B VS06-B5a AI Facility Policy Handoff

## Outcome and evidence level

B5a is complete at **focused fake-port** level. `AiRuntimeController` now owns only the decision policy for a one-time rank-I facility bootstrap. It has no production Coordinator binding yet and therefore remains fail-closed in the real composition until B5b/A supplies the port delegate.

No rule/economic value changed. No main, Coordinator, AiRuntimeWorldBridge, CardFlow, Inventory, CommodityFlow, RegionInfrastructure, catalog, UI, Monster, or vertical-slice file was edited.

## Files

- `scripts/runtime/ai_runtime_controller.gd`
- `scripts/runtime/ai_v06_economy_action_port.gd`
- `scripts/runtime/ai_v06_economy_action_port.gd.uid`
- `tests/ai_v06_facility_bootstrap_policy_test.gd`
- `docs/ai_v06_facility_bootstrap_contract.md`
- this handoff

The AI controller already contained unrelated shared-tree changes before B5a; they were preserved.

## Stable AI API

```gdscript
set_v06_economy_action_port(port: RefCounted) -> Dictionary
execute_v06_facility_bootstrap_cycle(force: bool = false) -> Dictionary
ai_v06_facility_bootstrap_public_snapshot() -> Dictionary
```

Normal scheduling calls `execute_v06_facility_bootstrap_cycle(false)` from the existing card-decision timer. Focused/vertical-slice callers must use the same function with `true`; force bypasses only action cooldown. One cycle stops after one finalized seat, so another AI can proceed on a later cycle. If no action finalizes, the existing legacy card-decision pass still runs.

The public-safe result is aggregate only. Exact rejection reasons, actors, transactions, cash, hands, routes, plans, pressure, and scores do not leave the internal policy path.

## Required B5b port signatures

```gdscript
market_snapshot(actor_id: String) -> Dictionary

purchase_rank_i_facility(
    actor_id: String,
    item_id: String,
    transaction_id: String,
    expected_market_revision: int,
    expected_player_revision: int,
    expected_source_revision: int
) -> Dictionary

player_snapshot(actor_id: String) -> Dictionary
play_runtime_card(request: Dictionary) -> Dictionary
economic_source_snapshot(actor_id: String) -> Dictionary
```

Every response must be recursively pure data with `available`, nonnegative `revision`, and non-empty `reason_code`. The full normalized schemas are in `docs/ai_v06_facility_bootstrap_contract.md`.

`play_runtime_card(request)` receives exactly:

```text
actor_id, slot_index, runtime_instance_id, transaction_id,
region_id, expected_player_revision, expected_source_revision
```

AI never passes price, card/effect payload, owner receipt, or claimed finalization.

## Policy and transaction behavior

- Starter readiness comes from `MonsterRuntimeController.monster_starter_state_snapshot_v06`; legacy roster presence is not accepted.
- Candidate requires no authoritative source, no persistent `bootstrap_finalized` marker, sufficient private cash, and a canonical rank-I facility.
- An already-owned bootstrap facility is played before considering another purchase, preventing purchase-success/play-failure from becoming a second charge.
- Purchase and play IDs are deterministic hashes of immutable bindings.
- After purchase the old player snapshot is discarded; a fresh snapshot must supply the stable runtime instance and slot.
- Success requires owner `committed=true` and terminal finalization.
- The controller keeps no business journal, queue, facility marker, hand, or cash shadow.

## Authoritative target requirement

The cross-audit risk is closed on the consumer side. AI no longer picks the lexicographically first live map region.

Target selection accepts only production-provided:

- canonical listing `target_region_id` or ordered `legal_region_ids`;
- otherwise source snapshot `target_region_id` or ordered `legal_region_ids` for an already-owned bootstrap card.

No candidate means no purchase. B5b/A must derive these targets from authoritative region commodity/industry facts and exclude `region_production_product_industry_mismatch`. The controller never infers industry from a card name and never scans legacy `district.card_choices`.

## Focused verification

Command class: Godot 4.7 headless with isolated temporary `APPDATA` and `LOCALAPPDATA`.

```text
godot --headless --path . --script res://tests/ai_v06_facility_bootstrap_policy_test.gd
PASS: 40/40 checks, exit 0
```

Covered:

- two completed AI starters; normal cycle finalizes seat one and later forced cycle finalizes seat two;
- normal/forced owner call sequences are identical;
- same-seat repeat performs no second purchase/play;
- stale market/player revision, insufficient cash, missing starter, existing source, persistent finalized marker, missing port, and missing authoritative target all have zero owner mutation;
- force respects every legality/revision/cost gate;
- world players and districts remain unchanged;
- only fake owner purchase/play methods mutate fixture state;
- public-safe recursive privacy scan reports zero forbidden fields.

No full slice, full smoke, MCP, headed run, or default `user://` was used.

## Production gaps / next dependency

1. A6 must freeze a normalized target/source projection and persistent `bootstrap_finalized` lineage.
2. A/Coordinator owner must create/bind the thin delegate using the existing canonical market, Inventory/CardFlow purchase, player snapshot, and `play_v06_runtime_card` facade. No second owner or journal is allowed.
3. Coordinator acceptance owner must replace the stale `_auto_expand_rival_syndicates` harness call with `execute_v06_facility_bootstrap_cycle(true)` and measure income from authoritative facility/CommodityFlow evidence rather than legacy city count.
4. Only after that connection can this evidence be promoted from focused to integrated/production.

## Lessons for other agents

- **invariant:** AI decides; production owners alone mutate cash, cards, market, facilities, sources, and journals.
- **failed approach:** restoring `_auto_expand_rival_syndicates` or choosing the first map region cannot satisfy industry legality and recreates a legacy write path.
- **stable API:** inject the five-method port, call `execute_v06_facility_bootstrap_cycle`, and keep responses revisioned pure data.
- **test oracle:** one purchase plus one terminal play, unchanged world state, same-seat repeat zero mutation, and second seat only on a later cycle.
- **integration trap:** a canonical card is insufficient without production-derived legal region candidates; otherwise the AI can pay before a permanent industry mismatch rejection.
- **reusable pattern:** preflight source/player/listing revisions → deterministic purchase → refresh player → bind stable instance → deterministic terminal play.
- **stale evidence:** `built=0` from the removed helper and `ai_income_source_count` as a legacy city alias do not measure the new production policy.
- **next dependency:** A6/B5b must supply normalized legal targets, persistent bootstrap lineage, and the thin Coordinator delegate.
