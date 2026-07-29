extends Node

@export var auto_run := true
@export var auto_quit := true

var _checks := 0
var _failures: Array[String] = []
var _run_started := false
var _last_result: Dictionary = {}


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("_run_auto_bench")


func _run_auto_bench() -> void:
	var result := await run_bench()
	if not auto_quit:
		return
	# Keep the focused scene alive briefly so MCP can read the terminal result
	# before the self-running Bench closes.
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0 if bool(result.get("passed", false)) else 1)


func run_bench() -> Dictionary:
	if _run_started:
		return _last_result.duplicate(true)
	_run_started = true
	await get_tree().process_frame
	await get_tree().process_frame

	var flow := get_node_or_null("SaveResumeApplicationFlowController") as SaveResumeApplicationFlowController
	var gateway := get_node_or_null("FakeSaveResumeRuntimeGateway")
	var production_main := get_node_or_null("ProductionMain")
	var lifecycle := production_main.get_node_or_null("RuntimeServices/MenuLifecycleApplicationFlowController") as MenuLifecycleApplicationFlowController if production_main != null else null
	var coordinator := production_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator if production_main != null else null
	var world := production_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/WorldSessionState") as WorldSessionState if production_main != null else null
	var overlay := production_main.get_node_or_null("RuntimeGameScreen/OverlayLayer/RuntimeSurfaceLayer/MenuModalOverlay") as SpaceSyndicateMenuOverlay if production_main != null else null
	_expect(flow != null and gateway != null, "flow bench composes the scene-owned controller and one fake high-level gateway")
	_expect(lifecycle != null and coordinator != null and world != null and overlay != null, "production menu dependencies load in the focused Bench")
	if flow == null or gateway == null or lifecycle == null or coordinator == null or world == null or overlay == null:
		return _finish()

	_expect(SaveSlotPolicyV06.path_for_production_slot(&"current_run") == "user://saves/v06/current_run.save", "v0.6 production uses one fixed local slot")
	_expect(SaveSlotPolicyV06.is_allowed_path("user://saves/v06/current_run.save"), "fixed production path is accepted")
	var qa_path := SaveSlotPolicyV06.qa_path("run-001", "producer")
	_expect(qa_path == "user://test_runs/alpha04c/run-001/producer.save" and SaveSlotPolicyV06.is_allowed_path(qa_path, true), "QA path is isolated by run and process role")
	_expect(not SaveSlotPolicyV06.is_allowed_path("user://test_runs/alpha04c/../escape.save", true) and SaveSlotPolicyV06.qa_path("../bad", "producer").is_empty(), "path traversal fails closed")
	var descriptor_text := JSON.stringify(SaveSlotPolicyV06.production_slot_descriptor())
	_expect(not descriptor_text.contains("user://") and descriptor_text.contains("current_run"), "player-safe slot descriptor omits the filesystem path")

	var intent := SaveResumeIntentV06.save("bench:save:1", &"pause_menu")
	var roundtrip := SaveResumeIntentV06.from_dictionary(intent.to_dictionary())
	_expect(intent.is_valid() and roundtrip != null and roundtrip.is_valid(), "typed save intent roundtrips as closed data")
	var intent_text := JSON.stringify(intent.to_dictionary())
	_expect(not intent_text.contains("user://") and not intent_text.contains("envelope") and not intent_text.contains("fingerprint"), "typed intent contains no path, envelope, or fingerprint")

	_set_ready_inspection(gateway)
	var state_signal_count := [0]
	flow.public_state_changed.connect(func(_snapshot: Dictionary) -> void: state_signal_count[0] = int(state_signal_count[0]) + 1)
	var inspection := flow.inspect_slot(&"root_menu")
	_expect(inspection.accepted and not inspection.applied and inspection.can_resume, "inspection accepts a ready fixed slot without pretending to apply it")
	var public_snapshot := flow.public_snapshot()
	var public_text := JSON.stringify(public_snapshot).to_lower()
	_expect(bool(public_snapshot.get("can_resume", false)) and str(public_snapshot.get("summary", "")).contains("4席"), "public inspection exposes concise resume metadata")
	_expect(not _contains_forbidden_public_term(public_text), "public save projection excludes private and transport internals")
	_expect(int(state_signal_count[0]) >= 2, "inspection publishes busy and terminal public states")

	gateway.call("set_response", &"inspect", _inspection_response("empty", true, true, false, false, "save_not_found"))
	var empty_inspection := flow.inspect_slot(&"root_menu")
	_expect(empty_inspection.accepted and empty_inspection.slot_state == SaveResumeReceiptV06.SLOT_EMPTY and not empty_inspection.can_resume, "empty fixed slot remains saveable but cannot resume")
	_expect(str(flow.public_snapshot().get("summary", "")) == "存档：暂无可继续的游戏。", "empty slot has a concise public summary")
	gateway.call("set_response", &"inspect", _inspection_response("corrupt", false, true, false, true, "save_corrupt"))
	var corrupt_inspection := flow.inspect_slot(&"root_menu")
	_expect(not corrupt_inspection.accepted and corrupt_inspection.backup_available, "corrupt slot fails closed while preserving backup availability")
	_expect(str(flow.public_snapshot().get("summary", "")).contains("可尝试备份"), "corrupt slot summary offers only the safe recovery fact")
	_set_ready_inspection(gateway)

	gateway.set("reentrant_flow_path", gateway.get_path_to(flow))
	gateway.set("trigger_reentrant_save", true)
	flow.inspect_slot(&"root_menu")
	var reentrant_receipt := gateway.get("reentrant_receipt") as SaveResumeReceiptV06
	_expect(reentrant_receipt != null and reentrant_receipt.reason_code == "operation_in_progress", "reentrant operation fails closed while the active inspection completes")
	_expect(not bool(flow.public_snapshot().get("busy", true)), "outer operation leaves the flow out of busy state")

	gateway.call("set_response", &"save", _successful_save_response())
	var save_receipt := flow.request_save_game(&"pause_menu")
	_expect(save_receipt.accepted and save_receipt.applied and save_receipt.can_resume, "typed save receipt reports one applied high-level save")
	_expect(str(flow.public_snapshot().get("summary", "")) == "存档：已保存当前游戏。", "successful save publishes a concise player summary")

	gateway.call("set_response", &"save", {
		"accepted": false,
		"applied": false,
		"reason_code": "write_failed",
		"slot_state": "ready",
		"can_save": true,
		"can_resume": true,
		"backup_available": false,
		"saved_at_unix": 0,
		"playtime_seconds": 0,
		"seat_count": 4,
		"ruleset_id": "v0.6",
	})
	var failed_save := flow.request_save_game(&"pause_menu")
	_expect(not failed_save.accepted and str(flow.public_snapshot().get("summary", "")).contains("当前牌桌未受影响"), "failed save keeps a safe non-destructive summary")

	gateway.call("set_response", &"inspect", {
		"accepted": true,
		"applied": false,
		"reason_code": "slot_ready",
		"slot_state": "ready",
		"can_save": true,
		"can_resume": true,
		"backup_available": false,
		"saved_at_unix": 1,
		"playtime_seconds": 754,
		"seat_count": 4,
		"ruleset_id": "v0.6",
		"envelope": {"private": "must-reject"},
	})
	# The fake itself emits the closed gateway shape, so exercise a malformed
	# direct gateway result through a temporary shim method on the flow contract.
	var malformed_intent := SaveResumeIntentV06.inspect("bench:malformed", &"root_menu")
	var malformed := SaveResumeReceiptV06.from_gateway_result(malformed_intent, {
		"schema_version": 1,
		"request_id": malformed_intent.request_id,
		"operation": "inspect",
		"slot_id": "current_run",
		"accepted": true,
		"applied": false,
		"reason_code": "slot_ready",
		"slot_state": "ready",
		"can_save": true,
		"can_resume": true,
		"backup_available": false,
		"saved_at_unix": 1,
		"playtime_seconds": 1,
		"seat_count": 4,
		"ruleset_id": "v0.6",
		"envelope": {},
	})
	_expect(not malformed.accepted and malformed.reason_code == "gateway_receipt_shape_invalid", "unknown gateway fields fail closed before reaching presentation")

	_set_ready_inspection(gateway)
	lifecycle.bind_save_resume_flow(lifecycle.get_path_to(flow))
	world.players = [{"name": "本地玩家"}, {"name": "对手甲"}, {"name": "对手乙"}, {"name": "对手丙"}]
	coordinator.begin_session({"session_id": "save-resume-menu-bench", "scenario_id": "bench", "seed": 41, "player_count": 4})
	_expect(lifecycle.open_root_menu(), "root menu opens with the bound save/resume flow")
	var lobby := overlay.find_child("MainMenuPlanetLobbyPanel", true, false) as SpaceSyndicateMenuRootLobby
	var resume_button := lobby.get_resume_run_button() if lobby != null else null
	_expect(resume_button != null and resume_button.text == "继续游戏" and not resume_button.disabled, "main menu exposes an enabled 继续游戏 action for a ready slot")
	_expect(str(overlay.run_save_label.text).contains("4席"), "main menu shows only the public slot summary")

	gateway.call("set_response", &"resume", _successful_resume_response())
	if resume_button != null:
		resume_button.pressed.emit()
	_expect(not overlay.visible, "successful Continue returns to the active table")
	_expect(int(lifecycle.debug_snapshot().get("load_request_count", 0)) == 1, "Continue submits exactly one typed resume intent")

	gateway.call("set_response", &"save", _successful_save_response())
	_expect(lifecycle.open_pause_menu(), "pause menu opens for an active table")
	var pause_board := overlay.find_child("PauseMenuSummaryBoard", true, false) as SpaceSyndicatePauseMenuSummaryBoard
	_expect(pause_board != null and not pause_board.save_game_button.disabled, "pause summary exposes an enabled 保存游戏 action")
	if pause_board != null:
		pause_board.set_save_resume_state(SaveResumeReceiptV06.busy_public_snapshot(SaveResumeIntentV06.OPERATION_SAVE))
		_expect(pause_board.save_game_button.disabled and pause_board.save_game_button.text == "保存中…", "pause summary renders the saving state and blocks duplicate clicks")
		pause_board.set_save_resume_state(flow.public_snapshot())
		pause_board.save_game_button.pressed.emit()
	_expect(pause_board != null and str(pause_board.save_game_status_label.text) == "存档：已保存当前游戏。", "pause summary reports save success without leaving the menu")
	_expect(int(lifecycle.debug_snapshot().get("save_request_count", 0)) == 1, "pause save submits exactly one typed save intent")

	var flow_source := FileAccess.get_file_as_string("res://scripts/runtime/save_resume_application_flow_controller.gd")
	var lifecycle_source := FileAccess.get_file_as_string("res://scripts/runtime/menu_lifecycle_application_flow_controller.gd")
	_expect(flow_source.contains("submit_save_resume_intent") and not flow_source.contains("request_run_save") and not flow_source.contains("read_and_validate"), "application flow depends only on the one high-level gateway contract")
	_expect(not lifecycle_source.contains("request_run_load") and not lifecycle_source.contains("inspect_run_save"), "menu lifecycle no longer calls the legacy raw save facade")
	return _finish()


