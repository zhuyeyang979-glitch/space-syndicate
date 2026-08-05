extends Control
class_name V073SampleGameScreen

signal application_intent_requested(intent: Dictionary)
signal playtest_presentation_event(event_type: String, payload: Dictionary)
signal playtest_feedback_submitted(feedback: Dictionary)
signal playtest_feedback_skipped
# MCP_FINALIZE

const RULESET_ID := "v0.7.3"
const PlanetPresentationAdapter := preload(
	"res://scripts/presentation/v073/v073_planet_presentation_adapter_v1.gd"
)
const ResponsiveTableLayout := preload(
	"res://scripts/ui/v073/v073_responsive_table_layout_v2.gd"
)
const UILayoutCollisionAudit := preload(
	"res://scripts/ui/v073/v073_ui_layout_collision_audit_v1.gd"
)
const COLORS := ["life", "energy", "industry", "technology", "commerce", "shipping"]
const COLOR_LABELS := {
	"life": "生命",
	"energy": "能源",
	"industry": "工业",
	"technology": "科技",
	"commerce": "商业",
	"shipping": "航运",
}
const COLOR_VALUES := {
	"life": Color("#52d681"),
	"energy": Color("#f2c14e"),
	"industry": Color("#aeb8c6"),
	"technology": Color("#4cc9f0"),
	"commerce": Color("#d08cf0"),
	"shipping": Color("#46d6b5"),
}
const ICON_PATHS := {
	"life": "res://assets/third_party/commercial/icons/game_icons/normalized/life_64.png",
	"energy": "res://assets/third_party/commercial/icons/game_icons/normalized/energy_64.png",
	"industry": "res://assets/third_party/commercial/icons/game_icons/normalized/industry_64.png",
	"technology": "res://assets/third_party/commercial/icons/game_icons/normalized/technology_64.png",
	"commerce": "res://assets/third_party/commercial/icons/game_icons/normalized/commerce_64.png",
	"shipping": "res://assets/third_party/commercial/icons/game_icons/normalized/shipping_64.png",
}
const COMMODITY_ART_PATHS := [
	"res://assets/art/cards/v06/style_keys/commodity/blue_tide_algae_v01.svg",
	"res://assets/art/cards/v06/style_keys/commodity/deep_sea_fungal_mat_v01.svg",
	"res://assets/art/cards/v06/style_keys/commodity/dream_fragrance_v01.svg",
	"res://assets/art/cards/v06/style_keys/commodity/gravity_ceramic_v01.svg",
	"res://assets/art/cards/v06/style_keys/commodity/living_chip_v01.svg",
	"res://assets/art/cards/v06/style_keys/commodity/photosynthetic_gel_v01.svg",
	"res://assets/art/cards/v06/style_keys/commodity/ring_crystal_battery_v02.svg",
	"res://assets/art/cards/v06/style_keys/commodity/solar_scale_v01.svg",
	"res://assets/art/cards/v06/style_keys/commodity/star_whale_canning_v01.svg",
	"res://assets/art/cards/v06/style_keys/commodity/storm_pearl_v01.svg",
	"res://assets/art/cards/v06/style_keys/commodity/titanium_shell_clam_v01.svg",
	"res://assets/art/cards/v06/style_keys/commodity/trajectory_ink_v01.svg",
]
const FACTORY_ART_PATH := (
	"res://assets/third_party/commercial/materials/ambientcg/"
	+ "MetalPlates013/MetalPlates013_1K-JPG_Color.jpg"
)
const MARKET_ART_PATH := (
	"res://assets/third_party/commercial/materials/ambientcg/"
	+ "PaintedMetal007/PaintedMetal007_1K-JPG_Color.jpg"
)

@onready var _ruleset_label: Label = %RulesetLabel
@onready var _phase_label: Label = %PhaseLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _timer_progress: ProgressBar = %TimerProgress
@onready var _save_notice: Label = %SaveNotice
@onready var _new_game_button: Button = %NewGameButton
@onready var _roster_grid: GridContainer = %RosterGrid
@onready var _track_meta: Label = %TrackMeta
@onready var _track_rail: HBoxContainer = %TrackRail
@onready var _increase_option: OptionButton = %IncreaseOption
@onready var _decrease_option: OptionButton = %DecreaseOption
@onready var _apply_stance_button: Button = %ApplyStanceButton
@onready var _planet_board: Control = %PlanetBoard
@onready var _target_rail: HBoxContainer = %TargetRail
@onready var _asset_rail: HBoxContainer = %AssetRail
@onready var _deck_label: Label = %DeckLabel
@onready var _discard_label: Label = %DiscardLabel
@onready var _commodity_label: Label = %CommodityLabel
@onready var _special_label: Label = %SpecialLabel
@onready var _hand_rail: HBoxContainer = %HandRail
@onready var _queue_rail: VBoxContainer = %QueueRail
@onready var _merge_button: Button = %MergeButton
@onready var _finish_button: Button = %FinishMaintenanceButton
@onready var _lock_button: Button = %LockButton
@onready var _accelerate_button: Button = %AccelerateButton
@onready var _action_status: Label = %ActionStatus
@onready var _history_label: RichTextLabel = %HistoryLabel
@onready var _start_overlay: Control = %StartOverlay
@onready var _region_popup: Control = %RegionPopup
@onready var _region_popup_title: Label = %RegionPopupTitle
@onready var _region_popup_body: RichTextLabel = %RegionPopupBody
@onready var _settlement_overlay: Control = %SettlementOverlay
@onready var _settlement_title: Label = %SettlementTitle
@onready var _settlement_standings: VBoxContainer = %SettlementStandings
@onready var _toast_label: Label = %ToastLabel
@onready var _seed_input: LineEdit = %SeedInput
@onready var _coach_marks: Node = %V073PlaytestCoachMarks
@onready var _marker_panel: Node = %V073PlaytestMarkerPanel
@onready var _questionnaire: Node = %V073PlaytestQuestionnaire

var acceptance_state: Dictionary = {}
var _flow: Node
var _telemetry: Node
var _snapshot: Dictionary = {}
var _capabilities: Dictionary = {}
var _planet_presentation_adapter := PlanetPresentationAdapter.new()
var _layout_profile: Dictionary = {}
var _selected_region_id := ""
var _map_presentation_apply_count := 0
var _map_region_selection_count := 0
var _map_target_binding_count := 0
var _map_illegal_target_reject_count := 0
var _map_region_popup_opened := false
var _planet_rotation_used := false
var _planet_zoom_used := false
var _selected_card_id := ""
var _selected_card_definition_id := ""
var _selected_card_color := ""
var _selected_card_type := ""
var _submission_remaining := 30.0
var _texture_cache: Dictionary = {}
var _toast_tween: Tween
var _runtime_frame_count := 0
var _normal_card_render_count := 0
var _normal_card_art_count := 0
var _commodity_card_render_count := 0
var _commodity_card_art_count := 0
var _last_public_ui_surface := "table"
var _last_settlement_id := ""
var _pending_track_event: Dictionary = {}
var _pending_target_event: Dictionary = {}
var _interaction_counts := {
	"new_game": 0,
	"card_selected": 0,
	"target_bound": 0,
	"queue_reordered": 0,
	"track_acquired": 0,
	"merge_requested": 0,
	"submission_locked": 0,
	"maintenance_finished": 0,
	"region_popup": 0,
	"accelerated": 0,
	"settlement_presented": 0,
}


