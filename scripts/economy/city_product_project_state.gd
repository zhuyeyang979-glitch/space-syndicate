extends RefCounted
class_name CityProductProjectState

const PROJECT_SCHEMA_VERSION := "v0.5"
const SHARE_BASIS_POINTS := 10000
const MAX_PROJECT_RANK := 4
const VALID_DIRECTIONS := ["production", "demand", "commerce"]
const SLOT_COUNTS := {
	"production": 2,
	"demand": 2,
	"commerce": 1,
}


static func region_id(district_index: int, explicit_region_id: String = "") -> String:
	var stable_id := explicit_region_id.strip_edges().to_lower()
	if stable_id != "":
		return stable_id
	return "region.%04d" % maxi(0, district_index)


static func slot_id(district_index: int, slot_kind: String, slot_index: int, explicit_region_id: String = "") -> String:
	var safe_kind := normalize_direction(slot_kind)
	return "%s.slot.%s.%d" % [region_id(district_index, explicit_region_id), safe_kind, maxi(0, slot_index)]


static func project_id(district_index: int, slot_kind: String, slot_index: int, generation: int, explicit_region_id: String = "") -> String:
	return "%s.project.g%d" % [slot_id(district_index, slot_kind, slot_index, explicit_region_id), maxi(1, generation)]


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


static func slot_count(slot_kind: String) -> int:
	return int(SLOT_COUNTS.get(normalize_direction(slot_kind), 0))


