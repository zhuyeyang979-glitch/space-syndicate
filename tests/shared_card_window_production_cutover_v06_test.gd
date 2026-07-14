extends SceneTree

const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const CardResolutionMainTestHarnessScript := preload("res://tests/helpers/card_resolution_main_test_harness.gd")
const GameTableViewModelRuntimeServiceScript := preload("res://scripts/runtime/game_table_viewmodel_runtime_service.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var harness := CardResolutionMainTestHarnessScript.new()
	var main := harness.create_main() as Control
	_expect(main != null, "production main harness binds the authored card-window controller")
	if main == null:
		_finish()
		return
	var controller := harness.controller_for(main)
	_expect(controller != null, "main consumes the sole CardResolutionRuntimeController")
	if controller == null:
		main.free()
		_finish()
		return

	for sequence in range(4):
		var cadence: Dictionary = main.call("_card_group_cadence_snapshot", sequence)
		var opening := sequence < 3
		var expected_total := 45 if opening else 30
		var expected_planning := 35 if opening else 20
		_expect(
			int(cadence.get("window_sequence", -1)) == sequence
			and int(cadence.get("total_seconds", 0)) == expected_total
			and int(cadence.get("planning_seconds", 0)) == expected_planning
			and int(cadence.get("public_bid_seconds", 0)) == 5
			and int(cadence.get("lock_seconds", 0)) == 5,
			"main projects authoritative cadence for window sequence %d" % sequence
		)
		_expect(bool(main.call("_begin_card_group_window", 0, sequence)), "main opens sequence %d through the controller API" % sequence)
		var runtime_snapshot: Dictionary = controller.call("debug_snapshot")
		_expect(int(runtime_snapshot.get("window_sequence", -1)) == sequence, "controller remains the sequence owner for window %d" % sequence)

	var opening_text := str(main.call("_card_group_window_cadence_text", 0))
	var standard_text := str(main.call("_card_group_window_cadence_text", 3))
	_expect(opening_text.contains("45") and opening_text.contains("35") and opening_text.contains("5") and standard_text.contains("30") and standard_text.contains("20"), "player cadence copy is formatted from the controller snapshot")

	var source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var stale_text_absent := not source.contains("8秒卡牌组窗口") \
		and not source.contains("8秒共享窗") \
		and not source.contains("6秒组织") \
		and not source.contains("最后2秒") \
		and not source.contains("默认每组3张")
	_expect(stale_text_absent, "production main no longer presents 8/6/2 or default-three copy")
	_expect(not source.contains("== \"organize\"") and not source.contains("[\"organize\""), "production main consumes planning/public_bid/lock phase names")
	_expect(source.contains("controller.call(\"begin_group_window\""), "main starts shared windows through the authoritative controller")
	_expect(source.contains("func _apply_card_group_wager_pool_receipt"), "cadence cutover leaves public wager receipt ownership unchanged")

	var viewmodel := GameTableViewModelRuntimeServiceScript.new()
	var opening_planning := {"group_phase": "planning", "group_phase_remaining_seconds": 35.0, "group_count": 1}
	var standard_planning := {"group_phase": "planning", "group_phase_remaining_seconds": 20.0, "group_count": 1}
	var public_bid := {"group_phase": "public_bid", "group_phase_remaining_seconds": 5.0, "group_count": 2, "auction_open": true}
	var lock := {"group_phase": "lock", "group_phase_remaining_seconds": 5.0, "group_count": 2}
	_expect(str(viewmodel.call("_track_phase", opening_planning)) == "规划" and str(viewmodel.call("_track_phase", public_bid)) == "公开竞价" and str(viewmodel.call("_track_phase", lock)) == "锁牌", "ViewModel maps planning/public_bid/lock without the legacy organize phase")
	var cadence_copy := [
		str(viewmodel.call("_track_summary", opening_planning, [])),
		str(viewmodel.call("_track_summary", standard_planning, [])),
		str(viewmodel.call("_track_summary", public_bid, [])),
		str(viewmodel.call("_track_summary", lock, [])),
	]
	_expect(cadence_copy[0].contains("35秒") and cadence_copy[1].contains("20秒") and cadence_copy[2].contains("5秒") and cadence_copy[3].contains("5秒"), "ViewModel consumes both opening and standard authoritative phase durations")
	_expect(not "｜".join(cadence_copy).contains("前6秒") and not "｜".join(cadence_copy).contains("最后2秒"), "ViewModel cadence copy contains no stale 6/2 wording")
	var legacy_summary := str(viewmodel.call("_track_summary", {"group_phase": "organize", "group_phase_remaining_seconds": 20.0}, []))
	_expect(str(viewmodel.call("_track_phase", {"group_phase": "organize"})) == "规划" and legacy_summary.contains("规划阶段") and not legacy_summary.contains("组织"), "legacy organize input is normalized internally without displaying the old rule")
	viewmodel.free()

	main.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("SHARED CARD WINDOW PRODUCTION CUTOVER: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Shared card window production cutover v0.6 test passed. checks=%d" % _checks)
		quit(0)
		return
	push_error("Shared card window production cutover v0.6 test failed:\n- %s" % "\n- ".join(_failures))
	quit(1)
