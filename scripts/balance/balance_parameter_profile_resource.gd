@tool
extends Resource
class_name BalanceParameterProfileResource

@export var profile_id := "runtime_balance_v1"
@export var display_name := "Runtime Balance Profile v1"
@export_multiline var design_notes := "Inspector-editable parameter wrapper for runtime balance targets and card price curve data. It does not replace settlement formulas or action ids."
@export var runtime_parameters: Resource
@export var price_curve_parameters: Resource


func to_runtime_targets_dictionary() -> Dictionary:
	if runtime_parameters != null and runtime_parameters.has_method("to_runtime_targets_dictionary"):
		var data: Variant = runtime_parameters.call("to_runtime_targets_dictionary")
		return data if data is Dictionary else {}
	return {}


func to_price_curve_dictionary() -> Dictionary:
	if price_curve_parameters != null and price_curve_parameters.has_method("to_price_curve_dictionary"):
		var data: Variant = price_curve_parameters.call("to_price_curve_dictionary")
		return data if data is Dictionary else {}
	return {}


func validate_profile() -> Array:
	var records: Array = []
	records.append({
		"id": "profile_runtime_resource",
		"passed": runtime_parameters != null and runtime_parameters.has_method("to_runtime_targets_dictionary"),
		"notes": "runtime balance target Resource is assigned",
	})
	records.append({
		"id": "profile_price_curve_resource",
		"passed": price_curve_parameters != null and price_curve_parameters.has_method("to_price_curve_dictionary"),
		"notes": "card price curve Resource is assigned",
	})
	if runtime_parameters != null and runtime_parameters.has_method("validate_profile"):
		var runtime_records: Variant = runtime_parameters.call("validate_profile")
		if runtime_records is Array:
			records.append_array(runtime_records)
	if price_curve_parameters != null and price_curve_parameters.has_method("validate_profile"):
		var curve_records: Variant = price_curve_parameters.call("validate_profile")
		if curve_records is Array:
			records.append_array(curve_records)
	return records


func resource_summary() -> Dictionary:
	var runtime_payload := to_runtime_targets_dictionary()
	var price_payload := to_price_curve_dictionary()
	return {
		"profile_id": profile_id,
		"display_name": display_name,
		"runtime_version": str(runtime_payload.get("version", "")),
		"starting_cash": int(runtime_payload.get("starting_cash", 0)),
		"city_build_cost": int(runtime_payload.get("city_build_cost", 0)),
		"price_type_count": (price_payload.get("base_by_type", {}) as Dictionary).size() if price_payload.get("base_by_type", {}) is Dictionary else 0,
		"price_weight_count": (price_payload.get("weights", {}) as Dictionary).size() if price_payload.get("weights", {}) is Dictionary else 0,
	}
