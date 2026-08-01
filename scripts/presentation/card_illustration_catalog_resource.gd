@tool
extends Resource
class_name CardIllustrationCatalogResource

@export var schema_version := "alpha01.card_illustration_catalog.v1"
@export var alpha_card_ids: PackedStringArray = []
@export var rendered_card_ids: PackedStringArray = []
@export var presentation_keys: PackedStringArray = []
@export var rendered_textures: Array[Texture2D] = []
@export var fit_modes: PackedStringArray = []
@export var tint_modes: PackedStringArray = []
@export var semantic_motifs: PackedStringArray = []
@export var layout_variants: PackedStringArray = []
@export var texture_filters: PackedStringArray = []
@export var overlay_intensities: PackedFloat32Array = []
@export var source_kinds: PackedStringArray = []
@export_group("Active Commodity Coverage")
@export var active_commodity_ids: PackedStringArray = []
@export var active_commodity_family_ids: PackedStringArray = []
@export var active_commodity_color_ids: PackedStringArray = []
@export var active_commodity_levels: PackedInt32Array = []
@export_group("Stable Presentation Assets")
@export var stable_asset_schema_version := "commercial.presentation_assets.v1"
@export var stable_asset_keys: PackedStringArray = []
@export var stable_asset_resources: Array[Resource] = []
@export var stable_asset_kinds: PackedStringArray = []
@export var stable_asset_scopes: PackedStringArray = []


func presentation_key_for_card(card_id: String) -> StringName:
	var normalized := card_id.strip_edges()
	var index := rendered_card_ids.find(normalized)
	if index < 0:
		var rank_one_id := _active_commodity_rank_one_id(normalized)
		index = rendered_card_ids.find(rank_one_id) if not rank_one_id.is_empty() else -1
	return StringName(presentation_keys[index]) if index >= 0 and index < presentation_keys.size() else StringName()


func presentation_key_for_commodity_id(commodity_id: String) -> StringName:
	var index := active_commodity_ids.find(commodity_id.strip_edges())
	if index < 0 or index >= active_commodity_family_ids.size():
		return StringName()
	return presentation_key_for_card("%s.rank_1" % active_commodity_family_ids[index])


func presentation_key_for_commodity_family(family_id: String) -> StringName:
	var normalized := family_id.strip_edges()
	if not active_commodity_family_ids.has(normalized):
		return StringName()
	return presentation_key_for_card("%s.rank_1" % normalized)


func ranked_active_commodity_card_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for family_id in active_commodity_family_ids:
		for level in active_commodity_levels:
			result.append("%s.rank_%d" % [family_id, level])
	return result


func texture_for_key(presentation_key: StringName) -> Texture2D:
	return resource_for_asset_key(presentation_key) as Texture2D


func resource_for_asset_key(asset_key: StringName) -> Resource:
	var normalized := str(asset_key).strip_edges()
	var stable_index := stable_asset_keys.find(normalized)
	if stable_index >= 0 and stable_index < stable_asset_resources.size():
		return stable_asset_resources[stable_index]
	var illustration_index := presentation_keys.find(normalized)
	return rendered_textures[illustration_index] \
		if illustration_index >= 0 and illustration_index < rendered_textures.size() else null


func asset_kind_for_key(asset_key: StringName) -> StringName:
	var normalized := str(asset_key).strip_edges()
	var stable_index := stable_asset_keys.find(normalized)
	if stable_index >= 0 and stable_index < stable_asset_kinds.size():
		return StringName(stable_asset_kinds[stable_index])
	return &"Texture2D" if presentation_keys.has(normalized) else StringName()


func asset_scope_for_key(asset_key: StringName) -> StringName:
	var normalized := str(asset_key).strip_edges()
	var stable_index := stable_asset_keys.find(normalized)
	if stable_index >= 0 and stable_index < stable_asset_scopes.size():
		return StringName(stable_asset_scopes[stable_index])
	return &"legacy_card_illustration" if presentation_keys.has(normalized) else StringName()


func has_asset_key(asset_key: StringName) -> bool:
	return resource_for_asset_key(asset_key) != null


func all_asset_keys() -> PackedStringArray:
	var result := presentation_keys.duplicate()
	result.append_array(stable_asset_keys)
	return result


