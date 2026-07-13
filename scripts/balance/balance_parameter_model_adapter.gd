extends RefCounted
class_name BalanceParameterModelAdapter

const ResourceRegistryScript := preload("res://scripts/balance/balance_parameter_resource_registry.gd")

const RUNTIME_MODEL_SCRIPT_PATH := "res://scripts/balance/runtime_balance_model.gd"
const CARD_PRICE_CURVE_SCRIPT_PATH := "res://scripts/balance/card_price_curve.gd"

var _registry: RefCounted = ResourceRegistryScript.new()
var _runtime_model: RefCounted = null
var _price_curve_model: RefCounted = null


func runtime_targets() -> Dictionary:
	return _registry.call("runtime_resource_payload")


func price_curve() -> Dictionary:
	return _registry.call("price_curve_resource_payload")


func model_script_paths() -> Array[String]:
	return [
		RUNTIME_MODEL_SCRIPT_PATH,
		"res://scripts/balance/movement_balance_model.gd",
		"res://scripts/balance/combat_balance_model.gd",
		"res://scripts/balance/environment_balance_model.gd",
		CARD_PRICE_CURVE_SCRIPT_PATH,
	]


func sample_outputs_for_case(case_data: Dictionary) -> Dictionary:
	var kind := str(case_data.get("kind", ""))
	match kind:
		"card_price":
			return _sample_card_price(case_data)
		"product_price":
			return _sample_product_price(case_data)
		"product_flow":
			return _sample_product_flow(case_data)
		"victory_goal":
			return _sample_victory_goal(case_data)
		"monster_movement":
			return _sample_monster_movement(case_data)
		"combat_knockback":
			return _sample_combat_knockback(case_data)
		"weather_refresh":
			return _sample_weather_refresh(case_data)
		"monster_owner_damage":
			return _sample_monster_owner_damage(case_data)
	return _base_record(case_data, {}, {}, {}, false, false, false, false, "Unsupported sandbox case kind: %s" % kind)


func _sample_card_price(case_data: Dictionary) -> Dictionary:
	var input := _input(case_data)
	var card: Dictionary = input.get("card", {}) if input.get("card", {}) is Dictionary else {}
	var model: RefCounted = _price_curve()
	var model_price := 0
	if model != null:
		model.call("load_from_file", "res://data/balance/price_curve_v1.json")
		model_price = int(model.call("suggested_price", card))
	var curve := price_curve()
	var json_curve := _json_payload("res://data/balance/price_curve_v1.json")
	var resource_price := _suggested_price_from_curve(card, curve)
	var json_price := _suggested_price_from_curve(card, json_curve)
	var runtime_output := {
		"suggested_price": model_price,
		"source": CARD_PRICE_CURVE_SCRIPT_PATH,
	}
	var resource_output := {
		"suggested_price": resource_price,
		"base_by_type": _value_for_card_type(card, curve.get("base_by_type", {})),
		"rank_step": _value_for_card_rank(card, curve.get("rank_step", {})),
		"weight_count": (curve.get("weights", {}) as Dictionary).size() if curve.get("weights", {}) is Dictionary else 0,
	}
	var json_anchor := {
		"suggested_price": json_price,
		"curve_path": "res://data/balance/price_curve_v1.json",
	}
	var parity := model_price == resource_price and model_price == json_price
	return _base_record(case_data, runtime_output, resource_output, json_anchor, not card.is_empty(), model_price > 0, resource_price > 0, parity, "Card price dry-run uses existing CardPriceCurve script and Resource curve formula.")


func _sample_product_price(case_data: Dictionary) -> Dictionary:
	var input := _input(case_data)
	var model_variant: Variant = _runtime().call("product_price_model", int(input.get("base_price", 100)), int(input.get("supply_score", 0)), int(input.get("demand_score", 0)), int(input.get("route_damage_score", 0)), int(input.get("monster_pressure", 0)), int(input.get("weather_modifier", 0)), int(input.get("volatility", 4)), float(input.get("random_noise", 0.0)), float(input.get("growth_multiplier", 1.0)))
	var model_output: Dictionary = model_variant if model_variant is Dictionary else {}
	var policy := _runtime_policy("product_price_policy")
	var json_policy := _json_policy("product_price_policy")
	var resource_output := {
		"formula": str(policy.get("formula", "")),
		"delta_drivers": policy.get("delta_drivers", []),
		"single_refresh_caps": policy.get("single_refresh_caps", {}),
	}
	var parity := not model_output.is_empty() and _deep_equal(policy, json_policy) and model_output.has("price") and model_output.has("step_cap")
	return _base_record(case_data, model_output, resource_output, json_policy, true, not model_output.is_empty(), not policy.is_empty(), parity, "Product price formula remains script-owned; Resource/JSON anchors verify the tunable policy surface.")


