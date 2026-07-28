@tool
extends RefCounted
class_name CardBatchAuthoredRuleV1

const PURE = preload("res://scripts/semantic/card_batch_pure_data.gd")
const SUBMISSION = preload("res://scripts/semantic/card_batch_submission_v1.gd")
const TARGET = preload("res://scripts/semantic/card_batch_prebound_target_spec_v1.gd")

const SCHEMA_VERSION := 1
const FIELDS: Array[String] = [
	"schema_version", "card_semantic_id", "action_class", "source_pool",
	"order_priority", "target_kind", "target_invalidation_policy",
	"authored_parameters",
]


static func build(
	card_semantic_id: String,
	action_class: String,
	source_pool: String,
	order_priority: int,
	target_kind: String,
	target_invalidation_policy: String,
	authored_parameters: Dictionary
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"card_semantic_id": card_semantic_id.strip_edges(),
		"action_class": action_class.strip_edges(),
		"source_pool": source_pool.strip_edges(),
		"order_priority": order_priority,
		"target_kind": target_kind.strip_edges(),
		"target_invalidation_policy": target_invalidation_policy.strip_edges(),
		"authored_parameters": authored_parameters.duplicate(true),
	}


static func from_submission(submission: Dictionary) -> Dictionary:
	var binding: Dictionary = submission.get("target_binding", {}) if submission.get("target_binding") is Dictionary else {}
	return build(
		str(submission.get("card_semantic_id", "")),
		str(submission.get("action_class", "")),
		str(submission.get("source_pool", "")),
		int(submission.get("order_priority", 0)),
		str(binding.get("target_kind", "")),
		str(binding.get("target_invalidation_policy", TARGET.DEFAULT_INVALIDATION_POLICY)),
		binding.get("authored_parameters", {}) if binding.get("authored_parameters") is Dictionary else {}
	)


static func validate(value: Dictionary) -> Dictionary:
	if not PURE.has_exact_keys(value, FIELDS) or int(value.get("schema_version", -1)) != SCHEMA_VERSION:
		return _rejected("card_batch_authored_rule_schema_invalid")
	if not PURE.is_pure_json_data(value) or not PURE.first_forbidden_runtime_key(value).is_empty() \
			or not PURE.first_retired_counter_key(value).is_empty():
		return _rejected("card_batch_authored_rule_not_pure")
	if str(value.get("card_semantic_id", "")).is_empty() \
			or str(value.get("action_class", "")) not in SUBMISSION.ACTION_CLASSES \
			or str(value.get("source_pool", "")) not in SUBMISSION.SOURCE_POOLS \
			or str(value.get("target_kind", "")).is_empty() \
			or str(value.get("target_invalidation_policy", "")) not in TARGET.INVALIDATION_POLICIES \
			or not (value.get("authored_parameters") is Dictionary):
		return _rejected("card_batch_authored_rule_fields_invalid")
	return {"valid": true, "reason_code": "card_batch_authored_rule_valid", "normalized": value.duplicate(true)}


static func matches_submission(rule: Dictionary, submission: Dictionary) -> bool:
	if not bool(validate(rule).get("valid", false)) or not bool(SUBMISSION.validate(submission).get("valid", false)):
		return false
	var binding: Dictionary = submission.get("target_binding", {})
	return str(rule.get("card_semantic_id", "")) == str(submission.get("card_semantic_id", "")) \
		and str(rule.get("action_class", "")) == str(submission.get("action_class", "")) \
		and str(rule.get("source_pool", "")) == str(submission.get("source_pool", "")) \
		and int(rule.get("order_priority", 0)) == int(submission.get("order_priority", 0)) \
		and str(rule.get("target_kind", "")) == str(binding.get("target_kind", "")) \
		and str(rule.get("target_invalidation_policy", "")) == str(binding.get("target_invalidation_policy", "")) \
		and PURE.stable_fingerprint(rule.get("authored_parameters", {})) == PURE.stable_fingerprint(binding.get("authored_parameters", {}))


static func _rejected(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code, "normalized": {}}
