extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CODEC := preload("res://scripts/runtime/card_resolution_execution_save_wire_codec_v4.gd")
const SCALAR := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")
const REGISTRY_VALIDATOR := preload("res://scripts/tools/alpha04c_registry_binding_contract_validator_v1.gd")
const EVIDENCE_PATH := "res://reports/handoffs/alpha04c_execution_restore_difference_characterization.json"
const BASELINE_REPOSITORY_HEAD := "d9ceda8196dbc6aa4152c63cd7ec5c9ed0be98ed"
const RUN_SEED := 900626424
const CHALLENGE_DEPTH := 1
const LOCAL_PLAYER_COUNT := 1
const AI_PLAYER_COUNT := 3
const SAFE_PATH_SEGMENTS := [
	"owner_debug", "transition_debug", "world", "rng",
	"rng_draw_invocation_count", "world_clock_advance_count", "public_log_revision",
	"private_feedback_revision", "presentation_revision",
	"last_phase", "last_reason", "last_summary", "plan_count", "advance_count",
	"finalized_count", "rejected_count", "aborted_count", "last_resolution_id",
	"schema_version", "execution_wire_version", "ruleset_id", "transaction_sequence",
	"completed_resolution_ids", "inflight_resolution_ids", "inflight_execution_transactions",
	"pending_settlements", "transition_controller", "execution_wire_fingerprint",
	"transition_state_wire_version", "card_group_cadence_version", "card_group_cadence",
	"card_group_window_phase", "card_resolution_timer", "card_resolution_counter_window_active",
	"card_resolution_counter_timer", "card_resolution_simultaneous_timer",
	"card_resolution_auction_timer", "card_resolution_auction_open",
	"card_resolution_batch_locked", "card_resolution_batch_reference_player",
	"card_group_window_sequence", "last_card_resolution_player_index",
	"card_group_ready_players", "card_transition_command_schema_version",
	"card_transition_command_revision", "card_transition_command_next_order_index",
	"card_transition_applied_lineage", "card_transition_last_applied_revision",
	"card_transition_last_applied_order_index",
]

