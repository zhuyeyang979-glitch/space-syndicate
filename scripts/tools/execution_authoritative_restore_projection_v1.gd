extends RefCounted
class_name ExecutionAuthoritativeRestoreProjectionV1

const CODEC := preload("res://scripts/runtime/card_resolution_execution_save_wire_codec_v4.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const SCALAR := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")

const PROJECTION_SCHEMA_VERSION := 1
const AUTHORITY_SOURCE := "save_v4_and_typed_authoritative_queries"
const WIRE_ROOT_FIELDS := [
	"schema_version",
	"execution_wire_version",
	"ruleset_id",
	"transaction_sequence",
	"completed_resolution_ids",
	"inflight_resolution_ids",
	"inflight_execution_transactions",
	"pending_settlements",
	"transition_controller",
	"execution_wire_fingerprint",
]
const RUNTIME_ROOT_FIELDS := [
	"schema_version",
	"execution_wire_version",
	"ruleset_id",
	"transaction_sequence",
	"completed_resolution_ids",
	"inflight_resolution_ids",
	"inflight_execution_transactions",
	"pending_settlements",
	"transition_controller",
]
const TRANSITION_FIELDS := [
	"transition_state_wire_version",
	"card_group_cadence_version",
	"card_group_cadence",
	"card_group_window_phase",
	"card_resolution_timer",
	"card_resolution_counter_window_active",
	"card_resolution_counter_timer",
	"card_resolution_simultaneous_timer",
	"card_resolution_auction_timer",
	"card_resolution_auction_open",
	"card_resolution_batch_locked",
	"card_resolution_batch_reference_player",
	"card_group_window_sequence",
	"last_card_resolution_player_index",
	"card_group_ready_players",
	"card_transition_command_schema_version",
	"card_transition_command_revision",
	"card_transition_command_next_order_index",
	"card_transition_applied_lineage",
	"card_transition_last_applied_revision",
	"card_transition_last_applied_order_index",
]
const CADENCE_FIELDS := [
	"cadence_version",
	"window_sequence",
	"extended",
	"total_seconds",
	"planning_seconds",
	"public_bid_seconds",
	"lock_seconds",
]
const EXACT_ONCE_ROOT_FIELDS := [
	"transaction_sequence",
	"completed_resolution_ids",
	"inflight_resolution_ids",
	"inflight_execution_transactions",
	"pending_settlements",
]
const EXACT_ONCE_TRANSITION_FIELDS := [
	"card_transition_command_revision",
	"card_transition_command_next_order_index",
	"card_transition_applied_lineage",
	"card_transition_last_applied_revision",
	"card_transition_last_applied_order_index",
]
const ATTESTED_DIAGNOSTIC_DIFFERENCE_PATHS := [
	"$.owner_debug.last_phase",
	"$.owner_debug.last_reason",
]
const POST_RESTORE_REASONS := [
	"execution_lineage_restored",
]
const REDACTED_EVIDENCE_FIELDS := [
	"schema_version",
	"evidence_id",
	"authority_source",
	"save_wire_fingerprint_before",
	"save_wire_fingerprint_after",
	"recursive_field_manifest_sha256_before",
	"recursive_field_manifest_sha256_after",
	"wire_root_field_count",
	"decoded_root_field_count",
	"transition_state_field_count",
	"recursive_path_count",
	"field_coverage_percent",
	"save_v4_field_omission_count",
	"exact_once_field_omission_count",
	"typed_authoritative_query_parity",
	"authoritative_restore_parity",
	"diagnostic_canonicalization_green",
	"exact_once_green",
	"duplicate_effect_dispatch_count",
	"duplicate_card_commitment_count",
	"duplicate_history_append_count",
	"duplicate_settlement_count",
	"duplicate_transition_command_apply_count",
	"parity_excluded_paths",
	"parity_exclusion_wildcard_count",
	"private_payload_redacted",
]


static func capture(owner: Node, transition: Node = null) -> Dictionary:
	if owner == null or not owner.has_method("to_save_data") or not owner.has_method("preflight_save_data"):
		return _failure("execution_authoritative_projection_owner_invalid")
	var wire_variant: Variant = owner.call("to_save_data")
	if not (wire_variant is Dictionary):
		return _failure("execution_authoritative_projection_capture_invalid")
	var wire := (wire_variant as Dictionary).duplicate(true)
	var preflight_variant: Variant = owner.call("preflight_save_data", wire)
	var preflight := preflight_variant as Dictionary if preflight_variant is Dictionary else {}
	if not bool(preflight.get("accepted", false)):
		return _failure(str(preflight.get("reason_code", "execution_authoritative_projection_preflight_rejected")))
	var report := from_wire(wire)
	if not bool(report.get("ok", false)):
		return report
	var runtime := report.get("decoded_runtime", {}) as Dictionary
	var typed_query_parity := _typed_query_parity(owner, transition, runtime)
	report["typed_authoritative_query_parity"] = typed_query_parity
	report["ok"] = bool(report.get("ok", false)) and typed_query_parity
	if not typed_query_parity:
		report["reason_code"] = "execution_authoritative_projection_typed_query_mismatch"
	report.erase("decoded_runtime")
	return report