static func slot_is_valid(slot_kind: String, slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < slot_count(slot_kind)


static func create_project_slots(district_index: int, explicit_region_id: String = "", enabled_counts: Dictionary = {}) -> Array:
	var slots: Array = []
	var stable_region_id := region_id(district_index, explicit_region_id)
	for slot_kind in VALID_DIRECTIONS:
		var enabled_count := clampi(int(enabled_counts.get(slot_kind, SLOT_COUNTS[slot_kind])), 0, int(SLOT_COUNTS[slot_kind]))
		for slot_index in range(int(SLOT_COUNTS[slot_kind])):
			slots.append(create_empty_slot(district_index, slot_kind, slot_index, stable_region_id, slot_index < enabled_count))
	return slots


static func create_empty_slot(district_index: int, slot_kind: String, slot_index: int, explicit_region_id: String = "", enabled: bool = true) -> Dictionary:
	var safe_kind := normalize_direction(slot_kind)
	var stable_region_id := region_id(district_index, explicit_region_id)
	return {
		"slot_id": slot_id(district_index, safe_kind, slot_index, stable_region_id),
		"region_id": stable_region_id,
		"district_index": district_index,
		"slot_kind": safe_kind,
		"slot_index": slot_index,
		"generation": 0,
		"enabled": enabled,
		"active_project": {},
	}


static func normalize_slot(value: Dictionary, district_index: int, expected_kind: String, expected_index: int, explicit_region_id: String = "") -> Dictionary:
	var safe_kind := normalize_direction(expected_kind)
	var stable_region_id := region_id(district_index, explicit_region_id)
	var slot := create_empty_slot(district_index, safe_kind, expected_index, stable_region_id, bool(value.get("enabled", true)))
	slot["generation"] = maxi(0, int(value.get("generation", 0)))
	var active_variant: Variant = value.get("active_project", {})
	if active_variant is Dictionary and not (active_variant as Dictionary).is_empty():
		var project := normalize_project(active_variant as Dictionary, district_index, safe_kind, expected_index, maxi(1, int(slot["generation"])), stable_region_id)
		if bool(project.get("active", false)):
			slot["generation"] = maxi(int(slot["generation"]), int(project.get("generation", 1)))
			slot["active_project"] = project
	return slot


static func create_project(
	district_index: int,
	product_id: String,
	direction: String,
	player_index: int,
	contribution_units: int,
	created_order: int,
	slot_index: int = 0,
	generation: int = 1,
	explicit_region_id: String = ""
) -> Dictionary:
	var safe_direction := normalize_direction(direction)
	var safe_slot_index := clampi(slot_index, 0, maxi(0, slot_count(safe_direction) - 1))
	var safe_generation := maxi(1, generation)
	var stable_region_id := region_id(district_index, explicit_region_id)
	var stable_slot_id := slot_id(district_index, safe_direction, safe_slot_index, stable_region_id)
	var project := {
		"schema_version": PROJECT_SCHEMA_VERSION,
		"project_id": project_id(district_index, safe_direction, safe_slot_index, safe_generation, stable_region_id),
		"slot_id": stable_slot_id,
		"region_id": stable_region_id,
		"district_index": district_index,
		"slot_kind": safe_direction,
		"slot_index": safe_slot_index,
		"generation": safe_generation,
		"product_id": product_id.strip_edges(),
		"direction": safe_direction,
		"level": 1,
		"rank": 1,
		"active": true,
		"lifecycle_state": "active",
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


static func normalize_project(
	value: Dictionary,
	district_index_override: int = -1,
	slot_kind_override: String = "",
	slot_index_override: int = -1,
	generation_override: int = -1,
	explicit_region_id: String = ""
) -> Dictionary:
	var project := value.duplicate(true)
	var district_index := district_index_override if district_index_override >= 0 else int(project.get("district_index", -1))
	var safe_kind := normalize_direction(slot_kind_override if slot_kind_override != "" else str(project.get("slot_kind", project.get("direction", "production"))))
	var safe_slot_index := slot_index_override if slot_index_override >= 0 else int(project.get("slot_index", 0))
	safe_slot_index = clampi(safe_slot_index, 0, maxi(0, slot_count(safe_kind) - 1))
	var safe_generation := generation_override if generation_override > 0 else int(project.get("generation", 1))
	safe_generation = maxi(1, safe_generation)
	var stable_region_id := region_id(district_index, explicit_region_id if explicit_region_id != "" else str(project.get("region_id", "")))
	project["schema_version"] = PROJECT_SCHEMA_VERSION
	project["district_index"] = district_index
	project["region_id"] = stable_region_id
	project["slot_kind"] = safe_kind
	project["direction"] = safe_kind
	project["slot_index"] = safe_slot_index
	project["slot_id"] = slot_id(district_index, safe_kind, safe_slot_index, stable_region_id)
	project["generation"] = safe_generation
	# Product identity is content. It never participates in slot or project identity.
	project["project_id"] = project_id(district_index, safe_kind, safe_slot_index, safe_generation, stable_region_id)
	project["product_id"] = str(project.get("product_id", "")).strip_edges()
	project["level"] = clampi(int(project.get("rank", project.get("level", 1))), 1, MAX_PROJECT_RANK)
	project["rank"] = int(project["level"])
	project["active"] = bool(project.get("active", true))
	project["lifecycle_state"] = "active" if bool(project["active"]) else str(project.get("lifecycle_state", "tombstoned"))
	project["created_order"] = maxi(0, int(project.get("created_order", 0)))
	project["founder_player_index"] = int(project.get("founder_player_index", -1))
	project["current_gdp"] = maxi(0, int(project.get("current_gdp", 0))) if bool(project["active"]) else 0
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
	var current_rank := clampi(int(project.get("rank", project.get("level", 1))), 1, MAX_PROJECT_RANK)
	if contributions.size() > 1 or int(contributions[player_key]) > 1:
		current_rank = mini(MAX_PROJECT_RANK, current_rank + 1)
	project["level"] = current_rank
	project["rank"] = current_rank
	return recalculate_shares(project)


static func recalculate_shares(value: Dictionary) -> Dictionary:
	var project := value.duplicate(true)
	var contributions := _numeric_dictionary(project.get("contribution_by_player", {}), true)
	var orders := _numeric_dictionary(project.get("contribution_order_by_player", {}), true)
	var positive_contributions := {}
	for player_key_variant in contributions.keys():
		var player_key := str(player_key_variant)
		var amount := maxi(0, int(contributions[player_key_variant]))
		if amount > 0:
			positive_contributions[player_key] = amount
	var shares := _allocate_basis_points(positive_contributions, SHARE_BASIS_POINTS)
	var controller := _unique_highest_player(positive_contributions)
	project["contribution_by_player"] = positive_contributions
	project["contribution_order_by_player"] = orders
	project["share_basis_points_by_player"] = shares
	project["controller_player_index"] = controller
	project["level"] = clampi(int(project.get("rank", project.get("level", 1))), 1, MAX_PROJECT_RANK)
	project["rank"] = int(project["level"])
	project["public_summary"] = "%s｜%s｜Lv.%d｜GDP %d/min" % [
		str(project.get("product_id", "商品")),
		direction_label(str(project.get("direction", "production"))),
		int(project["level"]),
		maxi(0, int(project.get("current_gdp", 0))),
	]
	return project


static func assign_city_gdp(project_values: Array, city_gdp: int) -> Array:
	var projects: Array = []
	var weights := {}
	for value_variant in project_values:
		var project := normalize_project(value_variant as Dictionary) if value_variant is Dictionary else {}
		if project.is_empty():
			continue
		project["current_gdp"] = 0
		projects.append(project)
		if bool(project.get("active", true)):
			weights[str(projects.size() - 1)] = maxi(1, int(project.get("rank", project.get("level", 1))))
	var allocation := _allocate_integer_total(weights, maxi(0, city_gdp))
	for index_key_variant in allocation.keys():
		var index := int(str(index_key_variant))
		if index >= 0 and index < projects.size():
			projects[index]["current_gdp"] = int(allocation[index_key_variant])
	for index in range(projects.size()):
		projects[index] = recalculate_shares(projects[index] as Dictionary)
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
		var allocation := _allocate_weighted_total(shares, project_gdp, SHARE_BASIS_POINTS)
		for player_key_variant in allocation.keys():
			var player_key := str(player_key_variant)
			result[player_key] = int(result.get(player_key, 0)) + int(allocation[player_key_variant])
	return result


static func player_gdp(project_values: Array, player_index: int) -> int:
	return int(gdp_by_player(project_values).get(str(player_index), 0))


static func public_snapshot(value: Dictionary) -> Dictionary:
	var project := normalize_project(value)
	return {
		"schema_version": PROJECT_SCHEMA_VERSION,
		"project_id": str(project.get("project_id", "")),
		"slot_id": str(project.get("slot_id", "")),
		"region_id": str(project.get("region_id", "")),
		"district_index": int(project.get("district_index", -1)),
		"slot_kind": str(project.get("slot_kind", "production")),
		"slot_index": int(project.get("slot_index", 0)),
		"generation": int(project.get("generation", 1)),
		"product_id": str(project.get("product_id", "")),
		"direction": str(project.get("direction", "production")),
		"direction_label": direction_label(str(project.get("direction", "production"))),
		"level": int(project.get("level", 1)),
		"rank": int(project.get("rank", 1)),
		"active": bool(project.get("active", true)),
		"lifecycle_state": str(project.get("lifecycle_state", "active")),
		"current_gdp": int(project.get("current_gdp", 0)),
		"public_summary": str(project.get("public_summary", "")),
		"visibility_scope": "public",
		"presentation_key": "ui.city.project.summary",
		"assistive_message_key": "ui.city.project.summary.a11y",
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
	result["visibility_scope"] = "viewer_private"
	return result


static func _unique_highest_player(contributions: Dictionary) -> int:
	var highest := -1
	var leaders: Array[int] = []
	for player_key_variant in contributions.keys():
		var amount := int(contributions[player_key_variant])
		var player_index := int(str(player_key_variant))
		if amount > highest:
			highest = amount
			leaders = [player_index]
		elif amount == highest:
			leaders.append(player_index)
	return leaders[0] if leaders.size() == 1 else -1


static func _allocate_basis_points(weights: Dictionary, total_points: int) -> Dictionary:
	return _allocate_integer_total(weights, total_points)


static func _allocate_integer_total(weights: Dictionary, total_value: int) -> Dictionary:
	var total_weight := 0
	for value_variant in weights.values():
		total_weight += maxi(0, int(value_variant))
	return _allocate_weighted_total(weights, total_value, total_weight)


static func _allocate_weighted_total(weights: Dictionary, total_value: int, denominator: int) -> Dictionary:
	var result := {}
	if total_value <= 0 or denominator <= 0:
		for key_variant in weights.keys():
			result[str(key_variant)] = 0
		return result
	var remainders: Array = []
	var assigned := 0
	for key_variant in weights.keys():
		var key := str(key_variant)
		var weight := maxi(0, int(weights[key_variant]))
		var numerator := weight * total_value
		var base_value := floori(float(numerator) / float(denominator))
		result[key] = base_value
		assigned += base_value
		remainders.append({"key": key, "remainder": numerator % denominator})
	remainders.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left_remainder := int(a.get("remainder", 0))
		var right_remainder := int(b.get("remainder", 0))
		if left_remainder != right_remainder:
			return left_remainder > right_remainder
		return _stable_key_less(str(a.get("key", "")), str(b.get("key", "")))
	)
	var remaining := maxi(0, total_value - assigned)
	for index in range(remaining):
		if remainders.is_empty():
			break
		var key := str((remainders[index % remainders.size()] as Dictionary).get("key", ""))
		result[key] = int(result.get(key, 0)) + 1
	return result


static func _stable_key_less(left: String, right: String) -> bool:
	if left.is_valid_int() and right.is_valid_int():
		return int(left) < int(right)
	return left < right


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
