extends RefCounted
class_name InstalledCommodityContinuousEconomyCharacterizationRegistry

const MAIN_BASELINE := {
	"sha256": "CD3D0B15ABDC0F6281BC1EEC440511DCEDF76789CA18F51CC98533B438AAB607",
	"total_lines": 19862,
	"nonblank_lines": 17433,
	"function_count": 1141,
	"top_level_var_count": 131,
	"constant_count": 175,
}

const CURRENT_OWNER_MATRIX := [
	{
		"owner_id": "commodity_flow_runtime_controller",
		"script_path": "res://scripts/runtime/commodity_flow_runtime_controller.gd",
		"owns_now": ["installed_commodity_roster", "fixed_point_flow", "capacity_allocation", "backpressure", "sale_receipt_ledger", "flow_save_shape"],
		"v06_disposition": "authoritative",
	},
	{
		"owner_id": "commodity_flow_world_bridge",
		"script_path": "res://scripts/runtime/commodity_flow_world_bridge.gd",
		"owns_now": ["world_fact_capture", "atomic_cash_and_rent_apply"],
		"v06_disposition": "non_owning_bridge",
	},
	{
		"owner_id": "city_trade_network_runtime_controller",
		"script_path": "res://scripts/runtime/city_trade_network_runtime_controller.gd",
		"owns_now": ["read_only_transition_route_candidates"],
		"v06_disposition": "retire_after_ss06_03_route_cutover",
	},
	{
		"owner_id": "product_market_runtime_controller",
		"script_path": "res://scripts/runtime/product_market_runtime_controller.gd",
		"owns_now": ["public_prices", "price_history", "futures", "market_boons"],
		"v06_disposition": "price_authority_only",
	},
	{
		"owner_id": "economy_cashflow_runtime_controller",
		"script_path": "res://scripts/runtime/economy_cashflow_runtime_controller.gd",
		"owns_now": [],
		"v06_disposition": "retired_no_fallback",
	},
	{
		"owner_id": "gdp_formula_runtime_controller",
		"script_path": "res://scripts/runtime/gdp_formula_runtime_controller.gd",
		"owns_now": [],
		"v06_disposition": "retired_no_fallback",
	},
]

const TARGET_OWNER_BOUNDARY := {
	"commodity_flow_runtime_controller": [
		"installed_commodity_roster",
		"fixed_point_production_and_demand",
		"facility_capacity_proportional_allocation",
		"inventory_and_backpressure",
		"demand_allocation",
		"sale_receipt_exact_once_ledger",
		"continuous_economy_save_state",
	],
	"commodity_flow_world_bridge": ["collect_world_facts", "apply_atomic_receipt_batch"],
	"region_infrastructure_runtime_controller": ["facility_roster", "shared_region_integrity", "region_revision"],
	"product_market_runtime_controller": ["public_product_prices", "price_history"],
	"city_trade_network_runtime_controller_ss06_02_transition": ["read_only_route_candidates_only"],
	"ss06_03_route_owner": ["multimodal_legs", "facility_sequence", "capacity_bottleneck", "distance_and_rent_preview"],
}

const REQUIRED_INSTALLATION_FIELDS := [
	"installation_id", "commodity_id", "color", "installer_player_index", "direction",
	"base_units_per_minute", "source_card_rank", "facility_id", "region_id",
	"region_revision", "generation", "active",
]

const REQUIRED_ROUTE_FIELDS := [
	"route_id", "commodity_id", "source_region_id", "market_region_id", "ordered_legs",
	"mode_tags", "facility_ids", "shortest_legal_distance", "bottleneck_units_per_minute",
	"expected_rents", "region_revision_fingerprint",
]

const REQUIRED_SALE_RECEIPT_FIELDS := [
	"receipt_id", "commodity_owner", "commodity_id", "color", "units", "source_region_id",
	"market_region_id", "route_id", "base_unit_price_cents", "shortest_legal_distance",
	"distance_premium_basis_points", "unit_price_cents", "gross_value", "rent_rows",
	"owner_net_cash", "gdp_value", "settled_at",
]

const MAIN_DELETION_CANDIDATES := [
	"_apply_product_market_cycle_world_step",
	"_active_city_district_indices",
	"_city_trade_routes",
	"_city_cycle_income_breakdown",
	"_record_city_gdp_snapshot",
	"_refresh_city_networks",
	"_trade_routes_for_product",
	"_update_realtime_economy_cashflow",
	"_settle_city_cashflow_seconds",
]

const CITY_TRADE_DELETION_CANDIDATES := [
	"normalize_city",
	"refresh_networks",
	"apply_trade_disruption_from_destroyed_district",
	"settle_cashflow_seconds",
	"gdp_formula_snapshot",
	"city_gdp_breakdown",
	"_city_with_gdp_rows",
	"_city_gdp_formula_snapshot_from_snapshot",
	"_city_gdp_breakdown_from_snapshot",
	"_project_attribution_rows",
	"_trade_route_for_product",
	"_district_supplies_product",
	"_trade_source_type",
	"_node_cost_multiplier",
]

const LEGACY_STATE_KEYS := [
	"project_slots", "project_sequence", "generation_by_slot_id", "project_tombstones",
	"player_gdp_attribution_rows", "gdp_cashflow_remainder_by_source_id", "trade_route_damage",
	"last_cashflow_rate", "last_income", "cashflow_paid_total",
]

const SS06_02B_HARD_CUTOVER_GATE := {
	"next_sprint_id": "SS06-02B",
	"single_new_owner_required": true,
	"parallel_fallback_allowed": false,
	"main_minimum_nonblank_line_reduction": 250,
	"main_minimum_function_reduction": 8,
	"main_adapter_line_limit": 160,
	"city_trade_project_and_settlement_formulas_must_be_absent": true,
	"gdp_must_derive_from_sale_receipts": true,
	"cash_rent_gdp_mana_must_share_receipt_id": true,
	"project_save_shape_must_be_removed": true,
	"ss06_03_route_transition_must_be_explicit": true,
}


static func current_owner_snapshot() -> Array:
	return CURRENT_OWNER_MATRIX.duplicate(true)


static func target_owner_snapshot() -> Dictionary:
	return TARGET_OWNER_BOUNDARY.duplicate(true)


static func deletion_snapshot() -> Dictionary:
	return {
		"main": MAIN_DELETION_CANDIDATES.duplicate(),
		"city_trade": CITY_TRADE_DELETION_CANDIDATES.duplicate(),
		"legacy_state_keys": LEGACY_STATE_KEYS.duplicate(),
		"hard_cutover_gate": SS06_02B_HARD_CUTOVER_GATE.duplicate(true),
	}


static func debug_snapshot() -> Dictionary:
	return {
		"main_baseline": MAIN_BASELINE.duplicate(true),
		"current_owners": current_owner_snapshot(),
		"target_owners": target_owner_snapshot(),
		"required_installation_fields": REQUIRED_INSTALLATION_FIELDS.duplicate(),
		"required_route_fields": REQUIRED_ROUTE_FIELDS.duplicate(),
		"required_sale_receipt_fields": REQUIRED_SALE_RECEIPT_FIELDS.duplicate(),
		"deletion": deletion_snapshot(),
	}
