@tool
extends Node
class_name MenuLifecycleApplicationFlowController

## Scene-owned application shell lifecycle. It owns only menu presentation,
## pause/resume coordination, and root-lobby application actions. Gameplay
## state, simulation timing, page snapshots, and save data remain in their
## authoritative owners.

const ROOT_LOBBY_SCENE := preload("res://scenes/ui/MenuRootLobby.tscn")
const PAUSE_SUMMARY_SCENE := preload("res://scenes/ui/PauseMenuSummaryBoard.tscn")
const COMMERCIAL_CREDITS_SCENE := preload("res://scenes/ui/CommercialCreditsSurface.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/CommercialSettingsSurface.tscn")
const RULES_BOARD_SCENE := preload("res://scenes/ui/RulesQuickReferenceBoard.tscn")
const RULES_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/rules_quick_reference_snapshot_v06.gd")
const COMPENDIUM_HUB_SNAPSHOT := preload("res://scripts/viewmodels/compendium_hub_snapshot.gd")
const PRESENTATION_WINDOW_MODES := ["windowed", "fullscreen"]
const PRESENTATION_RESOLUTIONS := ["1366x768", "1600x960", "1920x1080"]
const PRESENTATION_LANGUAGES := ["zh-Hans", "en"]
const DEFAULT_PRESENTATION_SETTINGS := {
	"master_volume": 1.0,
	"music_volume": 0.75,
	"sfx_volume": 0.85,
	"window_mode": "windowed",
	"resolution": "1600x960",
	"language": "zh-Hans",
	"reduced_motion": false,
	"screen_shake": true,
	"tooltip_delay_ms": 420,
}

signal new_game_requested
signal presentation_settings_changed(snapshot: Dictionary)

@export var menu_overlay_path: NodePath
@export var coordinator_path: NodePath
@export var world_session_state_path: NodePath
@export var application_flow_port_path: NodePath
@export var codex_navigation_owner_path: NodePath
@export var game_screen_path: NodePath
@export var v075_application_flow_path: NodePath
@export var open_root_on_ready := true

var _root_open_count := 0
var _pause_open_count := 0
var _requested_shell_count := 0
var _page_prepare_count := 0
var _close_count := 0
var _load_request_count := 0
var _load_run_button: Button
var _last_shell_kind: StringName = &""
var _v075_saved_pace_multiplier := 1
var _v075_pause_depth := 0
var _settings_surface: Control
var _presentation_settings_snapshot: Dictionary = (
	DEFAULT_PRESENTATION_SETTINGS.duplicate(true)
)
var _presentation_settings_revision := 1
var _presentation_settings_change_count := 0
var _presentation_settings_rejection_count := 0
var _presentation_settings_surface_load_count := 0
var _last_presentation_settings_reason := "session_defaults"
var _menu_input_response_count := 0
var _menu_input_response_last_ms := 0.0
var _menu_input_response_max_ms := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_propagate_presentation_settings_to_game_screen")
	if open_root_on_ready:
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
		else:
			_resume_v075_pacing()
	_request_full_refresh()
	_close_count += 1
	_last_shell_kind = &"table"
	return true


func is_menu_visible() -> bool:
	var overlay := _menu_overlay()
	return overlay != null and overlay.visible


func get_presentation_settings_snapshot() -> Dictionary:
	"""Return the session-only presentation settings owned by this controller."""
	return _presentation_settings_snapshot.duplicate(true)


func handle_key_request(keycode: Key) -> bool:
	match keycode:
		KEY_ESCAPE:
			if is_menu_visible():
				close_to_table()
			else:
				var screen := _game_screen()
				if screen != null and screen.has_method("request_pause_menu"):
					screen.call("request_pause_menu")
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


func handle_application_intent(intent: Dictionary) -> void:
	"""Release the shell before a real embedded New Game intent reaches Flow.

	The menu remains the single presentation owner.  This bridge only changes
	which presentation surface receives input; it never submits or rewrites the
	authoritative intent.
	"""
	if str(intent.get("intent_kind", "")) != "new_game.start":
		return
	if is_menu_visible():
		close_to_embedded_new_game()


