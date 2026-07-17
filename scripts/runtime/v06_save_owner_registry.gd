@tool
extends Node
class_name V06SaveOwnerRegistry

const BindingScript := preload("res://scripts/runtime/v06_save_owner_binding_resource.gd")
const REGISTRY_ID := "v06_save_owner_registry"
const REGISTRY_VERSION := 1
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
	"all_owner_preflights_passed",
	"owner_checkpoint_capture_failed",
	"owner_apply_failed",
	"owners_applied",
]
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
	"ai",
	"bankruptcy_neutral_estate",
	"victory_control",
	"session",
]

@export var handshake_path: NodePath
@export var bindings: Array[BindingScript] = []

var _operation_in_progress := false
var _operation_sequence := 0


func fixed_section_order() -> Array[String]:
	var result: Array[String] = []
	for section_id in FIXED_SECTION_ORDER:
		result.append(str(section_id))
	return result


func registry_snapshot() -> Dictionary:
	var analysis := _registry_analysis()
	return {
		"registry_id": REGISTRY_ID,
		"registry_version": REGISTRY_VERSION,
		"valid": bool(analysis.get("valid", false)),
		"resume_ready": bool(analysis.get("resume_ready", false)),
		"required_section_count": FIXED_SECTION_ORDER.size(),
		"binding_count": bindings.size(),
		"transactional_section_count": int(analysis.get("transactional_section_count", 0)),
		"unsupported_section_count": int(analysis.get("unsupported_section_count", 0)),
		"errors": (analysis.get("errors", []) as Array).duplicate(),
		"contracts": (analysis.get("contracts", []) as Array).duplicate(true),
		"fixed_apply_order": FIXED_SECTION_ORDER.duplicate(),
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
	var internal := _preflight_envelope_internal(envelope)
	_operation_in_progress = false
	return {
		"operation": "preflight",
		"ok": bool(internal.get("ok", false)),
		"reason_code": str(internal.get("reason_code", "owner_preflight_rejected")),
		"registry_id": REGISTRY_ID,
		"registry_version": REGISTRY_VERSION,
		"envelope_valid": bool(internal.get("envelope_valid", false)),
		"preflight_complete": bool(internal.get("preflight_complete", false)),
		"preflight_count": int(internal.get("preflight_count", 0)),
		"unsupported_count": int(internal.get("unsupported_count", 0)),
	}


func apply_envelope(envelope: Dictionary) -> Dictionary:
	if _operation_in_progress:
		return _result("apply", false, "registry_busy")
	_operation_in_progress = true
	_operation_sequence += 1
	var preflight := _preflight_envelope_internal(envelope)
	if not bool(preflight.get("ok", false)):
		_operation_in_progress = false
		var rejected := _result("apply", false, str(preflight.get("reason_code", "owner_preflight_rejected")))
		rejected["envelope_valid"] = bool(preflight.get("envelope_valid", false))
		rejected["preflight_complete"] = false
		rejected["preflight_count"] = int(preflight.get("preflight_count", 0))
		rejected["unsupported_count"] = int(preflight.get("unsupported_count", 0))
		return rejected
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
			return checkpoint_rejected
		checkpoints[section_id] = checkpoint
	var applied_sections: Array[String] = []
	for section_id in FIXED_SECTION_ORDER:
		var binding := binding_by_section.get(section_id) as BindingScript
		var owner := get_node_or_null(binding.owner_path)
		var planned: Dictionary = plan.get(section_id, {})
		var apply_variant: Variant = owner.call(binding.apply_method, (planned.get("decoded_owner_state", {}) as Dictionary).duplicate(true))
		var apply_receipt: Dictionary = apply_variant if apply_variant is Dictionary else {}
		applied_sections.append(section_id)
		var post_capture := _capture_owner_checkpoint(binding)
		var applied_exactly := bool(apply_receipt.get("applied", false)) \
			and bool(post_capture.get("ok", false)) \
			and _same_encoded_state(post_capture.get("encoded_owner_state"), planned.get("normalized_encoded_owner_state"))
		if not applied_exactly:
			var rollback := _rollback_sections(applied_sections, checkpoints, binding_by_section)
			_operation_in_progress = false
			var failed := _result("apply", false, "owner_apply_failed")
			failed["envelope_valid"] = true
			failed["preflight_complete"] = true
			failed["apply_count"] = maxi(0, applied_sections.size() - 1)
			failed["rollback_attempted"] = true
			failed["rollback_complete"] = bool(rollback.get("complete", false))
			failed["applied_section_ids"] = applied_sections.duplicate()
			failed["rollback_section_ids"] = (rollback.get("section_ids", []) as Array).duplicate()
			return failed
	_operation_in_progress = false
	var success := _result("apply", true, "owners_applied")
	success["envelope_valid"] = true
	success["preflight_complete"] = true
	success["apply_count"] = applied_sections.size()
	success["rollback_attempted"] = false
	success["rollback_complete"] = true
	success["applied_section_ids"] = applied_sections.duplicate()
	return success


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
	for key in ["envelope_valid", "preflight_complete", "rollback_attempted", "rollback_complete"]:
		if receipt.has(key):
			result[key] = _public_bool(receipt.get(key))
	for key in ["preflight_count", "apply_count", "unsupported_count"]:
		if receipt.has(key):
			result[key] = _public_nonnegative_int(receipt.get(key))
	return result


func debug_snapshot() -> Dictionary:
	var snapshot := registry_snapshot()
	snapshot["operation_in_progress"] = _operation_in_progress
	snapshot["operation_sequence"] = _operation_sequence
	snapshot["pure_data_capture"] = true
	snapshot["global_preflight_before_apply"] = true
	snapshot["reverse_order_rollback"] = true
	snapshot["public_receipt_allowlisted"] = true
	return snapshot


func _capture_resume_envelope_internal(identity: Dictionary) -> Dictionary:
	var analysis := _registry_analysis()
	if not bool(analysis.get("valid", false)):
		return _result("capture", false, "owner_registry_invalid")
	if not bool(analysis.get("resume_ready", false)):
		var unsupported := _result("capture", false, "restore_capability_incomplete")
		unsupported["unsupported_count"] = int(analysis.get("unsupported_section_count", 0))
		unsupported["unsupported_section_ids"] = (analysis.get("unsupported_section_ids", []) as Array).duplicate()
		return unsupported
	var handshake := _handshake_node()
	var binding_by_section: Dictionary = analysis.get("binding_by_section", {})
	var session_section: Dictionary = {}
	var domain_sections: Dictionary = {}
	for section_id in FIXED_SECTION_ORDER:
		var binding := binding_by_section.get(section_id) as BindingScript
		var captured := _capture_owner_checkpoint(binding)
		if not bool(captured.get("ok", false)):
			return _result("capture", false, "owner_capture_failed")
		var wrapper := {
			"schema_version": binding.state_version,
			"owner_id": binding.owner_id,
			"owner_state": captured.get("encoded_owner_state"),
		}
		if section_id == "session":
			session_section = wrapper
		else:
			domain_sections[section_id] = wrapper
	var envelope_variant: Variant = handshake.call("compose_v06_envelope", session_section, domain_sections, identity)
	var envelope: Dictionary = (envelope_variant as Dictionary).duplicate(true) if envelope_variant is Dictionary else {}
	var validation_variant: Variant = handshake.call("validate_envelope", envelope)
	var validation: Dictionary = validation_variant if validation_variant is Dictionary else {}
	if envelope.is_empty() or not bool(validation.get("valid", false)):
		return _result("capture", false, "captured_envelope_invalid")
	var success := _result("capture", true, "resume_envelope_captured")
	success["envelope_valid"] = true
	success["envelope"] = envelope
	success["fingerprint"] = str(validation.get("fingerprint", ""))
	return success


func _preflight_envelope_internal(envelope: Dictionary) -> Dictionary:
	var analysis := _registry_analysis()
	if not bool(analysis.get("valid", false)):
		return {"ok": false, "reason_code": "owner_registry_invalid", "envelope_valid": false, "preflight_complete": false}
	var handshake := _handshake_node()
	var validation_variant: Variant = handshake.call("validate_envelope", envelope)
	var validation: Dictionary = validation_variant if validation_variant is Dictionary else {}
	if not bool(validation.get("valid", false)):
		return {"ok": false, "reason_code": "envelope_validation_failed", "envelope_valid": false, "preflight_complete": false}
	if not bool(analysis.get("resume_ready", false)):
		return {
			"ok": false,
			"reason_code": "restore_capability_incomplete",
			"envelope_valid": true,
			"preflight_complete": false,
			"unsupported_count": int(analysis.get("unsupported_section_count", 0)),
		}
	var sections: Dictionary = envelope.get("sections", {}) if envelope.get("sections", {}) is Dictionary else {}
	var binding_by_section: Dictionary = analysis.get("binding_by_section", {})
	var plan: Dictionary = {}
	var preflight_count := 0
	for section_id in FIXED_SECTION_ORDER:
		var binding := binding_by_section.get(section_id) as BindingScript
		var decoded := _decode_section_wrapper(sections.get(section_id), binding)
		if not bool(decoded.get("ok", false)):
			return {"ok": false, "reason_code": "section_wrapper_invalid", "envelope_valid": true, "preflight_complete": false, "preflight_count": preflight_count}
		var owner := get_node_or_null(binding.owner_path)
		var owner_preflight := _preflight_owner(owner, binding, decoded.get("owner_state", {}) as Dictionary)
		if not bool(owner_preflight.get("ok", false)):
			return {"ok": false, "reason_code": "owner_preflight_rejected", "envelope_valid": true, "preflight_complete": false, "preflight_count": preflight_count}
		plan[section_id] = {
			"decoded_owner_state": (decoded.get("owner_state", {}) as Dictionary).duplicate(true),
			"normalized_encoded_owner_state": owner_preflight.get("normalized_encoded_owner_state"),
		}
		preflight_count += 1
	return {
		"ok": true,
		"reason_code": "all_owner_preflights_passed",
		"envelope_valid": true,
		"preflight_complete": true,
		"preflight_count": preflight_count,
		"plan": plan,
	}


func _preflight_owner(owner: Node, binding: BindingScript, owner_state: Dictionary) -> Dictionary:
	if owner == null:
		return {"ok": false}
	if not binding.preflight_method.is_empty():
		var preflight_variant: Variant = owner.call(binding.preflight_method, owner_state.duplicate(true))
		var preflight_receipt: Dictionary = preflight_variant if preflight_variant is Dictionary else {}
		if not bool(preflight_receipt.get("accepted", false)):
			return {"ok": false}
		var preflight_normalized_state: Dictionary = (
			(preflight_receipt.get("normalized_state", {}) as Dictionary).duplicate(true)
			if preflight_receipt.get("normalized_state", {}) is Dictionary
			else owner_state.duplicate(true)
		)
		var normalized_encoded := _encode_owner_state(preflight_normalized_state)
		if not bool(normalized_encoded.get("ok", false)):
			return {"ok": false}
		return {"ok": true, "normalized_encoded_owner_state": normalized_encoded.get("value")}
	var probe_variant: Variant = owner.duplicate()
	if not (probe_variant is Node):
		return {"ok": false}
	var probe := probe_variant as Node
	var apply_variant: Variant = probe.call(binding.apply_method, owner_state.duplicate(true))
	var apply_receipt: Dictionary = apply_variant if apply_variant is Dictionary else {}
	if not bool(apply_receipt.get("applied", false)):
		probe.free()
		return {"ok": false}
	var normalized_variant: Variant = probe.call(binding.capture_method)
	var normalized_state: Dictionary = (normalized_variant as Dictionary).duplicate(true) if normalized_variant is Dictionary else {}
	var encoded := _encode_owner_state(normalized_state)
	probe.free()
	if not bool(encoded.get("ok", false)):
		return {"ok": false}
	return {"ok": true, "normalized_encoded_owner_state": encoded.get("value")}


func _capture_owner_checkpoint(binding: BindingScript) -> Dictionary:
	var owner := get_node_or_null(binding.owner_path)
	if owner == null or not owner.has_method(binding.capture_method):
		return {"ok": false}
	var raw_variant: Variant = owner.call(binding.capture_method)
	if not (raw_variant is Dictionary):
		return {"ok": false}
	var raw_state := (raw_variant as Dictionary).duplicate(true)
	var encoded := _encode_owner_state(raw_state)
	if not bool(encoded.get("ok", false)):
		return {"ok": false}
	return {
		"ok": true,
		"raw_owner_state": raw_state,
		"encoded_owner_state": encoded.get("value"),
	}


func _rollback_sections(applied_sections: Array[String], checkpoints: Dictionary, binding_by_section: Dictionary) -> Dictionary:
	var rollback_section_ids: Array[String] = []
	var complete := true
	for index in range(applied_sections.size() - 1, -1, -1):
		var section_id := applied_sections[index]
		var binding := binding_by_section.get(section_id) as BindingScript
		var owner := get_node_or_null(binding.owner_path)
		var checkpoint: Dictionary = checkpoints.get(section_id, {})
		var rollback_variant: Variant = owner.call(binding.rollback_method, (checkpoint.get("raw_owner_state", {}) as Dictionary).duplicate(true)) if owner != null else {}
		var rollback_receipt: Dictionary = rollback_variant if rollback_variant is Dictionary else {}
		var after := _capture_owner_checkpoint(binding)
		var restored_exactly := bool(rollback_receipt.get("applied", false)) \
			and bool(after.get("ok", false)) \
			and _same_encoded_state(after.get("encoded_owner_state"), checkpoint.get("encoded_owner_state"))
		complete = complete and restored_exactly
		rollback_section_ids.append(section_id)
	return {"complete": complete, "section_ids": rollback_section_ids}


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
	var handshake := _handshake_node()
	var decoded_variant: Variant = handshake.call("decode_codec_value", wrapper.get("owner_state"))
	var decoded: Dictionary = decoded_variant if decoded_variant is Dictionary else {}
	if not bool(decoded.get("ok", false)) or not (decoded.get("value") is Dictionary):
		return {"ok": false}
	return {"ok": true, "owner_state": (decoded.get("value") as Dictionary).duplicate(true)}


func _encode_owner_state(owner_state: Dictionary) -> Dictionary:
	var handshake := _handshake_node()
	if handshake == null or not handshake.has_method("encode_codec_value"):
		return {"ok": false}
	var encoded_variant: Variant = handshake.call("encode_codec_value", owner_state)
	return (encoded_variant as Dictionary).duplicate(true) if encoded_variant is Dictionary else {"ok": false}


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
	var manifest: Dictionary = handshake.call("required_section_manifest") if handshake != null and handshake.has_method("required_section_manifest") else {}
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


func _handshake_node() -> Node:
	return get_node_or_null(handshake_path) if not handshake_path.is_empty() else null


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
