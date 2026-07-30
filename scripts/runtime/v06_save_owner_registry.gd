@tool
extends Node
class_name V06SaveOwnerRegistry

const BindingScript := preload("res://scripts/runtime/v06_save_owner_binding_resource.gd")
const CardHistoryRestoreDependencyContractScript := preload("res://scripts/runtime/card_history_restore_dependency_contract.gd")
const CommodityFlowPostCommitRestoreDependencyContractScript := preload("res://scripts/runtime/commodity_flow_postcommit_restore_dependency_contract.gd")

const REGISTRY_ID := "v06_save_owner_registry"
const REGISTRY_VERSION := 2
const SECTION_WRAPPER_KEYS := ["schema_version", "owner_id", "owner_state"]
const PUBLIC_OPERATIONS := ["capture", "preflight", "apply"]
const PUBLIC_REASON_CODES := [
	"registry_busy",
	"owner_registry_invalid",
	"restore_capability_incomplete",
	"owner_capture_failed",
	"captured_envelope_invalid",
	"resume_envelope_captured",
	"envelope_validation_failed",
	"section_wrapper_invalid",
	"owner_preflight_rejected",
	"ruleset_attestation_mismatch",
	"cross_section_dependency_rejected",
	"all_owner_preflights_passed",
	"owner_checkpoint_capture_failed",
	"global_checkpoint_capture_failed",
	"restore_barrier_failed",
	"owner_apply_failed",
	"restore_quiet_window_violated",
	"post_restore_rebind_failed",
	"post_restore_exact_capture_failed",
	"restore_barrier_commit_failed",
	"owners_applied",
]

# Stable semantic section identity and envelope order. Restore order is the
# explicit DAG below; it intentionally is not this serialization order.
const FIXED_SECTION_ORDER := [
	"ruleset",
	"region_infrastructure",
	"region_supply",
	"commodity_flow",
	"routes",
	"player_mana",
	"commodity_belt_visibility",
	"card_inventory",
	"player_organization",
	"monsters",
	"military",
	"weather",
	"card_resolution_queue",
	"card_resolution_execution",
	"card_resolution_history",
	"ai",
	"bankruptcy_neutral_estate",
	"victory_control",
	"session",
]
const AUTHORITATIVE_SECTION_ORDER := [
	"region_infrastructure",
	"region_supply",
	"commodity_flow",
	"player_mana",
	"card_inventory",
	"player_organization",
	"monsters",
	"military",
	"weather",
	"card_resolution_queue",
	"card_resolution_execution",
	"card_resolution_history",
	"ai",
	"bankruptcy_neutral_estate",
	"victory_control",
]
const DERIVED_SECTION_ORDER := ["routes", "commodity_belt_visibility"]
const RESTORE_DAG_NODE_ORDER := [
	"ruleset",
	"session_foundation",
	"region_infrastructure",
	"region_supply",
	"commodity_flow",
	"player_mana",
	"card_inventory",
	"player_organization",
	"monsters",
	"military",
	"weather",
	"card_resolution_queue",
	"card_resolution_execution",
	"card_resolution_history",
	"ai",
	"bankruptcy_neutral_estate",
	"victory_control",
	"routes",
	"commodity_belt_visibility",
	"session_tail",
]

@export var handshake_path: NodePath
@export var restore_barrier_path: NodePath
@export var bindings: Array[BindingScript] = []

var _operation_in_progress := false
var _operation_sequence := 0
var _cross_section_preflight_count := 0
var _cross_section_rejection_count := 0
var _restore_commit_count := 0
var _restore_rollback_count := 0
var _partial_restore_state_count := 0
var _post_restore_rebind_count := 0
var _last_restore_phase := 0
var _last_apply_duration_us := 0
var _last_preflight_duration_us := 0
var _last_owner_apply_count := 0
var _last_registry_apply_count := 0
var _last_internal_capture_failure_section := ""
var _last_internal_capture_failure_reason := ""
var _last_internal_preflight_failure_section := ""
var _last_internal_preflight_failure_reason := ""
var _test_apply_failure_once := ""
var _last_internal_rollback_order: Array[String] = []


func fixed_section_order() -> Array[String]:
	var result: Array[String] = []
	for section_id in FIXED_SECTION_ORDER:
		result.append(str(section_id))
	return result


func restore_dag_node_order() -> Array[String]:
	var result: Array[String] = []
	for node_id in RESTORE_DAG_NODE_ORDER:
		result.append(str(node_id))
	return result


func registry_snapshot() -> Dictionary:
	var analysis := _registry_analysis()
	var barrier := _restore_barrier_node()
	var barrier_debug := _call_dictionary(barrier, "debug_snapshot")
	return {
		"registry_id": REGISTRY_ID,
		"registry_version": REGISTRY_VERSION,
		"valid": bool(analysis.get("valid", false)),
		"resume_ready": bool(analysis.get("resume_ready", false)) and (restore_barrier_path.is_empty() or bool(barrier_debug.get("barrier_ready", false))),
		"required_section_count": FIXED_SECTION_ORDER.size(),
		"binding_count": bindings.size(),
		"transactional_section_count": int(analysis.get("transactional_section_count", 0)),
		"unsupported_section_count": int(analysis.get("unsupported_section_count", 0)),
		"errors": (analysis.get("errors", []) as Array).duplicate(),
		"contracts": (analysis.get("contracts", []) as Array).duplicate(true),
		"fixed_capture_order": FIXED_SECTION_ORDER.duplicate(),
		"restore_dag_node_order": RESTORE_DAG_NODE_ORDER.duplicate(),
		"authoritative_apply_order": AUTHORITATIVE_SECTION_ORDER.duplicate(),
		"derived_apply_order": DERIVED_SECTION_ORDER.duplicate(),
		"restore_barrier_ready": restore_barrier_path.is_empty() or bool(barrier_debug.get("barrier_ready", false)),
		"captures_business_state": false,
		"stores_parallel_owner_state": false,
	}


