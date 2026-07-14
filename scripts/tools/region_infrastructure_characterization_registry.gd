extends RefCounted
class_name RegionInfrastructureCharacterizationRegistry

const MAIN_BASELINE := {
	"sha256": "7F4AF6CA535051FB5189BDCD4273B990CE996464BFBCBE756A43BA7381673A62",
	"total_lines": 22825,
	"nonblank_lines": 20163,
	"function_count": 1287,
}

const SS06_01_DELETION_GATE := {
	"minimum_nonblank_lines_removed": 700,
	"minimum_functions_removed": 24,
	"maximum_main_nonblank_lines": 19463,
	"maximum_main_function_count": 1263,
	"maximum_region_infrastructure_adapter_lines": 180,
	"parallel_legacy_engine_allowed": false,
	"compatibility_wrapper_farm_allowed": false,
}

const LEGACY_HEAT_DELETION_GATE := {
	"v06_heat_state_allowed": false,
	"v06_panic_state_allowed": false,
	"player_visible_heat_label_allowed": false,
	"heat_triggered_damage_allowed": false,
	"monster_heat_scoring_allowed": false,
	"legacy_card_resolution": "reauthor_or_block",
	"delete_with_region_cutover": true,
}

const LEGACY_STATE_KEYS := [
	"districts[].hp",
	"districts[].damage",
	"districts[].destroyed",
	"districts[].panic",
	"districts[].city.active",
	"districts[].city.projects",
	"districts[].city.trade_route_damage",
	"districts[].city.warehouse_stockpiles",
]

const LEGACY_HEAT_OWNERSHIP := [
	{"path": "res://scripts/main.gd", "kind": "state_and_mutation", "symbols": ["districts[].panic", "_apply_panic_shift", "_apply_news_event"]},
	{"path": "res://scripts/runtime/monster_runtime_controller.gd", "kind": "target_scoring_and_public_facts", "symbols": ["panic", "热度"]},
	{"path": "res://scripts/runtime/codex_public_snapshot_service.gd", "kind": "player_visible_region_chip", "symbols": ["热度", "panic"]},
	{"path": "res://scripts/runtime/card_presentation_runtime_service.gd", "kind": "player_visible_card_copy", "symbols": ["panic_shift", "heat", "热度"]},
	{"path": "res://resources/cards/runtime/families", "kind": "legacy_card_content", "symbols": ["rules_text", "news_category", "panic"]},
	{"path": "res://tests", "kind": "legacy_fixture_expectations", "symbols": ["热度", "panic", "heat_score"]},
]

const MAIN_DELETION_CANDIDATES := [
	"_damage_district",
	"_repair_district",
	"_city_is_active",
	"_city_has_project_shares",
	"_city_public_project_snapshots",
	"_city_private_project_snapshots",
	"_normalize_city_product_project_state",
	"_rebuild_city_development_runtime_cards",
	"_preferred_city_development_directions",
	"_city_development_card_for_district",
	"_ensure_city_development_card_supply_for_district",
	"_ensure_city_development_card_supply",
	"_city_development_site_error",
	"_active_city_district_indices",
	"_player_active_city_count",
	"_city_competition_matches",
	"_city_trade_routes",
	"_apply_trade_disruption_from_destroyed_district",
	"_refresh_city_networks",
	"_trade_routes_for_product",
	"_settle_city_cashflow_seconds",
	"_destroyed_district_count",
	"_has_destroyed_district",
	"_alive_district_indices",
]

const CROSS_DOMAIN_WRITERS := [
	{"owner": "main", "symbol": "_damage_district", "kind": "legacy_region_mutation"},
	{"owner": "main", "symbol": "_repair_district", "kind": "legacy_region_mutation"},
	{"owner": "monster_runtime", "symbol": "_damage_district", "kind": "unit_damage_request_and_legacy_mutation"},
	{"owner": "military_runtime", "symbol": "execute_command", "kind": "unit_damage_or_repair_request"},
	{"owner": "card_execution", "symbol": "_apply_global_barrage", "kind": "non_unit_direct_damage_to_retire"},
	{"owner": "card_execution", "symbol": "_apply_riot", "kind": "non_unit_direct_damage_to_retire"},
	{"owner": "city_trade_network", "symbol": "apply_trade_disruption_from_destroyed_district", "kind": "post_lifecycle_refresh"},
	{"owner": "product_market", "symbol": "settle_futures_for_destroyed_warehouse", "kind": "post_lifecycle_receipt"},
]


static func debug_snapshot() -> Dictionary:
	return {
		"registry_id": "region_infrastructure_characterization_ss06_00",
		"ruleset_id": "v0.6",
		"runtime_cutover_enabled": false,
		"current_owner": "res://scripts/main.gd",
		"next_owner": "RegionInfrastructureRuntimeController",
		"main_baseline": MAIN_BASELINE.duplicate(true),
		"ss06_01_deletion_gate": SS06_01_DELETION_GATE.duplicate(true),
		"legacy_heat_deletion_gate": LEGACY_HEAT_DELETION_GATE.duplicate(true),
		"legacy_state_keys": LEGACY_STATE_KEYS.duplicate(),
		"legacy_heat_ownership": LEGACY_HEAT_OWNERSHIP.duplicate(true),
		"main_deletion_candidates": MAIN_DELETION_CANDIDATES.duplicate(),
		"cross_domain_writers": CROSS_DOMAIN_WRITERS.duplicate(true),
	}


static func deletion_candidate_count() -> int:
	return MAIN_DELETION_CANDIDATES.size()