func _sample_product_flow(case_data: Dictionary) -> Dictionary:
	var input := _input(case_data)
	var model_variant: Variant = _runtime().call("product_flow_speed_model", str(input.get("product_name", "")), float(input.get("transport_score", 1.0)), float(input.get("route_flow_multiplier", 1.0)), int(input.get("route_damage", 0)), float(input.get("weather_multiplier", 1.0)))
	var model_output: Dictionary = model_variant if model_variant is Dictionary else {}
	var policy := _runtime_policy("product_flow_policy")
	var json_policy := _json_policy("product_flow_policy")
	var parity := not model_output.is_empty() and _deep_equal(policy, json_policy) and float(model_output.get("flow_units_per_minute", 0.0)) > 0.0
	return _base_record(case_data, model_output, policy, json_policy, true, not model_output.is_empty(), not policy.is_empty(), parity, "Product flow dry-run keeps transport formula in runtime_balance_model and checks Resource/JSON formula notes.")


func _sample_victory_goal(case_data: Dictionary) -> Dictionary:
	var input := _input(case_data)
	var depth := int(input.get("depth", 1))
	var model_goal := int(_runtime().call("victory_cash_goal_for_duration", depth))
	var runtime_payload := runtime_targets()
	var json_payload := _json_payload("res://data/balance/runtime_balance_targets.json")
	var resource_row := _depth_row(_nested(runtime_payload, ["victory_goal", "goals_by_depth"]), depth)
	var json_row := _depth_row(_nested(json_payload, ["victory_goal", "goals_by_depth"]), depth)
	var resource_goal := int(resource_row.get("cash_goal", -1))
	var json_goal := int(json_row.get("cash_goal", -2))
	var runtime_output := {
		"depth": depth,
		"cash_goal": model_goal,
		"source": RUNTIME_MODEL_SCRIPT_PATH,
	}
	var parity := model_goal == resource_goal and resource_goal == json_goal
	return _base_record(case_data, runtime_output, resource_row, json_row, depth > 0, model_goal > 0, resource_goal > 0, parity, "Victory goal Resource rows match the existing model output for this depth.")


func _sample_monster_movement(case_data: Dictionary) -> Dictionary:
	var input := _input(case_data)
	var actor: Dictionary = input.get("actor", {}) if input.get("actor", {}) is Dictionary else {}
	var target_seconds := float(input.get("target_region_exit_seconds", _nested(runtime_targets(), ["movement_policy", "normal_monster_region_exit_target_seconds"])))
	var model_variant: Variant = _runtime().call("monster_movement_speed_model", actor, float(input.get("terrain_multiplier", 1.0)), float(input.get("action_speed_mps", -1.0)), float(input.get("region_radius_m", -1.0)), target_seconds)
	var model_output: Dictionary = model_variant if model_variant is Dictionary else {}
	var movement_policy := _runtime_policy("movement_policy")
	var json_policy := _json_policy("movement_policy")
	var expected_multiplier := float(input.get("expected_ecology_multiplier", 1.0))
	var expected_move_damage := int(input.get("expected_move_damage", -1))
	var multiplier_ok := is_equal_approx(float(model_output.get("ecology_speed_multiplier", -999.0)), expected_multiplier)
	var damage_ok := expected_move_damage < 0 or int(model_output.get("move_damage", -99)) == expected_move_damage
	var resource_output := {
		"expected_ecology_multiplier": expected_multiplier,
		"expected_move_damage": expected_move_damage,
		"movement_policy": movement_policy,
	}
	var parity := not model_output.is_empty() and _deep_equal(movement_policy, json_policy) and multiplier_ok and damage_ok
	return _base_record(case_data, model_output, resource_output, json_policy, not actor.is_empty(), not model_output.is_empty(), not movement_policy.is_empty(), parity, "Monster movement dry-run checks model ecology multipliers against Resource movement policy anchors.")


func _sample_combat_knockback(case_data: Dictionary) -> Dictionary:
	var input := _input(case_data)
	var action: Dictionary = input.get("action", {}) if input.get("action", {}) is Dictionary else {}
	var model_variant: Variant = _runtime().call("monster_knockback_distance_model", action, {}, float(input.get("region_radius_m", -1.0)))
	var model_output: Dictionary = model_variant if model_variant is Dictionary else {}
	var combat_policy := _runtime_policy("combat_knockback_policy")
	var json_policy := _json_policy("combat_knockback_policy")
	var multipliers: Dictionary = combat_policy.get("profile_multipliers", {}) if combat_policy.get("profile_multipliers", {}) is Dictionary else {}
	var profile := str(model_output.get("profile", ""))
	var resource_multiplier := float(multipliers.get(profile, -1.0))
	var parity := not model_output.is_empty() and _deep_equal(combat_policy, json_policy) and is_equal_approx(float(model_output.get("profile_multiplier", -2.0)), resource_multiplier)
	var resource_output := {
		"profile": profile,
		"profile_multiplier": resource_multiplier,
		"normal_duration": float(combat_policy.get("normal_knockback_duration_seconds", 0.0)),
	}
	return _base_record(case_data, model_output, resource_output, json_policy, not action.is_empty(), not model_output.is_empty(), resource_multiplier > 0.0, parity, "Combat dry-run checks knockback profile against Resource profile multipliers.")


