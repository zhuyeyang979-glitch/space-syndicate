@tool
extends Control
class_name V07ContextualTableSurface

signal region_projection_requested(region_index: int)
signal prebound_target_requested(region_index: int)
signal player_inspection_requested(player_id: String)

const MODE_TABLE_MAP := "TABLE_MAP_MODE"
const MODE_REGION_SUPPLY_POPUP := "REGION_SUPPLY_POPUP_MODE"
const MODE_CARD_SUBMISSION := "CARD_SUBMISSION_MODE"
const MODE_CARD_TARGET_SELECTION := "CARD_TARGET_SELECTION_MODE"
const MODE_CARD_RESOLUTION := "CARD_RESOLUTION_MODE"
const MODE_MENU_OR_CODEX := "MENU_OR_CODEX_MODE"

const RESOLUTION_PHASES := [
	"RESOLUTION_ORDER_REVEAL",
	"CARD_RESOLUTION_ACTIVE",
	"CARD_AFTERMATH",
	"BATCH_AFTERMATH",
]

const ROSTER_ROOT_KEYS := ["players"]
const ROSTER_ROW_KEYS := ["player_id", "display_name", "public_status", "public_order_index", "is_viewer", "avatar_key", "accent"]
const CARD_WINDOW_KEYS := ["phase", "window_id", "batch_id", "window_duration_seconds", "remaining_seconds", "status_text"]
const SUBMISSION_PREVIEW_KEYS := ["card_display_name", "target_display_name", "mode_display_name", "quantity", "locked"]
const REGION_ROOT_KEYS := ["region_index", "region_id", "rack_revision", "display_name", "public_status", "availability_text", "cards"]
const REGION_CARD_KEYS := ["card_id", "display_name", "price", "action_text", "detail", "availability"]
const RESOLUTION_KEYS := ["phase", "batch_id", "receipt_id", "batch_label", "completed_count", "total_count", "current_card", "next_card", "remaining_cards", "defense_feedback", "authoritative_result"]
const CARD_DOCK_ROOT_KEYS := ["bound_actions", "normal_cards", "commodity_stacks"]
const CARD_DOCK_ROW_KEYS := ["display_name", "status", "card_semantic_id", "source_kind", "action_class", "level", "base_units"]

@export var apply_reference_fixture_on_ready := false

@onready var roster_grid: GridContainer = %RosterGrid
@onready var roster_count_label: Label = %RosterCountLabel
@onready var map_mode_label: Label = %MapModeLabel
@onready var card_window_panel: PanelContainer = %CardWindowPanel
@onready var card_window_title: Label = %CardWindowTitle
@onready var card_window_timer: Label = %CardWindowTimer
@onready var card_window_status: Label = %CardWindowStatus
@onready var region_popup: PanelContainer = %RegionSupplyPopup
@onready var region_popup_title: Label = %RegionPopupTitle
@onready var region_popup_status: Label = %RegionPopupStatus
@onready var region_popup_cards: VBoxContainer = %RegionPopupCards
@onready var region_popup_close: Button = %RegionPopupClose
@onready var resolution_overlay: PanelContainer = %CardResolutionOverlay
@onready var resolution_title: Label = %ResolutionTitle
@onready var resolution_current: Label = %ResolutionCurrent
@onready var resolution_next: Label = %ResolutionNext
@onready var resolution_queue: Label = %ResolutionQueue
@onready var resolution_result: Label = %ResolutionResult
@onready var resolution_defense: Label = %ResolutionDefense
@onready var bound_action_cards: HFlowContainer = %BoundActionCards
@onready var normal_hand_cards: HFlowContainer = %NormalHandCards
@onready var commodity_cards: HFlowContainer = %CommodityCards
@onready var bound_action_title: Label = %BoundActionTitle
@onready var normal_hand_title: Label = %NormalHandTitle
@onready var commodity_title: Label = %CommodityTitle
@onready var submission_summary: Label = %SubmissionSummary
@onready var reference_planet_stage: Control = $ReferencePlanetStage

