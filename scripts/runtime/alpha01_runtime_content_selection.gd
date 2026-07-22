extends RefCounted
class_name Alpha01RuntimeContentSelection

const SCHEMA_VERSION := "alpha01.runtime_selection.v1"
const EXPECTED_ROLE_COUNT := 8
const EXPECTED_REGION_CARD_COUNT := 28
const EXPECTED_COMMODITY_CARD_COUNT := 12
const EXPECTED_MONSTER_COUNT := 8

var manifest_id := ""
var selection_sha256 := ""
var role_records: Array[Dictionary] = []
var region_supply_card_ids: Array[String] = []
var commodity_track_card_ids: Array[String] = []
var monster_records: Array[Dictionary] = []
var active_map: Dictionary = {}
var recommended_configuration: Dictionary = {}
var errors: Array[String] = []


static func from_dictionary(source: Dictionary) -> Alpha01RuntimeContentSelection:
	var selection := Alpha01RuntimeContentSelection.new()
	selection._apply(source)
	return selection


func is_valid() -> bool:
	return errors.is_empty()


func role_source_indices() -> Array[int]:
	var result: Array[int] = []
	for record in role_records:
		result.append(int(record.get("source_index", -1)))
	return result


func role_names() -> Array[String]:
	return _record_names(role_records)


func monster_source_indices() -> Array[int]:
	var result: Array[int] = []
	for record in monster_records:
		result.append(int(record.get("source_index", -1)))
	return result


func monster_names() -> Array[String]:
	return _record_names(monster_records)


func acquisition_card_ids() -> Array[String]:
	var result := region_supply_card_ids.duplicate()
	result.append_array(commodity_track_card_ids)
	return result


func active_challenge_depth() -> int:
	return int(active_map.get("challenge_depth", 0))


func public_activation_snapshot() -> Dictionary:
	return {
		"manifest_id": manifest_id,
		"selection_sha256": selection_sha256,
		"role_source_indices": role_source_indices(),
		"role_names": role_names(),
		"region_supply_card_ids": region_supply_card_ids.duplicate(),
		"commodity_track_card_ids": commodity_track_card_ids.duplicate(),
		"monster_source_indices": monster_source_indices(),
		"monster_names": monster_names(),
		"active_map": active_map.duplicate(true),
		"counts": {
			"roles": role_records.size(),
			"region_supply": region_supply_card_ids.size(),
			"commodity_track": commodity_track_card_ids.size(),
			"acquisition_total": acquisition_card_ids().size(),
			"monsters": monster_records.size(),
		},
	}


func _apply(source: Dictionary) -> void:
	if str(source.get("schema_version", "")) != SCHEMA_VERSION:
		errors.append("alpha01_runtime_schema_invalid")
	manifest_id = str(source.get("manifest_id", "")).strip_edges()
	selection_sha256 = str(source.get("selection_sha256", "")).strip_edges()
	var recommended := _dictionary(source.get("recommended_configuration", {}))
	recommended_configuration = {
		"player_count": int(recommended.get("player_count", 0)),
		"human_player_count": int(recommended.get("human_player_count", 0)),
		"ai_player_count": int(recommended.get("ai_player_count", 0)),
	}
	role_records = _records(source.get("roles", []), "role")
	monster_records = _records(source.get("monsters", []), "monster")
	var acquisition := _dictionary(source.get("acquisition", {}))
	region_supply_card_ids = _string_array(acquisition.get("region_supply_rank_1_ids", []), "region_supply")
	commodity_track_card_ids = _string_array(acquisition.get("commodity_track_rank_1_ids", []), "commodity_track")
	var map_source := _dictionary(source.get("active_map", {}))
	active_map = {
		"map_id": str(map_source.get("map_id", "")).strip_edges(),
		"challenge_depth": int(map_source.get("challenge_depth", 0)),
		"generator": str(map_source.get("generator", "")).strip_edges(),
		"art_surface": str(map_source.get("art_surface", "")).strip_edges(),
	}
	if manifest_id.is_empty() or selection_sha256.is_empty():
		errors.append("alpha01_runtime_identity_missing")
	if recommended_configuration != {"player_count": 4, "human_player_count": 1, "ai_player_count": 3}:
		errors.append("alpha01_runtime_recommended_configuration_invalid")
	if role_records.size() != EXPECTED_ROLE_COUNT:
		errors.append("alpha01_runtime_role_count_invalid")
	if region_supply_card_ids.size() != EXPECTED_REGION_CARD_COUNT:
		errors.append("alpha01_runtime_region_card_count_invalid")
	if commodity_track_card_ids.size() != EXPECTED_COMMODITY_CARD_COUNT:
		errors.append("alpha01_runtime_commodity_card_count_invalid")
	if monster_records.size() != EXPECTED_MONSTER_COUNT:
		errors.append("alpha01_runtime_monster_count_invalid")
	if str(active_map.get("map_id", "")).is_empty() or active_challenge_depth() != 1:
		errors.append("alpha01_runtime_map_invalid")
	var acquisition_ids := acquisition_card_ids()
	if acquisition_ids.size() != EXPECTED_REGION_CARD_COUNT + EXPECTED_COMMODITY_CARD_COUNT or _has_duplicates(acquisition_ids):
		errors.append("alpha01_runtime_acquisition_identity_invalid")
	for card_id in acquisition_ids:
		if not card_id.ends_with(".rank_1") or card_id.contains(".rank_2") or card_id.contains(".rank_3") or card_id.contains(".rank_4"):
			errors.append("alpha01_runtime_non_rank_one_acquisition:%s" % card_id)
	for card_id in region_supply_card_ids:
		if card_id.begins_with("commodity."):
			errors.append("alpha01_runtime_region_contains_commodity:%s" % card_id)
	for card_id in commodity_track_card_ids:
		if not card_id.begins_with("commodity."):
			errors.append("alpha01_runtime_track_contains_noncommodity:%s" % card_id)


func _records(value: Variant, label: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen_indices: Dictionary = {}
	var seen_names: Dictionary = {}
	if not (value is Array):
		errors.append("alpha01_runtime_%s_records_invalid" % label)
		return result
	for record_variant in value:
		if not (record_variant is Dictionary):
			errors.append("alpha01_runtime_%s_record_invalid" % label)
			continue
		var record := record_variant as Dictionary
		var source_index := int(record.get("source_index", -1))
		var display_name := str(record.get("name", "")).strip_edges()
		if source_index < 0 or display_name.is_empty() or seen_indices.has(source_index) or seen_names.has(display_name):
			errors.append("alpha01_runtime_%s_identity_invalid" % label)
			continue
		seen_indices[source_index] = true
		seen_names[display_name] = true
		result.append({"source_index": source_index, "name": display_name})
	return result


func _string_array(value: Variant, label: String) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		errors.append("alpha01_runtime_%s_ids_invalid" % label)
		return result
	for item_variant in value:
		var item := str(item_variant).strip_edges()
		if item.is_empty():
			errors.append("alpha01_runtime_%s_id_empty" % label)
			continue
		result.append(item)
	if _has_duplicates(result):
		errors.append("alpha01_runtime_%s_ids_duplicate" % label)
	return result


func _record_names(records: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for record in records:
		result.append(str(record.get("name", "")))
	return result


func _has_duplicates(values: Array) -> bool:
	var seen: Dictionary = {}
	for value in values:
		if seen.has(value):
			return true
		seen[value] = true
	return false


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
