@tool
extends Node
class_name V06SaveOwnerRegistry

const BindingScript := preload("res://scripts/runtime/v06_save_owner_binding_resource.gd")
const CardHistoryRestoreDependencyContractScript := preload("res://scripts/runtime/card_history_restore_dependency_contract.gd")
const CommodityFlowPostCommitRestoreDependencyContractScript := preload("res://scripts/runtime/commodity_flow_postcommit_restore_dependency_contract.gd")
const CaptureFailureScript := preload("res://scripts/runtime/save_owner_capture_failure_v1.gd")

const REGISTRY_ID := "v06_save_owner_registry"
const REGISTRY_VERSION := 2
const BINDING_CONTRACT_ID := "v06_save_owner_registry.binding_contract.v1"
const BINDING_CONTRACT_SCHEMA_VERSION := 1
const CHECKPOINT_STRATEGY_EXPLICIT_OWNER_METHOD := "explicit_owner_method"
const CHECKPOINT_STRATEGY_REGISTRY_MANAGED := "registry_managed_checkpoint"
const CHECKPOINT_STRATEGY_OWNER_INTERNAL := "owner_internal_transaction_checkpoint"
const CHECKPOINT_STRATEGIES := [
	CHECKPOINT_STRATEGY_EXPLICIT_OWNER_METHOD,
	CHECKPOINT_STRATEGY_REGISTRY_MANAGED,
	CHECKPOINT_STRATEGY_OWNER_INTERNAL,
]
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
const RESTORE_DAG_DEPENDENCIES := {
	"ruleset": [],
	"session_foundation": ["ruleset"],
	"region_infrastructure": ["session_foundation"],
	"region_supply": ["region_infrastructure"],
	"commodity_flow": ["region_infrastructure"],
	"player_mana": ["session_foundation"],
	"card_inventory": ["region_supply", "player_mana"],
	"player_organization": ["session_foundation"],
	"monsters": ["region_infrastructure", "card_inventory"],
	"military": ["region_infrastructure", "card_inventory", "monsters"],
	"weather": ["region_infrastructure"],
	"card_resolution_queue": [
		"region_infrastructure",
		"player_mana",
		"card_inventory",
	],
	"card_resolution_execution": [
		"card_resolution_queue",
		"player_mana",
		"commodity_flow",
	],
	"card_resolution_history": ["card_resolution_execution"],
	"ai": ["card_inventory", "card_resolution_history"],
	"bankruptcy_neutral_estate": [
		"region_infrastructure",
		"commodity_flow",
		"player_mana",
		"card_inventory",
		"monsters",
		"military",
	],
	"victory_control": [
		"region_infrastructure",
		"commodity_flow",
		"bankruptcy_neutral_estate",
	],
	"routes": ["region_infrastructure", "weather"],
	"commodity_belt_visibility": ["card_inventory"],
	"session_tail": [
		"card_resolution_history",
		"ai",
		"victory_control",
		"routes",
		"commodity_belt_visibility",
	],
}

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
var _last_internal_capture_failure: Dictionary = {}
var _last_capture_operation_sequence := 0
var _last_capture_section_count := 0
var _last_capture_sections_fingerprint := ""
var _last_capture_envelope_fingerprint := ""
var _last_capture_write_id := ""
var _capture_diagnostic_progress_sink: Variant
var _capture_diagnostic_row_context: Dictionary = {}
var _last_internal_preflight_failure_section := ""
var _last_internal_preflight_failure_reason := ""
var _test_apply_failure_once := ""
var _test_capture_live_fingerprint_failure_once := ""
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


func registry_binding_contract_v1() -> Dictionary:
	var analysis := _registry_analysis()
	var binding_by_section: Dictionary = analysis.get("binding_by_section", {})
	var handshake := _handshake_node()
	var manifest: Dictionary = _call_dictionary(handshake, "required_section_manifest")
	var restore_dag := _registry_binding_restore_dag_v1()
	var errors: Array[String] = []
	var rows: Array[Dictionary] = []
	var configured_section_order: Array[String] = []
	var strategy_counts := {
		CHECKPOINT_STRATEGY_EXPLICIT_OWNER_METHOD: 0,
		CHECKPOINT_STRATEGY_REGISTRY_MANAGED: 0,
		CHECKPOINT_STRATEGY_OWNER_INTERNAL: 0,
	}
	var owner_without_checkpoint_or_rollback_semantics_count := 0
	for binding in bindings:
		configured_section_order.append(binding.section_id if binding != null else "")
	if configured_section_order != fixed_section_order():
		errors.append("binding_order_mismatch")
	if not _registry_binding_restore_dag_valid_v1(restore_dag):
		errors.append("restore_dag_invalid")
	for section_index in range(FIXED_SECTION_ORDER.size()):
		var section_id := str(FIXED_SECTION_ORDER[section_index])
		var binding := binding_by_section.get(section_id) as BindingScript
		if binding == null:
			errors.append("binding_missing:%s" % section_id)
			continue
		var owner := get_node_or_null(binding.owner_path)
		var strategy := _registry_binding_checkpoint_strategy_v1(binding)
		var checkpoint_method_present := not binding.checkpoint_method.strip_edges().is_empty()
		var capture_method_exists := owner != null and not binding.capture_method.is_empty() \
			and owner.has_method(binding.capture_method)
		var preflight_method_exists := owner != null and (binding.preflight_method.is_empty() \
			or owner.has_method(binding.preflight_method))
		var apply_method_exists := owner != null and not binding.apply_method.is_empty() \
			and owner.has_method(binding.apply_method)
		var checkpoint_method_exists := owner != null and checkpoint_method_present \
			and owner.has_method(binding.checkpoint_method)
		var rollback_method_exists := owner != null and not binding.rollback_method.is_empty() \
			and owner.has_method(binding.rollback_method)
		var strategy_valid := _registry_binding_checkpoint_strategy_valid_v1(
			strategy,
			checkpoint_method_present,
			capture_method_exists,
			checkpoint_method_exists,
			rollback_method_exists
		)
		var manifest_contract: Dictionary = manifest.get(section_id, {}) \
			if manifest.get(section_id, {}) is Dictionary else {}
		var state_version_valid := binding.state_version > 0 \
			and str(manifest_contract.get("owner_id", "")) == binding.owner_id \
			and int(manifest_contract.get("state_version", 0)) == binding.state_version
		var restore_nodes := _registry_binding_restore_nodes_v1(section_id, restore_dag)
		var row_valid := binding.is_transactional() \
			and owner != null \
			and capture_method_exists \
			and preflight_method_exists \
			and apply_method_exists \
			and rollback_method_exists \
			and strategy_valid \
			and state_version_valid \
			and not restore_nodes.is_empty()
		if CHECKPOINT_STRATEGIES.has(strategy):
			strategy_counts[strategy] = int(strategy_counts.get(strategy, 0)) + 1
		if not strategy_valid or not rollback_method_exists:
			owner_without_checkpoint_or_rollback_semantics_count += 1
		if not row_valid:
			errors.append("binding_contract_invalid:%s" % section_id)
		var row := {
			"section_index": section_index,
			"section_id": binding.section_id,
			"owner_id": binding.owner_id,
			"owner_path": str(binding.owner_path),
			"state_version": binding.state_version,
			"restore_mode": binding.restore_mode,
			"capture_method": binding.capture_method,
			"preflight_method": binding.preflight_method,
			"apply_method": binding.apply_method,
			"checkpoint_method_present": checkpoint_method_present,
			"checkpoint_method": binding.checkpoint_method,
			"rollback_method": binding.rollback_method,
			"checkpoint_strategy": strategy,
			"checkpoint_source_method": binding.checkpoint_method \
				if strategy == CHECKPOINT_STRATEGY_EXPLICIT_OWNER_METHOD else binding.capture_method,
			"restore_nodes": restore_nodes,
			"dependencies": _registry_binding_dependency_ids_v1(restore_nodes),
			"owner_node_present": owner != null,
			"capture_method_exists": capture_method_exists,
			"preflight_method_exists": preflight_method_exists,
			"apply_method_exists": apply_method_exists,
			"checkpoint_method_exists": checkpoint_method_exists,
			"rollback_method_exists": rollback_method_exists,
			"checkpoint_strategy_valid": strategy_valid,
			"state_version_valid": state_version_valid,
			"checkpoint_captured_before_any_apply": true,
			"rollback_invoked_by_registry": true,
			"rollback_order": "reverse_restore_dag",
			"post_rollback_exact_recapture_required": true,
			"method_contract_source": "V06SaveOwnerRegistry._capture_owner_checkpoint/_rollback_sections",
			"valid": row_valid,
		}
		row["binding_contract_fingerprint"] = _registry_binding_contract_fingerprint_v1(row)
		rows.append(row)
	errors = _unique_sorted_strings(errors)
	return {
		"schema_version": BINDING_CONTRACT_SCHEMA_VERSION,
		"contract_id": BINDING_CONTRACT_ID,
		"registry_id": REGISTRY_ID,
		"registry_version": REGISTRY_VERSION,
		"valid": bool(analysis.get("valid", false)) and errors.is_empty(),
		"reason_code": "registry_binding_contract_valid" \
			if bool(analysis.get("valid", false)) and errors.is_empty() \
			else "registry_binding_contract_invalid",
		"binding_count": rows.size(),
		"configured_section_order": configured_section_order,
		"fixed_section_order": fixed_section_order(),
		"restore_dag_node_order": restore_dag_node_order(),
		"restore_dag": restore_dag,
		"checkpoint_strategies": CHECKPOINT_STRATEGIES.duplicate(),
		"checkpoint_strategy_counts": strategy_counts,
		"owner_without_checkpoint_or_rollback_semantics_count": owner_without_checkpoint_or_rollback_semantics_count,
		"bindings": rows,
		"errors": errors,
	}


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