var _interaction_mode := MODE_TABLE_MAP
var _roster_apply_count := 0
var _popup_apply_count := 0
var _resolution_apply_count := 0
var _dock_apply_count := 0
var _last_rack_revision := ""
var _last_popup_region_id := ""
var _last_popup_region_index := -1
var _last_resolution_phase := ""
var _gameplay_action_emission_count := 0
var _ignored_gameplay_input_count := 0
var _region_query_request_count := 0
var _prebound_target_request_count := 0
var _window_apply_count := 0
var _submission_preview_apply_count := 0
var _last_window_phase := "CARD_WINDOW_CLOSED"
var _last_submission_locked := false
var _mode_before_popup := MODE_TABLE_MAP
var _planet_map_view: Control
var _last_district_selected_frame := -1
var _popup_blank_close_count := 0
var _popup_same_region_close_count := 0
var _roster_player_ids: Array[String] = []
var _roster_buttons: Array[Button] = []
var _roster_inspection_count := 0
var _last_inspected_player_id := ""
var _viewer_player_id := ""


func _ready() -> void:
	region_popup_close.pressed.connect(close_region_popup)
	set_process_unhandled_key_input(true)
	call_deferred("_connect_planet_map")
	if apply_reference_fixture_on_ready:
		apply_reference_fixture()


func apply_player_roster(projection: Dictionary) -> bool:
	if not _is_exact_projection(projection, ROSTER_ROOT_KEYS):
		return false
	var players: Array = projection.get("players", []) \
		if projection.get("players", []) is Array else []
	if players.size() < 3 or players.size() > 8:
		return false
	if not _rows_use_exact_keys(players, ROSTER_ROW_KEYS):
		return false
	var next_player_ids: Array[String] = []
	var public_order_indexes: Array[int] = []
	var viewer_player_ids: Array[String] = []
	for player_variant in players:
		if not (player_variant is Dictionary):
			return false
		var player := player_variant as Dictionary
		var player_id := str(player.get("player_id", "")).strip_edges()
		if typeof(player.get("public_order_index")) != TYPE_INT:
			return false
		var public_order_index := int(player.get("public_order_index", -1))
		if player_id.is_empty() or player_id in next_player_ids:
			return false
		if public_order_index < 0 or public_order_index in public_order_indexes:
			return false
		if player.has("is_viewer") and typeof(player.get("is_viewer")) != TYPE_BOOL:
			return false
		if bool(player.get("is_viewer", false)):
			viewer_player_ids.append(player_id)
		next_player_ids.append(player_id)
		public_order_indexes.append(public_order_index)
	if viewer_player_ids.size() != 1:
		return false
	_viewer_player_id = viewer_player_ids[0]
	var ordered_players := players.duplicate(true)
	ordered_players.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _roster_sort_key(left) < _roster_sort_key(right)
	)
	next_player_ids.clear()
	for player_variant in ordered_players:
		next_player_ids.append(str((player_variant as Dictionary).get("player_id", "")))
	_clear_children(roster_grid)
	_roster_buttons.clear()
	_roster_player_ids = next_player_ids
	if _last_inspected_player_id not in _roster_player_ids:
		_last_inspected_player_id = ""
	roster_grid.columns = 1 if players.size() <= 4 else 2
	for player_variant in ordered_players:
		var player := player_variant as Dictionary
		var player_id := str(player.get("player_id", ""))
		var row := Button.new()
		row.name = "RosterPlayer_%s" % _safe_node_fragment(player_id)
		row.custom_minimum_size = Vector2(132, 52)
		row.focus_mode = Control.FOCUS_ALL
		row.toggle_mode = true
		row.set_meta("public_player_id", player_id)
		row.set_meta("is_viewer", player_id == _viewer_player_id)
		row.button_pressed = player_id == _last_inspected_player_id
		row.text = "%s%s\n%s" % [
			str(player.get("display_name", "席位")),
			"（你）" if player_id == _viewer_player_id else "",
			str(player.get("public_status", "观察中")),
		]
		if player_id == _viewer_player_id:
			row.self_modulate = Color(0.82, 0.95, 1.0, 1.0)
		row.tooltip_text = "查看 %s 的公开信息" % str(player.get("display_name", "玩家"))
		row.pressed.connect(_on_roster_player_pressed.bind(player_id))
		roster_grid.add_child(row)
		_roster_buttons.append(row)
	_configure_roster_focus_neighbors()
	roster_count_label.text = "%d 席｜%s" % [
		players.size(),
		"一列" if roster_grid.columns == 1 else "两列",
	]
	_roster_apply_count += 1
	return true


