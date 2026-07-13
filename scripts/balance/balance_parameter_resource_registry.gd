extends RefCounted
class_name BalanceParameterResourceRegistry

const PROFILE_RESOURCE_PATH := "res://resources/balance/balance_parameter_profile_v1.tres"
const RUNTIME_RESOURCE_PATH := "res://resources/balance/runtime_balance_parameters_v1.tres"
const PRICE_CURVE_RESOURCE_PATH := "res://resources/balance/card_price_curve_parameters_v1.tres"
const RUNTIME_JSON_PATH := "res://data/balance/runtime_balance_targets.json"
const PRICE_CURVE_JSON_PATH := "res://data/balance/price_curve_v1.json"
const RUNTIME_MODEL_SCRIPT_PATH := "res://scripts/balance/runtime_balance_model.gd"
const MOVEMENT_MODEL_SCRIPT_PATH := "res://scripts/balance/movement_balance_model.gd"
const COMBAT_MODEL_SCRIPT_PATH := "res://scripts/balance/combat_balance_model.gd"
const ENVIRONMENT_MODEL_SCRIPT_PATH := "res://scripts/balance/environment_balance_model.gd"
const PRICE_CURVE_SCRIPT_PATH := "res://scripts/balance/card_price_curve.gd"


func resource_paths() -> Array[String]:
	return [
		PROFILE_RESOURCE_PATH,
		RUNTIME_RESOURCE_PATH,
		PRICE_CURVE_RESOURCE_PATH,
	]


func resource_cases() -> Array:
	return [
		_case("profile_loads", "Profile", PROFILE_RESOURCE_PATH, "", "Balance profile .tres loads and exposes runtime/price subresources."),
		_case("runtime_core_matches_json", "Runtime Targets", RUNTIME_RESOURCE_PATH, RUNTIME_JSON_PATH, "Core economy and target length anchors match runtime_balance_targets.json."),
		_case("runtime_victory_region_matches_json", "Runtime Targets", RUNTIME_RESOURCE_PATH, RUNTIME_JSON_PATH, "Victory depth rows and region count rows match JSON."),
		_case("runtime_movement_matches_json", "Runtime Targets", RUNTIME_RESOURCE_PATH, RUNTIME_JSON_PATH, "Movement policy target seconds and ecology multipliers match JSON."),
		_case("runtime_combat_environment_matches_json", "Runtime Targets", RUNTIME_RESOURCE_PATH, RUNTIME_JSON_PATH, "Combat knockback and global environment ranges match JSON."),
		_case("runtime_card_and_damage_policy_matches_json", "Runtime Targets", RUNTIME_RESOURCE_PATH, RUNTIME_JSON_PATH, "Card price policy and monster-owner damage exposure match JSON."),
		_case("price_curve_base_rank_matches_json", "Price Curve", PRICE_CURVE_RESOURCE_PATH, PRICE_CURVE_JSON_PATH, "Card type base prices and rank steps match price_curve_v1.json."),
		_case("price_curve_weights_match_json", "Price Curve", PRICE_CURVE_RESOURCE_PATH, PRICE_CURVE_JSON_PATH, "Inspector-exposed weight fields match price_curve_v1.json."),
		_case("model_script_paths_registered", "Model Scripts", PROFILE_RESOURCE_PATH, "", "Existing runtime balance model scripts remain registered; formulas are not moved in this sprint."),
		_case("payloads_stay_pure_data", "Profile", PROFILE_RESOURCE_PATH, "", "Resource adapters emit Dictionary/Array/String/Number/Bool data only."),
	]


