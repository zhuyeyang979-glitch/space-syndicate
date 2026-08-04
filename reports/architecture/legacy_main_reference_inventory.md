# V0.7.4 Legacy Main Reference Inventory

Generated from `05c2415014187e902592bf3a8d1291222f738694` after the MCP deletion of `scripts/main.gd` and its UID.

## Verdict

- Physical legacy script deleted: `true`
- Physical legacy UID deleted: `true`
- Production entrypoint: `scenes/main.tscn`
- Production dependency closure files: `79`
- Production-reachable legacy references: `0`
- V0.7.4 active-test dependency references: `0`
- Compatibility wrappers/replacement monoliths: `0`
- Remaining classified textual evidence: `2655` occurrences in `424` files

Textual evidence is intentionally not treated as an executable dependency. Historical documents, frozen V0.6 source oracles, and negative tests remain readable. The machine-readable companion classifies every matched line and distinguishes dependencies from negative/historical evidence.

## Classification

| Classification | Files | Occurrences | Dependencies |
| --- | ---: | ---: | ---: |
| duplicate | 252 | 1983 | 0 |
| frozen_v06_reliability_only | 151 | 628 | 0 |
| obsolete | 6 | 24 | 0 |
| v073_active_test | 15 | 20 | 0 |

## Operational References

| Path | Classification | Role | Occurrences | Dependencies | Lines |
| --- | --- | --- | ---: | ---: | --- |
| `tests/helpers/card_resolution_main_test_harness.gd` | obsolete | retired_oracle | 2 | 0 | 4, 14 |
| `tests/main_gd_architecture_gate_test.gd` | obsolete | retired_oracle | 4 | 0 | 5, 26, 57, 98 |
| `tests/shared_card_window_production_cutover_v06_test.gd` | obsolete | retired_oracle | 2 | 0 | 3, 50 |
| `tests/v07_adapters/v07_adapter_architecture_contract_test.gd` | v073_active_test | negative_or_historical_rule_assertion | 3 | 0 | 44, 83, 96 |
| `tests/v07_adapters/v07_canonical_rng_adapter_test.gd` | v073_active_test | negative_or_historical_rule_assertion | 1 | 0 | 87 |
| `tests/v07_adapters/v07_canonical_save_adapter_test.gd` | v073_active_test | negative_or_historical_rule_assertion | 1 | 0 | 392 |
| `tests/v07_adapters/v07_latest_main_resync_test.gd` | v073_active_test | negative_or_historical_rule_assertion | 1 | 0 | 73 |
| `tests/v07_semantic/v07_asset_batch_core_test.gd` | v073_active_test | negative_or_historical_rule_assertion | 1 | 0 | 2076 |
| `tests/v07_semantic/v07_dbg_deck_core_test.gd` | v073_active_test | negative_or_historical_rule_assertion | 1 | 0 | 2211 |
| `tests/v07_semantic/v07_three_wing_contract_aggregate_test.gd` | v073_active_test | negative_or_historical_rule_assertion | 1 | 0 | 2597 |
| `tests/v07_semantic/v07_track_acquisition_authority_port_test.gd` | v073_active_test | negative_or_historical_rule_assertion | 1 | 0 | 740 |
| `tests/v07_semantic/v072_card_definition_registry_test.gd` | v073_active_test | negative_or_historical_rule_assertion | 1 | 0 | 174 |
| `tests/v07_semantic/v073_fixed_order_facility_contention_core_test.gd` | v073_active_test | negative_or_historical_rule_assertion | 1 | 0 | 75 |
| `tests/v071_simulation/v071_rule_consistency_review_scene_test.gd` | v073_active_test | negative_or_historical_rule_assertion | 2 | 0 | 34, 40 |
| `tests/v072_simulation/v072_starter_bootstrap_review_scene_test.gd` | v073_active_test | negative_or_historical_rule_assertion | 2 | 0 | 31, 38 |
| `tests/v073_production_sample_acceptance_test.gd` | v073_active_test | negative_or_historical_rule_assertion | 1 | 0 | 52 |
| `tests/v073_simulation/v073_deterministic_contention_simulator_test.gd` | v073_active_test | negative_or_historical_rule_assertion | 1 | 0 | 120 |
| `tests/v073_simulation/v073_fixed_order_facility_contention_review_scene_test.gd` | v073_active_test | negative_or_historical_rule_assertion | 2 | 0 | 49, 95 |
| `tools/architecture/build_main_gd_call_graph.py` | obsolete | retired_oracle | 6 | 0 | 2, 14, 91, 115, 117, 166 |
| `tools/architecture/check_main_gd_budget.py` | obsolete | retired_oracle | 5 | 0 | 2, 15, 36, 46, 73 |

## Direct Loads

- `tests/card_resolution_controller_consolidation_test.gd:78`: obsolete V0.6-only fixture; not V0.7.4 active or production reachable.
- `tests/helpers/card_resolution_main_test_harness.gd:14`: obsolete V0.6-only fixture; not V0.7.4 active or production reachable.

## Reserved Integration Dependency

`scripts/v074_runtime/v074_application_bootstrap.gd` is owned by another lane and arrives in commit `03960728`. Lane F does not edit it. The new bootstrap architecture ratchet targets that exact path and will enforce:

- at most 120 lines;
- zero domain-rule ownership;
- zero gameplay mutation;
- zero Save ownership;
- zero RNG ownership;
- zero legacy Main lookup or fallback.

It is absent from this isolated Lane F base and must be validated after integration.

## Disposition

- `production_reachable`: must remain zero.
- `v074_active_test`: negative architecture-ratchet evidence only; dependency count must remain zero.
- `v073_active_test`: retained negative/historical V0.7.3 assertions.
- `frozen_v06_reliability_only`: retained on the frozen reliability track; not part of V0.7.4 acceptance.
- `obsolete`: old Main-instantiating fixtures and extinction-budget tooling; explicitly retired from V0.7.4 acceptance.
- `duplicate`: historical docs/reports retained as provenance.
- `pure_algorithm_candidate`: none found; no legacy Main code was copied or extracted.