func _set_ready_inspection(gateway: Node) -> void:
	gateway.call("set_response", &"inspect", {
		"accepted": true,
		"applied": false,
		"reason_code": "slot_ready",
		"slot_state": "ready",
		"can_save": true,
		"can_resume": true,
		"backup_available": false,
		"saved_at_unix": 1785326400,
		"playtime_seconds": 754,
		"seat_count": 4,
		"ruleset_id": "v0.6",
	})


func _successful_save_response() -> Dictionary:
	return {
		"accepted": true,
		"applied": true,
		"reason_code": "save_committed",
		"slot_state": "ready",
		"can_save": true,
		"can_resume": true,
		"backup_available": false,
		"saved_at_unix": 1785326400,
		"playtime_seconds": 754,
		"seat_count": 4,
		"ruleset_id": "v0.6",
	}


func _inspection_response(
	state: String,
	is_accepted: bool,
	allows_save: bool,
	allows_resume: bool,
	has_backup: bool,
	reason: String
) -> Dictionary:
	return {
		"accepted": is_accepted,
		"applied": false,
		"reason_code": reason,
		"slot_state": state,
		"can_save": allows_save,
		"can_resume": allows_resume,
		"backup_available": has_backup,
		"saved_at_unix": 0,
		"playtime_seconds": 0,
		"seat_count": 0,
		"ruleset_id": "",
	}


func _successful_resume_response() -> Dictionary:
	var response := _successful_save_response()
	response["reason_code"] = "resume_applied"
	return response


func _contains_forbidden_public_term(text: String) -> bool:
	for token in ["user://", "envelope", "section", "fingerprint", "write_id", "request_id", "cash", "hand", "discard", "ai_memory", "owner_truth", "rng_state"]:
		if text.contains(token):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> Dictionary:
	_last_result = {"passed": _failures.is_empty(), "checks": _checks, "failures": _failures.duplicate()}
	print("SaveResumeApplicationFlowBench: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		push_error("SaveResumeApplicationFlowBench failures:\n- " + "\n- ".join(_failures))
	return _last_result.duplicate(true)
