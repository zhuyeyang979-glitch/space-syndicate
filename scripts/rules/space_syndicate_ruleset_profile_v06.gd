extends Resource
class_name SpaceSyndicateRulesetProfileV06

@export var ruleset_id: String = "v0.6"
@export var profile_schema_version: int = 1
@export var currency_scale: int = 100

@export_group("Region Infrastructure")
@export var facility_hp_contribution_by_rank: Dictionary = {"I": 100, "II": 200, "III": 300, "IV": 400}
@export var factory_market_capacity_by_rank: Dictionary = {"I": 40, "II": 80, "III": 140, "IV": 220}
@export var transport_throughput_by_rank: Dictionary = {"I": 50, "II": 100, "III": 175, "IV": 275}
@export var transport_speed_multiplier_by_rank: Dictionary = {"I": 1.0, "II": 1.2, "III": 1.45, "IV": 1.75}
@export var warehouse_capacity_by_rank: Dictionary = {"I": 200, "II": 400, "III": 700, "IV": 1100}
@export var warehouse_throughput_by_rank: Dictionary = {"I": 50, "II": 100, "III": 175, "IV": 275}
@export var warehouse_storage_rent_bp_per_minute_by_rank: Dictionary = {"I": 25, "II": 20, "III": 15, "IV": 10}
@export var maximum_facility_rank: int = 4

@export_group("Control And Victory")
@export var region_control_threshold_bp: int = 3000
@export var dynamic_victory_coverage_bp: int = 4000
@export var gdp_per_required_region_per_minute: int = 36
@export var qualification_seconds: int = 10
@export var audit_seconds: int = 120
@export var gdp_observation_window_seconds: int = 30

@export_group("Cards And Commodity Belt")
@export var card_group_seconds: int = 30
@export var planning_seconds: int = 20
@export var public_bid_seconds: int = 5
@export var lock_seconds: int = 5
@export var opening_extended_windows: int = 3
@export var opening_group_seconds: int = 45
@export var opening_planning_seconds: int = 35
@export var ordinary_card_limit: int = 1
@export var maximum_with_explicit_capability: int = 3
@export var ordinary_hand_limit: int = 5
@export var maximum_card_rank: int = 4
@export var commodity_rate_by_rank: Dictionary = {"I": 10, "II": 20, "III": 40, "IV": 80}
@export var commodity_belt_refresh_seconds: int = 5
@export var leading_tier_minimum_visible_cards: int = 3

@export_group("Economy And Mana")
@export var mana_observation_window_seconds: int = 30
@export var mana_per_color_maximum: int = 100
@export var mana_gdp_per_minute_divisor: int = 100
@export var direct_delivery_distance_limit: int = 1
@export var near_distance_limit: int = 2
@export var distance_premium_per_unit_bp: int = 1200
@export var distance_premium_maximum_bp: int = 12000
@export var non_storage_rent_cap_bp: int = 3500
@export var order_supply_units_by_rank: Dictionary = {"I": 20, "II": 40, "III": 80, "IV": 160}
@export var commodity_flow_terms_version: int = 2
@export var ambient_consumption_default_units_per_minute: int = 1
@export var ambient_consumption_units_per_minute_by_commodity: Dictionary = {}
@export var ambient_consumption_value_basis_points: int = 1000
@export var market_backlog_horizon_seconds: int = 120
@export var market_backlog_recovery_extra_basis_points: int = 10000

@export_group("Monster And Wager")
@export var monster_battle_limit_seconds: int = 60
@export var monster_upgrade_delay_extension_seconds: int = 60
@export var monster_wager_seconds: int = 8
@export var monster_wager_min_rate_bp: int = 500
@export var monster_wager_max_rate_bp: int = 1000
@export var monster_wager_standard_rate_bp: int = 500

@export_group("Roster Acceptance")
@export var minimum_player_count: int = 3
@export var maximum_player_count: int = 8
@export var minimum_ai_count_for_acceptance: int = 2
@export var maximum_ai_count_for_acceptance: int = 7

@export_group("Capabilities")
@export var public_facility_model_enabled: bool = true
@export var region_shared_hp_enabled: bool = true
@export var continuous_commodity_flow_enabled: bool = true
@export var six_color_mana_enabled: bool = true
@export var legacy_project_slots_enabled: bool = false
@export var industry_capacity_reservations_enabled: bool = false
@export var direct_city_build_allowed: bool = false
@export var private_plan_enabled: bool = false
@export var end_turn_enabled: bool = false
@export var player_pipeline_building_enabled: bool = false
@export var standard_market_noise_enabled: bool = false


func validation_snapshot() -> Dictionary:
	return {
		"ruleset_id": ruleset_id,
		"profile_schema_version": profile_schema_version,
		"currency_scale": currency_scale,
		"region_control_threshold_bp": region_control_threshold_bp,
		"dynamic_victory_coverage_bp": dynamic_victory_coverage_bp,
		"gdp_per_required_region_per_minute": gdp_per_required_region_per_minute,
		"commodity_flow_terms_version": commodity_flow_terms_version,
		"maximum_facility_rank": maximum_facility_rank,
		"maximum_card_rank": maximum_card_rank,
		"minimum_player_count": minimum_player_count,
		"maximum_player_count": maximum_player_count,
		"minimum_ai_count_for_acceptance": minimum_ai_count_for_acceptance,
		"maximum_ai_count_for_acceptance": maximum_ai_count_for_acceptance,
	}


