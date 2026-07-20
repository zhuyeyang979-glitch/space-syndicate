@tool
extends Node
class_name MenuLifecycleApplicationFlowController

## Scene-owned application shell lifecycle. It owns only menu presentation,
## pause/resume coordination, and root-lobby application actions. Gameplay
## state, simulation timing, page snapshots, and save data remain in their
## authoritative owners.

const ROOT_LOBBY_SCENE := preload("res://scenes/ui/MenuRootLobby.tscn")
const PAUSE_SUMMARY_SCENE := preload("res://scenes/ui/PauseMenuSummaryBoard.tscn")

@export var menu_overlay_path: NodePath
@export var coordinator_path: NodePath
@export var world_session_state_path: NodePath
@export var application_flow_port_path: NodePath
@export var codex_navigation_owner_path: NodePath
@export var game_screen_path: NodePath
@export var open_root_on_ready := true

var _root_open_count := 0
var _pause_open_count := 0
var _requested_shell_count := 0
var _page_prepare_count := 0
var _close_count := 0
var _load_request_count := 0
var _load_run_button: Button
var _last_shell_kind: StringName = &""


func _ready() -> void:
	if open_root_on_ready and not Engine.is_editor_hint():
		call_deferred("open_root_menu")


func prepare_application_page(_action_id: StringName) -> void:
	_page_prepare_count += 1
	_pause_for_application_surface()


func open_root_menu() -> bool:
	if not _present_shell(
		"太空辛迪加｜星球赌桌",
		"秘密建城 · 匿名出牌 · 怪兽赌局\n控制区域，推进GDP，接受公开审计。",
		_has_active_table() and not _session_finished(),
		true,
		false
	):
		return false
	_attach_root_lobby()
	_root_open_count += 1
	_last_shell_kind = &"root"
	return true


func open_pause_menu() -> bool:
	if not _has_active_table():
		return open_root_menu()
	if not _present_shell(
		"暂停菜单",
		"游戏已暂停。继续游戏，或查看局势、经济、情报、图鉴和规则。",
		not _session_finished(),
		true,
		false
	):
		return false
	_attach_pause_summary()
	_pause_open_count += 1
	_last_shell_kind = &"pause"
	return true


func present_requested_shell(title: String, summary: String, can_continue: bool) -> bool:
	if title.strip_edges().is_empty() or summary.strip_edges().is_empty():
		return false
	if not _present_shell(title, summary, can_continue, false, false):
		return false
	_requested_shell_count += 1
	_last_shell_kind = &"requested"
	return true


func close_to_table() -> bool:
	var overlay := _menu_overlay()
	if overlay == null:
		return false
	if not _has_active_table():
		return open_root_menu()
	overlay.visible = false
	overlay.set_body_text("", false)
	overlay.clear_preview()
	if not _session_finished():
		var coordinator := _coordinator()
		if coordinator != null:
			coordinator.resume_session()
	_request_full_refresh()
	_close_count += 1
	_last_shell_kind = &"table"
	return true


func is_menu_visible() -> bool:
	var overlay := _menu_overlay()
	return overlay != null and overlay.visible


func handle_key_request(keycode: Key) -> bool:
	match keycode:
		KEY_ESCAPE:
			if is_menu_visible():
				close_to_table()
			else:
				var screen := _game_screen()
				if screen != null:
					screen.request_pause_menu()
			return true
		KEY_ENTER:
			if is_menu_visible():
				close_to_table()
				return true
		KEY_SPACE:
			if is_menu_visible():
				close_to_table()
			else:
				toggle_table_pause()
			return true
	return false


func toggle_table_pause() -> bool:
	var coordinator := _coordinator()
	if coordinator == null or coordinator.session_is_finished():
		return false
	if coordinator.session_is_paused():
		coordinator.resume_session()
	else:
		coordinator.pause_session()
	_request_full_refresh()
	return true


func debug_snapshot() -> Dictionary:
	return {
		"controller_id": "menu_lifecycle_application_flow_controller_v1",
		"root_open_count": _root_open_count,
		"pause_open_count": _pause_open_count,
		"requested_shell_count": _requested_shell_count,
		"page_prepare_count": _page_prepare_count,
		"close_count": _close_count,
		"load_request_count": _load_request_count,
		"last_shell_kind": String(_last_shell_kind),
		"menu_visible": is_menu_visible(),
		"owns_gameplay_state": false,
		"owns_world_clock": false,
		"owns_page_snapshots": false,
		"owns_save_data": false,
		"references_main": false,
	}


