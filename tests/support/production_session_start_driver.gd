extends RefCounted
class_name ProductionSessionStartDriver

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const DRAFT_SERVICE_PATH := "RuntimeServices/NewGameSetupDraftService"
const COMMAND_PORT_PATH := "RuntimeServices/SetupDraftCommandPort"
const TRANSACTION_PATH := "RuntimeServices/SessionStartTransactionCoordinator"
const GAME_SESSION_PATH := COORDINATOR_PATH + "/GameSessionRuntimeController"
const SAVE_COORDINATOR_PATH := GAME_SESSION_PATH + "/GameSaveRuntimeCoordinator"


static func start_default_session(
	tree: SceneTree,
	qa_save_path: String,
	request_id: String = "production-session-start-default"
) -> Dictionary:
	return await start_configured_session(tree, {}, qa_save_path, request_id)


static func start_configured_session(
	tree: SceneTree,
	configuration: Dictionary,
	qa_save_path: String,
	request_id: String = "production-session-start-configured"
) -> Dictionary:
	var result := _empty_result("session_start_driver_not_ready")
	if tree == null or qa_save_path.strip_edges().is_empty() or request_id.strip_edges().is_empty():
		result["reason_code"] = "session_start_driver_input_invalid"
		return result
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		result["reason_code"] = "main_scene_unavailable"
		return result
	var main_root := packed.instantiate()
	if main_root == null:
		result["reason_code"] = "main_scene_instance_unavailable"
		return result
	var save_coordinator := main_root.get_node_or_null(SAVE_COORDINATOR_PATH)
	var qa_override_ready := save_coordinator != null \
		and save_coordinator.has_method("set_qa_default_save_path_override") \
		and bool(save_coordinator.call("set_qa_default_save_path_override", qa_save_path))
	if not qa_override_ready:
		main_root.free()
		result["reason_code"] = "qa_save_override_unavailable"
		return result
	tree.root.add_child(main_root)
	await tree.process_frame
	await tree.process_frame

	var coordinator := main_root.get_node_or_null(COORDINATOR_PATH) as GameRuntimeCoordinator
	var world_session := coordinator.world_session_state() if coordinator != null else null
	var game_session := main_root.get_node_or_null(GAME_SESSION_PATH) as GameSessionRuntimeController
	var draft_service := main_root.get_node_or_null(DRAFT_SERVICE_PATH) as NewGameSetupDraftService
	var command_port := main_root.get_node_or_null(COMMAND_PORT_PATH) as SetupDraftCommandPort
	var transaction := main_root.get_node_or_null(TRANSACTION_PATH) as SessionStartTransactionCoordinator
	result.merge({
		"main_root": main_root,
		"coordinator": coordinator,
		"world_session": world_session,
		"game_session": game_session,
		"draft_service": draft_service,
		"command_port": command_port,
		"transaction": transaction,
		"save_coordinator": save_coordinator,
		"qa_save_override_ready": qa_override_ready,
	}, true)
	if coordinator == null or world_session == null or game_session == null \
		or draft_service == null or command_port == null or transaction == null:
		result["reason_code"] = "formal_session_start_composition_unavailable"
		return result

	var configure_result := _configure_draft(draft_service, command_port, configuration, request_id)
	result["draft_command_receipts"] = (configure_result.get("receipts", []) as Array).duplicate(true)
	if not bool(configure_result.get("configured", false)):
		result["reason_code"] = str(configure_result.get("reason_code", "setup_draft_configuration_failed"))
		return result
	var request := SessionStartRequest.create(
		request_id,
		draft_service.draft_snapshot(),
		game_session.session_start_revision(),
		"focused_test"
	)
	var receipt := transaction.start_session(request)
	result["receipt"] = receipt
	result["transaction_snapshot"] = transaction.operation_snapshot()
	result["started"] = receipt != null and receipt.applied
	result["reason_code"] = receipt.reason_code if receipt != null else "session_start_receipt_missing"
	result["main_start_call_count"] = 0
	result["setup_fallback_count"] = 0
	if bool(result["started"]):
		await tree.process_frame
		await tree.process_frame
	return result


