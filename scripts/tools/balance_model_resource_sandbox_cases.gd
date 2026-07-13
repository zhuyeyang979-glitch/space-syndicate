extends RefCounted
class_name BalanceModelResourceSandboxCases

const CASES := [
	{
		"case_id": "card_price_basic",
		"category": "Card Price",
		"kind": "card_price",
		"input": {
			"card": {
				"type": "经济",
				"rank": "I",
				"effect_power": 2,
				"targeting_premium": 0,
				"hidden_info_premium": 0,
				"economy_scaling_premium": 1,
				"interaction_premium": 0,
				"setup_requirement_discount": 0,
				"delayed_effect_discount": 0,
				"self_risk_discount": 0,
			},
		},
		"notes": "Baseline I-rank economy card.",
	},
	{
		"case_id": "card_price_high_rank",
		"category": "Card Price",
		"kind": "card_price",
		"input": {
			"card": {
				"type": "怪兽",
				"rank": "IV",
				"effect_power": 5,
				"targeting_premium": 2,
				"hidden_info_premium": 1,
				"economy_scaling_premium": 0,
				"interaction_premium": 2,
				"setup_requirement_discount": 1,
				"delayed_effect_discount": 0,
				"self_risk_discount": 1,
			},
		},
		"notes": "High-rank monster card with premiums and discounts.",
	},
	{
		"case_id": "product_price_stable",
		"category": "Product Economy",
		"kind": "product_price",
		"input": {
			"base_price": 100,
			"supply_score": 2,
			"demand_score": 3,
			"route_damage_score": 0,
			"monster_pressure": 0,
			"weather_modifier": 0,
			"volatility": 4,
			"random_noise": 0.0,
			"growth_multiplier": 1.0,
		},
		"notes": "Stable product refresh with mild demand.",
	},
	{
		"case_id": "product_price_volatile",
		"category": "Product Economy",
		"kind": "product_price",
		"input": {
			"base_price": 180,
			"supply_score": 1,
			"demand_score": 6,
			"route_damage_score": 4,
			"monster_pressure": 3,
			"weather_modifier": 9,
			"volatility": 21,
			"random_noise": 5.0,
			"growth_multiplier": 1.35,
		},
		"notes": "Volatile product refresh under route/weather pressure.",
	},
	{
		"case_id": "product_flow_damaged_route",
		"category": "Product Economy",
		"kind": "product_flow",
		"input": {
			"product_name": "Ore Freight",
			"transport_score": 1.35,
			"route_flow_multiplier": 1.4,
			"route_damage": 3,
			"weather_multiplier": 0.72,
		},
		"notes": "Route damage should reduce flow without changing runtime formulas.",
	},
	{
		"case_id": "victory_goal_depth_1",
		"category": "Victory Goal",
		"kind": "victory_goal",
		"input": {"depth": 1},
		"notes": "Depth I cash goal anchor.",
	},
	{
		"case_id": "victory_goal_depth_4",
		"category": "Victory Goal",
		"kind": "victory_goal",
		"input": {"depth": 4},
		"notes": "Depth IV cash goal anchor.",
	},
	{
		"case_id": "monster_movement_flying",
		"category": "Movement",
		"kind": "monster_movement",
		"input": {
			"actor": {"name": "Sky Warden", "movement_mode": "fly", "move": 190, "traits": ["flying"]},
			"terrain_multiplier": 1.0,
			"action_speed_mps": -1.0,
			"region_radius_m": 180.0,
			"target_region_exit_seconds": 10.0,
			"expected_ecology_multiplier": 10.0,
			"expected_move_damage": 0,
		},
		"notes": "Flying ecology multiplier and zero trample damage anchor.",
	},
	{
		"case_id": "monster_movement_stationary",
		"category": "Movement",
		"kind": "monster_movement",
		"input": {
			"actor": {"name": "Rooted Spire", "movement_mode": "walk", "move": 190, "stationary": true, "traits": ["stationary"]},
			"terrain_multiplier": 1.0,
			"action_speed_mps": -1.0,
			"region_radius_m": 180.0,
			"target_region_exit_seconds": 10.0,
			"expected_ecology_multiplier": 0.03,
			"expected_move_damage": 1,
		},
		"notes": "Stationary floor multiplier anchor.",
	},
	{
		"case_id": "combat_knockback_beam",
		"category": "Combat",
		"kind": "combat_knockback",
		"input": {
			"action": {"name": "Solar Beam", "kind": "beam_attack", "damage": 3, "range": 620.0, "tags": ["光线"]},
			"region_radius_m": 180.0,
		},
		"notes": "Beam knockback profile multiplier anchor.",
	},
	{
		"case_id": "weather_refresh_depth_3",
		"category": "Environment",
		"kind": "weather_refresh",
		"input": {
			"depth": 3,
			"region_count": 18,
			"active_weather_count": 1,
			"volatility_level": 2,
		},
		"notes": "Depth III public market/weather refresh bounds.",
	},
	{
		"case_id": "monster_owner_damage_rank_iv",
		"category": "Combat",
		"kind": "monster_owner_damage",
		"input": {
			"rank": 4,
			"roman": "IV",
		},
		"notes": "Rank IV owner damage cash pool anchor.",
	},
]


func cases() -> Array:
	return _duplicate_array(CASES)


func case_ids() -> Array[String]:
	var result: Array[String] = []
	for case_variant in CASES:
		var case_data: Dictionary = case_variant if case_variant is Dictionary else {}
		result.append(str(case_data.get("case_id", "")))
	return result


func case(case_id: String) -> Dictionary:
	for case_variant in CASES:
		var case_data: Dictionary = case_variant if case_variant is Dictionary else {}
		if str(case_data.get("case_id", "")) == case_id:
			return case_data.duplicate(true)
	return {}


func categories() -> Array[String]:
	var result: Array[String] = []
	for case_variant in CASES:
		var case_data: Dictionary = case_variant if case_variant is Dictionary else {}
		var category := str(case_data.get("category", ""))
		if category != "" and not result.has(category):
			result.append(category)
	return result


func _duplicate_array(source: Array) -> Array:
	var result: Array = []
	for value in source:
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
		elif value is Array:
			result.append(_duplicate_array(value))
		else:
			result.append(value)
	return result
