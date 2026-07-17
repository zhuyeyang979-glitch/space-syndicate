extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const FLOW_SCENE := "res://scenes/runtime/ApplicationFlowPort.tscn"
const MAIN_SOURCE := "res://scripts/" + "main.gd"
var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var main_scene := load(MAIN_SCENE) as PackedScene
	_check(main_scene != null, "formal main scene loads")
	var flow_scene := load(FLOW_SCENE) as PackedScene
	_check(flow_scene != null, "application flow port scene loads")
	if main_scene == null or flow_scene == null:
		_finish()
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	var flow := main.get_node_or_null("RuntimeServices/ApplicationFlowPort")
	_check(flow != null and flow.get_script() != null, "main composes one scene-owned ApplicationFlowPort")
	_check(main.get_node_or_null("RuntimeServices/FinalSettlementRuntimeComposition") != null, "settlement composition remains scene-owned")
	var main_scene_source := FileAccess.get_file_as_string(MAIN_SCENE)
	_check(main_scene_source.contains("ApplicationFlowPort.tscn"), "composition declares typed flow port")
	_check(main_scene_source.contains('to=\"RuntimeServices/ApplicationFlowPort\" method=\"submit_action\"'), "settlement action targets the flow port")
	_check(main_scene_source.contains('to=\"RuntimeServices/ApplicationFlowPort\" method=\"request_menu\"'), "settlement menu request targets the flow port")
	_check(not main_scene_source.contains('from=\"RuntimeServices/FinalSettlementRuntimeComposition\" to=\".\"'), "settlement no longer depends directly on Main")
	var main_source := FileAccess.get_file_as_string(MAIN_SOURCE)
	_check(not main_source.contains("ApplicationFlowPort"), "Main does not discover or own the flow port")
	_check(not main_source.contains("func _process("), "Main remains without a gameplay process owner")
	if flow != null:
		_check(bool(flow.call("submit_action", &"economy")), "allow-listed application action is accepted")
		_check(not bool(flow.call("submit_action", &"private_state")), "non-application action is rejected")
		_check(not bool(flow.call("request_menu", "", "", false)), "empty menu requests fail closed")
	_finish()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("main_dependency_direction_migration_test: PASS %d/%d" % [_checks, _checks])
		quit(0)
	else:
		printerr("main_dependency_direction_migration_test: FAIL %d/%d\n%s" % [_failures.size(), _checks, "\n".join(_failures)])
		quit(1)