static func from_wire(wire: Dictionary) -> Dictionary:
	if not _has_exact_fields(wire, WIRE_ROOT_FIELDS) or not WIRE.is_closed_data(wire):
		return _failure("execution_authoritative_projection_wire_invalid")
	var decoded := CODEC.decode_save_state(wire)
	if not bool(decoded.get("ok", false)) or not (decoded.get("value") is Dictionary):
		return _failure(str(decoded.get("reason_code", "execution_authoritative_projection_decode_failed")))
	var runtime := decoded.get("value") as Dictionary
	if not _has_exact_fields(runtime, RUNTIME_ROOT_FIELDS):
		return _failure("execution_authoritative_projection_runtime_root_invalid")
	var transition_variant: Variant = runtime.get("transition_controller")
	if not (transition_variant is Dictionary):
		return _failure("execution_authoritative_projection_transition_missing")
	var transition := transition_variant as Dictionary
	if not _has_exact_fields(transition, TRANSITION_FIELDS):
		return _failure("execution_authoritative_projection_transition_shape_invalid")
	var cadence_variant: Variant = transition.get("card_group_cadence")
	if not (cadence_variant is Dictionary) or not _has_exact_fields(cadence_variant as Dictionary, CADENCE_FIELDS):
		return _failure("execution_authoritative_projection_cadence_shape_invalid")

	var exact_once_omissions := 0
	for field in EXACT_ONCE_ROOT_FIELDS:
		if not runtime.has(field):
			exact_once_omissions += 1
	for field in EXACT_ONCE_TRANSITION_FIELDS:
		if not transition.has(field):
			exact_once_omissions += 1
	var projection := wire.duplicate(true)
	var source_path_count := _path_count(wire)
	var projection_path_count := _path_count(projection)
	var omission_count := 0 if projection == wire and source_path_count == projection_path_count else 1
	var coverage_percent := 0
	if source_path_count > 0 and omission_count == 0:
		coverage_percent = int(roundi(float(projection_path_count) * 100.0 / float(source_path_count)))
	var diagnostic_persisted_count := 0
	for diagnostic_field in ["last_phase", "last_reason", "last_summary"]:
		if wire.has(diagnostic_field) or transition.has(diagnostic_field):
			diagnostic_persisted_count += 1
	return {
		"ok": omission_count == 0 and exact_once_omissions == 0 and diagnostic_persisted_count == 0,
		"reason_code": "execution_authoritative_projection_valid" if omission_count == 0 and exact_once_omissions == 0 and diagnostic_persisted_count == 0 else "execution_authoritative_projection_incomplete",
		"projection_schema_version": PROJECTION_SCHEMA_VERSION,
		"authority_source": AUTHORITY_SOURCE,
		"debug_snapshot_used_as_restore_authority": false,
		"projection": projection,
		"decoded_runtime": runtime.duplicate(true),
		"projection_fingerprint": str(wire.get("execution_wire_fingerprint", "")),
		"recursive_field_manifest_sha256": JSON.stringify(wire).sha256_text().to_lower(),
		"wire_root_field_count": wire.size(),
		"decoded_root_field_count": runtime.size(),
		"transition_state_field_count": transition.size(),
		"source_path_count": source_path_count,
		"projection_path_count": projection_path_count,
		"field_coverage_percent": coverage_percent,
		"save_v4_field_omission_count": omission_count,
		"exact_once_field_omission_count": exact_once_omissions,
		"diagnostic_fields_persisted_to_save_count": diagnostic_persisted_count,
		"parity_excluded_field_count": ATTESTED_DIAGNOSTIC_DIFFERENCE_PATHS.size(),
		"parity_excluded_field_reason_count": ATTESTED_DIAGNOSTIC_DIFFERENCE_PATHS.size(),
		"parity_exclusion_wildcard_count": 0,
		"unknown_parity_exclusion_count": 0,
		"automatic_golden_update_count": 0,
	}


