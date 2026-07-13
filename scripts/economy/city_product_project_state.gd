extends RefCounted
class_name CityProductProjectState

const SHARE_BASIS_POINTS := 10000
const VALID_DIRECTIONS := ["production", "demand", "commerce"]


static func project_id(district_index: int, product_id: String, direction: String) -> String:
	return "%d:%s:%s" % [district_index, product_id.strip_edges(), normalize_direction(direction)]


static func normalize_direction(direction: String) -> String:
	var normalized := direction.strip_edges().to_lower()
	return normalized if VALID_DIRECTIONS.has(normalized) else "production"


static func direction_label(direction: String) -> String:
	match normalize_direction(direction):
		"demand":
			return "需求"
		"commerce":
			return "通商"
	return "生产"


static func create_project(district_index: int, product_id: String, direction: String, player_index: int, contribution_units: int, created_order: int) -> Dictionary:
	var safe_direction := normalize_direction(direction)
	var project := {
		"project_id": project_id(district_index, product_id, safe_direction),
		"district_index": district_index,
		"product_id": product_id.strip_edges(),
		"direction": safe_direction,
		"level": 1,
		"active": true,
		"created_order": maxi(0, created_order),
		"founder_player_index": player_index,
		"contribution_by_player": {},
		"contribution_order_by_player": {},
		"share_basis_points_by_player": {},
		"controller_player_index": -1,
		"current_gdp": 0,
		"public_summary": "",
		"cashflow_remainder_by_player": {},
		"cashflow_paid_by_player": {},
	}
	return contribute(project, player_index, contribution_units, created_order)


static func normalize_project(value: Dictionary) -> Dictionary:
	var project := value.duplicate(true)
	project["district_index"] = int(project.get("district_index", -1))
	project["product_id"] = str(project.get("product_id", "")).strip_edges()
	project["direction"] = normalize_direction(str(project.get("direction", "production")))
	project["project_id"] = str(project.get("project_id", project_id(int(project["district_index"]), str(project["product_id"]), str(project["direction"]))))
	project["level"] = maxi(1, int(project.get("level", 1)))
	project["active"] = bool(project.get("active", true))
	project["created_order"] = maxi(0, int(project.get("created_order", 0)))
	project["founder_player_index"] = int(project.get("founder_player_index", -1))
	project["current_gdp"] = maxi(0, int(project.get("current_gdp", 0)))
	project["cashflow_remainder_by_player"] = _numeric_dictionary(project.get("cashflow_remainder_by_player", {}), false)
	project["cashflow_paid_by_player"] = _numeric_dictionary(project.get("cashflow_paid_by_player", {}), true)
	return recalculate_shares(project)


static func contribute(value: Dictionary, player_index: int, contribution_units: int, contribution_order: int) -> Dictionary:
	var project := value.duplicate(true)
	var contributions := _numeric_dictionary(project.get("contribution_by_player", {}), true)
	var orders := _numeric_dictionary(project.get("contribution_order_by_player", {}), true)
	var player_key := str(player_index)
	contributions[player_key] = maxi(0, int(contributions.get(player_key, 0))) + maxi(1, contribution_units)
	if not orders.has(player_key):
		orders[player_key] = maxi(0, contribution_order)
	if int(project.get("founder_player_index", -1)) < 0:
		project["founder_player_index"] = player_index
	project["contribution_by_player"] = contributions
	project["contribution_order_by_player"] = orders
	project["level"] = maxi(1, int(project.get("level", 1))) + (1 if contributions.size() > 1 or int(contributions[player_key]) > 1 else 0)
	return recalculate_shares(project)


static func recalculate_shares(value: Dictionary) -> Dictionary:
	var project := value.duplicate(true)
	var contributions := _numeric_dictionary(project.get("contribution_by_player", {}), true)
	var orders := _numeric_dictionary(project.get("contribution_order_by_player", {}), true)
	var total := 0
	for amount_variant in contributions.values():
		total += maxi(0, int(amount_variant))
	var shares := {}
	var controller := -1
	var best_amount := -1
	var best_order := 2147483647
	if total > 0:
		for player_key_variant in contributions.keys():
			var player_key := str(player_key_variant)
			var amount := maxi(0, int(contributions[player_key]))
			shares[player_key] = int(floor(float(amount * SHARE_BASIS_POINTS) / float(total)))
			var player_index := int(player_key)
			var order := int(orders.get(player_key, 2147483647))
			if amount > best_amount or (amount == best_amount and order < best_order) or (amount == best_amount and order == best_order and (controller < 0 or player_index < controller)):
				controller = player_index
				best_amount = amount
				best_order = order
		var assigned := 0
		for share_variant in shares.values():
			assigned += int(share_variant)
		if controller >= 0:
			var controller_key := str(controller)
			shares[controller_key] = int(shares.get(controller_key, 0)) + SHARE_BASIS_POINTS - assigned
	project["contribution_by_player"] = contributions
	project["contribution_order_by_player"] = orders
	project["share_basis_points_by_player"] = shares
	project["controller_player_index"] = controller
	project["public_summary"] = "%s｜%s｜Lv.%d｜GDP %d/min" % [
		str(project.get("product_id", "商品")),
		direction_label(str(project.get("direction", "production"))),
		maxi(1, int(project.get("level", 1))),
		maxi(0, int(project.get("current_gdp", 0))),
	]
	return project


