extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CODEC := preload("res://scripts/runtime/ai_runtime_save_wire_codec_v3.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const TERMINAL_EVIDENCE := preload("res://scripts/tools/cold_restore_terminal_evidence.gd")
const AUTHORITATIVE_STEPPER := preload("res://scripts/tools/full_run_authoritative_runtime_stepper.gd")

const FIXED_SEED := 900626424
const MAX_TICKS := 120

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
	var context := _context(main)
	_expect(bool(context.get("ready", false)), "production_runtime_context_ready")
	if not bool(context.get("ready", false)):
		await _finish(main)
		return
	var started := _start_session(context)
	_expect(bool(started.get("applied", false)), "production_v0_6_session_started")
	if not bool(started.get("applied", false)):
		await _finish(main)
		return
	var before := int(_safety(context).get("ai_action_submission_count", 0))
	var lease := TERMINAL_EVIDENCE.acquire_manual_lease(context)
	_expect(bool(lease.get("accepted", false)), "manual_runtime_lease_acquired")
	if bool(lease.get("accepted", false)):
		for _tick_index in range(MAX_TICKS):
			var step := AUTHORITATIVE_STEPPER.advance_bounded(
				context.get("runtime_loop") as RuntimeLoop,
				0.5,
				1
			)
			if not bool(step.get("accepted", false)):
				_failures.append("authoritative_runtime_step_rejected")
				break
			if int(_safety(context).get("ai_action_submission_count", 0)) > before:
				break
		var release := TERMINAL_EVIDENCE.release_manual_lease(context)
		_expect(bool(release.get("released", false)), "manual_runtime_lease_released")
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var action_delta := maxi(0, int(_safety(context).get("ai_action_submission_count", 0)) - before)
	var owner := context.get("owner") as AiRuntimeController
	var save := owner.to_save_data()
	var checkpoint := owner.capture_runtime_checkpoint()
	var decoded := CODEC.decode_save_state(save)
	var raw: Dictionary = decoded.get("value", {}) \
			if decoded.get("value", {}) is Dictionary else {}
	var memory_nondefault := false
	var legal_card_action_count := action_delta
	var categories := _action_category_counts(raw)
	var normal_purchase_count := int(categories.get("normal_purchase_count", 0))
	var business_action_count := int(categories.get("business_action_count", 0))
	for row_variant in raw.get("player_states", []) as Array:
		var memory := ((row_variant as Dictionary).get("ai_memory", {}) as Dictionary)
		if not (memory.get("decision_samples", []) as Array).is_empty() \
				or not (memory.get("action_counts", {}) as Dictionary).is_empty() \
				or not str(memory.get("economic_focus_product", "")).is_empty() \
				or not str(memory.get("strategic_intent", "")).is_empty() \
				or not str(memory.get("route_plan_stage", "")).is_empty():
			memory_nondefault = true
			break
	_expect(action_delta >= 1, "runtime_loop_submitted_at_least_one_ai_action")
	_expect(bool(decoded.get("ok", false)) and WIRE.is_closed_data(save), "runtime_loop_state_captures_closed_save_v3")
	_expect(WIRE.is_closed_data(checkpoint) and bool(CODEC.decode_runtime_checkpoint(checkpoint).get("ok", false)), "runtime_loop_state_captures_closed_checkpoint_v2")
	_expect(int(raw.get("request_sequence", 0)) > 0, "runtime_loop_advances_request_sequence")
	_expect((raw.get("player_states", []) as Array).size() == 3, "runtime_loop_preserves_three_ai_players")
	_expect(memory_nondefault, "runtime_loop_forms_nondefault_ai_memory")
	_expect(legal_card_action_count >= 1, "runtime_loop_forms_legal_card_action_state")
	var save_json: Variant = JSON.parse_string(JSON.stringify(save))
	var checkpoint_json: Variant = JSON.parse_string(JSON.stringify(checkpoint))
	var preflight := owner.preflight_save_data(save_json as Dictionary if save_json is Dictionary else {})
	var applied := owner.apply_save_data(save_json as Dictionary if save_json is Dictionary else {})
	var checkpoint_restored := owner.restore_runtime_checkpoint(
		checkpoint_json as Dictionary if checkpoint_json is Dictionary else {}
	)
	_expect(bool(preflight.get("accepted", false)) and bool(applied.get("applied", false)) \
			and owner.to_save_data() == save, "runtime_loop_save_v3_roundtrip_parity")
	_expect(bool(checkpoint_restored.get("restored", false)) \
			and owner.capture_runtime_checkpoint() == checkpoint, "runtime_loop_checkpoint_v2_roundtrip_parity")
	var action_before_zero_tick := int(_safety(context).get("ai_action_submission_count", 0))
	(context.get("coordinator") as GameRuntimeCoordinator).tick_ai(0.0)
	_expect(int(_safety(context).get("ai_action_submission_count", 0)) == action_before_zero_tick \
			and owner.to_save_data() == save, "zero_delta_post_restore_tick_submits_no_extra_action")
	print("AI_RUNTIME_LEGAL_RUNTIME_CHARACTERIZATION_TEST|status=%s|checks=%d|failures=%d|action_count=%d|legal_card_action_count=%d|normal_purchase_count=%d|business_action_count=%d|request_sequence_positive=%s|memory_nondefault=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		action_delta,
		legal_card_action_count,
		normal_purchase_count,
		business_action_count,
		str(int(raw.get("request_sequence", 0)) > 0),
		str(memory_nondefault),
	])
	await _finish(main)