func capture_resume_envelope(identity: Dictionary) -> Dictionary:
	if _operation_in_progress:
		return _result("capture", false, "registry_busy")
	_operation_in_progress = true
	_operation_sequence += 1
	var result := _capture_resume_envelope_internal(identity)
	_operation_in_progress = false
	return result


func preflight_envelope(envelope: Dictionary) -> Dictionary:
	if _operation_in_progress:
		return _result("preflight", false, "registry_busy")
	_operation_in_progress = true
	_operation_sequence += 1
	var started_us := Time.get_ticks_usec()
	var internal := _preflight_envelope_internal(envelope)
	_last_preflight_duration_us = Time.get_ticks_usec() - started_us
	_operation_in_progress = false
	return {
		"operation": "preflight",
		"ok": bool(internal.get("ok", false)),
		"reason_code": str(internal.get("reason_code", "owner_preflight_rejected")),
		"registry_id": REGISTRY_ID,
		"registry_version": REGISTRY_VERSION,
		"operation_sequence": _operation_sequence,
		"envelope_valid": bool(internal.get("envelope_valid", false)),
		"preflight_complete": bool(internal.get("preflight_complete", false)),
		"preflight_count": int(internal.get("preflight_count", 0)),
		"cross_section_check_count": int(internal.get("cross_section_check_count", 0)),
		"unsupported_count": int(internal.get("unsupported_count", 0)),
		"requires_backup": bool(internal.get("requires_backup", false)),
		"duration_us": _last_preflight_duration_us,
	}


func apply_envelope(envelope: Dictionary) -> Dictionary:
	if _operation_in_progress:
		return _result("apply", false, "registry_busy")
	_operation_in_progress = true
	_operation_sequence += 1
	_last_owner_apply_count = 0
	_last_registry_apply_count = 0
	_last_restore_phase = 0
	var apply_started_us := Time.get_ticks_usec()
	var preflight_started_us := Time.get_ticks_usec()
	var preflight := _preflight_envelope_internal(envelope)
	_last_preflight_duration_us = Time.get_ticks_usec() - preflight_started_us
	if not bool(preflight.get("ok", false)):
		_operation_in_progress = false
		return _apply_rejection_from_preflight(preflight)

	_last_restore_phase = 2
	var analysis := _registry_analysis()
	var binding_by_section: Dictionary = analysis.get("binding_by_section", {})
	var plan: Dictionary = preflight.get("plan", {})
	var checkpoints: Dictionary = {}
	for section_id in FIXED_SECTION_ORDER:
		var binding := binding_by_section.get(section_id) as BindingScript
		var checkpoint := _capture_owner_checkpoint(binding)
		if not bool(checkpoint.get("ok", false)):
			_operation_in_progress = false
			var checkpoint_rejected := _result("apply", false, "owner_checkpoint_capture_failed")
			checkpoint_rejected["envelope_valid"] = true
			checkpoint_rejected["preflight_complete"] = true
			checkpoint_rejected["preflight_count"] = int(preflight.get("preflight_count", 0))
			checkpoint_rejected["failing_section_id"] = section_id
			return checkpoint_rejected
		checkpoints[section_id] = checkpoint

	var operation_id := "v06-restore-%d" % _operation_sequence
	var global_capture := _capture_global_checkpoint(operation_id)
	if not bool(global_capture.get("accepted", false)):
		_operation_in_progress = false
		var global_rejected := _result("apply", false, "global_checkpoint_capture_failed")
		global_rejected["envelope_valid"] = true
		global_rejected["preflight_complete"] = true
		global_rejected["preflight_count"] = int(preflight.get("preflight_count", 0))
		return global_rejected

	_last_restore_phase = 3
	var barrier_enter := _enter_restore_barrier(operation_id, global_capture.get("checkpoint", {}) as Dictionary)
	if not bool(barrier_enter.get("acquired", false)):
		_operation_in_progress = false
		var barrier_rejected := _result("apply", false, "restore_barrier_failed")
		barrier_rejected["envelope_valid"] = true
		barrier_rejected["preflight_complete"] = true
		barrier_rejected["preflight_count"] = int(preflight.get("preflight_count", 0))
		return barrier_rejected

	var touched_sections: Array[String] = []
	var owner_apply_count := 0
	var ruleset_apply := _apply_planned_section("ruleset", plan, binding_by_section)
	touched_sections.append("ruleset")
	if not bool(ruleset_apply.get("applied", false)) or _consume_test_failure("ruleset"):
		return _rollback_failed_apply("ruleset", operation_id, touched_sections, checkpoints, binding_by_section, plan, owner_apply_count)
	owner_apply_count += 1

	_last_restore_phase = 4
	var session_binding := binding_by_section.get("session") as BindingScript
	var session_owner := get_node_or_null(session_binding.owner_path) if session_binding != null else null
	var session_planned: Dictionary = plan.get("session", {}) if plan.get("session", {}) is Dictionary else {}
	var session_state := (session_planned.get("normalized_owner_state", {}) as Dictionary).duplicate(true)
	var session_has_split_restore := session_owner != null \
		and session_owner.has_method("apply_restore_foundation") \
		and session_owner.has_method("finalize_restore_tail")
	if session_has_split_restore:
		touched_sections.append("session")
		var foundation := _call_dictionary(session_owner, "apply_restore_foundation", [session_state])
		if not bool(foundation.get("applied", false)) or _consume_test_failure("session_foundation"):
			return _rollback_failed_apply("session", operation_id, touched_sections, checkpoints, binding_by_section, plan, owner_apply_count)

	_last_restore_phase = 5
	for section_id in AUTHORITATIVE_SECTION_ORDER:
		touched_sections.append(section_id)
		var applied := _apply_planned_section(section_id, plan, binding_by_section)
		if not bool(applied.get("applied", false)) or _consume_test_failure(section_id):
			return _rollback_failed_apply(section_id, operation_id, touched_sections, checkpoints, binding_by_section, plan, owner_apply_count)
		owner_apply_count += 1

	_last_restore_phase = 6
	for section_id in DERIVED_SECTION_ORDER:
		touched_sections.append(section_id)
		var applied := _apply_planned_section(section_id, plan, binding_by_section)
		if not bool(applied.get("applied", false)) or _consume_test_failure(section_id):
			return _rollback_failed_apply(section_id, operation_id, touched_sections, checkpoints, binding_by_section, plan, owner_apply_count)
		owner_apply_count += 1

	_last_restore_phase = 7
	if session_has_split_restore:
		var tail := _call_dictionary(session_owner, "finalize_restore_tail", [session_state])
		if not bool(tail.get("applied", false)) or _consume_test_failure("session") or _consume_test_failure("session_tail"):
			return _rollback_failed_apply("session", operation_id, touched_sections, checkpoints, binding_by_section, plan, owner_apply_count)
	else:
		touched_sections.append("session")
		var session_apply := _apply_planned_section("session", plan, binding_by_section)
		if not bool(session_apply.get("applied", false)) or _consume_test_failure("session"):
			return _rollback_failed_apply("session", operation_id, touched_sections, checkpoints, binding_by_section, plan, owner_apply_count)
	owner_apply_count += 1

	var quiet := _verify_restore_quiet(operation_id)
	if not bool(quiet.get("accepted", false)):
		return _rollback_failed_apply("restore_quiet_window", operation_id, touched_sections, checkpoints, binding_by_section, plan, owner_apply_count, "restore_quiet_window_violated")
	var exact := _verify_plan_exact(plan, binding_by_section, true)
	if not bool(exact.get("exact", false)):
		return _rollback_failed_apply(str(exact.get("failing_section_id", "post_restore_exact_capture")), operation_id, touched_sections, checkpoints, binding_by_section, plan, owner_apply_count, "post_restore_exact_capture_failed")

	_last_restore_phase = 8
	var rebind_started_us := Time.get_ticks_usec()
	var rebind := _post_restore_rebind(operation_id)
	var rebind_duration_us := Time.get_ticks_usec() - rebind_started_us
	if not bool(rebind.get("applied", false)):
		return _rollback_failed_apply("post_restore_rebind", operation_id, touched_sections, checkpoints, binding_by_section, plan, owner_apply_count, "post_restore_rebind_failed")
	_post_restore_rebind_count += 1

	_last_restore_phase = 9
	var barrier_commit := _commit_restore_barrier(operation_id)
	if not bool(barrier_commit.get("committed", false)):
		return _rollback_failed_apply("restore_barrier_commit", operation_id, touched_sections, checkpoints, binding_by_section, plan, owner_apply_count, "restore_barrier_commit_failed")

	_restore_commit_count += 1
	_last_apply_duration_us = Time.get_ticks_usec() - apply_started_us
	_operation_in_progress = false
	var success := _result("apply", true, "owners_applied")
	success["envelope_valid"] = true
	success["preflight_complete"] = true
	success["preflight_count"] = int(preflight.get("preflight_count", 0))
	success["apply_count"] = owner_apply_count
	success["registry_apply_count"] = 1
	_last_owner_apply_count = owner_apply_count
	_last_registry_apply_count = 1
	success["rollback_attempted"] = false
	success["rollback_complete"] = true
	success["restore_phase_count"] = 10
	success["post_restore_rebind_count"] = 1
	success["post_restore_full_refresh_count"] = int(rebind.get("full_refresh_count", 0))
	success["preflight_duration_us"] = _last_preflight_duration_us
	success["post_restore_rebind_duration_us"] = rebind_duration_us
	success["apply_duration_us"] = _last_apply_duration_us
	return success