func _ready() -> void:
	set_process(true)
	_connect_static_controls()
	_populate_stance_options()
	_configure_planet_shell()
	_connect_planet_interactions()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_region_popup_body.add_theme_constant_override("line_separation", 5)
	_start_overlay.visible = true
	_region_popup.visible = false
	_settlement_overlay.visible = false
	_accelerate_button.visible = (
		OS.get_environment("SPACE_SYNDICATE_SANITY_MODE") == "1"
	)
	_seed_input.text = "900626424"
	_bind_playtest_surfaces()
	_update_acceptance_state()


func bind_application_flow(
	flow: Node,
	identity: Dictionary,
	capabilities: Dictionary
) -> void:
	_flow = flow
	_capabilities = capabilities.duplicate(true)
	_ruleset_label.text = "%s · NEW GAME ONLY" % str(
		identity.get("ruleset_id", RULESET_ID)
	)
	_save_notice.text = str(identity.get(
		"save_notice",
		"V0.7.3样品暂不支持中途保存"
	))
	_update_acceptance_state()


func bind_playtest_telemetry(telemetry: Node) -> void:
	_telemetry = telemetry
	if _telemetry != null and _telemetry.has_signal("export_status_changed"):
		_telemetry.connect("export_status_changed", _on_export_status_changed)
	_update_acceptance_state()


func apply_snapshot(snapshot: Dictionary) -> void:
	if str(snapshot.get("ruleset_id", "")) != RULESET_ID:
		present_runtime_fault({
			"reason_code": "production_projection_ruleset_mismatch",
		})
		return
	_snapshot = snapshot.duplicate(true)
	_submission_remaining = float(snapshot.get(
		"submission_seconds_remaining",
		0.0
	))
	_refresh_phase()
	_refresh_roster()
	_refresh_track()
	_refresh_assets()
	_refresh_hand()
	_refresh_queue()
	_refresh_targets()
	_refresh_planet_presentation()
	_refresh_history()
	_refresh_playtest_context()
	_update_acceptance_state()


func apply_receipt(receipt: Dictionary) -> void:
	var accepted := bool(receipt.get("accepted", false))
	var intent_kind := str(receipt.get("intent_kind", ""))
	var reason_code := str(receipt.get("reason_code", "unknown"))
	if accepted and _interaction_counts.has(intent_kind):
		_interaction_counts[intent_kind] = int(
			_interaction_counts.get(intent_kind, 0)
		) + 1
	match intent_kind:
		"new_game.start":
			if accepted:
				_start_overlay.visible = false
				_interaction_counts["new_game"] += 1
				_coach_marks.call("restart_from_settings")
		"track.acquire":
			if accepted:
				_interaction_counts["track_acquired"] += 1
				var track_type := "track_commodity_claimed" \
					if str(_pending_track_event.get("card_kind", "")) == "commodity_card" \
					else "track_normal_card_purchased"
				_emit_playtest_event(track_type, _pending_track_event)
			_pending_track_event = {}
		"card.queue":
			if accepted:
				_interaction_counts["target_bound"] += 1
				_pending_target_event["public_reason_code"] = reason_code
				_emit_playtest_event("target_bound", _pending_target_event)
				_pending_target_event = {}
				_clear_selected_card()
		"queue.reorder":
			if accepted:
				_interaction_counts["queue_reordered"] += 1
		"merge.normal":
			if accepted:
				_interaction_counts["merge_requested"] += 1
		"submission.lock":
			if accepted:
				_interaction_counts["submission_locked"] += 1
		"maintenance.finish":
			if accepted:
				_interaction_counts["maintenance_finished"] += 1
		"sample.accelerate":
			if accepted:
				_interaction_counts["accelerated"] += 1
	_show_toast(reason_code, accepted)
	_action_status.text = reason_code
	_refresh_playtest_context()
	_update_acceptance_state()


func present_final_settlement(settlement: Dictionary) -> void:
	_settlement_overlay.visible = true
	_last_settlement_id = str(settlement.get("settlement_id", "settlement"))
	_settlement_title.text = "FINAL SETTLEMENT · %s" % str(
		settlement.get("winner_player_id", "")
	)
	_clear_children(_settlement_standings)
	for row_variant in settlement.get("standings", []) as Array:
		var row := row_variant as Dictionary
		var label := Label.new()
		label.text = "%d   %s   设施 %d   资产 %d" % [
			int(row.get("rank", 0)),
			str(row.get("display_name", "")),
			int(row.get("facility_count", 0)),
			int(row.get("asset_total", 0)),
		]
		label.add_theme_font_size_override("font_size", 18)
		_settlement_standings.add_child(label)
	_interaction_counts["settlement_presented"] += 1
	_update_acceptance_state()
	_refresh_playtest_context()


func present_runtime_fault(receipt: Dictionary) -> void:
	_action_status.text = "RUNTIME FAULT · %s" % str(
		receipt.get("reason_code", "unknown")
	)
	_show_toast(_action_status.text, false)
	_update_acceptance_state()


func _process(delta: float) -> void:
	_runtime_frame_count += 1
	if str(_snapshot.get("phase", "")) == "submission":
		_submission_remaining = maxf(0.0, _submission_remaining - delta)
		_timer_label.text = "%02d s" % int(ceil(_submission_remaining))
		_timer_progress.value = _submission_remaining
	_update_acceptance_state()


func _connect_static_controls() -> void:
	_new_game_button.pressed.connect(func() -> void:
		_start_overlay.visible = true
		_refresh_playtest_context()
	)
	for count in [3, 4, 6, 8]:
		var button := get_node("%%Start%dButton" % count) as Button
		button.pressed.connect(_request_new_game.bind(count))
	%StartOverlayClose.pressed.connect(func() -> void:
		_start_overlay.visible = false
		_refresh_playtest_context()
	)
	%RegionPopupClose.pressed.connect(func() -> void:
		_region_popup.visible = false
		_emit_playtest_event("ui_backtracked", {"ui_surface": "region_popup"})
		_refresh_playtest_context()
	)
	%SettlementClose.pressed.connect(_acknowledge_final_settlement)
	%GuideButton.pressed.connect(func() -> void:
		_coach_marks.call("restart_from_settings")
	)
	%RandomSeedButton.pressed.connect(_set_random_seed)
	_apply_stance_button.pressed.connect(_request_stance)
	_merge_button.pressed.connect(_request_merge)
	_finish_button.pressed.connect(func() -> void:
		_emit_intent("maintenance.finish")
	)
	_lock_button.pressed.connect(func() -> void:
		_emit_intent("submission.lock")
	)
	_accelerate_button.pressed.connect(func() -> void:
		_emit_intent("sample.accelerate", {"max_steps": 2000})
	)