func apply_card_window(projection: Dictionary) -> bool:
	if not _is_exact_projection(projection, CARD_WINDOW_KEYS):
		return false
	var phase := str(projection.get("phase", "CARD_WINDOW_CLOSED"))
	var duration := int(projection.get("window_duration_seconds", 30))
	if duration != 30:
		return false
	var seconds := clampi(int(projection.get("remaining_seconds", 0)), 0, 30)
	_last_window_phase = phase
	card_window_panel.visible = phase in [
		"CARD_WINDOW_OPEN",
		"CARD_WINDOW_LOCKING",
		"RESOLUTION_ORDER_BUILD",
	]
	card_window_title.text = "本批次一次性出牌"
	card_window_timer.text = "%02d 秒" % seconds
	card_window_status.text = str(projection.get(
		"status_text",
		"选择卡牌、目标、模式与数量，然后锁定。"
	))
	if phase == "CARD_WINDOW_OPEN":
		set_interaction_mode(MODE_CARD_SUBMISSION)
	elif phase in ["CARD_WINDOW_CLOSED", "BATCH_COMPLETE"] \
			and _interaction_mode not in [MODE_CARD_RESOLUTION, MODE_MENU_OR_CODEX]:
		set_interaction_mode(MODE_TABLE_MAP)
	_window_apply_count += 1
	return true


func apply_submission_preview(projection: Dictionary) -> bool:
	if not _is_exact_projection(projection, SUBMISSION_PREVIEW_KEYS):
		return false
	var card_name := str(projection.get("card_display_name", "")).strip_edges()
	var target_name := str(projection.get("target_display_name", "")).strip_edges()
	if card_name.is_empty() or target_name.is_empty():
		return false
	var mode_name := str(projection.get("mode_display_name", "标准"))
	var quantity := maxi(1, int(projection.get("quantity", 1)))
	_last_submission_locked = bool(projection.get("locked", false))
	submission_summary.text = "%s → %s · %s ×%d｜%s" % [
		card_name,
		target_name,
		mode_name,
		quantity,
		"已锁定" if _last_submission_locked else "待锁定",
	]
	submission_summary.visible = true
	_submission_preview_apply_count += 1
	return true


func set_interaction_mode(mode_id: String) -> bool:
	if mode_id not in [
		MODE_TABLE_MAP,
		MODE_REGION_SUPPLY_POPUP,
		MODE_CARD_SUBMISSION,
		MODE_CARD_TARGET_SELECTION,
		MODE_CARD_RESOLUTION,
		MODE_MENU_OR_CODEX,
	]:
		return false
	_interaction_mode = mode_id
	map_mode_label.text = _mode_label(mode_id)
	if mode_id in [MODE_CARD_TARGET_SELECTION, MODE_CARD_RESOLUTION, MODE_MENU_OR_CODEX]:
		region_popup.visible = false
	if mode_id != MODE_CARD_RESOLUTION and not RESOLUTION_PHASES.has(_last_resolution_phase):
		resolution_overlay.visible = false
	return true


func open_region_popup(projection: Dictionary) -> bool:
	if _interaction_mode not in [MODE_TABLE_MAP, MODE_REGION_SUPPLY_POPUP, MODE_CARD_SUBMISSION] \
			or not _is_exact_projection(projection, REGION_ROOT_KEYS):
		return false
	var region_id := str(projection.get("region_id", "")).strip_edges()
	var region_index := int(projection.get("region_index", -1))
	var rack_revision := str(projection.get("rack_revision", "")).strip_edges()
	if region_index < 0 or region_id.is_empty() or rack_revision.is_empty():
		return false
	var cards: Array = projection.get("cards", []) if projection.get("cards", []) is Array else []
	if not _rows_use_exact_keys(cards, REGION_CARD_KEYS):
		return false
	if _interaction_mode != MODE_REGION_SUPPLY_POPUP:
		_mode_before_popup = _interaction_mode
	_last_popup_region_id = region_id
	_last_popup_region_index = region_index
	_last_rack_revision = rack_revision
	region_popup_title.text = str(projection.get("display_name", region_id))
	region_popup_status.text = "%s｜%s" % [
		str(projection.get("public_status", "公开牌架")),
		str(projection.get("availability_text", "当前状态由权威端口提供")),
	]
	_clear_children(region_popup_cards)
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		var label := Label.new()
		label.text = "%s  ¥%d  · %s" % [
			str(card.get("display_name", "商品牌")),
			maxi(0, int(card.get("price", 0))),
			str(card.get("action_text", "仅浏览")),
		]
		label.tooltip_text = str(card.get("detail", ""))
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		region_popup_cards.add_child(label)
	region_popup.visible = true
	_interaction_mode = MODE_REGION_SUPPLY_POPUP
	map_mode_label.text = _mode_label(_interaction_mode)
	_popup_apply_count += 1
	return true


