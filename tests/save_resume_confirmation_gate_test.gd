extends SceneTree

const GameSessionRuntimeController := preload("res://scripts/runtime/game_session_runtime_controller.gd")
const SaveResumeIntentV06 := preload("res://scripts/runtime/save_resume_intent_v06.gd")
const SaveSlotPolicyV06 := preload("res://scripts/runtime/save_slot_policy_v06.gd")
const SpaceSyndicatePauseMenuSummaryBoard := preload("res://scripts/ui/pause_menu_summary_board.gd")
const WorldSessionState := preload("res://scripts/runtime/world_session_state.gd")
const PAUSE_BOARD_SCENE := preload("res://scenes/ui/PauseMenuSummaryBoard.tscn")
const GATE_COORDINATOR_SCRIPT := preload("res://tests/support/save_resume_confirmation_gate_coordinator.gd")

var _checks := 0
var _failures: Array[String] = []
var _save_signal_count := 0


class GateSession:
	extends GameSessionRuntimeController

	var summary_state := {
		"session_state": GameSessionRuntimeController.STATE_IDLE,
		"dirty": false,
	}
	var load_call_count := 0
	var save_call_count := 0
	var mutation_revision := 0

	func session_summary() -> Dictionary:
		return summary_state.duplicate(true)

	func request_load(_path: String = "") -> Dictionary:
		load_call_count += 1
		mutation_revision += 1
		return {
			"ok": true,
			"applied": true,
			"reason_code": "resume_applied",
		}

	func request_save(_path: String, _envelope: Dictionary, _authorization: Dictionary = {}) -> Dictionary:
		save_call_count += 1
		return {"ok": true, "reason_code": "unexpected_test_write"}

	func owner_snapshot() -> Dictionary:
		return {
			"summary_state": summary_state.duplicate(true),
			"load_call_count": load_call_count,
			"save_call_count": save_call_count,
			"mutation_revision": mutation_revision,
		}


class CaptureRejectingRegistry:
	extends Node
	var capture_call_count := 0

	func capture_resume_envelope(_identity: Dictionary) -> Dictionary:
		capture_call_count += 1
		return {
			"operation": "capture",
			"ok": false,
			"reason_code": "owner_capture_failed",
			"failing_section_id": "card_inventory",
			"internal_reason_code": "card_inventory_v2_invalid",
		}


class SaveAuthorizationSpy:
	extends Node
	var write_authorization_call_count := 0

	func write_authorization(_path: String, _envelope: Dictionary, _options: Dictionary = {}) -> Dictionary:
		write_authorization_call_count += 1
		return {"allowed": true, "reason_code": "unexpected_test_authorization"}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gate_session := GateSession.new()
	var rejecting_registry := CaptureRejectingRegistry.new()
	rejecting_registry.name = "V06SaveOwnerRegistry"
	gate_session.add_child(rejecting_registry)
	var save_spy := SaveAuthorizationSpy.new()
	save_spy.name = "GameSaveRuntimeCoordinator"
	gate_session.add_child(save_spy)
	var gate_world := WorldSessionState.new()
	var coordinator := GATE_COORDINATOR_SCRIPT.new()
	coordinator.gate_session = gate_session
	coordinator.gate_world = gate_world

	var occupied_before := _production_slot_bytes_snapshot()
	var unconfirmed_save := _save_intent(false)
	var save_receipt_variant: Variant = coordinator.call("submit_save_resume_intent", unconfirmed_save)
	var save_receipt: Dictionary = save_receipt_variant if save_receipt_variant is Dictionary else {}
	_expect(not bool(save_receipt.get("accepted", true)) and not bool(save_receipt.get("applied", true)) and str(save_receipt.get("reason_code", "")) == "confirmation_required", "occupied Save rejects before confirmation")
	_expect(_same_value(occupied_before, _production_slot_bytes_snapshot()), "occupied unconfirmed Save performs no write")

	var pause_board := PAUSE_BOARD_SCENE.instantiate() as SpaceSyndicatePauseMenuSummaryBoard
	root.add_child(pause_board)
	await process_frame
	pause_board.save_game_requested.connect(_on_save_game_requested)
	pause_board.set_save_resume_state({
		"busy": false,
		"can_save": true,
		"slot_state": "ready",
		"summary": "存档：可以继续。",
		"last_succeeded": false,
	})
	var cancel_before := _production_slot_bytes_snapshot()
	pause_board.save_game_button.pressed.emit()
	_expect(bool(pause_board.debug_snapshot().get("confirmation_pending", false)) and _save_signal_count == 0, "occupied Save opens confirmation without submitting")
	pause_board.call("cancel_save_confirmation")
	_expect(not bool(pause_board.debug_snapshot().get("confirmation_pending", true)) and _save_signal_count == 0, "Save cancellation submits no gateway intent")
	_expect(_same_value(cancel_before, _production_slot_bytes_snapshot()), "Save cancellation preserves the existing file byte-for-byte")
	pause_board.queue_free()
	await process_frame

	var capture_rejection_bytes_before := _production_slot_bytes_snapshot()
	var capture_rejection_variant: Variant = coordinator.call("submit_save_resume_intent", _save_intent(true))
	var capture_rejection: Dictionary = capture_rejection_variant if capture_rejection_variant is Dictionary else {}
	_expect(not bool(capture_rejection.get("accepted", true)) \
			and not bool(capture_rejection.get("applied", true)) \
			and str(capture_rejection.get("reason_code", "")) == "owner_capture_failed", "semantic owner capture rejection returns through the production Save gateway")
	_expect(rejecting_registry.capture_call_count == 1 \
			and save_spy.write_authorization_call_count == 0 \
			and gate_session.save_call_count == 0, "semantic owner capture rejection reaches neither write authorization nor Session request_save")
	_expect(_same_value(capture_rejection_bytes_before, _production_slot_bytes_snapshot()), "semantic owner capture rejection preserves the existing destination byte-for-byte")

	gate_session.summary_state = {
		"session_state": GameSessionRuntimeController.STATE_RUNNING,
		"dirty": true,
	}
	gate_world.players = [
		{"id": "player-0", "name": "本地玩家"},
		{"id": "player-1", "name": "对手"},
	]
	var session_before := gate_session.owner_snapshot()
	var world_before := gate_world.capture_runtime_checkpoint()
	var dirty_resume_variant: Variant = coordinator.call("submit_save_resume_intent", _resume_intent(false, "dirty"))
	var dirty_resume: Dictionary = dirty_resume_variant if dirty_resume_variant is Dictionary else {}
	_expect(not bool(dirty_resume.get("accepted", true)) and not bool(dirty_resume.get("applied", true)) and str(dirty_resume.get("reason_code", "")) == "confirmation_required", "dirty active Resume rejects before confirmation")
	_expect(_same_value(session_before, gate_session.owner_snapshot()) and _same_value(world_before, gate_world.capture_runtime_checkpoint()), "dirty unconfirmed Resume performs zero owner mutation")

	gate_session.summary_state = {
		"session_state": GameSessionRuntimeController.STATE_RUNNING,
		"dirty": true,
	}
	gate_world.players = []
	var empty_resume_variant: Variant = coordinator.call("submit_save_resume_intent", _resume_intent(false, "empty"))
	var empty_resume: Dictionary = empty_resume_variant if empty_resume_variant is Dictionary else {}
	_expect(bool(empty_resume.get("accepted", false)) and bool(empty_resume.get("applied", false)) and gate_session.load_call_count == 1, "empty current roster allows Resume directly")

	gate_session.summary_state = {
		"session_state": GameSessionRuntimeController.STATE_IDLE,
		"dirty": false,
	}
	gate_world.players = [{"id": "player-0", "name": "本地玩家"}]
	var inactive_resume_variant: Variant = coordinator.call("submit_save_resume_intent", _resume_intent(false, "inactive"))
	var inactive_resume: Dictionary = inactive_resume_variant if inactive_resume_variant is Dictionary else {}
	_expect(bool(inactive_resume.get("accepted", false)) and bool(inactive_resume.get("applied", false)) and gate_session.load_call_count == 2, "no-active-session Resume is directly allowed without confirmation")

	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var save_gate_index := coordinator_source.find('not intent.destructive_confirmed')
	var capture_index := coordinator_source.find('"capture_resume_envelope"', save_gate_index)
	var resume_gate_index := coordinator_source.find("save_resume_replacement_confirmation_required() and not intent.destructive_confirmed")
	var load_index := coordinator_source.find("session.request_load(path)", resume_gate_index)
	_expect(save_gate_index >= 0 and capture_index > save_gate_index and resume_gate_index >= 0 and load_index > resume_gate_index, "production gateway places both confirmation gates before owner capture/load mutation")

	coordinator.free()
	gate_world.free()
	gate_session.free()
	_finish()