func infrastructure_rules() -> Dictionary:
	return {
		"facility_hp_contribution_by_rank": facility_hp_contribution_by_rank.duplicate(true),
		"factory_market_capacity_by_rank": factory_market_capacity_by_rank.duplicate(true),
		"transport_throughput_by_rank": transport_throughput_by_rank.duplicate(true),
		"transport_speed_multiplier_by_rank": transport_speed_multiplier_by_rank.duplicate(true),
		"warehouse_capacity_by_rank": warehouse_capacity_by_rank.duplicate(true),
		"warehouse_throughput_by_rank": warehouse_throughput_by_rank.duplicate(true),
		"warehouse_storage_rent_bp_per_minute_by_rank": warehouse_storage_rent_bp_per_minute_by_rank.duplicate(true),
		"maximum_facility_rank": maximum_facility_rank,
	}


func victory_rules() -> Dictionary:
	return {
		"region_control_threshold_bp": region_control_threshold_bp,
		"dynamic_victory_coverage_bp": dynamic_victory_coverage_bp,
		"gdp_per_required_region_per_minute": gdp_per_required_region_per_minute,
		"qualification_seconds": qualification_seconds,
		"audit_seconds": audit_seconds,
		"gdp_observation_window_seconds": gdp_observation_window_seconds,
	}


func card_group_rules() -> Dictionary:
	return {
		"group_seconds": card_group_seconds,
		"planning_seconds": planning_seconds,
		"public_bid_seconds": public_bid_seconds,
		"lock_seconds": lock_seconds,
		"opening_extended_windows": opening_extended_windows,
		"opening_group_seconds": opening_group_seconds,
		"opening_planning_seconds": opening_planning_seconds,
		"ordinary_card_limit": ordinary_card_limit,
		"maximum_with_explicit_capability": maximum_with_explicit_capability,
		"organize_seconds": planning_seconds,
		"standard_group_card_limit": ordinary_card_limit,
	}


func card_inventory_rules() -> Dictionary:
	return {
		"ordinary_hand_limit": ordinary_hand_limit,
		"maximum_card_rank": maximum_card_rank,
		"commodity_rate_by_rank": commodity_rate_by_rank.duplicate(true),
	}


func commodity_rules() -> Dictionary:
	return {
		"commodity_rate_by_rank": commodity_rate_by_rank.duplicate(true),
		"commodity_belt_refresh_seconds": commodity_belt_refresh_seconds,
		"leading_tier_minimum_visible_cards": leading_tier_minimum_visible_cards,
		"direct_delivery_distance_limit": direct_delivery_distance_limit,
		"near_distance_limit": near_distance_limit,
		"distance_premium_per_unit_bp": distance_premium_per_unit_bp,
		"distance_premium_maximum_bp": distance_premium_maximum_bp,
		"non_storage_rent_cap_bp": non_storage_rent_cap_bp,
		"order_supply_units_by_rank": order_supply_units_by_rank.duplicate(true),
		"commodity_flow_terms_version": commodity_flow_terms_version,
		"ambient_consumption_default_units_per_minute": ambient_consumption_default_units_per_minute,
		"ambient_consumption_units_per_minute_by_commodity": ambient_consumption_units_per_minute_by_commodity.duplicate(true),
		"ambient_consumption_value_basis_points": ambient_consumption_value_basis_points,
		"market_backlog_horizon_seconds": market_backlog_horizon_seconds,
		"market_backlog_recovery_extra_basis_points": market_backlog_recovery_extra_basis_points,
	}


func mana_rules() -> Dictionary:
	return {
		"observation_window_seconds": mana_observation_window_seconds,
		"per_color_maximum": mana_per_color_maximum,
		"gdp_per_minute_divisor": mana_gdp_per_minute_divisor,
	}


func monster_rules() -> Dictionary:
	return {
		"battle_limit_seconds": monster_battle_limit_seconds,
		"upgrade_delay_extension_seconds": monster_upgrade_delay_extension_seconds,
		"wager_seconds": monster_wager_seconds,
		"wager_minimum_rate_bp": monster_wager_min_rate_bp,
		"wager_maximum_rate_bp": monster_wager_max_rate_bp,
		"wager_standard_rate_bp": monster_wager_standard_rate_bp,
	}


func capability_rules() -> Dictionary:
	return {
		"public_facility_model_enabled": public_facility_model_enabled,
		"region_shared_hp_enabled": region_shared_hp_enabled,
		"continuous_commodity_flow_enabled": continuous_commodity_flow_enabled,
		"six_color_mana_enabled": six_color_mana_enabled,
		"legacy_project_slots_enabled": legacy_project_slots_enabled,
		"industry_capacity_reservations_enabled": industry_capacity_reservations_enabled,
		"direct_city_build_allowed": direct_city_build_allowed,
		"private_plan_enabled": private_plan_enabled,
		"end_turn_enabled": end_turn_enabled,
		"player_pipeline_building_enabled": player_pipeline_building_enabled,
		"standard_market_noise_enabled": standard_market_noise_enabled,
	}


func debug_snapshot() -> Dictionary:
	return {
		"identity": {"ruleset_id": ruleset_id, "profile_schema_version": profile_schema_version, "currency_scale": currency_scale},
		"validation": validation_snapshot(),
		"infrastructure": infrastructure_rules(),
		"victory": victory_rules(),
		"card_group": card_group_rules(),
		"card_inventory": card_inventory_rules(),
		"commodity": commodity_rules(),
		"mana": mana_rules(),
		"monster": monster_rules(),
		"capabilities": capability_rules(),
	}
