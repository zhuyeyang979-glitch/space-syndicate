@tool
extends Node
class_name CommoditySushiTrackApplicationFlowController

const SERVICE_SCRIPT := preload("res://scripts/runtime/commodity_sushi_track_runtime_service.gd")
const REQUEST_SCRIPT := preload("res://scripts/runtime/commodity_sushi_track_claim_request.gd")

@export var service_path: NodePath
@export var game_screen_path: NodePath
@export var refresh_port_path: NodePath

var _submit_count := 0
var _success_count := 0
var _failure_count := 0


func handle_claim_request(request: REQUEST_SCRIPT) -> void:
	_submit_count += 1
	var service := get_node_or_null(service_path) as SERVICE_SCRIPT
	var game_screen := get_node_or_null(game_screen_path) as SpaceSyndicateGameScreen
	if service == null or game_screen == null:
		_failure_count += 1
		return
	var result := service.claim(request)
	if bool(result.get("success", false)):
		_success_count += 1
	else:
		_failure_count += 1
	game_screen.apply_commodity_claim_result(result, service.public_snapshot(request.viewer_index))
	if bool(result.get("success", false)):
		var refresh_port := get_node_or_null(refresh_port_path) as TablePresentationRefreshPort
		if refresh_port != null:
			refresh_port.request_immediate(&"full", &"commodity_sushi_claimed")


func debug_snapshot() -> Dictionary:
	return {
		"configured": get_node_or_null(service_path) is SERVICE_SCRIPT \
			and get_node_or_null(game_screen_path) is SpaceSyndicateGameScreen,
		"submit_count": _submit_count,
		"success_count": _success_count,
		"failure_count": _failure_count,
		"references_main": false,
		"owns_belt_state": false,
		"ui_mutates_gameplay": false,
	}