func _populate_stance_options() -> void:
	for color_id in COLORS:
		_increase_option.add_item(str(COLOR_LABELS.get(color_id, color_id)))
		_increase_option.set_item_metadata(
			_increase_option.item_count - 1,
			color_id
		)
		_decrease_option.add_item(str(COLOR_LABELS.get(color_id, color_id)))
		_decrease_option.set_item_metadata(
			_decrease_option.item_count - 1,
			color_id
		)
	_decrease_option.select(1)


func _configure_planet_shell() -> void:
	if _planet_board.has_method("set_board_state"):
		_planet_board.call("set_board_state", {
			"title": "V0.7.3 行星运营图",
			"hint": "公开设施 · 日照效率 · 地区态势",
			"left_rail": {
				"title": "公开态势",
				"lines": ["设施槽位", "怪兽与军队", "公开历史"],
			},
			"right_rail": {"hidden": true},
			"flow_compass": {
				"title": "行动阶段",
				"steps": ["选牌", "选区", "排序", "锁定", "结算"],
				"next_label": "当前：选择手牌",
			},
		})


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var player_count := maxi(4, (_snapshot.get("roster", []) as Array).size())
	_layout_profile = ResponsiveTableLayout.profile_for(viewport_size, player_count)
	var mode := str(_layout_profile.get("mode", ResponsiveTableLayout.REGULAR_DESKTOP))
	var compact := mode == ResponsiveTableLayout.COMPACT_DESKTOP
	var root_margin := $RootMargin as MarginContainer
	var shell := $RootMargin/Shell as VBoxContainer
	var header := $RootMargin/Shell/Header as Control
	var track_panel := $RootMargin/Shell/TrackPanel as Control
	var table_area := $RootMargin/Shell/TableArea as Control
	var roster_panel := $RootMargin/Shell/TableArea/RosterPanel as Control
	var target_panel := $RootMargin/Shell/TargetPanel as Control
	var dock_panel := $RootMargin/Shell/DockPanel as Control
	var queue_panel := $RootMargin/Shell/DockPanel/DockMargin/DockRows/DockBody/QueuePanel as Control
	var stage := _planet_board.get_node_or_null("PlanetRows/PlanetStageViewport") as Control
	var outer_margin := 6.0 if compact else 10.0
	root_margin.offset_top = outer_margin
	root_margin.offset_bottom = -outer_margin
	shell.add_theme_constant_override("separation", int(_layout_profile.get("shell_separation", 5)))
	header.custom_minimum_size.y = float(_layout_profile.get("header_height", 82.0))
	track_panel.custom_minimum_size.y = float(_layout_profile.get("track_height", 128.0))
	table_area.custom_minimum_size.y = float(_layout_profile.get("table_height", 430.0))
	target_panel.custom_minimum_size.y = float(_layout_profile.get("target_height", 38.0))
	dock_panel.custom_minimum_size.y = float(_layout_profile.get("dock_height", 198.0))
	roster_panel.custom_minimum_size.x = float(_layout_profile.get("roster_width", 190.0))
	queue_panel.custom_minimum_size.x = 258.0 if compact else (340.0 if mode == ResponsiveTableLayout.WIDE_DESKTOP else 300.0)
	_planet_board.custom_minimum_size = Vector2(0.0, float(_layout_profile.get("table_height", 430.0)))
	if stage != null:
		stage.custom_minimum_size.y = float(_layout_profile.get("planet_stage_height", 340.0))
		stage.update_minimum_size()
	_planet_board.call("set_layout_mode", mode)
	_track_rail.add_theme_constant_override("separation", 4 if compact else 8)
	_target_rail.add_theme_constant_override("separation", 3 if compact else 5)
	_save_notice.custom_minimum_size = Vector2(0.0, 22.0)
	_save_notice.autowrap_mode = TextServer.AUTOWRAP_OFF
	_save_notice.text = "样品暂不支持保存 / 继续" if compact else "V0.7.3样品暂不支持中途保存"
	_save_notice.tooltip_text = "V0.7.3样品暂不支持中途保存"
	%SaveButton.custom_minimum_size.x = 48.0 if compact else 58.0
	%ContinueButton.custom_minimum_size.x = 48.0 if compact else 58.0
	if _marker_panel != null and _marker_panel.has_method("apply_safe_layout"):
		_marker_panel.call("apply_safe_layout", viewport_size, mode, outer_margin + 48.0)
	_planet_board.update_minimum_size()
	shell.queue_sort()


func _connect_planet_interactions() -> void:
	var bindings := {
		"district_selected": Callable(self, "_on_planet_district_selected"),
		"district_double_clicked": Callable(self, "_on_planet_district_double_clicked"),
		"map_background_clicked": Callable(self, "_on_planet_map_background_clicked"),
		"camera_interacted": Callable(self, "_on_planet_camera_interacted"),
	}
	for signal_name in bindings:
		var callback: Callable = bindings[signal_name]
		if _planet_board.has_signal(signal_name) and not _planet_board.is_connected(signal_name, callback):
			_planet_board.connect(signal_name, callback)


func _refresh_planet_presentation() -> void:
	if not bool(_snapshot.get("match_started", false)):
		return
	var presentation_seed := int(_snapshot.get("presentation_match_seed", 0))
	if presentation_seed <= 0:
		return
	var viewer_index := 0
	for row_variant in _snapshot.get("roster", []) as Array:
		var row := row_variant as Dictionary
		if bool(row.get("is_local_player", false)):
			viewer_index = int(row.get("public_order_index", 0))
			break
	var authorization_revision := _planet_presentation_adapter.authorization_revision(_snapshot)
	_planet_board.call("bind_presentation_viewer", viewer_index, authorization_revision)
	var map_snapshot: MapPresentationSnapshot = _planet_presentation_adapter.build_map_snapshot(
		presentation_seed,
		_snapshot,
		_selected_card_id,
		_selected_region_id
	)
	if map_snapshot == null:
		return
	_map_presentation_apply_count = int(_planet_board.call("apply_map_presentation", map_snapshot))


func _on_planet_district_selected(index: int) -> void:
	var region_id := _planet_presentation_adapter.region_id_for_index(
		int(_snapshot.get("presentation_match_seed", 0)),
		index
	)
	if region_id.is_empty():
		return
	_map_region_selection_count += 1
	_handle_region_selection(region_id, "planet_map")


func _on_planet_district_double_clicked(_index: int) -> void:
	_last_public_ui_surface = "planet_map"


func _on_planet_map_background_clicked() -> void:
	_selected_region_id = ""
	_last_public_ui_surface = "planet_map"
	_refresh_planet_presentation()


func _on_planet_camera_interacted(kind: String) -> void:
	_last_public_ui_surface = "planet_map"
	if kind == "drag":
		_planet_rotation_used = true
	elif kind in ["wheel", "touch_zoom"]:
		_planet_zoom_used = true


