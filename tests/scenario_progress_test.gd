extends SceneTree

const LOADER_SCRIPT := preload("res://scripts/scenarios/scenario_loader.gd")
const PROGRESS_SCRIPT := preload("res://scripts/scenarios/scenario_progress.gd")
const MAIN_SCENE_PATH := "res://scenes/main.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scenario: Dictionary = LOADER_SCRIPT.new().load_by_id("first_table")
	_expect(not scenario.is_empty(), "first_table scenario loads")
	var progress: Variant = PROGRESS_SCRIPT.new().apply_state(scenario)
	_expect(str(progress.current_phase().get("id", "")) == "select_district", "first_table starts at select_district")
	var expected := [
		["district_selected", "first_summon"],
		["monster_summoned", "build_city"],
		["city_built", "open_rack"],
		["rack_opened", "buy_card"],
		["card_bought", "play_card"],
	]
	for pair in expected:
		progress.mark_signal(str(pair[0]))
		_expect(str(progress.current_phase().get("id", "")) == str(pair[1]), "after %s first_table advances to %s" % [str(pair[0]), str(pair[1])])
	progress.mark_signal("card_played")
	_expect(progress.is_complete(), "first_table completes after card_played")
	var snapshot: Dictionary = progress.to_dictionary()
	_expect(int(snapshot.get("current_index", -1)) == 6 and bool(snapshot.get("completed", false)), "progress snapshot records completed first_table")
	await _check_runtime_auto_signal_progression()
	if _failures.is_empty():
		print("Scenario progress test passed.")
	else:
		push_error("Scenario progress test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())


func _check_runtime_auto_signal_progression() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main scene loads for runtime scenario progression")
	if packed == null:
		return
	var main := packed.instantiate()
	get_root().add_child(main)
	await process_frame
	if main.has_method("_start_scenario_from_menu") and main.has_method("_select_district"):
		main.call("_start_scenario_from_menu", "first_table")
		await process_frame
		main.call("_select_district", 0)
		await process_frame
		var signals: Dictionary = main.get("scenario_completed_signals") as Dictionary
		var coach: Dictionary = main.call("_runtime_scenario_coach_snapshot_source", 0) as Dictionary
		var phase: Dictionary = coach.get("current_phase", {}) if coach.get("current_phase", {}) is Dictionary else {}
		_expect(bool(signals.get("district_selected", false)), "runtime district selection auto-completes the current scenario signal")
		_expect(str(phase.get("id", "")) == "first_summon", "runtime coach advances after the real district-selection action")
	else:
		_expect(false, "main scene exposes scenario start and district selection hooks")
	get_root().remove_child(main)
	main.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)