var _checks := 0
var _failures: Array[String] = []
var _fingerprint_salt := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_fingerprint_salt = Crypto.new().generate_random_bytes(32).hex_encode()
	var main := MAIN_SCENE.instantiate()
	var lifecycle := main.get_node_or_null("RuntimeServices/MenuLifecycleApplicationFlowController")
	if lifecycle != null:
		lifecycle.set("open_root_on_ready", false)
	root.add_child(main)
	await process_frame
	await process_frame
	var context := _runtime_context(main)
	_expect(bool(context.get("ready", false)), "production Execution composition is available")
	if not bool(context.get("ready", false)):
		await _finish(main, {})
		return

	var started := _start_fixed_session(context)
	_expect(bool(started.get("applied", false)), "production-equivalent fixed session starts")
	_expect(int(started.get("challenge_depth", -1)) == CHALLENGE_DEPTH \
			and int(started.get("seed", 0)) == RUN_SEED \
			and int(started.get("local_player_count", -1)) == LOCAL_PLAYER_COUNT \
			and int(started.get("ai_player_count", -1)) == AI_PLAYER_COUNT, "scenario identity matches replay v1")
	if not bool(started.get("applied", false)):
		await _finish(main, {})
		return
	main.process_mode = Node.PROCESS_MODE_DISABLED

	var owner: Node = context.get("owner")
	var registry: Node = context.get("registry")
	var registry_contract: Dictionary = registry.call("registry_binding_contract_v1")
	var registry_report := REGISTRY_VALIDATOR.validate(registry_contract, registry, 19)
	var binding_rows := registry_contract.get("bindings", []) as Array
	var target_binding := binding_rows[13] as Dictionary if binding_rows.size() > 13 and binding_rows[13] is Dictionary else {}
	_expect(bool(registry_report.get("valid", false)) \
			and int(target_binding.get("section_index", -1)) == 13 \
			and int(target_binding.get("state_version", -1)) == 2, "production Registry binds Execution Owner 13 state v2")
	var before_runtime := _observation(context)
	var save_a: Dictionary = owner.call("to_save_data")
	var handshake: Node = context.get("handshake")
	var envelope_encoded: Dictionary = handshake.call("encode_codec_value", save_a)
	var parsed_encoded: Variant = JSON.parse_string(JSON.stringify(envelope_encoded.get("value")))
	var envelope_decoded: Dictionary = handshake.call("decode_codec_value", parsed_encoded)
	var decoded_wire := envelope_decoded.get("value", {}) as Dictionary
	var preflight: Dictionary = owner.call("preflight_save_data", decoded_wire)
	var raw_a_result := CODEC.decode_save_state(save_a)
	var applied: Dictionary = owner.call("apply_save_data", decoded_wire)
	var save_b: Dictionary = owner.call("to_save_data")
	var restored: Dictionary = owner.call("apply_save_data", save_a)
	var save_c: Dictionary = owner.call("to_save_data")
	var after_runtime := _observation(context)
	var raw_c_result := CODEC.decode_save_state(save_c)
	var raw_a := raw_a_result.get("value", {}) as Dictionary
	var raw_c := raw_c_result.get("value", {}) as Dictionary

	_expect(_all_dictionary_keys_are_strings(before_runtime) \
			and _all_dictionary_keys_are_strings(after_runtime) \
			and _all_dictionary_keys_are_strings(save_a) \
			and _all_dictionary_keys_are_strings(save_c), "comparison trees use only explicit string Dictionary keys")
	var runtime_differences: Array[Dictionary] = []
	_collect_differences(before_runtime, after_runtime, "$", runtime_differences)
	var wire_differences: Array[Dictionary] = []
	_collect_differences(save_a, save_c, "$", wire_differences)
	var difference_paths: Array[String] = []
	for record in runtime_differences:
		difference_paths.append(str(record.get("path", "")))

	_expect(bool(preflight.get("accepted", false)) and bool(applied.get("applied", false)) \
			and bool(restored.get("applied", false)), "the same v1 apply sequence succeeds")
	_expect(bool(envelope_encoded.get("ok", false)) and bool(envelope_decoded.get("ok", false)) \
			and decoded_wire == save_a, "v1 envelope JSON roundtrip remains exact")
	_expect(bool(raw_a_result.get("ok", false)) and bool(raw_c_result.get("ok", false)) \
			and raw_a == raw_c, "decoded runtime Save tree remains exact")
	_expect(save_a == save_b and save_b == save_c and wire_differences.is_empty(), "Save A/B/C remain exactly equal")
	_expect(not runtime_differences.is_empty() and before_runtime != after_runtime, "v1 aggregate runtime-observation mismatch is reproduced")
	_expect(not difference_paths.has("$.owner_debug.plan_count") \
			and not difference_paths.has("$.owner_debug.advance_count") \
			and not difference_paths.has("$.owner_debug.finalized_count") \
			and not difference_paths.has("$.owner_debug.rejected_count") \
			and not difference_paths.has("$.owner_debug.aborted_count"), "operation counters are compared and unchanged")

	var evidence := {
		"schema_version": 1,
		"task_id": "ALPHA_0_4_C_CARD_RESOLUTION_EXECUTION_REPLAY_AUTHORITATIVE_PARITY_REPAIR_REMAINING_OWNER_PREFLIGHT_AND_CONDITIONAL_V8_PROCESS_A",
		"characterization_id": "card_resolution_execution_restore_difference_characterization_v1",
		"status": "GREEN" if _failures.is_empty() else "BLOCKED",
		"repository_head": BASELINE_REPOSITORY_HEAD,
		"production_runtime_ruleset_id": "v0.6",
		"highest_target_ruleset_id": "v0.7.3",
		"scene_path": "res://scenes/main.tscn",
		"challenge_depth": CHALLENGE_DEPTH,
		"run_seed": RUN_SEED,
		"local_player_count": LOCAL_PLAYER_COUNT,
		"ai_player_count": AI_PLAYER_COUNT,
		"replay_authorization_consumed": false,
		"diagnostic_quota_claim_count": 0,
		"registry_owner_index": int(target_binding.get("section_index", -1)),
		"registry_owner_state_version": int(target_binding.get("state_version", -1)),
		"registry_binding_attested": bool(registry_report.get("valid", false)),
		"scenario_identity_fingerprint": _fingerprint({
			"production_runtime_ruleset_id": "v0.6",
			"highest_target_ruleset_id": "v0.7.3",
			"scene_path": "res://scenes/main.tscn",
			"challenge_depth": CHALLENGE_DEPTH,
			"run_seed": RUN_SEED,
			"local_player_count": LOCAL_PLAYER_COUNT,
			"ai_player_count": AI_PLAYER_COUNT,
		}),
		"registry_binding_fingerprint": _fingerprint(registry_contract),
		"envelope_encode_green": bool(envelope_encoded.get("ok", false)),
		"envelope_decode_green": bool(envelope_decoded.get("ok", false)),
		"preflight_accepted": bool(preflight.get("accepted", false)),
		"first_apply_applied": bool(applied.get("applied", false)),
		"second_restore_applied": bool(restored.get("applied", false)),
		"decoded_runtime_a_equals_c": raw_a == raw_c,
		"runtime_observation_a_equals_c": before_runtime == after_runtime,
		"before_save_wire_fingerprint": _fingerprint(save_a),
		"after_recaptured_save_wire_fingerprint": _fingerprint(save_c),
		"save_a_equals_save_b": save_a == save_b,
		"save_a_equals_save_c": save_a == save_c,
		"save_wire_difference_path_count": wire_differences.size(),
		"save_wire_difference_paths": wire_differences,
		"execution_restore_difference_path_count": runtime_differences.size(),
		"execution_restore_difference_paths": runtime_differences,
		"private_payload_redacted": true,
		"raw_runtime_observation_recorded": false,
		"raw_save_wire_recorded": false,
	}
	_write_evidence(evidence)
	await _finish(main, evidence)


