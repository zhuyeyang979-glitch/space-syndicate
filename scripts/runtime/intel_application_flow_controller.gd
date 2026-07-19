extends Node
class_name IntelApplicationFlowController

const BOARD_SCENE := preload("res://scenes/ui/IntelDossierBoard.tscn")

@export var menu_overlay_path: NodePath
@export var application_flow_port_path: NodePath
@export var viewer_query_port_path: NodePath
@export var private_command_port_path: NodePath
@export var compendium_navigation_port_path: NodePath

var _board: SpaceSyndicateIntelDossierBoard
var _focused_history_entry_id := ""
var _focused_region_id := ""
var _command_sequence := 0
var _open_count := 0
var _query_count := 0
var _apply_count := 0
var _command_count := 0
var _command_refresh_count := 0
var _navigation_count := 0


func open_intel() -> void:
	open_application_intent(IntelApplicationIntent.open())


func open_application_intent(intent: IntelApplicationIntent) -> bool:
	if intent == null or not intent.is_valid() or not _dependencies_ready():
		return false
	_focused_history_entry_id = intent.focused_history_entry_id
	_focused_region_id = intent.focused_region_id
	_open_count += 1
	_menu_overlay().present_menu_shell({
		"title": "情报档案",
		"context": "授权本地视角",
		"hint": "",
		"body": "",
		"clear_preview": true,
		"continue_visible": false,
		"back_visible": true,
		"quick_nav_visible": false,
	})
	_board = null
	var snapshot := _query_once(_focused_history_entry_id, _focused_region_id)
	if not bool(snapshot.get("valid", false)):
		_menu_overlay().set_body_text(str(snapshot.get("summary_text", "暂无当前局情报")), true)
		return false
	var host := _menu_overlay().get_preview_host()
	if host == null or not (host is VBoxContainer) or not is_instance_valid(host):
		return false
	var candidate := BOARD_SCENE.instantiate() as SpaceSyndicateIntelDossierBoard
	if candidate == null:
		return false
	candidate.action_requested.connect(_on_board_action_requested)
	host.add_child(candidate)
	_board = candidate
	host.visible = true
	_apply_once(snapshot)
	return true


func debug_snapshot() -> Dictionary:
	return {
		"controller_id": "intel_application_flow_controller_v1",
		"open_count": _open_count,
		"query_count": _query_count,
		"apply_count": _apply_count,
		"command_count": _command_count,
		"command_refresh_count": _command_refresh_count,
		"navigation_count": _navigation_count,
		"scene_owned": true,
		"uses_main": false,
		"scene_lookup_fallback": false,
		"uses_dynamic_method_routing": false,
		"command_refreshes_exactly_once": _command_refresh_count <= _command_count,
	}


func _on_board_action_requested(intent: IntelDossierActionIntent) -> void:
	if intent == null or not intent.is_valid():
		return
	if intent.is_private_command():
		_submit_private_command(intent)
		return
	_navigate(intent)


func _submit_private_command(intent: IntelDossierActionIntent) -> void:
	_command_sequence += 1
	_command_count += 1
	var command := IntelPrivateCommand.create(
		"intel:%d:%d" % [intent.viewer_index, _command_sequence],
		intent.intent_kind,
		intent.viewer_index,
		intent.subject_id,
		intent.expected_owner_revision,
		intent.payload
	)
	var receipt := _private_commands().submit_command(command)
	if receipt == null or not receipt.applied:
		return
	var snapshot := _query_once(_focused_history_entry_id, _focused_region_id)
	if bool(snapshot.get("valid", false)):
		_apply_once(snapshot)
		_command_refresh_count += 1


func _navigate(intent: IntelDossierActionIntent) -> void:
	match intent.intent_kind:
		&"focus_history":
			_focused_history_entry_id = intent.subject_id
			var snapshot := _query_once(_focused_history_entry_id, _focused_region_id)
			if bool(snapshot.get("valid", false)):
				_apply_once(snapshot)
				_navigation_count += 1
		&"open_economy":
			if _application_flow().submit_action("economy"):
				_navigation_count += 1
		&"open_card":
			if _compendium_navigation().request_open("card", "detail", intent.subject_id, -1, "all", 0, "intel", {"origin": "intel"}):
				_navigation_count += 1
		&"open_product":
			if _compendium_navigation().request_open("product", "detail", intent.subject_id, -1, "", 0, "intel", {"origin": "intel"}):
				_navigation_count += 1
		&"open_monster":
			if _compendium_navigation().request_open("monster", "detail", intent.subject_id, -1, "", 0, "intel", {"origin": "intel"}):
				_navigation_count += 1
		&"open_region":
			if _compendium_navigation().request_open("region", "detail", intent.subject_id, -1, "", 0, "intel", {"origin": "intel"}):
				_navigation_count += 1


func _query_once(focused_history_entry_id: String, focused_region_id: String) -> Dictionary:
	_query_count += 1
	return _viewer_query().snapshot_for_authorized_viewer(focused_history_entry_id, focused_region_id)


func _apply_once(snapshot: Dictionary) -> void:
	if _board == null:
		return
	_board.set_dossier(snapshot.get("board", {}) as Dictionary)
	_menu_overlay().set_body_text(str(snapshot.get("summary_text", "")), false)
	_apply_count += 1


func _dependencies_ready() -> bool:
	return _menu_overlay() != null and _application_flow() != null and _viewer_query() != null \
		and _private_commands() != null and _compendium_navigation() != null


func _menu_overlay() -> SpaceSyndicateMenuOverlay:
	return get_node_or_null(menu_overlay_path) as SpaceSyndicateMenuOverlay


func _application_flow() -> ApplicationFlowPort:
	return get_node_or_null(application_flow_port_path) as ApplicationFlowPort


func _viewer_query() -> IntelDossierViewerQueryPort:
	return get_node_or_null(viewer_query_port_path) as IntelDossierViewerQueryPort


func _private_commands() -> IntelPrivateCommandPort:
	return get_node_or_null(private_command_port_path) as IntelPrivateCommandPort


func _compendium_navigation() -> CompendiumNavigationPort:
	return get_node_or_null(compendium_navigation_port_path) as CompendiumNavigationPort
