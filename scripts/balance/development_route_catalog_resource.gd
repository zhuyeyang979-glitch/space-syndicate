@tool
extends Resource
class_name DevelopmentRouteCatalogResource

@export var catalog_id := "development_routes_v04"
@export var display_name := "Space Syndicate Development Routes v0.4"
@export_multiline var design_note := "Inspector-editable metadata for the seven player development routes. Runtime rules and balance formulas remain owned by their existing services."
@export var route_resources: Array[Resource] = []


func all_routes() -> Array:
	var result: Array = []
	for route_resource in route_resources:
		if route_resource == null or not route_resource.has_method("to_runtime_dictionary"):
			continue
		var payload: Variant = route_resource.call("to_runtime_dictionary")
		if payload is Dictionary:
			result.append((payload as Dictionary).duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("sort_order", 0)) < int(right.get("sort_order", 0))
	)
	return result


func route_profile(route_id: String) -> Dictionary:
	for route_variant in all_routes():
		var route: Dictionary = route_variant
		if str(route.get("id", "")) == route_id:
			return route.duplicate(true)
	return {}


func route_id_for_strategy_label(strategy_label: String) -> String:
	for route_variant in all_routes():
		var route: Dictionary = route_variant
		var labels: Array = route.get("strategy_labels", []) if route.get("strategy_labels", []) is Array else []
		if labels.has(strategy_label):
			return str(route.get("id", "tactical_support"))
	return "tactical_support"


func validation_report() -> Dictionary:
	var issues: Array = []
	var route_ids: Array[String] = []
	var sort_orders: Array[int] = []
	for route_resource in route_resources:
		if route_resource == null or not route_resource.has_method("to_runtime_dictionary"):
			issues.append("invalid_route_resource")
			continue
		var payload: Dictionary = route_resource.call("to_runtime_dictionary")
		var route_id := str(payload.get("id", ""))
		var sort_order := int(payload.get("sort_order", -1))
		if route_id == "" or route_ids.has(route_id):
			issues.append("duplicate_or_missing_route:%s" % route_id)
		else:
			route_ids.append(route_id)
		if sort_orders.has(sort_order):
			issues.append("duplicate_sort_order:%d" % sort_order)
		else:
			sort_orders.append(sort_order)
		if route_resource.has_method("validation_issues"):
			for issue_variant in route_resource.call("validation_issues"):
				issues.append("%s:%s" % [route_id, str(issue_variant)])
	return {
		"catalog_id": catalog_id,
		"route_count": route_ids.size(),
		"route_ids": route_ids,
		"valid": issues.is_empty() and route_ids.size() == 7,
		"issues": issues,
	}


func debug_snapshot() -> Dictionary:
	var report := validation_report()
	report["routes"] = all_routes()
	return report
