@tool
extends RefCounted
class_name CardBatchReceiptV1

const PURE = preload("res://scripts/semantic/card_batch_pure_data.gd")

const SCHEMA_VERSION := 1
const CARD_OUTCOMES := ["COMMITTED", "FIZZLE_NO_EFFECT", "COMMIT_LEGAL_REMAINDER", "REFUND_BY_AUTHORED_RULE"]
const CARD_FIELDS: Array[String] = [
	"schema_version", "receipt_kind", "receipt_id", "batch_id", "window_id",
	"resolution_index", "submission_id", "card_instance_id", "outcome",
	"reason_code", "resolved_target_ids", "effect_amount",
	"defense_applications", "mutation_summary",
]
const DEFENSE_APPLICATION_FIELDS: Array[String] = [
	"defense_status_id", "owner_player_id", "source_card_instance_id",
	"effect_kind", "amount_before", "amount_after", "remaining_uses",
	"refund_amount", "private_trace_count",
]
const MUTATION_SUMMARY_FIELDS: Array[String] = [
	"mutation_kind", "submission_id", "resolved_target_ids", "effect_amount",
	"created_defense_status_id", "defense_application_count",
]
const BATCH_FIELDS: Array[String] = [
	"schema_version", "receipt_kind", "receipt_id", "batch_id",
	"completed_window_id", "completed_submission_ids",
	"resolution_order_fingerprint", "defense_status_fingerprint",
	"next_window_id", "trace_fingerprint", "empty_batch",
]
const PRIVATE_DEFENSE_FIELDS: Array[String] = [
	"schema_version", "receipt_kind", "receipt_id", "batch_id", "window_id",
	"resolution_index", "owner_player_id", "defense_status_id",
	"source_card_instance_id", "triggering_submission_id", "refund_amount",
	"private_trace_count", "amount_before", "amount_after", "visibility_scope",
]


static func card_resolution(
	receipt_id: String,
	batch_id: String,
	window_id: String,
	resolution_index: int,
	submission: Dictionary,
	outcome: String,
	resolved_target_ids: Array,
	effect_amount: int,
	defense_applications: Array,
	mutation_summary: Dictionary,
	reason_code: String = ""
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"receipt_kind": "CARD_RESOLUTION_COMMITTED",
		"receipt_id": receipt_id,
		"batch_id": batch_id,
		"window_id": window_id,
		"resolution_index": resolution_index,
		"submission_id": str(submission.get("submission_id", "")),
		"card_instance_id": str(submission.get("card_instance_id", "")),
		"outcome": outcome,
		"reason_code": reason_code,
		"resolved_target_ids": PURE.string_array(resolved_target_ids, true),
		"effect_amount": effect_amount,
		"defense_applications": defense_applications.duplicate(true),
		"mutation_summary": mutation_summary.duplicate(true),
	}


static func batch_complete(
	receipt_id: String,
	batch_id: String,
	completed_window_id: String,
	completed_submission_ids: Array,
	resolution_order_fingerprint: String,
	defense_status_fingerprint: String,
	next_window_id: String,
	trace_fingerprint: String,
	empty_batch: bool
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"receipt_kind": "CARD_BATCH_COMPLETE_RECEIPT",
		"receipt_id": receipt_id,
		"batch_id": batch_id,
		"completed_window_id": completed_window_id,
		"completed_submission_ids": PURE.string_array(completed_submission_ids, true),
		"resolution_order_fingerprint": resolution_order_fingerprint,
		"defense_status_fingerprint": defense_status_fingerprint,
		"next_window_id": next_window_id,
		"trace_fingerprint": trace_fingerprint,
		"empty_batch": empty_batch,
	}


static func private_defense_trigger(
	batch_id: String,
	window_id: String,
	resolution_index: int,
	owner_player_id: String,
	defense_status_id: String,
	source_card_instance_id: String,
	triggering_submission_id: String,
	refund_amount: int,
	private_trace_count: int,
	amount_before: int,
	amount_after: int
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"receipt_kind": "DEFENSE_STATUS_TRIGGERED_PRIVATE",
		"receipt_id": expected_private_defense_receipt_id(batch_id, resolution_index, defense_status_id),
		"batch_id": batch_id,
		"window_id": window_id,
		"resolution_index": resolution_index,
		"owner_player_id": owner_player_id,
		"defense_status_id": defense_status_id,
		"source_card_instance_id": source_card_instance_id,
		"triggering_submission_id": triggering_submission_id,
		"refund_amount": refund_amount,
		"private_trace_count": private_trace_count,
		"amount_before": amount_before,
		"amount_after": amount_after,
		"visibility_scope": "owner_private",
	}