func close_region_popup() -> void:
	region_popup.visible = false
	_last_popup_region_index = -1
	if _interaction_mode == MODE_REGION_SUPPLY_POPUP:
		_interaction_mode = _mode_before_popup
		map_mode_label.text = _mode_label(_interaction_mode)


func apply_resolution_overlay(projection: Dictionary) -> bool:
	if not _is_exact_projection(projection, RESOLUTION_KEYS):
		return false
	var phase := str(projection.get("phase", ""))
	_last_resolution_phase = phase
	if phase not in RESOLUTION_PHASES:
		resolution_overlay.visible = false
		if phase == "BATCH_COMPLETE" and _interaction_mode == MODE_CARD_RESOLUTION:
			set_interaction_mode(MODE_TABLE_MAP)
		return true
	set_interaction_mode(MODE_CARD_RESOLUTION)
	card_window_panel.visible = false
	submission_summary.visible = false
	resolution_overlay.visible = true
	resolution_title.text = "%s｜%d / %d" % [
		str(projection.get("batch_label", "批次结算")),
		maxi(0, int(projection.get("completed_count", 0))),
		maxi(0, int(projection.get("total_count", 0))),
	]
	resolution_current.text = "当前｜%s" % str(projection.get("current_card", "无"))
	resolution_next.text = "下一张｜%s" % str(projection.get("next_card", "批次收尾"))
	resolution_queue.text = "后续｜%s" % " · ".join(_string_array(projection.get("remaining_cards", [])))
	resolution_defense.text = str(projection.get("defense_feedback", "预绑定目标已重新验证"))
	resolution_result.text = str(projection.get("authoritative_result", "等待权威结果"))
	_resolution_apply_count += 1
	return true


func apply_player_card_dock(projection: Dictionary) -> bool:
	if not _is_exact_projection(projection, CARD_DOCK_ROOT_KEYS):
		return false
	var normal_cards: Array = projection.get("normal_cards", []) \
		if projection.get("normal_cards", []) is Array else []
	var commodity_stacks: Array = projection.get("commodity_stacks", []) \
		if projection.get("commodity_stacks", []) is Array else []
	var bound_actions: Array = projection.get("bound_actions", []) \
		if projection.get("bound_actions", []) is Array else []
	if normal_cards.size() > 5 or commodity_stacks.size() > 5:
		return false
	if not _rows_use_exact_keys(normal_cards, CARD_DOCK_ROW_KEYS) \
			or not _rows_use_exact_keys(commodity_stacks, CARD_DOCK_ROW_KEYS) \
			or not _rows_use_exact_keys(bound_actions, CARD_DOCK_ROW_KEYS):
		return false
	bound_action_title.text = "绑定行动 %d｜不占上限" % bound_actions.size()
	normal_hand_title.text = "普通手牌 %d / 5" % normal_cards.size()
	commodity_title.text = "商品库存 %d / 5" % commodity_stacks.size()
	_apply_card_chips(bound_action_cards, bound_actions, "来源")
	_apply_card_chips(normal_hand_cards, normal_cards, "普通")
	_apply_card_chips(commodity_cards, commodity_stacks, "商品")
	_dock_apply_count += 1
	return true