func _sample_weather_refresh(case_data: Dictionary) -> Dictionary:
	var input := _input(case_data)
	var model_variant: Variant = _runtime().call("global_environment_refresh_model", int(input.get("depth", 1)), int(input.get("region_count", -1)), int(input.get("active_weather_count", 0)), int(input.get("volatility_level", 1)))
	var model_output: Dictionary = model_variant if model_variant is Dictionary else {}
	var environment_policy := _runtime_policy("global_environment_policy")
	var json_policy := _json_policy("global_environment_policy")
	var market_range: Dictionary = environment_policy.get("market_refresh_seconds", {}) if environment_policy.get("market_refresh_seconds", {}) is Dictionary else {}
	var forecast_range: Dictionary = environment_policy.get("weather_forecast_seconds", {}) if environment_policy.get("weather_forecast_seconds", {}) is Dictionary else {}
	var zone_range: Dictionary = environment_policy.get("weather_zone_count", {}) if environment_policy.get("weather_zone_count", {}) is Dictionary else {}
	var market_ok := _number_in_range(float(model_output.get("market_refresh_seconds", -1.0)), market_range)
	var forecast_ok := _number_in_range(float(model_output.get("forecast_window_seconds", -1.0)), forecast_range)
	var zone_ok := _number_in_range(float(model_output.get("weather_zone_count", -1)), zone_range)
	var parity := not model_output.is_empty() and _deep_equal(environment_policy, json_policy) and market_ok and forecast_ok and zone_ok
	return _base_record(case_data, model_output, environment_policy, json_policy, true, not model_output.is_empty(), not environment_policy.is_empty(), parity, "Weather/global environment dry-run checks existing model output against Resource ranges.")


func _sample_monster_owner_damage(case_data: Dictionary) -> Dictionary:
	var input := _input(case_data)
	var rank := int(input.get("rank", 1))
	var roman := str(input.get("roman", _roman_for_rank(rank)))
	var model_cash := int(_runtime().call("owner_damage_cash_total_for_rank", rank))
	var policy := _runtime_policy("monster_owner_damage_cash")
	var json_policy := _json_policy("monster_owner_damage_cash")
	var pools: Dictionary = policy.get("pools_by_rank", {}) if policy.get("pools_by_rank", {}) is Dictionary else {}
	var resource_cash := int(pools.get(roman, -1))
	var runtime_output := {
		"rank": rank,
		"roman": roman,
		"owner_damage_cash_total": model_cash,
	}
	var resource_output := {
		"rank": rank,
		"roman": roman,
		"owner_damage_cash_total": resource_cash,
		"policy": policy,
	}
	var parity := model_cash == resource_cash and _deep_equal(policy, json_policy)
	return _base_record(case_data, runtime_output, resource_output, json_policy, rank > 0, model_cash > 0, resource_cash > 0, parity, "Monster owner damage cash pool matches Resource and JSON by rank.")


func _base_record(case_data: Dictionary, runtime_output: Dictionary, resource_output: Dictionary, json_anchor: Dictionary, input_checked: bool, runtime_model_checked: bool, resource_profile_checked: bool, parity_checked: bool, notes: String) -> Dictionary:
	var passed := input_checked and runtime_model_checked and resource_profile_checked and parity_checked and _is_pure_data(case_data) and _is_pure_data(runtime_output) and _is_pure_data(resource_output) and _is_pure_data(json_anchor)
	return {
		"case_id": str(case_data.get("case_id", "")),
		"category": str(case_data.get("category", "")),
		"kind": str(case_data.get("kind", "")),
		"input": _input(case_data),
		"runtime_model_output": runtime_output,
		"resource_profile_output": resource_output,
		"json_anchor": json_anchor,
		"input_checked": input_checked,
		"runtime_model_checked": runtime_model_checked,
		"resource_profile_checked": resource_profile_checked,
		"json_anchor_checked": not json_anchor.is_empty(),
		"parity_checked": parity_checked,
		"passed": passed,
		"notes": notes if passed else "failed: %s" % notes,
	}