func capture_all_sections_detailed(progress_sink: Variant = null) -> Dictionary:
	if _operation_in_progress:
		return {
			"captured": false,
			"section_count": 0,
			"sections": [],
			"section_results": [],
			"first_failure": CaptureFailureScript.build({
				"registry_operation_id": "capture-%d" % _operation_sequence,
				"capture_sequence": _operation_sequence,
				"failure_class": "REGISTRY_INTERNAL_ERROR",
				"reason_code": "registry_busy",
			}),
		}
	_operation_in_progress = true
	_operation_sequence += 1
	_capture_diagnostic_progress_sink = progress_sink
	_capture_diagnostic_row_context.clear()
	var result := _capture_all_sections_detailed_internal({}, true)
	result["section_results"] = _complete_diagnostic_section_rows(
		result.get("section_results", []) as Array,
		_registry_analysis().get("binding_by_section", {}) as Dictionary
	)
	_capture_diagnostic_progress_sink = null
	_capture_diagnostic_row_context.clear()
	_operation_in_progress = false
	result.erase("plan")
	result.erase("section_payloads")
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


func arm_test_capture_live_fingerprint_failure_once(section_id: String) -> bool:
	var normalized := section_id.strip_edges()
	if normalized not in FIXED_SECTION_ORDER:
		return false
	_test_capture_live_fingerprint_failure_once = normalized
	return true


func clear_test_capture_live_fingerprint_failure() -> void:
	_test_capture_live_fingerprint_failure_once = ""


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
	snapshot["last_internal_capture_failure"] = _last_internal_capture_failure.duplicate(true)
	snapshot["last_capture_operation_sequence"] = _last_capture_operation_sequence
	snapshot["last_capture_section_count"] = _last_capture_section_count
	snapshot["last_capture_sections_fingerprint"] = _last_capture_sections_fingerprint
	snapshot["last_capture_envelope_fingerprint"] = _last_capture_envelope_fingerprint
	snapshot["last_capture_write_id"] = _last_capture_write_id
	snapshot["last_internal_preflight_failure_section"] = _last_internal_preflight_failure_section
	snapshot["last_internal_preflight_failure_reason"] = _last_internal_preflight_failure_reason
	snapshot["last_internal_rollback_order"] = _last_internal_rollback_order.duplicate()
	snapshot["public_receipt_allowlisted"] = true
	return snapshot


func _capture_resume_envelope_internal(identity: Dictionary) -> Dictionary:
	_last_internal_capture_failure_section = ""
	_last_internal_capture_failure_reason = ""
	_last_internal_capture_failure.clear()
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
	var detailed := _capture_all_sections_detailed_internal(analysis)
	if not bool(detailed.get("captured", false)):
		var first_failure: Dictionary = detailed.get("first_failure", {}) \
				if detailed.get("first_failure", {}) is Dictionary else {}
		if first_failure.is_empty() and detailed.get("post_capture_failure", {}) is Dictionary:
			first_failure = (detailed.get("post_capture_failure", {}) as Dictionary).duplicate(true)
		return _capture_rejection(
			str(first_failure.get("section_id", "registry")),
			str(first_failure.get("reason_code", "owner_checkpoint_capture_failed")),
			first_failure
		)
	var session_section: Dictionary = {}
	var domain_sections: Dictionary = {}
	var plan: Dictionary = detailed.get("plan", {}) if detailed.get("plan", {}) is Dictionary else {}
	var detailed_sections: Dictionary = detailed.get("section_payloads", {}) \
			if detailed.get("section_payloads", {}) is Dictionary else {}
	for section_id in FIXED_SECTION_ORDER:
		var wrapper: Dictionary = detailed_sections.get(section_id, {}) \
				if detailed_sections.get(section_id, {}) is Dictionary else {}
		if section_id == "session":
			session_section = wrapper
		else:
			domain_sections[section_id] = wrapper
	var envelope := _call_dictionary(handshake, "compose_v06_envelope", [session_section, domain_sections, identity])
	var validation := _call_dictionary(handshake, "validate_envelope", [envelope])
	if envelope.is_empty() or not bool(validation.get("valid", false)):
		return _result("capture", false, "captured_envelope_invalid")
	var success := _result("capture", true, "resume_envelope_captured")
	var captured_sections: Dictionary = envelope.get("sections", {}) \
			if envelope.get("sections", {}) is Dictionary else {}
	var captured_sections_canonical := str(handshake.call("canonical_json", captured_sections)) \
			if handshake != null and handshake.has_method("canonical_json") else ""
	_last_capture_operation_sequence = _operation_sequence
	_last_capture_section_count = int(detailed.get("section_count", 0))
	_last_capture_sections_fingerprint = captured_sections_canonical.sha256_text() \
			if not captured_sections_canonical.is_empty() else ""
	_last_capture_envelope_fingerprint = str(validation.get("fingerprint", ""))
	_last_capture_write_id = str(envelope.get("write_id", ""))
	success["envelope_valid"] = true
	success["envelope"] = envelope
	success["fingerprint"] = str(validation.get("fingerprint", ""))
	return success


