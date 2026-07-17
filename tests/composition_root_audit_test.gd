extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	_check(packed != null, "formal main scene loads")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	_check(main.get_node_or_null("RuntimeGameScreen") != null, "main composes one RuntimeGameScreen")
	_check(main.get_node_or_null("RuntimeServices/RuntimeControllerHost") != null, "main exposes the runtime controller host")
	var coordinator := main.get_node_or_null(COORDINATOR_PATH) as GameRuntimeCoordinator
	_check(coordinator != null, "GameRuntimeCoordinator is the formal runtime composition root")
	if coordinator != null:
		_check(coordinator.find_children("RuntimeLoop", "RuntimeLoop", true, false).size() == 1, "one RuntimeLoop is composed")
		_check(coordinator.find_children("RuntimeCommandPipeline", "RuntimeCommandPipeline", true, false).size() == 1, "one RuntimeCommandPipeline is composed")
		_check(coordinator.find_children("SimulationMutationAuthority", "SimulationMutationAuthority", true, false).size() == 1, "one SimulationMutationAuthority is composed")
		_check(coordinator.find_children("MonsterRuntimeController", "MonsterRuntimeController", true, false).size() == 1, "one MonsterRuntimeController owner is composed")
		_check(coordinator.find_children("MonsterMoveCommandSink", "MonsterMoveCommandSink", true, false).size() == 1, "one monster move sink is composed")
		_check(coordinator.find_children("MonsterActionCommandSink", "MonsterActionCommandSink", true, false).size() == 1, "one monster action sink is composed")
		var pipeline := coordinator.get_node_or_null("RuntimeCommandPipeline") as RuntimeCommandPipeline
		_check(pipeline != null and bool(pipeline.debug_snapshot().get("monster_move_ready", false)), "move command boundary is wired")
		_check(pipeline != null and bool(pipeline.debug_snapshot().get("monster_action_ready", false)), "special action command boundary is wired")
		_check(pipeline != null and int(pipeline.debug_snapshot().get("supported_command_type_count", 0)) == 4, "command pipeline has one authoritative four-type registry")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	_check(not coordinator_source.contains("get_tree()"), "coordinator does not discover the scene tree")
	_check(not coordinator_source.contains("current_scene"), "coordinator does not use current_scene lookup")
	_check(not coordinator_source.contains("/root" + "/Main"), "coordinator has no root Main lookup")
	_check(not coordinator_source.contains("main" + ".call(") and not coordinator_source.contains("main" + ".get(") and not coordinator_source.contains("main" + ".set("), "coordinator has no dynamic Main fallback")
	var runtime_files := _runtime_production_files()
	var dynamic_main_refs := 0
	for path in runtime_files:
		var source := FileAccess.get_file_as_string(path)
		if source.contains("/root" + "/Main") or source.contains("current_scene"):
			dynamic_main_refs += 1
	_check(dynamic_main_refs == 0, "runtime production controllers have no root-scene Main discovery")
	_check(coordinator != null and coordinator.get_node_or_null("MonsterActionCommandSink") != null, "special-action mutation stays below the composition root")
	main.queue_free()
	await process_frame
	_finish()


func _runtime_production_files() -> Array[String]:
	var files: Array[String] = []
	var directory := DirAccess.open("res://scripts/runtime")
	if directory == null:
		return files
	for filename in directory.get_files():
		if filename.ends_with(".gd"):
			files.append("res://scripts/runtime/%s" % filename)
	return files


func _finish() -> void:
	print("composition_root_audit_test: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		push_error("\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
