extends SceneTree

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/" + "main.gd")
	var lines := source.split("\n")
	var nonblank := 0
	for line in lines:
		if not str(line).strip_edges().is_empty():
			nonblank += 1
	var method_count := _count_regex(source, "^func\\s", true)
	_check(lines.size() <= 13159 and nonblank <= 11414 and method_count <= 819, "Main budget is no larger than the audited pre-reduction baseline")
	_check(not source.contains("func _process("), "Main is not a gameplay frame owner")
	_check(not source.contains("SimulationMutationAuthority"), "Main does not own mutation authority")
	_check(not source.contains("dispatch_monster_action"), "Main does not dispatch monster actions")
	_check(not source.contains("apply_autonomous_action_command"), "Main does not mutate autonomous monster actions")
	_check(not source.contains("RuntimeCommandPipeline"), "Main does not own the command pipeline")
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "formal application scene remains the only entry scene")
	if packed != null:
		var app := packed.instantiate()
		root.add_child(app)
		await process_frame
		_check(app.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") != null, "Main delegates runtime composition to GameRuntimeCoordinator")
		_check(app.find_children("RuntimeLoop", "RuntimeLoop", true, false).size() == 1, "application scene has one RuntimeLoop")
		_check(app.find_children("GameRuntimeCoordinator", "GameRuntimeCoordinator", true, false).size() == 1, "application scene has one coordinator")
		app.queue_free()
		await process_frame
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	_check(not coordinator_source.contains("class_name Main"), "Coordinator is not a renamed Main god object")
	_check(not coordinator_source.contains("func _process("), "Coordinator is not a second frame owner")
	print("composition_root_reduction_test: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		push_error("\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _count_regex(source: String, pattern: String, multiline: bool = false) -> int:
	var regex := RegEx.new()
	regex.compile(("(?m)" if multiline else "") + pattern)
	return regex.search_all(source).size()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
