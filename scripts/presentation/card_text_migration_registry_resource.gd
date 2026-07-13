extends Resource
class_name CardTextMigrationRegistryResource

const PlayerTextSpecScript := preload("res://scripts/presentation/player_text_spec_v05.gd")

const REQUIRED_FIELDS := [
	"legacy_card_id",
	"resource_path",
	"family",
	"rank",
	"rules_text_hash",
	"proposed_stable_id",
	"migration_status",
	"blocking_reason",
	"effect_owner",
	"requirement_owner",
	"terms_owner",
	"parity_evidence",
]

@export var schema_version: String = "v0.5"
@export var source_catalog_path: String = "res://resources/cards/runtime/card_runtime_catalog_v04.tres"
@export var expected_entry_count: int = 239
@export var entries: Array[Dictionary] = []


func validation_snapshot() -> Dictionary:
	var errors: Array[String] = []
	var seen_legacy_ids: Dictionary = {}
	var seen_stable_ids: Dictionary = {}
	var ready_count := 0
	var blocked_count := 0
	var draft_count := 0
	for entry in entries:
		for required_field in REQUIRED_FIELDS:
			if not entry.has(required_field):
				errors.append("field_missing:%s" % required_field)
		var legacy_card_id := str(entry.get("legacy_card_id", ""))
		if legacy_card_id.is_empty() or seen_legacy_ids.has(legacy_card_id):
			errors.append("legacy_card_id_invalid_or_duplicate:%s" % legacy_card_id)
		else:
			seen_legacy_ids[legacy_card_id] = true
		var stable_id := str(entry.get("proposed_stable_id", ""))
		if not stable_id.is_empty():
			if not PlayerTextSpecScript.is_stable_ascii_id(stable_id) or seen_stable_ids.has(stable_id):
				errors.append("stable_id_invalid_or_duplicate:%s" % stable_id)
			else:
				seen_stable_ids[stable_id] = true
		var migration_status := str(entry.get("migration_status", ""))
		match migration_status:
			"release_ready":
				ready_count += 1
				if stable_id.is_empty() or (entry.get("parity_evidence", []) as Array).is_empty():
					errors.append("release_ready_missing_evidence:%s" % legacy_card_id)
			"blocked":
				blocked_count += 1
				if str(entry.get("blocking_reason", "")).strip_edges().is_empty():
					errors.append("blocked_reason_missing:%s" % legacy_card_id)
			"draft":
				draft_count += 1
			_:
				errors.append("migration_status_invalid:%s" % legacy_card_id)
		var rules_hash := str(entry.get("rules_text_hash", ""))
		if rules_hash.length() != 64 or not _is_upper_hex(rules_hash):
			errors.append("rules_text_hash_invalid:%s" % legacy_card_id)
		if not str(entry.get("resource_path", "")).begins_with("res://resources/cards/runtime/families/"):
			errors.append("resource_path_invalid:%s" % legacy_card_id)
		if str(entry.get("effect_owner", "")).is_empty() or str(entry.get("requirement_owner", "")).is_empty() or str(entry.get("terms_owner", "")).is_empty():
			errors.append("owner_metadata_missing:%s" % legacy_card_id)
	if entries.size() != expected_entry_count:
		errors.append("entry_count_mismatch:%d" % entries.size())
	if not PlayerTextSpecScript.is_pure_data(debug_snapshot()):
		errors.append("registry_snapshot_not_pure_data")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"entry_count": entries.size(),
		"release_ready_count": ready_count,
		"blocked_count": blocked_count,
		"draft_count": draft_count,
		"stable_id_count": seen_stable_ids.size(),
	}


func entry_for_legacy_id(legacy_card_id: String) -> Dictionary:
	for entry in entries:
		if str(entry.get("legacy_card_id", "")) == legacy_card_id:
			return entry.duplicate(true)
	return {}


func debug_snapshot() -> Dictionary:
	return {
		"schema_version": schema_version,
		"source_catalog_path": source_catalog_path,
		"expected_entry_count": expected_entry_count,
		"entries": entries.duplicate(true),
	}


func _is_upper_hex(value: String) -> bool:
	for character in value:
		var code := character.unicode_at(0)
		if not (code >= 48 and code <= 57) and not (code >= 65 and code <= 70):
			return false
	return true