func validation_records() -> Array:
	var profile := _load_resource(PROFILE_RESOURCE_PATH)
	var runtime_payload := runtime_resource_payload()
	var price_payload := price_curve_resource_payload()
	var runtime_json := json_payload(RUNTIME_JSON_PATH)
	var price_json := json_payload(PRICE_CURVE_JSON_PATH)
	var records: Array = []
	records.append(_record_for_case("profile_loads", profile != null and profile.has_method("to_runtime_targets_dictionary") and profile.has_method("to_price_curve_dictionary"), true, false, true, "profile and subresource adapter methods are available"))
	records.append(_record_for_case("runtime_core_matches_json", _selected_keys_match(runtime_payload, runtime_json, ["version", "starting_cash", "city_build_cost", "city_final_value", "reference_city_gdp_per_minute", "target_game_length"]), true, true, false, "core runtime balance anchors mirror JSON"))
	records.append(_record_for_case("runtime_victory_region_matches_json", _deep_equal(_nested(runtime_payload, ["victory_goal", "goals_by_depth"]), _nested(runtime_json, ["victory_goal", "goals_by_depth"])) and _deep_equal(_nested(runtime_payload, ["planet_region_policy", "region_counts_by_depth"]), _nested(runtime_json, ["planet_region_policy", "region_counts_by_depth"])), true, true, false, "victory and region rows mirror JSON"))
	records.append(_record_for_case("runtime_movement_matches_json", _deep_equal(runtime_payload.get("movement_policy", {}), runtime_json.get("movement_policy", {})), true, true, false, "movement policy mirrors JSON"))
	records.append(_record_for_case("runtime_combat_environment_matches_json", _deep_equal(runtime_payload.get("combat_knockback_policy", {}), runtime_json.get("combat_knockback_policy", {})) and _deep_equal(runtime_payload.get("global_environment_policy", {}), runtime_json.get("global_environment_policy", {})), true, true, false, "combat and environment policies mirror JSON"))
	records.append(_record_for_case("runtime_card_and_damage_policy_matches_json", _deep_equal(runtime_payload.get("card_price_policy", {}), runtime_json.get("card_price_policy", {})) and _deep_equal(runtime_payload.get("monster_owner_damage_cash", {}), runtime_json.get("monster_owner_damage_cash", {})), true, true, false, "card pricing policy and monster-owner exposure mirror JSON"))
	records.append(_record_for_case("price_curve_base_rank_matches_json", _deep_equal(price_payload.get("base_by_type", {}), price_json.get("base_by_type", {})) and _deep_equal(price_payload.get("rank_step", {}), price_json.get("rank_step", {})), true, true, false, "price curve base/rank values mirror JSON"))
	records.append(_record_for_case("price_curve_weights_match_json", _deep_equal(price_payload.get("weights", {}), price_json.get("weights", {})), true, true, false, "price curve weights mirror JSON"))
	records.append(_record_for_case("model_script_paths_registered", _model_script_paths_exist(runtime_payload), true, false, true, "existing balance model scripts remain the runtime formula owners"))
	records.append(_record_for_case("payloads_stay_pure_data", _is_pure_data(runtime_payload) and _is_pure_data(price_payload) and _is_pure_data(profile_summary()), true, true, true, "Resource payloads stay pure data"))
	return records


func build_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_variant in resource_cases():
		var case: Dictionary = case_variant if case_variant is Dictionary else {}
		records.append({
			"case_id": str(case.get("case_id", "")),
			"resource_path": str(case.get("resource_path", "")),
			"json_path": str(case.get("json_path", "")),
			"category": str(case.get("category", "")),
			"inspector_visible": str(case.get("resource_path", "")).ends_with(".tres"),
			"json_parity_checked": str(case.get("json_path", "")) != "",
			"model_compatibility_checked": str(case.get("case_id", "")) == "model_script_paths_registered",
			"pure_data_checked": str(case.get("case_id", "")) == "payloads_stay_pure_data",
			"passed": false,
			"notes": "Preview manifest only; run BalanceParameterResourceBench for live results.",
		})
	return {
		"suite": "balance_parameter_resourceization",
		"profile_resource": PROFILE_RESOURCE_PATH,
		"runtime_resource": RUNTIME_RESOURCE_PATH,
		"price_curve_resource": PRICE_CURVE_RESOURCE_PATH,
		"runtime_json": RUNTIME_JSON_PATH,
		"price_curve_json": PRICE_CURVE_JSON_PATH,
		"record_count": records.size(),
		"records": records,
	}


func validation_record_for_case(case_id: String) -> Dictionary:
	for record_variant in validation_records():
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		if str(record.get("case_id", "")) == case_id:
			return record.duplicate(true)
	return {}


func categories() -> Array[String]:
	var result: Array[String] = []
	for case_variant in resource_cases():
		var case: Dictionary = case_variant if case_variant is Dictionary else {}
		var category := str(case.get("category", ""))
		if category != "" and not result.has(category):
			result.append(category)
	return result