func _present_shell(title: String, body: String, can_continue: bool, show_main_actions: bool, compact_page: bool) -> bool:
	var overlay := _menu_overlay()
	if overlay == null:
		return false
	_pause_for_application_surface()
	_load_run_button = null
	var root_table_menu := show_main_actions and title == "太空辛迪加｜星球赌桌"
	overlay.present_menu_shell({
		"title": title,
		"body": body,
		"context": _context_text(title, show_main_actions),
		"context_visible": not root_table_menu and not compact_page,
		"hint": _hint_text(title, show_main_actions),
		"hint_visible": not root_table_menu and not compact_page,
		"continue_disabled": not can_continue,
		"continue_visible": can_continue and show_main_actions and not root_table_menu,
		"back_visible": not show_main_actions,
		"nav_visible": not root_table_menu,
		"run_save_visible": show_main_actions,
		"root_table_menu": root_table_menu,
		"compact_page": compact_page,
		"quick_nav": _quick_nav_entries(),
		"quick_nav_active_id": _quick_nav_active_key(title),
		"quick_nav_visible": not compact_page and title not in ["太空辛迪加｜星球赌桌", "暂停菜单"],
	})
	if show_main_actions:
		_refresh_run_save_state()
	overlay.refresh_current_layout()
	return true


func _pause_for_application_surface() -> void:
	var coordinator := _coordinator()
	if coordinator != null:
		coordinator.pause_session()
	var navigation := _codex_navigation_owner()
	if navigation != null:
		navigation.set_catalog_mode("")


func _attach_root_lobby() -> void:
	var overlay := _menu_overlay()
	if overlay == null:
		return
	overlay.clear_preview()
	var host := overlay.get_preview_host()
	if host == null:
		return
	host.visible = true
	var lobby := ROOT_LOBBY_SCENE.instantiate() as SpaceSyndicateMenuRootLobby
	if lobby == null:
		return
	host.add_child(lobby)
	lobby.action_requested.connect(_on_root_lobby_action_requested)
	lobby.setup_requested.connect(_submit_application_action.bind("setup"))
	lobby.rules_requested.connect(_submit_application_action.bind("rules"))
	lobby.compendium_requested.connect(_submit_application_action.bind("compendium"))
	lobby.set_lobby(_root_lobby_snapshot())
	_load_run_button = lobby.get_load_run_button()
	_refresh_run_save_state()


func _attach_pause_summary() -> void:
	var overlay := _menu_overlay()
	if overlay == null:
		return
	overlay.clear_preview()
	var host := overlay.get_preview_host()
	if host == null:
		return
	host.visible = true
	var board := PAUSE_SUMMARY_SCENE.instantiate() as Control
	if board != null:
		host.add_child(board)


func _on_root_lobby_action_requested(action_id: String) -> void:
	match action_id:
		"continue":
			close_to_table()
		"load_run":
			_load_run_from_menu()
		"quit":
			get_tree().quit()


func _submit_application_action(action_id: String) -> void:
	var port := _application_flow_port()
	if port != null:
		port.submit_action(action_id)


func _load_run_from_menu() -> void:
	var coordinator := _coordinator()
	if coordinator == null:
		return
	_load_request_count += 1
	var result := coordinator.request_run_load("")
	if bool(result.get("ok", false)) and bool(result.get("applied", false)) and int(result.get("error_code", ERR_INVALID_DATA)) == OK:
		coordinator.record_legacy_viewer_feedback("已读取保存局面。")
		open_root_menu()
	else:
		var error_code := int(result.get("error_code", ERR_INVALID_DATA))
		var detail := str(result.get("summary", result.get("reason_code", error_string(error_code))))
		coordinator.record_legacy_viewer_feedback("局面读取失败：%s" % detail)
		_request_full_refresh()
	_refresh_run_save_state()


func _refresh_run_save_state() -> void:
	var overlay := _menu_overlay()
	var coordinator := _coordinator()
	if overlay == null or coordinator == null:
		return
	var inspection := coordinator.inspect_run_save("")
	var has_save := bool(inspection.get("ok", false)) and bool(inspection.get("applied", false))
	if _load_run_button != null:
		_load_run_button.disabled = not has_save
	overlay.set_run_save_summary(str(inspection.get("summary", "存档：运行时恢复服务不可用。")))


func _request_full_refresh() -> void:
	var coordinator := _coordinator()
	if coordinator != null:
		coordinator.request_table_presentation_refresh(&"full", &"application_menu_state_changed")


func _has_active_table() -> bool:
	var world := _world_session_state()
	return world != null and not world.players.is_empty()


func _session_finished() -> bool:
	var coordinator := _coordinator()
	return coordinator == null or coordinator.session_is_finished()


