extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const INSPECTOR := preload("res://scripts/tools/card_inventory_checkpoint_purity_inspector_v1.gd")
const SCENARIO_IDENTITY := preload("res://scripts/tools/diagnostic_scenario_identity_v1.gd")
const REGISTRY_VALIDATOR := preload("res://scripts/tools/alpha04c_registry_binding_contract_validator_v1.gd")

const REPLAY_RUN_ID := "alpha04c-v7-card-inventory-save-v4-checkpoint-v2-replay"
const FIXED_SEED := 900626424
const FIXED_CHALLENGE_DEPTH := 1
const FIXED_LOCAL_PLAYER_COUNT := 1
const FIXED_AI_PLAYER_COUNT := 3
const TARGET_OWNER_INDEX := 7
const TARGET_SECTION_ID := "card_inventory"
const TARGET_OWNER_ID := "card_inventory"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_path := _argument_value("--evidence-output=")
	var repository_head := _argument_value("--repository-head=").to_lower()
	var result := _base_result(repository_head)
	if output_path.is_empty() or output_path.contains("current_run.save"):
		_finish(result, output_path, "replay_evidence_path_invalid")
		return
	if not _lower_hex(repository_head, 40, 64):
		_finish(result, output_path, "replay_repository_head_invalid")
		return

	var main := MAIN_SCENE.instantiate()
	var lifecycle := main.get_node_or_null("RuntimeServices/MenuLifecycleApplicationFlowController")
	if lifecycle != null:
		lifecycle.set("open_root_on_ready", false)
	root.add_child(main)
	await process_frame
	await process_frame
	var context := _runtime_context(main)
	if not bool(context.get("ready", false)):
		main.queue_free()
		await process_frame
		_finish(result, output_path, "production_composition_unavailable")
		return

	var started := _start_fixed_session(context)
	result["challenge_depth"] = int(started.get("challenge_depth", -1))
	result["seed"] = int(started.get("seed", 0))
	result["local_player_count"] = int(started.get("local_player_count", -1))
	result["ai_player_count"] = int(started.get("ai_player_count", -1))
	if not bool(started.get("applied", false)):
		main.queue_free()
		await process_frame
		_finish(result, output_path, str(started.get("reason_code", "session_start_failed")))
		return
	main.process_mode = Node.PROCESS_MODE_DISABLED

	var identity := _build_scenario_identity(context, started, repository_head)
	var identity_report := SCENARIO_IDENTITY.validation_report(
		identity,
		REPLAY_RUN_ID,
		repository_head,
		str(started.get("scenario_fingerprint", ""))
	)
	result["scenario_identity_attested"] = bool(identity_report.get("valid", false))
	result["scenario_identity_fingerprint"] = str(identity.get("identity_fingerprint", ""))
	if not bool(identity_report.get("valid", false)):
		main.queue_free()
		await process_frame
		_finish(result, output_path, str(identity_report.get("reason_code", "scenario_identity_invalid")))
		return

	var registry: Node = context.get("registry")
	var owner: Node = context.get("owner")
	var contract: Dictionary = registry.call("registry_binding_contract_v1")
	var registry_report := REGISTRY_VALIDATOR.validate(contract, registry, 19)
	var target_binding := _target_binding(contract)
	var bound_owner := registry.get_node_or_null(NodePath(str(target_binding.get("owner_path", "")))) \
			if not target_binding.is_empty() else null
	var binding_attested := bool(registry_report.get("valid", false)) \
			and int(target_binding.get("section_index", -1)) == TARGET_OWNER_INDEX \
			and str(target_binding.get("section_id", "")) == TARGET_SECTION_ID \
			and str(target_binding.get("owner_id", "")) == TARGET_OWNER_ID \
			and int(target_binding.get("state_version", 0)) == 4 \
			and str(target_binding.get("capture_method", "")) == "to_save_data" \
			and str(target_binding.get("checkpoint_method", "")) == "capture_runtime_checkpoint" \
			and bound_owner == owner
	result["registry_binding_attested"] = binding_attested
	result["registry_binding_count"] = int(registry_report.get("binding_count", 0))
	result["target_owner_index"] = TARGET_OWNER_INDEX
	result["target_section_id"] = TARGET_SECTION_ID
	result["target_owner_id"] = TARGET_OWNER_ID
	if not binding_attested:
		main.queue_free()
		await process_frame
		_finish(result, output_path, str(registry_report.get("reason_code", "card_inventory_binding_invalid")))
		return

	var before_save := _observation(context)
	var save_a: Dictionary = owner.call("to_save_data")
	var after_save := _observation(context)
	var save_report := INSPECTOR.inspect(save_a, {
		"commodity_card_inventory": "to_save_data",
		"product_market": "to_save_data",
		"district_purchase": "to_save_data",
	})
	var handshake: Node = context.get("handshake")
	var encoded_save: Dictionary = handshake.call("encode_codec_value", save_a)
	var parsed_encoded: Variant = JSON.parse_string(JSON.stringify(encoded_save.get("value")))
	var decoded_save: Dictionary = handshake.call("decode_codec_value", parsed_encoded)
	var decoded_state: Dictionary = decoded_save.get("value", {}) \
			if decoded_save.get("value") is Dictionary else {}
	var save_preflight: Dictionary = owner.call("preflight_save_data", decoded_state)

	var before_checkpoint := _observation(context)
	var checkpoint_a: Dictionary = owner.call("capture_runtime_checkpoint")
	var after_checkpoint := _observation(context)
	var checkpoint_report := INSPECTOR.inspect(checkpoint_a, {
		"commodity_card_inventory": "capture_runtime_checkpoint",
		"product_market": "capture_runtime_checkpoint",
		"district_purchase": "capture_runtime_checkpoint",
	})

	var before_roundtrip := _observation(context)
	var applied: Dictionary = owner.call("apply_save_data", decoded_state)
	var save_b: Dictionary = owner.call("to_save_data")
	var restored: Dictionary = owner.call("restore_runtime_checkpoint", checkpoint_a)
	var checkpoint_b: Dictionary = owner.call("capture_runtime_checkpoint")
	var save_c: Dictionary = owner.call("to_save_data")
	var after_roundtrip := _observation(context)

	var save_capture_mutation_count := 0 if before_save == after_save else 1
	var checkpoint_capture_mutation_count := 0 if before_checkpoint == after_checkpoint else 1
	var save_closed := int(save_a.get("schema_version", 0)) == 4 \
			and WIRE.is_closed_data(save_a) \
			and int(save_report.get("strict_non_closed_leaf_count", -1)) == 0
	var checkpoint_closed := int(checkpoint_a.get("schema_version", 0)) == 2 \
			and WIRE.is_closed_data(checkpoint_a) \
			and int(checkpoint_report.get("strict_non_closed_leaf_count", -1)) == 0
	var save_roundtrip := bool(encoded_save.get("ok", false)) \
			and bool(decoded_save.get("ok", false)) \
			and bool(save_preflight.get("accepted", false)) \
			and bool(applied.get("applied", false)) \
			and save_a == decoded_state and save_b == save_a
	var checkpoint_roundtrip := bool(restored.get("restored", restored.get("applied", false))) \
			and checkpoint_b == checkpoint_a and save_c == save_a
	var restore_quiet := before_roundtrip == after_roundtrip

	result.merge({
		"persistent_save_leaf_count": int(save_report.get("checkpoint_leaf_count", 0)),
		"persistent_save_non_closed_leaf_count_after": int(save_report.get("strict_non_closed_leaf_count", -1)),
		"runtime_checkpoint_leaf_count": int(checkpoint_report.get("checkpoint_leaf_count", 0)),
		"runtime_checkpoint_non_closed_leaf_count_after": int(checkpoint_report.get("strict_non_closed_leaf_count", -1)),
		"card_inventory_save_schema_version": int(save_a.get("schema_version", 0)),
		"card_inventory_checkpoint_schema_version": int(checkpoint_a.get("schema_version", 0)),
		"save_payload_closed": save_closed,
		"checkpoint_payload_closed": checkpoint_closed,
		"save_capture_mutation_count": save_capture_mutation_count,
		"checkpoint_capture_mutation_count": checkpoint_capture_mutation_count,
		"capture_rng_draw_delta": _capture_delta(before_save, after_save, before_checkpoint, after_checkpoint, "rng_draw_invocation_count"),
		"capture_world_time_delta": _capture_delta(before_save, after_save, before_checkpoint, after_checkpoint, "world_clock_advance_count"),
		"capture_public_log_delta": _capture_delta(before_save, after_save, before_checkpoint, after_checkpoint, "public_log_revision"),
		"capture_private_feedback_delta": _capture_delta(before_save, after_save, before_checkpoint, after_checkpoint, "private_feedback_revision"),
		"capture_presentation_revision_delta": _capture_delta(before_save, after_save, before_checkpoint, after_checkpoint, "presentation_revision"),
		"save_v4_roundtrip_green": save_roundtrip,
		"checkpoint_v2_roundtrip_green": checkpoint_roundtrip,
		"restore_parity": checkpoint_roundtrip and restore_quiet,
		"product_market_growth_bits_parity": save_roundtrip and _growth_tags(save_b) == _growth_tags(save_a),
		"product_market_timer_bits_parity": save_roundtrip and _product_tag(save_b, "market_timer") == _product_tag(save_a, "market_timer"),
		"district_purchase_window_key_parity": checkpoint_roundtrip and _district_windows(checkpoint_b) == _district_windows(checkpoint_a),
		"allocator_cursor_restore_parity": checkpoint_roundtrip and _district_cursor(save_c) == _district_cursor(save_a),
		"transaction_journal_restore_parity": checkpoint_roundtrip and _commodity_field(save_c, "transaction_journal") == _commodity_field(save_a, "transaction_journal"),
		"terminal_operation_restore_parity": checkpoint_roundtrip and _commodity_field(save_c, "terminal_operations") == _commodity_field(save_a, "terminal_operations"),
		"world_fingerprint_restore_parity": str(before_roundtrip.get("world_fingerprint", "")) == str(after_roundtrip.get("world_fingerprint", "")),
		"owner_fingerprint_restore_parity": str(before_roundtrip.get("owner_fingerprint", "")) == str(after_roundtrip.get("owner_fingerprint", "")),
	}, true)

	var green := bool(result.get("scenario_identity_attested", false)) \
			and bool(result.get("registry_binding_attested", false)) \
			and save_closed and checkpoint_closed \
			and save_capture_mutation_count == 0 and checkpoint_capture_mutation_count == 0 \
			and int(result.get("capture_rng_draw_delta", -1)) == 0 \
			and int(result.get("capture_world_time_delta", -1)) == 0 \
			and int(result.get("capture_public_log_delta", -1)) == 0 \
			and int(result.get("capture_private_feedback_delta", -1)) == 0 \
			and int(result.get("capture_presentation_revision_delta", -1)) == 0 \
			and save_roundtrip and checkpoint_roundtrip and restore_quiet
	result["v7_card_inventory_save_v4_replay_green"] = green
	result["v7_card_inventory_checkpoint_v2_replay_green"] = green
	result["v7_card_inventory_restore_parity"] = checkpoint_roundtrip and restore_quiet
	result["success"] = green
	result["status"] = "GREEN" if green else "BLOCKED"
	result["reason_code"] = "v7_card_inventory_nonconsuming_replay_green" if green else "v7_card_inventory_nonconsuming_replay_failed"

	main.queue_free()
	await process_frame
	_write_result(output_path, result)
	_print_result(result)
	quit(0 if green else 1)