func presentation_profile_for_key(presentation_key: StringName) -> Dictionary:
	var index := presentation_keys.find(str(presentation_key))
	if index < 0:
		return {}
	return {
		"fit_mode": _packed_string_at(fit_modes, index, "cover"),
		"tint_mode": _packed_string_at(tint_modes, index, "preserve"),
		"semantic_motif": _packed_string_at(semantic_motifs, index, ""),
		"layout_variant": _packed_string_at(layout_variants, index, "centered_crop_safe"),
		"texture_filter": _packed_string_at(texture_filters, index, "linear"),
		"overlay_intensity": _packed_float_at(overlay_intensities, index, 0.2),
	}


func is_authored_key(presentation_key: StringName) -> bool:
	var index := presentation_keys.find(str(presentation_key))
	return index >= 0 and _packed_string_at(source_kinds, index, "") == "authored"


func validation_report() -> Dictionary:
	var errors: Array[String] = []
	if schema_version != "alpha01.card_illustration_catalog.v1":
		errors.append("schema_version_invalid")
	if alpha_card_ids.size() != 40 or _has_duplicates(alpha_card_ids):
		errors.append("alpha_card_ids_invalid")
	if rendered_card_ids.is_empty() or _has_duplicates(rendered_card_ids):
		errors.append("rendered_card_ids_invalid")
	if presentation_keys.is_empty() or _has_duplicates(presentation_keys):
		errors.append("presentation_keys_invalid")
	var parallel_sizes := [
		presentation_keys.size(), rendered_textures.size(), fit_modes.size(), tint_modes.size(), semantic_motifs.size(),
		layout_variants.size(), texture_filters.size(), overlay_intensities.size(), source_kinds.size(),
	]
	for size_variant in parallel_sizes:
		if int(size_variant) != rendered_card_ids.size():
			errors.append("rendered_parallel_array_size_invalid")
			break
	for index in range(rendered_card_ids.size()):
		var card_id := rendered_card_ids[index]
		if not alpha_card_ids.has(card_id):
			errors.append("rendered_card_not_in_alpha:%s" % card_id)
		if index >= rendered_textures.size() or rendered_textures[index] == null:
			errors.append("rendered_texture_missing:%s" % card_id)
	_validate_active_commodity_coverage(errors)
	_validate_stable_assets(errors)
	var rendered_alpha_count := 0
	for card_id in alpha_card_ids:
		if presentation_key_for_card(card_id) != StringName():
			rendered_alpha_count += 1
	var active_card_ids := ranked_active_commodity_card_ids()
	var active_fallback_count := 0
	var active_keys := {}
	for card_id in active_card_ids:
		var key := presentation_key_for_card(card_id)
		if key == StringName():
			active_fallback_count += 1
		else:
			active_keys[str(key)] = true
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"alpha_count": alpha_card_ids.size(),
		"rendered_count": rendered_alpha_count,
		"fallback_count": alpha_card_ids.size() - rendered_alpha_count,
		"active_commodity_type_count": active_commodity_ids.size(),
		"active_commodity_family_count": active_commodity_family_ids.size(),
		"active_commodity_card_id_count": active_card_ids.size(),
		"active_commodity_unique_art_count": active_keys.size(),
		"active_commodity_fallback_count": active_fallback_count,
		"stable_asset_count": stable_asset_keys.size(),
		"total_asset_key_count": all_asset_keys().size(),
	}


func _validate_stable_assets(errors: Array[String]) -> void:
	if stable_asset_schema_version != "commercial.presentation_assets.v1":
		errors.append("stable_asset_schema_version_invalid")
	if _has_duplicates(stable_asset_keys):
		errors.append("stable_asset_keys_duplicate")
	var stable_sizes := [
		stable_asset_resources.size(), stable_asset_kinds.size(), stable_asset_scopes.size(),
	]
	for size_variant in stable_sizes:
		if int(size_variant) != stable_asset_keys.size():
			errors.append("stable_asset_parallel_array_size_invalid")
			return
	for index in range(stable_asset_keys.size()):
		var asset_key := stable_asset_keys[index].strip_edges()
		var resource := stable_asset_resources[index]
		var kind := stable_asset_kinds[index].strip_edges()
		var scope := stable_asset_scopes[index].strip_edges()
		if asset_key.is_empty() or asset_key != asset_key.to_lower() \
				or asset_key.begins_with("res://") or asset_key.contains("\\") \
				or presentation_keys.has(asset_key):
			errors.append("stable_asset_key_invalid:%s" % asset_key)
		if resource == null:
			errors.append("stable_asset_resource_missing:%s" % asset_key)
		elif not _resource_matches_kind(resource, kind):
			errors.append("stable_asset_kind_mismatch:%s:%s" % [asset_key, kind])
		if not scope.begins_with("production_safe_") and not scope.begins_with("reference_only_"):
			errors.append("stable_asset_scope_invalid:%s:%s" % [asset_key, scope])