func debug_snapshot() -> Dictionary:
	var stage_snapshot := _reference_stage_snapshot()
	return {
		"interaction_mode": _interaction_mode,
		"roster_columns": roster_grid.columns,
		"roster_count": roster_grid.get_child_count(),
		"roster_side": "left",
		"roster_player_ids": _roster_player_ids.duplicate(),
		"viewer_player_id": _viewer_player_id,
		"viewer_marker_count": _viewer_marker_count(),
		"roster_focusable_count": _roster_buttons.size(),
		"roster_focus_links_valid": _roster_focus_links_valid(),
		"roster_inspection_count": _roster_inspection_count,
		"last_inspected_player_id": _last_inspected_player_id,
		"inspected_roster_button_count": _inspected_roster_button_count(),
		"reference_player_roster_source_count": 1,
		"region_popup_visible": region_popup.visible,
		"region_popup_region_id": _last_popup_region_id,
		"region_popup_region_index": _last_popup_region_index,
		"rack_revision": _last_rack_revision,
		"card_window_visible": card_window_panel.visible,
		"submission_summary_visible": submission_summary.visible,
		"resolution_overlay_visible": resolution_overlay.visible,
		"resolution_phase": _last_resolution_phase,
		"counter_ui_element_count": 0,
		"gameplay_action_emission_count": _gameplay_action_emission_count,
		"ignored_gameplay_input_count": _ignored_gameplay_input_count,
		"region_query_request_count": _region_query_request_count,
		"prebound_target_request_count": _prebound_target_request_count,
		"window_apply_count": _window_apply_count,
		"submission_preview_apply_count": _submission_preview_apply_count,
		"window_phase": _last_window_phase,
		"submission_locked": _last_submission_locked,
		"planet_map_connected": _planet_map_view != null,
		"reference_planet_stage": bool(stage_snapshot.get("reference_stage", false)),
		"orbit_player_marker_count": int(stage_snapshot.get("positional_marker_count", -1)) \
			+ int(stage_snapshot.get("positional_decoration_count", -1)),
		"orbit_radial_spoke_count": int(stage_snapshot.get("radial_spoke_count", -1)),
		"left_right_seat_layer_count": int(stage_snapshot.get("left_right_layer_count", -1)),
		"legacy_draw_fallback_enabled": bool(stage_snapshot.get("legacy_draw_fallback_enabled", true)),
		"roster_apply_count": _roster_apply_count,
		"popup_apply_count": _popup_apply_count,
		"popup_blank_close_count": _popup_blank_close_count,
		"popup_same_region_close_count": _popup_same_region_close_count,
		"resolution_apply_count": _resolution_apply_count,
		"dock_apply_count": _dock_apply_count,
		"normal_count": normal_hand_cards.get_child_count(),
		"commodity_count": commodity_cards.get_child_count(),
		"bound_action_count": bound_action_cards.get_child_count(),
	}


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and region_popup.visible:
		close_region_popup()
		get_viewport().set_input_as_handled()


func apply_reference_fixture(player_count: int = 6) -> void:
	apply_player_roster({"players": _fixture_players(clampi(player_count, 3, 8))})
	apply_card_window({
		"phase": "CARD_WINDOW_OPEN",
		"window_id": "fixture-window-12",
		"batch_id": "fixture-batch-12",
		"window_duration_seconds": 30,
		"remaining_seconds": 23,
		"status_text": "本轮选择将在窗口锁定后同时公开。",
	})
	apply_submission_preview({
		"card_display_name": "预先部署",
		"target_display_name": "晨曦环带 · 轨道工厂",
		"mode_display_name": "护盾",
		"quantity": 1,
		"locked": true,
	})
	apply_player_card_dock({
		"bound_actions": [
			{"display_name": "陨星守卫｜护盾阵列", "status": "主动行动"},
			{"display_name": "行星防卫军｜拦截网", "status": "被动能力"},
		],
		"normal_cards": [
			{"display_name": "预先部署"},
			{"display_name": "市场干扰"},
			{"display_name": "航线保险"},
		],
		"commodity_stacks": [
			{"display_name": "蓝色商品 L2"},
			{"display_name": "紫色商品 L1"},
		],
	})
	open_region_popup(_reference_region_projection(0))


func begin_prebound_target_selection() -> bool:
	if _last_window_phase != "CARD_WINDOW_OPEN":
		return false
	return set_interaction_mode(MODE_CARD_TARGET_SELECTION)


