@tool
extends Node
class_name CardResolutionHistoryRuntimeService

const DEFAULT_HISTORY_LIMIT := 24
const SAVE_SCHEMA := "v0.6.card-resolution-history.1"

const PUBLIC_ENTRY_FIELDS := [
	"resolution_id",
	"resolved_time",
	"selected_district",
	"selected_trade_product",
	"target_slot",
	"target_player",
	"contract_source_district",
	"contract_target_district",
	"contract_product",
	"group_id",
	"group_order",
	"group_size",
	"group_position",
	"countered",
	"countered_by_resolution_id",
	"aftermath_clue",
	"resolved",
	"resolution_outcome",
]

const FORBIDDEN_PRIVATE_KEYS := {
	"true_owner": true,
	"hidden_owner": true,
	"hidden_owner_id": true,
	"owner_truth": true,
	"ai_plan": true,
	"ai_private_plan": true,
	"ai_reason": true,
	"ai_utility_score": true,
	"route_plan_score": true,
	"pressure_bucket": true,
	"decision_samples": true,
	"learning_bonus": true,
}

const RETIRED_CARD_OWNER_FIELDS := [
	"guessers",
	"public_owner_revealed",
	"public_owner_label",
	"owner_revealed_time",
	"authoritative_actor",
	"hidden_actor",
	"hidden_owner",
	"true_owner",
]

var _history: Array = []
var _appended_resolution_ids: Dictionary = {}
var _history_limit := DEFAULT_HISTORY_LIMIT
var _configured := false
var _revision := 0
var _append_count := 0
var _duplicate_append_count := 0
var _patch_count := 0
var _last_reason := ""


func configure(config: Dictionary = {}) -> void:
	_history_limit = maxi(1, int(config.get("history_limit", DEFAULT_HISTORY_LIMIT)))
	_configured = true
	reset_state()


func reset_state() -> void:
	_history.clear()
	_appended_resolution_ids.clear()
	_revision = 0
	_append_count = 0
	_duplicate_append_count = 0
	_patch_count = 0
	_last_reason = ""


func append_resolved(entry: Dictionary) -> Dictionary:
	if not _configured:
		return _append_rejection("service_not_configured")
	if not _is_data_only(entry):
		return _append_rejection("entry_not_data_only")
	var resolution_id := _entry_id(entry)
	if resolution_id < 0:
		return _append_rejection("resolution_id_missing")
	var id_key := str(resolution_id)
	if _appended_resolution_ids.has(id_key):
		_duplicate_append_count += 1
		_last_reason = "duplicate_resolution"
		return {
			"appended": false,
			"duplicate": true,
			"reason": _last_reason,
			"resolution_id": resolution_id,
			"revision": _revision,
		}
	var stored := entry.duplicate(true)
	_strip_retired_card_owner_fields(stored)
	stored["resolution_id"] = resolution_id
	_history.append(stored)
	_appended_resolution_ids[id_key] = true
	while _history.size() > _history_limit:
		_history.pop_front()
	_revision += 1
	_append_count += 1
	_last_reason = "appended"
	return {
		"appended": true,
		"duplicate": false,
		"reason": _last_reason,
		"resolution_id": resolution_id,
		"history_count": _history.size(),
		"revision": _revision,
	}


func patch_entry(resolution_id: int, patch: Dictionary) -> Dictionary:
	if not _configured:
		return _mutation_rejection("service_not_configured", resolution_id)
	if resolution_id < 0 or patch.is_empty() or not _is_data_only(patch):
		return _mutation_rejection("invalid_patch", resolution_id)
	if patch.has("resolution_id") or patch.has("queued_order") or patch.has("player_index") or _contains_retired_card_owner_field(patch):
		return _mutation_rejection("identity_patch_forbidden", resolution_id)
	var entry_index := _history_index(resolution_id)
	if entry_index < 0:
		return _mutation_rejection("resolution_not_found", resolution_id)
	var before := (_history[entry_index] as Dictionary).duplicate(true)
	var after := before.duplicate(true)
	for key_variant in patch.keys():
		after[key_variant] = _duplicate_data(patch[key_variant])
	if after == before:
		_last_reason = "unchanged"
		return {
			"patched": true,
			"changed": false,
			"reason": _last_reason,
			"resolution_id": resolution_id,
			"revision": _revision,
		}
	_history[entry_index] = after
	_revision += 1
	_patch_count += 1
	_last_reason = "patched"
	return {
		"patched": true,
		"changed": true,
		"reason": _last_reason,
		"resolution_id": resolution_id,
		"revision": _revision,
	}


