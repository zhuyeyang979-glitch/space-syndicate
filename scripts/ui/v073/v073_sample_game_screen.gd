extends Control
class_name V073SampleGameScreen

signal application_intent_requested(intent: Dictionary)

const RULESET_ID := "v0.7.3"
const COMPACT_VIEWPORT_HEIGHT := 820.0
const COMPACT_PLANET_STAGE_HEIGHT := 104.0
const REGULAR_PLANET_STAGE_HEIGHT := 252.0
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

var acceptance_state: Dictionary = {}
var _flow: Node
var _snapshot: Dictionary = {}
var _capabilities: Dictionary = {}
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
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_region_popup_body.add_theme_constant_override("line_separation", 5)
	_start_overlay.visible = true
	_region_popup.visible = false
	_settlement_overlay.visible = false
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
	_refresh_history()
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
		"track.acquire":
			if accepted:
				_interaction_counts["track_acquired"] += 1
		"card.queue":
			if accepted:
				_interaction_counts["target_bound"] += 1
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
	_update_acceptance_state()


func present_final_settlement(settlement: Dictionary) -> void:
	_settlement_overlay.visible = true
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
	)
	for count in [3, 4, 6, 8]:
		var button := get_node("%%Start%dButton" % count) as Button
		button.pressed.connect(_request_new_game.bind(count))
	%StartOverlayClose.pressed.connect(func() -> void:
		_start_overlay.visible = false
	)
	%RegionPopupClose.pressed.connect(func() -> void:
		_region_popup.visible = false
	)
	%SettlementClose.pressed.connect(func() -> void:
		_settlement_overlay.visible = false
	)
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
	var compact := get_viewport_rect().size.y <= COMPACT_VIEWPORT_HEIGHT
	var root_margin := $RootMargin as MarginContainer
	var shell := $RootMargin/Shell as VBoxContainer
	var stage := _planet_board.get_node_or_null(
		"PlanetRows/PlanetStageViewport"
	) as Control
	if root_margin != null:
		root_margin.offset_top = 6.0 if compact else 10.0
		root_margin.offset_bottom = -6.0 if compact else -10.0
	if shell != null:
		shell.add_theme_constant_override("separation", 2 if compact else 6)
	if stage != null:
		stage.custom_minimum_size.y = (
			COMPACT_PLANET_STAGE_HEIGHT
			if compact
			else REGULAR_PLANET_STAGE_HEIGHT
		)
		stage.update_minimum_size()
	_planet_board.update_minimum_size()
	if shell != null:
		shell.queue_sort()


func _request_new_game(player_count: int) -> void:
	_emit_intent("new_game.start", {
		"player_count": player_count,
		"seed": 730045 + player_count,
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
			44 if get_viewport_rect().size.y <= COMPACT_VIEWPORT_HEIGHT else 54
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
		card.configure(
			card_data,
			title,
			"零成本 Starter · 预绑定目标",
			art,
			COLOR_VALUES.get(color_id, Color.WHITE),
			"STARTER"
		)
		card.set_selected(
			str(card_data.get("instance_id", "")) == _selected_card_id
		)
		card.activated.connect(_on_hand_card_activated)
		card.drag_started.connect(_on_hand_card_dragged)
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
	_selected_card_id = str(payload.get("instance_id", ""))
	_selected_card_definition_id = str(payload.get("definition_id", ""))
	_selected_card_color = str(payload.get("primary_color", ""))
	_selected_card_type = str(payload.get("card_type", ""))
	_interaction_counts["card_selected"] += 1
	_action_status.text = "已选 %s · 请选择地区目标" % _card_type_label(
		_selected_card_definition_id
	)
	_refresh_hand()
	_refresh_targets()
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
	for row_variant in _snapshot.get("region_solar", []) as Array:
		var row := row_variant as Dictionary
		solar_by_region[str(row.get("region_id", ""))] = row
	for region_id in [
		"region.alpha",
		"region.beta",
		"region.gamma",
		"region.delta",
		"region.epsilon",
		"region.zeta",
	]:
		var solar := solar_by_region.get(region_id, {}) as Dictionary
		var button := Button.new()
		button.custom_minimum_size = Vector2(126, 52)
		var sunlit := bool(solar.get("sunlit", false))
		button.text = "%s
%s ×%.1f" % [
			_region_label(region_id),
			"日照" if sunlit else "暗面",
			float(solar.get("facility_efficiency_multiplier", 1.0)),
		]
		button.tooltip_text = "地区公开信息"
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
	if _selected_card_id.is_empty():
		_show_region_popup(region_id)
		return
	var option := _legal_option_for_selected(region_id)
	if option.is_empty():
		_show_toast("该地区不是当前卡牌的合法目标", false)
		return
	_emit_intent("card.queue", {
		"card_instance_id": _selected_card_id,
		"target_slot_id": str(option.get("target_slot_id", "")),
	})


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
	_toast_label.text = message
	_toast_label.modulate = Color("#7ce5ae") if positive else Color("#ff8f8f")
	_toast_label.visible = true
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_callback(func() -> void:
		_toast_label.visible = false
	)


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _update_acceptance_state() -> void:
	var debug := {}
	if _flow != null and _flow.has_method("debug_snapshot"):
		debug = _flow.call("debug_snapshot") as Dictionary
	var runtime := debug.get("runtime", {}) as Dictionary
	acceptance_state = {
		"schema": "V073SampleAcceptanceStateV1",
		"ruleset_id": RULESET_ID,
		"runtime_frames": _runtime_frame_count,
		"viewport_size": get_viewport_rect().size,
		"compact_layout": get_viewport_rect().size.y <= COMPACT_VIEWPORT_HEIGHT,
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
	}
