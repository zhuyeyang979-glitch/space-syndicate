extends RefCounted
class_name CityProductProjectBridge

const PROJECT_STATE := preload("res://scripts/economy/city_product_project_state.gd")
const V04_MIGRATION := preload("res://scripts/economy/city_project_state_migration_v04_to_v05.gd")


static func normalize_city(city_value: Dictionary, district_index: int, created_order_seed: int = 0, generation_by_slot_id: Dictionary = {}) -> Dictionary:
	var migration: Dictionary = V04_MIGRATION.migrate_city(city_value, district_index, created_order_seed, generation_by_slot_id)
	return (migration.get("city", {}) as Dictionary).duplicate(true) if migration.get("city", {}) is Dictionary else {}


static func resolve_development_slot(city_value: Dictionary, district_index: int, skill: Dictionary, generation_by_slot_id: Dictionary = {}) -> Dictionary:
	var city := normalize_city(city_value, district_index, int(city_value.get("project_sequence", 0)), generation_by_slot_id)
	var product_id := str(skill.get("product_id", skill.get("play_product", ""))).strip_edges()
	var slot_kind := PROJECT_STATE.normalize_direction(str(skill.get("project_direction", "production")))
	var requested_slot_id := str(skill.get("slot_id", "")).strip_edges().to_lower()
	var requested_slot_index := int(skill.get("slot_index", -1))
	var slots: Array = city.get("project_slots", []) if city.get("project_slots", []) is Array else []
	var target_index := -1
	var explicit_request := requested_slot_id != "" or requested_slot_index >= 0
	for index in range(slots.size()):
		var slot: Dictionary = slots[index] if slots[index] is Dictionary else {}
		if str(slot.get("slot_kind", "")) != slot_kind:
			continue
		if requested_slot_id != "" and str(slot.get("slot_id", "")) == requested_slot_id:
			target_index = index
			break
		if requested_slot_id == "" and requested_slot_index >= 0 and int(slot.get("slot_index", -1)) == requested_slot_index:
			target_index = index
			break
	if not explicit_request:
		for index in range(slots.size()):
			var slot: Dictionary = slots[index] if slots[index] is Dictionary else {}
			var active: Dictionary = slot.get("active_project", {}) if slot.get("active_project", {}) is Dictionary else {}
			if str(slot.get("slot_kind", "")) == slot_kind and not active.is_empty() and str(active.get("product_id", "")) == product_id:
				target_index = index
				break
		if target_index < 0:
			for index in range(slots.size()):
				var slot: Dictionary = slots[index] if slots[index] is Dictionary else {}
				if str(slot.get("slot_kind", "")) == slot_kind and bool(slot.get("enabled", true)) and (slot.get("active_project", {}) as Dictionary).is_empty():
					target_index = index
					break
	if target_index < 0 or target_index >= slots.size():
		return {"valid": false, "reason_code": "project_slot_unavailable", "city": city}
	var target_slot: Dictionary = slots[target_index]
	if not bool(target_slot.get("enabled", true)):
		return {"valid": false, "reason_code": "project_slot_disabled", "city": city}
	if str(target_slot.get("slot_kind", "")) != slot_kind:
		return {"valid": false, "reason_code": "project_slot_kind_mismatch", "city": city}
	var active_project: Dictionary = target_slot.get("active_project", {}) if target_slot.get("active_project", {}) is Dictionary else {}
	if explicit_request and not active_project.is_empty() and str(active_project.get("product_id", "")) != product_id:
		return {"valid": false, "reason_code": "project_slot_occupied", "city": city}
	var generation := int(target_slot.get("generation", 0)) if not active_project.is_empty() else int(target_slot.get("generation", 0)) + 1
	var stable_project_id := str(active_project.get("project_id", "")) if not active_project.is_empty() else PROJECT_STATE.project_id(
		district_index,
		slot_kind,
		int(target_slot.get("slot_index", 0)),
		generation,
		str(city.get("region_id", ""))
	)
	return {
		"valid": true,
		"reason_code": "",
		"city": city,
		"slot_array_index": target_index,
		"slot_id": str(target_slot.get("slot_id", "")),
		"slot_kind": slot_kind,
		"slot_index": int(target_slot.get("slot_index", 0)),
		"generation": generation,
		"project_id": stable_project_id,
		"existing_project": not active_project.is_empty(),
	}