func _runtime_context(main: Node) -> Dictionary:
	var services := main.get_node_or_null("RuntimeServices")
	var coordinator := services.get_node_or_null("RuntimeControllerHost/GameRuntimeCoordinator") if services != null else null
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") if coordinator != null else null
	var registry := session.get_node_or_null("V06SaveOwnerRegistry") if session != null else null
	var save := session.get_node_or_null("GameSaveRuntimeCoordinator") if session != null else null
	var handshake := save.get_node_or_null("RulesetSaveHandshakeService") if save != null else null
	var owner := coordinator.get_node_or_null("CardInventorySaveOwner") if coordinator != null else null
	return {
		"ready": services != null and coordinator != null and session != null \
				and registry != null and save != null and handshake != null and owner != null,
		"main": main,
		"services": services,
		"coordinator": coordinator,
		"session": session,
		"registry": registry,
		"save": save,
		"handshake": handshake,
		"owner": owner,
	}


func _start_fixed_session(context: Dictionary) -> Dictionary:
	var services: Node = context.get("services")
	var coordinator: GameRuntimeCoordinator = context.get("coordinator")
	var session: GameSessionRuntimeController = context.get("session")
	var draft := services.get_node_or_null("NewGameSetupDraftService") as NewGameSetupDraftService
	var transaction := services.get_node_or_null("SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator
	var rng := coordinator.run_rng_service() if coordinator != null else null
	if draft == null or transaction == null or session == null or rng == null:
		return {"applied": false, "reason_code": "session_start_dependency_missing"}
	draft.reset_to_defaults()
	rng.set_seed(FIXED_SEED)
	var setup := draft.draft_snapshot()
	if int(setup.get("challenge_depth", -1)) != FIXED_CHALLENGE_DEPTH \
			or int(setup.get("player_count", -1)) != FIXED_LOCAL_PLAYER_COUNT + FIXED_AI_PLAYER_COUNT \
			or int(setup.get("ai_player_count", -1)) != FIXED_AI_PLAYER_COUNT:
		return {"applied": false, "reason_code": "fixed_setup_mismatch"}
	var request := SessionStartRequest.create(
		REPLAY_RUN_ID,
		setup,
		session.session_start_revision(),
		"quality_driver"
	)
	var receipt := transaction.start_session(request)
	var summary := session.session_summary()
	var organization := coordinator.get_node_or_null("PlayerOrganizationRuntimeController")
	var organization_debug: Dictionary = organization.debug_snapshot() \
			if organization != null and organization.has_method("debug_snapshot") else {}
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var ai_debug: Dictionary = ai.debug_snapshot() if ai != null else {}
	var player_count := int(organization_debug.get("actor_count", 0))
	var ai_count := int(ai_debug.get("ai_player_count", 0))
	var session_seed := int(summary.get("seed", 0))
	return {
		"applied": receipt != null and receipt.applied,
		"reason_code": receipt.reason_code if receipt != null else "session_start_receipt_missing",
		"challenge_depth": int(setup.get("challenge_depth", -1)),
		"seed": int(rng.seed),
		"session_seed": session_seed,
		"session_id": str(summary.get("session_id", "")),
		"session_generation": int(receipt.operation_sequence) if receipt != null else -1,
		"session_plan_fingerprint": str(receipt.plan_fingerprint) if receipt != null else "",
		"local_player_count": player_count - ai_count,
		"ai_player_count": ai_count,
		"scenario_fingerprint": _fingerprint({
			"challenge_depth": int(setup.get("challenge_depth", -1)),
			"run_seed": int(rng.seed),
			"session_seed": str(session_seed),
			"player_count": int(setup.get("player_count", -1)),
			"ai_player_count": int(setup.get("ai_player_count", -1)),
		}),
	}


func _build_scenario_identity(context: Dictionary, started: Dictionary, repository_head: String) -> Dictionary:
	var main: Node = context.get("main")
	var coordinator: GameRuntimeCoordinator = context.get("coordinator")
	var session: Node = context.get("session")
	var registry: Node = context.get("registry")
	var ruleset_owner := session.get_node_or_null("../RulesetSaveAttestationOwner")
	var ruleset_state: Dictionary = ruleset_owner.call("to_save_data") \
			if ruleset_owner != null and ruleset_owner.has_method("to_save_data") else {}
	var world := coordinator.world_session_state() if coordinator != null else null
	var geometry: Dictionary = world.public_world_geometry_snapshot() if world != null else {}
	var lifecycle: Dictionary = world.public_lifecycle_snapshot() if world != null else {}
	var roster: Array = []
	var local_count := 0
	var ai_count := 0
	if world != null:
		for player_index in range(world.players.size()):
			var player: Dictionary = world.players[player_index] if world.players[player_index] is Dictionary else {}
			var is_ai := bool(player.get("is_ai", false))
			ai_count += 1 if is_ai else 0
			local_count += 0 if is_ai else 1
			roster.append({"player_index": player_index, "actor_id": str(player.get("actor_id", "")), "is_ai": is_ai})
	var composition_paths := [
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/V06SaveOwnerRegistry",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardInventorySaveOwner",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CommodityCardInventoryRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductMarketRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/DistrictPurchaseRuntimeController",
	]
	var composition_presence: Array = []
	for path_variant in composition_paths:
		var path := str(path_variant)
		var node := main.get_node_or_null(path)
		composition_presence.append({"path": path, "present": node != null, "class": node.get_class() if node != null else ""})
	var registry_snapshot: Dictionary = registry.call("registry_snapshot")
	var world_revision := int(geometry.get("revision", -1))
	if int(lifecycle.get("session_revision", -2)) != world_revision:
		world_revision = -1
	return SCENARIO_IDENTITY.build({
		"run_id": REPLAY_RUN_ID,
		"repository_head": repository_head,
		"ruleset_id": str(ruleset_state.get("ruleset_id", "")),
		"ruleset_fingerprint": _fingerprint(ruleset_state),
		"challenge_depth": int(started.get("challenge_depth", -1)),
		"run_seed": int(started.get("seed", 0)),
		"session_seed": int(started.get("session_seed", 0)),
		"scenario_fingerprint": str(started.get("scenario_fingerprint", "")),
		"local_player_count": local_count,
		"ai_player_count": ai_count,
		"roster_fingerprint": _fingerprint(roster),
		"session_id": str(started.get("session_id", "")),
		"session_generation": int(started.get("session_generation", -1)),
		"session_plan_fingerprint": str(started.get("session_plan_fingerprint", "")),
		"world_revision": world_revision,
		"runtime_composition_fingerprint": _fingerprint(composition_presence),
		"save_registry_fingerprint": _fingerprint({
			"fixed_section_order": registry_snapshot.get("fixed_capture_order", []),
			"contracts": registry_snapshot.get("contracts", []),
			"transactional_section_count": registry_snapshot.get("transactional_section_count", 0),
		}),
		"user_data_path_fingerprint": OS.get_user_data_dir().sha256_text().to_lower(),
	})


func _target_binding(contract: Dictionary) -> Dictionary:
	var rows: Array = contract.get("bindings", []) if contract.get("bindings") is Array else []
	if TARGET_OWNER_INDEX < 0 or TARGET_OWNER_INDEX >= rows.size() or not (rows[TARGET_OWNER_INDEX] is Dictionary):
		return {}
	return (rows[TARGET_OWNER_INDEX] as Dictionary).duplicate(true)


func _observation(context: Dictionary) -> Dictionary:
	var coordinator: GameRuntimeCoordinator = context.get("coordinator")
	var owner: Node = context.get("owner")
	var world := coordinator.world_session_state()
	var commodity := coordinator.get_node_or_null("CommodityCardInventoryRuntimeController")
	var product := coordinator.get_node_or_null("ProductMarketRuntimeController")
	var district := coordinator.get_node_or_null("DistrictPurchaseRuntimeController")
	var owner_material := {
		"owner": owner.call("debug_snapshot"),
		"commodity": commodity.call("capture_runtime_checkpoint"),
		"product_market": product.call("capture_runtime_checkpoint"),
		"district_purchase": district.call("capture_runtime_checkpoint"),
	}
	var safety := coordinator.save_restore_safety_observation()
	return {
		"world_fingerprint": _fingerprint(world.to_save_data()),
		"owner_fingerprint": _fingerprint(owner_material),
		"rng_draw_invocation_count": int(safety.get("rng_draw_invocation_count", 0)),
		"world_clock_advance_count": int(safety.get("world_clock_advance_count", 0)),
		"public_log_revision": int(safety.get("public_log_revision", 0)),
		"private_feedback_revision": int(safety.get("private_feedback_revision", 0)),
		"presentation_revision": int(safety.get("presentation_revision", 0)),
	}


func _capture_delta(
	before_save: Dictionary,
	after_save: Dictionary,
	before_checkpoint: Dictionary,
	after_checkpoint: Dictionary,
	field: String
) -> int:
	return int(after_save.get(field, 0)) - int(before_save.get(field, 0)) \
			+ int(after_checkpoint.get(field, 0)) - int(before_checkpoint.get(field, 0))


func _product_tag(save: Dictionary, field: String) -> Dictionary:
	var product := save.get("product_market", {}) as Dictionary
	return (product.get(field, {}) as Dictionary).duplicate(true) if product.get(field) is Dictionary else {}


func _growth_tags(save: Dictionary) -> Array:
	var product := save.get("product_market", {}) as Dictionary
	var market := product.get("product_market", {}) as Dictionary
	var product_ids: Array = market.keys()
	product_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	var tags: Array = []
	for product_id_variant in product_ids:
		var entry := market.get(product_id_variant, {}) as Dictionary
		tags.append((entry.get("growth_multiplier", {}) as Dictionary).duplicate(true) if entry.get("growth_multiplier") is Dictionary else {})
	return tags


func _district_windows(checkpoint: Dictionary) -> Dictionary:
	var children := checkpoint.get("children", {}) as Dictionary
	var wrapper := children.get("district_purchase", {}) as Dictionary
	var state := wrapper.get("state", {}) as Dictionary
	return (state.get("windows_by_player", {}) as Dictionary).duplicate(true) if state.get("windows_by_player") is Dictionary else {}


func _district_cursor(save: Dictionary) -> int:
	var district := save.get("district_purchase", {}) as Dictionary
	var state := district.get("district_purchase_runtime", {}) as Dictionary
	return int(state.get("next_quote_sequence", -1))


func _commodity_field(save: Dictionary, field: String) -> Dictionary:
	var commodity := save.get("commodity_card_inventory", {}) as Dictionary
	return (commodity.get(field, {}) as Dictionary).duplicate(true) if commodity.get(field) is Dictionary else {}


func _fingerprint(value: Variant) -> String:
	return JSON.stringify(value, "", true, true).sha256_text().to_lower()


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix).strip_edges()
	return ""


