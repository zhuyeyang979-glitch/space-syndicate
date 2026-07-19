extends SceneTree

const BENCH_SCENE := preload("res://scenes/tools/SessionEnvelopeSaveOwnerBench.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bench := BENCH_SCENE.instantiate()
	_expect(bench != null, "session envelope Bench scene instantiates")
	if bench == null:
		_finish(0)
		return
	bench.auto_run_on_ready = false
	root.add_child(bench)
	await process_frame
	var result: Dictionary = bench.run_bench()
	_expect(bool(result.get("passed", false)), "session envelope production transaction matrix passes: %s" % JSON.stringify(result.get("failures", [])))
	_expect(int(result.get("checks", 0)) >= 57, "session envelope Bench executes the full bounded cold-restore matrix")
	bench.queue_free()
	await process_frame
	await _verify_formal_four_player_capture()
	_finish(int(result.get("checks", 0)))


func _verify_formal_four_player_capture() -> void:
	var formal_root := MAIN_SCENE.instantiate()
	formal_root.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(formal_root)
	await process_frame
	var draft := formal_root.get_node_or_null("RuntimeServices/NewGameSetupDraftService") as NewGameSetupDraftService
	var transaction := formal_root.get_node_or_null("RuntimeServices/SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator
	var session := formal_root.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController") as GameSessionRuntimeController
	var request := SessionStartRequest.create(
		"session-envelope-formal-capture",
		draft.draft_snapshot() if draft != null else {},
		session.session_start_revision() if session != null else -1,
		"focused_test"
	)
	var start_receipt := transaction.start_session(request) if transaction != null else null
	_expect(
		start_receipt != null and start_receipt.applied,
		"formal main starts through the scene-owned session transaction: %s" % JSON.stringify(start_receipt.to_dictionary() if start_receipt != null else {})
	)
	await process_frame
	var coordinator := formal_root.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
	var world := coordinator.world_session_state() if coordinator != null else null
	var owner := coordinator.get_node_or_null("GameSessionRuntimeController/SessionEnvelopeSaveOwner") as SessionEnvelopeSaveOwner if coordinator != null else null
	var before: Dictionary = world.to_save_data() if world != null else {}
	var capture: Dictionary = owner.capture_composite_state() if owner != null else {}
	var state: Dictionary = capture.get("state", {}) if capture.get("state", {}) is Dictionary else {}
	var world_state: Dictionary = state.get("world_session_state", {}) if state.get("world_session_state", {}) is Dictionary else {}
	_expect(
		bool(capture.get("captured", false))
		and (world_state.get("players", []) as Array).size() == 4
		and not (world_state.get("districts", []) as Array).is_empty(),
		"formal main four-player world captures through session v2: %s" % str(capture.get("reason_code", "missing_reason"))
	)
	_expect(world != null and world.to_save_data() == before, "formal main capture mutates zero world-session state")
	formal_root.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(bench_checks: int) -> void:
	print("SESSION_ENVELOPE_SAVE_OWNER_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		bench_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Session envelope save owner test failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
