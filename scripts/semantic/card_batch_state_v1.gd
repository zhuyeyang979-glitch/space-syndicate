@tool
extends RefCounted
class_name CardBatchStateV1

const PURE = preload("res://scripts/semantic/card_batch_pure_data.gd")
const SUBMISSION = preload("res://scripts/semantic/card_batch_submission_v1.gd")
const RESOLUTION = preload("res://scripts/semantic/card_batch_card_resolution_state_v1.gd")
const DEFENSE = preload("res://scripts/semantic/card_batch_defense_status_v1.gd")
const INVENTORY = preload("res://scripts/semantic/card_batch_inventory_state_v1.gd")
const RECEIPT = preload("res://scripts/semantic/card_batch_receipt_v1.gd")
const AUTHORED_RULE = preload("res://scripts/semantic/card_batch_authored_rule_v1.gd")

const SCHEMA_VERSION := 1
const RULESET_ID := "V0.7_REFERENCE_ONLY"
const WINDOW_DURATION_USEC := 30_000_000
const PHASE_CARD_WINDOW_CLOSED := "CARD_WINDOW_CLOSED"
const PHASE_CARD_WINDOW_OPEN := "CARD_WINDOW_OPEN"
const PHASE_CARD_WINDOW_LOCKING := "CARD_WINDOW_LOCKING"
const PHASE_RESOLUTION_ORDER_BUILD := "RESOLUTION_ORDER_BUILD"
const PHASE_RESOLUTION_ORDER_REVEAL := "RESOLUTION_ORDER_REVEAL"
const PHASE_CARD_RESOLUTION_ACTIVE := "CARD_RESOLUTION_ACTIVE"
const PHASE_CARD_EFFECT_COMMIT := "CARD_EFFECT_COMMIT"
const PHASE_CARD_AFTERMATH := "CARD_AFTERMATH"
const PHASE_BATCH_AFTERMATH := "BATCH_AFTERMATH"
const PHASE_BATCH_COMPLETE := "BATCH_COMPLETE"
const PHASES := [
	PHASE_CARD_WINDOW_CLOSED, PHASE_CARD_WINDOW_OPEN, PHASE_CARD_WINDOW_LOCKING,
	PHASE_RESOLUTION_ORDER_BUILD, PHASE_RESOLUTION_ORDER_REVEAL,
	PHASE_CARD_RESOLUTION_ACTIVE, PHASE_CARD_EFFECT_COMMIT,
	PHASE_CARD_AFTERMATH, PHASE_BATCH_AFTERMATH, PHASE_BATCH_COMPLETE,
]
const RESOLUTION_PHASES := [
	PHASE_CARD_WINDOW_LOCKING, PHASE_RESOLUTION_ORDER_BUILD,
	PHASE_RESOLUTION_ORDER_REVEAL, PHASE_CARD_RESOLUTION_ACTIVE,
	PHASE_CARD_EFFECT_COMMIT, PHASE_CARD_AFTERMATH, PHASE_BATCH_AFTERMATH,
	PHASE_BATCH_COMPLETE,
]
const FIELDS: Array[String] = [
	"schema_version", "ruleset_id", "production_cutover", "batch_sequence",
	"batch_id", "batch_revision", "phase", "window_sequence", "window_id",
	"window_remaining_phase_time_usec", "world_effective_time_usec",
	"card_phase_time_usec", "actor_ids", "authored_rules_by_semantic_id", "submissions_by_actor",
	"locked_submission_ids", "locked_submissions_by_id", "resolution_order",
	"current_resolution_index", "active_resolution_id", "pending_receipt_ids",
	"card_resolution_state", "card_receipts", "aftermath_state", "batch_after_action_complete",
	"batch_complete", "batch_complete_receipt",
	"consumed_batch_complete_receipt_ids", "defense_statuses",
	"private_defense_receipts_by_actor",
	"inventories_by_actor", "deterministic_effect_totals_by_target",
	"phase_trace", "mutation_trace",
]


