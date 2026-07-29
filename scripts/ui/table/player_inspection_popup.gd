@tool
extends Control
class_name SpaceSyndicatePlayerInspectionPopup

signal close_requested
signal popup_visibility_changed(is_visible: bool, player_id: String, reason: String)
signal navigation_intent_requested(intent: Dictionary)

const PROJECTION_SERVICE := preload(
	"res://scripts/presentation/public_player_roster_projection_service.gd"
)
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

@onready var dismiss_layer: Button = %DismissLayer
@onready var popup_card: PanelContainer = %PopupCard
@onready var accent_strip: ColorRect = %AccentStrip
@onready var avatar_glyph: Label = %AvatarGlyph
@onready var player_name_label: Label = %PlayerName
@onready var role_status_label: Label = %RoleStatus
@onready var close_button: Button = %CloseButton
@onready var assets_summary: Label = %AssetsSummary
@onready var facilities_summary: Label = %FacilitiesSummary
@onready var military_summary: Label = %MilitarySummary
@onready var monster_summary: Label = %MonsterSummary
@onready var navigation_title: Label = %NavigationTitle
@onready var navigation_rows: VBoxContainer = %NavigationRows

var _service: PublicPlayerRosterProjectionService = PROJECTION_SERVICE.new()
var _last_rendered_signature := ""
var _navigation_button_by_key: Dictionary = {}
var _navigation_intent_by_key: Dictionary = {}
var _open_count := 0
var _close_count := 0
var _switch_count := 0
var _same_player_close_count := 0
var _outside_close_count := 0
var _escape_close_count := 0
var _render_count := 0
var _navigation_node_create_count := 0
var _navigation_node_reuse_count := 0
var _navigation_node_retire_count := 0
var _navigation_request_count := 0
var _last_close_reason := "none"


func _ready() -> void:
	dismiss_layer.pressed.connect(func() -> void: close_popup("outside_click"))
	close_button.pressed.connect(func() -> void: close_popup("close_button"))
	visible = false


func bind_viewer(viewer_index: int, authorization_revision: int) -> bool:
	var previous_viewer := _service.bound_viewer_index()
	var previous_authorization := _service.bound_authorization_revision()
	var accepted := _service.bind_viewer(viewer_index, authorization_revision)
	if not accepted:
		clear_projection()
		return false
	if previous_viewer != viewer_index or previous_authorization != authorization_revision:
		clear_projection(false)
	return true


func apply_projection(value: Dictionary) -> bool:
	if not _service.apply_inspection_projection(value):
		return false
	var signature := _service.inspection_signature()
	if signature == _last_rendered_signature:
		return true
	_last_rendered_signature = signature
	_render_projection(_service.inspection_projection())
	return true


func show_projection(value: Dictionary) -> bool:
	var previous_player_id := current_player_id()
	var was_visible := visible
	if not apply_projection(value):
		return false
	var next_player_id := current_player_id()
	if was_visible and previous_player_id != next_player_id:
		_switch_count += 1
	_open_popup("switch_player" if was_visible else "show_player")
	return true


func toggle_projection(value: Dictionary) -> bool:
	var previous_player_id := current_player_id()
	var was_visible := visible
	if not apply_projection(value):
		return false
	var next_player_id := current_player_id()
	if was_visible and previous_player_id == next_player_id:
		_same_player_close_count += 1
		close_popup("same_player")
		return true
	if was_visible and previous_player_id != next_player_id:
		_switch_count += 1
	_open_popup("switch_player" if was_visible else "show_player")
	return true


func close_popup(reason := "external") -> void:
	if not visible:
		return
	visible = false
	_close_count += 1
	_last_close_reason = reason
	if reason == "outside_click":
		_outside_close_count += 1
	elif reason == "escape":
		_escape_close_count += 1
	if get_viewport() != null:
		get_viewport().gui_release_focus()
	close_requested.emit()
	popup_visibility_changed.emit(false, current_player_id(), reason)


func clear_projection(clear_service := true) -> void:
	if clear_service:
		_service.clear_inspection()
	visible = false
	_last_rendered_signature = ""
	_last_close_reason = "cleared"
	player_name_label.text = "公开玩家" if player_name_label != null else ""
	role_status_label.text = "" if role_status_label != null else ""
	_clear_navigation_nodes()