func history_snapshot() -> Array:
	return _history.duplicate(true)


func entry_by_id(resolution_id: int) -> Dictionary:
	var index := _history_index(resolution_id)
	return (_history[index] as Dictionary).duplicate(true) if index >= 0 else {}


func replace_legacy_entries(entries: Array) -> Dictionary:
	if not _configured:
		return {"applied": false, "reason": "service_not_configured"}
	for entry_variant in entries:
		if not (entry_variant is Dictionary) or not _is_data_only(entry_variant):
			return {"applied": false, "reason": "legacy_history_invalid"}
	reset_state()
	for entry_variant in entries:
		var receipt := append_resolved(entry_variant as Dictionary)
		if not bool(receipt.get("appended", false)):
			return {"applied": false, "reason": str(receipt.get("reason", "legacy_history_append_failed"))}
	return {"applied": true, "history_count": _history.size(), "revision": _revision}


func public_history_snapshot() -> Array:
	var result: Array = []
	for entry_variant in _history:
		if entry_variant is Dictionary:
			result.append(_public_entry(entry_variant as Dictionary))
	return result


func private_viewer_snapshot(_viewer_index: int) -> Array:
	return public_history_snapshot()


func to_save_data() -> Dictionary:
	return {
		"schema": SAVE_SCHEMA,
		"history_limit": _history_limit,
		"history": _history.duplicate(true),
		"appended_resolution_ids": _sorted_resolution_ids(),
		"revision": _revision,
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	if not _configured:
		return {"applied": false, "reason": "service_not_configured", "revision": _revision}
	if not _is_data_only(data):
		return {"applied": false, "reason": "save_not_data_only", "revision": _revision}
	var schema := str(data.get("schema", SAVE_SCHEMA))
	if schema != SAVE_SCHEMA:
		return {"applied": false, "reason": "save_schema_mismatch", "revision": _revision}
	var restored_limit := maxi(1, int(data.get("history_limit", _history_limit)))
	var restored_history_variant: Variant = data.get("history", [])
	var restored_ids_variant: Variant = data.get("appended_resolution_ids", [])
	if not (restored_history_variant is Array) or not (restored_ids_variant is Array):
		return {"applied": false, "reason": "save_shape_invalid", "revision": _revision}
	var restored_history: Array = []
	var restored_ids: Dictionary = {}
	for id_variant in restored_ids_variant as Array:
		var resolution_id := int(id_variant)
		if resolution_id < 0 or restored_ids.has(str(resolution_id)):
			return {"applied": false, "reason": "save_lineage_invalid", "revision": _revision}
		restored_ids[str(resolution_id)] = true
	for entry_variant in restored_history_variant as Array:
		if not (entry_variant is Dictionary):
			return {"applied": false, "reason": "save_entry_invalid", "revision": _revision}
		var entry := (entry_variant as Dictionary).duplicate(true)
		_strip_retired_card_owner_fields(entry)
		var resolution_id := _entry_id(entry)
		if resolution_id < 0 or not restored_ids.has(str(resolution_id)):
			return {"applied": false, "reason": "save_history_lineage_mismatch", "revision": _revision}
		for existing_variant in restored_history:
			if _entry_id(existing_variant as Dictionary) == resolution_id:
				return {"applied": false, "reason": "save_history_duplicate", "revision": _revision}
		entry["resolution_id"] = resolution_id
		restored_history.append(entry)
	while restored_history.size() > restored_limit:
		restored_history.pop_front()
	_history_limit = restored_limit
	_history = restored_history
	_appended_resolution_ids = restored_ids
	_revision = maxi(0, int(data.get("revision", 0)))
	_append_count = 0
	_duplicate_append_count = 0
	_patch_count = 0
	_last_reason = "save_applied"
	return {"applied": true, "reason": _last_reason, "history_count": _history.size(), "revision": _revision}


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"history_authoritative": _configured,
		"history_count": _history.size(),
		"history_limit": _history_limit,
		"lineage_count": _appended_resolution_ids.size(),
		"revision": _revision,
		"append_count": _append_count,
		"duplicate_append_count": _duplicate_append_count,
		"patch_count": _patch_count,
		"public_actor_reveal_count": 0,
		"private_viewer_actor_projection": false,
		"last_reason": _last_reason,
		"selected_resolution_authority": false,
		"queue_authority": false,
		"presentation_authority": false,
	}