static func apply_project_contribution(city_value: Dictionary, district_index: int, player_index: int, skill: Dictionary, contribution_order: int, generation_by_slot_id: Dictionary = {}) -> Dictionary:
	var resolution := resolve_development_slot(city_value, district_index, skill, generation_by_slot_id)
	if not bool(resolution.get("valid", false)):
		return {
			"applied": false,
			"reason_code": str(resolution.get("reason_code", "project_slot_unavailable")),
			"city": (resolution.get("city", city_value) as Dictionary).duplicate(true),
		}
	var city: Dictionary = (resolution.get("city", {}) as Dictionary).duplicate(true)
	var slots: Array = (city.get("project_slots", []) as Array).duplicate(true)
	var target_index := int(resolution.get("slot_array_index", -1))
	var slot: Dictionary = (slots[target_index] as Dictionary).duplicate(true)
	var active: Dictionary = (slot.get("active_project", {}) as Dictionary).duplicate(true) if slot.get("active_project", {}) is Dictionary else {}
	var product_id := str(skill.get("product_id", skill.get("play_product", ""))).strip_edges()
	var units := maxi(1, int(skill.get("contribution_units", 1)))
	var created_project := active.is_empty()
	if created_project:
		active = PROJECT_STATE.create_project(
			district_index,
			product_id,
			str(resolution.get("slot_kind", "production")),
			player_index,
			units,
			contribution_order,
			int(resolution.get("slot_index", 0)),
			int(resolution.get("generation", 1)),
			str(city.get("region_id", ""))
		)
	else:
		active = PROJECT_STATE.contribute(active, player_index, units, contribution_order)
	slot["generation"] = int(active.get("generation", resolution.get("generation", 1)))
	slot["active_project"] = active
	slots[target_index] = slot
	city["project_slots"] = slots
	city["projects"] = active_projects(city)
	city["project_sequence"] = maxi(int(city.get("project_sequence", 0)), contribution_order + 1)
	city = sync_legacy_fields(city)
	return {
		"applied": true,
		"reason_code": "",
		"city": city,
		"project": active.duplicate(true),
		"slot_id": str(slot.get("slot_id", "")),
		"project_id": str(active.get("project_id", "")),
		"generation": int(active.get("generation", 1)),
		"created_project": created_project,
	}


static func tombstone_project(city_value: Dictionary, district_index: int, stable_slot_id: String, reason: String, generation_by_slot_id: Dictionary = {}) -> Dictionary:
	var city := normalize_city(city_value, district_index, int(city_value.get("project_sequence", 0)), generation_by_slot_id)
	var slots: Array = (city.get("project_slots", []) as Array).duplicate(true)
	var tombstones: Array = (city.get("project_tombstones", []) as Array).duplicate(true) if city.get("project_tombstones", []) is Array else []
	for index in range(slots.size()):
		var slot: Dictionary = (slots[index] as Dictionary).duplicate(true)
		if str(slot.get("slot_id", "")) != stable_slot_id:
			continue
		var active: Dictionary = (slot.get("active_project", {}) as Dictionary).duplicate(true) if slot.get("active_project", {}) is Dictionary else {}
		if active.is_empty():
			return {"applied": false, "reason_code": "project_slot_empty", "city": city}
		active["active"] = false
		active["lifecycle_state"] = "tombstoned"
		active["current_gdp"] = 0
		active["tombstone_reason"] = reason.strip_edges()
		tombstones.append(active)
		slot["active_project"] = {}
		slots[index] = slot
		city["project_slots"] = slots
		city["project_tombstones"] = tombstones
		city["projects"] = active_projects(city)
		return {"applied": true, "reason_code": "", "city": city, "tombstone": active, "slot_id": stable_slot_id}
	return {"applied": false, "reason_code": "project_slot_unknown", "city": city}