func _runtime() -> RefCounted:
	if _runtime_model == null:
		var script: Script = load(RUNTIME_MODEL_SCRIPT_PATH) as Script
		if script != null:
			_runtime_model = script.new() as RefCounted
	return _runtime_model


func _price_curve() -> RefCounted:
	if _price_curve_model == null:
		var script: Script = load(CARD_PRICE_CURVE_SCRIPT_PATH) as Script
		if script != null:
			_price_curve_model = script.new() as RefCounted
	return _price_curve_model


func _input(case_data: Dictionary) -> Dictionary:
	var value: Variant = case_data.get("input", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _runtime_policy(key: String) -> Dictionary:
	var payload := runtime_targets()
	var value: Variant = payload.get(key, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _json_policy(key: String) -> Dictionary:
	var payload := _json_payload("res://data/balance/runtime_balance_targets.json")
	var value: Variant = payload.get(key, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _json_payload(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _suggested_price_from_curve(card: Dictionary, curve: Dictionary) -> int:
	var base_by_type: Dictionary = curve.get("base_by_type", {}) if curve.get("base_by_type", {}) is Dictionary else {}
	var rank_step: Dictionary = curve.get("rank_step", {}) if curve.get("rank_step", {}) is Dictionary else {}
	var weights: Dictionary = curve.get("weights", {}) if curve.get("weights", {}) is Dictionary else {}
	var card_type := str(card.get("type", "经济"))
	var rank := str(card.get("rank", "I"))
	var value := int(base_by_type.get(card_type, 60)) + int(rank_step.get(rank, 0))
	value += int(card.get("effect_power", 0)) * int(weights.get("effect_power", 8))
	value += int(card.get("targeting_premium", 0)) * int(weights.get("targeting_premium", 12))
	value += int(card.get("hidden_info_premium", 0)) * int(weights.get("hidden_info_premium", 10))
	value += int(card.get("economy_scaling_premium", 0)) * int(weights.get("economy_scaling_premium", 9))
	value += int(card.get("interaction_premium", 0)) * int(weights.get("interaction_premium", 8))
	value -= int(card.get("setup_requirement_discount", 0)) * int(weights.get("setup_requirement_discount", 9))
	value -= int(card.get("delayed_effect_discount", 0)) * int(weights.get("delayed_effect_discount", 7))
	value -= int(card.get("self_risk_discount", 0)) * int(weights.get("self_risk_discount", 8))
	return maxi(10, int(round(float(value) / 5.0) * 5))


func _value_for_card_type(card: Dictionary, base_by_type: Variant) -> int:
	var values: Dictionary = base_by_type if base_by_type is Dictionary else {}
	return int(values.get(str(card.get("type", "经济")), 60))


func _value_for_card_rank(card: Dictionary, rank_step: Variant) -> int:
	var values: Dictionary = rank_step if rank_step is Dictionary else {}
	return int(values.get(str(card.get("rank", "I")), 0))


func _depth_row(rows_variant: Variant, depth: int) -> Dictionary:
	var rows: Array = rows_variant if rows_variant is Array else []
	for row_variant in rows:
		var row: Dictionary = row_variant if row_variant is Dictionary else {}
		if int(row.get("depth", -1)) == depth:
			return row.duplicate(true)
	return {}


func _nested(source: Dictionary, keys: Array) -> Variant:
	var value: Variant = source
	for key_variant in keys:
		if not (value is Dictionary):
			return null
		value = (value as Dictionary).get(str(key_variant))
	return value


func _number_in_range(value: float, range_payload: Dictionary) -> bool:
	return value >= float(range_payload.get("min", -INF)) and value <= float(range_payload.get("max", INF))


func _roman_for_rank(rank: int) -> String:
	match rank:
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		_:
			return "IV"


func _deep_equal(left: Variant, right: Variant) -> bool:
	var left_type := typeof(left)
	var right_type := typeof(right)
	if _is_number_type(left_type) and _is_number_type(right_type):
		return is_equal_approx(float(left), float(right))
	if left_type != right_type:
		return false
	if left is Dictionary:
		var left_dictionary: Dictionary = left
		var right_dictionary: Dictionary = right
		if left_dictionary.size() != right_dictionary.size():
			return false
		for key in left_dictionary.keys():
			if not right_dictionary.has(key):
				return false
			if not _deep_equal(left_dictionary[key], right_dictionary[key]):
				return false
		return true
	if left is Array:
		var left_array: Array = left
		var right_array: Array = right
		if left_array.size() != right_array.size():
			return false
		for index in left_array.size():
			if not _deep_equal(left_array[index], right_array[index]):
				return false
		return true
	return left == right


func _is_number_type(value_type: int) -> bool:
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or value is Object:
		return false
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if not _is_pure_data(key) or not _is_pure_data((value as Dictionary)[key]):
				return false
		return true
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
	return true