func _public_entry(entry: Dictionary) -> Dictionary:
	var skill: Dictionary = entry.get("skill", {}) if entry.get("skill", {}) is Dictionary else {}
	var result := {
		"resolution_id": _entry_id(entry),
		"card_name": str(skill.get("name", entry.get("card_name", ""))),
		"card_kind": str(skill.get("kind", entry.get("card_kind", ""))),
		"skill": {
			"name": str(skill.get("name", entry.get("card_name", ""))),
			"display_name": str(skill.get("display_name", skill.get("name", entry.get("card_name", "")))),
			"kind": str(skill.get("kind", entry.get("card_kind", ""))),
			"rank": maxi(1, int(skill.get("rank", 1))),
		},
		"visibility_scope": "public",
	}
	for field_variant in PUBLIC_ENTRY_FIELDS:
		var field := str(field_variant)
		if field == "resolution_id" or not entry.has(field):
			continue
		result[field] = _sanitize_public_data(entry[field])
	return result


func _sanitize_public_data(value: Variant) -> Variant:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return value
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_sanitize_public_data(item))
		return result
	if value is Dictionary:
		var result := {}
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			if FORBIDDEN_PRIVATE_KEYS.has(key) or key in ["player_index", "slot_index", "cash", "hand", "discard"]:
				continue
			result[key_variant] = _sanitize_public_data((value as Dictionary)[key_variant])
		return result
	return null


func _history_index(resolution_id: int) -> int:
	for index in range(_history.size()):
		if _entry_id(_history[index] as Dictionary) == resolution_id:
			return index
	return -1


func _entry_id(entry: Dictionary) -> int:
	return int(entry.get("resolution_id", entry.get("queued_order", -1))) if not entry.is_empty() else -1


func _sorted_resolution_ids() -> Array:
	var result: Array = []
	for id_key_variant in _appended_resolution_ids.keys():
		result.append(int(id_key_variant))
	result.sort()
	return result


func _append_rejection(reason: String) -> Dictionary:
	_last_reason = reason
	return {"appended": false, "duplicate": false, "reason": reason, "resolution_id": -1, "revision": _revision}


func _mutation_rejection(reason: String, resolution_id: int) -> Dictionary:
	_last_reason = reason
	return {"patched": false, "revealed": false, "changed": false, "reason": reason, "resolution_id": resolution_id, "revision": _revision}


func _strip_retired_card_owner_fields(entry: Dictionary) -> void:
	for key_variant in entry.keys():
		var key := str(key_variant)
		if RETIRED_CARD_OWNER_FIELDS.has(key):
			entry.erase(key_variant)
			continue
		var value: Variant = entry.get(key_variant)
		if value is Dictionary:
			_strip_retired_card_owner_fields(value as Dictionary)
		elif value is Array:
			for child_variant in value as Array:
				if child_variant is Dictionary:
					_strip_retired_card_owner_fields(child_variant as Dictionary)


func _contains_retired_card_owner_field(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if RETIRED_CARD_OWNER_FIELDS.has(str(key_variant)) or _contains_retired_card_owner_field((value as Dictionary)[key_variant]):
				return true
	elif value is Array:
		for child in value:
			if _contains_retired_card_owner_field(child):
				return true
	return false


func _duplicate_data(value: Variant) -> Variant:
	return value.duplicate(true) if value is Array or value is Dictionary else value


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_data_only(item):
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
		return true
	return false
