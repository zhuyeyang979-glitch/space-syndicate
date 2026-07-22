extends Node
class_name V06SaveOwnerRegistryBench

const BindingScript := preload("res://scripts/runtime/v06_save_owner_binding_resource.gd")
const RegistryScript := preload("res://scripts/runtime/v06_save_owner_registry.gd")
const FakeOwnerScript := preload("res://scripts/tools/v06_save_owner_registry_fake_owner.gd")
const HANDSHAKE_SCENE := preload("res://scenes/runtime/RulesetSaveHandshakeService.tscn")
const EXPECTED_FIXED_ORDER := [
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
const PRIVATE_SENTINELS := [
	"98765432100",
	"V06_OWNER_REGISTRY_PRIVATE_HAND",
	"V06_OWNER_REGISTRY_OWNER_TRUTH",
	"V06_OWNER_REGISTRY_AI_PLAN",
]
const FORBIDDEN_PUBLIC_KEYS := [
	"envelope",
	"sections",
	"owner_state",
	"private_cash_cents",
	"private_hand",
	"owner_truth",
	"ai_plan",
	"applied_section_ids",
	"rollback_section_ids",
]

@export var auto_run_on_ready := true

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	if auto_run_on_ready and not Engine.is_editor_hint():
		call_deferred("_run_from_scene")


func _run_from_scene() -> void:
	var result := run_bench()
	print("V06_SAVE_OWNER_REGISTRY_BENCH|status=%s|checks=%d|failures=%d|details=%s|evidence=%s" % [
		"PASS" if bool(result.get("passed", false)) else "FAIL",
		int(result.get("checks", 0)),
		int(result.get("failure_count", 0)),
		JSON.stringify(result.get("failures", [])),
		JSON.stringify(result.get("evidence", {})),
	])
	if not bool(result.get("passed", false)):
		push_error("v0.6 save owner registry Bench failed: %s" % JSON.stringify(result.get("failures", [])))


func run_bench() -> Dictionary:
	_checks = 0
	_failures.clear()
	var production_registry := get_node_or_null("GameRuntimeCoordinator/GameSessionRuntimeController/V06SaveOwnerRegistry")
	_check(production_registry != null, "production_registry_scene_wired")
	var production_snapshot: Dictionary = production_registry.registry_snapshot() if production_registry != null else {}
	_check(bool(production_snapshot.get("valid", false)), "production_registry_matches_handshake_manifest")
	_check(int(production_snapshot.get("required_section_count", 0)) == 19 and int(production_snapshot.get("binding_count", 0)) == 19, "production_registry_has_all_19_unique_sections")
	_check(int(production_snapshot.get("transactional_section_count", 0)) == 12 and int(production_snapshot.get("unsupported_section_count", 0)) == 7 and not bool(production_snapshot.get("resume_ready", true)), "production_registry_declares_twelve_auditable_transactional_owners")
	_check(_binding_matches(production_registry, "region_supply", "region_supply", "../../RegionSupplyRuntimeController", 1), "region_supply_section_uses_the_unique_transactional_rack_owner")
	_check(_commodity_binding_is_transactional(production_registry), "commodity_flow_section_uses_the_unique_transactional_economy_owner_and_pure_preflight")
	_check(_bankruptcy_binding_is_transactional(production_registry), "bankruptcy_section_uses_the_unique_transactional_estate_owner")
	_check(_weather_binding_is_transactional(production_registry), "weather_section_uses_the_unique_transactional_weather_owner")
	_check(_binding_is_transactional(production_registry, "card_resolution_execution"), "card_execution_section_uses_the_unique_transactional_execution_owner")
	_check(_history_binding_is_transactional(production_registry), "card_history_section_uses_the_unique_transactional_history_owner")
	_check(not bool(production_snapshot.get("captures_business_state", true)) and not bool(production_snapshot.get("stores_parallel_owner_state", true)), "registry_bindings_copy_no_bankruptcy_or_participant_journal_state")
	var production_capture: Dictionary = production_registry.capture_resume_envelope({"envelope_id": "production-reject", "write_id": "production-reject"}) if production_registry != null else {}
	_check(not bool(production_capture.get("ok", true)) and str(production_capture.get("reason_code", "")) == "restore_capability_incomplete" and not production_capture.has("envelope"), "production_capture_fails_closed_without_complete_owner_capability")
	var production_public: Dictionary = production_registry.public_operation_receipt(production_capture) if production_registry != null else {}
	_check(_public_receipt_safe(production_public), "production_rejection_receipt_is_allowlisted_and_private")

	var harness := _build_transactional_harness()
	var registry := harness.get_node_or_null("V06SaveOwnerRegistry")
	var handshake := harness.get_node_or_null("RulesetSaveHandshakeService")
	_check(registry != null and handshake != null, "transactional_harness_uses_real_registry_and_handshake")
	if registry == null or handshake == null:
		return _finish(production_snapshot, {})
	var fixed_order: Array[String] = registry.fixed_section_order()
	var fake_snapshot: Dictionary = registry.registry_snapshot()
	_check(bool(fake_snapshot.get("valid", false)) and bool(fake_snapshot.get("resume_ready", false)) and int(fake_snapshot.get("transactional_section_count", 0)) == 19, "complete_transactional_registry_is_resume_ready")
	_check(fixed_order == EXPECTED_FIXED_ORDER and fixed_order[-1] == "session", "fixed_apply_order_is_complete_and_session_last")

	var original_bindings: Array[BindingScript] = registry.bindings.duplicate()
	var duplicate_bindings: Array[BindingScript] = original_bindings.duplicate()
	duplicate_bindings.append(original_bindings[0])
	registry.bindings = duplicate_bindings
	_check(not bool(registry.registry_snapshot().get("valid", true)), "duplicate_section_or_owner_binding_rejects")
	registry.bindings = original_bindings

	var capture: Dictionary = registry.capture_resume_envelope({"envelope_id": "registry-bench-1", "write_id": "registry-bench-write-1"})
	var envelope: Dictionary = capture.get("envelope", {}) if capture.get("envelope", {}) is Dictionary else {}
	var validation: Dictionary = handshake.call("validate_envelope", envelope) if not envelope.is_empty() else {}
	_check(bool(capture.get("ok", false)) and bool(validation.get("valid", false)) and (envelope.get("sections", {}) as Dictionary).size() == 19, "capture_composes_one_valid_full_manifest_envelope")
	_check(JSON.stringify(envelope).contains("Vector2") and JSON.stringify(envelope).contains("Color"), "capture_uses_handshake_explicit_variant_codec")
	_check(_public_receipt_safe(registry.public_operation_receipt(capture)), "capture_public_receipt_omits_envelope_and_private_owner_state")
	var forged_public: Dictionary = registry.public_operation_receipt({
		"operation": {"private_hand": [PRIVATE_SENTINELS[1]]},
		"ok": true,
		"reason_code": PRIVATE_SENTINELS[2],
		"registry_id": {"ai_plan": PRIVATE_SENTINELS[3]},
		"operation_sequence": {"private_cash_cents": 98765432100},
	})
	_check(_public_receipt_safe(forged_public) and not bool(forged_public.get("ok", true)) and str(forged_public.get("operation", "")) == "unknown" and str(forged_public.get("reason_code", "")) == "registry_receipt_invalid", "public_receipt_type_normalization_rejects_forged_allowlisted_values")

	var success_envelope := _envelope_with_values(handshake, envelope, fixed_order, 100)
	var preflight: Dictionary = registry.preflight_envelope(success_envelope)
	_check(bool(preflight.get("ok", false)) and bool(preflight.get("envelope_valid", false)) and bool(preflight.get("preflight_complete", false)) and int(preflight.get("preflight_count", 0)) == 19, "all_owner_preflights_complete_before_apply")
	var success: Dictionary = registry.apply_envelope(success_envelope)
	_check(bool(success.get("ok", false)) and success.get("applied_section_ids", []) == fixed_order and int(success.get("apply_count", 0)) == 19, "owners_apply_once_in_fixed_order")
	_check(_owner_values_match(harness, fixed_order, 100), "successful_apply_commits_all_normalized_owner_states")
	_check(_public_receipt_safe(registry.public_operation_receipt(success)), "success_public_receipt_omits_sections_balances_hands_owner_truth_and_ai_plan")
	var dependency_before := _owner_states(harness, fixed_order)
	var dependency_apply_counts_before := _owner_apply_counts(harness, fixed_order)
	var missing_dependency_envelope := success_envelope.duplicate(true)
	var dependency_sections: Dictionary = missing_dependency_envelope.get("sections", {})
	var session_wrapper: Dictionary = (dependency_sections.get("session", {}) as Dictionary).duplicate(true)
	var session_decoded: Dictionary = handshake.call("decode_codec_value", session_wrapper.get("owner_state"))
	var session_owner_state: Dictionary = (session_decoded.get("value", {}) as Dictionary).duplicate(true)
	var annotation_state: Dictionary = session_owner_state.get("card_history_private_annotations", {})
	annotation_state["annotations_by_viewer"] = {"0": {"card-history:999": {}}}
	session_owner_state["card_history_private_annotations"] = annotation_state
	var session_encoded: Dictionary = handshake.call("encode_codec_value", session_owner_state)
	session_wrapper["owner_state"] = session_encoded.get("value")
	dependency_sections["session"] = session_wrapper
	missing_dependency_envelope["sections"] = dependency_sections
	var missing_dependency: Dictionary = registry.apply_envelope(missing_dependency_envelope)
	_check(not bool(missing_dependency.get("ok", true)) and str(missing_dependency.get("reason_code", "")) == "cross_section_dependency_rejected" and int(missing_dependency.get("preflight_count", 0)) == fixed_order.size(), "missing_history_reference_rejects_after_all_structural_preflights_and_before_apply")
	_check(_same_data(dependency_before, _owner_states(harness, fixed_order)) and _same_data(dependency_apply_counts_before, _owner_apply_counts(harness, fixed_order)), "cross_section_dependency_rejection_mutates_zero_live_owners")
	_check(_public_receipt_safe(registry.public_operation_receipt(missing_dependency)), "cross_section_rejection_public_receipt_exposes_no_private_payload")

	var before_rejections := _owner_states(harness, fixed_order)
	var before_rejection_apply_counts := _owner_apply_counts(harness, fixed_order)
	var malformed_section := success_envelope.duplicate(true)
	var rejection_section := fixed_order[-1]
	var rejection_wrapper: Dictionary = ((malformed_section.get("sections", {}) as Dictionary).get(rejection_section, {}) as Dictionary).duplicate(true)
	var decoded: Dictionary = handshake.call("decode_codec_value", rejection_wrapper.get("owner_state"))
	var invalid_owner_state: Dictionary = (decoded.get("value", {}) as Dictionary).duplicate(true)
	invalid_owner_state["value"] = "not-an-integer"
	var invalid_encoded: Dictionary = handshake.call("encode_codec_value", invalid_owner_state)
	rejection_wrapper["owner_state"] = invalid_encoded.get("value")
	(malformed_section.get("sections", {}) as Dictionary)[rejection_section] = rejection_wrapper
	_check(bool((handshake.call("validate_envelope", malformed_section) as Dictionary).get("valid", false)), "handshake_accepts_structural_envelope_before_owner_preflight")
	var owner_rejected: Dictionary = registry.apply_envelope(malformed_section)
	_check(not bool(owner_rejected.get("ok", true)) and str(owner_rejected.get("reason_code", "")) == "owner_preflight_rejected" and int(owner_rejected.get("preflight_count", -1)) == fixed_order.size() - 1, "late_owner_preflight_failure_occurs_after_all_prior_detached_probes")
	_check(_same_data(before_rejections, _owner_states(harness, fixed_order)) and _same_data(before_rejection_apply_counts, _owner_apply_counts(harness, fixed_order)), "late_owner_preflight_failure_mutates_zero_live_owners")
	var missing_section := success_envelope.duplicate(true)
	(missing_section.get("sections", {}) as Dictionary).erase(fixed_order[0])
	var envelope_rejected: Dictionary = registry.apply_envelope(missing_section)
	_check(not bool(envelope_rejected.get("ok", true)) and str(envelope_rejected.get("reason_code", "")) == "envelope_validation_failed" and _same_data(before_rejections, _owner_states(harness, fixed_order)), "full_envelope_validation_precedes_all_owner_preflights")

	var rollback_capture: Dictionary = registry.capture_resume_envelope({"envelope_id": "registry-bench-2", "write_id": "registry-bench-write-2"})
	var rollback_envelope := _envelope_with_values(handshake, rollback_capture.get("envelope", {}) as Dictionary, fixed_order, 300)
	var rollback_before := _owner_states(harness, fixed_order)
	var failure_section := "monsters"
	var failure_owner := harness.get_node_or_null(_owner_node_name(failure_section))
	failure_owner.arm_fail_once()
	var rollback_result: Dictionary = registry.apply_envelope(rollback_envelope)
	var expected_applied: Array = fixed_order.slice(0, fixed_order.find(failure_section) + 1)
	var expected_rollback := expected_applied.duplicate()
	expected_rollback.reverse()
	_check(not bool(rollback_result.get("ok", true)) and bool(rollback_result.get("rollback_attempted", false)) and bool(rollback_result.get("rollback_complete", false)), "mid_apply_partial_failure_triggers_complete_rollback")
	_check(rollback_result.get("applied_section_ids", []) == expected_applied and rollback_result.get("rollback_section_ids", []) == expected_rollback, "rollback_runs_in_exact_reverse_applied_order_including_failed_owner")
	_check(_same_data(rollback_before, _owner_states(harness, fixed_order)), "rollback_restores_every_touched_owner_exactly")
	_check(_public_receipt_safe(registry.public_operation_receipt(rollback_result)), "rollback_public_receipt_exposes_no_section_or_private_state")

	var evidence := {
		"production_required_sections": int(production_snapshot.get("required_section_count", 0)),
		"production_transactional_sections": int(production_snapshot.get("transactional_section_count", 0)),
		"production_unsupported_sections": int(production_snapshot.get("unsupported_section_count", 0)),
		"production_resume_ready": bool(production_snapshot.get("resume_ready", true)),
		"region_supply_section_transactional": _binding_is_transactional(production_registry, "region_supply"),
		"commodity_flow_section_transactional": _binding_is_transactional(production_registry, "commodity_flow"),
		"bankruptcy_section_registered": _bankruptcy_binding_is_transactional(production_registry),
		"bankruptcy_section_transactional": _binding_is_transactional(production_registry, "bankruptcy_neutral_estate"),
		"bankruptcy_unsupported_reason": _binding_unsupported_reason(production_registry, "bankruptcy_neutral_estate"),
		"weather_section_transactional": _binding_is_transactional(production_registry, "weather"),
		"weather_unsupported_reason": _binding_unsupported_reason(production_registry, "weather"),
		"card_execution_section_transactional": _binding_is_transactional(production_registry, "card_resolution_execution"),
		"card_execution_unsupported_reason": _binding_unsupported_reason(production_registry, "card_resolution_execution"),
		"card_history_section_transactional": _history_binding_is_transactional(production_registry),
		"card_history_unsupported_reason": _binding_unsupported_reason(production_registry, "card_resolution_history"),
		"transactional_harness_sections": fixed_order.size(),
		"fixed_apply_order_count": fixed_order.size(),
		"global_preflight": bool(preflight.get("preflight_complete", false)),
		"rollback_complete": bool(rollback_result.get("rollback_complete", false)),
		"public_receipt_private": _public_receipt_safe(registry.public_operation_receipt(rollback_result)),
		"full_production_restore_claimed": false,
	}
	harness.queue_free()
	return _finish(production_snapshot, evidence)


func _build_transactional_harness() -> Node:
	var existing := get_node_or_null("TransactionalHarness")
	if existing != null:
		existing.free()
	var harness := Node.new()
	harness.name = "TransactionalHarness"
	add_child(harness)
	var handshake := HANDSHAKE_SCENE.instantiate()
	handshake.name = "RulesetSaveHandshakeService"
	harness.add_child(handshake)
	var registry := RegistryScript.new()
	registry.name = "V06SaveOwnerRegistry"
	registry.handshake_path = NodePath("../RulesetSaveHandshakeService")
	var manifest: Dictionary = handshake.call("required_section_manifest")
	var configured_bindings: Array[BindingScript] = []
	var order: Array[String] = registry.fixed_section_order()
	for index in range(order.size()):
		var section_id := order[index]
		var contract: Dictionary = manifest.get(section_id, {}) if manifest.get(section_id, {}) is Dictionary else {}
		var owner := FakeOwnerScript.new()
		owner.name = _owner_node_name(section_id)
		owner.configure(section_id, index)
		harness.add_child(owner)
		var binding := BindingScript.new()
		binding.section_id = section_id
		binding.owner_id = str(contract.get("owner_id", ""))
		binding.state_version = int(contract.get("state_version", 0))
		binding.owner_path = NodePath("../%s" % owner.name)
		binding.capture_method = "to_save_data"
		binding.apply_method = "apply_save_data"
		binding.rollback_method = "apply_save_data"
		binding.restore_mode = BindingScript.RESTORE_TRANSACTIONAL
		binding.unsupported_reason = ""
		configured_bindings.append(binding)
	registry.bindings = configured_bindings
	harness.add_child(registry)
	return harness


func _bankruptcy_binding_is_transactional(registry: Node) -> bool:
	if registry == null:
		return false
	for binding in registry.bindings:
		if binding == null or binding.section_id != "bankruptcy_neutral_estate":
			continue
		return binding.owner_id == "bankruptcy_neutral_estate" \
			and binding.state_version == 1 \
			and binding.restore_mode == BindingScript.RESTORE_TRANSACTIONAL \
			and binding.unsupported_reason.is_empty() \
			and str(binding.owner_path) == "../../BankruptcyNeutralEstateRuntimeController" \
			and binding.capture_method == "to_save_data" \
			and binding.apply_method == "apply_save_data" \
			and binding.rollback_method == "apply_save_data"
	return false


func _commodity_binding_is_transactional(registry: Node) -> bool:
	if registry == null:
		return false
	for binding in registry.bindings:
		if binding == null or binding.section_id != "commodity_flow":
			continue
		return binding.owner_id == "commodity_flow" \
			and binding.state_version == 2 \
			and binding.restore_mode == BindingScript.RESTORE_TRANSACTIONAL \
			and binding.unsupported_reason.is_empty() \
			and str(binding.owner_path) == "../../CommodityFlowRuntimeController" \
			and binding.capture_method == "to_save_data" \
			and binding.preflight_method == "preflight_save_data" \
			and binding.apply_method == "apply_save_data" \
			and binding.rollback_method == "apply_save_data"
	return false


func _weather_binding_is_transactional(registry: Node) -> bool:
	if registry == null:
		return false
	for binding in registry.bindings:
		if binding == null or binding.section_id != "weather":
			continue
		return binding.owner_id == "weather_runtime" \
			and binding.state_version == 1 \
			and binding.restore_mode == BindingScript.RESTORE_TRANSACTIONAL \
			and binding.unsupported_reason.is_empty() \
			and str(binding.owner_path) == "../../WeatherRuntimeController" \
			and binding.capture_method == "to_save_data" \
			and binding.apply_method == "apply_save_data" \
			and binding.rollback_method == "apply_save_data"
	return false


func _history_binding_is_transactional(registry: Node) -> bool:
	if registry == null:
		return false
	for binding in registry.bindings:
		if binding == null or binding.section_id != "card_resolution_history":
			continue
		return binding.owner_id == "card_resolution_history" \
			and binding.state_version == 1 \
			and binding.restore_mode == BindingScript.RESTORE_TRANSACTIONAL \
			and binding.unsupported_reason.is_empty() \
			and str(binding.owner_path) == "../../CardResolutionHistoryRuntimeService" \
			and binding.capture_method == "to_save_data" \
			and binding.preflight_method == "preflight_save_data" \
			and binding.apply_method == "apply_save_data" \
			and binding.rollback_method == "apply_save_data"
	return false


func _binding_matches(
	registry: Node,
	section_id: String,
	owner_id: String,
	owner_path: String,
	state_version: int
) -> bool:
	if registry == null:
		return false
	for binding in registry.bindings:
		if binding == null or binding.section_id != section_id:
			continue
		return binding.owner_id == owner_id \
			and binding.state_version == state_version \
			and binding.restore_mode == BindingScript.RESTORE_TRANSACTIONAL \
			and binding.unsupported_reason.is_empty() \
			and str(binding.owner_path) == owner_path \
			and binding.capture_method == "to_save_data" \
			and binding.apply_method == "apply_save_data" \
			and binding.rollback_method == "apply_save_data"
	return false


func _binding_unsupported_reason(registry: Node, section_id: String) -> String:
	if registry == null:
		return ""
	for binding in registry.bindings:
		if binding != null and binding.section_id == section_id:
			return str(binding.unsupported_reason)
	return ""


func _binding_is_transactional(registry: Node, section_id: String) -> bool:
	if registry == null:
		return false
	for binding in registry.bindings:
		if binding != null and binding.section_id == section_id:
			return binding.is_transactional()
	return false


func _envelope_with_values(handshake: Node, source: Dictionary, order: Array[String], base_value: int) -> Dictionary:
	var result := source.duplicate(true)
	var sections: Dictionary = result.get("sections", {}) if result.get("sections", {}) is Dictionary else {}
	for index in range(order.size()):
		var section_id := order[index]
		var wrapper: Dictionary = (sections.get(section_id, {}) as Dictionary).duplicate(true)
		var decoded: Dictionary = handshake.call("decode_codec_value", wrapper.get("owner_state"))
		var owner_state: Dictionary = (decoded.get("value", {}) as Dictionary).duplicate(true)
		if section_id == "card_resolution_history":
			owner_state["revision"] = base_value + index
		elif section_id == "session":
			owner_state["fixture_value"] = base_value + index
		else:
			owner_state["value"] = base_value + index
			owner_state["position"] = Vector2(base_value + index, base_value + index + 1)
		var encoded: Dictionary = handshake.call("encode_codec_value", owner_state)
		wrapper["owner_state"] = encoded.get("value")
		sections[section_id] = wrapper
	result["sections"] = sections
	return result


func _owner_values_match(harness: Node, order: Array[String], base_value: int) -> bool:
	for index in range(order.size()):
		var owner := harness.get_node_or_null(_owner_node_name(order[index]))
		if owner == null or owner.current_value() != base_value + index:
			return false
	return true


func _owner_states(harness: Node, order: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for section_id in order:
		var owner := harness.get_node_or_null(_owner_node_name(section_id))
		result[section_id] = owner.to_save_data() if owner != null else {}
	return result


func _owner_apply_counts(harness: Node, order: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for section_id in order:
		var owner := harness.get_node_or_null(_owner_node_name(section_id))
		result[section_id] = int(owner.apply_count) if owner != null else -1
	return result


func _owner_node_name(section_id: String) -> String:
	return "Owner_%s" % section_id


func _public_receipt_safe(value: Variant) -> bool:
	var encoded := JSON.stringify(value)
	for sentinel in PRIVATE_SENTINELS:
		if encoded.contains(sentinel):
			return false
	return not _contains_forbidden_key(value)


func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if FORBIDDEN_PUBLIC_KEYS.has(str(key_variant).to_lower()) or _contains_forbidden_key((value as Dictionary).get(key_variant)):
				return true
	elif value is Array:
		for child_variant in value as Array:
			if _contains_forbidden_key(child_variant):
				return true
	return false


func _same_data(left: Variant, right: Variant) -> bool:
	return JSON.stringify(left) == JSON.stringify(right)


func _check(passed: bool, label: String) -> void:
	_checks += 1
	if not passed:
		_failures.append(label)


func _finish(production_snapshot: Dictionary, evidence: Dictionary) -> Dictionary:
	return {
		"passed": _failures.is_empty(),
		"checks": _checks,
		"failure_count": _failures.size(),
		"failures": _failures.duplicate(),
		"production_snapshot": production_snapshot.duplicate(true),
		"evidence": evidence.duplicate(true),
	}
