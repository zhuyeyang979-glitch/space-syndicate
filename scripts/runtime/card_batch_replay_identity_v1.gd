@tool
extends RefCounted
class_name CardBatchReplayIdentityV1

const PURE = preload("res://scripts/semantic/card_batch_pure_data.gd")
const SUBMISSION = preload("res://scripts/semantic/card_batch_submission_v1.gd")
const RECEIPT = preload("res://scripts/semantic/card_batch_receipt_v1.gd")

const SCHEMA_VERSION := 1
const RULESET_ID := "V0.7_REFERENCE_ONLY"
const FIELDS: Array[String] = [
	"schema_version", "ruleset_id", "batch_id",
	"authored_rule_catalog_fingerprint", "submissions",
	"resolution_order_fingerprint", "defense_status_fingerprint",
	"private_defense_receipts_fingerprint", "card_receipts_fingerprint",
	"mutation_trace_fingerprint", "replay_identity_fingerprint",
]
const SUBMISSION_FIELDS: Array[String] = [
	"batch_id", "submission_id", "card_instance_id", "target_binding_fingerprint",
]


static func build(state: Dictionary) -> Dictionary:
	var order: Array = state.get("resolution_order", []) if state.get("resolution_order") is Array else []
	var locked: Dictionary = state.get("locked_submissions_by_id", {}) if state.get("locked_submissions_by_id") is Dictionary else {}
	var submission_rows: Array = []
	for submission_id_variant in order:
		var submission_id := str(submission_id_variant)
		if not (locked.get(submission_id) is Dictionary):
			continue
		var submission := locked.get(submission_id, {}) as Dictionary
		submission_rows.append({
			"batch_id": str(state.get("batch_id", "")),
			"submission_id": submission_id,
			"card_instance_id": str(submission.get("card_instance_id", "")),
			"target_binding_fingerprint": PURE.stable_fingerprint(submission.get("target_binding", {})),
		})
	var identity := {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": str(state.get("ruleset_id", "")),
		"batch_id": str(state.get("batch_id", "")),
		"authored_rule_catalog_fingerprint": PURE.stable_fingerprint(state.get("authored_rules_by_semantic_id", {})),
		"submissions": submission_rows,
		"resolution_order_fingerprint": PURE.stable_fingerprint(order),
		"defense_status_fingerprint": PURE.stable_fingerprint(state.get("defense_statuses", [])),
		"private_defense_receipts_fingerprint": PURE.stable_fingerprint(state.get("private_defense_receipts_by_actor", {})),
		"card_receipts_fingerprint": PURE.stable_fingerprint(state.get("card_receipts", [])),
		"mutation_trace_fingerprint": PURE.stable_fingerprint(state.get("mutation_trace", [])),
	}
	identity["replay_identity_fingerprint"] = PURE.stable_fingerprint(identity)
	return identity


static func validate(identity: Dictionary) -> Dictionary:
	if not PURE.has_exact_keys(identity, FIELDS) \
			or int(identity.get("schema_version", -1)) != SCHEMA_VERSION \
			or str(identity.get("ruleset_id", "")) != RULESET_ID \
			or str(identity.get("batch_id", "")).is_empty():
		return {"valid": false, "reason_code": "card_batch_replay_identity_invalid"}
	if not PURE.is_pure_json_data(identity) or not PURE.first_retired_counter_key(identity).is_empty():
		return {"valid": false, "reason_code": "card_batch_replay_identity_not_pure"}
	for key in ["authored_rule_catalog_fingerprint", "resolution_order_fingerprint", "defense_status_fingerprint", "private_defense_receipts_fingerprint", "card_receipts_fingerprint", "mutation_trace_fingerprint", "replay_identity_fingerprint"]:
		if not RECEIPT.is_sha256(str(identity.get(key, ""))):
			return {"valid": false, "reason_code": "card_batch_replay_identity_fingerprint_invalid"}
	if not (identity.get("submissions") is Array):
		return {"valid": false, "reason_code": "card_batch_replay_identity_submissions_invalid"}
	var submission_ids: Array[String] = []
	for row_variant in identity.get("submissions", []) as Array:
		if not (row_variant is Dictionary):
			return {"valid": false, "reason_code": "card_batch_replay_identity_submission_invalid"}
		var row := row_variant as Dictionary
		var submission_id := str(row.get("submission_id", ""))
		if not PURE.has_exact_keys(row, SUBMISSION_FIELDS) \
				or str(row.get("batch_id", "")) != str(identity.get("batch_id", "")) \
				or submission_id.is_empty() \
				or submission_id in submission_ids \
				or str(row.get("card_instance_id", "")).is_empty() \
				or not RECEIPT.is_sha256(str(row.get("target_binding_fingerprint", ""))):
			return {"valid": false, "reason_code": "card_batch_replay_identity_submission_invalid"}
		submission_ids.append(submission_id)
	if str(identity.get("resolution_order_fingerprint", "")) != PURE.stable_fingerprint(submission_ids):
		return {"valid": false, "reason_code": "card_batch_replay_identity_order_fingerprint_mismatch"}
	var payload := identity.duplicate(true)
	var actual_self_fingerprint := str(payload.get("replay_identity_fingerprint", ""))
	payload.erase("replay_identity_fingerprint")
	if actual_self_fingerprint != PURE.stable_fingerprint(payload):
		return {"valid": false, "reason_code": "card_batch_replay_identity_self_fingerprint_mismatch"}
	return {"valid": true, "reason_code": "card_batch_replay_identity_valid"}
