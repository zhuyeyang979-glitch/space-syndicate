@tool
extends RefCounted
class_name CardHistoryRestoreDependencyContract

const HISTORY_SAVE_SCHEMA := "v0.6.card-resolution-history.1"
const HISTORY_STATE_KEYS := [
	"schema",
	"history_limit",
	"history",
	"appended_resolution_ids",
	"revision",
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
	"cash": true,
	"hand": true,
	"discard": true,
	"private_hand": true,
	"slot_index": true,
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


static func normalize_history_state(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _rejection("history_state_not_dictionary")
	if not _is_data_only(value):
		return _rejection("history_state_not_data_only")
	var source := value as Dictionary
	if not _has_exact_string_keys(source, HISTORY_STATE_KEYS):
		return _rejection("history_state_shape_invalid")
	if typeof(source.get("schema")) != TYPE_STRING or str(source.get("schema", "")) != HISTORY_SAVE_SCHEMA:
		return _rejection("history_schema_invalid")
	if typeof(source.get("history_limit")) != TYPE_INT or int(source.get("history_limit", 0)) < 1:
		return _rejection("history_limit_invalid")
	if typeof(source.get("revision")) != TYPE_INT or int(source.get("revision", -1)) < 0:
		return _rejection("history_revision_invalid")
	if not (source.get("history") is Array):
		return _rejection("history_array_invalid")
	if not (source.get("appended_resolution_ids") is Array):
		return _rejection("history_lineage_array_invalid")

	var history_limit := int(source.get("history_limit"))
	var normalized_history: Array = []
	var history_ids: Array[int] = []
	var seen_history_ids: Dictionary = {}
	for entry_variant in source.get("history") as Array:
		if not (entry_variant is Dictionary):
			return _rejection("history_entry_invalid")
		var entry := (entry_variant as Dictionary).duplicate(true)
		_strip_retired_fields(entry)
		if _contains_forbidden_private_field(entry):
			return _rejection("history_private_field_forbidden")
		if not entry.has("resolution_id") or typeof(entry.get("resolution_id")) != TYPE_INT:
			return _rejection("history_resolution_id_invalid")
		var resolution_id := int(entry.get("resolution_id"))
		if resolution_id < 0:
			return _rejection("history_resolution_id_invalid")
		if seen_history_ids.has(resolution_id):
			return _rejection("history_duplicate_resolution")
		seen_history_ids[resolution_id] = true
		history_ids.append(resolution_id)
		normalized_history.append(entry)
	if normalized_history.size() > history_limit:
		return _rejection("history_limit_exceeded")

	var lineage: Array[int] = []
	var seen_lineage_ids: Dictionary = {}
	for id_variant in source.get("appended_resolution_ids") as Array:
		if typeof(id_variant) != TYPE_INT or int(id_variant) < 0 or seen_lineage_ids.has(int(id_variant)):
			return _rejection("history_lineage_invalid")
		var resolution_id := int(id_variant)
		seen_lineage_ids[resolution_id] = true
		lineage.append(resolution_id)
	var canonical_lineage: Array[int] = lineage.duplicate()
	canonical_lineage.sort()
	if lineage != canonical_lineage:
		return _rejection("history_lineage_not_canonical")
	var canonical_history_ids: Array[int] = history_ids.duplicate()
	canonical_history_ids.sort()
	if canonical_history_ids != canonical_lineage:
		return _rejection("history_lineage_mismatch")

	return {
		"accepted": true,
		"reason_code": "history_state_valid",
		"normalized_state": {
			"schema": HISTORY_SAVE_SCHEMA,
			"history_limit": history_limit,
			"history": normalized_history,
			"appended_resolution_ids": canonical_lineage,
			"revision": int(source.get("revision")),
		},
	}


static func history_entry_ids(history_state: Dictionary) -> Array[String]:
	var normalized := normalize_history_state(history_state)
	var result: Array[String] = []
	if not bool(normalized.get("accepted", false)):
		return result
	var state: Dictionary = normalized.get("normalized_state", {})
	for entry_variant in state.get("history", []):
		if entry_variant is Dictionary:
			result.append("card-history:%d" % int((entry_variant as Dictionary).get("resolution_id", -1)))
	return result


static func history_fingerprint(history_state: Dictionary) -> String:
	var normalized := normalize_history_state(history_state)
	if not bool(normalized.get("accepted", false)):
		return ""
	return JSON.stringify(_canonicalize(normalized.get("normalized_state", {}))).sha256_text()


static func validate_annotation_dependency(annotation_checkpoint: Dictionary, history_state: Dictionary) -> Dictionary:
	var normalized := normalize_history_state(history_state)
	if not bool(normalized.get("accepted", false)):
		return {
			"accepted": false,
			"reason_code": str(normalized.get("reason_code", "history_state_invalid")),
			"missing_history_entry_ids": [],
		}
	if not _is_data_only(annotation_checkpoint):
		return {"accepted": false, "reason_code": "annotation_checkpoint_not_data_only", "missing_history_entry_ids": []}
	var normalized_history: Dictionary = normalized.get("normalized_state", {}) as Dictionary
	var expected_history_fingerprint := history_fingerprint(normalized_history)
	if annotation_checkpoint.has("history_fingerprint"):
		var fingerprint_variant: Variant = annotation_checkpoint.get("history_fingerprint")
		if typeof(fingerprint_variant) != TYPE_STRING or not _is_canonical_sha256(str(fingerprint_variant)):
			return _annotation_dependency_rejection("annotation_history_fingerprint_invalid")
		if str(fingerprint_variant) != expected_history_fingerprint:
			return _annotation_dependency_rejection("annotation_history_fingerprint_mismatch")
	var rows_variant: Variant = annotation_checkpoint.get("annotations_by_viewer")
	if not (rows_variant is Dictionary):
		return {"accepted": false, "reason_code": "annotation_dependency_shape_invalid", "missing_history_entry_ids": []}
	var available: Dictionary = {}
	var entry_ids := history_entry_ids(normalized_history)
	for entry_id in entry_ids:
		available[entry_id] = true
	var missing: Array[String] = []
	for viewer_key_variant in (rows_variant as Dictionary).keys():
		var viewer_rows_variant: Variant = (rows_variant as Dictionary).get(viewer_key_variant)
		if not (viewer_rows_variant is Dictionary):
			return {"accepted": false, "reason_code": "annotation_dependency_shape_invalid", "missing_history_entry_ids": []}
		for history_id_variant in (viewer_rows_variant as Dictionary).keys():
			if typeof(history_id_variant) != TYPE_STRING or not _valid_history_entry_id(str(history_id_variant)):
				return {"accepted": false, "reason_code": "annotation_history_id_invalid", "missing_history_entry_ids": []}
			var history_id := str(history_id_variant)
			if not available.has(history_id) and not missing.has(history_id):
				missing.append(history_id)
	missing.sort()
	if not missing.is_empty():
		return {"accepted": false, "reason_code": "card_annotation_public_history_missing", "missing_history_entry_ids": missing}
	return {
		"accepted": true,
		"reason_code": "annotation_dependency_valid",
		"missing_history_entry_ids": [],
		"history_entry_ids": entry_ids,
		"history_fingerprint": expected_history_fingerprint,
	}


static func _rejection(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code, "normalized_state": {}}


static func _annotation_dependency_rejection(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code, "missing_history_entry_ids": []}


static func _has_exact_string_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in value.keys():
		if typeof(key_variant) != TYPE_STRING or not expected.has(str(key_variant)):
			return false
	return true


static func _strip_retired_fields(value: Variant) -> void:
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			if RETIRED_CARD_OWNER_FIELDS.has(str(key_variant).to_lower()):
				dictionary.erase(key_variant)
				continue
			_strip_retired_fields(dictionary.get(key_variant))
	elif value is Array:
		for child in value as Array:
			_strip_retired_fields(child)


static func _contains_forbidden_private_field(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if FORBIDDEN_PRIVATE_KEYS.has(str(key_variant).to_lower()) or _contains_forbidden_private_field((value as Dictionary).get(key_variant)):
				return true
	elif value is Array:
		for child in value as Array:
			if _contains_forbidden_private_field(child):
				return true
	return false


static func _valid_history_entry_id(value: String) -> bool:
	if not value.begins_with("card-history:"):
		return false
	var suffix := value.trim_prefix("card-history:")
	return suffix.is_valid_int() and int(suffix) >= 0 and suffix == str(int(suffix))


static func _is_canonical_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in value.length():
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return false
	return true


static func _is_data_only(value: Variant) -> bool:
	if value is Callable or value is Object:
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if typeof(key_variant) != TYPE_STRING or not _is_data_only((value as Dictionary).get(key_variant)):
				return false
		return true
	if value is Array:
		for child in value as Array:
			if not _is_data_only(child):
				return false
		return true
	if typeof(value) == TYPE_FLOAT:
		return is_finite(float(value))
	return typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING]


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var keys: Array = (value as Dictionary).keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return _canonical_key(left) < _canonical_key(right))
		var entries: Array = []
		for key_variant in keys:
			entries.append({"key": _canonical_key(key_variant), "value": _canonicalize((value as Dictionary).get(key_variant))})
		return {"@type": "Dictionary", "entries": entries}
	if value is Array:
		var result: Array = []
		for child in value as Array:
			result.append(_canonicalize(child))
		return result
	if value is StringName:
		return {"@type": "StringName", "value": str(value)}
	return value


static func _canonical_key(value: Variant) -> String:
	match typeof(value):
		TYPE_STRING:
			return "string:%s" % str(value)
		TYPE_STRING_NAME:
			return "string_name:%s" % str(value)
		TYPE_INT:
			return "int:%d" % int(value)
		TYPE_FLOAT:
			return "float:%s" % String.num(float(value), 17)
		TYPE_BOOL:
			return "bool:%s" % str(value)
		TYPE_NIL:
			return "nil"
	return "variant:%s" % str(value)