func request_player_inspection(player_id: String) -> bool:
	var normalized := player_id.strip_edges()
	if normalized.is_empty() or normalized not in _roster_player_ids:
		return false
	_on_roster_player_pressed(normalized)
	return true


func planet_map_view() -> Control:
	return _planet_map_view


func _connect_planet_map() -> void:
	if reference_planet_stage == null \
			or not reference_planet_stage.has_method("get_embedded_map_view"):
		return
	_planet_map_view = reference_planet_stage.call("get_embedded_map_view") as Control
	if _planet_map_view != null and _planet_map_view.has_signal("district_selected") \
			and not _planet_map_view.is_connected(
				"district_selected",
				Callable(self, "_on_planet_district_selected")
			):
		_planet_map_view.connect("district_selected", Callable(self, "_on_planet_district_selected"))
	if _planet_map_view != null and _planet_map_view.has_signal("gui_input") \
			and not _planet_map_view.is_connected(
				"gui_input",
				Callable(self, "_on_planet_map_gui_input")
			):
		_planet_map_view.connect("gui_input", Callable(self, "_on_planet_map_gui_input"))


func _on_roster_player_pressed(player_id: String) -> void:
	if player_id not in _roster_player_ids:
		return
	_last_inspected_player_id = player_id
	for button in _roster_buttons:
		button.button_pressed = str(button.get_meta("public_player_id", "")) == player_id
	_roster_inspection_count += 1
	player_inspection_requested.emit(player_id)


func _on_planet_district_selected(region_index: int) -> void:
	_last_district_selected_frame = Engine.get_process_frames()
	match _interaction_mode:
		MODE_CARD_RESOLUTION, MODE_MENU_OR_CODEX:
			_ignored_gameplay_input_count += 1
		MODE_CARD_TARGET_SELECTION:
			_prebound_target_request_count += 1
			_gameplay_action_emission_count += 1
			prebound_target_requested.emit(region_index)
		MODE_REGION_SUPPLY_POPUP:
			if region_popup.visible and region_index == _last_popup_region_index:
				_popup_same_region_close_count += 1
				close_region_popup()
			else:
				_region_query_request_count += 1
				region_projection_requested.emit(region_index)
		_:
			_region_query_request_count += 1
			region_projection_requested.emit(region_index)


func _on_planet_map_gui_input(event: InputEvent) -> void:
	if not region_popup.visible or _interaction_mode != MODE_REGION_SUPPLY_POPUP:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			call_deferred(
				"_close_region_popup_after_blank_map_click",
				Engine.get_process_frames()
			)


func _close_region_popup_after_blank_map_click(click_frame: int) -> void:
	if region_popup.visible \
			and _interaction_mode == MODE_REGION_SUPPLY_POPUP \
			and _last_district_selected_frame != click_frame:
		_popup_blank_close_count += 1
		close_region_popup()


func _reference_region_projection(region_index: int) -> Dictionary:
	return {
		"region_index": region_index,
		"region_id": "region.%d" % region_index,
		"rack_revision": "fixture-rack-%d-1" % region_index,
		"display_name": "晨曦环带" if region_index == 0 else "远星走廊 %d" % region_index,
		"public_status": "受光｜怪兽压力 +0.5x",
		"availability_text": "当前牌架仅由权威查询投影",
		"cards": [
			{"display_name": "轨道工厂 I", "price": 8, "action_text": "获取报价"},
			{"display_name": "航线保险 I", "price": 5, "action_text": "可购买"},
			{"display_name": "城市升级 I", "price": 6, "action_text": "仅浏览"},
		],
	}


func _fixture_players(count: int) -> Array:
	var result: Array = []
	for index in range(count):
		result.append({
			"player_id": "seat-%d" % index,
			"display_name": "玩家 %d" % (index + 1),
			"public_status": "已锁定" if index % 2 == 0 else "选择中",
			"public_order_index": index,
			"is_viewer": index == count - 1,
		})
	return result


func _reference_stage_snapshot() -> Dictionary:
	if reference_planet_stage == null or not reference_planet_stage.has_method("debug_snapshot"):
		return {}
	var value: Variant = reference_planet_stage.call("debug_snapshot")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _roster_sort_key(player: Dictionary) -> int:
	return int(player.get("public_order_index", -1))