func _root_lobby_snapshot() -> Dictionary:
	var can_continue := _has_active_table() and not _session_finished()
	return {
		"accent": Color("#f59e0b"),
		"tooltip": "星球赌桌大厅：保存、开局、继续和资料库入口。",
		"title": "SPACE SYNDICATE",
		"title_tooltip": "主菜单保留开新一桌、继续牌桌、资料库和游戏规则。",
		"status": "星球赌桌｜控区、GDP与公开审计",
		"status_tooltip": "终局按现金排名。",
		"planet_mark": "◎",
		"planet_title": "星球赌桌大厅",
		"planet_hint": "建城｜怪兽｜下注｜推理",
		"chip_rail_tooltip": "首屏只保留开桌前必须知道的桌面身份。",
		"table_line": "选择你的下一步",
		"table_tooltip": "主菜单只显示当前可用的正常游戏入口。",
		"columns": 1,
		"chips": [
			{"text": "席位 3-8｜真人对 AI", "accent": Color("#bfdbfe"), "tooltip": "真人玩家对2-7个电脑对手。"},
			{"text": "开局 怪兽｜先压上桌", "accent": Color("#fda4af"), "tooltip": "新局在开局准备里选择起始怪兽。"},
			{"text": "牌轨 匿名｜亮牌不亮人", "accent": Color("#c084fc"), "tooltip": "出牌公开，牌主隐藏。"},
		],
		"actions": [
			{"id": "new_run", "kicker": "01｜开桌", "label": "开始新局", "detail": "先设置席位、AI、角色与起始怪兽牌", "accent": Color("#22c55e"), "featured": true},
			{"id": "compendium", "kicker": "02｜资料", "label": "资料库", "detail": "图鉴、卡牌、商品、区域", "accent": Color("#f472b6")},
		],
		"utilities": [
			{"id": "continue", "label": "继续牌桌" if can_continue else "暂无牌桌", "tooltip": "回到当前星球" if can_continue else "先开新一桌。", "accent": Color("#22c55e"), "disabled": not can_continue},
			{"id": "rules", "label": "游戏规则", "accent": Color("#93c5fd")},
			{"id": "load_run", "label": "读取局面", "accent": Color("#94a3b8")},
			{"id": "quit", "label": "退出游戏", "accent": Color("#fb7185")},
		],
	}


func _quick_nav_entries() -> Array:
	return [
		{"id": "setup", "label": "开局", "tooltip": "进入开局配置。", "accent": Color("#38bdf8")},
		{"id": "standings", "label": "局势", "tooltip": "查看局势排名。", "accent": Color("#facc15")},
		{"id": "economy", "label": "经济", "tooltip": "查看经济总览。", "accent": Color("#4ade80")},
		{"id": "intel", "label": "情报", "tooltip": "查看情报档案。", "accent": Color("#c084fc")},
		{"id": "rules", "label": "规则", "tooltip": "查看当前规则。", "accent": Color("#93c5fd")},
		{"id": "compendium", "label": "图鉴", "tooltip": "查看资料库。", "accent": Color("#f472b6")},
	]


func _quick_nav_active_key(title: String) -> String:
	match title:
		"开局准备": return "setup"
		"局势排名", "终局结算": return "standings"
		"经济总览": return "economy"
		"情报档案": return "intel"
		"游戏规则": return "rules"
		"图鉴", "角色图鉴", "怪兽生态档案", "卡牌图鉴", "商品图鉴", "区域图鉴": return "compendium"
	return ""


func _context_text(title: String, show_main_actions: bool) -> String:
	if show_main_actions and title == "太空辛迪加｜星球赌桌":
		return ""
	if show_main_actions and title == "暂停菜单":
		return "暂停｜继续、局势、资料、保存"
	return "%s｜返回回上级" % title


func _hint_text(title: String, show_main_actions: bool) -> String:
	if show_main_actions and title == "太空辛迪加｜星球赌桌":
		return ""
	if show_main_actions and title == "暂停菜单":
		return "暂停菜单｜继续、复查局势、查资料或保存。"
	return "只显示本页操作。"


func _menu_overlay() -> SpaceSyndicateMenuOverlay:
	return get_node_or_null(menu_overlay_path) as SpaceSyndicateMenuOverlay if not menu_overlay_path.is_empty() else null


func _coordinator() -> GameRuntimeCoordinator:
	return get_node_or_null(coordinator_path) as GameRuntimeCoordinator if not coordinator_path.is_empty() else null


func _world_session_state() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState if not world_session_state_path.is_empty() else null


func _application_flow_port() -> ApplicationFlowPort:
	return get_node_or_null(application_flow_port_path) as ApplicationFlowPort if not application_flow_port_path.is_empty() else null


func _codex_navigation_owner() -> CodexNavigationRuntimeController:
	return get_node_or_null(codex_navigation_owner_path) as CodexNavigationRuntimeController if not codex_navigation_owner_path.is_empty() else null


func _game_screen() -> SpaceSyndicateGameScreen:
	return get_node_or_null(game_screen_path) as SpaceSyndicateGameScreen if not game_screen_path.is_empty() else null
