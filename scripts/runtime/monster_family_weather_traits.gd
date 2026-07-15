@tool
extends Resource
class_name MonsterFamilyWeatherTraits

const ALLOWED_TAGS := [
	"electromagnetic",
	"biological",
	"crystal",
	"cold",
	"energy",
]

@export var catalog_index_to_family_id: PackedStringArray = PackedStringArray()
@export var family_tags_by_id: Dictionary = {}


func family_id_for_catalog_index(catalog_index: int) -> String:
	if catalog_index < 0 or catalog_index >= catalog_index_to_family_id.size():
		return ""
	return str(catalog_index_to_family_id[catalog_index]).strip_edges()


func tags_for_family(family_id: String) -> Array:
	var normalized_id := family_id.strip_edges()
	if normalized_id.is_empty() or not family_tags_by_id.has(normalized_id):
		return []
	var source: Variant = family_tags_by_id.get(normalized_id, [])
	var result: Array = []
	if source is PackedStringArray or source is Array:
		for tag_variant in source:
			var tag := str(tag_variant).strip_edges()
			if ALLOWED_TAGS.has(tag) and not result.has(tag):
				result.append(tag)
	return result


func tags_for_actor(family_id: String, catalog_index: int) -> Array:
	var normalized_id := family_id.strip_edges()
	if normalized_id.is_empty():
		normalized_id = family_id_for_catalog_index(catalog_index)
	return tags_for_family(normalized_id)


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var indexed_families: Dictionary = {}
	for index in range(catalog_index_to_family_id.size()):
		var family_id := family_id_for_catalog_index(index)
		if family_id.is_empty():
			errors.append("catalog_index_%d_family_missing" % index)
			continue
		if indexed_families.has(family_id):
			errors.append("family_%s_catalog_index_duplicate" % family_id)
		indexed_families[family_id] = true
		if not family_tags_by_id.has(family_id):
			errors.append("family_%s_tags_missing" % family_id)
	for family_variant in family_tags_by_id.keys():
		var family_id := str(family_variant).strip_edges()
		if family_id.is_empty():
			errors.append("family_id_empty")
			continue
		if not indexed_families.has(family_id):
			errors.append("family_%s_catalog_index_missing" % family_id)
		var raw_tags: Variant = family_tags_by_id.get(family_variant, [])
		if not (raw_tags is PackedStringArray or raw_tags is Array):
			errors.append("family_%s_tags_invalid" % family_id)
			continue
		if tags_for_family(family_id).is_empty():
			errors.append("family_%s_tags_empty" % family_id)
		for tag_variant in raw_tags:
			var tag := str(tag_variant).strip_edges()
			if not ALLOWED_TAGS.has(tag):
				errors.append("family_%s_tag_%s_invalid" % [family_id, tag])
	return errors
