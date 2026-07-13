extends RefCounted
class_name BalanceRuntimeParameterBridge

const SOURCE_JSON_CURRENT := "json_current"
const SOURCE_RESOURCE_PROFILE := "resource_profile"
const SOURCE_AUTO_SAFE := "auto_safe"

const RegistryScript := preload("res://scripts/balance/balance_parameter_resource_registry.gd")

const RUNTIME_JSON_PATH := "res://data/balance/runtime_balance_targets.json"
const PRICE_CURVE_JSON_PATH := "res://data/balance/price_curve_v1.json"
const PROFILE_RESOURCE_PATH := "res://resources/balance/balance_parameter_profile_v1.tres"

var _registry: RefCounted = RegistryScript.new()


func source_modes() -> Array[String]:
	return [SOURCE_JSON_CURRENT, SOURCE_RESOURCE_PROFILE, SOURCE_AUTO_SAFE]


func default_source_mode() -> String:
	return SOURCE_JSON_CURRENT


func runtime_targets(source_mode: String = SOURCE_JSON_CURRENT) -> Dictionary:
	match _normalized_source_mode(source_mode):
		SOURCE_RESOURCE_PROFILE:
			return resource_runtime_targets()
		SOURCE_AUTO_SAFE:
			return resource_runtime_targets() if _sources_match("runtime") else json_runtime_targets()
	return json_runtime_targets()


func price_curve(source_mode: String = SOURCE_JSON_CURRENT) -> Dictionary:
	match _normalized_source_mode(source_mode):
		SOURCE_RESOURCE_PROFILE:
			return resource_price_curve()
		SOURCE_AUTO_SAFE:
			return resource_price_curve() if _sources_match("price_curve") else json_price_curve()
	return json_price_curve()


func resource_runtime_targets() -> Dictionary:
	var data: Variant = _registry.call("runtime_resource_payload")
	return (data as Dictionary).duplicate(true) if data is Dictionary else {}


func resource_price_curve() -> Dictionary:
	var data: Variant = _registry.call("price_curve_resource_payload")
	return (data as Dictionary).duplicate(true) if data is Dictionary else {}


func json_runtime_targets() -> Dictionary:
	return _json_payload(RUNTIME_JSON_PATH)


func json_price_curve() -> Dictionary:
	return _json_payload(PRICE_CURVE_JSON_PATH)


func compare_sources() -> Dictionary:
	var json_runtime := json_runtime_targets()
	var resource_runtime := resource_runtime_targets()
	var json_curve := json_price_curve()
	var resource_curve := resource_price_curve()
	var runtime_parity := _deep_equal(json_runtime, resource_runtime)
	var price_curve_parity := _deep_equal(json_curve, resource_curve)
	var json_current_runtime := runtime_targets(SOURCE_JSON_CURRENT)
	var json_current_curve := price_curve(SOURCE_JSON_CURRENT)
	var resource_mode_runtime := runtime_targets(SOURCE_RESOURCE_PROFILE)
	var resource_mode_curve := price_curve(SOURCE_RESOURCE_PROFILE)
	return {
		"default_source_mode": default_source_mode(),
		"profile_resource": PROFILE_RESOURCE_PATH,
		"runtime_json": RUNTIME_JSON_PATH,
		"price_curve_json": PRICE_CURVE_JSON_PATH,
		"source_modes": source_modes(),
		"json_runtime_summary": _runtime_summary(json_runtime),
		"resource_runtime_summary": _runtime_summary(resource_runtime),
		"json_price_curve_summary": _price_curve_summary(json_curve),
		"resource_price_curve_summary": _price_curve_summary(resource_curve),
		"runtime_targets_parity": runtime_parity,
		"price_curve_parity": price_curve_parity,
		"all_parity": runtime_parity and price_curve_parity,
		"json_current_is_default": default_source_mode() == SOURCE_JSON_CURRENT,
		"json_current_runtime_checked": _deep_equal(json_current_runtime, json_runtime),
		"json_current_price_curve_checked": _deep_equal(json_current_curve, json_curve),
		"resource_profile_runtime_checked": _deep_equal(resource_mode_runtime, resource_runtime),
		"resource_profile_price_curve_checked": _deep_equal(resource_mode_curve, resource_curve),
		"auto_safe_runtime_source": SOURCE_RESOURCE_PROFILE if runtime_parity else SOURCE_JSON_CURRENT,
		"auto_safe_price_curve_source": SOURCE_RESOURCE_PROFILE if price_curve_parity else SOURCE_JSON_CURRENT,
		"pure_data_checked": _is_pure_data(json_runtime) and _is_pure_data(resource_runtime) and _is_pure_data(json_curve) and _is_pure_data(resource_curve),
	}


func bridge_summary(source_mode: String = SOURCE_JSON_CURRENT) -> Dictionary:
	var mode := _normalized_source_mode(source_mode)
	var runtime_payload := runtime_targets(mode)
	var price_payload := price_curve(mode)
	return {
		"source_mode": mode,
		"default_source_mode": default_source_mode(),
		"default_runtime_unchanged": default_source_mode() == SOURCE_JSON_CURRENT,
		"runtime_summary": _runtime_summary(runtime_payload),
		"price_curve_summary": _price_curve_summary(price_payload),
		"comparison": compare_sources(),
	}


func _normalized_source_mode(source_mode: String) -> String:
	return source_mode if source_modes().has(source_mode) else SOURCE_JSON_CURRENT


func _sources_match(kind: String) -> bool:
	var comparison := compare_sources()
	match kind:
		"runtime":
			return bool(comparison.get("runtime_targets_parity", false))
		"price_curve":
			return bool(comparison.get("price_curve_parity", false))
	return false


func _json_payload(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _int_value(value: Variant, fallback := 0) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String:
		return str(value).to_int()
	return fallback


func _runtime_summary(payload: Dictionary) -> Dictionary:
	var movement_policy: Dictionary = payload.get("movement_policy", {}) if payload.get("movement_policy", {}) is Dictionary else {}
	var victory_goal: Dictionary = payload.get("victory_goal", {}) if payload.get("victory_goal", {}) is Dictionary else {}
	var goals: Array = victory_goal.get("goals_by_depth", []) if victory_goal.get("goals_by_depth", []) is Array else []
	return {
		"version": str(payload.get("version", "")),
		"starting_cash": _int_value(payload.get("starting_cash", 0)),
		"city_build_cost": _int_value(payload.get("city_build_cost", 0)),
		"target_game_length": _int_value(payload.get("target_game_length", 0)),
		"victory_goal_rows": goals.size(),
		"normal_monster_region_exit_target_seconds": float(movement_policy.get("normal_monster_region_exit_target_seconds", 0.0)),
		"source_script_count": (payload.get("source_scripts", []) as Array).size() if payload.get("source_scripts", []) is Array else 0,
	}


func _price_curve_summary(payload: Dictionary) -> Dictionary:
	var base_by_type: Dictionary = payload.get("base_by_type", {}) if payload.get("base_by_type", {}) is Dictionary else {}
	var rank_step: Dictionary = payload.get("rank_step", {}) if payload.get("rank_step", {}) is Dictionary else {}
	var weights: Dictionary = payload.get("weights", {}) if payload.get("weights", {}) is Dictionary else {}
	return {
		"version": str(payload.get("version", "")),
		"base_type_count": base_by_type.size(),
		"rank_step_count": rank_step.size(),
		"weight_count": weights.size(),
		"economy_base": _int_value(base_by_type.get("经济", 0)),
		"rank_iv_step": _int_value(rank_step.get("IV", 0)),
	}


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