func arm_test_apply_failure_once(section_or_phase_id: String) -> bool:
	var normalized := section_or_phase_id.strip_edges()
	if normalized not in FIXED_SECTION_ORDER and normalized not in ["session_foundation", "session_tail"]:
		return false
	_test_apply_failure_once = normalized
	return true


func clear_test_apply_failure() -> void:
	_test_apply_failure_once = ""


func public_operation_receipt(receipt: Dictionary) -> Dictionary:
	var operation := str(receipt.get("operation", ""))
	var reason_code := str(receipt.get("reason_code", ""))
	var receipt_shape_valid := PUBLIC_OPERATIONS.has(operation) \
		and PUBLIC_REASON_CODES.has(reason_code) \
		and str(receipt.get("registry_id", "")) == REGISTRY_ID \
		and _public_nonnegative_int(receipt.get("registry_version")) == REGISTRY_VERSION
	var result := {
		"operation": operation if PUBLIC_OPERATIONS.has(operation) else "unknown",
		"ok": receipt_shape_valid and _public_bool(receipt.get("ok")),
		"reason_code": reason_code if receipt_shape_valid else "registry_receipt_invalid",
		"registry_id": REGISTRY_ID,
		"registry_version": REGISTRY_VERSION,
		"operation_sequence": _public_nonnegative_int(receipt.get("operation_sequence")),
	}
	for key in ["envelope_valid", "preflight_complete", "rollback_attempted", "rollback_complete", "requires_backup"]:
		if receipt.has(key):
			result[key] = _public_bool(receipt.get(key))
	for key in ["preflight_count", "apply_count", "unsupported_count", "registry_apply_count", "restore_phase_count", "post_restore_rebind_count", "post_restore_full_refresh_count"]:
		if receipt.has(key):
			result[key] = _public_nonnegative_int(receipt.get(key))
	return result


