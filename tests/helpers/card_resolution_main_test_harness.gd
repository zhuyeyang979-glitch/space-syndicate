extends RefCounted
class_name CardResolutionMainTestHarness

const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const CONTROLLER_SCENE_PATH := "res://scenes/runtime/CardResolutionRuntimeController.tscn"
const CONTROLLER_NODE_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionRuntimeController"
const RULESET_BRIDGE_SCENE_PATH := "res://scenes/runtime/RulesetRuntimeBridge.tscn"
const RULESET_BRIDGE_NODE_PATH := "RuntimeServices/RulesetRuntimeBridge"
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const COORDINATOR_NODE_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"


func create_main() -> Control:
	var main_script := load(MAIN_SCRIPT_PATH) as Script
	var ruleset_bridge_scene := load(RULESET_BRIDGE_SCENE_PATH) as PackedScene
	var coordinator_scene := load(COORDINATOR_SCENE_PATH) as PackedScene
	if main_script == null or ruleset_bridge_scene == null or coordinator_scene == null:
		return null
	var main := main_script.new() as Control
	if main == null:
		return null
	main.name = "Main"
	var runtime_services := Node.new()
	runtime_services.name = "RuntimeServices"
	main.add_child(runtime_services)
	var ruleset_bridge := ruleset_bridge_scene.instantiate() as Node
	if ruleset_bridge == null:
		main.free()
		return null
	ruleset_bridge.name = "RulesetRuntimeBridge"
	runtime_services.add_child(ruleset_bridge)
	var controller_host := Node.new()
	controller_host.name = "RuntimeControllerHost"
	runtime_services.add_child(controller_host)
	var coordinator := coordinator_scene.instantiate() as Node
	if coordinator == null:
		main.free()
		return null
	coordinator.name = "GameRuntimeCoordinator"
	controller_host.add_child(coordinator)
	main.call("_bind_ruleset_runtime_bridge")
	main.call("_bind_game_runtime_coordinator")
	main.call("_bind_card_resolution_runtime_controller")
	return main


func controller_for(main: Node) -> Node:
	return main.get_node_or_null(CONTROLLER_NODE_PATH) if main != null else null


func ruleset_bridge_for(main: Node) -> Node:
	return main.get_node_or_null(RULESET_BRIDGE_NODE_PATH) if main != null else null


func coordinator_for(main: Node) -> Node:
	return main.get_node_or_null(COORDINATOR_NODE_PATH) if main != null else null
