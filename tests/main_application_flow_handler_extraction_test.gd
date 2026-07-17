extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const MAIN_SOURCE := "res://scripts/" + "main.gd"
const PORT_SCENE := "res://scenes/runtime/ApplicationFlowPort.tscn"
const CONTROLLER_SCENE := "res://scenes/runtime/ApplicationFlowController.tscn"
var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var main_scene := load(MAIN_SCENE) as PackedScene
	_check(main_scene != null, "formal main scene loads")
	_check(load(PORT_SCENE) != null, "ApplicationFlowPort scene loads")
	_check(load(CONTROLLER_SCENE) != null, "ApplicationFlowController scene loads")
	if main_scene == null:
		_finish()
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	var port := main.get_node_or_null("RuntimeServices/ApplicationFlowPort")
	var controller := main.get_node_or_null("RuntimeServices/ApplicationFlowController")
	_check(port != null, "one production ApplicationFlowPort is composed")
	_check(controller != null, "one production ApplicationFlowController is composed")
	_check(main.get_node_or_null("RuntimeServices/ApplicationFlowController") == controller, "controller is not duplicated")
	if port != null and controller != null:
		var controller_debug := controller.call("debug_snapshot") as Dictionary
		_check(not bool(controller_debug.get("owns_gameplay_state", true)), "controller does not own gameplay state")
		_check(not bool(controller_debug.get("owns_runtime_command_pipeline", true)), "controller does not own command pipeline")
		_check(not bool(controller_debug.get("owns_mutation_authority", true)), "controller does not own mutation authority")
		_check(not bool(controller_debug.get("owns_rng", true)), "controller does not own RNG")
		_check(bool(port.call("submit_action", "rules")), "rules action remains allow-listed")
		var opened := int((controller.call("debug_snapshot") as Dictionary).get("rules_open_count", 0))
		_check(opened == 1, "rules action reaches the real ApplicationFlowController")
		_check(not bool(port.call("submit_action", "invalid_action")), "invalid action is rejected")
		_check(not bool(port.call("request_menu", "", "", false)), "empty menu request is rejected")
	var main_scene_source := FileAccess.get_file_as_string(MAIN_SCENE)
	_check(main_scene_source.contains("ApplicationFlowController.tscn"), "main scene explicitly composes the handler")
	_check(main_scene_source.contains('to=\"RuntimeServices/ApplicationFlowController\" method=\"open_rules\"'), "rules port signal targets the handler")
	_check(not main_scene_source.contains('to=\".\" method=\"_open_rules_menu\"'), "production scene has no direct rules-to-Main connection")
	var main_source := FileAccess.get_file_as_string(MAIN_SOURCE)
	_check(not main_source.contains("func _open_rules_menu("), "Main rules handler is physically deleted")
	_check(not main_source.contains("func _populate_rules_summary_cards("), "Main rules population helper is physically deleted")
	_check(not main_source.contains("func _add_rules_quick_reference_board("), "Main rules board builder is physically deleted")
	var controller_source := FileAccess.get_file_as_string("res://scripts/runtime/application_flow_controller.gd")
	_check(not controller_source.contains("/root/" + "Main") and not controller_source.contains("current_scene"), "handler has no Main or current-scene fallback")
	_check(not controller_source.contains("RuntimeCommandPipeline") and not controller_source.contains("SimulationMutationAuthority") and not controller_source.contains("RunRngService"), "handler has no simulation authority dependency")
	_finish()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("main_application_flow_handler_extraction_test: PASS %d/%d" % [_checks, _checks])
		quit(0)
	else:
		printerr("main_application_flow_handler_extraction_test: FAIL %d/%d\n%s" % [_failures.size(), _checks, "\n".join(_failures)])
		quit(1)