func _handle_region_selection(region_id: String, source_surface: String) -> void:
	_selected_region_id = region_id
	_last_public_ui_surface = source_surface
	_refresh_planet_presentation()
	if _selected_card_id.is_empty():
		_map_region_popup_opened = _map_region_popup_opened or source_surface == "planet_map"
		_show_region_popup(region_id)
		return
	var option := _legal_option_for_selected(region_id)
	if option.is_empty():
		if source_surface == "planet_map":
			_map_illegal_target_reject_count += 1
		_show_toast("该地区不是当前卡牌的合法目标", false)
		return
	if source_surface == "planet_map":
		_map_target_binding_count += 1
	_pending_target_event = {
		"card_definition_id": _selected_card_definition_id,
		"color_id": _selected_card_color,
		"region_id": region_id,
		"facility_type": str(option.get("facility_type", "")),
		"facility_action_mode": str(option.get("facility_action_mode", "")),
		"asset_cost": int(option.get("asset_cost", 0)),
		"source_surface": source_surface,
	}
	_emit_intent("card.queue", {
		"card_instance_id": _selected_card_id,
		"target_slot_id": str(option.get("target_slot_id", "")),
	})


func _request_new_game(player_count: int) -> void:
	var seed_value := 900626424
	if _seed_input.text.strip_edges().is_valid_int():
		seed_value = int(_seed_input.text.strip_edges())
	_emit_intent("new_game.start", {
		"player_count": player_count,
		"seed": seed_value,
	})


func _request_stance() -> void:
	var increase := str(_increase_option.get_item_metadata(
		_increase_option.selected
	))
	var decrease := str(_decrease_option.get_item_metadata(
		_decrease_option.selected
	))
	if increase == decrease:
		_show_toast("轨道升降颜色必须不同", false)
		return
	_emit_intent("track.set_stance", {
		"increase_color": increase,
		"decrease_color": decrease,
	})


func _request_merge() -> void:
	var facts := (
		_snapshot.get("personal_dbg", {}) as Dictionary
	).get("facts", {}) as Dictionary
	var pairs := facts.get("eligible_merge_pairs", []) as Array
	if pairs.is_empty():
		_show_toast("当前没有可合成组合", false)
		return
	var pair := pairs[0] as Array
	if pair.size() != 2:
		return
	_emit_intent("merge.normal", {
		"left_instance_id": str(pair[0]),
		"right_instance_id": str(pair[1]),
	})


func _emit_intent(
	intent_kind: String,
	parameters: Dictionary = {}
) -> void:
	if _flow == null:
		_show_toast("application_flow_unbound", false)
		return
	var intent_variant: Variant = _flow.call(
		"issue_intent",
		intent_kind,
		parameters
	)
	if not (intent_variant is Dictionary):
		_show_toast("typed_intent_build_failed", false)
		return
	application_intent_requested.emit(
		(intent_variant as Dictionary).duplicate(true)
	)


func _refresh_phase() -> void:
	var phase := str(_snapshot.get("phase", "idle"))
	var phase_names := {
		"idle": "待命",
		"submission": "提交窗口",
		"resolving": "匿名轮转结算",
		"maintenance": "手牌维护",
		"settled": "终局结算",
		"failed": "运行故障",
	}
	_phase_label.text = str(phase_names.get(phase, phase))
	_timer_progress.max_value = 30.0
	_timer_progress.value = _submission_remaining
	_timer_label.text = "%02d s" % int(ceil(_submission_remaining))
	_lock_button.disabled = (
		phase != "submission"
		or bool(_snapshot.get("submission_locked", false))
	)
	_finish_button.disabled = phase != "maintenance"
	_merge_button.disabled = phase != "maintenance"
	_apply_stance_button.disabled = phase != "submission"
	_accelerate_button.disabled = phase in ["idle", "settled", "failed"]


func _refresh_roster() -> void:
	_clear_children(_roster_grid)
	var roster := _snapshot.get("roster", []) as Array
	_roster_grid.columns = 2 if roster.size() > 4 else 1
	for row_variant in roster:
		var row := row_variant as Dictionary
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(
			92,
			44 if str(_layout_profile.get("mode", "")) == ResponsiveTableLayout.COMPACT_DESKTOP else 54
		)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#172236")
		style.border_color = Color("#49c9b5") 			if bool(row.get("is_local_player", false)) 			else Color("#53647e")
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.text = "%s
%s · 设施 %d" % [
			str(row.get("display_name", "")),
			"AI" if bool(row.get("is_ai", false)) else "LOCAL",
			int(row.get("facility_count", 0)),
		]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		panel.add_child(label)
		_roster_grid.add_child(panel)


func _refresh_track() -> void:
	_clear_children(_track_rail)
	_normal_card_render_count = 0
	_normal_card_art_count = 0
	_commodity_card_render_count = 0
	_commodity_card_art_count = 0
	var track := _snapshot.get("unified_track", {}) as Dictionary
	var public_facts := track.get("public_facts", {}) as Dictionary
	var private_facts := track.get("viewer_private_facts", {}) as Dictionary
	_track_meta.text = "公开轨道 %d · 60%% 普通 / 40%% 商品 · replacement %d" % [
		int(public_facts.get("track_revision", 0)),
		int(public_facts.get("scroll_sequence", 0)),
	]
	for item_variant in private_facts.get("own_segment_items", []) as Array:
		var item := item_variant as Dictionary
		var card := V073SampleCardButton.new()
		var kind := str(item.get("card_kind", ""))
		var color_id := str(item.get("primary_color", "industry"))
		var title := "商品 · %s" % COLOR_LABELS.get(color_id, color_id)
		var badge := "COMMODITY"
		var meta := "库存 0/5"
		if kind == "normal_card":
			title = "%s · %s" % [
				_card_type_label(str(item.get("card_definition_id", ""))),
				COLOR_LABELS.get(color_id, color_id),
			]
			badge = "NORMAL · L1"
			meta = "成本 %d · 进入弃牌" % int(item.get("primary_asset_cost", 1))
		var art := _card_art(item)
		card.configure(item, title, meta, art, COLOR_VALUES.get(
			color_id,
			Color.WHITE
		), badge)
		card.custom_minimum_size = Vector2(132, 106)
		card.activated.connect(_on_track_card_activated)
		card.hover_summary.connect(_on_card_hover_summary.bind("unified_track"))
		_track_rail.add_child(card)
		if kind == "normal_card":
			_normal_card_render_count += 1
			if art != null:
				_normal_card_art_count += 1
		else:
			_commodity_card_render_count += 1
			if art != null:
				_commodity_card_art_count += 1


func _on_track_card_activated(payload: Dictionary) -> void:
	if not bool(payload.get("claimable", false)):
		_show_toast("替补牌将在下一次滚动后解锁", false)
		return
	_pending_track_event = _card_summary(payload, "unified_track")
	_emit_intent("track.acquire", {
		"source_instance_id": str(payload.get("instance_id", "")),
	})