func _capture_rejection(section_id: String, internal_reason_code: String, failure: Dictionary = {}) -> Dictionary:
	var safe_reason := CaptureFailureScript.sanitize_reason_code(internal_reason_code)
	_last_internal_capture_failure_section = section_id
	_last_internal_capture_failure_reason = safe_reason
	_last_internal_capture_failure = failure.duplicate(true)
	var rejected := _result("capture", false, "owner_capture_failed")
	rejected["failing_section_id"] = section_id
	rejected["internal_reason_code"] = safe_reason
	if not failure.is_empty():
		rejected["capture_failure"] = failure.duplicate(true)
	return rejected


func _capture_all_sections_detailed_internal(
	existing_analysis: Dictionary = {},
	capture_audit_only := false
) -> Dictionary:
	_last_internal_capture_failure_section = ""
	_last_internal_capture_failure_reason = ""
	_last_internal_capture_failure.clear()
	var analysis := existing_analysis if not existing_analysis.is_empty() else _registry_analysis()
	var result := {
		"captured": false,
		"section_count": 0,
		"sections": [],
		"section_results": [],
		"first_failure": {},
		"post_capture_failure": {},
		"plan": {},
		"section_payloads": {},
	}
	if not bool(analysis.get("valid", false)):
		result["first_failure"] = CaptureFailureScript.build({
			"registry_operation_id": "capture-%d" % _operation_sequence,
			"capture_sequence": _operation_sequence,
			"failure_class": "REGISTRY_INTERNAL_ERROR",
			"reason_code": "owner_registry_invalid",
		})
		return result
	if not bool(analysis.get("resume_ready", false)) or not bool(registry_snapshot().get("resume_ready", false)):
		result["first_failure"] = CaptureFailureScript.build({
			"registry_operation_id": "capture-%d" % _operation_sequence,
			"capture_sequence": _operation_sequence,
			"failure_class": "REGISTRY_INTERNAL_ERROR",
			"reason_code": "restore_capability_incomplete",
		})
		return result
	var binding_by_section: Dictionary = analysis.get("binding_by_section", {})
	var sections: Array = result["sections"]
	var section_payloads: Dictionary = result["section_payloads"]
	var section_results: Array = result["section_results"]
	var plan: Dictionary = result["plan"]
	var live_fingerprints_before: Dictionary = {}
	for baseline_index in range(FIXED_SECTION_ORDER.size()):
		var baseline_section_id := str(FIXED_SECTION_ORDER[baseline_index])
		var baseline_binding := binding_by_section.get(baseline_section_id) as BindingScript
		var baseline_owner := get_node_or_null(baseline_binding.owner_path) if baseline_binding != null else null
		var baseline_started_ms := Time.get_ticks_msec()
		var baseline_observation := _capture_progress_observation()
		var baseline := {
			"ok": false,
			"reason_code": "owner_live_fingerprint_unavailable",
		} if _consume_test_capture_live_fingerprint_failure(baseline_section_id) \
				else _capture_owner_live_fingerprint(baseline_owner)
		if not bool(baseline.get("ok", false)):
			_begin_capture_diagnostic_row_from_observation(
				baseline_binding,
				baseline_index,
				baseline_started_ms,
				baseline_observation
			)
			var baseline_failure := _capture_failure_for_binding(
				baseline_binding,
				baseline_index,
				"REGISTRY_INTERNAL_ERROR",
				str(baseline.get("reason_code", "owner_live_fingerprint_unavailable"))
			)
			section_results.append(_section_capture_result(baseline_binding, false, str(baseline_failure.get("reason_code", "registry_internal_error")), int(baseline_binding.state_version) if baseline_binding != null else -1, ""))
			result["first_failure"] = baseline_failure.duplicate(true)
			_last_internal_capture_failure_section = baseline_section_id
			_last_internal_capture_failure_reason = str(baseline_failure.get("reason_code", "registry_internal_error"))
			_last_internal_capture_failure = baseline_failure.duplicate(true)
			return result
		live_fingerprints_before[baseline_section_id] = str(baseline.get("fingerprint", ""))
	for section_index in range(FIXED_SECTION_ORDER.size()):
		var section_id := str(FIXED_SECTION_ORDER[section_index])
		var binding := binding_by_section.get(section_id) as BindingScript
		_begin_capture_diagnostic_row(binding, section_index)
		var captured := _capture_owner_checkpoint_detailed(
			binding,
			section_index,
			false,
			str(live_fingerprints_before.get(section_id, "")),
			not capture_audit_only
		)
		if not bool(captured.get("ok", false)):
			var failure: Dictionary = captured.get("failure", {}) \
					if captured.get("failure", {}) is Dictionary else {}
			section_results.append(_section_capture_result(binding, false, str(failure.get("reason_code", "owner_checkpoint_capture_failed")), int(binding.state_version) if binding != null else -1, ""))
			result["first_failure"] = failure.duplicate(true)
			result["section_count"] = sections.size()
			_last_internal_capture_failure_section = section_id
			_last_internal_capture_failure_reason = str(failure.get("reason_code", "owner_checkpoint_capture_failed"))
			_last_internal_capture_failure = failure.duplicate(true)
			return _finalize_capture_failure(result, binding_by_section, live_fingerprints_before, plan, section_id)
		var raw_state: Dictionary = captured.get("raw_owner_state", {}) \
				if captured.get("raw_owner_state", {}) is Dictionary else {}
		var owner := get_node_or_null(binding.owner_path) if binding != null else null
		var owner_preflight := _preflight_owner(owner, binding, raw_state, not capture_audit_only)
		var live_after_preflight := _capture_owner_live_fingerprint(owner)
		if not bool(live_after_preflight.get("ok", false)) \
				or str(live_after_preflight.get("fingerprint", "")) != str(captured.get("live_fingerprint_before", "")):
			var preflight_mutation_rollback := _rollback_owner_capture_mutation(
				owner,
				binding,
				(captured.get("rollback_checkpoint", {}) as Dictionary).duplicate(true),
				bool(captured.get("rollback_checkpoint_available", false)),
				str(captured.get("live_fingerprint_before", ""))
			)
			var failure := _capture_failure_for_binding(
				binding,
				section_index,
				"OWNER_CAPTURE_MUTATED_RUNTIME",
				"owner_preflight_mutated_runtime" if bool(preflight_mutation_rollback.get("exact", false)) \
						else "owner_capture_mutation_rollback_failed",
				{"live_state_mutated_during_capture": true}
			)
			section_results.append(_section_capture_result(binding, false, str(failure.get("reason_code", "registry_internal_error")), binding.state_version, str(captured.get("payload_fingerprint", ""))))
			result["first_failure"] = failure.duplicate(true)
			result["section_count"] = sections.size()
			_last_internal_capture_failure_section = section_id
			_last_internal_capture_failure_reason = str(failure.get("reason_code", "registry_internal_error"))
			_last_internal_capture_failure = failure.duplicate(true)
			return _finalize_capture_failure(result, binding_by_section, live_fingerprints_before, plan, section_id)
		if not bool(owner_preflight.get("ok", false)):
			var owner_reason := str(owner_preflight.get("reason_code", "owner_preflight_rejected"))
			var capture_reason := "owner_capture_empty" if raw_state.is_empty() else owner_reason
			var failure := _capture_failure_for_binding(
				binding,
				section_index,
				_classify_owner_preflight_failure(raw_state, owner_reason),
				capture_reason,
				{
					"result_empty": raw_state.is_empty(),
					"result_header_invalid": _classify_owner_preflight_failure(raw_state, owner_reason) == "OWNER_CAPTURE_HEADER_INVALID",
					"result_version_invalid": _classify_owner_preflight_failure(raw_state, owner_reason) == "OWNER_CAPTURE_VERSION_INVALID",
					"result_ruleset_invalid": _classify_owner_preflight_failure(raw_state, owner_reason) == "OWNER_CAPTURE_RULESET_INVALID",
					"state_version_observed": _strict_observed_int(raw_state.get("schema_version", raw_state.get("state_version", -1))),
					"ruleset_id_observed": str(raw_state.get("ruleset_id", "")),
				}
			)
			var safe_owner_reason := str(failure.get("reason_code", "registry_internal_error"))
			section_results.append(_section_capture_result(binding, false, safe_owner_reason, binding.state_version, str(captured.get("payload_fingerprint", ""))))
			result["first_failure"] = failure.duplicate(true)
			result["section_count"] = sections.size()
			_last_internal_capture_failure_section = section_id
			_last_internal_capture_failure_reason = safe_owner_reason
			_last_internal_capture_failure = failure.duplicate(true)
			return _finalize_capture_failure(result, binding_by_section, live_fingerprints_before, plan, section_id)
		plan[section_id] = {
			"decoded_owner_state": raw_state.duplicate(true),
			"normalized_owner_state": (owner_preflight.get("normalized_owner_state", {}) as Dictionary).duplicate(true),
			"normalized_encoded_owner_state": owner_preflight.get("normalized_encoded_owner_state"),
			"capture_rollback_checkpoint": (captured.get("rollback_checkpoint", {}) as Dictionary).duplicate(true),
			"capture_rollback_checkpoint_available": bool(captured.get("rollback_checkpoint_available", false)),
			"capture_live_fingerprint_before": str(captured.get("live_fingerprint_before", "")),
		}
		if not capture_audit_only:
			section_payloads[section_id] = {
				"schema_version": binding.state_version,
				"owner_id": binding.owner_id,
				"owner_state": owner_preflight.get("normalized_encoded_owner_state"),
			}
		sections.append(section_id)
		section_results.append(_section_capture_result(
			binding,
			true,
			"owner_capture_valid",
			binding.state_version,
			str(captured.get("payload_fingerprint", ""))
		))
	var dependency_preflight := _preflight_cross_section_dependencies(plan, binding_by_section)
	for final_index in range(FIXED_SECTION_ORDER.size()):
		var final_section_id := str(FIXED_SECTION_ORDER[final_index])
		var final_binding := binding_by_section.get(final_section_id) as BindingScript
		var final_owner := get_node_or_null(final_binding.owner_path) if final_binding != null else null
		var final_live := _capture_owner_live_fingerprint(final_owner)
		var final_expected := str(live_fingerprints_before.get(final_section_id, ""))
		if bool(final_live.get("ok", false)) \
				and str(final_live.get("fingerprint", "")) == final_expected:
			continue
		var final_plan: Dictionary = plan.get(final_section_id, {}) \
				if plan.get(final_section_id, {}) is Dictionary else {}
		var final_rollback := _rollback_owner_capture_mutation(
			final_owner,
			final_binding,
			(final_plan.get("capture_rollback_checkpoint", {}) as Dictionary).duplicate(true),
			bool(final_plan.get("capture_rollback_checkpoint_available", false)),
			final_expected
		)
		var final_failure := _capture_failure_for_binding(
			final_binding,
			final_index,
			"OWNER_CAPTURE_MUTATED_RUNTIME",
			"owner_capture_cross_owner_mutation" if bool(final_rollback.get("exact", false)) \
					else "owner_capture_mutation_rollback_failed",
			{"live_state_mutated_during_capture": true}
		)
		result["post_capture_failure"] = final_failure.duplicate(true)
		result["section_count"] = sections.size()
		_last_internal_capture_failure_section = final_section_id
		_last_internal_capture_failure_reason = str(final_failure.get("reason_code", "registry_internal_error"))
		_last_internal_capture_failure = final_failure.duplicate(true)
		return result
	if not bool(dependency_preflight.get("accepted", false)):
		_cross_section_rejection_count += 1
		var failing_section_id := str(dependency_preflight.get("failing_section_id", "cross_section"))
		var failing_binding := binding_by_section.get(failing_section_id) as BindingScript
		var internal_reason := str(dependency_preflight.get("internal_reason_code", dependency_preflight.get("reason_code", "cross_section_dependency_rejected")))
		var failure := _capture_failure_for_binding(
			failing_binding,
			maxi(0, FIXED_SECTION_ORDER.find(failing_section_id)),
			"REGISTRY_INTERNAL_ERROR",
			internal_reason
		)
		var safe_internal_reason := str(failure.get("reason_code", "registry_internal_error"))
		result["post_capture_failure"] = failure.duplicate(true)
		result["section_count"] = sections.size()
		_last_internal_capture_failure_section = failing_section_id
		_last_internal_capture_failure_reason = safe_internal_reason
		_last_internal_capture_failure = failure.duplicate(true)
		return result
	result["captured"] = true
	result["section_count"] = sections.size()
	return result