func _context(main: Node) -> Dictionary:
	var services := main.get_node_or_null("RuntimeServices")
	var coordinator := services.get_node_or_null("RuntimeControllerHost/GameRuntimeCoordinator") \
			if services != null else null
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") \
			if coordinator != null else null
	var owner := coordinator.get_node_or_null("AiRuntimeController") if coordinator != null else null
	var runtime_loop := coordinator.get_node_or_null("RuntimeLoop") if coordinator != null else null
	var barrier := coordinator.get_node_or_null("SaveRestoreRuntimeBarrier") if coordinator != null else null
	return {
		"ready": services != null and coordinator is GameRuntimeCoordinator \
				and session is GameSessionRuntimeController \
				and owner is AiRuntimeController and runtime_loop is RuntimeLoop \
				and barrier is SaveRestoreRuntimeBarrier,
		"main": main,
		"services": services,
		"coordinator": coordinator,
		"session": session,
		"owner": owner,
		"runtime_loop": runtime_loop,
		"barrier": barrier,
	}


func _start_session(context: Dictionary) -> Dictionary:
	var services: Node = context.get("services")
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var session := context.get("session") as GameSessionRuntimeController
	var draft := services.get_node_or_null("NewGameSetupDraftService") as NewGameSetupDraftService
	var transaction := services.get_node_or_null("SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator
	var rng := coordinator.run_rng_service()
	if draft == null or transaction == null or rng == null:
		return {"applied": false}
	draft.reset_to_defaults()
	rng.set_seed(FIXED_SEED)
	var setup := draft.draft_snapshot()
	if int(setup.get("challenge_depth", -1)) != 1 \
			or int(setup.get("player_count", -1)) != 4 \
			or int(setup.get("ai_player_count", -1)) != 3:
		return {"applied": false}
	var request := SessionStartRequest.create(
		"alpha04c-ai-runtime-legal-characterization",
		setup,
		session.session_start_revision(),
		"quality_driver"
	)
	var receipt := transaction.start_session(request)
	return {"applied": receipt != null and receipt.applied}


func _safety(context: Dictionary) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	return coordinator.save_restore_safety_observation() if coordinator != null else {}


func _action_category_counts(raw: Dictionary) -> Dictionary:
	var result := {
		"legal_card_action_count": 0,
		"normal_purchase_count": 0,
		"business_action_count": 0,
	}
	for row_variant in raw.get("player_states", []) as Array:
		if not (row_variant is Dictionary):
			continue
		var memory := ((row_variant as Dictionary).get("ai_memory", {}) as Dictionary)
		var action_counts := memory.get("action_counts", {}) as Dictionary
		result["legal_card_action_count"] = int(result.get("legal_card_action_count", 0)) \
				+ int(action_counts.get("匿名出牌", 0)) + int(action_counts.get("相位反制", 0))
		result["normal_purchase_count"] = int(result.get("normal_purchase_count", 0)) \
				+ int(action_counts.get("区域购牌", 0))
		result["business_action_count"] = int(result.get("business_action_count", 0)) \
				+ int(action_counts.get("匿名商业", 0))
	return result


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish(main: Node) -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
		await process_frame
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