func _refresh_assets() -> void:
	_clear_children(_asset_rail)
	var assets := _snapshot.get("six_color_assets", {}) as Dictionary
	var values := assets.get("own_available_assets", {}) as Dictionary
	for color_id in COLORS:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(112, 38)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#131d2d")
		style.border_color = COLOR_VALUES.get(color_id, Color.WHITE)
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", style)
		var row := HBoxContainer.new()
		panel.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _texture(str(ICON_PATHS.get(color_id, "")))
		row.add_child(icon)
		var label := Label.new()
		label.text = "%s
%d / 6" % [
			COLOR_LABELS.get(color_id, color_id),
			int(values.get(color_id, 0)),
		]
		label.add_theme_font_size_override("font_size", 11)
		row.add_child(label)
		_asset_rail.add_child(panel)


func _refresh_hand() -> void:
	_clear_children(_hand_rail)
	var dbg := _snapshot.get("personal_dbg", {}) as Dictionary
	var facts := dbg.get("facts", {}) as Dictionary
	_deck_label.text = "牌库 %d" % int(facts.get("draw_pile_count", 0))
	_discard_label.text = "弃牌 %d" % int(facts.get("discard_count", 0))
	_commodity_label.text = "商品 %d / 5" % int(
		facts.get("commodity_inventory_count", 0)
	)
	var special_actions := _snapshot.get("special_actions", []) as Array
	_special_label.text = "特殊 %d" % special_actions.size()
	for card_variant in facts.get("hand", []) as Array:
		var card_data := card_variant as Dictionary
		var card := V073SampleCardButton.new()
		var color_id := str(card_data.get("primary_color", "industry"))
		var title := "%s · %s" % [
			_card_type_label(str(card_data.get("definition_id", ""))),
			COLOR_LABELS.get(color_id, color_id),
		]
		var art := _card_art({
			"card_kind": "normal_card",
			"card_definition_id": str(card_data.get("definition_id", "")),
		})
		var is_starter := (
			str(card_data.get("origin_class", "")) == "starter_bootstrap"
		)
		card.configure(
			card_data,
			title,
			"零成本 Starter · 预绑定目标"
				if is_starter
				else "标准设施牌 · 预绑定目标",
			art,
			COLOR_VALUES.get(color_id, Color.WHITE),
			"STARTER" if is_starter else "STANDARD"
		)
		card.set_selected(
			str(card_data.get("instance_id", "")) == _selected_card_id
		)
		card.activated.connect(_on_hand_card_activated)
		card.drag_started.connect(_on_hand_card_dragged)
		card.hover_summary.connect(_on_card_hover_summary.bind("hand_dock"))
		_hand_rail.add_child(card)
		_normal_card_render_count += 1
		if art != null:
			_normal_card_art_count += 1
	for special_variant in special_actions:
		var special := special_variant as Dictionary
		var card := V073SampleCardButton.new()
		card.configure(
			special,
			"战术支援",
			"独立特殊行动 · 不占手牌上限",
			_texture("res://assets/third_party/night_patrol/ui/card-frame-power.png"),
			Color("#f18f62"),
			"SPECIAL"
		)
		card.activated.connect(func(_payload: Dictionary) -> void:
			_show_toast("特殊行动当前等待合法目标", false)
		)
		_hand_rail.add_child(card)


func _on_hand_card_activated(payload: Dictionary) -> void:
	var incoming_id := str(payload.get("instance_id", ""))
	if incoming_id == _selected_card_id and not incoming_id.is_empty():
		_emit_playtest_event("card_deselected", _card_summary(payload, "hand_dock"))
		_emit_playtest_event("target_cancelled", {"source_surface": "hand_dock"})
		_clear_selected_card()
		return
	_selected_card_id = str(payload.get("instance_id", ""))
	_selected_card_definition_id = str(payload.get("definition_id", ""))
	_selected_card_color = str(payload.get("primary_color", ""))
	_selected_card_type = str(payload.get("card_type", ""))
	_interaction_counts["card_selected"] += 1
	_last_public_ui_surface = "hand_dock"
	var summary := _card_summary(payload, "hand_dock")
	_emit_playtest_event("card_selected", summary)
	_emit_playtest_event("target_selection_started", summary)
	_action_status.text = "已选 %s · 请选择地区目标" % _card_type_label(
		_selected_card_definition_id
	)
	_refresh_hand()
	_refresh_targets()
	_refresh_planet_presentation()
	_update_acceptance_state()


func _on_hand_card_dragged(payload: Dictionary) -> void:
	_on_hand_card_activated(payload)


func _clear_selected_card() -> void:
	_selected_card_id = ""
	_selected_card_definition_id = ""
	_selected_card_color = ""
	_selected_card_type = ""
	_refresh_hand()
	_refresh_targets()
	_refresh_planet_presentation()


func _refresh_queue() -> void:
	_clear_children(_queue_rail)
	var queue := _snapshot.get("queued_actions", []) as Array
	if queue.is_empty():
		var empty := Label.new()
		empty.text = "尚未锁定行动"
		empty.add_theme_color_override("font_color", Color("#8494aa"))
		_queue_rail.add_child(empty)
		return
	for index in range(queue.size()):
		var entry := queue[index] as Dictionary
		var row := HBoxContainer.new()
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "%d · %s → %s" % [
			index + 1,
			_card_type_label(str(entry.get("card_definition_id", ""))),
			_region_label(str(entry.get("target_region_id", ""))),
		]
		row.add_child(label)
		var up := Button.new()
		up.text = "▲"
		up.tooltip_text = "提前"
		up.disabled = index == 0
		var row_index := index
		up.pressed.connect(func() -> void:
			_last_public_ui_surface = "queue"
			_emit_intent("queue.reorder", {
				"from_index": row_index,
				"to_index": row_index - 1,
			})
		)
		row.add_child(up)
		var down := Button.new()
		down.text = "▼"
		down.tooltip_text = "延后"
		down.disabled = index >= queue.size() - 1
		down.pressed.connect(func() -> void:
			_last_public_ui_surface = "queue"
			_emit_intent("queue.reorder", {
				"from_index": row_index,
				"to_index": row_index + 1,
			})
		)
		row.add_child(down)
		var remove := Button.new()
		remove.text = "×"
		remove.tooltip_text = "移除"
		var action_id := str(entry.get("action_id", ""))
		remove.pressed.connect(func() -> void:
			_emit_intent("queue.remove", {"action_id": action_id})
		)
		row.add_child(remove)
		_queue_rail.add_child(row)