func _safe_node_fragment(value: String) -> String:
	var result := value.validate_node_name().replace(" ", "_")
	return result if not result.is_empty() else "unknown"


func _configure_roster_focus_neighbors() -> void:
	if _roster_buttons.is_empty():
		return
	var columns := maxi(1, roster_grid.columns)
	var last_index := _roster_buttons.size() - 1
	for index in range(_roster_buttons.size()):
		var button := _roster_buttons[index]
		var column := index % columns
		var top_index := index - columns if index >= columns else index
		var bottom_index := index + columns if index + columns <= last_index else index
		var left_index := index - 1 if column > 0 else index
		var right_index := index + 1 \
			if column + 1 < columns and index + 1 <= last_index else index
		button.focus_neighbor_top = button.get_path_to(_roster_buttons[top_index])
		button.focus_neighbor_bottom = button.get_path_to(_roster_buttons[bottom_index])
		button.focus_neighbor_left = button.get_path_to(_roster_buttons[left_index])
		button.focus_neighbor_right = button.get_path_to(_roster_buttons[right_index])
		button.focus_next = button.get_path_to(_roster_buttons[(index + 1) % _roster_buttons.size()])
		button.focus_previous = button.get_path_to(
			_roster_buttons[(index - 1 + _roster_buttons.size()) % _roster_buttons.size()]
		)


func _roster_focus_links_valid() -> bool:
	if _roster_buttons.size() != _roster_player_ids.size() or _roster_buttons.is_empty():
		return false
	for button in _roster_buttons:
		if button == null or button.focus_mode != Control.FOCUS_ALL:
			return false
		for path in [
			button.focus_neighbor_top,
			button.focus_neighbor_bottom,
			button.focus_neighbor_left,
			button.focus_neighbor_right,
			button.focus_next,
			button.focus_previous,
		]:
			if path.is_empty() or not (button.get_node_or_null(path) is Button):
				return false
	return true


func _inspected_roster_button_count() -> int:
	var count := 0
	for button in _roster_buttons:
		if button != null and button.button_pressed:
			count += 1
	return count


func _viewer_marker_count() -> int:
	var count := 0
	for button in _roster_buttons:
		if button != null and bool(button.get_meta("is_viewer", false)):
			count += 1
	return count


func _apply_card_chips(host: HFlowContainer, rows: Array, fallback: String) -> void:
	_clear_children(host)
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		var chip := Button.new()
		chip.text = str(row.get("display_name", fallback))
		chip.tooltip_text = str(row.get("status", "窗口内选择并预绑定目标"))
		chip.disabled = true
		host.add_child(chip)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _mode_label(mode_id: String) -> String:
	match mode_id:
		MODE_TABLE_MAP:
			return "地图模式｜点击地区查看牌架"
		MODE_REGION_SUPPLY_POPUP:
			return "地区牌架｜点击其他地区直接切换"
		MODE_CARD_SUBMISSION:
			return "出牌窗口｜所有选择一次锁定"
		MODE_CARD_TARGET_SELECTION:
			return "目标选择｜地图点击只绑定目标"
		MODE_CARD_RESOLUTION:
			return "连续结算｜不接受游戏行动"
		MODE_MENU_OR_CODEX:
			return "资料页｜只读"
	return mode_id


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value as Array:
			result.append(str(entry))
	return result


func _is_pure_data(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_ARRAY:
			for entry in value as Array:
				if not _is_pure_data(entry):
					return false
			return true
		TYPE_DICTIONARY:
			for key in (value as Dictionary).keys():
				if not (key is String or key is StringName) \
						or not _is_pure_data((value as Dictionary)[key]):
					return false
			return true
	return false


func _is_exact_projection(value: Dictionary, allowed_keys: Array) -> bool:
	if not _is_pure_data(value):
		return false
	for key_variant in value.keys():
		if not (key_variant is String or key_variant is StringName) \
				or str(key_variant) not in allowed_keys:
			return false
	return true


func _rows_use_exact_keys(rows: Array, allowed_keys: Array) -> bool:
	for row_variant in rows:
		if not (row_variant is Dictionary) \
				or not _is_exact_projection(row_variant as Dictionary, allowed_keys):
			return false
	return true
