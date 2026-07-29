extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	var lifecycle := main.get_node_or_null("RuntimeServices/MenuLifecycleApplicationFlowController")
	if lifecycle != null:
		lifecycle.set("open_root_on_ready", false)
	root.add_child(main)
	await process_frame
	await process_frame
	var services := main.get_node_or_null("RuntimeServices")
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var session := coordinator.get_node_or_null("GameSessionRuntimeController")
	var draft := services.get_node_or_null("NewGameSetupDraftService") as NewGameSetupDraftService
	var transaction := services.get_node_or_null("SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator
	var started := false
	if draft != null and transaction != null and session != null:
		draft.reset_to_defaults()
		var request := SessionStartRequest.create(
			"alpha04c-production-registry-session",
			draft.draft_snapshot(),
			session.session_start_revision(),
			"focused_test"
		)
		var start_receipt := transaction.start_session(request)
		started = start_receipt != null and start_receipt.applied
	_expect(started, "production transaction test starts a real default session")
	var registry := session.get_node_or_null("V06SaveOwnerRegistry") if session != null else null
	var handshake := session.get_node_or_null("GameSaveRuntimeCoordinator/RulesetSaveHandshakeService") if session != null else null
	_expect(registry != null and handshake != null, "production registry and handshake are composed")
	if registry == null or handshake == null:
		_finish()
		return

	var snapshot: Dictionary = registry.registry_snapshot()
	_expect(bool(snapshot.get("valid", false)), "production registry contract is valid")
	_expect(int(snapshot.get("required_section_count", 0)) == 19, "production manifest keeps all 19 semantic sections")
	_expect(int(snapshot.get("transactional_section_count", 0)) == 19 and int(snapshot.get("unsupported_section_count", -1)) == 0, "all 19 sections have transactional owners")
	_expect(bool(snapshot.get("resume_ready", false)) and bool(snapshot.get("restore_barrier_ready", false)), "production registry and global restore barrier are resume-ready")

	var capture: Dictionary = registry.capture_resume_envelope({
		"envelope_id": "alpha04c-production-registry-base",
		"write_id": "alpha04c-production-registry-base-write",
	})
	var envelope: Dictionary = capture.get("envelope", {}) if capture.get("envelope") is Dictionary else {}
	_expect(bool(capture.get("ok", false)) and not envelope.is_empty(), "production composition captures a complete envelope")
	var preflight: Dictionary = registry.preflight_envelope(envelope)
	var preflight_debug: Dictionary = registry.debug_snapshot()
	var organization := coordinator.get_node_or_null("PlayerOrganizationRuntimeController")
	var organization_save: Dictionary = organization.to_save_data() if organization != null else {}
	print("ALPHA04C_ORGANIZATION_CAPTURE|actors=%d|players=%d|configured=%s|secret=%s" % [
		(organization_save.get("actor_ids", []) as Array).size(),
		(organization_save.get("players", {}) as Dictionary).size(),
		bool(organization_save.get("configured", false)),
		not str(organization_save.get("capability_secret", "")).is_empty(),
	])
	print("ALPHA04C_PRODUCTION_PREFLIGHT|ok=%s|reason=%s|count=%d|cross=%d|section=%s|internal=%s" % [
		bool(preflight.get("ok", false)),
		str(preflight.get("reason_code", "")),
		int(preflight.get("preflight_count", 0)),
		int(preflight.get("cross_section_check_count", 0)),
		str(preflight_debug.get("last_internal_preflight_failure_section", "")),
		str(preflight_debug.get("last_internal_preflight_failure_reason", "")),
	])
	_expect(bool(preflight.get("ok", false)) and bool(preflight.get("preflight_complete", false)) and int(preflight.get("preflight_count", 0)) == 19, "all-owner pure preflight accepts the production envelope")
	var baseline_sections := _canonical_sections(handshake, envelope)
	_expect(not baseline_sections.is_empty(), "baseline section fingerprint is available without exposing payloads")

	var fault_passes := 0
	var reverse_order_passes := 0
	for section_variant in registry.fixed_section_order():
		var section_id := str(section_variant)
		var armed := bool(registry.arm_test_apply_failure_once(section_id))
		var failure: Dictionary = registry.apply_envelope(envelope)
		var recapture: Dictionary = registry.capture_resume_envelope({
			"envelope_id": "alpha04c-fault-%s" % section_id,
			"write_id": "alpha04c-fault-%s-write" % section_id,
		})
		var after_envelope: Dictionary = recapture.get("envelope", {}) if recapture.get("envelope") is Dictionary else {}
		var exact := bool(recapture.get("ok", false)) and _canonical_sections(handshake, after_envelope) == baseline_sections
		if armed and not bool(failure.get("ok", true)) \
				and bool(failure.get("rollback_attempted", false)) \
				and bool(failure.get("rollback_complete", false)) \
				and int(failure.get("partial_restore_state_count", -1)) == 0 \
				and exact:
			fault_passes += 1
		var rollback_debug: Dictionary = registry.debug_snapshot()
		if rollback_debug.get("last_internal_rollback_order", []) == _expected_reverse_rollback_order(registry, section_id):
			reverse_order_passes += 1
	_expect(fault_passes == 19, "every production owner apply-fault rolls back to the exact pre-restore state")
	_expect(reverse_order_passes == 19, "every production fault rolls touched owners back in exact reverse DAG order")

	var success: Dictionary = registry.apply_envelope(envelope)
	var success_debug: Dictionary = registry.debug_snapshot()
	print("ALPHA04C_PRODUCTION_APPLY|ok=%s|reason=%s|apply=%d|registry=%d|phase=%d|preflight_section=%s|preflight_reason=%s" % [
		bool(success.get("ok", false)),
		str(success.get("reason_code", "")),
		int(success.get("apply_count", 0)),
		int(success.get("registry_apply_count", 0)),
		int(success_debug.get("last_restore_phase", 0)),
		str(success_debug.get("last_internal_preflight_failure_section", "")),
		str(success_debug.get("last_internal_preflight_failure_reason", "")),
	])
	_expect(bool(success.get("ok", false)) and int(success.get("registry_apply_count", 0)) == 1 and int(success.get("apply_count", 0)) == 19, "one registry load applies exactly 19 owners")
	_expect(int(success.get("restore_phase_count", 0)) == 10 and int(success.get("post_restore_rebind_count", 0)) == 1, "staged restore commits one barrier and one post-restore rebind")
	var debug: Dictionary = registry.debug_snapshot()
	_expect(int(debug.get("partial_restore_state_count", -1)) == 0 and bool(debug.get("global_preflight_before_apply", false)) and bool(debug.get("all_checkpoints_before_mutation", false)) and bool(debug.get("reverse_order_rollback", false)), "global preflight/checkpoint/reverse-rollback invariants remain true")

	main.queue_free()
	await process_frame
	_finish()


func _canonical_sections(handshake: Node, envelope: Dictionary) -> String:
	if handshake == null or not handshake.has_method("canonical_json") or not (envelope.get("sections") is Dictionary):
		return ""
	return str(handshake.call("canonical_json", envelope.get("sections")))


func _expected_reverse_rollback_order(registry: Node, failing_section_id: String) -> Array[String]:
	var touched: Array[String] = []
	for node_variant in registry.restore_dag_node_order():
		var node_id := str(node_variant)
		var section_id := "session" if node_id in ["session_foundation", "session_tail"] else node_id
		if not touched.has(section_id):
			touched.append(section_id)
		if section_id == failing_section_id and (failing_section_id != "session" or node_id == "session_tail"):
			break
	touched.reverse()
	return touched


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("ALPHA04C_PRODUCTION_REGISTRY_TRANSACTION_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(0 if _failures.is_empty() else 1)
