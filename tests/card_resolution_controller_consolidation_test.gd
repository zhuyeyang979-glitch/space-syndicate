extends SceneTree

const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const CONTROLLER_SCENE_PATH := "res://scenes/runtime/CardResolutionRuntimeController.tscn"
const CardResolutionMainTestHarnessScript := preload("res://tests/helpers/card_resolution_main_test_harness.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	_expect(not main_source.contains("_update_card_resolution_queue_legacy"), "main.gd no longer contains the legacy card-resolution tick")
	_expect(not main_source.contains("_legacy_card_resolution_") and not main_source.contains("_legacy_card_group_window_sequence") and not main_source.contains("_legacy_last_card_resolution_player_index"), "main.gd no longer declares legacy timing backing fields")

	var harness := CardResolutionMainTestHarnessScript.new()
	var main := harness.create_main() as Control
	_expect(main != null, "test harness creates a script-level main with the real controller scene")
	if main == null:
		_finish()
		return
	var controller := harness.controller_for(main)
	_expect(controller != null and controller.scene_file_path == CONTROLLER_SCENE_PATH, "test harness mounts CardResolutionRuntimeController.tscn at the production node path")
	if controller == null:
		main.free()
		_finish()
		return

	var initial_snapshot: Dictionary = controller.call("debug_snapshot")
	_expect(bool(initial_snapshot.get("controller_authoritative", false)) and not bool(initial_snapshot.get("legacy_state_fallback_used", true)) and not bool(initial_snapshot.get("controller_missing", true)), "script-level main reports one authoritative controller and no timing fallback")

	var property_cases := [
		{"main": "card_resolution_timer", "controller": "active_display_timer", "value": 3.5},
		{"main": "card_resolution_counter_window_active", "controller": "counter_window_active", "value": true},
		{"main": "card_resolution_counter_timer", "controller": "counter_timer", "value": 2.5},
		{"main": "card_resolution_simultaneous_timer", "controller": "simultaneous_timer", "value": 24.0},
		{"main": "card_resolution_auction_timer", "controller": "auction_timer", "value": 4.0},
		{"main": "card_resolution_auction_open", "controller": "auction_open", "value": true},
		{"main": "card_resolution_batch_locked", "controller": "batch_locked", "value": false},
		{"main": "card_resolution_batch_reference_player", "controller": "batch_reference_player", "value": 2},
		{"main": "card_group_window_sequence", "controller": "window_sequence", "value": 12},
		{"main": "last_card_resolution_player_index", "controller": "last_resolution_player_index", "value": 1},
	]
	var proxies_match := true
	for case_variant in property_cases:
		var property_case: Dictionary = case_variant
		main.set(StringName(property_case["main"]), property_case["value"])
		proxies_match = proxies_match and main.get(StringName(property_case["main"])) == controller.get(StringName(property_case["controller"]))
	_expect(proxies_match, "main compatibility properties write through to and read from the controller")
	controller.set("simultaneous_timer", 6.0)
	_expect(is_equal_approx(float(main.get("card_resolution_simultaneous_timer")), 6.0), "controller-side changes are immediately visible through the main compatibility proxy")

	var saved: Dictionary = controller.call("to_save_data")
	_expect(saved.has("card_resolution_timer") and saved.has("card_resolution_simultaneous_timer") and saved.has("card_group_window_sequence") and int(saved.get("card_group_window_sequence", 0)) == 12, "Controller save boundary preserves existing card-resolution keys")
	var legacy_auction_state := saved.duplicate(true)
	legacy_auction_state["card_resolution_simultaneous_timer"] = 0.0
	legacy_auction_state["card_resolution_auction_timer"] = 4.0
	legacy_auction_state["card_resolution_auction_open"] = true
	controller.call("apply_save_data", legacy_auction_state)
	_expect(is_equal_approx(float(controller.get("simultaneous_timer")), 9.0), "Controller.apply_save_data migrates auction-only state into public bid")

	controller.call("reset_state")
	controller.call("begin_group_window", 30.0, 1, 9)
	var external_players := [{"cash": 900}]
	var external_districts := [{"id": 4, "city": {"owner": 0}}]
	var commands: Array = controller.call("tick", 1.0, {
		"queue_empty": false,
		"active_present": false,
		"players": external_players,
		"districts": external_districts,
	})
	_expect(_is_pure_data(commands), "controller tick emits pure-data transition commands")
	_expect(int((external_players[0] as Dictionary).get("cash", 0)) == 900 and int((external_districts[0] as Dictionary).get("id", -1)) == 4, "controller tick does not mutate players, districts, or card effects")

	var bare_main_script := load(MAIN_SCRIPT_PATH) as Script
	var bare_main := bare_main_script.new() as Control if bare_main_script != null else null
	var missing_controller := bare_main == null or bare_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionRuntimeController") == null
	_expect(missing_controller and not main_source.contains("legacy_state_fallback_used"), "a bare main has no hidden fallback timing state machine")
	if bare_main != null:
		bare_main.free()
	main.free()
	_finish()


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or value is Object:
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not _is_pure_data(key_variant) or not _is_pure_data((value as Dictionary)[key_variant]):
				return false
	if value is Array:
		for item in value as Array:
			if not _is_pure_data(item):
				return false
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("CARD RESOLUTION CONSOLIDATION: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Card resolution controller consolidation test passed.")
		quit(0)
		return
	push_error("Card resolution controller consolidation test failed:\n- %s" % "\n- ".join(_failures))
	quit(1)