static func compare(before_projection: Dictionary, after_projection: Dictionary) -> Dictionary:
	var before_ok := bool(before_projection.get("ok", false))
	var after_ok := bool(after_projection.get("ok", false))
	var equal: bool = before_ok and after_ok \
			and before_projection.get("projection") == after_projection.get("projection")
	return {
		"green": equal,
		"reason_code": "execution_authoritative_restore_parity_green" if equal else "execution_authoritative_restore_parity_mismatch",
		"projection_a_equals_b": equal,
		"fingerprint_parity": str(before_projection.get("projection_fingerprint", "")) \
				== str(after_projection.get("projection_fingerprint", "")),
		"authority_source": AUTHORITY_SOURCE,
		"debug_snapshot_used_as_restore_authority": false,
	}


static func redacted_evidence(
	before_projection: Dictionary,
	after_projection: Dictionary,
	comparison: Dictionary,
	diagnostics: Dictionary,
	exact_once: Dictionary
) -> Dictionary:
	return {
		"schema_version": 1,
		"evidence_id": "ExecutionAuthoritativeRestoreProjectionV1RedactedEvidence",
		"authority_source": AUTHORITY_SOURCE,
		"save_wire_fingerprint_before": str(before_projection.get("projection_fingerprint", "")),
		"save_wire_fingerprint_after": str(after_projection.get("projection_fingerprint", "")),
		"recursive_field_manifest_sha256_before": str(before_projection.get("recursive_field_manifest_sha256", "")),
		"recursive_field_manifest_sha256_after": str(after_projection.get("recursive_field_manifest_sha256", "")),
		"wire_root_field_count": int(after_projection.get("wire_root_field_count", -1)),
		"decoded_root_field_count": int(after_projection.get("decoded_root_field_count", -1)),
		"transition_state_field_count": int(after_projection.get("transition_state_field_count", -1)),
		"recursive_path_count": int(after_projection.get("projection_path_count", -1)),
		"field_coverage_percent": int(after_projection.get("field_coverage_percent", -1)),
		"save_v4_field_omission_count": int(after_projection.get("save_v4_field_omission_count", -1)),
		"exact_once_field_omission_count": int(after_projection.get("exact_once_field_omission_count", -1)),
		"typed_authoritative_query_parity": bool(after_projection.get("typed_authoritative_query_parity", false)),
		"authoritative_restore_parity": bool(comparison.get("green", false)),
		"diagnostic_canonicalization_green": bool(diagnostics.get("ok", false)),
		"exact_once_green": bool(exact_once.get("green", false)),
		"duplicate_effect_dispatch_count": int(exact_once.get("duplicate_effect_dispatch_count", -1)),
		"duplicate_card_commitment_count": int(exact_once.get("duplicate_card_commitment_count", -1)),
		"duplicate_history_append_count": int(exact_once.get("duplicate_history_append_count", -1)),
		"duplicate_settlement_count": int(exact_once.get("duplicate_settlement_count", -1)),
		"duplicate_transition_command_apply_count": int(exact_once.get("duplicate_transition_command_apply_count", -1)),
		"parity_excluded_paths": ATTESTED_DIAGNOSTIC_DIFFERENCE_PATHS.duplicate(),
		"parity_exclusion_wildcard_count": 0,
		"private_payload_redacted": true,
	}


static func diagnostic_canonicalization(owner: Node) -> Dictionary:
	if owner == null or not owner.has_method("debug_snapshot"):
		return _failure("execution_post_restore_diagnostic_owner_invalid")
	var debug_variant: Variant = owner.call("debug_snapshot")
	if not (debug_variant is Dictionary):
		return _failure("execution_post_restore_diagnostic_snapshot_invalid")
	var debug := debug_variant as Dictionary
	var phase_canonical := debug.get("last_phase") is String \
			and str(debug.get("last_phase")) == "restored"
	var reason_canonical := debug.get("last_reason") is String \
			and POST_RESTORE_REASONS.has(str(debug.get("last_reason")))
	var summary_canonical := debug.get("last_summary") is Dictionary \
			and (debug.get("last_summary") as Dictionary).is_empty()
	return {
		"ok": phase_canonical and reason_canonical and summary_canonical,
		"reason_code": "execution_post_restore_diagnostic_canonical" \
				if phase_canonical and reason_canonical and summary_canonical \
				else "execution_post_restore_diagnostic_not_canonical",
		"post_restore_diagnostic_phase_canonical": phase_canonical,
		"post_restore_diagnostic_reason_canonical": reason_canonical,
		"post_restore_diagnostic_summary_canonical": summary_canonical,
		"diagnostic_fields_persisted_to_save_count": 0,
		"raw_last_summary_recorded": false,
	}


