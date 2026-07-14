extends Node
class_name IndustryCapacityWorldBridge

var _city_trade_network_controller: Node


func bind_city_trade_network_controller(controller: Node) -> void:
	_city_trade_network_controller = controller


func project_rows_for_player(player_index: int) -> Array:
	var rows: Array = []
	if _city_trade_network_controller == null:
		return rows
	if not _city_trade_network_controller.has_method("active_city_district_indices") or not _city_trade_network_controller.has_method("private_project_snapshots"):
		return rows
	var district_indices_variant: Variant = _city_trade_network_controller.call("active_city_district_indices")
	var district_indices: Array = district_indices_variant if district_indices_variant is Array else []
	for district_index_variant in district_indices:
		var district_index := int(district_index_variant)
		var projects_variant: Variant = _city_trade_network_controller.call("private_project_snapshots", district_index, player_index)
		var projects: Array = projects_variant if projects_variant is Array else []
		for project_variant in projects:
			if not (project_variant is Dictionary):
				continue
			var project := project_variant as Dictionary
			rows.append({
				"district_index": district_index,
				"project_id": str(project.get("project_id", "")),
				"slot_id": str(project.get("slot_id", "")),
				"generation": maxi(0, int(project.get("generation", 0))),
				"product_id": str(project.get("product_id", project.get("product", ""))),
				"industry_id": str(project.get("industry_id", "")),
				"attributable_gdp_per_minute": maxi(0, int(project.get("own_gdp_per_minute", 0))),
			})
	return rows


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": _city_trade_network_controller != null,
		"runtime_owner": "none",
		"bridge_role": "industry_capacity_world_facts",
		"city_trade_network_bound": _city_trade_network_controller != null,
		"owns_project_state": false,
		"owns_gdp_formula": false,
		"owns_capacity_formula": false,
		"owns_queue_state": false,
	}