static func assign_city_gdp(project_values: Array, city_gdp: int) -> Array:
	var projects: Array = []
	var active_indices: Array = []
	var total_weight := 0
	for value_variant in project_values:
		var project := normalize_project(value_variant as Dictionary) if value_variant is Dictionary else {}
		if project.is_empty():
			continue
		project["current_gdp"] = 0
		projects.append(project)
		if bool(project.get("active", true)):
			active_indices.append(projects.size() - 1)
			total_weight += maxi(1, int(project.get("level", 1)))
	if total_weight <= 0 or city_gdp <= 0:
		return projects
	var assigned := 0
	for index_variant in active_indices:
		var index := int(index_variant)
		var weight := maxi(1, int((projects[index] as Dictionary).get("level", 1)))
		var amount := int(floor(float(city_gdp * weight) / float(total_weight)))
		projects[index]["current_gdp"] = amount
		assigned += amount
	if not active_indices.is_empty():
		var first_index := int(active_indices[0])
		projects[first_index]["current_gdp"] = int(projects[first_index].get("current_gdp", 0)) + city_gdp - assigned
	for i in range(projects.size()):
		projects[i] = recalculate_shares(projects[i] as Dictionary)
	return projects


static func gdp_by_player(project_values: Array) -> Dictionary:
	var result := {}
	for value_variant in project_values:
		if not (value_variant is Dictionary):
			continue
		var project := normalize_project(value_variant as Dictionary)
		if not bool(project.get("active", true)):
			continue
		var project_gdp := maxi(0, int(project.get("current_gdp", 0)))
		var shares: Dictionary = project.get("share_basis_points_by_player", {})
		var assigned := 0
		for player_key_variant in shares.keys():
			var player_key := str(player_key_variant)
			var amount := int(floor(float(project_gdp * int(shares[player_key])) / float(SHARE_BASIS_POINTS)))
			result[player_key] = int(result.get(player_key, 0)) + amount
			assigned += amount
		var controller := int(project.get("controller_player_index", -1))
		if controller >= 0 and project_gdp > assigned:
			var controller_key := str(controller)
			result[controller_key] = int(result.get(controller_key, 0)) + project_gdp - assigned
	return result


static func player_gdp(project_values: Array, player_index: int) -> int:
	return int(gdp_by_player(project_values).get(str(player_index), 0))


static func public_snapshot(value: Dictionary) -> Dictionary:
	var project := normalize_project(value)
	return {
		"project_id": str(project.get("project_id", "")),
		"district_index": int(project.get("district_index", -1)),
		"product_id": str(project.get("product_id", "")),
		"direction": str(project.get("direction", "production")),
		"direction_label": direction_label(str(project.get("direction", "production"))),
		"level": int(project.get("level", 1)),
		"active": bool(project.get("active", true)),
		"current_gdp": int(project.get("current_gdp", 0)),
		"public_summary": str(project.get("public_summary", "")),
	}


static func private_snapshot(value: Dictionary, viewer_player_index: int) -> Dictionary:
	var project := normalize_project(value)
	var result := public_snapshot(project)
	var shares: Dictionary = project.get("share_basis_points_by_player", {})
	var contributions: Dictionary = project.get("contribution_by_player", {})
	var viewer_key := str(viewer_player_index)
	result["own_share_basis_points"] = int(shares.get(viewer_key, 0))
	result["own_share_percent"] = float(int(shares.get(viewer_key, 0))) / 100.0
	result["own_contribution"] = int(contributions.get(viewer_key, 0))
	result["is_controller"] = int(project.get("controller_player_index", -1)) == viewer_player_index
	return result


static func _numeric_dictionary(value: Variant, integers: bool) -> Dictionary:
	var result := {}
	if not (value is Dictionary):
		return result
	for key_variant in (value as Dictionary).keys():
		var key := str(key_variant)
		if integers:
			result[key] = int((value as Dictionary)[key_variant])
		else:
			result[key] = float((value as Dictionary)[key_variant])
	return result