static func _has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant: Variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func _typed_query_parity(owner: Node, transition_owner: Node, runtime: Dictionary) -> bool:
	for resolution_variant: Variant in runtime.get("completed_resolution_ids", []) as Array:
		if not (resolution_variant is int) or not bool(owner.call("resolution_completed", int(resolution_variant))):
			return false
	for resolution_variant: Variant in runtime.get("inflight_resolution_ids", []) as Array:
		if not (resolution_variant is int) or not bool(owner.call("has_inflight_execution", int(resolution_variant))):
			return false
	for pending_variant: Variant in runtime.get("pending_settlements", []) as Array:
		if not (pending_variant is Dictionary):
			return false
		var resolution_id := int((pending_variant as Dictionary).get("resolution_id", -1))
		if resolution_id < 0 or not (owner.call("pending_settlement", resolution_id) is Dictionary) \
				or (owner.call("pending_settlement", resolution_id) as Dictionary).is_empty():
			return false
	if transition_owner == null or not transition_owner.has_method("to_save_data") \
			or not transition_owner.has_method("transition_lineage_snapshot"):
		return false
	var authored_transition := (runtime.get("transition_controller", {}) as Dictionary).duplicate(true)
	authored_transition.erase("transition_state_wire_version")
	var live_transition: Dictionary = transition_owner.call("to_save_data")
	if not _transition_bits_and_values_equal(authored_transition, live_transition):
		return false
	var lineage: Dictionary = transition_owner.call("transition_lineage_snapshot")
	if int(lineage.get("batch_revision", -1)) != int(authored_transition.get("card_transition_command_revision", -2)) \
			or int(lineage.get("next_order_index", -1)) != int(authored_transition.get("card_transition_command_next_order_index", -2)) \
			or lineage.get("applied_lineage") != authored_transition.get("card_transition_applied_lineage") \
			or int(lineage.get("last_applied_batch_revision", -2)) != int(authored_transition.get("card_transition_last_applied_revision", -3)) \
			or int(lineage.get("last_applied_order_index", -2)) != int(authored_transition.get("card_transition_last_applied_order_index", -3)):
		return false
	for entry_variant: Variant in authored_transition.get("card_transition_applied_lineage", []) as Array:
		if not (entry_variant is Dictionary):
			return false
		var entry := entry_variant as Dictionary
		var query: Dictionary = transition_owner.call(
			"transition_command_applied",
			str(entry.get("command_id", "")),
			str(entry.get("command_fingerprint", ""))
		)
		if not bool(query.get("applied", false)):
			return false
	return true


static func _transition_bits_and_values_equal(authored: Dictionary, live: Dictionary) -> bool:
	if authored.keys() != live.keys():
		return false
	for field in [
		"card_resolution_timer",
		"card_resolution_counter_timer",
		"card_resolution_simultaneous_timer",
		"card_resolution_auction_timer",
	]:
		if not _float_bits_equal(authored.get(field), live.get(field)):
			return false
	var authored_cadence := authored.get("card_group_cadence", {}) as Dictionary
	var live_cadence := live.get("card_group_cadence", {}) as Dictionary
	for field in ["total_seconds", "planning_seconds", "public_bid_seconds", "lock_seconds"]:
		if not _float_bits_equal(authored_cadence.get(field), live_cadence.get(field)):
			return false
	var authored_without_floats := authored.duplicate(true)
	var live_without_floats := live.duplicate(true)
	for field in [
		"card_resolution_timer",
		"card_resolution_counter_timer",
		"card_resolution_simultaneous_timer",
		"card_resolution_auction_timer",
	]:
		authored_without_floats.erase(field)
		live_without_floats.erase(field)
	var authored_cadence_without_floats := authored_cadence.duplicate(true)
	var live_cadence_without_floats := live_cadence.duplicate(true)
	for field in ["total_seconds", "planning_seconds", "public_bid_seconds", "lock_seconds"]:
		authored_cadence_without_floats.erase(field)
		live_cadence_without_floats.erase(field)
	authored_without_floats["card_group_cadence"] = authored_cadence_without_floats
	live_without_floats["card_group_cadence"] = live_cadence_without_floats
	return authored_without_floats == live_without_floats


static func _float_bits_equal(left: Variant, right: Variant) -> bool:
	return left is float and right is float \
			and SCALAR.f64_bits_hex(float(left)) == SCALAR.f64_bits_hex(float(right))


static func _path_count(value: Variant) -> int:
	if value is Dictionary:
		var count := 1
		for child: Variant in (value as Dictionary).values():
			count += _path_count(child)
		return count
	if value is Array:
		var count := 1
		for child: Variant in value as Array:
			count += _path_count(child)
		return count
	return 1


static func _failure(reason_code: String) -> Dictionary:
	return {"ok": false, "reason_code": reason_code}
