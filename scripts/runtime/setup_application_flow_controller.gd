extends Node
class_name SetupApplicationFlowController

const SETUP_PAGE_SCENE := preload("res://scenes/ui/NewGameSetupPage.tscn")

@export var menu_overlay_path: NodePath
@export var draft_service_path: NodePath
@export var query_port_path: NodePath
@export var command_port_path: NodePath
@export var transaction_coordinator_path: NodePath
@export var game_session_path: NodePath
@export var menu_lifecycle_path: NodePath

var _page: SpaceSyndicateNewGameSetupPage
var _command_sequence := 0
var _start_sequence := 0
var _open_count := 0
var _query_count := 0
var _page_apply_count := 0
var _command_count := 0
var _start_count := 0


func open_setup() -> bool:
	if not _dependencies_ready():
		return false
	_open_count += 1
	_menu_overlay().present_menu_shell({
		"title": "开局准备",
		"context": "新会话草案",
		"hint": "角色公开；首召怪兽独立选择且召唤自愿。",
		"body": "",
		"clear_preview": true,
		"continue_visible": false,
		"back_visible": false,
		"quick_nav_visible": false,
	})
	var host := _menu_overlay().get_preview_host()
	if host == null:
		return false
	var candidate := SETUP_PAGE_SCENE.instantiate() as SpaceSyndicateNewGameSetupPage
	if candidate == null:
		return false
	_connect_page(candidate)
	host.add_child(candidate)
	host.visible = true
	_page = candidate
	return _refresh_page()


func debug_snapshot() -> Dictionary:
	return {
		"controller_id": "setup_application_flow_controller_v1",
		"open_count": _open_count,
		"query_count": _query_count,
		"page_apply_count": _page_apply_count,
		"command_count": _command_count,
		"start_count": _start_count,
		"references_main": false,
		"owns_setup_draft": false,
		"owns_gameplay_state": false,
	}


func _connect_page(page: SpaceSyndicateNewGameSetupPage) -> void:
	page.start_requested.connect(_on_start_requested)
	page.back_requested.connect(_on_back_requested)
	page.return_table_requested.connect(_on_return_table_requested)
	page.player_count_requested.connect(_submit_integer_command.bind(SetupDraftCommand.KIND_SET_PLAYER_COUNT, -1))
	page.ai_count_requested.connect(_submit_integer_command.bind(SetupDraftCommand.KIND_SET_AI_PLAYER_COUNT, -1))
	page.challenge_depth_requested.connect(_submit_integer_command.bind(SetupDraftCommand.KIND_SET_CHALLENGE_DEPTH, -1))
	page.role_step_requested.connect(_on_role_step_requested)
	page.role_random_requested.connect(_on_role_random_requested)
	page.starter_monster_step_requested.connect(_on_starter_monster_step_requested)


func _refresh_page() -> bool:
	if _page == null:
		return false
	_query_count += 1
	var snapshot: Dictionary = _query_port().page_snapshot(_menu_overlay().available_content_width())
	if snapshot.is_empty():
		return false
	_page.set_page(snapshot)
	_page_apply_count += 1
	return true


func _submit_integer_command(value: int, kind: StringName, player_index: int) -> void:
	_submit_command(kind, player_index, value)


func _on_role_step_requested(player_index: int, step: int) -> void:
	_submit_command(SetupDraftCommand.KIND_STEP_ROLE, player_index, step)


func _on_role_random_requested(player_index: int) -> void:
	_submit_command(SetupDraftCommand.KIND_SET_ROLE_RANDOM, player_index, 0)


func _on_starter_monster_step_requested(player_index: int, step: int) -> void:
	_submit_command(SetupDraftCommand.KIND_STEP_STARTER_MONSTER, player_index, step)


func _submit_command(kind: StringName, player_index: int, value: int) -> void:
	_command_sequence += 1
	_command_count += 1
	var draft := _draft_service().draft_snapshot()
	var command := SetupDraftCommand.create(
		"setup:%d" % _command_sequence,
		kind,
		int(draft.get("draft_revision", -1)),
		value,
		player_index,
		"setup_ui"
	)
	var receipt := _command_port().submit_command(command)
	if receipt != null and receipt.applied:
		_refresh_page()


func _on_start_requested() -> void:
	_start_sequence += 1
	_start_count += 1
	var draft := _draft_service().draft_snapshot()
	var request := SessionStartRequest.create(
		"setup-start:%d:%d" % [int(draft.get("draft_revision", 0)), _start_sequence],
		draft,
		_game_session().session_start_revision(),
		"setup_ui"
	)
	var receipt := _transaction().start_session(request)
	if receipt != null and receipt.applied:
		_draft_service().reset_to_defaults()
		var lifecycle := _menu_lifecycle()
		if lifecycle != null:
			lifecycle.close_to_table()
		return
	_menu_overlay().set_body_text(_failure_text(receipt), true)
	_refresh_page()


func _on_back_requested() -> void:
	if _game_session().session_state() in ["running", "paused"]:
		_on_return_table_requested()
		return
	_menu_overlay().main_menu_requested.emit()


func _on_return_table_requested() -> void:
	var lifecycle := _menu_lifecycle()
	if lifecycle != null:
		lifecycle.close_to_table()


func _failure_text(receipt: SessionStartReceipt) -> String:
	if receipt == null:
		return "无法开始牌局：事务服务不可用。请保留当前配置后重试。"
	return "无法开始牌局：%s。当前配置和原牌局均已保留。" % receipt.reason_code


func _dependencies_ready() -> bool:
	return _menu_overlay() != null and _draft_service() != null and _query_port() != null and _command_port() != null and _transaction() != null and _game_session() != null


func _menu_overlay() -> SpaceSyndicateMenuOverlay:
	return get_node_or_null(menu_overlay_path) as SpaceSyndicateMenuOverlay


func _draft_service() -> NewGameSetupDraftService:
	return get_node_or_null(draft_service_path) as NewGameSetupDraftService


func _query_port() -> NewGameSetupViewerQueryPort:
	return get_node_or_null(query_port_path) as NewGameSetupViewerQueryPort


func _command_port() -> SetupDraftCommandPort:
	return get_node_or_null(command_port_path) as SetupDraftCommandPort


func _transaction() -> SessionStartTransactionCoordinator:
	return get_node_or_null(transaction_coordinator_path) as SessionStartTransactionCoordinator


func _game_session() -> GameSessionRuntimeController:
	return get_node_or_null(game_session_path) as GameSessionRuntimeController


func _menu_lifecycle() -> MenuLifecycleApplicationFlowController:
	return get_node_or_null(menu_lifecycle_path) as MenuLifecycleApplicationFlowController