func current_player_id() -> String:
	return str(_service.inspection_projection().get("player_id", ""))


func debug_snapshot() -> Dictionary:
	var service_debug := _service.debug_snapshot()
	var navigation_instance_ids: Array[int] = []
	for key in _navigation_button_by_key.keys():
		var button := _navigation_button_by_key.get(key) as Button
		if is_instance_valid(button):
			navigation_instance_ids.append(button.get_instance_id())
	navigation_instance_ids.sort()
	return {
		"visible": visible,
		"player_id": current_player_id(),
		"viewer_index": int(service_debug.get("viewer_index", -1)),
		"authorization_revision": int(service_debug.get("authorization_revision", 0)),
		"source_revision": int(service_debug.get("inspection_source_revision", -1)),
		"projection_signature": _last_rendered_signature,
		"open_count": _open_count,
		"close_count": _close_count,
		"switch_count": _switch_count,
		"same_player_close_count": _same_player_close_count,
		"outside_close_count": _outside_close_count,
		"escape_close_count": _escape_close_count,
		"last_close_reason": _last_close_reason,
		"render_count": _render_count,
		"navigation_node_count": _navigation_button_by_key.size(),
		"navigation_node_instance_ids": navigation_instance_ids,
		"navigation_node_create_count": _navigation_node_create_count,
		"navigation_node_reuse_count": _navigation_node_reuse_count,
		"navigation_node_retire_count": _navigation_node_retire_count,
		"navigation_request_count": _navigation_request_count,
		"duplicate_projection_count": int(service_debug.get("duplicate_count", 0)),
		"stale_projection_count": int(service_debug.get("stale_count", 0)),
		"conflict_projection_count": int(service_debug.get("conflict_count", 0)),
		"transient_overlay": true,
		"permanent_layout_width": 0,
		"direct_gameplay_mutation_count": 0,
		"rng_draw_count": 0,
		"private_fact_read_count": 0,
	}


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") \
			or (event is InputEventKey \
			and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo \
			and (event as InputEventKey).keycode == KEY_ESCAPE):
		close_popup("escape")
		get_viewport().set_input_as_handled()


func _open_popup(reason: String) -> void:
	var was_visible := visible
	visible = true
	if not was_visible:
		_open_count += 1
	_last_close_reason = "none"
	close_button.grab_focus.call_deferred()
	popup_visibility_changed.emit(true, current_player_id(), reason)


func _render_projection(projection: Dictionary) -> void:
	var display_name := str(projection.get("display_name", ""))
	var role_name := str(projection.get("role_display_name", ""))
	var status := str(projection.get("public_status", ""))
	var accent := _accent_color(str(projection.get("accent", "")))
	player_name_label.text = display_name
	role_status_label.text = "%s · %s" % [role_name, _status_label(status)]
	avatar_glyph.text = display_name.substr(0, 1) if not display_name.is_empty() else "?"
	avatar_glyph.tooltip_text = str(projection.get("avatar_key", ""))
	accent_strip.color = accent
	assets_summary.text = _summary_or_empty(str(
		projection.get("public_assets_summary", "")
	))
	facilities_summary.text = _summary_or_empty(str(
		projection.get("public_facilities_summary", "")
	))
	military_summary.text = _summary_or_empty(str(
		projection.get("public_military_summary", "")
	))
	monster_summary.text = _summary_or_empty(str(
		projection.get("public_monster_summary", "")
	))
	_sync_navigation_nodes(
		projection.get("public_history_links", []) as Array,
		projection.get("allowed_navigation_intents", []) as Array
	)
	_apply_popup_style(accent)
	_render_count += 1