func _finalize_capture_failure(
	result: Dictionary,
	binding_by_section: Dictionary,
	live_fingerprints_before: Dictionary,
	plan: Dictionary,
	source_section_id: String
) -> Dictionary:
	var mutation_found := false
	var rollback_exact := true
	for section_index in range(FIXED_SECTION_ORDER.size()):
		var section_id := str(FIXED_SECTION_ORDER[section_index])
		if not live_fingerprints_before.has(section_id):
			continue
		var binding := binding_by_section.get(section_id) as BindingScript
		var owner := get_node_or_null(binding.owner_path) if binding != null else null
		var live_after := _capture_owner_live_fingerprint(owner)
		var expected := str(live_fingerprints_before.get(section_id, ""))
		if bool(live_after.get("ok", false)) \
				and str(live_after.get("fingerprint", "")) == expected:
			continue
		mutation_found = true
		var planned: Dictionary = plan.get(section_id, {}) \
				if plan.get(section_id, {}) is Dictionary else {}
		var rollback := _rollback_owner_capture_mutation(
			owner,
			binding,
			(planned.get("capture_rollback_checkpoint", {}) as Dictionary).duplicate(true),
			bool(planned.get("capture_rollback_checkpoint_available", false)),
			expected
		)
		rollback_exact = rollback_exact and bool(rollback.get("exact", false))
	if not mutation_found:
		return result
	var source_index := FIXED_SECTION_ORDER.find(source_section_id)
	var source_binding := binding_by_section.get(source_section_id) as BindingScript
	var mutation_failure := _capture_failure_for_binding(
		source_binding,
		maxi(0, source_index),
		"OWNER_CAPTURE_MUTATED_RUNTIME",
		"owner_capture_cross_owner_mutation" if rollback_exact else "owner_capture_mutation_rollback_failed",
		{"live_state_mutated_during_capture": true}
	)
	result["post_capture_failure"] = mutation_failure.duplicate(true)
	var section_results: Array = result.get("section_results", []) \
			if result.get("section_results", []) is Array else []
	for row_variant in section_results:
		if row_variant is Dictionary \
				and str((row_variant as Dictionary).get("section_id", "")) == source_section_id:
			# The Owner capture returned a valid payload; the independent post-capture
			# fingerprint sweep detected mutation afterwards. Preserve that temporal
			# distinction and bind the unsafe row through mutation_count plus the
			# typed post_capture_failure above.
			(row_variant as Dictionary)["mutation_count"] = maxi(1, int((row_variant as Dictionary).get("mutation_count", 0)))
			(row_variant as Dictionary).erase("row_evidence_fingerprint")
			(row_variant as Dictionary)["row_evidence_fingerprint"] = _encoded_payload_fingerprint(row_variant as Dictionary)
			break
	_last_internal_capture_failure_section = source_section_id
	_last_internal_capture_failure_reason = str(mutation_failure.get("reason_code", "registry_internal_error"))
	_last_internal_capture_failure = mutation_failure.duplicate(true)
	return result