func toggle_table_pause() -> bool:
	var coordinator := _coordinator()
	if coordinator == null:
		var flow := _v075_application_flow()
		if flow == null or _session_finished():
			return false
		if _v075_pause_depth > 0:
			_resume_v075_pacing()
		else:
			_pause_v075_pacing()
		return true
	if coordinator.session_is_finished():
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
		"v075_application_flow_bound": _v075_application_flow() != null,
		"v075_pause_depth": _v075_pause_depth,
		"settings_surface_reachable": is_instance_valid(_settings_surface),
		"presentation_settings": get_presentation_settings_snapshot(),
		"presentation_settings_field_count": (
			_presentation_settings_snapshot.size()
		),
		"presentation_settings_revision": _presentation_settings_revision,
		"presentation_settings_change_count": (
			_presentation_settings_change_count
		),
		"presentation_settings_rejection_count": (
			_presentation_settings_rejection_count
		),
		"presentation_settings_surface_load_count": (
			_presentation_settings_surface_load_count
		),
		"last_presentation_settings_reason": (
			_last_presentation_settings_reason
		),
		"menu_input_response_count": _menu_input_response_count,
		"menu_input_response_last_ms": _menu_input_response_last_ms,
		"menu_input_response_max_ms": _menu_input_response_max_ms,
		"presentation_settings_owner_count": 1,
		"presentation_settings_session_only": true,
		"instant_test_mode_production_ui_reachable": false,
		"single_menu_owner": true,
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
	else:
		if _v075_pause_depth == 0:
			_pause_v075_pacing()
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
	lobby.setup_requested.connect(_on_root_setup_requested)
	lobby.rules_requested.connect(_on_root_rules_requested)
	lobby.compendium_requested.connect(_on_root_compendium_requested)
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
	var started_usec := Time.get_ticks_usec()
	match action_id:
		"continue":
			close_to_table()
		"load_run":
			_load_run_from_menu()
		"credits":
			_open_credits()
		"settings":
			_open_settings()
		"rules":
			_on_root_rules_requested()
		"compendium":
			_on_root_compendium_requested()
		"setup":
			_on_root_setup_requested()
		"quit":
			get_tree().quit()
	_record_menu_input_response(started_usec)


func _record_menu_input_response(started_usec: int) -> void:
	var elapsed_ms := maxf(
		0.0,
		float(Time.get_ticks_usec() - started_usec) / 1000.0
	)
	_menu_input_response_count += 1
	_menu_input_response_last_ms = elapsed_ms
	_menu_input_response_max_ms = maxf(
		_menu_input_response_max_ms,
		elapsed_ms
	)
	var screen := _game_screen()
	if (
		screen != null
		and screen.has_method("record_presentation_input_response")
	):
		screen.call(
			"record_presentation_input_response",
			"menu",
			elapsed_ms
		)


func _on_root_setup_requested() -> void:
	if _application_flow_port() != null:
		_submit_application_action("setup")
		return
	# Candidate 5 keeps the already-proven embedded New Game surface as the
	# setup owner.  The shell only closes itself and hands input back to it.
	new_game_requested.emit()
	close_to_embedded_new_game()


func _on_root_rules_requested() -> void:
	if _application_flow_port() != null:
		_submit_application_action("rules")
		return
	_open_static_rules()


func _on_root_compendium_requested() -> void:
	if _application_flow_port() != null:
		_submit_application_action("compendium")
		return
	_open_static_compendium()


func _submit_application_action(action_id: String) -> void:
	var port := _application_flow_port()
	if port != null:
		port.submit_action(action_id)


func _open_credits() -> void:
	if not _present_shell("Credits", "第三方素材、许可证、音乐与字体。", false, false, true):
		return
	var overlay := _menu_overlay()
	if overlay == null:
		return
	overlay.clear_preview()
	var host := overlay.get_preview_host()
	if host == null:
		return
	host.visible = true
	var credits := COMMERCIAL_CREDITS_SCENE.instantiate() as Control
	if credits != null:
		host.add_child(credits)
	_last_shell_kind = &"credits"


func _load_run_from_menu() -> void:
	var coordinator := _coordinator()
	if coordinator == null:
		_load_request_count += 1
		var overlay := _menu_overlay()
		if overlay != null:
			overlay.set_run_save_summary("读取局面：当前 Alpha 0.7 为 New Game Only，暂无可用存档。")
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
	if overlay == null:
		return
	if coordinator == null:
		if _load_run_button != null:
			_load_run_button.disabled = true
		overlay.set_run_save_summary("存档：当前 Alpha 0.7 为 New Game Only，Continue 保持 Disabled。")
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


func close_to_embedded_new_game() -> void:
	var overlay := _menu_overlay()
	if overlay != null:
		overlay.visible = false
		overlay.clear_preview()
	_resume_v075_pacing()
	var screen := _game_screen()
	if screen == null:
		return
	var start_overlay := screen.get_node_or_null("OverlayLayer/StartOverlay") as Control
	if start_overlay != null:
		start_overlay.visible = true