func _sync_navigation_nodes(history_links: Array, allowed_intents: Array) -> void:
	var rows: Array[Dictionary] = []
	for link_variant in history_links:
		var link := link_variant as Dictionary
		rows.append({
			"key": "history:%s" % str(link.get("history_entry_id", "")),
			"label": str(link.get("label", "")),
			"intent": (link.get("navigation_intent", {}) as Dictionary).duplicate(true),
		})
	for intent_variant in allowed_intents:
		var intent := intent_variant as Dictionary
		var intent_key := WIRE.fingerprint(intent)
		rows.append({
			"key": "intent:%s" % intent_key,
			"label": _navigation_label(intent),
			"intent": intent.duplicate(true),
		})
	var desired_keys: Array[String] = []
	for index in range(rows.size()):
		var row := rows[index]
		var key := str(row.get("key", ""))
		if key.is_empty() or desired_keys.has(key):
			continue
		desired_keys.append(key)
		var button := _navigation_button_by_key.get(key) as Button
		if not is_instance_valid(button):
			button = Button.new()
			button.name = "Navigation_%s" % key.sha256_text().left(12)
			button.focus_mode = Control.FOCUS_ALL
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(_emit_navigation.bind(key))
			_navigation_button_by_key[key] = button
			navigation_rows.add_child(button)
			_navigation_node_create_count += 1
		else:
			_navigation_node_reuse_count += 1
		button.text = str(row.get("label", ""))
		button.tooltip_text = button.text
		_navigation_intent_by_key[key] = (row.get("intent", {}) as Dictionary).duplicate(true)
		if button.get_parent() != navigation_rows:
			button.reparent(navigation_rows, false)
		navigation_rows.move_child(button, desired_keys.size() - 1)
	var retired: Array[String] = []
	for key_variant in _navigation_button_by_key.keys():
		var key := str(key_variant)
		if desired_keys.has(key):
			continue
		var button := _navigation_button_by_key.get(key) as Button
		if is_instance_valid(button):
			button.queue_free()
		retired.append(key)
		_navigation_node_retire_count += 1
	for key in retired:
		_navigation_button_by_key.erase(key)
		_navigation_intent_by_key.erase(key)
	navigation_title.visible = not desired_keys.is_empty()
	navigation_rows.visible = not desired_keys.is_empty()


func _clear_navigation_nodes() -> void:
	for node_variant in _navigation_button_by_key.values():
		var node := node_variant as Node
		if is_instance_valid(node):
			node.queue_free()
	_navigation_button_by_key.clear()
	_navigation_intent_by_key.clear()
	if navigation_title != null:
		navigation_title.visible = false
	if navigation_rows != null:
		navigation_rows.visible = false


func _emit_navigation(key: String) -> void:
	var intent_variant: Variant = _navigation_intent_by_key.get(key, {})
	if not (intent_variant is Dictionary) or (intent_variant as Dictionary).is_empty():
		return
	_navigation_request_count += 1
	navigation_intent_requested.emit((intent_variant as Dictionary).duplicate(true))


func _apply_popup_style(accent: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#050c19").lerp(accent, 0.055)
	style.border_color = accent.darkened(0.18)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	popup_card.add_theme_stylebox_override("panel", style)


func _summary_or_empty(value: String) -> String:
	return value if not value.strip_edges().is_empty() else "暂无公开信息"


func _status_label(status: String) -> String:
	return {
		"active": "行动中",
		"ready": "已就绪",
		"waiting": "等待中",
		"eliminated": "已离场",
		"disconnected": "已断开",
	}.get(status, status.replace("_", " "))


func _navigation_label(intent: Dictionary) -> String:
	if intent.has("action_kind"):
		return {
			"region_detail": "打开地区详情",
			"card_browser": "打开卡牌浏览",
			"compendium_hub": "打开百科",
			"card_detail": "打开卡牌详情",
			"pause_menu": "打开菜单",
		}.get(str(intent.get("action_kind", "")), "继续查看")
	return "打开情报记录" if intent.has("kind") else "继续查看"


func _accent_color(value: String) -> Color:
	var normalized := value.strip_edges()
	if Color.html_is_valid(normalized):
		return Color(normalized)
	return {
		"cyan": Color("#22d3ee"),
		"blue": Color("#60a5fa"),
		"violet": Color("#a78bfa"),
		"amber": Color("#fbbf24"),
		"rose": Color("#fb7185"),
		"emerald": Color("#34d399"),
	}.get(normalized.to_lower(), Color("#94a3b8"))