static func empty_state() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"production_cutover": false,
		"batch_sequence": 0,
		"batch_id": "",
		"batch_revision": 0,
		"phase": PHASE_CARD_WINDOW_CLOSED,
		"window_sequence": 0,
		"window_id": "",
		"window_remaining_phase_time_usec": 0,
		"world_effective_time_usec": 0,
		"card_phase_time_usec": 0,
		"actor_ids": [],
		"authored_rules_by_semantic_id": {},
		"submissions_by_actor": {},
		"locked_submission_ids": [],
		"locked_submissions_by_id": {},
		"resolution_order": [],
		"current_resolution_index": 0,
		"active_resolution_id": "",
		"pending_receipt_ids": [],
		"card_resolution_state": {},
		"card_receipts": [],
		"aftermath_state": {},
		"batch_after_action_complete": false,
		"batch_complete": false,
		"batch_complete_receipt": {},
		"consumed_batch_complete_receipt_ids": [],
		"defense_statuses": [],
		"private_defense_receipts_by_actor": {},
		"inventories_by_actor": {},
		"deterministic_effect_totals_by_target": {},
		"phase_trace": [],
		"mutation_trace": [],
	}


static func validate(value: Dictionary) -> Dictionary:
	if not PURE.has_exact_keys(value, FIELDS) or int(value.get("schema_version", -1)) != SCHEMA_VERSION:
		return _rejected("card_batch_state_schema_invalid")
	if str(value.get("ruleset_id", "")) != RULESET_ID or bool(value.get("production_cutover", true)):
		return _rejected("card_batch_state_reference_boundary_invalid")
	if not PURE.is_pure_json_data(value) or not PURE.first_forbidden_runtime_key(value).is_empty():
		return _rejected("card_batch_state_not_pure_data")
	var retired_path := PURE.first_retired_counter_key(value)
	if not retired_path.is_empty():
		return _rejected("card_batch_state_retired_counter_payload:%s" % retired_path)
	if str(value.get("phase", "")) not in PHASES:
		return _rejected("card_batch_state_phase_invalid")
	for field in ["batch_sequence", "batch_revision", "window_sequence", "window_remaining_phase_time_usec", "world_effective_time_usec", "card_phase_time_usec", "current_resolution_index"]:
		if int(value.get(field, -1)) < 0:
			return _rejected("card_batch_state_%s_invalid" % field)
	var batch_sequence := int(value.get("batch_sequence", 0))
	var window_sequence := int(value.get("window_sequence", 0))
	if batch_sequence == 0:
		if window_sequence != 0 \
				or not str(value.get("batch_id", "")).is_empty() \
				or not str(value.get("window_id", "")).is_empty() \
				or str(value.get("phase", "")) != PHASE_CARD_WINDOW_CLOSED:
			return _rejected("card_batch_state_unstarted_lifecycle_invalid")
	elif window_sequence != batch_sequence \
			or str(value.get("batch_id", "")) != _batch_id(batch_sequence) \
			or str(value.get("window_id", "")) != _window_id(window_sequence) \
			or str(value.get("phase", "")) == PHASE_CARD_WINDOW_CLOSED:
		return _rejected("card_batch_state_active_lifecycle_identity_invalid")
	if int(value.get("window_remaining_phase_time_usec", 0)) > WINDOW_DURATION_USEC:
		return _rejected("card_batch_state_window_time_invalid")
	var actor_ids_variant: Variant = value.get("actor_ids")
	if not (actor_ids_variant is Array):
		return _rejected("card_batch_state_actor_ids_invalid")
	var actor_ids := PURE.string_array(actor_ids_variant, true)
	if actor_ids.size() != (actor_ids_variant as Array).size():
		return _rejected("card_batch_state_actor_ids_invalid")
	for dictionary_field in ["authored_rules_by_semantic_id", "submissions_by_actor", "locked_submissions_by_id", "private_defense_receipts_by_actor", "inventories_by_actor", "deterministic_effect_totals_by_target", "aftermath_state", "batch_complete_receipt", "card_resolution_state"]:
		if not (value.get(dictionary_field) is Dictionary):
			return _rejected("card_batch_state_%s_invalid" % dictionary_field)
	for array_field in ["locked_submission_ids", "resolution_order", "pending_receipt_ids", "card_receipts", "consumed_batch_complete_receipt_ids", "defense_statuses", "phase_trace", "mutation_trace"]:
		if not (value.get(array_field) is Array):
			return _rejected("card_batch_state_%s_invalid" % array_field)
	var authored_rules: Dictionary = value.get("authored_rules_by_semantic_id", {})
	for semantic_id_variant in authored_rules.keys():
		var semantic_id := str(semantic_id_variant)
		if semantic_id.is_empty() or not (authored_rules.get(semantic_id_variant) is Dictionary):
			return _rejected("card_batch_state_authored_rule_key_invalid")
		var rule: Dictionary = authored_rules.get(semantic_id_variant, {})
		if str(rule.get("card_semantic_id", "")) != semantic_id \
				or not bool(AUTHORED_RULE.validate(rule).get("valid", false)):
			return _rejected("card_batch_state_authored_rule_invalid")
	var drafts: Dictionary = value.get("submissions_by_actor", {})
	for actor_variant in drafts.keys():
		var actor_id := str(actor_variant)
		if actor_id not in actor_ids or not (drafts.get(actor_variant) is Dictionary):
			return _rejected("card_batch_state_draft_actor_invalid")
		var draft_validation := SUBMISSION.validate(drafts.get(actor_variant, {}), false)
		if not bool(draft_validation.get("valid", false)) \
				or str((drafts.get(actor_variant, {}) as Dictionary).get("actor_id", "")) != actor_id \
				or not str((drafts.get(actor_variant, {}) as Dictionary).get("locked_at_window_id", "")).is_empty():
			return _rejected("card_batch_state_draft_invalid")
		var draft_rule: Dictionary = authored_rules.get(str((drafts.get(actor_variant, {}) as Dictionary).get("card_semantic_id", "")), {})
		if not AUTHORED_RULE.matches_submission(draft_rule, drafts.get(actor_variant, {})):
			return _rejected("card_batch_state_draft_authored_rule_mismatch")
	var locked_ids_variant: Variant = value.get("locked_submission_ids")
	var locked_ids := PURE.string_array(locked_ids_variant, true)
	if locked_ids.size() != (locked_ids_variant as Array).size():
		return _rejected("card_batch_state_locked_ids_invalid")
	var locked: Dictionary = value.get("locked_submissions_by_id", {})
	if locked.size() != locked_ids.size():
		return _rejected("card_batch_state_locked_count_invalid")
	var locked_actor_ids: Array[String] = []
	for submission_id in locked_ids:
		if not (locked.get(submission_id) is Dictionary):
			return _rejected("card_batch_state_locked_submission_missing")
		var locked_submission := locked.get(submission_id, {}) as Dictionary
		var locked_actor_id := str(locked_submission.get("actor_id", ""))
		if str(locked_submission.get("submission_id", "")) != submission_id \
				or not bool(SUBMISSION.validate(locked_submission, true).get("valid", false)) \
				or str(locked_submission.get("locked_at_window_id", "")) != str(value.get("window_id", "")) \
				or locked_actor_id not in actor_ids \
				or locked_actor_id in locked_actor_ids:
			return _rejected("card_batch_state_locked_submission_invalid")
		var locked_rule: Dictionary = authored_rules.get(str(locked_submission.get("card_semantic_id", "")), {})
		if not AUTHORED_RULE.matches_submission(locked_rule, locked_submission):
			return _rejected("card_batch_state_locked_authored_rule_mismatch")
		locked_actor_ids.append(locked_actor_id)
	var order_variant: Variant = value.get("resolution_order")
	var order := PURE.string_array(order_variant, true)
	if order.size() != (order_variant as Array).size() or order.size() != locked_ids.size():
		return _rejected("card_batch_state_resolution_order_invalid")
	var order_members := order.duplicate()
	var locked_members := locked_ids.duplicate()
	order_members.sort()
	locked_members.sort()
	if order_members != locked_members:
		return _rejected("card_batch_state_resolution_order_members_invalid")
	var expected_rows: Array = []
	for submission_id in locked_ids:
		expected_rows.append(locked.get(submission_id, {}))
	expected_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return SUBMISSION.stable_order_key(left) < SUBMISSION.stable_order_key(right))
	var expected_order: Array[String] = []
	for row_variant in expected_rows:
		expected_order.append(str((row_variant as Dictionary).get("submission_id", "")))
	if order != expected_order:
		return _rejected("card_batch_state_resolution_order_not_authoritative")
	var resolution_index := int(value.get("current_resolution_index", 0))
	if resolution_index > order.size():
		return _rejected("card_batch_state_resolution_index_invalid")
	var active_id := str(value.get("active_resolution_id", ""))
	if not active_id.is_empty() and (resolution_index >= order.size() or active_id != order[resolution_index]):
		return _rejected("card_batch_state_active_resolution_invalid")
	var resolution_state: Dictionary = value.get("card_resolution_state", {})
	var phase := str(value.get("phase", ""))
	if phase in [PHASE_CARD_RESOLUTION_ACTIVE, PHASE_CARD_EFFECT_COMMIT, PHASE_CARD_AFTERMATH]:
		if not bool(RESOLUTION.validate(resolution_state).get("valid", false)) \
				or str(resolution_state.get("submission_id", "")) != active_id \
				or int(resolution_state.get("resolution_index", -1)) != resolution_index \
				or str(resolution_state.get("phase", "")) != phase \
				or str(resolution_state.get("batch_id", "")) != str(value.get("batch_id", "")) \
				or str(resolution_state.get("window_id", "")) != str(value.get("window_id", "")) \
				or str(resolution_state.get("prebound_target_fingerprint", "")) != PURE.stable_fingerprint((locked.get(active_id, {}) as Dictionary).get("target_binding", {})):
			return _rejected("card_batch_state_card_resolution_state_invalid")
	elif not resolution_state.is_empty():
		return _rejected("card_batch_state_unexpected_card_resolution_state")
	var card_receipts: Array = value.get("card_receipts", [])
	if phase in [PHASE_CARD_RESOLUTION_ACTIVE, PHASE_CARD_EFFECT_COMMIT] and card_receipts.size() != resolution_index:
		return _rejected("card_batch_state_precommit_receipt_count_invalid")
	if phase == PHASE_CARD_AFTERMATH and card_receipts.size() != resolution_index + 1:
		return _rejected("card_batch_state_aftermath_receipt_count_invalid")
	if phase in [PHASE_BATCH_AFTERMATH, PHASE_BATCH_COMPLETE] and (resolution_index != order.size() or card_receipts.size() != order.size()):
		return _rejected("card_batch_state_batch_receipt_count_invalid")
	if phase in [PHASE_CARD_WINDOW_CLOSED, PHASE_CARD_WINDOW_OPEN, PHASE_CARD_WINDOW_LOCKING, PHASE_RESOLUTION_ORDER_BUILD, PHASE_RESOLUTION_ORDER_REVEAL] and not card_receipts.is_empty():
		return _rejected("card_batch_state_receipt_before_resolution")
	var pending_variant: Variant = value.get("pending_receipt_ids")
	var pending_ids := PURE.string_array(pending_variant, true)
	if pending_ids.size() != (pending_variant as Array).size():
		return _rejected("card_batch_state_pending_receipt_ids_invalid")
	var aftermath: Dictionary = value.get("aftermath_state", {})
	if phase == PHASE_CARD_AFTERMATH:
		if pending_ids.size() != 1 \
				or card_receipts.is_empty() \
				or pending_ids[0] != str((card_receipts[-1] as Dictionary).get("receipt_id", "")) \
				or not PURE.has_exact_keys(aftermath, ["kind", "receipt_id", "complete"]) \
				or str(aftermath.get("kind", "")) != "CARD" \
				or str(aftermath.get("receipt_id", "")) != pending_ids[0] \
				or typeof(aftermath.get("complete")) != TYPE_BOOL \
				or bool(aftermath.get("complete", true)):
			return _rejected("card_batch_state_card_aftermath_lineage_invalid")
	elif not pending_ids.is_empty():
		return _rejected("card_batch_state_unexpected_pending_receipt")
	if phase == PHASE_BATCH_COMPLETE:
		if not PURE.has_exact_keys(aftermath, ["kind", "complete"]) \
				or str(aftermath.get("kind", "")) != "BATCH" \
				or typeof(aftermath.get("complete")) != TYPE_BOOL \
				or not bool(aftermath.get("complete", false)) \
				or not bool(value.get("batch_after_action_complete", false)) \
				or not bool(value.get("batch_complete", false)):
			return _rejected("card_batch_state_batch_completion_flags_invalid")
	elif (phase != PHASE_CARD_AFTERMATH and not aftermath.is_empty()) \
			or bool(value.get("batch_after_action_complete", false)) \
			or bool(value.get("batch_complete", false)):
		return _rejected("card_batch_state_premature_batch_completion")
	var defense_statuses_by_id: Dictionary = {}
	for status_variant in value.get("defense_statuses", []) as Array:
		if not (status_variant is Dictionary) or not bool(DEFENSE.validate(status_variant as Dictionary).get("valid", false)):
			return _rejected("card_batch_state_defense_status_invalid")
		var status := status_variant as Dictionary
		var status_id := str(status.get("defense_status_id", ""))
		if defense_statuses_by_id.has(status_id):
			return _rejected("card_batch_state_defense_status_duplicate")
		defense_statuses_by_id[status_id] = status
	var inventories: Dictionary = value.get("inventories_by_actor", {})
	if inventories.size() != actor_ids.size():
		return _rejected("card_batch_state_inventory_count_invalid")
	for actor_id in actor_ids:
		if not (inventories.get(actor_id) is Dictionary):
			return _rejected("card_batch_state_inventory_missing")
		var inventory := inventories.get(actor_id, {}) as Dictionary
		if str(inventory.get("actor_id", "")) != actor_id or not bool(INVENTORY.validate(inventory).get("valid", false)):
			return _rejected("card_batch_state_inventory_invalid")
	var receipt_ids: Array[String] = []
	for receipt_index in range(card_receipts.size()):
		var receipt_variant: Variant = card_receipts[receipt_index]
		if not (receipt_variant is Dictionary) or not RECEIPT.validate_card_resolution(receipt_variant as Dictionary):
			return _rejected("card_batch_state_card_receipt_invalid")
		var receipt := receipt_variant as Dictionary
		if receipt_index >= order.size():
			return _rejected("card_batch_state_card_receipt_order_overflow")
		var ordered_submission_id := str(order[receipt_index])
		var ordered_submission: Dictionary = locked.get(ordered_submission_id, {})
		var receipt_id := str(receipt.get("receipt_id", ""))
		if receipt_id in receipt_ids \
				or receipt_id != RECEIPT.expected_card_receipt_id(str(value.get("batch_id", "")), receipt_index) \
				or str(receipt.get("batch_id", "")) != str(value.get("batch_id", "")) \
				or str(receipt.get("window_id", "")) != str(value.get("window_id", "")) \
				or int(receipt.get("resolution_index", -1)) != receipt_index \
				or str(receipt.get("submission_id", "")) != ordered_submission_id \
				or str(receipt.get("card_instance_id", "")) != str(ordered_submission.get("card_instance_id", "")):
			return _rejected("card_batch_state_card_receipt_lineage_invalid")
		for application_variant in receipt.get("defense_applications", []) as Array:
			var application := application_variant as Dictionary
			var status_id := str(application.get("defense_status_id", ""))
			if not (defense_statuses_by_id.get(status_id) is Dictionary):
				return _rejected("card_batch_state_receipt_defense_status_missing")
			var status := defense_statuses_by_id.get(status_id, {}) as Dictionary
			if str(application.get("owner_player_id", "")) != str(status.get("owner_player_id", "")) \
					or str(application.get("source_card_instance_id", "")) != str(status.get("source_card_instance_id", "")) \
					or int(application.get("refund_amount", -1)) != int(status.get("trigger_refund_amount", -1)) \
					or int(application.get("private_trace_count", -1)) != int(status.get("private_trace_count", -1)):
				return _rejected("card_batch_state_receipt_defense_status_lineage_invalid")
		receipt_ids.append(receipt_id)
	if phase == PHASE_CARD_AFTERMATH:
		var active_receipt := card_receipts[-1] as Dictionary
		var active_applications: Array[String] = []
		for application_variant in active_receipt.get("defense_applications", []) as Array:
			active_applications.append(str((application_variant as Dictionary).get("defense_status_id", "")))
		if str(resolution_state.get("authoritative_effect_receipt_id", "")) != str(active_receipt.get("receipt_id", "")) \
				or str(resolution_state.get("outcome", "")) != str(active_receipt.get("outcome", "")) \
				or resolution_state.get("applied_defense_status_ids", []) != active_applications:
			return _rejected("card_batch_state_active_receipt_resolution_lineage_invalid")
	var mutation_trace: Array = value.get("mutation_trace", [])
	if mutation_trace.size() != card_receipts.size():
		return _rejected("card_batch_state_mutation_receipt_count_invalid")
	var mutation_fields: Array[String] = [
		"mutation_index", "batch_id", "submission_id", "outcome", "summary", "receipt_fingerprint",
	]
	for mutation_index in range(mutation_trace.size()):
		if not (mutation_trace[mutation_index] is Dictionary):
			return _rejected("card_batch_state_mutation_trace_invalid")
		var mutation := mutation_trace[mutation_index] as Dictionary
		var receipt := card_receipts[mutation_index] as Dictionary
		if not PURE.has_exact_keys(mutation, mutation_fields) \
				or int(mutation.get("mutation_index", -1)) != mutation_index \
				or str(mutation.get("batch_id", "")) != str(value.get("batch_id", "")) \
				or str(mutation.get("submission_id", "")) != str(receipt.get("submission_id", "")) \
				or str(mutation.get("outcome", "")) != str(receipt.get("outcome", "")) \
				or mutation.get("summary", {}) != receipt.get("mutation_summary", {}) \
				or str(mutation.get("receipt_fingerprint", "")) != PURE.stable_fingerprint(receipt):
			return _rejected("card_batch_state_mutation_receipt_lineage_invalid")
	var expected_private_receipts: Dictionary = {}
	for receipt_variant in card_receipts:
		var receipt := receipt_variant as Dictionary
		for application_variant in receipt.get("defense_applications", []) as Array:
			var application := application_variant as Dictionary
			var owner_id := str(application.get("owner_player_id", ""))
			var rows: Array = expected_private_receipts.get(owner_id, []) if expected_private_receipts.get(owner_id) is Array else []
			rows.append(RECEIPT.private_defense_trigger(
				str(value.get("batch_id", "")),
				str(value.get("window_id", "")),
				int(receipt.get("resolution_index", -1)),
				owner_id,
				str(application.get("defense_status_id", "")),
				str(application.get("source_card_instance_id", "")),
				str(receipt.get("submission_id", "")),
				int(application.get("refund_amount", 0)),
				int(application.get("private_trace_count", 0)),
				int(application.get("amount_before", 0)),
				int(application.get("amount_after", 0))
			))
			expected_private_receipts[owner_id] = rows
	var private_defense_receipts: Dictionary = value.get("private_defense_receipts_by_actor", {})
	var private_receipt_ids: Array[String] = []
	for actor_id_variant in private_defense_receipts.keys():
		var actor_id := str(actor_id_variant)
		if actor_id not in actor_ids or not (private_defense_receipts.get(actor_id_variant) is Array):
			return _rejected("card_batch_state_private_defense_receipt_actor_invalid")
		for private_receipt_variant in private_defense_receipts.get(actor_id_variant, []) as Array:
			if not (private_receipt_variant is Dictionary) \
					or not RECEIPT.validate_private_defense_trigger(private_receipt_variant as Dictionary) \
					or str((private_receipt_variant as Dictionary).get("owner_player_id", "")) != actor_id \
					or str((private_receipt_variant as Dictionary).get("receipt_id", "")) in private_receipt_ids:
				return _rejected("card_batch_state_private_defense_receipt_invalid")
			private_receipt_ids.append(str((private_receipt_variant as Dictionary).get("receipt_id", "")))
	if PURE.stable_fingerprint(private_defense_receipts) != PURE.stable_fingerprint(expected_private_receipts):
		return _rejected("card_batch_state_private_defense_receipt_lineage_invalid")
	var complete_receipt: Dictionary = value.get("batch_complete_receipt", {})
	if bool(value.get("batch_complete", false)) != (not complete_receipt.is_empty()):
		return _rejected("card_batch_state_completion_mismatch")
	if not complete_receipt.is_empty():
		if not RECEIPT.validate_batch_complete(complete_receipt) \
				or str(complete_receipt.get("batch_id", "")) != str(value.get("batch_id", "")) \
				or str(complete_receipt.get("completed_window_id", "")) != str(value.get("window_id", "")) \
				or complete_receipt.get("completed_submission_ids", []) != order \
				or str(complete_receipt.get("resolution_order_fingerprint", "")) != PURE.stable_fingerprint(order) \
				or str(complete_receipt.get("defense_status_fingerprint", "")) != PURE.stable_fingerprint(value.get("defense_statuses", [])) \
				or str(complete_receipt.get("next_window_id", "")) != _window_id(int(value.get("window_sequence", 0)) + 1) \
				or str(complete_receipt.get("trace_fingerprint", "")) != PURE.stable_fingerprint(value.get("phase_trace", [])):
			return _rejected("card_batch_state_batch_receipt_lineage_invalid")
	var consumed_variant: Variant = value.get("consumed_batch_complete_receipt_ids")
	var consumed_ids := PURE.string_array(consumed_variant, true)
	if consumed_ids.size() != (consumed_variant as Array).size() \
			or consumed_ids.size() != maxi(0, int(value.get("batch_sequence", 0)) - 1):
		return _rejected("card_batch_state_consumed_receipt_ids_invalid")
	for consumed_index in range(consumed_ids.size()):
		if consumed_ids[consumed_index] != RECEIPT.expected_batch_receipt_id(_batch_id(consumed_index + 1)):
			return _rejected("card_batch_state_consumed_receipt_lineage_invalid")
	if not complete_receipt.is_empty() and str(complete_receipt.get("receipt_id", "")) in consumed_ids:
		return _rejected("card_batch_state_current_completion_already_consumed")
	return {"valid": true, "reason_code": "card_batch_state_valid", "normalized": value.duplicate(true)}


static func fingerprint(value: Dictionary) -> String:
	return PURE.stable_fingerprint(value) if bool(validate(value).get("valid", false)) else ""


static func _batch_id(sequence: int) -> String:
	return "card-batch:%06d" % sequence


static func _window_id(sequence: int) -> String:
	return "card-window:%06d" % sequence


static func _rejected(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code, "normalized": {}}