func debug_snapshot() -> Dictionary:
	var snapshot := registry_snapshot()
	snapshot["operation_in_progress"] = _operation_in_progress
	snapshot["operation_sequence"] = _operation_sequence
	snapshot["pure_data_capture"] = true
	snapshot["global_preflight_before_apply"] = true
	snapshot["all_checkpoints_before_mutation"] = true
	snapshot["cross_section_preflight_before_apply"] = true
	snapshot["cross_section_preflight_count"] = _cross_section_preflight_count
	snapshot["cross_section_rejection_count"] = _cross_section_rejection_count
	snapshot["cross_section_preflight_reads_live_owners"] = false
	snapshot["reverse_order_rollback"] = true
	snapshot["session_foundation_before_domains"] = true
	snapshot["session_tail_after_domains"] = true
	snapshot["restore_commit_count"] = _restore_commit_count
	snapshot["restore_rollback_count"] = _restore_rollback_count
	snapshot["partial_restore_state_count"] = _partial_restore_state_count
	snapshot["post_restore_rebind_count"] = _post_restore_rebind_count
	snapshot["last_restore_phase"] = _last_restore_phase
	snapshot["last_preflight_duration_us"] = _last_preflight_duration_us
	snapshot["last_apply_duration_us"] = _last_apply_duration_us
	snapshot["last_owner_apply_count"] = _last_owner_apply_count
	snapshot["last_registry_apply_count"] = _last_registry_apply_count
	snapshot["last_internal_capture_failure_section"] = _last_internal_capture_failure_section
	snapshot["last_internal_capture_failure_reason"] = _last_internal_capture_failure_reason
	snapshot["last_internal_preflight_failure_section"] = _last_internal_preflight_failure_section
	snapshot["last_internal_preflight_failure_reason"] = _last_internal_preflight_failure_reason
	snapshot["last_internal_rollback_order"] = _last_internal_rollback_order.duplicate()
	snapshot["public_receipt_allowlisted"] = true
	return snapshot


func _capture_resume_envelope_internal(identity: Dictionary) -> Dictionary:
	_last_internal_capture_failure_section = ""
	_last_internal_capture_failure_reason = ""
	var analysis := _registry_analysis()
	if not bool(analysis.get("valid", false)):
		return _result("capture", false, "owner_registry_invalid")
	if not bool(analysis.get("resume_ready", false)) or not bool(registry_snapshot().get("resume_ready", false)):
		var unsupported := _result("capture", false, "restore_capability_incomplete")
		unsupported["unsupported_count"] = int(analysis.get("unsupported_section_count", 0))
		unsupported["unsupported_section_ids"] = (analysis.get("unsupported_section_ids", []) as Array).duplicate()
		return unsupported
	var handshake := _handshake_node()
	var binding_by_section: Dictionary = analysis.get("binding_by_section", {})
	var session_section: Dictionary = {}
	var domain_sections: Dictionary = {}
	var plan: Dictionary = {}
	for section_id in FIXED_SECTION_ORDER:
		var binding := binding_by_section.get(section_id) as BindingScript
		var captured := _capture_owner_checkpoint(binding)
		if not bool(captured.get("ok", false)):
			return _capture_rejection(section_id, str(captured.get("reason_code", "owner_checkpoint_capture_failed")))
		var owner := get_node_or_null(binding.owner_path) if binding != null else null
		var owner_preflight := _preflight_owner(owner, binding, captured.get("raw_owner_state", {}) as Dictionary)
		if not bool(owner_preflight.get("ok", false)):
			return _capture_rejection(section_id, str(owner_preflight.get("reason_code", "owner_preflight_rejected")))
		plan[section_id] = {
			"decoded_owner_state": (captured.get("raw_owner_state", {}) as Dictionary).duplicate(true),
			"normalized_owner_state": (owner_preflight.get("normalized_owner_state", {}) as Dictionary).duplicate(true),
			"normalized_encoded_owner_state": owner_preflight.get("normalized_encoded_owner_state"),
		}
		var wrapper := {
			"schema_version": binding.state_version,
			"owner_id": binding.owner_id,
			"owner_state": owner_preflight.get("normalized_encoded_owner_state"),
		}
		if section_id == "session":
			session_section = wrapper
		else:
			domain_sections[section_id] = wrapper
	var dependency_preflight := _preflight_cross_section_dependencies(plan, binding_by_section)
	if not bool(dependency_preflight.get("accepted", false)):
		_cross_section_rejection_count += 1
		return _capture_rejection(
			str(dependency_preflight.get("failing_section_id", "cross_section")),
			str(dependency_preflight.get("internal_reason_code", dependency_preflight.get("reason_code", "cross_section_dependency_rejected")))
		)
	var envelope := _call_dictionary(handshake, "compose_v06_envelope", [session_section, domain_sections, identity])
	var validation := _call_dictionary(handshake, "validate_envelope", [envelope])
	if envelope.is_empty() or not bool(validation.get("valid", false)):
		return _result("capture", false, "captured_envelope_invalid")
	var success := _result("capture", true, "resume_envelope_captured")
	success["envelope_valid"] = true
	success["envelope"] = envelope
	success["fingerprint"] = str(validation.get("fingerprint", ""))
	return success


func _capture_rejection(section_id: String, internal_reason_code: String) -> Dictionary:
	_last_internal_capture_failure_section = section_id
	_last_internal_capture_failure_reason = internal_reason_code
	var rejected := _result("capture", false, "owner_capture_failed")
	rejected["failing_section_id"] = section_id
	rejected["internal_reason_code"] = internal_reason_code
	return rejected