func profile_summary() -> Dictionary:
	var profile := _load_resource(PROFILE_RESOURCE_PATH)
	if profile != null and profile.has_method("resource_summary"):
		var data: Variant = profile.call("resource_summary")
		return data if data is Dictionary else {}
	return {}


func runtime_resource_payload() -> Dictionary:
	var profile := _load_resource(PROFILE_RESOURCE_PATH)
	if profile != null and profile.has_method("to_runtime_targets_dictionary"):
		var data: Variant = profile.call("to_runtime_targets_dictionary")
		return data if data is Dictionary else {}
	var runtime_resource := _load_resource(RUNTIME_RESOURCE_PATH)
	if runtime_resource != null and runtime_resource.has_method("to_runtime_targets_dictionary"):
		var runtime_data: Variant = runtime_resource.call("to_runtime_targets_dictionary")
		return runtime_data if runtime_data is Dictionary else {}
	return {}


func price_curve_resource_payload() -> Dictionary:
	var profile := _load_resource(PROFILE_RESOURCE_PATH)
	if profile != null and profile.has_method("to_price_curve_dictionary"):
		var data: Variant = profile.call("to_price_curve_dictionary")
		return data if data is Dictionary else {}
	var curve_resource := _load_resource(PRICE_CURVE_RESOURCE_PATH)
	if curve_resource != null and curve_resource.has_method("to_price_curve_dictionary"):
		var curve_data: Variant = curve_resource.call("to_price_curve_dictionary")
		return curve_data if curve_data is Dictionary else {}
	return {}


func json_payload(path: String) -> Dictionary:
	if path == "":
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _case(case_id: String, category: String, resource_path: String, json_path: String, notes: String) -> Dictionary:
	return {
		"case_id": case_id,
		"category": category,
		"resource_path": resource_path,
		"json_path": json_path,
		"notes": notes,
	}


func _record_for_case(case_id: String, passed: bool, inspector_visible: bool, json_parity_checked: bool, model_compatibility_checked: bool, notes: String) -> Dictionary:
	var case := _case_for_id(case_id)
	var pure_data_checked := case_id == "payloads_stay_pure_data"
	return {
		"case_id": case_id,
		"resource_path": str(case.get("resource_path", "")),
		"json_path": str(case.get("json_path", "")),
		"category": str(case.get("category", "")),
		"inspector_visible": inspector_visible and _resource_path_visible(str(case.get("resource_path", ""))),
		"json_parity_checked": json_parity_checked,
		"model_compatibility_checked": model_compatibility_checked,
		"pure_data_checked": pure_data_checked,
		"passed": passed,
		"notes": notes if passed else "failed: %s" % notes,
	}


func _case_for_id(case_id: String) -> Dictionary:
	for case_variant in resource_cases():
		var case: Dictionary = case_variant if case_variant is Dictionary else {}
		if str(case.get("case_id", "")) == case_id:
			return case.duplicate(true)
	return {}


func _resource_path_visible(path: String) -> bool:
	return path.ends_with(".tres") and ResourceLoader.exists(path)


func _load_resource(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Resource


func _selected_keys_match(left: Dictionary, right: Dictionary, keys: Array) -> bool:
	for key_variant in keys:
		var key := str(key_variant)
		if not _deep_equal(left.get(key), right.get(key)):
			return false
	return true


func _nested(source: Dictionary, keys: Array) -> Variant:
	var value: Variant = source
	for key_variant in keys:
		if not (value is Dictionary):
			return null
		value = (value as Dictionary).get(str(key_variant))
	return value


func _model_script_paths_exist(runtime_payload: Dictionary) -> bool:
	var source_scripts: Array = runtime_payload.get("source_scripts", []) if runtime_payload.get("source_scripts", []) is Array else []
	var paths: Array = [
		RUNTIME_MODEL_SCRIPT_PATH,
		MOVEMENT_MODEL_SCRIPT_PATH,
		COMBAT_MODEL_SCRIPT_PATH,
		ENVIRONMENT_MODEL_SCRIPT_PATH,
		PRICE_CURVE_SCRIPT_PATH,
	]
	for source_path in source_scripts:
		if not paths.has(str(source_path)):
			paths.append(str(source_path))
	for path_variant in paths:
		if not ResourceLoader.exists(str(path_variant)):
			return false
	return true


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