func _save_intent(confirmed: bool) -> SaveResumeIntentV06:
	var intent := SaveResumeIntentV06.new()
	intent.set("schema_version", 2)
	intent.set("request_id", "confirmation-gate-save")
	intent.set("operation", SaveResumeIntentV06.OPERATION_SAVE)
	intent.set("slot_id", SaveSlotPolicyV06.PRODUCTION_SLOT_ID)
	intent.set("source_surface", &"pause_menu")
	intent.set("overwrite_existing", confirmed)
	intent.set("preserve_incompatible_backup", true)
	intent.set("destructive_confirmed", confirmed)
	return intent


func _resume_intent(confirmed: bool, suffix: String) -> SaveResumeIntentV06:
	var intent := SaveResumeIntentV06.new()
	intent.set("schema_version", 2)
	intent.set("request_id", "confirmation-gate-resume-%s" % suffix)
	intent.set("operation", SaveResumeIntentV06.OPERATION_RESUME)
	intent.set("slot_id", SaveSlotPolicyV06.PRODUCTION_SLOT_ID)
	intent.set("source_surface", &"root_menu")
	intent.set("overwrite_existing", false)
	intent.set("preserve_incompatible_backup", false)
	intent.set("destructive_confirmed", confirmed)
	return intent


func _production_slot_bytes_snapshot() -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(SaveSlotPolicyV06.PRODUCTION_PATH)
	var exists := FileAccess.file_exists(absolute_path)
	return {
		"exists": exists,
		"bytes": FileAccess.get_file_as_bytes(absolute_path) if exists else PackedByteArray(),
	}


func _on_save_game_requested(_destructive_confirmed: bool) -> void:
	_save_signal_count += 1


func _same_value(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	if left is Dictionary:
		var left_dictionary := left as Dictionary
		var right_dictionary := right as Dictionary
		if left_dictionary.size() != right_dictionary.size():
			return false
		for key_variant: Variant in left_dictionary.keys():
			if not right_dictionary.has(key_variant) or not _same_value(left_dictionary.get(key_variant), right_dictionary.get(key_variant)):
				return false
		return true
	if left is Array:
		var left_array := left as Array
		var right_array := right as Array
		if left_array.size() != right_array.size():
			return false
		for index in range(left_array.size()):
			if not _same_value(left_array[index], right_array[index]):
				return false
		return true
	return left == right


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("SAVE_RESUME_CONFIRMATION_GATE_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	if not _failures.is_empty():
		push_error("Save/resume confirmation gate failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