func _preflight_envelope_internal(envelope: Dictionary) -> Dictionary:
	_last_restore_phase = 0
	_last_internal_preflight_failure_section = ""
	_last_internal_preflight_failure_reason = ""
	var analysis := _registry_analysis()
	if not bool(analysis.get("valid", false)):
		return {"ok": false, "reason_code": "owner_registry_invalid", "envelope_valid": false, "preflight_complete": false}
	var validation := _call_dictionary(_handshake_node(), "validate_envelope", [envelope])
	if not bool(validation.get("valid", false)):
		return {"ok": false, "reason_code": "envelope_validation_failed", "envelope_valid": false, "preflight_complete": false}
	if not bool(analysis.get("resume_ready", false)) or not bool(registry_snapshot().get("resume_ready", false)):
		return {
			"ok": false,
			"reason_code": "restore_capability_incomplete",
			"envelope_valid": true,
			"preflight_complete": false,
			"unsupported_count": int(analysis.get("unsupported_section_count", 0)),
		}
	_last_restore_phase = 1
	var sections: Dictionary = envelope.get("sections", {}) if envelope.get("sections", {}) is Dictionary else {}
	var binding_by_section: Dictionary = analysis.get("binding_by_section", {})
	var plan: Dictionary = {}
	var preflight_count := 0
	for section_id in FIXED_SECTION_ORDER:
		var binding := binding_by_section.get(section_id) as BindingScript
		var decoded := _decode_section_wrapper(sections.get(section_id), binding)
		if not bool(decoded.get("ok", false)):
			_last_internal_preflight_failure_section = section_id
			_last_internal_preflight_failure_reason = str(decoded.get("reason_code", "section_wrapper_invalid"))
			return {"ok": false, "reason_code": "section_wrapper_invalid", "envelope_valid": true, "preflight_complete": false, "preflight_count": preflight_count}
		var owner := get_node_or_null(binding.owner_path)
		var owner_preflight := _preflight_owner(owner, binding, decoded.get("owner_state", {}) as Dictionary)
		if not bool(owner_preflight.get("ok", false)):
			var owner_reason := str(owner_preflight.get("reason_code", "owner_preflight_rejected"))
			_last_internal_preflight_failure_section = section_id
			_last_internal_preflight_failure_reason = owner_reason
			var public_reason := "ruleset_attestation_mismatch" \
				if section_id == "ruleset" and owner_reason == "ruleset_attestation_mismatch" \
				else "owner_preflight_rejected"
			return {"ok": false, "reason_code": public_reason, "envelope_valid": true, "preflight_complete": false, "preflight_count": preflight_count, "failing_section_id": section_id, "requires_backup": bool(owner_preflight.get("requires_backup", false))}
		plan[section_id] = {
			"decoded_owner_state": (decoded.get("owner_state", {}) as Dictionary).duplicate(true),
			"normalized_owner_state": (owner_preflight.get("normalized_owner_state", {}) as Dictionary).duplicate(true),
			"normalized_encoded_owner_state": owner_preflight.get("normalized_encoded_owner_state"),
		}
		preflight_count += 1
	var dependency_preflight := _preflight_cross_section_dependencies(plan, binding_by_section)
	if not bool(dependency_preflight.get("accepted", false)):
		_cross_section_rejection_count += 1
		_last_internal_preflight_failure_section = str(dependency_preflight.get("failing_section_id", "cross_section"))
		_last_internal_preflight_failure_reason = str(dependency_preflight.get("internal_reason_code", dependency_preflight.get("reason_code", "cross_section_dependency_rejected")))
		return {
			"ok": false,
			"reason_code": "cross_section_dependency_rejected",
			"envelope_valid": true,
			"preflight_complete": false,
			"preflight_count": preflight_count,
			"cross_section_check_count": int(dependency_preflight.get("check_count", 0)),
		}
	return {
		"ok": true,
		"reason_code": "all_owner_preflights_passed",
		"envelope_valid": true,
		"preflight_complete": true,
		"preflight_count": preflight_count,
		"cross_section_check_count": int(dependency_preflight.get("check_count", 0)),
		"plan": plan,
	}


func _preflight_owner(owner: Node, binding: BindingScript, owner_state: Dictionary) -> Dictionary:
	if owner == null:
		return {"ok": false}
	if not binding.preflight_method.is_empty():
		var preflight_receipt := _call_dictionary(owner, binding.preflight_method, [owner_state.duplicate(true)])
		if not bool(preflight_receipt.get("accepted", false)):
			return {"ok": false, "reason_code": str(preflight_receipt.get("reason_code", "owner_preflight_rejected")), "requires_backup": bool(preflight_receipt.get("requires_backup", false))}
		var normalized := owner_state.duplicate(true)
		if preflight_receipt.has("normalized_state"):
			if not (preflight_receipt.get("normalized_state") is Dictionary):
				return {"ok": false, "reason_code": "owner_preflight_normalized_state_invalid"}
			normalized = (preflight_receipt.get("normalized_state") as Dictionary).duplicate(true)
		var encoded := _encode_owner_state(normalized)
		return {
			"ok": bool(encoded.get("ok", false)),
			"reason_code": "owner_state_encode_failed" if not bool(encoded.get("ok", false)) else "owner_preflight_accepted",
			"normalized_owner_state": normalized,
			"normalized_encoded_owner_state": encoded.get("value"),
		}
	var probe_variant: Variant = owner.duplicate()
	if not (probe_variant is Node):
		return {"ok": false}
	var probe := probe_variant as Node
	var apply_receipt := _call_dictionary(probe, binding.apply_method, [owner_state.duplicate(true)])
	if not bool(apply_receipt.get("applied", false)):
		probe.free()
		return {"ok": false}
	var normalized_variant: Variant = probe.call(binding.capture_method)
	var normalized_state: Dictionary = (normalized_variant as Dictionary).duplicate(true) if normalized_variant is Dictionary else {}
	var encoded := _encode_owner_state(normalized_state)
	probe.free()
	return {
		"ok": bool(encoded.get("ok", false)),
		"normalized_owner_state": normalized_state,
		"normalized_encoded_owner_state": encoded.get("value"),
	}