func _open_static_rules() -> void:
	if not _present_shell("游戏规则", "当前牌桌规则速览。", false, false, false):
		return
	var overlay := _menu_overlay()
	if overlay == null:
		return
	var host := overlay.get_preview_host()
	if host == null:
		return
	overlay.clear_preview()
	host.visible = true
	var board := RULES_BOARD_SCENE.instantiate() as Control
	if board == null or not board.has_method("set_board"):
		return
	host.add_child(board)
	board.call("set_board", RULES_SNAPSHOT_SCRIPT.compose(_available_width(overlay)))
	_last_shell_kind = &"rules"


func _open_static_compendium() -> void:
	if not _present_shell("资料库", "角色、卡牌、商品、区域与怪兽生态。", false, false, false):
		return
	var overlay := _menu_overlay()
	if overlay == null or not overlay.has_method("present_codex_page"):
		return
	var page := {
		"mode": "compendium",
		"view": "browser",
		"hub": COMPENDIUM_HUB_SNAPSHOT.compose(_available_width(overlay)),
		"navigation": {"back_visible": true, "back_text": "返回大厅"},
	}
	if overlay.call("present_codex_page", page):
		_last_shell_kind = &"compendium"


func _open_settings() -> void:
	if not _present_shell("设置", "调整声音、窗口、语言和可访问性。", false, false, true):
		return
	var overlay := _menu_overlay()
	if overlay == null:
		return
	overlay.clear_preview()
	var host := overlay.get_preview_host()
	if host == null:
		return
	host.visible = true
	_settings_surface = SETTINGS_SCENE.instantiate() as Control
	if _settings_surface != null:
		if _settings_surface.has_method("load_settings_snapshot"):
			var loaded := _settings_surface.call(
				"load_settings_snapshot",
				get_presentation_settings_snapshot()
			) as Dictionary
			if bool(loaded.get("accepted", false)):
				_presentation_settings_surface_load_count += 1
			else:
				_presentation_settings_rejection_count += 1
				_last_presentation_settings_reason = str(loaded.get(
					"reason_code",
					"presentation_settings_surface_load_rejected"
				))
		var callback := Callable(
			self,
			"_on_commercial_settings_changed"
		)
		if (
			_settings_surface.has_signal("settings_changed")
			and not _settings_surface.is_connected(
				"settings_changed",
				callback
			)
		):
			_settings_surface.connect("settings_changed", callback)
		host.add_child(_settings_surface)
	_last_shell_kind = &"settings"


func _on_commercial_settings_changed(snapshot: Dictionary) -> void:
	if snapshot.has("instant_test_mode"):
		_presentation_settings_rejection_count += 1
		_last_presentation_settings_reason = (
			"instant_test_mode_production_unreachable"
		)
		return
	_presentation_settings_snapshot = _normalized_presentation_settings(
		snapshot,
		_presentation_settings_snapshot
	)
	_presentation_settings_revision += 1
	_presentation_settings_change_count += 1
	_last_presentation_settings_reason = "presentation_settings_applied"
	_propagate_presentation_settings_to_game_screen()
	presentation_settings_changed.emit(
		get_presentation_settings_snapshot()
	)


func _propagate_presentation_settings_to_game_screen() -> bool:
	var screen := _game_screen()
	if screen == null or not screen.has_method("apply_presentation_settings"):
		return false
	screen.call(
		"apply_presentation_settings",
		get_presentation_settings_snapshot()
	)
	return true


func _normalized_presentation_settings(
	source: Dictionary,
	fallback: Dictionary
) -> Dictionary:
	var normalized := DEFAULT_PRESENTATION_SETTINGS.duplicate(true)
	for key_variant in DEFAULT_PRESENTATION_SETTINGS.keys():
		var key := str(key_variant)
		if fallback.has(key):
			normalized[key] = fallback.get(key)
	normalized["master_volume"] = _normalized_presentation_float(
		source,
		"master_volume",
		float(normalized.get("master_volume", 1.0))
	)
	normalized["music_volume"] = _normalized_presentation_float(
		source,
		"music_volume",
		float(normalized.get("music_volume", 0.75))
	)
	normalized["sfx_volume"] = _normalized_presentation_float(
		source,
		"sfx_volume",
		float(normalized.get("sfx_volume", 0.85))
	)
	normalized["window_mode"] = _normalized_presentation_string(
		source,
		"window_mode",
		str(normalized.get("window_mode", "windowed")),
		PRESENTATION_WINDOW_MODES
	)
	normalized["resolution"] = _normalized_presentation_string(
		source,
		"resolution",
		str(normalized.get("resolution", "1600x960")),
		PRESENTATION_RESOLUTIONS
	)
	normalized["language"] = _normalized_presentation_string(
		source,
		"language",
		str(normalized.get("language", "zh-Hans")),
		PRESENTATION_LANGUAGES
	)
	normalized["reduced_motion"] = _normalized_presentation_bool(
		source,
		"reduced_motion",
		bool(normalized.get("reduced_motion", false))
	)
	normalized["screen_shake"] = _normalized_presentation_bool(
		source,
		"screen_shake",
		bool(normalized.get("screen_shake", true))
	)
	var tooltip_value: Variant = source.get(
		"tooltip_delay_ms",
		source.get("tooltip_delay", normalized.get("tooltip_delay_ms", 420))
	)
	if typeof(tooltip_value) in [TYPE_INT, TYPE_FLOAT]:
		normalized["tooltip_delay_ms"] = clampi(
			int(tooltip_value),
			0,
			1200
		)
	return normalized


