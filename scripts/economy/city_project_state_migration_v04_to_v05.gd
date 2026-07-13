extends RefCounted
class_name CityProjectStateMigrationV04ToV05

const PROJECT_STATE := preload("res://scripts/economy/city_product_project_state.gd")


static func migrate_city(city_value: Dictionary, district_index: int, created_order_seed: int = 0, generation_by_slot_id: Dictionary = {}) -> Dictionary:
	var city := city_value.duplicate(true)
	if city.is_empty():
		return {"city": {}, "migrated_project_count": 0, "issues": [], "legacy_owner_ignored": false}
	var stable_region_id := PROJECT_STATE.region_id(district_index, str(city.get("region_id", "")))
	var slots := PROJECT_STATE.create_project_slots(district_index, stable_region_id, city.get("enabled_project_slot_counts", {}) as Dictionary if city.get("enabled_project_slot_counts", {}) is Dictionary else {})
	var slot_lookup := _slot_lookup(slots)
	var issues: Array = []
	var migrated_count := 0
	var existing_slots_variant: Variant = city.get("project_slots", [])
	var has_canonical_slots := existing_slots_variant is Array and not (existing_slots_variant as Array).is_empty()
	if has_canonical_slots:
		for slot_variant in existing_slots_variant as Array:
			if not (slot_variant is Dictionary):
				continue
			var source_slot: Dictionary = slot_variant
			var kind := PROJECT_STATE.normalize_direction(str(source_slot.get("slot_kind", "production")))
			var slot_index := int(source_slot.get("slot_index", -1))
			if not PROJECT_STATE.slot_is_valid(kind, slot_index):
				issues.append({"reason_code": "invalid_slot_coordinates", "slot_kind": kind, "slot_index": slot_index})
				continue
			var stable_slot_id := PROJECT_STATE.slot_id(district_index, kind, slot_index, stable_region_id)
			var canonical_index := int(slot_lookup.get(stable_slot_id, -1))
			if canonical_index < 0:
				continue
			var normalized := PROJECT_STATE.normalize_slot(source_slot, district_index, kind, slot_index, stable_region_id)
			normalized["generation"] = maxi(int(normalized.get("generation", 0)), int(generation_by_slot_id.get(stable_slot_id, 0)))
			var active_variant: Variant = normalized.get("active_project", {})
			if active_variant is Dictionary and not (active_variant as Dictionary).is_empty():
				var project := PROJECT_STATE.normalize_project(active_variant as Dictionary, district_index, kind, slot_index, maxi(1, int(normalized["generation"])), stable_region_id)
				normalized["active_project"] = project
				normalized["generation"] = int(project.get("generation", 1))
			slots[canonical_index] = normalized
	else:
		var source_projects: Array = city.get("projects", []) if city.get("projects", []) is Array else []
		for project_variant in source_projects:
			if not (project_variant is Dictionary):
				continue
			var source_project: Dictionary = project_variant
			var kind := PROJECT_STATE.normalize_direction(str(source_project.get("slot_kind", source_project.get("direction", "production"))))
			var requested_index := int(source_project.get("slot_index", -1))
			var target_index := _first_available_slot_index(slots, kind, requested_index)
			if target_index < 0:
				issues.append({
					"reason_code": "legacy_project_slot_overflow",
					"product_id": str(source_project.get("product_id", "")),
					"slot_kind": kind,
				})
				continue
			var slot: Dictionary = slots[target_index]
			var stable_slot_id := str(slot.get("slot_id", ""))
			var generation := maxi(1, int(source_project.get("generation", generation_by_slot_id.get(stable_slot_id, 1))))
			var project := PROJECT_STATE.normalize_project(source_project, district_index, kind, int(slot.get("slot_index", 0)), generation, stable_region_id)
			slot["generation"] = generation
			slot["active_project"] = project
			slots[target_index] = slot
			migrated_count += 1
	var tombstones: Array = []
	var tombstone_variant: Variant = city.get("project_tombstones", [])
	if tombstone_variant is Array:
		for entry_variant in tombstone_variant as Array:
			if not (entry_variant is Dictionary):
				continue
			var entry: Dictionary = entry_variant
			var kind := PROJECT_STATE.normalize_direction(str(entry.get("slot_kind", entry.get("direction", "production"))))
			var slot_index := clampi(int(entry.get("slot_index", 0)), 0, maxi(0, PROJECT_STATE.slot_count(kind) - 1))
			var generation := maxi(1, int(entry.get("generation", 1)))
			var tombstone := PROJECT_STATE.normalize_project(entry, district_index, kind, slot_index, generation, stable_region_id)
			tombstone["active"] = false
			tombstone["lifecycle_state"] = "tombstoned"
			tombstone["current_gdp"] = 0
			tombstones.append(tombstone)
	city["project_schema_version"] = PROJECT_STATE.PROJECT_SCHEMA_VERSION
	city["region_id"] = stable_region_id
	city["project_slots"] = slots
	city["project_tombstones"] = tombstones
	city["projects"] = _active_projects(slots)
	city["project_sequence"] = maxi(0, int(city.get("project_sequence", created_order_seed)))
	city["project_migration_issues"] = issues
	city["legacy_owner_is_project_authority"] = false
	return {
		"city": city,
		"migrated_project_count": migrated_count,
		"issues": issues,
		"legacy_owner_ignored": city.has("owner"),
	}


static func _slot_lookup(slots: Array) -> Dictionary:
	var result := {}
	for index in range(slots.size()):
		if slots[index] is Dictionary:
			result[str((slots[index] as Dictionary).get("slot_id", ""))] = index
	return result


static func _first_available_slot_index(slots: Array, slot_kind: String, requested_index: int) -> int:
	if PROJECT_STATE.slot_is_valid(slot_kind, requested_index):
		for index in range(slots.size()):
			var slot: Dictionary = slots[index] if slots[index] is Dictionary else {}
			if str(slot.get("slot_kind", "")) == slot_kind and int(slot.get("slot_index", -1)) == requested_index and (slot.get("active_project", {}) as Dictionary).is_empty():
				return index
	for index in range(slots.size()):
		var slot: Dictionary = slots[index] if slots[index] is Dictionary else {}
		if str(slot.get("slot_kind", "")) == slot_kind and (slot.get("active_project", {}) as Dictionary).is_empty():
			return index
	return -1


static func _active_projects(slots: Array) -> Array:
	var result: Array = []
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var active_variant: Variant = (slot_variant as Dictionary).get("active_project", {})
		if active_variant is Dictionary and not (active_variant as Dictionary).is_empty() and bool((active_variant as Dictionary).get("active", true)):
			result.append((active_variant as Dictionary).duplicate(true))
	return result