func _preflight_cross_section_dependencies(plan: Dictionary, binding_by_section: Dictionary) -> Dictionary:
	_cross_section_preflight_count += 1
	var check_count := 0
	var normalized_states: Dictionary = {}
	for section_id in FIXED_SECTION_ORDER:
		var planned: Dictionary = plan.get(section_id, {}) if plan.get(section_id, {}) is Dictionary else {}
		if not (planned.get("normalized_owner_state") is Dictionary):
			return {"accepted": false, "reason_code": "normalized_section_missing", "check_count": check_count}
		normalized_states[section_id] = (planned.get("normalized_owner_state", {}) as Dictionary).duplicate(true)

	var history_state := normalized_states.get("card_resolution_history", {}) as Dictionary
	var session_state := normalized_states.get("session", {}) as Dictionary
	var annotation_state: Dictionary = session_state.get("card_history_private_annotations", {}) \
		if session_state.get("card_history_private_annotations", {}) is Dictionary else {}
	var history_dependency := CardHistoryRestoreDependencyContractScript.validate_annotation_dependency(annotation_state, history_state)
	check_count += 1
	if not bool(history_dependency.get("accepted", false)):
		return {
			"accepted": false,
			"reason_code": "cross_section_dependency_rejected",
			"failing_section_id": "card_resolution_history",
			"internal_reason_code": str(history_dependency.get("reason_code", "card_history_annotation_dependency_rejected")),
			"check_count": check_count,
		}

	var commodity_dependency := CommodityFlowPostCommitRestoreDependencyContractScript.validate_dependencies(
		(normalized_states.get("commodity_flow", {}) as Dictionary).duplicate(true),
		session_state.duplicate(true),
		(normalized_states.get("bankruptcy_neutral_estate", {}) as Dictionary).duplicate(true),
		(normalized_states.get("player_mana", {}) as Dictionary).duplicate(true)
	)
	check_count += 1
	if not bool(commodity_dependency.get("accepted", false)):
		return {
			"accepted": false,
			"reason_code": "cross_section_dependency_rejected",
			"failing_section_id": "commodity_flow",
			"internal_reason_code": str(commodity_dependency.get("reason_code", "commodity_flow_dependency_rejected")),
			"check_count": check_count,
		}

	for section_id in FIXED_SECTION_ORDER:
		var binding := binding_by_section.get(section_id) as BindingScript
		var owner := get_node_or_null(binding.owner_path) if binding != null else null
		if owner == null or not owner.has_method("preflight_restore_dependencies"):
			continue
		var dependency := _call_dictionary(owner, "preflight_restore_dependencies", [
			(normalized_states.get(section_id, {}) as Dictionary).duplicate(true),
			normalized_states.duplicate(true),
		])
		check_count += 1
		if not bool(dependency.get("accepted", false)):
			return {
				"accepted": false,
				"reason_code": "cross_section_dependency_rejected",
				"failing_section_id": section_id,
				"internal_reason_code": str(dependency.get("reason_code", "owner_restore_dependency_rejected")),
				"check_count": check_count,
			}
	return {"accepted": true, "reason_code": "cross_section_dependencies_valid", "check_count": check_count}


func _apply_planned_section(section_id: String, plan: Dictionary, binding_by_section: Dictionary) -> Dictionary:
	var binding := binding_by_section.get(section_id) as BindingScript
	var owner := get_node_or_null(binding.owner_path) if binding != null else null
	var planned: Dictionary = plan.get(section_id, {}) if plan.get(section_id, {}) is Dictionary else {}
	if owner == null or binding == null:
		return {"applied": false, "reason_code": "owner_missing"}
	return _call_dictionary(owner, binding.apply_method, [(planned.get("normalized_owner_state", {}) as Dictionary).duplicate(true)])


func _capture_owner_checkpoint(binding: BindingScript, restore_verification := false) -> Dictionary:
	var owner := get_node_or_null(binding.owner_path) if binding != null else null
	if owner == null:
		return {"ok": false}
	var capture_method := binding.capture_method
	if restore_verification and binding.section_id == "session" and owner.has_method("capture_restore_verification_state"):
		capture_method = "capture_restore_verification_state"
	if capture_method.is_empty() or not owner.has_method(capture_method):
		return {"ok": false}
	var raw_variant: Variant = owner.call(capture_method)
	if not (raw_variant is Dictionary):
		return {"ok": false}
	var raw_state := (raw_variant as Dictionary).duplicate(true)
	var encoded := _encode_owner_state(raw_state)
	var rollback_checkpoint := raw_state.duplicate(true)
	if not binding.checkpoint_method.is_empty():
		if not owner.has_method(binding.checkpoint_method):
			return {"ok": false}
		var checkpoint_variant: Variant = owner.call(binding.checkpoint_method)
		if not (checkpoint_variant is Dictionary):
			return {"ok": false}
		rollback_checkpoint = (checkpoint_variant as Dictionary).duplicate(true)
		if not bool(_encode_owner_state(rollback_checkpoint).get("ok", false)):
			return {"ok": false}
	return {
		"ok": bool(encoded.get("ok", false)),
		"raw_owner_state": raw_state,
		"rollback_checkpoint": rollback_checkpoint,
		"encoded_owner_state": encoded.get("value"),
	}


func _verify_plan_exact(plan: Dictionary, binding_by_section: Dictionary, restore_verification: bool) -> Dictionary:
	for section_id in FIXED_SECTION_ORDER:
		var binding := binding_by_section.get(section_id) as BindingScript
		var after := _capture_owner_checkpoint(binding, restore_verification)
		var planned: Dictionary = plan.get(section_id, {}) if plan.get(section_id, {}) is Dictionary else {}
		if not bool(after.get("ok", false)) \
				or not _same_encoded_state(after.get("encoded_owner_state"), planned.get("normalized_encoded_owner_state")):
			return {"exact": false, "failing_section_id": section_id}
	return {"exact": true, "failing_section_id": ""}


func _rollback_failed_apply(
	failing_section_id: String,
	operation_id: String,
	touched_sections: Array[String],
	checkpoints: Dictionary,
	binding_by_section: Dictionary,
	_plan: Dictionary,
	owner_apply_count: int,
	reason_code := "owner_apply_failed"
) -> Dictionary:
	var rollback := _rollback_sections(touched_sections, checkpoints, binding_by_section)
	_last_internal_rollback_order.clear()
	for section_variant in rollback.get("section_ids", []) as Array:
		_last_internal_rollback_order.append(str(section_variant))
	var global_rollback := _rollback_restore_barrier(operation_id)
	var residual := _verify_checkpoints_exact(checkpoints, binding_by_section)
	var complete := bool(rollback.get("complete", false)) \
		and bool(global_rollback.get("applied", false)) \
		and bool(residual.get("exact", false))
	if not bool(residual.get("exact", false)):
		_partial_restore_state_count += int(residual.get("mismatch_count", 0))
	_restore_rollback_count += 1
	_last_apply_duration_us = 0
	_operation_in_progress = false
	var failed := _result("apply", false, reason_code)
	failed["envelope_valid"] = true
	failed["preflight_complete"] = true
	failed["apply_count"] = owner_apply_count
	failed["failing_section_id"] = failing_section_id
	failed["rollback_attempted"] = true
	failed["rollback_complete"] = complete
	failed["rollback_section_count"] = int((rollback.get("section_ids", []) as Array).size())
	failed["partial_restore_state_count"] = int(residual.get("mismatch_count", 0))
	return failed