func _runtime_context(main: Node) -> Dictionary:
	var services := main.get_node_or_null("RuntimeServices")
	var coordinator := services.get_node_or_null("RuntimeControllerHost/GameRuntimeCoordinator") if services != null else null
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") if coordinator != null else null
	var registry := session.get_node_or_null("V06SaveOwnerRegistry") if session != null else null
	var save := session.get_node_or_null("GameSaveRuntimeCoordinator") if session != null else null
	var handshake := save.get_node_or_null("RulesetSaveHandshakeService") if save != null else null
	var owner := coordinator.get_node_or_null("CardResolutionExecutionRuntimeService") if coordinator != null else null
	var transition := coordinator.get_node_or_null("CardResolutionRuntimeController") if coordinator != null else null
	return {
		"ready": services != null and coordinator != null and session != null and registry != null \
				and save != null and handshake != null and owner != null and transition != null,
		"services": services,
		"coordinator": coordinator,
		"session": session,
		"registry": registry,
		"handshake": handshake,
		"owner": owner,
		"transition": transition,
	}


func _start_fixed_session(context: Dictionary) -> Dictionary:
	var services: Node = context.get("services")
	var coordinator: GameRuntimeCoordinator = context.get("coordinator")
	var session: GameSessionRuntimeController = context.get("session")
	var draft := services.get_node_or_null("NewGameSetupDraftService") as NewGameSetupDraftService
	var transaction := services.get_node_or_null("SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator
	var rng := coordinator.run_rng_service() if coordinator != null else null
	if draft == null or transaction == null or session == null or rng == null:
		return {"applied": false, "reason_code": "characterization_session_dependency_missing"}
	draft.reset_to_defaults()
	rng.set_seed(RUN_SEED)
	var setup := draft.draft_snapshot()
	var request := SessionStartRequest.create(
		"alpha04c-execution-restore-difference-characterization",
		setup,
		session.session_start_revision(),
		"focused_test"
	)
	var receipt := transaction.start_session(request)
	var organization := coordinator.get_node_or_null("PlayerOrganizationRuntimeController")
	var organization_debug: Dictionary = organization.debug_snapshot() if organization != null else {}
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var ai_debug: Dictionary = ai.debug_snapshot() if ai != null else {}
	var player_count := int(organization_debug.get("actor_count", 0))
	var ai_count := int(ai_debug.get("ai_player_count", 0))
	return {
		"applied": receipt != null and receipt.applied,
		"reason_code": receipt.reason_code if receipt != null else "characterization_session_receipt_missing",
		"challenge_depth": int(setup.get("challenge_depth", -1)),
		"seed": int(rng.seed),
		"local_player_count": player_count - ai_count,
		"ai_player_count": ai_count,
	}


func _observation(context: Dictionary) -> Dictionary:
	var coordinator: GameRuntimeCoordinator = context.get("coordinator")
	var owner: Node = context.get("owner")
	var transition: Node = context.get("transition")
	var safety := coordinator.save_restore_safety_observation()
	return {
		"owner_debug": owner.call("debug_snapshot"),
		"transition_debug": transition.call("debug_snapshot"),
		"world": coordinator.world_session_state().to_save_data(),
		"rng": coordinator.run_rng_service().to_save_data(),
		"rng_draw_invocation_count": int(safety.get("rng_draw_invocation_count", 0)),
		"world_clock_advance_count": int(safety.get("world_clock_advance_count", 0)),
		"public_log_revision": int(safety.get("public_log_revision", 0)),
		"private_feedback_revision": int(safety.get("private_feedback_revision", 0)),
		"presentation_revision": int(safety.get("presentation_revision", 0)),
	}


func _collect_differences(before: Variant, after: Variant, path: String, output: Array[Dictionary]) -> void:
	if typeof(before) != typeof(after):
		output.append(_difference(path, before, after))
		return
	if before is Dictionary:
		var before_dictionary := before as Dictionary
		var after_dictionary := after as Dictionary
		var keys_by_signature: Dictionary = {}
		for key_variant: Variant in before_dictionary.keys():
			keys_by_signature[_typed_key_signature(key_variant)] = key_variant
		for key_variant: Variant in after_dictionary.keys():
			keys_by_signature[_typed_key_signature(key_variant)] = key_variant
		var signatures: Array[String] = []
		for signature_variant: Variant in keys_by_signature.keys():
			signatures.append(str(signature_variant))
		signatures.sort()
		for signature in signatures:
			var key_variant: Variant = keys_by_signature.get(signature)
			var child_path := "%s.%s" % [path, _safe_path_segment(key_variant)]
			if not before_dictionary.has(key_variant):
				_collect_one_sided(after_dictionary.get(key_variant), child_path, true, output)
			elif not after_dictionary.has(key_variant):
				_collect_one_sided(before_dictionary.get(key_variant), child_path, false, output)
			else:
				_collect_differences(before_dictionary.get(key_variant), after_dictionary.get(key_variant), child_path, output)
		return
	if before is Array:
		var before_array := before as Array
		var after_array := after as Array
		var maximum := maxi(before_array.size(), after_array.size())
		for index in range(maximum):
			var child_path := "%s[%d]" % [path, index]
			if index >= before_array.size():
				_collect_one_sided(after_array[index], child_path, true, output)
			elif index >= after_array.size():
				_collect_one_sided(before_array[index], child_path, false, output)
			else:
				_collect_differences(before_array[index], after_array[index], child_path, output)
		return
	if before is float:
		if SCALAR.f64_bits_hex(float(before)) != SCALAR.f64_bits_hex(float(after)):
			output.append(_difference(path, before, after))
		return
	if before != after:
		output.append(_difference(path, before, after))


func _collect_one_sided(value: Variant, path: String, before_missing: bool, output: Array[Dictionary]) -> void:
	if value is Dictionary:
		var keys: Array = (value as Dictionary).keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return _typed_key_signature(left) < _typed_key_signature(right))
		if keys.is_empty():
			output.append(_difference(path, _missing() if before_missing else value, value if before_missing else _missing()))
			return
		for key_variant: Variant in keys:
			_collect_one_sided((value as Dictionary).get(key_variant), "%s.%s" % [path, _safe_path_segment(key_variant)], before_missing, output)
		return
	if value is Array:
		if (value as Array).is_empty():
			output.append(_difference(path, _missing() if before_missing else value, value if before_missing else _missing()))
			return
		for index in range((value as Array).size()):
			_collect_one_sided((value as Array)[index], "%s[%d]" % [path, index], before_missing, output)
		return
	output.append(_difference(path, _missing() if before_missing else value, value if before_missing else _missing()))


