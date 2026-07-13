@tool
extends Resource
class_name RuntimeBalanceParametersResource

@export var version := "runtime_balance_v1"
@export_multiline var purpose := "Runtime-facing balance anchors for victory cash targets, card purchase prices, game-length expectations, planet/region scale, movement, knockback, global environment refreshes, and monster damage-to-cash exposure."
@export var source_json_path := "res://data/balance/runtime_balance_targets.json"
@export var source_scripts: PackedStringArray = PackedStringArray([
	"res://scripts/balance/runtime_balance_model.gd",
	"res://scripts/balance/movement_balance_model.gd",
	"res://scripts/balance/combat_balance_model.gd",
	"res://scripts/balance/environment_balance_model.gd",
])

@export_group("Core Economy")
@export var starting_cash := 2000
@export var city_build_cost := 600
@export var city_final_value := 700
@export var reference_city_gdp_per_minute := 88

@export_group("Game Length")
@export var target_game_length: Dictionary = {
	"min_seconds": 1800,
	"max_seconds": 3600,
	"base_seconds": 1800,
	"depth_step_seconds": 360,
	"design_note": "Each run should land roughly between 30 and 60 minutes. Depth I anchors around 30 minutes; late roguelike depths approach 60 minutes.",
}

@export_group("Victory Goals")
@export var victory_goal_formula := "expected_city_assets + expected_engine_gdp_per_minute * target_game_seconds / 60"
@export var victory_goals_by_depth: Array = [
	{"depth": 1, "roman": "I", "cash_goal": 4740, "target_minutes": 30, "expected_city_count": 1, "expected_minutes_to_goal": 30.0},
	{"depth": 2, "roman": "II", "cash_goal": 8720, "target_minutes": 36, "expected_city_count": 2, "expected_minutes_to_goal": 36.0},
	{"depth": 3, "roman": "III", "cash_goal": 14060, "target_minutes": 42, "expected_city_count": 3, "expected_minutes_to_goal": 42.0},
	{"depth": 4, "roman": "IV", "cash_goal": 20830, "target_minutes": 48, "expected_city_count": 4, "expected_minutes_to_goal": 48.0},
	{"depth": 5, "roman": "V", "cash_goal": 29120, "target_minutes": 54, "expected_city_count": 5, "expected_minutes_to_goal": 54.0},
	{"depth": 6, "roman": "VI", "cash_goal": 39020, "target_minutes": 60, "expected_city_count": 6, "expected_minutes_to_goal": 60.0},
]
@export_multiline var victory_goal_design_note := "Expected minutes are conservative baseline engine estimates using reference GDP only. Cards, futures, contract leverage, and monster disruption should shorten or lengthen real games."

@export_group("Product Economy")
@export var product_price_policy: Dictionary = {
	"formula": "clamp(base_price + capped_delta, min_price, max_price)",
	"delta_drivers": ["supply_score", "demand_score", "route_damage_score", "monster_pressure", "weather_modifier", "growth_multiplier", "volatility_noise"],
	"single_refresh_caps": {
		"stable": "12% of base price",
		"normal": "22% of base price",
		"volatile": "40% of base price",
	},
}
@export var product_flow_policy: Dictionary = {
	"formula": "60 * transport_score * route_flow_multiplier * route_damage_multiplier * weather_multiplier",
	"unit": "flow units per minute",
	"route_damage_multiplier": "1.0 - 0.16 * route_damage, clamped to 0.25-1.0",
}

@export_group("Planet / Region")
@export var region_counts_by_depth: Array = [
	{"depth": 1, "roman": "I", "region_min": 6, "region_max": 9},
	{"depth": 2, "roman": "II", "region_min": 10, "region_max": 14},
	{"depth": 3, "roman": "III", "region_min": 15, "region_max": 21},
	{"depth": 4, "roman": "IV", "region_min": 22, "region_max": 30},
	{"depth": 5, "roman": "V", "region_min": 31, "region_max": 41},
	{"depth": 6, "roman": "VI", "region_min": 40, "region_max": 54},
]
@export var average_region_area_target_m2: Dictionary = {"min": 65000, "max": 140000}
@export_multiline var planet_region_design_note := "Planet scale, region count, and region radius feed monster/military movement and knockback. Movement should be linear meters-per-second, not instant region hops."

@export_group("Movement")
@export var movement_policy: Dictionary = {
	"normal_monster_region_exit_target_seconds": 10,
	"normal_region_exit_soft_bounds_seconds": {"min": 7, "max": 14},
	"flying_monster_multiplier": 10,
	"aquatic_monster_multiplier": 6.5,
	"tunnel_monster_multiplier": 2.4,
	"stationary_monster_multiplier_floor": 0.03,
	"military_region_exit_target_seconds": 10,
	"flying_rule": "flying movement has zero normal trample movement damage",
}

@export_group("Combat")
@export var combat_knockback_policy: Dictionary = {
	"normal_knockback_duration_seconds": 0.5,
	"duration_soft_bounds_seconds": {"min": 0.35, "max": 0.65},
	"normal_melee_radius_ratio": 0.85,
	"minimum_radius_ratio": 0.45,
	"heavy_radius_ratio": 1.4,
	"profile_multipliers": {
		"melee": 1.0,
		"beam": 1.85,
		"throw": 2.25,
		"charge": 1.65,
		"blast": 1.45,
	},
	"attack_pressure": "damage, range, knockback, close damage, and rank multiplier combine into attack_pressure_score",
}