static func validate_card_resolution(value: Dictionary) -> bool:
	if not PURE.has_exact_keys(value, CARD_FIELDS) \
			or int(value.get("schema_version", -1)) != SCHEMA_VERSION \
			or str(value.get("receipt_kind", "")) != "CARD_RESOLUTION_COMMITTED" \
			or not PURE.is_pure_json_data(value) \
			or not PURE.first_retired_counter_key(value).is_empty():
		return false
	for field in ["receipt_id", "batch_id", "window_id", "submission_id", "card_instance_id", "reason_code"]:
		if not _is_nonempty_string(value.get(field)):
			return false
	if not _is_non_negative_integral(value.get("resolution_index")) \
			or not _is_integral(value.get("effect_amount")) \
			or str(value.get("outcome", "")) not in CARD_OUTCOMES:
		return false
	var index := int(value.get("resolution_index", -1))
	if str(value.get("receipt_id", "")) != expected_card_receipt_id(str(value.get("batch_id", "")), index):
		return false
	var target_ids_variant: Variant = value.get("resolved_target_ids")
	if not (target_ids_variant is Array) \
			or PURE.string_array(target_ids_variant, true).size() != (target_ids_variant as Array).size():
		return false
	if not (value.get("defense_applications") is Array):
		return false
	var seen_defense_ids: Array[String] = []
	for application_variant in value.get("defense_applications", []) as Array:
		if not (application_variant is Dictionary) or not _validate_defense_application(application_variant as Dictionary):
			return false
		var defense_id := str((application_variant as Dictionary).get("defense_status_id", ""))
		if defense_id in seen_defense_ids:
			return false
		seen_defense_ids.append(defense_id)
	if not (value.get("mutation_summary") is Dictionary):
		return false
	var summary := value.get("mutation_summary", {}) as Dictionary
	if not _validate_mutation_summary(summary, value):
		return false
	var outcome := str(value.get("outcome", ""))
	if outcome in ["FIZZLE_NO_EFFECT", "REFUND_BY_AUTHORED_RULE"] \
			and (not (target_ids_variant as Array).is_empty() or int(value.get("effect_amount", 0)) != 0):
		return false
	if outcome == "COMMIT_LEGAL_REMAINDER" and (target_ids_variant as Array).is_empty():
		return false
	return true


static func validate_batch_complete(value: Dictionary) -> bool:
	if not PURE.has_exact_keys(value, BATCH_FIELDS) \
			or int(value.get("schema_version", -1)) != SCHEMA_VERSION \
			or str(value.get("receipt_kind", "")) != "CARD_BATCH_COMPLETE_RECEIPT" \
			or not PURE.is_pure_json_data(value) \
			or not PURE.first_retired_counter_key(value).is_empty():
		return false
	for field in ["receipt_id", "batch_id", "completed_window_id", "next_window_id"]:
		if not _is_nonempty_string(value.get(field)):
			return false
	if str(value.get("receipt_id", "")) != expected_batch_receipt_id(str(value.get("batch_id", ""))):
		return false
	var completed_variant: Variant = value.get("completed_submission_ids")
	if not (completed_variant is Array) \
			or PURE.string_array(completed_variant, true).size() != (completed_variant as Array).size():
		return false
	for key in ["resolution_order_fingerprint", "defense_status_fingerprint", "trace_fingerprint"]:
		if not _is_sha256(str(value.get(key, ""))):
			return false
	return value.get("empty_batch") is bool \
		and bool(value.get("empty_batch", false)) == (completed_variant as Array).is_empty()