func _rollback_sections(touched_sections: Array[String], checkpoints: Dictionary, binding_by_section: Dictionary) -> Dictionary:
	var rollback_section_ids: Array[String] = []
	var failures: Array[String] = []
	var unique_reversed: Array[String] = []
	var seen: Dictionary = {}
	for index in range(touched_sections.size() - 1, -1, -1):
		var section_id := touched_sections[index]
		if seen.has(section_id):
			continue
		seen[section_id] = true
		unique_reversed.append(section_id)
	for section_id in unique_reversed:
		var binding := binding_by_section.get(section_id) as BindingScript
		var owner := get_node_or_null(binding.owner_path) if binding != null else null
		var checkpoint: Dictionary = checkpoints.get(section_id, {}) if checkpoints.get(section_id, {}) is Dictionary else {}
		var rollback_receipt := _call_dictionary(owner, binding.rollback_method, [(checkpoint.get("rollback_checkpoint", checkpoint.get("raw_owner_state", {})) as Dictionary).duplicate(true)]) if binding != null else {}
		var after := _capture_owner_checkpoint(binding, true)
		var restored_exactly := (bool(rollback_receipt.get("applied", false)) or bool(rollback_receipt.get("restored", false))) \
			and bool(after.get("ok", false)) \
			and _same_encoded_state(after.get("encoded_owner_state"), checkpoint.get("encoded_owner_state"))
		if not restored_exactly:
			failures.append(section_id)
		rollback_section_ids.append(section_id)
	return {"complete": failures.is_empty(), "section_ids": rollback_section_ids, "failures": failures}


func _verify_checkpoints_exact(checkpoints: Dictionary, binding_by_section: Dictionary) -> Dictionary:
	var mismatches: Array[String] = []
	for section_id in FIXED_SECTION_ORDER:
		var binding := binding_by_section.get(section_id) as BindingScript
		var after := _capture_owner_checkpoint(binding)
		var checkpoint: Dictionary = checkpoints.get(section_id, {}) if checkpoints.get(section_id, {}) is Dictionary else {}
		if not bool(after.get("ok", false)) \
				or not _same_encoded_state(after.get("encoded_owner_state"), checkpoint.get("encoded_owner_state")):
			mismatches.append(section_id)
	return {"exact": mismatches.is_empty(), "mismatch_count": mismatches.size(), "section_ids": mismatches}


func _capture_global_checkpoint(operation_id: String) -> Dictionary:
	var barrier := _restore_barrier_node()
	if barrier == null:
		return {"accepted": restore_barrier_path.is_empty(), "reason_code": "restore_barrier_not_configured", "checkpoint": {"operation_id": operation_id}}
	return _call_dictionary(barrier, "capture_global_checkpoint", [operation_id])


func _enter_restore_barrier(operation_id: String, checkpoint: Dictionary) -> Dictionary:
	var barrier := _restore_barrier_node()
	if barrier == null:
		return {"acquired": restore_barrier_path.is_empty(), "reason_code": "restore_barrier_not_configured"}
	return _call_dictionary(barrier, "enter_restore_barrier", [operation_id, checkpoint])


func _verify_restore_quiet(operation_id: String) -> Dictionary:
	var barrier := _restore_barrier_node()
	return _call_dictionary(barrier, "verify_restore_quiet", [operation_id]) if barrier != null else {"accepted": restore_barrier_path.is_empty(), "reason_code": "restore_barrier_not_configured"}


func _post_restore_rebind(operation_id: String) -> Dictionary:
	var barrier := _restore_barrier_node()
	return _call_dictionary(barrier, "post_restore_rebind", [operation_id]) if barrier != null else {"applied": restore_barrier_path.is_empty(), "reason_code": "restore_barrier_not_configured", "full_refresh_count": 0}


func _commit_restore_barrier(operation_id: String) -> Dictionary:
	var barrier := _restore_barrier_node()
	return _call_dictionary(barrier, "commit_restore_barrier", [operation_id]) if barrier != null else {"committed": restore_barrier_path.is_empty(), "reason_code": "restore_barrier_not_configured"}


func _rollback_restore_barrier(operation_id: String) -> Dictionary:
	var barrier := _restore_barrier_node()
	return _call_dictionary(barrier, "rollback_restore_barrier", [operation_id]) if barrier != null else {"applied": restore_barrier_path.is_empty(), "reason_code": "restore_barrier_not_configured"}


func _decode_section_wrapper(value: Variant, binding: BindingScript) -> Dictionary:
	if not (value is Dictionary):
		return {"ok": false}
	var wrapper := value as Dictionary
	if wrapper.keys().size() != SECTION_WRAPPER_KEYS.size():
		return {"ok": false}
	for key in SECTION_WRAPPER_KEYS:
		if not wrapper.has(key):
			return {"ok": false}
	if int(wrapper.get("schema_version", 0)) != binding.state_version or str(wrapper.get("owner_id", "")) != binding.owner_id:
		return {"ok": false}
	var decoded := _call_dictionary(_handshake_node(), "decode_codec_value", [wrapper.get("owner_state")])
	if not bool(decoded.get("ok", false)) or not (decoded.get("value") is Dictionary):
		return {"ok": false}
	return {"ok": true, "owner_state": (decoded.get("value") as Dictionary).duplicate(true)}