func _normalized_presentation_float(
	source: Dictionary,
	key: String,
	fallback: float
) -> float:
	var value: Variant = source.get(key, fallback)
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	return clampf(float(value), 0.0, 1.0)


func _normalized_presentation_bool(
	source: Dictionary,
	key: String,
	fallback: bool
) -> bool:
	var value: Variant = source.get(key, fallback)
	return bool(value) if typeof(value) == TYPE_BOOL else fallback


func _normalized_presentation_string(
	source: Dictionary,
	key: String,
	fallback: String,
	allowed: Array
) -> String:
	var value: Variant = source.get(key, fallback)
	if typeof(value) != TYPE_STRING:
		return fallback
	var normalized := str(value)
	return normalized if allowed.has(normalized) else fallback


func _available_width(overlay: Node) -> float:
	if overlay != null and overlay.has_method("available_content_width"):
		return float(overlay.call("available_content_width"))
	return 640.0


func _pause_v075_pacing() -> void:
	var flow := _v075_application_flow()
	if flow == null or not flow.has_method("issue_intent") or not flow.has_method("submit_intent"):
		return
	if _v075_pause_depth == 0 and flow.has_method("pacing_snapshot"):
		_v075_saved_pace_multiplier = int((flow.call("pacing_snapshot") as Dictionary).get("effective_multiplier", 1))
		if _v075_saved_pace_multiplier < 1:
			_v075_saved_pace_multiplier = 1
	var intent := flow.call("issue_intent", "ui.pacing.set", {"multiplier": 0}) as Dictionary
	flow.call("submit_intent", intent)
	_v075_pause_depth += 1


func _resume_v075_pacing() -> void:
	var flow := _v075_application_flow()
	if flow == null or not flow.has_method("issue_intent") or not flow.has_method("submit_intent"):
		return
	if _v075_pause_depth > 0:
		_v075_pause_depth -= 1
	if _v075_pause_depth > 0:
		return
	var intent := flow.call("issue_intent", "ui.pacing.set", {"multiplier": _v075_saved_pace_multiplier}) as Dictionary
	flow.call("submit_intent", intent)


func _v075_application_flow() -> Node:
	if v075_application_flow_path.is_empty():
		return null
	return get_node_or_null(v075_application_flow_path)


func _has_active_table() -> bool:
	var world := _world_session_state()
	if world != null:
		return not world.players.is_empty()
	var flow := _v075_application_flow()
	if flow != null and flow.has_method("local_snapshot"):
		return bool((flow.call("local_snapshot") as Dictionary).get("match_started", false))
	return false


func _session_finished() -> bool:
	var coordinator := _coordinator()
	if coordinator != null:
		return coordinator.session_is_finished()
	var flow := _v075_application_flow()
	if flow != null and flow.has_method("human_decision_snapshot"):
		return bool((flow.call("pacing_snapshot") as Dictionary).get("human_decision_reason_code", "") == "match_terminal") \
			or bool((flow.call("local_snapshot") as Dictionary).get("terminal", false))
	return true


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
			{"id": "settings", "label": "设置", "accent": Color("#a78bfa")},
			{"id": "load_run", "label": "读取局面", "accent": Color("#94a3b8")},
			{"id": "credits", "label": "Credits", "accent": Color("#35d0c5")},
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


func _game_screen() -> Node:
	# The current production V075 screen is a separate Control lineage from the
	# historical SpaceSyndicateGameScreen.  Resolve the configured composition
	# node without narrowing it to the retired class, then use guarded public
	# methods at each presentation-only call site.
	return (
		get_node_or_null(game_screen_path)
		if not game_screen_path.is_empty()
		else null
	)