func _refresh_targets() -> void:
	_clear_children(_target_rail)
	var solar_by_region := {}
	var region_ids: Array[String] = []
	for row_variant in _snapshot.get("region_solar", []) as Array:
		var row := row_variant as Dictionary
		var region_id := str(row.get("region_id", ""))
		if region_id.is_empty():
			continue
		solar_by_region[region_id] = row
		region_ids.append(region_id)
	for region_id in region_ids:
		var solar := solar_by_region.get(region_id, {}) as Dictionary
		var button := Button.new()
		var compact := str(_layout_profile.get("mode", "")) == ResponsiveTableLayout.COMPACT_DESKTOP
		button.custom_minimum_size = Vector2(92.0 if compact else 112.0, 28.0)
		button.focus_mode = Control.FOCUS_ALL
		var sunlit := bool(solar.get("sunlit", false))
		button.text = "%s · %s ×%.1f" % [
			_region_label(region_id),
			"日照" if sunlit else "暗面",
			float(solar.get("facility_efficiency_multiplier", 1.0)),
		]
		button.tooltip_text = "键盘与无障碍备用地区入口"
		var legal := _legal_option_for_selected(region_id)
		if not _selected_card_id.is_empty():
			button.disabled = legal.is_empty()
			if not legal.is_empty():
				button.tooltip_text = "绑定 %s / %s" % [
					str(legal.get("facility_type", "")),
					str(legal.get("industry_id", "")),
				]
		button.pressed.connect(_on_region_pressed.bind(region_id))
		_target_rail.add_child(button)


func _on_region_pressed(region_id: String) -> void:
	_handle_region_selection(region_id, "target_rail")


func _legal_option_for_selected(region_id: String) -> Dictionary:
	if _selected_card_id.is_empty():
		return {}
	for option_variant in _snapshot.get("legal_actions", []) as Array:
		var option := option_variant as Dictionary
		if str(option.get("card_instance_id", "")) == _selected_card_id 				and str(option.get("target_region_id", "")) == region_id:
			return option.duplicate(true)
	return {}


func _show_region_popup(region_id: String) -> void:
	_region_popup.visible = true
	_region_popup_title.text = _region_label(region_id)
	var solar: Dictionary = {}
	for row_variant in _snapshot.get("region_solar", []) as Array:
		var row := row_variant as Dictionary
		if str(row.get("region_id", "")) == region_id:
			solar = row
			break
	var facilities := 0
	for option_variant in _snapshot.get("legal_actions", []) as Array:
		if str((option_variant as Dictionary).get(
			"target_region_id",
			""
		)) == region_id:
			facilities += 1
	_region_popup_body.text = (
		"[indent][b]公开设施槽[/b]  %d
"
		+ "[b]设施效率[/b]  ×%.1f
"
		+ "[b]太阳状态[/b]  %s
"
		+ "[b]公开单位[/b]  怪兽与军队投影
"
		+ "[b]购牌面板[/b]  无[/indent]"
	) % [
		facilities,
		float(solar.get("facility_efficiency_multiplier", 1.0)),
		"日照" if bool(solar.get("sunlit", false)) else "暗面",
	]
	_interaction_counts["region_popup"] += 1
	_last_public_ui_surface = "region_popup"
	_emit_playtest_event("region_popup_opened", {
		"region_id": region_id,
		"ui_surface": "region_popup",
	})
	_refresh_playtest_context()
	_update_acceptance_state()


func _refresh_history() -> void:
	var lines: Array[String] = []
	var history := _snapshot.get("public_history", []) as Array
	var start := maxi(0, history.size() - 5)
	for index in range(start, history.size()):
		var row := history[index] as Dictionary
		lines.append("• %s" % str(row.get(
			"reason_code",
			row.get("outcome_id", "public_event")
		)))
	_history_label.text = "
".join(lines)


func _card_art(item: Dictionary) -> Texture2D:
	var definition_id := str(item.get("card_definition_id", ""))
	if str(item.get("card_kind", "")) == "commodity_card":
		var parts := definition_id.split(".")
		var index := 0
		if parts.size() >= 3:
			index = clampi(int(parts[2]), 0, COMMODITY_ART_PATHS.size() - 1)
		return _texture(COMMODITY_ART_PATHS[index])
	return _texture(
		MARKET_ART_PATH if ".market." in definition_id else FACTORY_ART_PATH
	)


func _texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache.get(path) as Texture2D
	var texture := load(path) as Texture2D
	_texture_cache[path] = texture
	return texture


func _card_type_label(definition_id: String) -> String:
	return "市场" if ".market." in definition_id else "工厂"


func _region_label(region_id: String) -> String:
	var suffix := region_id.trim_prefix("region.")
	return {
		"alpha": "阿尔法",
		"beta": "贝塔",
		"gamma": "伽马",
		"delta": "德尔塔",
		"epsilon": "艾普西隆",
		"zeta": "泽塔",
	}.get(suffix, suffix)


func _show_toast(message: String, positive: bool) -> void:
	_toast_label.visible = false
	_action_status.text = message
	_action_status.modulate = Color("#7ce5ae") if positive else Color("#ff8f8f")
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_callback(func() -> void:
		_action_status.modulate = Color.WHITE
	)


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _bind_playtest_surfaces() -> void:
	_marker_panel.connect("marker_requested", _on_marker_requested)
	_coach_marks.connect("coach_mark_shown", _on_coach_mark_shown)
	_coach_marks.connect("coach_mark_skipped", _on_coach_mark_skipped)
	_questionnaire.connect(
		"questionnaire_presented",
		_on_questionnaire_presented
	)
	_questionnaire.connect(
		"questionnaire_submitted",
		_on_questionnaire_submitted
	)
	_questionnaire.connect("questionnaire_skipped", _on_questionnaire_skipped)
	_coach_marks.call("bind_anchors", {
		"dock": $RootMargin/Shell/DockPanel,
		"assets": %AssetRail,
		"hand": %HandRail,
		"track": $RootMargin/Shell/TrackPanel,
		"targets": $RootMargin/Shell/TargetPanel/TargetMargin/TargetRow/TargetTitle,
		"target_panel": $RootMargin/Shell/TargetPanel,
		"planet": _planet_board,
		"roster": $RootMargin/Shell/TableArea/RosterPanel,
		"marker": _marker_panel,
		"lock": %LockButton,
		"queue": %QueueRail,
		"phase": %PhaseLabel,
		"history": %HistoryLabel,
		"save": %SaveNotice,
	})
	_refresh_playtest_context()


func _emit_playtest_event(event_type: String, payload: Dictionary = {}) -> void:
	playtest_presentation_event.emit(event_type, payload.duplicate(true))


func _on_card_hover_summary(payload: Dictionary, surface: String) -> void:
	_last_public_ui_surface = surface
	var summary := _card_summary(payload, surface)
	_emit_playtest_event("card_hover_summary", summary)
	if surface == "unified_track":
		_emit_playtest_event("track_offer_seen", summary)


func _card_summary(payload: Dictionary, surface: String) -> Dictionary:
	return {
		"card_definition_id": str(payload.get(
			"card_definition_id",
			payload.get("definition_id", "unknown")
		)),
		"card_kind": str(payload.get("card_kind", "normal_card")),
		"color_id": str(payload.get("primary_color", "unknown")),
		"asset_cost": int(payload.get("primary_asset_cost", 0)),
		"source_surface": surface,
	}


