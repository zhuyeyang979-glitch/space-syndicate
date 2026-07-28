@tool
extends RefCounted
class_name CardBatchSaveCodecV1

const PURE = preload("res://scripts/semantic/card_batch_pure_data.gd")
const STATE = preload("res://scripts/semantic/card_batch_state_v1.gd")

const SCHEMA_VERSION := 1
const ROOT_FIELDS: Array[String] = ["schema_version", "ruleset_id", "card_batch_state"]


static func capture(state: Dictionary) -> Dictionary:
	var validation := STATE.validate(state)
	if not bool(validation.get("valid", false)):
		return {"captured": false, "reason_code": str(validation.get("reason_code", "card_batch_state_invalid")), "save_data": {}}
	var save_data := {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": STATE.RULESET_ID,
		"card_batch_state": (validation.get("normalized", {}) as Dictionary).duplicate(true),
	}
	return {
		"captured": true,
		"reason_code": "card_batch_save_captured",
		"save_data": save_data,
		"fingerprint": PURE.stable_fingerprint(save_data),
	}


static func preflight(save_data: Dictionary) -> Dictionary:
	if not PURE.has_exact_keys(save_data, ROOT_FIELDS) or int(save_data.get("schema_version", -1)) != SCHEMA_VERSION:
		return _rejected("card_batch_save_schema_invalid")
	if str(save_data.get("ruleset_id", "")) != STATE.RULESET_ID or not PURE.is_pure_json_data(save_data):
		return _rejected("card_batch_save_ruleset_or_data_invalid")
	var retired_path := PURE.first_retired_counter_key(save_data)
	if not retired_path.is_empty():
		return _rejected("card_batch_save_retired_counter_payload:%s" % retired_path)
	if not (save_data.get("card_batch_state") is Dictionary):
		return _rejected("card_batch_save_state_missing")
	var validation := STATE.validate(save_data.get("card_batch_state", {}))
	if not bool(validation.get("valid", false)):
		return _rejected(str(validation.get("reason_code", "card_batch_save_state_invalid")))
	var normalized := {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": STATE.RULESET_ID,
		"card_batch_state": (validation.get("normalized", {}) as Dictionary).duplicate(true),
	}
	return {
		"accepted": true,
		"reason_code": "card_batch_save_valid",
		"normalized": normalized,
		"fingerprint": PURE.stable_fingerprint(normalized),
	}


static func stable_roundtrip(save_data: Dictionary) -> Dictionary:
	var preflight_result := preflight(save_data)
	if not bool(preflight_result.get("accepted", false)):
		return {"roundtrip": false, "reason_code": str(preflight_result.get("reason_code", "card_batch_save_invalid")), "restored_state": {}}
	var serialized := PURE.stable_serialize(preflight_result.get("normalized", {}))
	var parsed: Variant = JSON.parse_string(serialized)
	if not (parsed is Dictionary):
		return {"roundtrip": false, "reason_code": "card_batch_save_json_roundtrip_failed", "restored_state": {}}
	var restored_preflight := preflight(parsed as Dictionary)
	if not bool(restored_preflight.get("accepted", false)):
		return {"roundtrip": false, "reason_code": str(restored_preflight.get("reason_code", "card_batch_save_restore_invalid")), "restored_state": {}}
	return {
		"roundtrip": true,
		"reason_code": "card_batch_save_roundtrip_stable",
		"restored_state": ((restored_preflight.get("normalized", {}) as Dictionary).get("card_batch_state", {}) as Dictionary).duplicate(true),
		"fingerprint": PURE.stable_fingerprint(restored_preflight.get("normalized", {})),
	}


static func _rejected(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code, "normalized": {}, "fingerprint": ""}