func _resource_matches_kind(resource: Resource, kind: String) -> bool:
	match kind:
		"Texture2D":
			return resource is Texture2D
		"PackedScene":
			return resource is PackedScene
		"AudioStream":
			return resource is AudioStream
		"Font":
			return resource is Font
		"Shader":
			return resource is Shader
		"Material":
			return resource is Material
		"Environment":
			return resource is Environment
		"Sky":
			return resource is Sky
		"StyleBox":
			return resource is StyleBox
	return false


func _validate_active_commodity_coverage(errors: Array[String]) -> void:
	if active_commodity_ids.size() != 12 or _has_duplicates(active_commodity_ids):
		errors.append("active_commodity_ids_invalid")
	if active_commodity_family_ids.size() != active_commodity_ids.size() \
			or _has_duplicates(active_commodity_family_ids):
		errors.append("active_commodity_family_ids_invalid")
	if active_commodity_color_ids.size() != active_commodity_ids.size():
		errors.append("active_commodity_color_ids_invalid")
	if active_commodity_levels != PackedInt32Array([1, 2, 3, 4]):
		errors.append("active_commodity_levels_invalid")
	var color_counts := {}
	var commodity_keys := {}
	for index in range(mini(active_commodity_ids.size(), active_commodity_family_ids.size())):
		var commodity_id := active_commodity_ids[index].strip_edges()
		var family_id := active_commodity_family_ids[index].strip_edges()
		var color_id := active_commodity_color_ids[index].strip_edges() \
			if index < active_commodity_color_ids.size() else ""
		if commodity_id.is_empty() or not family_id.begins_with("commodity."):
			errors.append("active_commodity_identity_invalid:%d" % index)
			continue
		if color_id not in ["life", "energy", "industry", "technology", "commerce", "shipping"]:
			errors.append("active_commodity_color_invalid:%s" % family_id)
		else:
			color_counts[color_id] = int(color_counts.get(color_id, 0)) + 1
		var rank_one_id := "%s.rank_1" % family_id
		var rendered_index := rendered_card_ids.find(rank_one_id)
		var key := presentation_key_for_card(rank_one_id)
		if rendered_index < 0 or key == StringName():
			errors.append("active_commodity_rank_one_art_missing:%s" % family_id)
			continue
		if commodity_keys.has(str(key)):
			errors.append("active_commodity_art_reused:%s:%s" % [family_id, str(key)])
		commodity_keys[str(key)] = true
		if rendered_index >= source_kinds.size() or source_kinds[rendered_index] != "authored":
			errors.append("active_commodity_art_not_authored:%s" % family_id)
		if texture_for_key(key) == null:
			errors.append("active_commodity_texture_missing:%s" % family_id)
		for level in active_commodity_levels:
			if presentation_key_for_card("%s.rank_%d" % [family_id, level]) != key:
				errors.append("active_commodity_level_art_mismatch:%s:%d" % [family_id, level])
	for color_id in ["life", "energy", "industry", "technology", "commerce", "shipping"]:
		if int(color_counts.get(color_id, 0)) != 2:
			errors.append("active_commodity_color_count_invalid:%s" % color_id)


func _active_commodity_rank_one_id(card_id: String) -> String:
	var marker_index := card_id.rfind(".rank_")
	if marker_index <= 0:
		return ""
	var family_id := card_id.substr(0, marker_index)
	var level_text := card_id.substr(marker_index + 6)
	if not active_commodity_family_ids.has(family_id) or not level_text.is_valid_int():
		return ""
	var level := int(level_text)
	if not active_commodity_levels.has(level) \
			or card_id != "%s.rank_%d" % [family_id, level]:
		return ""
	return "%s.rank_1" % family_id


func _packed_string_at(values: PackedStringArray, index: int, fallback: String) -> String:
	return values[index] if index >= 0 and index < values.size() else fallback


func _packed_float_at(values: PackedFloat32Array, index: int, fallback: float) -> float:
	return float(values[index]) if index >= 0 and index < values.size() else fallback


func _has_duplicates(values: PackedStringArray) -> bool:
	var seen := {}
	for value in values:
		if seen.has(value):
			return true
		seen[value] = true
	return false