func _base_result(repository_head: String) -> Dictionary:
	return {
		"schema_version": 1,
		"replay_run_id": REPLAY_RUN_ID,
		"repository_head": repository_head,
		"status": "BLOCKED",
		"success": false,
		"reason_code": "not_run",
		"replay_official": false,
		"replay_formal": false,
		"replay_process_a": false,
		"targeted_owner_capture_diagnostic_count_before": 7,
		"targeted_owner_capture_diagnostic_count_after": 7,
		"replay_diagnostic_count_delta": 0,
		"replay_quota_claim_count": 0,
		"replay_full_owner_audit_count": 0,
		"replay_production_fixed_slot_write_count": 0,
		"replay_process_a_count": 0,
		"v7_historical_registry_owner_capture": "7/19",
		"v8_run_id_created": false,
		"private_payload_redacted": true,
	}


func _finish(result: Dictionary, output_path: String, reason_code: String) -> void:
	result["reason_code"] = reason_code
	result["status"] = "BLOCKED"
	result["success"] = false
	if not output_path.is_empty() and not output_path.contains("current_run.save"):
		_write_result(output_path, result)
	_print_result(result)
	quit(1)


func _write_result(path: String, result: Dictionary) -> void:
	var absolute_path := path if path.is_absolute_path() else ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir()) != OK:
		return
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(result, "  ", true, true) + "\n")
	file.flush()
	file.close()


func _print_result(result: Dictionary) -> void:
	print("ALPHA04C_V7_CARD_INVENTORY_NONCONSUMING_REPLAY|%s" % JSON.stringify(result))


func _lower_hex(value: String, minimum: int, maximum: int) -> bool:
	if value.length() < minimum or value.length() > maximum:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true