func _preflight_envelope_internal(envelope: Dictionary) -> Dictionary:
	_last_restore_phase = 0
	_last_internal_preflight_failure_section = ""
	_last_internal_preflight_failure_reason = ""
	var analysis := _registry_analysis()
	if not bool(analysis.get("valid", false)):
		return {"ok": false, "reason_code": "owner_registry_invalid", "envelope_valid": false, "preflight_complete": false}
	var validation := _call_dictionary(_handshake_node(), "validate_envelope", [envelope])
	if not bool(validation.get("valid", false)):
		var validation_reason := CaptureFailureScript.sanitize_reason_code(
			validation.get("reason_code", "envelope_validation_failed")
		)
		if validation_reason in [
			"allocator_cursor_missing_requires_backup",
			"card_inventory_v3_closed_wire_upgrade_requires_backup",
			"ai_save_v2_closed_wire_upgrade_requires_backup",
			"victory_save_v2_closed_wire_upgrade_requires_backup",
		]:
			match validation_reason:
				"ai_save_v2_closed_wire_upgrade_requires_backup":
					_last_internal_preflight_failure_section = "ai"
				"victory_save_v2_closed_wire_upgrade_requires_backup":
					_last_internal_preflight_failure_section = "victory_control"
				_:
					_last_internal_preflight_failure_section = "card_inventory"
			_last_internal_preflight_failure_reason = validation_reason
			return {
				"ok": false,
				"reason_code": validation_reason,
				"envelope_valid": false,
				"preflight_complete": false,
				"requires_backup": true,
			}
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
			_last_internal_preflight_failure_reason = CaptureFailureScript.sanitize_reason_code(decoded.get("reason_code", "section_wrapper_invalid"))
			return {"ok": false, "reason_code": "section_wrapper_invalid", "envelope_valid": true, "preflight_complete": false, "preflight_count": preflight_count}
		var owner := get_node_or_null(binding.owner_path)
		var owner_preflight := _preflight_owner(owner, binding, decoded.get("owner_state", {}) as Dictionary)
		if not bool(owner_preflight.get("ok", false)):
			var owner_reason := str(owner_preflight.get("reason_code", "owner_preflight_rejected"))
			_last_internal_preflight_failure_section = section_id
			_last_internal_preflight_failure_reason = CaptureFailureScript.sanitize_reason_code(owner_reason)
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
		_last_internal_preflight_failure_reason = CaptureFailureScript.sanitize_reason_code(
			dependency_preflight.get("internal_reason_code", dependency_preflight.get("reason_code", "cross_section_dependency_rejected"))
		)
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


func _preflight_owner(
	owner: Node,
	binding: BindingScript,
	owner_state: Dictionary,
	encode_normalized_state := true
) -> Dictionary:
	if owner == null:
		return {"ok": false}
	if not binding.preflight_method.is_empty():
		var preflight_receipt := _call_dictionary(owner, binding.preflight_method, [owner_state.duplicate(true)])
		if not bool(preflight_receipt.get("accepted", false)):
			return {
				"ok": false,
				"reason_code": str(preflight_receipt.get("reason_code", preflight_receipt.get("reason", "owner_preflight_rejected"))),
				"requires_backup": bool(preflight_receipt.get("requires_backup", false)),
			}
		var normalized := owner_state.duplicate(true)
		if preflight_receipt.has("normalized_state"):
			if not (preflight_receipt.get("normalized_state") is Dictionary):
				return {"ok": false, "reason_code": "owner_preflight_normalized_state_invalid"}
			normalized = (preflight_receipt.get("normalized_state") as Dictionary).duplicate(true)
		var encoded := _encode_owner_state(normalized) if encode_normalized_state else {
			"ok": _is_owner_codec_data(normalized),
			"value": null,
		}
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
	var encoded := _encode_owner_state(normalized_state) if encode_normalized_state else {
		"ok": _is_owner_codec_data(normalized_state),
		"value": null,
	}
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
	var section_index := FIXED_SECTION_ORDER.find(binding.section_id) if binding != null else 0
	return _capture_owner_checkpoint_detailed(binding, maxi(0, section_index), restore_verification)