func _encode_owner_state(owner_state: Dictionary) -> Dictionary:
	return _call_dictionary(_handshake_node(), "encode_codec_value", [owner_state])


func _same_encoded_state(left: Variant, right: Variant) -> bool:
	var handshake := _handshake_node()
	if handshake == null or not handshake.has_method("canonical_json"):
		return false
	var left_canonical := str(handshake.call("canonical_json", left))
	var right_canonical := str(handshake.call("canonical_json", right))
	return not left_canonical.is_empty() and left_canonical == right_canonical


func _registry_analysis() -> Dictionary:
	var errors: Array[String] = []
	var contracts: Array[Dictionary] = []
	var binding_by_section: Dictionary = {}
	var owner_ids: Dictionary = {}
	var transactional_owner_instances: Dictionary = {}
	var unsupported_section_ids: Array[String] = []
	var transactional_count := 0
	var handshake := _handshake_node()
	var manifest: Dictionary = _call_dictionary(handshake, "required_section_manifest")
	if manifest.is_empty():
		errors.append("handshake_manifest_unavailable")
	if bindings.size() != FIXED_SECTION_ORDER.size():
		errors.append("binding_count_mismatch")
	for binding in bindings:
		if binding == null or binding.section_id.is_empty() or binding.owner_id.is_empty():
			errors.append("binding_incomplete")
			continue
		if binding_by_section.has(binding.section_id):
			errors.append("duplicate_section_binding")
			continue
		binding_by_section[binding.section_id] = binding
		if owner_ids.has(binding.owner_id):
			errors.append("duplicate_owner_binding")
		else:
			owner_ids[binding.owner_id] = true
		if not FIXED_SECTION_ORDER.has(binding.section_id):
			errors.append("unknown_section_binding")
		var contract: Dictionary = manifest.get(binding.section_id, {}) if manifest.get(binding.section_id, {}) is Dictionary else {}
		if contract.is_empty() or str(contract.get("owner_id", "")) != binding.owner_id or int(contract.get("state_version", 0)) != binding.state_version:
			errors.append("binding_manifest_mismatch")
		if binding.is_transactional():
			var owner := get_node_or_null(binding.owner_path)
			if owner == null or binding.capture_method.is_empty() or binding.apply_method.is_empty() or binding.rollback_method.is_empty() \
					or not owner.has_method(binding.capture_method) or not owner.has_method(binding.apply_method) or not owner.has_method(binding.rollback_method):
				errors.append("transactional_owner_api_missing")
			elif not binding.preflight_method.is_empty() and not owner.has_method(binding.preflight_method):
				errors.append("transactional_owner_preflight_api_missing")
			elif not binding.checkpoint_method.is_empty() and not owner.has_method(binding.checkpoint_method):
				errors.append("transactional_owner_checkpoint_api_missing")
			else:
				var owner_instance_id := str(owner.get_instance_id())
				if transactional_owner_instances.has(owner_instance_id):
					errors.append("transactional_owner_instance_reused")
				else:
					transactional_owner_instances[owner_instance_id] = true
			transactional_count += 1
		elif binding.restore_mode == BindingScript.RESTORE_UNSUPPORTED and not binding.unsupported_reason.strip_edges().is_empty():
			unsupported_section_ids.append(binding.section_id)
		else:
			errors.append("restore_mode_invalid")
		contracts.append(binding.contract_snapshot())
	for section_id in FIXED_SECTION_ORDER:
		if not binding_by_section.has(section_id):
			errors.append("required_binding_missing")
	errors = _unique_sorted_strings(errors)
	unsupported_section_ids.sort()
	return {
		"valid": errors.is_empty(),
		"resume_ready": errors.is_empty() and unsupported_section_ids.is_empty(),
		"errors": errors,
		"contracts": contracts,
		"binding_by_section": binding_by_section,
		"transactional_section_count": transactional_count,
		"unsupported_section_count": unsupported_section_ids.size(),
		"unsupported_section_ids": unsupported_section_ids,
	}


func _apply_rejection_from_preflight(preflight: Dictionary) -> Dictionary:
	var rejected := _result("apply", false, str(preflight.get("reason_code", "owner_preflight_rejected")))
	rejected["envelope_valid"] = bool(preflight.get("envelope_valid", false))
	rejected["preflight_complete"] = false
	rejected["preflight_count"] = int(preflight.get("preflight_count", 0))
	rejected["unsupported_count"] = int(preflight.get("unsupported_count", 0))
	rejected["requires_backup"] = bool(preflight.get("requires_backup", false))
	return rejected


func _consume_test_failure(section_or_phase_id: String) -> bool:
	if _test_apply_failure_once != section_or_phase_id:
		return false
	_test_apply_failure_once = ""
	return true


func _handshake_node() -> Node:
	return get_node_or_null(handshake_path) if not handshake_path.is_empty() else null


func _restore_barrier_node() -> Node:
	return get_node_or_null(restore_barrier_path) if not restore_barrier_path.is_empty() else null


func _call_dictionary(target: Node, method: String, args: Array = []) -> Dictionary:
	if target == null or not target.has_method(method):
		return {}
	var value: Variant = target.callv(method, args)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _result(operation: String, ok: bool, reason_code: String) -> Dictionary:
	return {
		"operation": operation,
		"ok": ok,
		"reason_code": reason_code,
		"registry_id": REGISTRY_ID,
		"registry_version": REGISTRY_VERSION,
		"operation_sequence": _operation_sequence,
	}


func _public_bool(value: Variant) -> bool:
	return bool(value) if value is bool else false


func _public_nonnegative_int(value: Variant) -> int:
	return maxi(0, int(value)) if typeof(value) == TYPE_INT else 0


func _unique_sorted_strings(values: Array[String]) -> Array[String]:
	var seen: Dictionary = {}
	for value in values:
		seen[value] = true
	var result: Array[String] = []
	for value_variant in seen.keys():
		result.append(str(value_variant))
	result.sort()
	return result
