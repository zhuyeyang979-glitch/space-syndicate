extends RefCounted
class_name CityProductProjectState

# Historical v0.5 project-share fixture. Never preload from production v0.6.

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


static func attribute_gdp_rows(project_values: Array, row_values: Array) -> Dictionary:
	var projects: Array = []
	var project_index_by_id := {}
	for project_variant in project_values:
		if not (project_variant is Dictionary):
			continue
		var project := normalize_project(project_variant as Dictionary)
		project["current_gdp"] = 0
		project_index_by_id[str(project.get("project_id", ""))] = projects.size()
		projects.append(project)
	var rows: Array = []
	for row_variant in row_values:
		if row_variant is Dictionary:
			rows.append((row_variant as Dictionary).duplicate(true))
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("receipt_id", "")) < str(right.get("receipt_id", ""))
	)
	var errors: Array = []
	var seen_receipts := {}
	for row_variant in rows:
		var row: Dictionary = row_variant
		var receipt_id := str(row.get("receipt_id", ""))
		if receipt_id.is_empty() or seen_receipts.has(receipt_id):
			errors.append("receipt_id_missing_or_duplicate")
			continue
		seen_receipts[receipt_id] = true
		if int(row.get("net_gdp_per_minute", -1)) < 0:
			errors.append("row_net_negative:%s" % receipt_id)
			continue
		if bool(row.get("neutral", false)):
			continue
		var project_id_value := str(row.get("project_id", ""))
		if not project_index_by_id.has(project_id_value):
			errors.append("project_missing:%s" % receipt_id)
			continue
		var project: Dictionary = projects[int(project_index_by_id[project_id_value])]
		if not bool(project.get("active", false)) \
			or int(project.get("generation", 0)) != int(row.get("project_generation", -1)) \
			or str(project.get("slot_id", "")) != str(row.get("slot_id", "")) \
			or str(project.get("product_id", "")) != str(row.get("product_id", "")) \
			or str(project.get("direction", "")) != str(row.get("direction", "")):
			errors.append("project_identity_mismatch:%s" % receipt_id)
	if not errors.is_empty():
		return {
			"valid": false,
			"errors": errors,
			"projects": projects,
			"gdp_rows": [],
			"player_attribution_rows": [],
			"player_gdp_by_index": {},
			"neutral_rows": [],
			"project_gdp_per_minute": 0,
			"player_gdp_per_minute": 0,
			"neutral_gdp_per_minute": 0,
			"region_gdp_per_minute": 0,
			"conservation_passed": false,
		}
	var player_rows: Array = []
	var neutral_rows: Array = []
	var player_totals := {}
	var region_total := 0
	var project_total := 0
	var player_total := 0
	var neutral_total := 0
	var explicit_neutral_total := 0
	for row_variant in rows:
		var row: Dictionary = row_variant
		var row_gdp := maxi(0, int(row.get("net_gdp_per_minute", 0)))
		region_total += row_gdp
		if bool(row.get("neutral", false)):
			neutral_total += row_gdp
			explicit_neutral_total += row_gdp
			neutral_rows.append(_neutral_attribution_row(row, row_gdp, "explicit_neutral"))
			continue
		var project_id_value := str(row.get("project_id", ""))
		var project_index := int(project_index_by_id[project_id_value])
		var project: Dictionary = projects[project_index]
		project["current_gdp"] = int(project.get("current_gdp", 0)) + row_gdp
		projects[project_index] = project
		project_total += row_gdp
		var shares: Dictionary = project.get("share_basis_points_by_player", {}) if project.get("share_basis_points_by_player", {}) is Dictionary else {}
		var player_keys: Array = shares.keys()
		player_keys.sort_custom(func(left: Variant, right: Variant) -> bool:
			return int(str(left)) < int(str(right))
		)
		var row_assigned := 0
		for player_key_variant in player_keys:
			var player_key := str(player_key_variant)
			var share_basis_points := clampi(int(shares.get(player_key_variant, 0)), 0, SHARE_BASIS_POINTS)
			var attributable := floori(float(row_gdp * share_basis_points) / float(SHARE_BASIS_POINTS))
			row_assigned += attributable
			player_total += attributable
			player_totals[player_key] = int(player_totals.get(player_key, 0)) + attributable
			player_rows.append({
				"attribution_id": "%s.player.%s" % [str(row.get("receipt_id", "")), player_key],
				"source_receipt_id": str(row.get("receipt_id", "")),
				"region_id": str(row.get("region_id", "")),
				"project_id": project_id_value,
				"project_generation": int(row.get("project_generation", 0)),
				"slot_id": str(row.get("slot_id", "")),
				"product_id": str(row.get("product_id", "")),
				"industry_id": str(row.get("industry_id", "")),
				"direction": str(row.get("direction", "")),
				"source_kind": str(row.get("source_kind", "")),
				"player_index": int(player_key),
				"share_basis_points": share_basis_points,
				"attributable_gdp_per_minute": attributable,
				"rounding_order": player_keys.find(player_key_variant),
				"visibility_scope": "viewer_private",
			})
		var neutral_remainder := maxi(0, row_gdp - row_assigned)
		if neutral_remainder > 0:
			neutral_total += neutral_remainder
			neutral_rows.append(_neutral_attribution_row(row, neutral_remainder, "share_rounding_remainder"))
	for index in range(projects.size()):
		projects[index] = recalculate_shares(projects[index] as Dictionary)
	var project_conservation := project_total + explicit_neutral_total == region_total
	var attribution_conservation := player_total + neutral_total == region_total
	return {
		"valid": project_conservation and attribution_conservation,
		"errors": [],
		"projects": projects,
		"gdp_rows": rows,
		"player_attribution_rows": player_rows,
		"player_gdp_by_index": player_totals,
		"neutral_rows": neutral_rows,
		"project_gdp_per_minute": project_total,
		"explicit_neutral_gdp_per_minute": explicit_neutral_total,
		"player_gdp_per_minute": player_total,
		"neutral_gdp_per_minute": neutral_total,
		"region_gdp_per_minute": region_total,
		"project_conservation_passed": project_conservation,
		"attribution_conservation_passed": attribution_conservation,
		"conservation_passed": project_conservation and attribution_conservation,
	}


static func _neutral_attribution_row(row: Dictionary, amount: int, reason: String) -> Dictionary:
	return {
		"source_receipt_id": str(row.get("receipt_id", "")),
		"region_id": str(row.get("region_id", "")),
		"project_id": str(row.get("project_id", "")),
		"product_id": str(row.get("product_id", "")),
		"industry_id": str(row.get("industry_id", "")),
		"direction": str(row.get("direction", "")),
		"neutral_gdp_per_minute": maxi(0, amount),
		"reason_code": reason,
		"visibility_scope": "public",
	}


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