func _capture_owner_checkpoint_detailed(
	binding: BindingScript,
	section_index: int,
	restore_verification := false,
	expected_live_fingerprint := "",
	encode_payload := true
) -> Dictionary:
	if binding == null:
		return {
			"ok": false,
			"failure": _capture_failure_for_binding(null, section_index, "REGISTRY_INTERNAL_ERROR", "owner_binding_missing"),
		}
	var owner := get_node_or_null(binding.owner_path)
	if owner == null:
		return {
			"ok": false,
			"failure": _capture_failure_for_binding(binding, section_index, "OWNER_NODE_MISSING", "owner_node_missing"),
		}
	var capture_method := binding.capture_method
	if restore_verification and binding.section_id == "session" and owner.has_method("capture_restore_verification_state"):
		capture_method = "capture_restore_verification_state"
	if capture_method.is_empty() or not owner.has_method(capture_method):
		return {
			"ok": false,
			"failure": _capture_failure_for_binding(binding, section_index, "OWNER_METHOD_MISSING", "owner_capture_method_missing", {
				"method_missing": true,
				"capture_method": capture_method,
			}),
		}
	var live_before := _capture_owner_live_fingerprint(owner)
	if not bool(live_before.get("ok", false)):
		return {
			"ok": false,
			"failure": _capture_failure_for_binding(binding, section_index, "REGISTRY_INTERNAL_ERROR", str(live_before.get("reason_code", "owner_live_fingerprint_unavailable"))),
		}
	if not expected_live_fingerprint.is_empty() \
			and str(live_before.get("fingerprint", "")) != expected_live_fingerprint:
		return {
			"ok": false,
			"failure": _capture_failure_for_binding(binding, section_index, "OWNER_CAPTURE_MUTATED_RUNTIME", "owner_capture_cross_owner_mutation", {
				"live_state_mutated_during_capture": true,
			}),
		}
	var rollback_checkpoint: Dictionary = {}
	var rollback_checkpoint_available := false
	var checkpoint_uses_method := not binding.checkpoint_method.is_empty()
	if checkpoint_uses_method:
		if not owner.has_method(binding.checkpoint_method):
			return {
				"ok": false,
				"failure": _capture_failure_for_binding(binding, section_index, "OWNER_METHOD_MISSING", "owner_checkpoint_method_missing", {
					"method_missing": true,
					"capture_method": binding.checkpoint_method,
				}),
			}
		var pre_capture_checkpoint_variant: Variant = owner.call(binding.checkpoint_method)
		if not (pre_capture_checkpoint_variant is Dictionary):
			return {
				"ok": false,
				"failure": _capture_failure_for_binding(binding, section_index, "OWNER_CAPTURE_WRONG_TYPE", "owner_checkpoint_result_not_dictionary", {
					"result_not_dictionary": true,
					"capture_method": binding.checkpoint_method,
				}),
			}
		rollback_checkpoint = (pre_capture_checkpoint_variant as Dictionary).duplicate(true)
		if rollback_checkpoint.is_empty() or (rollback_checkpoint.has("captured") \
				and not bool(rollback_checkpoint.get("captured", false))):
			return {
				"ok": false,
				"failure": _capture_failure_for_binding(
					binding,
					section_index,
					"REGISTRY_INTERNAL_ERROR",
					str(rollback_checkpoint.get("reason_code", "owner_checkpoint_capture_failed")),
					{"capture_method": binding.checkpoint_method}
				),
			}
		rollback_checkpoint_available = true
		var checkpoint_is_pure := _is_owner_codec_data(rollback_checkpoint)
		if not checkpoint_is_pure:
			return {
				"ok": false,
				"failure": _capture_failure_for_binding(binding, section_index, "OWNER_CAPTURE_NOT_PURE_DATA", "owner_checkpoint_not_pure_data", {
					"result_not_pure_data": true,
					"capture_method": binding.checkpoint_method,
				}),
			}
	var raw_variant: Variant = owner.call(capture_method)
	var live_after := _capture_owner_live_fingerprint(owner)
	if not bool(live_after.get("ok", false)) \
			or str(live_after.get("fingerprint", "")) != str(live_before.get("fingerprint", "")):
		if not rollback_checkpoint_available and raw_variant is Dictionary:
			rollback_checkpoint = (raw_variant as Dictionary).duplicate(true)
			rollback_checkpoint_available = true
		var mutation_rollback := _rollback_owner_capture_mutation(
			owner,
			binding,
			rollback_checkpoint,
			rollback_checkpoint_available,
			str(live_before.get("fingerprint", ""))
		)
		return {
			"ok": false,
			"failure": _capture_failure_for_binding(binding, section_index, "OWNER_CAPTURE_MUTATED_RUNTIME", \
					"owner_capture_mutated_runtime" if bool(mutation_rollback.get("exact", false)) \
					else "owner_capture_mutation_rollback_failed", {
				"result_not_dictionary": not (raw_variant is Dictionary),
				"live_state_mutated_during_capture": true,
				"capture_method": capture_method,
			}),
		}
	if not (raw_variant is Dictionary):
		return {
			"ok": false,
			"failure": _capture_failure_for_binding(binding, section_index, "OWNER_CAPTURE_WRONG_TYPE", "owner_capture_result_not_dictionary", {
				"result_not_dictionary": true,
				"capture_method": capture_method,
			}),
		}
	var raw_state := (raw_variant as Dictionary).duplicate(true)
	if not rollback_checkpoint_available:
		rollback_checkpoint = raw_state.duplicate(true)
		rollback_checkpoint_available = true
	var raw_is_pure := _is_owner_codec_data(raw_state)
	if not raw_is_pure:
		return {
			"ok": false,
			"failure": _capture_failure_for_binding(binding, section_index, "OWNER_CAPTURE_NOT_PURE_DATA", "owner_capture_not_pure_data", {
				"result_empty": raw_state.is_empty(),
				"result_not_pure_data": true,
				"capture_method": capture_method,
			}),
		}
	return {
		"ok": true,
		"raw_owner_state": raw_state,
		"rollback_checkpoint": rollback_checkpoint,
		"encoded_owner_state": _encode_owner_state(raw_state).get("value") if encode_payload else null,
		"payload_fingerprint": _owner_payload_fingerprint(raw_state),
		"live_fingerprint_before": str(live_before.get("fingerprint", "")),
		"rollback_checkpoint_available": rollback_checkpoint_available,
	}


func _rollback_owner_capture_mutation(
	owner: Node,
	binding: BindingScript,
	rollback_checkpoint: Dictionary,
	rollback_checkpoint_available: bool,
	expected_live_fingerprint: String
) -> Dictionary:
	if owner == null or binding == null or binding.rollback_method.is_empty() \
			or not owner.has_method(binding.rollback_method) or not rollback_checkpoint_available:
		return {"exact": false, "reason_code": "capture_mutation_rollback_unavailable"}
	var receipt := _call_dictionary(owner, binding.rollback_method, [rollback_checkpoint.duplicate(true)])
	if not bool(receipt.get("applied", false)) and not bool(receipt.get("restored", false)):
		return {"exact": false, "reason_code": "capture_mutation_rollback_rejected"}
	var live_after_rollback := _capture_owner_live_fingerprint(owner)
	var exact := bool(live_after_rollback.get("ok", false)) \
			and str(live_after_rollback.get("fingerprint", "")) == expected_live_fingerprint
	return {
		"exact": exact,
		"reason_code": "capture_mutation_rollback_complete",
	}


func _capture_owner_live_fingerprint(owner: Node) -> Dictionary:
	if owner == null:
		return {"ok": false, "reason_code": "owner_live_fingerprint_method_missing"}
	var snapshot := {
		"script_variables": _owner_script_variable_projection(owner),
		"dependency_snapshots": _owner_dependency_snapshot_projection(owner),
	}
	if not _is_owner_codec_data(snapshot):
		return {"ok": false, "reason_code": "owner_live_fingerprint_not_pure_data"}
	var fingerprint := _owner_payload_fingerprint(snapshot)
	return {
		"ok": not fingerprint.is_empty(),
		"reason_code": "owner_live_fingerprint_valid" if not fingerprint.is_empty() else "owner_live_fingerprint_unavailable",
		"fingerprint": fingerprint,
	}


func _owner_script_variable_projection(owner: Node) -> Dictionary:
	var projection: Dictionary = {}
	for property_variant in owner.get_property_list():
		if not (property_variant is Dictionary):
			continue
		var property := property_variant as Dictionary
		if (int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var property_name := str(property.get("name", ""))
		if property_name.is_empty() or _owner_live_property_excluded(owner, property_name):
			continue
		projection[property_name] = _live_variant_projection(owner.get(property_name))
	return projection


func _owner_live_property_excluded(owner: Node, property_name: String) -> bool:
	if property_name in ["_last_reason", "_last_reason_code"]:
		return true
	if owner is AiRuntimeController:
		return property_name.begins_with("AI_") or property_name in [
			"auto_monsters", "business_cycle_count", "card_resolution_auction_open",
			"card_resolution_batch_locked", "card_resolution_counter_window_active",
			"districts", "session_finished", "game_time", "military_units", "players",
			"product_market", "resolved_card_history", "rng", "selected_district",
			"selected_trade_product", "victory_control_active",
			"victory_control_remaining_seconds",
		]
	if owner is MonsterRuntimeController:
		return property_name in ["players", "districts", "game_time", "selected_district", "rng"]
	return false


func _owner_dependency_snapshot_projection(owner: Node) -> Dictionary:
	var projection: Dictionary = {}
	if not (owner is CardInventorySaveOwner or owner is SessionEnvelopeSaveOwner):
		return projection
	for property_variant in owner.get_property_list():
		if not (property_variant is Dictionary):
			continue
		var property := property_variant as Dictionary
		var property_name := str(property.get("name", ""))
		if not property_name.ends_with("_path") or int(property.get("type", TYPE_NIL)) != TYPE_NODE_PATH:
			continue
		var path_variant: Variant = owner.get(property_name)
		if not (path_variant is NodePath) or (path_variant as NodePath).is_empty():
			continue
		var dependency := owner.get_node_or_null(path_variant as NodePath)
		if dependency == null:
			continue
		projection[property_name] = _owner_script_variable_projection(dependency)
	return projection


func _live_variant_projection(value: Variant, depth := 0) -> Variant:
	if depth > 32:
		return {"variant_type": "depth_limit"}
	if value == null or value is String or value is bool or value is int:
		return value
	if value is StringName or value is NodePath:
		return str(value)
	if value is float:
		return {"variant_type": "float", "value": str(value)}
	if value is Vector2:
		return {"variant_type": "vector2", "x": str(value.x), "y": str(value.y)}
	if value is Color:
		return {"variant_type": "color", "value": value.to_html(true)}
	if value is Array:
		var projected_array: Array = []
		for item in value as Array:
			projected_array.append(_live_variant_projection(item, depth + 1))
		return projected_array
	if value is Dictionary:
		var key_rows: Array[Dictionary] = []
		for key_variant in (value as Dictionary).keys():
			key_rows.append({
				"label": "%d:%s" % [typeof(key_variant), str(key_variant)],
				"key": key_variant,
			})
		key_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return str(left.get("label", "")) < str(right.get("label", ""))
		)
		var projected_dictionary: Dictionary = {}
		for row in key_rows:
			projected_dictionary[str(row.get("label", ""))] = _live_variant_projection(
				(value as Dictionary).get(row.get("key")),
				depth + 1
			)
		return projected_dictionary
	if value is Object:
		return {
			"variant_type": "object_reference",
			"class": (value as Object).get_class(),
			"instance_id": str((value as Object).get_instance_id()),
		}
	return {"variant_type": type_string(typeof(value)), "value": str(value)}


