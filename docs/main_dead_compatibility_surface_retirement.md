# Main Dead Compatibility Surface Retirement

Status: SS06-01C complete on 2026-07-14.

## Purpose

This cleanup removes `main.gd` functions and declarations that had no production caller before SS06-02 continuous-economy characterization. It does not add a replacement runtime owner and does not change gameplay formulas. The removed surface existed only for historical reflection tests, old diagnostics, retired onboarding helpers, or already-replaced presentation paths.

## Deletion Proof

The audit scanned 700 production files under `scripts`, `scenes`, `resources`, `data`, and `project.godot`. It excluded `tests`, `scripts/tools`, `scenes/tools`, `addons`, `docs`, reports, generated output, and `.godot` import state.

A function was deleted only when all of these were true:

1. Its identifier appeared exactly once in `main.gd`, at its definition.
2. Its identifier appeared zero times in the production scan set.
3. It was not a Godot lifecycle, input, drawing, property, or tree callback.
4. No production scene connection, Callable, Resource, JSON record, or world bridge named it.

The same exact-declaration and zero-production-reference rule was used for top-level constants. The scan was repeated after each deletion batch until no additional zero-reference function or declaration remained.

## Removed Functions

The stable sweep removed 97 functions:

```text
_add_panel
_apply_role_market_income_bonus
_apply_run_state
_apply_trade_disruption_from_destroyed_district
_art_identity_audit_card_sources
_art_identity_audit_monster_action_sources
_art_identity_audit_monster_sources
_assert_auto_monster_rank_weights
_assert_ranked_action_weights_escalate
_boon_turn_text
_capture_run_state
_card_price_tier_text
_card_resolution_requirement_product_snapshot
_card_supply_locations_text
_city_route_flow_multiplier
_codex_navigation_state_snapshot
_codex_public_snapshot_service_node
_distance_label
_district_button_text
_district_index_for_card_source
_district_supply_has_monster_card
_economy_dashboard_public_snapshot_service_node
_economy_monster_cash_clue_line
_economy_player_cash_line
_economy_warehouse_risk_line
_entity_distance
_farthest_district_from
_final_settlement_public_snapshot_service_node
_format_seconds
_guess_card_resolution_owner
_intel_dossier_text
_is_card_resolution_busy
_load_settings_from_menu
_military_runtime_call
_monster_codex_public_snapshot_service_node
_monster_mobility_summary
_monster_ranked_action_weight_delta_summary
_monster_runtime_call
_nearest_auto_monster_distance_to_district_label
_next_card_resolution_sequence
_ocean_product_catalog_names
_on_guess_option_selected
_open_help_menu
_open_role_starter_monster_in_bestiary
_open_tutorial_menu
_opening_guide_completed_count
_opening_guide_lines
_opening_guide_next_step_text
_opening_guide_primary_action
_opening_guide_visible
_panel_container
_player_build_summary
_player_cycle_income
_player_intel_hud_text
_player_quick_goal_hint
_player_region_gdp_share_percent
_player_role_summary
_product_codex_public_snapshot_service_node
_product_market_apply_boon
_product_market_tier_summary
_public_status_tag_text
_recent_table_event_signature
_role_city_reveal_charges
_role_starter_monster_index
_ruleset_card_group_rules
_runtime_composition_snapshot
_runtime_player_board_bid_readiness_chip
_runtime_player_board_snapshot
_runtime_player_visible_cash
_runtime_rank_label
_save_run_from_menu
_save_settings_from_menu
_selected_city_info_text
_selected_district_has_card
_sort_product_strategy_hotspot_desc
_standings_public_snapshot_service_node
_start_player_cooldown
_table_tempo_status
_use_selected_role_city_reveal
_art_identity_card_stats
_card_resolution_runtime_debug_snapshot
_game_runtime_coordinator_debug_snapshot
_opening_guide_next_step_card
_opening_guide_step
_opening_guide_step_entries
_populate_tutorial_quick_start_board
_runtime_game_screen_duplicate_signal_count
_runtime_named_node_count
_runtime_player_board_bid_readiness_chips
_runtime_table_snapshot
_save_run
_use_role_city_reveal_for_player
_add_tutorial_quick_start_panel
_capture_run_domain_state_compatibility_adapter
_runtime_bid_status_chip
_card_resolution_runtime_save_data
_tutorial_quick_start_snapshot
```

## Removed Declarations

The sweep removed 24 unused constants, including the two obsolete `CityProductProjectStateScript`/`CityProductProjectBridgeScript` preloads, retired monster-presentation tuning values, retired event-target weights, old cooldown constants, and `TEMP_DECISION_CONTRACT` after its final dead compatibility chain disappeared.

## Metrics

| Metric | Before SS06-01C | After SS06-01C | Delta |
|---|---:|---:|---:|
| Total `main.gd` lines | 21,486 | 19,862 | -1,624 |
| Nonblank `main.gd` lines | 18,854 | 17,433 | -1,421 |
| Functions | 1,238 | 1,141 | -97 |
| Top-level variables | 131 | 131 | 0 |
| Top-level constants | 199 | 175 | -24 |

Current `main.gd` SHA-256: `CD3D0B15ABDC0F6281BC1EEC440511DCEDF76789CA18F51CC98533B438AAB607`.

Relative to the immutable pre-v0.6 baseline, `main.gd` is now down 2,730 nonblank lines and 146 functions.

## Historical Test Debt

Forty-six historical test/tool/addon files contain approximately 315 references to one or more removed identifiers. Most are concentrated in the old full smoke test, layout/composition reflection assertions, art identity capture, and characterization benches. These references are migration evidence, not production callers. They must be retired or rewritten against current Controller receipts; production wrappers must not be restored to keep them green.

No shared UI/card test file was edited in this cleanup because another agent owns that work concurrently.

## Engine Evidence

The project-local Godot MCP addon reloaded `res://scenes/main.tscn` after the fixed-point sweep. `scene_tree_dump` still contained `RuntimeGameScreen`, `RuntimeServices`, `GameRuntimeCoordinator`, `RegionInfrastructureRuntimeController`, and `RegionInfrastructureWorldBridge`. `get_errors` returned zero errors.

The next runtime task is SS06-02 Installed Commodity and Continuous Economy Characterization. Its baseline should start from this reduced call graph and identify the single future owner of installations, fixed-point flow, bottlenecks, rents, and sale receipts before any new mutation service is written.
