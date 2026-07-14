# Agent C VS06-C8 Map Economic Viability Handoff

## Outcome

PASS at focused-evidence level. Ordinary map generation now guarantees a real exact-product chain from region 0 to one direct neighboring demand before RegionInfrastructure initializes. The repair changes at most one demand slot and never mutates production, ownership, CommodityFlow, or economic formulas.

## Modified files

- `scripts/runtime/roguelike_economic_viability_policy.gd` — stateless pure-data `normalize`/`audit` policy.
- `scripts/main.gd` — one preload, one dev-only audit field/helper, and one policy call after `_assign_district_terrain_and_goods` completes its existing random assignment.
- `tests/roguelike_economic_viability_policy_test.gd` — pure fixtures plus isolated real depth-I main/bridge gate.
- `docs/roguelike_economic_viability_v06_contract.md` — ownership, schema, invariants, and failure contract.

A6 Coordinator, CommodityFlow, RegionInfrastructure, Inventory, card adapters/tests, AI, UI, catalogs, and formulas were not changed.

## Stable API

- `RoguelikeEconomicViabilityPolicy.normalize(request) -> Dictionary`
- `RoguelikeEconomicViabilityPolicy.audit(request) -> Dictionary`
- `main._roguelike_economic_viability_dev_snapshot() -> Dictionary`

The request contains only minimal pure-data district facts, catalog IDs, terrain production pools, and `preferred_source_index=0`. The result returns copied facts plus:

- `exact_match_count`, `direct_match_count`, `preferred_source_match`;
- `changed`, `mutation_count`;
- source/destination indices and region IDs;
- exact `product_id` and structured `reason_code`.

Already viable input returns unchanged facts. Repair replaces only the first legal direct destination's sole demand. Missing legal neighbors, catalog violations, terrain-pool violations, self-demand, or malformed slot counts return `ok=false` without mutation.

## Minimal verification

Godot `4.7.stable`, isolated `APPDATA` and `LOCALAPPDATA`:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/roguelike_economic_viability_policy_test.gd
```

Result: `ROGUELIKE_ECONOMIC_VIABILITY_TEST|status=PASS|checks=627|failures=0`, exit code 0.

Covered evidence:

- already-valid zero mutation;
- zero-intersection one-demand repair;
- mixed land/ocean and two-region boundaries;
- no legal neighbor, self-demand, and catalog-external fail-closed cases;
- 64 deterministic seed-shaped fixtures with one production/one demand, no self-demand, terrain-pool preservation, and at most one mutation;
- real depth-I `main.tscn` exact intersection and region-0 direct match;
- `RegionInfrastructureWorldBridge.public_commodity_region_facts()` exactly matches repaired district production/demand facts;
- QA save-path isolation.

## Remaining evidence / risks

- Full vertical slice and Stage5 Sale Receipt were not run; coordination should rerun them once.
- A6 owner tests were intentionally not rerun. Their temporary compatibility demand remains useful owner evidence but is stale as evidence of real-main map viability.
- The v0.6 policy deliberately requires exactly one production and one demand slot. A future multi-slot map needs a versioned schema update, not a relaxed implicit fallback.
- On a truly unrepairable topology, generation records a structured dev failure and preserves the original facts; it never fabricates a catalog product or player-owned demand.
- `scripts/main.gd` is a shared dirty file; C8 touched only the preload, audit field/helper, and the end of `_assign_district_terrain_and_goods`.

## Lessons for other agents

- **invariant:** A viable economy begins with an exact product ID at a real source and a real reachable demand; industry similarity is not a match.
- **failed approach:** Installing a neutral demand inside CommodityFlow proves owner mechanics but hides a map-generation defect and cannot be production bootstrap.
- **stable API:** Map generation supplies minimal pure facts to `normalize`; downstream owners consume the repaired authoritative map unchanged.
- **test oracle:** Require global exact intersection, preferred one-edge reachability, destination non-production, and RegionInfrastructure fact equality together.
- **integration trap:** Region index 0 is a map source preference, not player 0 ownership; attaching a player owner would corrupt GDP/rent attribution.
- **reusable pattern:** Complete seeded randomness first, run a deterministic constrained repair, apply one narrow patch, then initialize downstream owners.
- **stale evidence:** A green Sale Receipt using a test-added demand does not prove the production map is viable.
- **next dependency:** Coordination reruns the unified vertical slice and requires Stage5 to sell through the generated map without any compatibility demand fixture.