static func active_projects(city: Dictionary) -> Array:
	var projects: Array = []
	for slot_variant in city.get("project_slots", []):
		if not (slot_variant is Dictionary):
			continue
		var active_variant: Variant = (slot_variant as Dictionary).get("active_project", {})
		if active_variant is Dictionary and not (active_variant as Dictionary).is_empty() and bool((active_variant as Dictionary).get("active", true)):
			projects.append(PROJECT_STATE.normalize_project(active_variant as Dictionary))
	return projects


static func sync_legacy_fields(city_value: Dictionary) -> Dictionary:
	var city := city_value.duplicate(true)
	var products: Array = city.get("products", []) if city.get("products", []) is Array else []
	var demands: Array = city.get("demands", []) if city.get("demands", []) is Array else []
	for project_variant in active_projects(city):
		if not (project_variant is Dictionary):
			continue
		var project: Dictionary = project_variant
		var product_id := str(project.get("product_id", ""))
		match str(project.get("direction", "production")):
			"production":
				var found := false
				for product_variant in products:
					if product_variant is Dictionary and str((product_variant as Dictionary).get("name", "")) == product_id:
						(product_variant as Dictionary)["level"] = maxi(int((product_variant as Dictionary).get("level", 1)), int(project.get("level", 1)))
						found = true
						break
				if not found:
					products.append({"name": product_id, "level": int(project.get("level", 1)), "base_price": 0, "tier": 1})
			"demand":
				if not demands.has(product_id):
					demands.append(product_id)
	city["products"] = products
	city["demands"] = demands
	city["projects"] = active_projects(city)
	return city


static func assign_city_gdp(city_value: Dictionary, city_gdp: int) -> Dictionary:
	var city := city_value.duplicate(true)
	var assigned_projects := PROJECT_STATE.assign_city_gdp(active_projects(city), maxi(0, city_gdp))
	city = _write_projects_to_slots(city, assigned_projects)
	city["project_gdp_by_player"] = PROJECT_STATE.gdp_by_player(assigned_projects)
	return city


static func public_projects(city: Dictionary) -> Array:
	var result: Array = []
	for project_variant in active_projects(city):
		if project_variant is Dictionary:
			result.append(PROJECT_STATE.public_snapshot(project_variant as Dictionary))
	return result


static func private_projects(city: Dictionary, viewer_player_index: int) -> Array:
	var result: Array = []
	for project_variant in active_projects(city):
		if project_variant is Dictionary:
			result.append(PROJECT_STATE.private_snapshot(project_variant as Dictionary, viewer_player_index))
	return result


static func public_slots(city: Dictionary) -> Array:
	var result: Array = []
	for slot_variant in city.get("project_slots", []):
		if not (slot_variant is Dictionary):
			continue
		var slot: Dictionary = slot_variant
		var active: Dictionary = slot.get("active_project", {}) if slot.get("active_project", {}) is Dictionary else {}
		result.append({
			"slot_id": str(slot.get("slot_id", "")),
			"region_id": str(slot.get("region_id", "")),
			"slot_kind": str(slot.get("slot_kind", "")),
			"slot_index": int(slot.get("slot_index", 0)),
			"generation": int(slot.get("generation", 0)),
			"enabled": bool(slot.get("enabled", true)),
			"occupied": not active.is_empty(),
			"project": PROJECT_STATE.public_snapshot(active) if not active.is_empty() else {},
			"visibility_scope": "public",
		})
	return result


static func _write_projects_to_slots(city_value: Dictionary, projects: Array) -> Dictionary:
	var city := city_value.duplicate(true)
	var by_slot := {}
	for project_variant in projects:
		if project_variant is Dictionary:
			by_slot[str((project_variant as Dictionary).get("slot_id", ""))] = (project_variant as Dictionary).duplicate(true)
	var slots: Array = (city.get("project_slots", []) as Array).duplicate(true) if city.get("project_slots", []) is Array else []
	for index in range(slots.size()):
		var slot: Dictionary = (slots[index] as Dictionary).duplicate(true)
		var stable_slot_id := str(slot.get("slot_id", ""))
		slot["active_project"] = (by_slot.get(stable_slot_id, {}) as Dictionary).duplicate(true) if by_slot.get(stable_slot_id, {}) is Dictionary else {}
		slots[index] = slot
	city["project_slots"] = slots
	city["projects"] = projects.duplicate(true)
	return city