func _difference(path: String, before: Variant, after: Variant) -> Dictionary:
	return {
		"path": path,
		"before_kind": _kind(before),
		"after_kind": _kind(after),
		"before_fingerprint": _fingerprint(before),
		"after_fingerprint": _fingerprint(after),
	}


func _missing() -> Dictionary:
	return {"$characterization_missing_value": true}


func _kind(value: Variant) -> String:
	if value is Dictionary and bool((value as Dictionary).get("$characterization_missing_value", false)):
		return "missing"
	return type_string(typeof(value))


func _fingerprint(value: Variant) -> String:
	if _kind(value) == "missing":
		return "missing"
	return ("%s|%s|%s" % [_fingerprint_salt, _kind(value), JSON.stringify(value)]).sha256_text().to_lower()


func _all_dictionary_keys_are_strings(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant: Variant in (value as Dictionary).keys():
			if not (key_variant is String) or not _all_dictionary_keys_are_strings((value as Dictionary).get(key_variant)):
				return false
		return true
	if value is Array:
		for child: Variant in value as Array:
			if not _all_dictionary_keys_are_strings(child):
				return false
	return true


func _typed_key_signature(value: Variant) -> String:
	return "%s:%s" % [type_string(typeof(value)), ("%s|%s" % [_fingerprint_salt, JSON.stringify(value)]).sha256_text()]


func _safe_path_segment(value: Variant) -> String:
	if value is String and SAFE_PATH_SEGMENTS.has(str(value)):
		return str(value)
	return "<redacted:%s:%s>" % [type_string(typeof(value)), _typed_key_signature(value).sha256_text().left(12)]


func _write_evidence(evidence: Dictionary) -> void:
	var absolute_path := ProjectSettings.globalize_path(EVIDENCE_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		_failures.append("characterization evidence file is writable")
		return
	file.store_string(JSON.stringify(evidence, "  ", true, true) + "\n")
	file.flush()
	file.close()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish(main: Node, evidence: Dictionary) -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
	await process_frame
	print("CARD_RESOLUTION_EXECUTION_RESTORE_DIFFERENCE_CHARACTERIZATION_TEST|status=%s|checks=%d|failures=%d|differences=%d|wire_differences=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		int(evidence.get("execution_restore_difference_path_count", -1)),
		int(evidence.get("save_wire_difference_path_count", -1)),
	])
	if not _failures.is_empty():
		push_error("Execution restore characterization failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
