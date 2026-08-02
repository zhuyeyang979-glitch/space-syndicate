extends RefCounted
class_name VictoryControlSaveWireCodecV3

const CLOSED_SCALAR_CODEC := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")
const PLAYER_INDEX_MAP := preload("res://scripts/runtime/canonical_player_index_map_v1.gd")
const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

const SAVE_SCHEMA_VERSION := 3
const MAX_PLAYER_COUNT := PLAYER_INDEX_MAP.MAX_ACTIVE_PLAYER_COUNT
const ROOT_FIELDS := ["victory_control_runtime"]
const PAYLOAD_FIELDS := [
	"schema_version",
	"ruleset_id",
	"state",
	"qualification_elapsed_by_player",
	"audit_roster",
	"audit_remaining_seconds",
	"outcome_sequence",
	"outcome_receipt",
]


static func encode_save_state(runtime_state: Dictionary) -> Dictionary:
	if not _has_exact_keys(runtime_state, ROOT_FIELDS) \
			or not (runtime_state.get("victory_control_runtime") is Dictionary):
		return _failure("victory_save_v3_runtime_shape_invalid")
	var payload := runtime_state.get("victory_control_runtime") as Dictionary
	if not _has_exact_keys(payload, PAYLOAD_FIELDS) \
			or not (payload.get("schema_version") is int) \
			or int(payload.get("schema_version", 0)) != SAVE_SCHEMA_VERSION \
			or not (payload.get("ruleset_id") is String) \
			or not (payload.get("state") is String) \
			or not (payload.get("audit_roster") is Array) \
			or not (payload.get("outcome_sequence") is int) \
			or not (payload.get("outcome_receipt") is Dictionary):
		return _failure("victory_save_v3_runtime_shape_invalid")
	var qualification := _encode_qualification(payload.get("qualification_elapsed_by_player"))
	if not bool(qualification.get("ok", false)):
		return qualification
	var audit_remaining := CLOSED_SCALAR_CODEC.encode_f64(payload.get("audit_remaining_seconds"))
	if not bool(audit_remaining.get("ok", false)):
		return _failure(str(audit_remaining.get("reason_code", "victory_audit_remaining_wire_invalid")))
	if _contains_reserved_codec_key(payload.get("outcome_receipt")):
		return _failure("victory_outcome_receipt_reserved_codec_key_collision")
	var outcome_receipt := CLOSED_SCALAR_CODEC.encode_tree(payload.get("outcome_receipt"))
	if not bool(outcome_receipt.get("ok", false)) or not (outcome_receipt.get("value") is Dictionary):
		return _failure(str(outcome_receipt.get("reason_code", "victory_outcome_receipt_wire_invalid")))
	var wire := {
		"victory_control_runtime": {
			"schema_version": SAVE_SCHEMA_VERSION,
			"ruleset_id": str(payload.get("ruleset_id", "")),
			"state": str(payload.get("state", "")),
			"qualification_elapsed_by_player": (qualification.get("value", {}) as Dictionary).duplicate(true),
			"audit_roster": (payload.get("audit_roster", []) as Array).duplicate(true),
			"audit_remaining_seconds": (audit_remaining.get("value", {}) as Dictionary).duplicate(true),
			"outcome_sequence": int(payload.get("outcome_sequence", 0)),
			"outcome_receipt": (outcome_receipt.get("value", {}) as Dictionary).duplicate(true),
		},
	}
	if not SEMANTIC_WIRE.is_closed_data(wire):
		return _failure("victory_save_v3_wire_not_closed")
	return {"ok": true, "value": wire}


static func decode_save_state(wire_state: Dictionary) -> Dictionary:
	if not SEMANTIC_WIRE.is_closed_data(wire_state) \
			or not _has_exact_keys(wire_state, ROOT_FIELDS) \
			or not (wire_state.get("victory_control_runtime") is Dictionary):
		return _failure("victory_save_v3_wire_invalid")
	var payload := wire_state.get("victory_control_runtime") as Dictionary
	if not _has_exact_keys(payload, PAYLOAD_FIELDS) \
			or not (payload.get("schema_version") is int) \
			or int(payload.get("schema_version", 0)) != SAVE_SCHEMA_VERSION \
			or not (payload.get("ruleset_id") is String) \
			or not (payload.get("state") is String) \
			or not (payload.get("audit_roster") is Array) \
			or not (payload.get("outcome_sequence") is int) \
			or not (payload.get("outcome_receipt") is Dictionary):
		return _failure("victory_save_v3_wire_invalid")
	var qualification := _decode_qualification(payload.get("qualification_elapsed_by_player"))
	if not bool(qualification.get("ok", false)):
		return qualification
	var audit_remaining := CLOSED_SCALAR_CODEC.decode_f64(payload.get("audit_remaining_seconds"))
	if not bool(audit_remaining.get("ok", false)):
		return _failure(str(audit_remaining.get("reason_code", "victory_audit_remaining_wire_invalid")))
	if _wire_has_unknown_codec(payload.get("outcome_receipt")):
		return _failure("victory_outcome_receipt_unknown_codec")
	var outcome_receipt := CLOSED_SCALAR_CODEC.decode_tree(payload.get("outcome_receipt"))
	if not bool(outcome_receipt.get("ok", false)) or not (outcome_receipt.get("value") is Dictionary):
		return _failure(str(outcome_receipt.get("reason_code", "victory_outcome_receipt_wire_invalid")))
	var runtime := {
		"victory_control_runtime": {
			"schema_version": SAVE_SCHEMA_VERSION,
			"ruleset_id": str(payload.get("ruleset_id", "")),
			"state": str(payload.get("state", "")),
			"qualification_elapsed_by_player": (qualification.get("value", {}) as Dictionary).duplicate(true),
			"audit_roster": (payload.get("audit_roster", []) as Array).duplicate(true),
			"audit_remaining_seconds": float(audit_remaining.get("value", 0.0)),
			"outcome_sequence": int(payload.get("outcome_sequence", 0)),
			"outcome_receipt": (outcome_receipt.get("value", {}) as Dictionary).duplicate(true),
		},
	}
	var canonical := encode_save_state(runtime)
	if not bool(canonical.get("ok", false)) or canonical.get("value") != wire_state:
		return _failure("victory_save_v3_wire_noncanonical")
	return {"ok": true, "value": runtime}