@export_group("Global Environment")
@export var global_environment_policy: Dictionary = {
	"market_refresh_seconds": {"min": 30, "max": 60},
	"weather_forecast_seconds": {"min": 60, "max": 180},
	"weather_zone_count": {"min": 1, "max": 5},
	"weather_duration_seconds": {"min": 75, "max": 180},
	"price_drivers": ["supply_score", "demand_score", "route_damage_score", "contract_pressure", "monster_pressure", "weather_modifier"],
	"design_note": "Weather and market refreshes are public global state. News is not passive; news-like events should be created by player cards.",
}

@export_group("Card Price Policy")
@export var card_price_policy: Dictionary = {
	"rank_prices_use_family_i": true,
	"field_adjustment_cap": {"min": -60, "max": 190},
	"tier_thresholds": {
		"basic": {"max": 125},
		"advanced": {"min": 126, "max": 210},
		"high": {"min": 211, "max": 305},
		"flagship": {"min": 306},
	},
	"priced_fields": [
		"cash",
		"revenue_amount",
		"contract_income",
		"accept_cash",
		"decline_cash_penalty",
		"production_delta",
		"transport_delta",
		"consumption_delta",
		"market_demand_pressure",
		"market_supply_pressure",
		"route_damage",
		"repair_routes",
		"damage",
		"draw_amount",
		"hp",
		"fixed_skill_count",
		"military_hp",
		"military_damage",
		"military_gdp_penalty",
		"military_strike_route_damage",
		"gdp_bet_multiplier",
		"gdp_bet_destroy_bonus",
		"hand_discard_count",
		"hand_steal_count",
		"global_barrage_target_count",
		"counter_strength",
	],
	"discount_fields": [
		"play_product",
		"play_flow_required",
		"gdp_bet_seconds",
		"play_cash_per_monster",
	],
}

@export_group("Monster Owner Exposure")
@export var monster_owner_damage_cash: Dictionary = {
	"damage_basis": "actual_hp_lost_not_overkill",
	"base_pool": 700,
	"rank_step": 170,
	"pools_by_rank": {
		"I": 700,
		"II": 870,
		"III": 1040,
		"IV": 1210,
	},
	"baseline_loss_examples": [
		{"rank": "I", "hp_damage_ratio": 0.10, "cash_loss": 70},
		{"rank": "II", "hp_damage_ratio": 0.10, "cash_loss": 87},
		{"rank": "III", "hp_damage_ratio": 0.10, "cash_loss": 104},
		{"rank": "IV", "hp_damage_ratio": 0.10, "cash_loss": 121},
		{"rank": "IV", "hp_damage_ratio": 0.25, "cash_loss": 303},
	],
}


func to_runtime_targets_dictionary() -> Dictionary:
	return {
		"version": version,
		"purpose": purpose,
		"source_scripts": _packed_to_array(source_scripts),
		"starting_cash": starting_cash,
		"city_build_cost": city_build_cost,
		"city_final_value": city_final_value,
		"reference_city_gdp_per_minute": reference_city_gdp_per_minute,
		"target_game_length": target_game_length.duplicate(true),
		"victory_goal": {
			"formula": victory_goal_formula,
			"goals_by_depth": _duplicate_array(victory_goals_by_depth),
			"design_note": victory_goal_design_note,
		},
		"product_price_policy": product_price_policy.duplicate(true),
		"product_flow_policy": product_flow_policy.duplicate(true),
		"planet_region_policy": {
			"region_counts_by_depth": _duplicate_array(region_counts_by_depth),
			"average_region_area_target_m2": average_region_area_target_m2.duplicate(true),
			"design_note": planet_region_design_note,
		},
		"movement_policy": movement_policy.duplicate(true),
		"combat_knockback_policy": combat_knockback_policy.duplicate(true),
		"global_environment_policy": global_environment_policy.duplicate(true),
		"card_price_policy": card_price_policy.duplicate(true),
		"monster_owner_damage_cash": monster_owner_damage_cash.duplicate(true),
	}


func validate_profile() -> Array:
	var records: Array = []
	records.append(_validation_record("runtime_core_economy", starting_cash > 0 and city_build_cost > 0 and city_final_value > 0, "core economy anchors are positive"))
	records.append(_validation_record("runtime_victory_depths", victory_goals_by_depth.size() == 6, "six depth rows are present"))
	records.append(_validation_record("runtime_movement_policy", movement_policy.has("normal_monster_region_exit_target_seconds") and movement_policy.has("flying_monster_multiplier"), "movement policy exposes target seconds and ecology multipliers"))
	records.append(_validation_record("runtime_combat_policy", combat_knockback_policy.has("profile_multipliers") and combat_knockback_policy.has("normal_knockback_duration_seconds"), "combat policy exposes knockback duration and profiles"))
	records.append(_validation_record("runtime_environment_policy", global_environment_policy.has("market_refresh_seconds") and global_environment_policy.has("weather_duration_seconds"), "environment policy exposes market/weather ranges"))
	records.append(_validation_record("runtime_card_price_policy", card_price_policy.has("priced_fields") and card_price_policy.has("discount_fields"), "card price policy exposes adjustment field lists"))
	return records


func _validation_record(id: String, passed: bool, notes: String) -> Dictionary:
	return {
		"id": id,
		"passed": passed,
		"notes": notes,
	}


func _packed_to_array(values: PackedStringArray) -> Array:
	var result: Array = []
	for value in values:
		result.append(str(value))
	return result


func _duplicate_array(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
		elif value is Array:
			result.append(_duplicate_array(value))
		else:
			result.append(value)
	return result