func _is_owner_codec_data(value: Variant) -> bool:
	if value == null or value is String or value is bool \
			or value is int or value is Vector2 or value is Color:
		return true
	if value is float:
		return is_finite(value)
	if value is Array:
		for item in value as Array:
			if not _is_owner_codec_data(item):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String or key_variant is StringName) \
					or not _is_owner_codec_data((value as Dictionary).get(key_variant)):
				return false
		return true
	return false


func _owner_payload_fingerprint(value: Variant) -> String:
	if not _is_owner_codec_data(value):
		return ""
	return Marshalls.raw_to_base64(var_to_bytes(value)).sha256_text()


func _capture_failure_for_binding(
	binding: BindingScript,
	section_index: int,
	failure_class: String,
	reason_code: String,
	extra: Dictionary = {}
) -> Dictionary:
	var owner := get_node_or_null(binding.owner_path) if binding != null else null
	var owner_script_path := ""
	if owner != null:
		var owner_script: Script = owner.get_script() as Script
		owner_script_path = owner_script.resource_path if owner_script != null else ""
	var fields := {
		"registry_operation_id": "capture-%d" % _operation_sequence,
		"capture_sequence": _operation_sequence,
		"section_index": section_index,
		"section_id": binding.section_id if binding != null else "",
		"owner_id": binding.owner_id if binding != null else "",
		"owner_node_path": str(binding.owner_path) if binding != null else "",
		"owner_script_path": owner_script_path,
		"capture_method": binding.capture_method if binding != null else "",
		"failure_class": failure_class,
		"reason_code": CaptureFailureScript.sanitize_reason_code(reason_code),
	}
	fields.merge(extra, true)
	return CaptureFailureScript.build(fields)


func _classify_owner_preflight_failure(raw_state: Dictionary, reason_code: String) -> String:
	if raw_state.is_empty():
		return "OWNER_CAPTURE_EMPTY"
	if reason_code in CaptureFailureScript.NOT_PURE_REASON_CODES:
		return "OWNER_CAPTURE_NOT_PURE_DATA"
	if reason_code in CaptureFailureScript.HEADER_REASON_CODES:
		return "OWNER_CAPTURE_HEADER_INVALID"
	if reason_code in CaptureFailureScript.VERSION_REASON_CODES:
		return "OWNER_CAPTURE_VERSION_INVALID"
	if reason_code in CaptureFailureScript.RULESET_REASON_CODES:
		return "OWNER_CAPTURE_RULESET_INVALID"
	if reason_code in CaptureFailureScript.MUTATION_REASON_CODES:
		return "OWNER_CAPTURE_MUTATED_RUNTIME"
	return "REGISTRY_INTERNAL_ERROR"


func _strict_observed_int(value: Variant) -> int:
	return int(value) if typeof(value) == TYPE_INT else -1


func _section_capture_result(
	binding: BindingScript,
	captured: bool,
	reason_code: String,
	state_version: int,
	payload_fingerprint: String
) -> Dictionary:
	var owner_index := FIXED_SECTION_ORDER.find(binding.section_id) if binding != null else -1
	var row_context := _capture_diagnostic_row_context.duplicate(true) \
			if int(_capture_diagnostic_row_context.get("owner_index", -2)) == owner_index else {}
	var after_observation := _capture_progress_observation()
	var before_observation: Dictionary = row_context.get("observation", {}) \
			if row_context.get("observation", {}) is Dictionary else {}
	var rng_delta := _observation_delta(before_observation, after_observation, "rng_draw_invocation_count")
	var world_delta := _observation_delta(before_observation, after_observation, "world_clock_advance_count")
	var log_delta := _observation_delta(before_observation, after_observation, "public_log_entry_count")
	var elapsed_ms := maxi(0, Time.get_ticks_msec() - int(row_context.get("started_ms", Time.get_ticks_msec())))
	var mutation_count := 1 if reason_code in [
		"owner_capture_mutated_runtime", "owner_preflight_mutated_runtime",
		"owner_capture_cross_owner_mutation", "owner_capture_mutation_rollback_failed",
	] or rng_delta != 0 or world_delta != 0 or log_delta != 0 else 0
	var unsealed := {
		"owner_index": owner_index,
		"section_id": binding.section_id if binding != null else "",
		"owner_id": binding.owner_id if binding != null else "",
		"owner_path": str(binding.owner_path) if binding != null else "",
		"capture_started": not row_context.is_empty(),
		"capture_completed": not row_context.is_empty(),
		"capture_result_kind": "CAPTURED" if captured else "FAILED",
		"payload_schema_version": state_version,
		"payload_fingerprint": payload_fingerprint,
		"payload_pure_data": captured and not payload_fingerprint.is_empty(),
		"elapsed_milliseconds": elapsed_ms,
		"mutation_count": mutation_count,
		"rng_draw_delta": rng_delta,
		"world_time_delta": world_delta,
		"public_log_delta": log_delta,
		"reason_code": CaptureFailureScript.sanitize_reason_code(reason_code),
		"private_payload_redacted": true,
	}
	unsealed["row_evidence_fingerprint"] = _encoded_payload_fingerprint(unsealed)
	_emit_capture_diagnostic_progress(
		owner_index,
		str(unsealed.get("section_id", "")),
		str(unsealed.get("owner_id", "")),
		str(unsealed.get("capture_result_kind", "")),
		str(unsealed.get("reason_code", ""))
	)
	_capture_diagnostic_row_context.clear()
	return unsealed


func _begin_capture_diagnostic_row(binding: BindingScript, owner_index: int) -> void:
	_begin_capture_diagnostic_row_from_observation(
		binding,
		owner_index,
		Time.get_ticks_msec(),
		_capture_progress_observation()
	)