static func _encode_qualification(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _failure("victory_qualification_wire_invalid")
	var entries: Dictionary = {}
	for key_variant in (value as Dictionary).keys():
		if not (key_variant is String):
			return _failure("player_index_key_invalid")
		var encoded_elapsed := CLOSED_SCALAR_CODEC.encode_f64((value as Dictionary).get(key_variant))
		if not bool(encoded_elapsed.get("ok", false)):
			return _failure("victory_qualification_elapsed_wire_invalid")
		entries[str(key_variant)] = (encoded_elapsed.get("value", {}) as Dictionary).duplicate(true)
	var validation := PLAYER_INDEX_MAP.decode(_player_map_wire(entries), MAX_PLAYER_COUNT)
	if not bool(validation.get("ok", false)):
		return _failure(str(validation.get("reason_code", "victory_qualification_wire_invalid")))
	var normalized_wire := validation.get("normalized_wire", {}) as Dictionary
	var normalized_entries := normalized_wire.get("entries", {}) as Dictionary
	if normalized_entries != entries:
		return _failure("victory_qualification_wire_noncanonical")
	return {"ok": true, "value": normalized_entries.duplicate(true)}


static func _decode_qualification(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _failure("victory_qualification_wire_invalid")
	var entries := value as Dictionary
	var validation := PLAYER_INDEX_MAP.decode(_player_map_wire(entries), MAX_PLAYER_COUNT)
	if not bool(validation.get("ok", false)):
		return _failure(str(validation.get("reason_code", "victory_qualification_wire_invalid")))
	var decoded_by_index := validation.get("value", {}) as Dictionary
	var indices: Array[int] = []
	for index_variant in decoded_by_index.keys():
		indices.append(int(index_variant))
	indices.sort()
	var runtime: Dictionary = {}
	for index in indices:
		var decoded_elapsed := CLOSED_SCALAR_CODEC.decode_f64(decoded_by_index.get(index))
		if not bool(decoded_elapsed.get("ok", false)):
			return _failure("victory_qualification_elapsed_wire_invalid")
		runtime[str(index)] = float(decoded_elapsed.get("value", 0.0))
	var canonical := _encode_qualification(runtime)
	if not bool(canonical.get("ok", false)) or canonical.get("value") != entries:
		return _failure("victory_qualification_wire_noncanonical")
	return {"ok": true, "value": runtime}


static func _player_map_wire(entries: Dictionary) -> Dictionary:
	return {
		"schema_version": PLAYER_INDEX_MAP.SCHEMA_VERSION,
		"key_codec": PLAYER_INDEX_MAP.KEY_CODEC_ID,
		"entries": entries.duplicate(true),
	}


static func _contains_reserved_codec_key(value: Variant) -> bool:
	if value is Dictionary:
		var dictionary := value as Dictionary
		if dictionary.has("codec") or dictionary.has(CLOSED_SCALAR_CODEC.INT64_CODEC_KEY):
			return true
		for child in dictionary.values():
			if _contains_reserved_codec_key(child):
				return true
	elif value is Array:
		for child in value as Array:
			if _contains_reserved_codec_key(child):
				return true
	return false


static func _wire_has_unknown_codec(value: Variant) -> bool:
	if value is Dictionary:
		var dictionary := value as Dictionary
		if dictionary.has("codec"):
			return str(dictionary.get("codec", "")) != CLOSED_SCALAR_CODEC.F64_CODEC_ID \
					or not bool(CLOSED_SCALAR_CODEC.decode_f64(dictionary).get("ok", false))
		if dictionary.has(CLOSED_SCALAR_CODEC.INT64_CODEC_KEY):
			return str(dictionary.get(CLOSED_SCALAR_CODEC.INT64_CODEC_KEY, "")) != CLOSED_SCALAR_CODEC.INT64_CODEC_ID \
					or not bool(CLOSED_SCALAR_CODEC.decode_tree(dictionary).get("ok", false))
		for child in dictionary.values():
			if _wire_has_unknown_codec(child):
				return true
	elif value is Array:
		for child in value as Array:
			if _wire_has_unknown_codec(child):
				return true
	return false


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in expected:
		if not value.has(str(key_variant)):
			return false
	return true


static func _failure(reason_code: String) -> Dictionary:
	return {"ok": false, "reason_code": reason_code}