static func _configure_draft(
	draft: NewGameSetupDraftService,
	commands: SetupDraftCommandPort,
	configuration: Dictionary,
	request_id: String
) -> Dictionary:
	var receipts: Array = []
	var sequence := 0
	var reset_result := _submit(commands, draft, request_id, sequence, SetupDraftCommand.KIND_RESET_DEFAULTS)
	sequence += 1
	receipts.append(reset_result.get("receipt", {}))
	if not bool(reset_result.get("applied", false)):
		return {"configured": false, "reason_code": reset_result.get("reason_code", "setup_reset_failed"), "receipts": receipts}

	var player_count := int(configuration.get("player_count", 4))
	var ai_player_count := int(configuration.get("ai_player_count", 3))
	var challenge_depth := int(configuration.get("challenge_depth", 1))
	for setting in [
		[SetupDraftCommand.KIND_SET_PLAYER_COUNT, player_count],
		[SetupDraftCommand.KIND_SET_AI_PLAYER_COUNT, ai_player_count],
		[SetupDraftCommand.KIND_SET_CHALLENGE_DEPTH, challenge_depth],
	]:
		var setting_result := _submit(commands, draft, request_id, sequence, setting[0], int(setting[1]))
		sequence += 1
		receipts.append(setting_result.get("receipt", {}))
		if not bool(setting_result.get("applied", false)):
			return {"configured": false, "reason_code": setting_result.get("reason_code", "setup_value_failed"), "receipts": receipts}

	var role_indices: Array = configuration.get("role_indices", []) if configuration.get("role_indices", []) is Array else []
	if not role_indices.is_empty():
		for player_index in range(player_count):
			if player_index >= role_indices.size():
				return {"configured": false, "reason_code": "setup_role_configuration_incomplete", "receipts": receipts}
			var role_result := _set_role(commands, draft, request_id, sequence, player_index, int(role_indices[player_index]))
			sequence = int(role_result.get("next_sequence", sequence + 1))
			receipts.append_array(role_result.get("receipts", []))
			if not bool(role_result.get("configured", false)):
				return {"configured": false, "reason_code": role_result.get("reason_code", "setup_role_configuration_failed"), "receipts": receipts}

	var starter_indices: Array = configuration.get("starter_monster_indices", []) if configuration.get("starter_monster_indices", []) is Array else []
	if not starter_indices.is_empty():
		for player_index in range(player_count):
			if player_index >= starter_indices.size():
				return {"configured": false, "reason_code": "setup_monster_configuration_incomplete", "receipts": receipts}
			var snapshot := draft.draft_snapshot()
			var current_indices: Array = snapshot.get("starter_monster_indices", []) if snapshot.get("starter_monster_indices", []) is Array else []
			if player_index >= current_indices.size():
				return {"configured": false, "reason_code": "setup_monster_snapshot_invalid", "receipts": receipts}
			var delta := int(starter_indices[player_index]) - int(current_indices[player_index])
			if delta == 0:
				continue
			var monster_result := _submit(commands, draft, request_id, sequence, SetupDraftCommand.KIND_STEP_STARTER_MONSTER, delta, player_index)
			sequence += 1
			receipts.append(monster_result.get("receipt", {}))
			if not bool(monster_result.get("applied", false)):
				return {"configured": false, "reason_code": monster_result.get("reason_code", "setup_monster_configuration_failed"), "receipts": receipts}
	return {"configured": true, "reason_code": "setup_draft_configured", "receipts": receipts}


static func _set_role(
	commands: SetupDraftCommandPort,
	draft: NewGameSetupDraftService,
	request_id: String,
	sequence: int,
	player_index: int,
	desired_role_index: int
) -> Dictionary:
	var receipts: Array = []
	if desired_role_index == NewGameSetupDraftService.ROLE_RANDOM_INDEX:
		var random_result := _submit(commands, draft, request_id, sequence, SetupDraftCommand.KIND_SET_ROLE_RANDOM, 0, player_index)
		receipts.append(random_result.get("receipt", {}))
		return {"configured": random_result.get("applied", false), "reason_code": random_result.get("reason_code", "setup_random_role_failed"), "receipts": receipts, "next_sequence": sequence + 1}
	var role_count := 0
	var parent := draft.get_node_or_null(draft.role_catalog_path) as RoleCatalogRuntimeService
	if parent != null:
		role_count = parent.role_count()
	for _attempt in range(maxi(1, role_count + 1)):
		var indices: Array = draft.draft_snapshot().get("role_indices", [])
		if player_index < indices.size() and int(indices[player_index]) == desired_role_index:
			return {"configured": true, "reason_code": "setup_role_configured", "receipts": receipts, "next_sequence": sequence}
		var step_result := _submit(commands, draft, request_id, sequence, SetupDraftCommand.KIND_STEP_ROLE, 1, player_index)
		sequence += 1
		receipts.append(step_result.get("receipt", {}))
		if not bool(step_result.get("applied", false)):
			return {"configured": false, "reason_code": step_result.get("reason_code", "setup_role_step_failed"), "receipts": receipts, "next_sequence": sequence}
	return {"configured": false, "reason_code": "setup_role_target_unreachable", "receipts": receipts, "next_sequence": sequence}


static func _submit(
	commands: SetupDraftCommandPort,
	draft: NewGameSetupDraftService,
	request_id: String,
	sequence: int,
	kind: StringName,
	value: int = 0,
	player_index: int = -1
) -> Dictionary:
	var command := SetupDraftCommand.create(
		"%s:draft:%d" % [request_id, sequence],
		kind,
		int(draft.draft_snapshot().get("draft_revision", -1)),
		value,
		player_index,
		"focused_test"
	)
	var receipt := commands.submit_command(command)
	return {
		"applied": receipt != null and receipt.applied,
		"reason_code": receipt.reason_code if receipt != null else "setup_command_receipt_missing",
		"receipt": receipt.to_dictionary() if receipt != null else {},
	}


static func _empty_result(reason_code: String) -> Dictionary:
	return {
		"started": false,
		"reason_code": reason_code,
		"receipt": null,
		"main_root": null,
		"coordinator": null,
		"world_session": null,
		"game_session": null,
		"draft_service": null,
		"command_port": null,
		"transaction": null,
		"save_coordinator": null,
		"qa_save_override_ready": false,
		"draft_command_receipts": [],
		"transaction_snapshot": {},
		"main_start_call_count": 0,
		"setup_fallback_count": 0,
	}