func _on_marker_requested(marker_type: String, note: String) -> void:
	_emit_playtest_event("playtest_marker_recorded", {
		"marker_type": marker_type,
		"note": note,
		"interaction_mode": _public_interaction_mode(),
		"ui_surface": _last_public_ui_surface,
	})


func _on_coach_mark_shown(mark_id: String) -> void:
	_emit_playtest_event("coach_mark_shown", {"mark_id": mark_id})


func _on_coach_mark_skipped(mark_id: String, skip_all: bool) -> void:
	_emit_playtest_event("coach_mark_skipped", {
		"mark_id": mark_id,
		"skip_all": skip_all,
	})


func _on_questionnaire_presented(settlement_id: String) -> void:
	_emit_playtest_event("questionnaire_presented", {
		"settlement_id": settlement_id,
	})
	_refresh_playtest_context()


func _on_questionnaire_submitted(values: Dictionary) -> void:
	playtest_feedback_submitted.emit(values.duplicate(true))
	_refresh_playtest_context()


func _on_questionnaire_skipped() -> void:
	playtest_feedback_skipped.emit()
	_refresh_playtest_context()


func _acknowledge_final_settlement() -> void:
	_settlement_overlay.visible = false
	_emit_playtest_event("ui_backtracked", {
		"ui_surface": "final_settlement",
	})
	_questionnaire.call(
		"present_after_final_settlement",
		_last_settlement_id
	)
	_refresh_playtest_context()


func _set_random_seed() -> void:
	var value := absi(
		int(Time.get_unix_time_from_system() * 1000.0)
		+ Time.get_ticks_msec()
	)
	_seed_input.text = str(maxi(1, value))


func _refresh_playtest_context() -> void:
	if _coach_marks == null:
		return
	var questionnaire_visible := bool(_questionnaire.call("is_presented"))
	var modal_visible := (
		_start_overlay.visible
		or _region_popup.visible
		or _settlement_overlay.visible
		or questionnaire_visible
	)
	if _marker_panel != null and _marker_panel.has_method("set_temporarily_hidden"):
		_marker_panel.call("set_temporarily_hidden", modal_visible)
	_coach_marks.call("apply_public_context", {
		"match_started": bool(_snapshot.get("match_started", false)),
		"phase": str(_snapshot.get("phase", "idle")),
		"card_selected": not _selected_card_id.is_empty(),
		"queue_count": (_snapshot.get("queued_actions", []) as Array).size(),
		"submission_locked": bool(_snapshot.get("submission_locked", false)),
		"modal_visible": modal_visible,
	})


func _public_interaction_mode() -> String:
	if bool(_questionnaire.call("is_presented")):
		return "questionnaire"
	if _settlement_overlay.visible:
		return "final_settlement"
	if _region_popup.visible:
		return "region_popup"
	if _start_overlay.visible:
		return "pre_game"
	var phase := str(_snapshot.get("phase", "idle"))
	if phase == "submission":
		if bool(_snapshot.get("submission_locked", false)):
			return "submission_locked"
		if not _selected_card_id.is_empty():
			return "target_selecting"
		if not (_snapshot.get("queued_actions", []) as Array).is_empty():
			return "submission_queued"
		return "submission_idle"
	return phase


func _on_export_status_changed(success: bool, message: String) -> void:
	if not is_inside_tree():
		return
	_show_toast(
		"试玩报告已保存：%s" % message if success else "试玩报告导出失败：%s" % message,
		success
	)
	_update_acceptance_state()


func _layout_collision_snapshot() -> Dictionary:
	var map_view := _planet_board.call("get_embedded_map_view") as Control
	var coach_debug := (
		_coach_marks.call("debug_snapshot") as Dictionary
		if _coach_marks != null and _coach_marks.has_method("debug_snapshot")
		else {}
	)
	var marker_debug := (
		_marker_panel.call("debug_snapshot") as Dictionary
		if _marker_panel != null and _marker_panel.has_method("debug_snapshot")
		else {}
	)
	var header_controls: Array = [
		$RootMargin/Shell/Header/HeaderMargin/HeaderRows/HeaderPrimaryRow/TitleStack,
		%PhaseLabel,
		%TimerProgress,
		%TimerLabel,
		%NewGameButton,
		%SaveNotice,
		%SaveButton,
		%ContinueButton,
		%GuideButton,
	]
	var interactive_controls: Array = [
		%NewGameButton,
		%SaveButton,
		%ContinueButton,
		%GuideButton,
		_merge_button,
		_finish_button,
		_lock_button,
		_accelerate_button,
		_planet_board.find_child("ResetOverviewButton", true, false),
		_planet_board.find_child("FullscreenButton", true, false),
	]
	return UILayoutCollisionAudit.audit(
		Rect2(Vector2.ZERO, get_viewport_rect().size),
		{
			"header": $RootMargin/Shell/Header,
			"track": $RootMargin/Shell/TrackPanel,
			"table": $RootMargin/Shell/TableArea,
			"target": $RootMargin/Shell/TargetPanel,
			"dock": $RootMargin/Shell/DockPanel,
			"roster": $RootMargin/Shell/TableArea/RosterPanel,
			"planet": _planet_board,
		},
		header_controls,
		interactive_controls,
		_planet_board.get_node_or_null("PlanetRows/PlanetStageViewport") as Control,
		map_view,
		coach_debug,
		marker_debug,
		_region_popup
	)


