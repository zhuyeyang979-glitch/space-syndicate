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


func presentation_key_for_card(card_id: String) -> StringName:
	var normalized := card_id.strip_edges()
	var index := rendered_card_ids.find(normalized)
	return StringName(presentation_keys[index]) if index >= 0 and index < presentation_keys.size() else StringName()


func texture_for_key(presentation_key: StringName) -> Texture2D:
	var index := presentation_keys.find(str(presentation_key))
	return rendered_textures[index] if index >= 0 and index < rendered_textures.size() else null


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
	if rendered_card_ids.size() != 5 or _has_duplicates(rendered_card_ids):
		errors.append("rendered_card_ids_invalid")
	if presentation_keys.size() != 5 or _has_duplicates(presentation_keys):
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
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"alpha_count": alpha_card_ids.size(),
		"rendered_count": rendered_card_ids.size(),
		"fallback_count": alpha_card_ids.size() - rendered_card_ids.size(),
	}


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