static func validate_private_defense_trigger(value: Dictionary) -> bool:
	if not PURE.has_exact_keys(value, PRIVATE_DEFENSE_FIELDS) \
			or int(value.get("schema_version", -1)) != SCHEMA_VERSION \
			or str(value.get("receipt_kind", "")) != "DEFENSE_STATUS_TRIGGERED_PRIVATE" \
			or str(value.get("visibility_scope", "")) != "owner_private" \
			or not PURE.is_pure_json_data(value) \
			or not PURE.first_retired_counter_key(value).is_empty():
		return false
	for field in ["receipt_id", "batch_id", "window_id", "owner_player_id", "defense_status_id", "source_card_instance_id", "triggering_submission_id"]:
		if not _is_nonempty_string(value.get(field)):
			return false
	for field in ["resolution_index", "refund_amount", "private_trace_count", "amount_before", "amount_after"]:
		if not _is_non_negative_integral(value.get(field)):
			return false
	if int(value.get("amount_after", 0)) > int(value.get("amount_before", 0)):
		return false
	return str(value.get("receipt_id", "")) == expected_private_defense_receipt_id(
		str(value.get("batch_id", "")),
		int(value.get("resolution_index", -1)),
		str(value.get("defense_status_id", ""))
	)


static func expected_card_receipt_id(batch_id: String, resolution_index: int) -> String:
	return "card-receipt:%s:%06d" % [batch_id, resolution_index]


static func expected_batch_receipt_id(batch_id: String) -> String:
	return "batch-complete:%s" % batch_id


static func expected_private_defense_receipt_id(batch_id: String, resolution_index: int, defense_status_id: String) -> String:
	return "defense-trigger:%s:%06d:%s" % [batch_id, resolution_index, defense_status_id]


static func is_sha256(value: String) -> bool:
	return _is_sha256(value)


static func _validate_defense_application(value: Dictionary) -> bool:
	if not PURE.has_exact_keys(value, DEFENSE_APPLICATION_FIELDS) or not PURE.is_pure_json_data(value):
		return false
	for field in ["defense_status_id", "owner_player_id", "source_card_instance_id", "effect_kind"]:
		if not _is_nonempty_string(value.get(field)):
			return false
	for field in ["amount_before", "amount_after", "remaining_uses", "refund_amount", "private_trace_count"]:
		if not _is_non_negative_integral(value.get(field)):
			return false
	return int(value.get("amount_after", 0)) <= int(value.get("amount_before", 0))


static func _validate_mutation_summary(summary: Dictionary, receipt: Dictionary) -> bool:
	if not PURE.has_exact_keys(summary, MUTATION_SUMMARY_FIELDS) or not PURE.is_pure_json_data(summary):
		return false
	if not _is_nonempty_string(summary.get("mutation_kind")) \
			or str(summary.get("submission_id", "")) != str(receipt.get("submission_id", "")) \
			or not _is_integral(summary.get("effect_amount")) \
			or int(summary.get("effect_amount", 0)) != int(receipt.get("effect_amount", 0)) \
			or not _is_non_negative_integral(summary.get("defense_application_count")) \
			or int(summary.get("defense_application_count", -1)) != (receipt.get("defense_applications", []) as Array).size():
		return false
	if not (summary.get("resolved_target_ids") is Array) \
			or summary.get("resolved_target_ids", []) != receipt.get("resolved_target_ids", []):
		return false
	if not (summary.get("created_defense_status_id") is String or summary.get("created_defense_status_id") is StringName):
		return false
	var outcome := str(receipt.get("outcome", ""))
	var expected_kind := "NO_EFFECT" if outcome in ["FIZZLE_NO_EFFECT", "REFUND_BY_AUTHORED_RULE"] else "CARD_EFFECT_COMMITTED"
	if not str(summary.get("created_defense_status_id", "")).is_empty():
		expected_kind = "DEFENSE_STATUS_CREATED"
	return str(summary.get("mutation_kind", "")) == expected_kind


static func _is_nonempty_string(value: Variant) -> bool:
	return (value is String or value is StringName) and not str(value).is_empty()


static func _is_integral(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


static func _is_non_negative_integral(value: Variant) -> bool:
	return _is_integral(value) and int(value) >= 0


static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		if value.substr(index, 1) not in "0123456789abcdef":
			return false
	return true
