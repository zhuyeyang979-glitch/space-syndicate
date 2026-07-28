@tool
extends RefCounted
class_name CardBatchSubmissionV1

const PURE = preload("res://scripts/semantic/card_batch_pure_data.gd")
const TARGET = preload("res://scripts/semantic/card_batch_prebound_target_spec_v1.gd")

const SCHEMA_VERSION := 1
const SOURCE_POOLS := ["normal_hand", "commodity_inventory", "bound_action_inventory"]
const ACTION_CLASSES := [
	"normal_card", "commodity_card", "proactive_defense", "insurance",
	"batch_interference", "batch_action", "passive_source_ability",
]
const FIELDS: Array[String] = [
	"schema_version", "submission_id", "actor_id", "card_instance_id",
	"card_semantic_id", "action_class", "source_pool", "source_revision",
	"locked_at_window_id", "actor_seat_index", "order_priority",
	"submission_sequence", "target_binding",
]


static func build(
	submission_id: String,
	actor_id: String,
	card_instance_id: String,
	card_semantic_id: String,
	action_class: String,
	source_pool: String,
	source_revision: int,
	actor_seat_index: int,
	order_priority: int,
	submission_sequence: int,
	target_binding: Dictionary,
	locked_at_window_id: String = ""
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"submission_id": submission_id.strip_edges(),
		"actor_id": actor_id.strip_edges(),
		"card_instance_id": card_instance_id.strip_edges(),
		"card_semantic_id": card_semantic_id.strip_edges(),
		"action_class": action_class.strip_edges(),
		"source_pool": source_pool.strip_edges(),
		"source_revision": source_revision,
		"locked_at_window_id": locked_at_window_id.strip_edges(),
		"actor_seat_index": actor_seat_index,
		"order_priority": order_priority,
		"submission_sequence": submission_sequence,
		"target_binding": target_binding.duplicate(true),
	}


static func validate(value: Dictionary, require_locked: bool = false) -> Dictionary:
	if not PURE.has_exact_keys(value, FIELDS) or int(value.get("schema_version", -1)) != SCHEMA_VERSION:
		return _rejected("card_batch_submission_schema_invalid")
	if not PURE.is_pure_json_data(value) or not PURE.first_forbidden_runtime_key(value).is_empty():
		return _rejected("card_batch_submission_not_pure_data")
	if not PURE.first_retired_counter_key(value).is_empty():
		return _rejected("card_batch_submission_retired_counter_payload")
	for id_field in ["submission_id", "actor_id", "card_instance_id", "card_semantic_id"]:
		if str(value.get(id_field, "")).is_empty():
			return _rejected("card_batch_submission_%s_missing" % id_field)
	var action_class := str(value.get("action_class", ""))
	if action_class not in ACTION_CLASSES:
		return _rejected("card_batch_submission_action_class_invalid")
	if str(value.get("source_pool", "")) not in SOURCE_POOLS:
		return _rejected("card_batch_submission_source_pool_invalid")
	var expected_pool: String = str({
		"normal_card": "normal_hand",
		"proactive_defense": "normal_hand",
		"insurance": "normal_hand",
		"batch_interference": "normal_hand",
		"commodity_card": "commodity_inventory",
		"batch_action": "bound_action_inventory",
	}.get(action_class, ""))
	if not expected_pool.is_empty() and str(value.get("source_pool", "")) != expected_pool:
		return _rejected("card_batch_submission_action_pool_mismatch")
	if action_class == "passive_source_ability":
		return _rejected("passive_source_ability_is_not_submittable")
	if action_class == "batch_action" and str(value.get("source_pool", "")) != "bound_action_inventory":
		return _rejected("batch_action_requires_bound_source_pool")
	if int(value.get("source_revision", -1)) < 0 or int(value.get("actor_seat_index", -1)) < 0 or int(value.get("submission_sequence", -1)) < 0:
		return _rejected("card_batch_submission_revision_or_order_invalid")
	if require_locked and str(value.get("locked_at_window_id", "")).is_empty():
		return _rejected("card_batch_submission_not_locked")
	if not (value.get("target_binding") is Dictionary):
		return _rejected("card_batch_submission_target_binding_invalid")
	var target_validation := TARGET.validate(value.get("target_binding", {}))
	if not bool(target_validation.get("valid", false)):
		return _rejected(str(target_validation.get("reason_code", "card_batch_submission_target_binding_invalid")))
	var parameters: Dictionary = (value.get("target_binding", {}) as Dictionary).get("authored_parameters", {})
	if str(parameters.get("timing_class", "")).to_lower() == "counter" or str(parameters.get("action_class", "")).to_lower() == "counter":
		return _rejected("retired_counter_submission_rejected")
	return {"valid": true, "reason_code": "card_batch_submission_valid", "normalized": value.duplicate(true)}


static func locked_copy(value: Dictionary, window_id: String) -> Dictionary:
	if not bool(validate(value, false).get("valid", false)) or window_id.is_empty():
		return {}
	var result := value.duplicate(true)
	result["locked_at_window_id"] = window_id
	return result if bool(validate(result, true).get("valid", false)) else {}


static func stable_order_key(value: Dictionary) -> String:
	var normalized_priority := int(value.get("order_priority", 0)) + 2_147_483_648
	return "%012d|%08d|%s|%s" % [
		normalized_priority,
		int(value.get("actor_seat_index", 0)),
		str(value.get("card_instance_id", "")),
		str(value.get("submission_id", "")),
	]


static func fingerprint(value: Dictionary) -> String:
	return PURE.stable_fingerprint(value) if bool(validate(value).get("valid", false)) else ""


static func _rejected(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code, "normalized": {}}
