@tool
extends RefCounted
class_name CardResolutionStateV1

const PURE = preload("res://scripts/semantic/card_batch_pure_data.gd")

const SCHEMA_VERSION := 1
const PHASES := ["CARD_RESOLUTION_ACTIVE", "CARD_EFFECT_COMMIT", "CARD_AFTERMATH"]
const OUTCOMES := ["", "COMMITTED", "FIZZLE_NO_EFFECT", "COMMIT_LEGAL_REMAINDER", "REFUND_BY_AUTHORED_RULE"]
const FIELDS: Array[String] = [
	"schema_version", "resolution_id", "batch_id", "window_id",
	"resolution_index", "submission_id", "phase",
	"prebound_target_fingerprint", "target_validation_result",
	"applied_defense_status_ids", "outcome",
	"authoritative_effect_receipt_id", "aftermath_complete",
]


static func build(
	batch_id: String,
	window_id: String,
	resolution_index: int,
	submission: Dictionary,
	phase: String,
	outcome: String = "",
	authoritative_effect_receipt_id: String = "",
	target_validation_result: String = "",
	applied_defense_status_ids: Array = [],
	aftermath_complete: bool = false
) -> Dictionary:
	var submission_id := str(submission.get("submission_id", ""))
	return {
		"schema_version": SCHEMA_VERSION,
		"resolution_id": "%s:%06d:%s" % [batch_id, resolution_index, submission_id],
		"batch_id": batch_id,
		"window_id": window_id,
		"resolution_index": resolution_index,
		"submission_id": submission_id,
		"phase": phase,
		"prebound_target_fingerprint": PURE.stable_fingerprint(submission.get("target_binding", {})),
		"target_validation_result": target_validation_result,
		"applied_defense_status_ids": PURE.string_array(applied_defense_status_ids, true),
		"outcome": outcome,
		"authoritative_effect_receipt_id": authoritative_effect_receipt_id,
		"aftermath_complete": aftermath_complete,
	}


static func validate(value: Dictionary) -> Dictionary:
	if not PURE.has_exact_keys(value, FIELDS) or int(value.get("schema_version", -1)) != SCHEMA_VERSION:
		return _rejected("card_resolution_state_schema_invalid")
	if not PURE.is_pure_json_data(value) or not PURE.first_retired_counter_key(value).is_empty():
		return _rejected("card_resolution_state_not_pure_data")
	for field in ["resolution_id", "batch_id", "window_id", "submission_id", "prebound_target_fingerprint"]:
		if str(value.get(field, "")).is_empty():
			return _rejected("card_resolution_state_%s_missing" % field)
	if int(value.get("resolution_index", -1)) < 0 or str(value.get("phase", "")) not in PHASES or str(value.get("outcome", "")) not in OUTCOMES:
		return _rejected("card_resolution_state_phase_or_outcome_invalid")
	if str(value.get("prebound_target_fingerprint", "")).length() != 64:
		return _rejected("card_resolution_state_target_fingerprint_invalid")
	var applied_ids_variant: Variant = value.get("applied_defense_status_ids")
	if not (applied_ids_variant is Array) \
			or PURE.string_array(applied_ids_variant, true).size() != (applied_ids_variant as Array).size():
		return _rejected("card_resolution_state_defense_ids_invalid")
	if str(value.get("phase", "")) == "CARD_AFTERMATH" and (str(value.get("outcome", "")).is_empty() \
			or str(value.get("authoritative_effect_receipt_id", "")).is_empty() \
			or str(value.get("target_validation_result", "")).is_empty()):
		return _rejected("card_resolution_state_aftermath_receipt_missing")
	if str(value.get("phase", "")) != "CARD_AFTERMATH" and (not str(value.get("outcome", "")).is_empty() \
			or not str(value.get("authoritative_effect_receipt_id", "")).is_empty() \
			or not str(value.get("target_validation_result", "")).is_empty() \
			or not (value.get("applied_defense_status_ids", []) as Array).is_empty() \
			or bool(value.get("aftermath_complete", false))):
		return _rejected("card_resolution_state_premature_outcome")
	return {"valid": true, "reason_code": "card_resolution_state_valid", "normalized": value.duplicate(true)}


static func _rejected(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code, "normalized": {}}