func _begin_capture_diagnostic_row_from_observation(
		binding: BindingScript,
		owner_index: int,
		started_ms: int,
		observation: Dictionary
) -> void:
	_capture_diagnostic_row_context = {
		"owner_index": owner_index,
		"started_ms": started_ms,
		"observation": observation.duplicate(true),
	}
	_emit_capture_diagnostic_progress(
		owner_index,
		binding.section_id if binding != null else "",
		binding.owner_id if binding != null else "",
		"STARTED",
		"owner_capture_started"
	)


func _capture_progress_observation() -> Dictionary:
	if _capture_diagnostic_progress_sink != null \
			and _capture_diagnostic_progress_sink.has_method("capture_owner_diagnostic_snapshot"):
		var value: Variant = _capture_diagnostic_progress_sink.call("capture_owner_diagnostic_snapshot")
		return (value as Dictionary).duplicate(true) if value is Dictionary else {}
	return {}


func _emit_capture_diagnostic_progress(
	owner_index: int,
	section_id: String,
	owner_id: String,
	result_kind: String,
	reason_code: String
) -> void:
	if _capture_diagnostic_progress_sink != null \
			and _capture_diagnostic_progress_sink.has_method("record_owner_capture_progress"):
		_capture_diagnostic_progress_sink.call(
			"record_owner_capture_progress",
			owner_index,
			section_id,
			owner_id,
			result_kind,
			reason_code
		)


func _observation_delta(before: Dictionary, after: Dictionary, field: String) -> int:
	if before.is_empty() or after.is_empty():
		return 0
	return int(after.get(field, 0)) - int(before.get(field, 0))


func _complete_diagnostic_section_rows(rows: Array, binding_by_section: Dictionary) -> Array:
	var rows_by_index: Dictionary = {}
	for row_variant in rows:
		if row_variant is Dictionary:
			rows_by_index[int((row_variant as Dictionary).get("owner_index", -1))] = (row_variant as Dictionary).duplicate(true)
	var complete: Array = []
	var failure_seen := false
	for owner_index in range(FIXED_SECTION_ORDER.size()):
		if rows_by_index.has(owner_index):
			var row := (rows_by_index.get(owner_index, {}) as Dictionary).duplicate(true)
			complete.append(row)
			failure_seen = failure_seen or str(row.get("capture_result_kind", "")) == "FAILED"
			continue
		var section_id := str(FIXED_SECTION_ORDER[owner_index])
		var binding := binding_by_section.get(section_id) as BindingScript
		var skipped := {
			"owner_index": owner_index,
			"section_id": section_id,
			"owner_id": binding.owner_id if binding != null else "",
			"owner_path": str(binding.owner_path) if binding != null else "",
			"capture_started": false,
			"capture_completed": false,
			"capture_result_kind": "NOT_ATTEMPTED_AFTER_FIRST_FAILURE",
			"payload_schema_version": -1,
			"payload_fingerprint": "",
			"payload_pure_data": false,
			"elapsed_milliseconds": 0,
			"mutation_count": 0,
			"rng_draw_delta": 0,
			"world_time_delta": 0,
			"public_log_delta": 0,
			"reason_code": "not_attempted_after_first_failure" if failure_seen else "not_attempted",
			"private_payload_redacted": true,
		}
		skipped["row_evidence_fingerprint"] = _encoded_payload_fingerprint(skipped)
		complete.append(skipped)
	return complete


func _encoded_payload_fingerprint(encoded_value: Variant) -> String:
	var handshake := _handshake_node()
	if handshake == null or not handshake.has_method("canonical_json"):
		return ""
	var canonical := str(handshake.call("canonical_json", encoded_value))
	return canonical.sha256_text() if not canonical.is_empty() else ""


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


func _registry_binding_checkpoint_strategy_v1(binding: BindingScript) -> String:
	if binding == null or not binding.is_transactional():
		return ""
	if not binding.checkpoint_method.strip_edges().is_empty():
		return CHECKPOINT_STRATEGY_EXPLICIT_OWNER_METHOD
	if not binding.capture_method.strip_edges().is_empty() \
			and not binding.rollback_method.strip_edges().is_empty():
		return CHECKPOINT_STRATEGY_REGISTRY_MANAGED
	return ""


func _registry_binding_checkpoint_strategy_valid_v1(
	strategy: String,
	checkpoint_method_present: bool,
	capture_method_exists: bool,
	checkpoint_method_exists: bool,
	rollback_method_exists: bool
) -> bool:
	match strategy:
		CHECKPOINT_STRATEGY_EXPLICIT_OWNER_METHOD:
			return checkpoint_method_present and checkpoint_method_exists and rollback_method_exists
		CHECKPOINT_STRATEGY_REGISTRY_MANAGED:
			return not checkpoint_method_present and capture_method_exists and rollback_method_exists
		CHECKPOINT_STRATEGY_OWNER_INTERNAL:
			return not checkpoint_method_present and rollback_method_exists
		_:
			return false


func _registry_binding_restore_dag_v1() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node_index in range(RESTORE_DAG_NODE_ORDER.size()):
		var node_id := str(RESTORE_DAG_NODE_ORDER[node_index])
		var dependencies: Array[String] = []
		dependencies.assign(RESTORE_DAG_DEPENDENCIES.get(node_id, []))
		result.append({
			"node_index": node_index,
			"node_id": node_id,
			"section_id": "session" if node_id in ["session_foundation", "session_tail"] else node_id,
			"dependencies": dependencies,
		})
	return result


func _registry_binding_restore_dag_valid_v1(restore_dag: Array[Dictionary]) -> bool:
	if restore_dag.size() != RESTORE_DAG_NODE_ORDER.size():
		return false
	var seen_nodes: Dictionary = {}
	for node_index in range(restore_dag.size()):
		var node: Dictionary = restore_dag[node_index]
		var node_id := str(node.get("node_id", ""))
		var section_id := str(node.get("section_id", ""))
		var dependencies: Array = node.get("dependencies", []) as Array
		if node_id != str(RESTORE_DAG_NODE_ORDER[node_index]) \
				or int(node.get("node_index", -1)) != node_index \
				or seen_nodes.has(node_id) \
				or section_id not in FIXED_SECTION_ORDER:
			return false
		if dependencies != RESTORE_DAG_DEPENDENCIES.get(node_id, []):
			return false
		for dependency_variant in dependencies:
			if not seen_nodes.has(str(dependency_variant)):
				return false
		seen_nodes[node_id] = true
	return true


func _registry_binding_restore_nodes_v1(
	section_id: String,
	restore_dag: Array[Dictionary]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in restore_dag:
		if str(node.get("section_id", "")) == section_id:
			result.append(node.duplicate(true))
	return result


func _registry_binding_dependency_ids_v1(restore_nodes: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for node in restore_nodes:
		for dependency_variant in node.get("dependencies", []) as Array:
			var dependency_id := str(dependency_variant)
			if not result.has(dependency_id):
				result.append(dependency_id)
	return result


func _registry_binding_contract_fingerprint_v1(row: Dictionary) -> String:
	var handshake := _handshake_node()
	if handshake == null or not handshake.has_method("canonical_json"):
		return ""
	var canonical := str(handshake.call("canonical_json", row))
	return canonical.sha256_text() if not canonical.is_empty() else ""


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


func _consume_test_capture_live_fingerprint_failure(section_id: String) -> bool:
	if _test_capture_live_fingerprint_failure_once != section_id:
		return false
	_test_capture_live_fingerprint_failure_once = ""
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
