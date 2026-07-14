# Agent C VS06-C11 — Relaxed Trade Invariant Handoff

## Outcome

Frozen PASS. The C9 full-map direct-neighbor requirement is retired. A valid generated planet now needs only one exact-product opportunity between different districts; adjacency and per-source coverage are informational.

## Files

- `scripts/runtime/roguelike_economic_viability_policy.gd`: schema v3 pure-data audit/normalizer; no-op on any existing remote match, otherwise one deterministic demand replacement at most.
- `scripts/main.gd`: existing narrow policy consumer now rejects patch sets larger than one demand slot before atomic application.
- `tests/roguelike_economic_viability_policy_test.gd`: relaxed fixtures, 64 deterministic shapes, fail-closed cases, and real depth-I seed 60610/RegionInfrastructure equality.
- `docs/roguelike_economic_viability_v06_contract.md`: owner boundary, v3 schema, repair rule, and retired C9 oracle.

## Stable public API

- `RoguelikeEconomicViabilityPolicy.normalize(request) -> {ok, reason_code, districts, audit}`
- `RoguelikeEconomicViabilityPolicy.audit(request) -> audit`
- Audit v3: `global_remote_match_count`, `direct_remote_match_count`, `source_with_remote_count`, `isolated_source_count`, `coverage_ratio`, `assignments`, `changed`, `mutation_count`, `changed_destination_indices`, and optional `repair`.
- `viable` means `global_remote_match_count > 0`; it does not mean full source coverage.

## Focused evidence

- Godot 4.7 isolated headless: `ROGUELIKE_ECONOMIC_VIABILITY_TEST|status=PASS|checks=902|failures=0`.
- The test used isolated `APPDATA`/`LOCALAPPDATA` and QA save override; no full slice, MCP, headed run, or default player save was used.
- Seed 60610 asserts `mutation_count <= 1`, at least one cross-district match, legal single slots, and exact equality between final map facts and RegionInfrastructure authoritative facts.

## Known boundary

This evidence does not prove CommodityFlow local weak GDP, route settlement, or the complete vertical slice. Those remain with the economic owner and coordinating final gate.

## Lessons for other agents

- **Invariant:** planet viability requires one different-district exact-product supply/demand opportunity, not direct adjacency or universal source coverage.
- **Failed approach:** C9's deterministic perfect matching and `coverage_ratio_bp == 10000` rewrote gameplay randomness and encoded an unapproved direct-trade rule.
- **Stable API:** consume schema-v3 `viable` plus explicit match counters; treat direct/coverage metrics as diagnostics only.
- **Test oracle:** any pre-existing remote match is byte-for-byte no-op; an absent match changes zero or one demand slot; unrepairable input returns the original copy.
- **Integration trap:** applying a policy patch before validating its full shape can partially rewrite the sole map owner; `main.gd` validates the optional single patch first.
- **Reusable pattern:** pure normalize/audit over copied facts, structured fail-closed output, then one atomic owner-side patch.
- **Stale evidence:** C9 100% coverage, per-region direct demand, region.002 neighbor matching, and matching-flow assertions must not be restored.
- **Next dependency:** the coordinating gate should pair this map evidence with A10 CommodityFlow local-baseline and remote-route evidence without adding demand-side map exceptions.
