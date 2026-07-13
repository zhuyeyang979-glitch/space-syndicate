extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const QA_OUTPUT_DIR := "user://space_syndicate_design_qa/game_session_save_ownership/fixtures/"
const QA_FIXTURE_PATH := QA_OUTPUT_DIR + "pre_cutover_current_run_v1.save"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate() as Control
	_expect(main != null, "main scene instantiates")
	if main == null:
		_finish()
		return
	main.call("_bind_ruleset_runtime_bridge")
	main.call("_bind_game_runtime_coordinator")
	main.call("_bind_city_development_runtime_controller")
	main.call("_bind_card_resolution_runtime_controller")
	var state: Dictionary = main.call("_capture_run_state")
	_expect(int(state.get("version", 0)) == 1, "current run save version is 1")
	_expect(state.get("players", null) is Array, "current run payload keeps players array")
	_expect(state.get("districts", null) is Array, "current run payload keeps districts array")
	_expect(state.has("card_resolution_queue") and state.has("active_monster_wagers"), "current run payload keeps card and forced-decision state")
	var make_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(QA_OUTPUT_DIR))
	_expect(make_error == OK, "QA fixture directory can be created")
	var save_error := int(main.call("_save_run", QA_FIXTURE_PATH))
	_expect(save_error == OK, "current main writes a QA-only characterization save")
	var file := FileAccess.open(QA_FIXTURE_PATH, FileAccess.READ)
	_expect(file != null, "characterization save reopens")
	var loaded: Variant = file.get_var(false) if file != null else null
	if file != null:
		file.close()
	_expect(loaded is Dictionary, "characterization save uses Variant Dictionary format")
	if loaded is Dictionary:
		_expect((loaded as Dictionary) == state, "binary Variant roundtrip preserves the current payload")
		print("GAME SESSION SAVE CHARACTERIZATION keys=%s" % ",".join((loaded as Dictionary).keys()))
	main.free()
	packed = null
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("GAME SESSION SAVE CHARACTERIZATION: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("GAME SESSION SAVE CHARACTERIZATION PASS fixture=%s" % QA_FIXTURE_PATH)
		quit(0)
		return
	print("GAME SESSION SAVE CHARACTERIZATION FAIL: %d" % _failures.size())
	quit(1)