func _update_acceptance_state() -> void:
	var debug := {}
	if _flow != null and _flow.has_method("debug_snapshot"):
		debug = _flow.call("debug_snapshot") as Dictionary
	var runtime := debug.get("runtime", {}) as Dictionary
	var telemetry_debug := {}
	if _telemetry != null and _telemetry.has_method("debug_snapshot"):
		telemetry_debug = _telemetry.call("debug_snapshot") as Dictionary
	var planet_debug := {}
	if _planet_board != null and _planet_board.has_method("map_presentation_target_debug_snapshot"):
		planet_debug = _planet_board.call("map_presentation_target_debug_snapshot") as Dictionary
	var map_debug := {}
	var map_view := _planet_board.call("get_embedded_map_view") as Control
	if map_view != null and map_view.has_method("get_sceneization_debug_snapshot"):
		map_debug = map_view.call("get_sceneization_debug_snapshot") as Dictionary
	var adapter_debug := _planet_presentation_adapter.debug_snapshot(
		int(_snapshot.get("presentation_match_seed", 0))
	)
	var layout_audit := _layout_collision_snapshot()
	acceptance_state = {
		"schema": "V073SampleAcceptanceStateV1",
		"ruleset_id": RULESET_ID,
		"runtime_frames": _runtime_frame_count,
		"viewport_size": get_viewport_rect().size,
		"compact_layout": str(_layout_profile.get("mode", "")) == ResponsiveTableLayout.COMPACT_DESKTOP,
		"match_started": bool(_snapshot.get("match_started", false)),
		"match_completed": str(_snapshot.get("phase", "")) == "settled",
		"player_count": (_snapshot.get("roster", []) as Array).size(),
		"local_human_count": int(runtime.get("local_human_count", 0)),
		"ai_player_count": int(runtime.get("ai_player_count", 0)),
		"initial_hand_count": int((
			(_snapshot.get("personal_dbg", {}) as Dictionary).get(
				"facts",
				{}
			) as Dictionary
		).get("hand_count", 0)),
		"save_enabled": false,
		"continue_enabled": false,
		"v06_save_apply_count": 0,
		"v06_save_write_count": 0,
		"single_unified_track": true,
		"right_permanent_panel_count": 0,
		"outer_orbit_decoration_count": 0,
		"planet_alpha": 1.0,
		"backside_occluded": true,
		"responsive_layout_owner": "V073ResponsiveTableLayoutV2",
		"responsive_layout_mode": str(_layout_profile.get("mode", "")),
		"ui_layout_collision_audit": layout_audit.duplicate(true),
		"unintended_major_panel_intersection_count": int(layout_audit.get("unintended_major_panel_intersection_count", 0)),
		"interactive_control_occlusion_count": int(layout_audit.get("interactive_control_occlusion_count", 0)),
		"header_overflow_count": int(layout_audit.get("header_overflow_count", 0)),
		"header_text_clip_count": int(layout_audit.get("header_text_clip_count", 0)),
		"header_interactive_control_overlap_count": int(layout_audit.get("header_interactive_control_overlap_count", 0)),
		"track_panel_overflow_count": int(layout_audit.get("track_panel_overflow_count", 0)),
		"planet_draw_outside_stage_count": int(layout_audit.get("planet_draw_outside_stage_count", 0)),
		"planet_input_outside_stage_count": int(layout_audit.get("planet_input_outside_stage_count", 0)),
		"target_panel_dock_overlap_count": int(layout_audit.get("target_panel_dock_overlap_count", 0)),
		"roster_planet_overlap_count": int(layout_audit.get("roster_planet_overlap_count", 0)),
		"coach_unintended_overlap_count": int(layout_audit.get("coach_unintended_overlap_count", 0)),
		"coach_target_occlusion_count": int(layout_audit.get("coach_target_occlusion_count", 0)),
		"marker_unintended_overlap_count": int(layout_audit.get("marker_unintended_overlap_count", 0)),
		"marker_panel_header_width_consumption": int(layout_audit.get("marker_panel_header_width_consumption", 0)),
		"region_popup_unintended_overlap_count": int(layout_audit.get("region_popup_unintended_overlap_count", 0)),
		"map_presentation_connection_count": int(adapter_debug.get("connection_count", 0)),
		"map_presentation_apply_count": _map_presentation_apply_count,
		"planet_placeholder_active": not bool(map_debug.get("has_map_data", false)),
		"procedural_region_count": int(map_debug.get("district_count", 0)),
		"region_geometry_fingerprint": str(map_debug.get("geometry_fingerprint", "")),
		"planet_interaction_frame_p95_ms": float(map_debug.get("planet_interaction_frame_p95_ms", 0.0)),
		"planet_idle_frame_p95_ms": float(map_debug.get("planet_idle_frame_p95_ms", 0.0)),
		"planet_interaction_frame_sample_count": int(map_debug.get("interaction_frame_sample_count", 0)),
		"planet_idle_frame_sample_count": int(map_debug.get("idle_frame_sample_count", 0)),
		"region_geometry_rebuild_count": int(map_debug.get("geometry_rebuild_count", 0)),
		"planet_presentation_gameplay_owner_count": int(adapter_debug.get("gameplay_owner_count", 0)),
		"planet_presentation_save_owner_count": int(adapter_debug.get("save_owner_count", 0)),
		"planet_presentation_rng_owner_count": int(adapter_debug.get("rng_owner_count", 0)),
		"presentation_rng_gameplay_draw_delta": int(adapter_debug.get("gameplay_rng_draw_count", 0)),
		"planet_rendering_mode": "canvas_shader_spherical_projection",
		"planet_flat_disc_only_mode": false,
		"planet_surface_rotates_with_camera": true,
		"planet_primary_target_selection_surface": true,
		"target_rail_primary_surface": false,
		"map_region_selection_count": _map_region_selection_count,
		"map_target_binding_count": _map_target_binding_count,
		"map_illegal_target_reject_count": _map_illegal_target_reject_count,
		"region_popup_opened_from_map": _map_region_popup_opened,
		"planet_rotation_used": _planet_rotation_used,
		"planet_zoom_used": _planet_zoom_used,
		"fixed_left_rail_visible_count": int(planet_debug.get("fixed_left_rail_visible_count", 0)),
		"fixed_right_rail_visible_count": int(planet_debug.get("fixed_right_rail_visible_count", 0)),
		"flow_compass_map_overlap_count": int(planet_debug.get("flow_compass_map_overlap_count", 0)),
		"six_color_icon_coverage": 6,
		"color_only_identification_count": 0,
		"normal_card_art_coverage": (
			1.0 if _normal_card_render_count == 0
			else float(_normal_card_art_count) / float(_normal_card_render_count)
		),
		"commodity_card_art_coverage": (
			1.0 if _commodity_card_render_count == 0
			else float(_commodity_card_art_count) / float(
				_commodity_card_render_count
			)
		),
		"special_action_visible": (
			_snapshot.get("special_actions", []) as Array
		).size() > 0,
		"special_action_counts_toward_normal_limit": false,
		"final_settlement_count": int(runtime.get(
			"final_settlement_count",
			0
		)),
		"duplicate_settlement_count": int(runtime.get(
			"duplicate_settlement_count",
			0
		)),
		"invalid_action_count": int(runtime.get("invalid_action_count", 0)),
		"runtime_error_count": int(runtime.get("runtime_error_count", 0)),
		"hidden_info_violation_count": int(runtime.get(
			"hidden_info_violation_count",
			0
		)),
		"dual_authority_count": int(runtime.get("dual_authority_count", 0)),
		"nonfinite_count": int(runtime.get("nonfinite_count", 0)),
		"interaction_counts": _interaction_counts.duplicate(true),
		"selected_card_id": _selected_card_id,
		"region_popup_visible": _region_popup.visible,
		"settlement_visible": _settlement_overlay.visible,
		"playtest_telemetry_ready": bool(telemetry_debug.get("ready", false)),
		"playtest_hidden_info_field_count": int(telemetry_debug.get(
			"hidden_info_field_count",
			0
		)),
		"playtest_export_green": bool(telemetry_debug.get(
			"export_succeeded",
			false
		)),
		"playtest_export_paths": (
			telemetry_debug.get("export_paths", {}) as Dictionary
		).duplicate(true),
		"coach_mark_count": int((_coach_marks.call(
			"debug_snapshot"
		) as Dictionary).get("mark_count", 0)),
		"playtest_markers_ready": _marker_panel != null,
		"final_questionnaire_ready": _questionnaire != null,
		"questionnaire_visible": bool(_questionnaire.call("is_presented")),
	}
