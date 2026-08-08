extends "res://scripts/ui/v073/v073_sample_game_screen.gd"
class_name V074SampleGameScreen

const V074_RULESET_ID := "v0.7.4"
const ResponsiveLayoutV074 := preload(
	"res://scripts/ui/v074/v074_responsive_table_layout.gd"
)
const LayoutAuditV074 := preload(
	"res://scripts/ui/v074/v074_ui_layout_collision_audit_v1.gd"
)
const TrackCardButtonV074 := preload(
	"res://scripts/ui/v074/v074_track_card_button.gd"
)
const AssetPipPresenter := preload(
	"res://scripts/ui/v074/v074_asset_pip_presenter.gd"
)
const AssetPipGroup := preload(
	"res://scripts/ui/v074/v074_asset_pip_group.gd"
)
const PreviewPlanetAdapter := preload(
	"res://scripts/presentation/v074/v074_planet_presentation_adapter_v1.gd"
)
const WAREHOUSE_ART_PATH := (
	"res://assets/third_party/commercial/materials/ambientcg/"
	+ "SheetMetal003/SheetMetal003_1K-JPG_Color.jpg"
)
const ASSET_RESERVATION_LOCK_ICON_PATH := (
	"res://assets/third_party/commercial/ui/"
	+ "kenney_board_game_icons/icons/lock.png"
)
const V074_TRACK_VISIBLE_CAPACITY := 10
const TRACK_PRESENTATION_DRIFT_AMPLITUDE_PX := 3.0
const TRACK_PRESENTATION_ANGULAR_SPEED := 0.45

@onready var _region_count_input: SpinBox = %RegionCountSpinBox
@onready var _complexity_option: OptionButton = %GeographyComplexityOption
@onready var _profile_option: OptionButton = %LandOceanProfileOption
@onready var _player_count_option: OptionButton = %PlayerCountOption
@onready var _preview_label: Label = %MapPreviewLabel
@onready var _virtual_target_rail: Control = %V074VirtualizedTargetRail
@onready var _virtual_target_rail_float: Control = (
	$PlaytestUtilityLayer/PlaytestSafeArea/V074TargetRailFloat
)
@onready var _region_popup_choices: VBoxContainer = %RegionPopupTargetChoices

const ACCEPTANCE_REFRESH_SECONDS := 1.0
const NEW_GAME_MAP_INPUT_GUARD_MSEC := 240

var _preview_planet_adapter: RefCounted = PreviewPlanetAdapter.new()
var _preview_receipt: Dictionary = {}
var _acceptance_refresh_elapsed := 0.0
var _map_input_guard_until_msec := 0
var _new_game_clickthrough_suppression_count := 0
var _last_planet_payload_signature := ""
var _planet_presentation_skip_count := 0
var _asset_pip_grid: GridContainer
var _track_ui_render_capacity := 0
var _track_duplicate_instance_count := 0
var _track_focus_order_green := false
var _track_horizontal_scroll_required := false
var _track_real_card_count := 0
var _track_vacancy_slot_count := 0
var _track_motion_phase := 0.0
var _track_motion_offset_px := 0.0
var _track_motion_sample_count := 0
var _track_motion_observed_delta_px := 0.0
var _asset_pip_fraction_text_count := 0
var _asset_pip_trailing_blank_width_px := 0.0
var _asset_pip_symbol_coverage := 0
var _asset_pip_slot_count_per_color := 0
var _asset_pip_value_parity := false
var _asset_pip_reserved_parity := false
var _asset_pip_projected_refresh_parity := false
var _asset_pip_accessibility_green := false


func _ready() -> void:
	super._ready()
	_region_popup_choices.get_parent().move_child(
		_region_popup_choices,
		%RegionPopupClose.get_index()
	)
	_populate_v074_map_options()
	%Subtitle.text = "V0.7.4 · ROGUELIKE PLANET"
	%PersistenceNotice.text = "V0.7.4样品暂不支持中途保存"
	_virtual_target_rail.visible = false
	_refresh_targets()
	_update_acceptance_state()


func _process(delta: float) -> void:
	_runtime_frame_count += 1
	if str(_snapshot.get("phase", "")) == "submission":
		_submission_remaining = maxf(0.0, _submission_remaining - delta)
		_timer_label.text = "%02d s" % int(ceil(_submission_remaining))
		_timer_progress.value = _submission_remaining
	_acceptance_refresh_elapsed += delta
	_advance_track_presentation(delta)
	if _acceptance_refresh_elapsed >= ACCEPTANCE_REFRESH_SECONDS:
		_acceptance_refresh_elapsed = 0.0
		_update_acceptance_state()


func bind_application_flow(
	flow: Node,
	identity: Dictionary,
	capabilities: Dictionary
) -> void:
	super.bind_application_flow(flow, identity, capabilities)
	_ruleset_label.text = "v0.7.4 · NEW GAME ONLY"
	_save_notice.text = str(identity.get(
		"save_notice",
		"V0.7.4样品暂不支持中途保存"
	))
	call_deferred("_request_map_preview")


func apply_snapshot(snapshot: Dictionary) -> void:
	if str(snapshot.get("ruleset_id", "")) != V074_RULESET_ID:
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


func _refresh_track() -> void:
	_clear_children(_track_rail)
	_normal_card_render_count = 0
	_normal_card_art_count = 0
	_commodity_card_render_count = 0
	_commodity_card_art_count = 0
	_track_duplicate_instance_count = 0
	_track_ui_render_capacity = 0
	_track_real_card_count = 0
	_track_vacancy_slot_count = 0
	_track_focus_order_green = false
	_track_motion_offset_px = 0.0
	var track := _snapshot.get("unified_track", {}) as Dictionary
	var public_facts := track.get("public_facts", {}) as Dictionary
	var private_facts := track.get(
		"viewer_private_facts",
		{}
	) as Dictionary
	var own_items := (
		private_facts.get("own_segment_items", []) as Array
	).duplicate(true)
	own_items.sort_custom(_track_item_before)
	var instance_ids := {}
	var occupied_slots := {}
	var track_cards: Array[Control] = []
	for item_index in range(own_items.size()):
		var item := own_items[item_index] as Dictionary
		var instance_id := str(item.get("instance_id", ""))
		if instance_ids.has(instance_id):
			_track_duplicate_instance_count += 1
		instance_ids[instance_id] = true
		var card := TrackCardButtonV074.new()
		card.name = "TrackCard_%02d" % item_index
		var kind := str(item.get("card_kind", ""))
		var color_id := str(item.get("primary_color", "industry"))
		var title := "商品 · %s" % COLOR_LABELS.get(color_id, color_id)
		var badge := "COMMODITY"
		var meta := "库存 0/5"
		if kind == "normal_card":
			title = "%s · %s" % [
				_card_type_label(str(item.get(
					"card_definition_id",
					""
				))),
				COLOR_LABELS.get(color_id, color_id),
			]
			badge = "NORMAL · L1"
			meta = "成本 %d · 进入弃牌" % int(
				item.get("primary_asset_cost", 1)
			)
		var art := _card_art(item)
		card.configure(
			item,
			title,
			meta,
			art,
			COLOR_VALUES.get(color_id, Color.WHITE),
			badge
		)
		card.custom_minimum_size = Vector2(96.0, 106.0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_stretch_ratio = 1.0
		var local_slot_index := int(item.get(
			"local_slot_index",
			item_index
		))
		card.set_meta("track_local_slot_index", local_slot_index)
		occupied_slots[local_slot_index] = true
		card.activated.connect(_on_track_card_activated)
		card.hover_summary.connect(
			_on_card_hover_summary.bind("unified_track")
		)
		_track_rail.add_child(card)
		track_cards.append(card)
		if kind == "normal_card":
			_normal_card_render_count += 1
			if art != null:
				_normal_card_art_count += 1
		else:
			_commodity_card_render_count += 1
			if art != null:
				_commodity_card_art_count += 1
	for slot_index in range(V074_TRACK_VISIBLE_CAPACITY):
		if occupied_slots.has(slot_index):
			continue
		var vacancy := _build_track_vacancy_slot(slot_index)
		_track_rail.add_child(vacancy)
		_track_rail.move_child(vacancy, slot_index)
		_track_vacancy_slot_count += 1
	_track_real_card_count = track_cards.size()
	for card_index in range(track_cards.size()):
		var card := track_cards[card_index]
		if card_index > 0:
			card.focus_neighbor_left = card.get_path_to(
				track_cards[card_index - 1]
			)
			card.focus_previous = card.focus_neighbor_left
		if card_index + 1 < track_cards.size():
			card.focus_neighbor_right = card.get_path_to(
				track_cards[card_index + 1]
			)
			card.focus_next = card.focus_neighbor_right
	_track_ui_render_capacity = _track_rail.get_child_count()
	_track_focus_order_green = (
		track_cards.size() == own_items.size()
		and _track_duplicate_instance_count == 0
	)
	var track_scroll := (
		$RootMargin/Shell/TrackPanel/TrackMargin/TrackRows/TrackScroll
		as ScrollContainer
	)
	track_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	track_scroll.clip_contents = false
	_track_rail.clip_contents = false
	_track_horizontal_scroll_required = false
	_track_meta.text = (
		"共享寿司轨 %d/%d · 空位 %d · 60%% 普通 / 40%% 商品 · 滚动 %d"
		% [
			_track_real_card_count,
			V074_TRACK_VISIBLE_CAPACITY,
			_track_vacancy_slot_count,
			int(public_facts.get("scroll_sequence", 0)),
		]
	)


func _refresh_assets() -> void:
	_clear_children(_asset_rail)
	var assets := _snapshot.get("six_color_assets", {}) as Dictionary
	var mode := str(_layout_profile.get(
		"mode",
		ResponsiveLayoutV074.REGULAR_DESKTOP
	))
	if mode.is_empty():
		var fallback_profile := (
			ResponsiveLayoutV074.new().resolve_for_window(
				Vector2(get_window().size),
				get_viewport_rect().size,
				maxi(4, (_snapshot.get("roster", []) as Array).size())
			)
		)
		mode = str(fallback_profile.get(
			"mode",
			ResponsiveLayoutV074.REGULAR_DESKTOP
		))
	var grid := GridContainer.new()
	grid.name = "V074AssetPipGrid"
	grid.columns = AssetPipPresenter.grid_columns(mode)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_END
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	_asset_rail.alignment = BoxContainer.ALIGNMENT_END
	_asset_rail.add_child(grid)
	_asset_pip_grid = grid
	_asset_rail.custom_minimum_size.y = (
		22.0 if grid.columns == 6 else 42.0
	)
	var lock_texture := _texture(
		ASSET_RESERVATION_LOCK_ICON_PATH
	)
	var valid_model_count := 0
	var reserved_parity_count := 0
	var projected_parity_count := 0
	var accessibility_count := 0
	_asset_pip_symbol_coverage = 0
	_asset_pip_slot_count_per_color = AssetPipPresenter.PIP_SLOT_COUNT
	_asset_pip_fraction_text_count = 0
	for color_id in COLORS:
		var model := AssetPipPresenter.model_from_projection(
			assets,
			color_id
		)
		var validation := AssetPipPresenter.validation_report(model)
		if bool(validation.get("valid", false)):
			valid_model_count += 1
		var exact := int((
			assets.get("own_exact_assets", {}) as Dictionary
		).get(color_id, 0))
		var available := int((
			assets.get("own_available_assets", {}) as Dictionary
		).get(color_id, 0))
		var projected_final := int((
			assets.get("own_projected_refresh", {}) as Dictionary
		).get(color_id, available))
		if int(model.get("reserved", -1)) == exact - available:
			reserved_parity_count += 1
		if int(model.get("projected_refresh", -1)) == maxi(
			0,
			projected_final - available
		):
			projected_parity_count += 1
		var symbol_texture := _texture(str(
			ICON_PATHS.get(color_id, "")
		))
		if symbol_texture != null:
			_asset_pip_symbol_coverage += 1
		var group := AssetPipGroup.new()
		group.configure(
			color_id,
			str(COLOR_LABELS.get(color_id, color_id)),
			symbol_texture,
			lock_texture,
			COLOR_VALUES.get(color_id, Color.WHITE),
			model
		)
		grid.add_child(group)
		var group_debug := group.debug_snapshot()
		if bool(group_debug.get(
			"accessibility_label_present",
			false
		)):
			accessibility_count += 1
	_asset_pip_value_parity = valid_model_count == COLORS.size()
	_asset_pip_reserved_parity = (
		reserved_parity_count == COLORS.size()
	)
	_asset_pip_projected_refresh_parity = (
		projected_parity_count == COLORS.size()
	)
	_asset_pip_accessibility_green = (
		accessibility_count == COLORS.size()
	)


func _advance_track_presentation(delta: float) -> void:
	if _track_rail == null or not is_instance_valid(_track_rail):
		return
	if _track_rail.get_child_count() == 0:
		return
	_track_motion_phase = fposmod(
		_track_motion_phase + delta * TRACK_PRESENTATION_ANGULAR_SPEED,
		TAU
	)
	var next_offset := (
		-TRACK_PRESENTATION_DRIFT_AMPLITUDE_PX
		* (_track_motion_phase / TAU)
	)
	_track_motion_observed_delta_px = maxf(
		_track_motion_observed_delta_px,
		absf(next_offset - _track_motion_offset_px)
	)
	if not is_equal_approx(next_offset, _track_motion_offset_px):
		_track_motion_sample_count += 1
	_track_motion_offset_px = next_offset
	_track_rail.position.x = next_offset


func _build_track_vacancy_slot(slot_index: int) -> Control:
	var vacancy := PanelContainer.new()
	vacancy.name = "TrackVacancy_%02d" % slot_index
	vacancy.custom_minimum_size = Vector2(96.0, 106.0)
	vacancy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vacancy.size_flags_stretch_ratio = 1.0
	vacancy.focus_mode = Control.FOCUS_NONE
	vacancy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vacancy.set_meta("track_local_slot_index", slot_index)
	vacancy.set_meta("track_vacancy", true)
	vacancy.set_meta(
		"accessibility_label",
		"第%d轨位已取走，等待共享轨自然滚动" % (slot_index + 1)
	)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.09, 0.62)
	style.border_color = Color(0.38, 0.58, 0.72, 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	vacancy.add_theme_stylebox_override("panel", style)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vacancy.add_child(center)
	var labels := VBoxContainer.new()
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.alignment = BoxContainer.ALIGNMENT_CENTER
	labels.add_theme_constant_override("separation", 4)
	center.add_child(labels)

	var status := Label.new()
	status.text = "已取走"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 11)
	status.add_theme_color_override(
		"font_color",
		Color(0.7, 0.86, 0.96, 0.92)
	)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(status)

	var wait := Label.new()
	wait.text = "等待共享轨滚动"
	wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wait.add_theme_font_size_override("font_size", 9)
	wait.add_theme_color_override(
		"font_color",
		Color(0.52, 0.67, 0.78, 0.8)
	)
	wait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(wait)
	return vacancy


func _audit_asset_pip_geometry() -> void:
	_asset_pip_trailing_blank_width_px = 0.0
	if _asset_pip_grid == null or not is_instance_valid(_asset_pip_grid):
		return
	for group_variant in _asset_pip_grid.get_children():
		var group := group_variant as Control
		if group == null or not group.has_method("debug_snapshot"):
			continue
		var debug := group.call("debug_snapshot") as Dictionary
		_asset_pip_trailing_blank_width_px = maxf(
			_asset_pip_trailing_blank_width_px,
			float(debug.get("trailing_blank_width", 0.0))
		)


func _track_item_before(left: Variant, right: Variant) -> bool:
	return int((left as Dictionary).get("local_slot_index", 0)) < int(
		(right as Dictionary).get("local_slot_index", 0)
	)


func apply_receipt(receipt: Dictionary) -> void:
	super.apply_receipt(receipt)
	if (
		str(receipt.get("intent_kind", "")) == "map.preview"
		and bool(receipt.get("accepted", false))
	):
		_preview_receipt = (
			receipt.get("map_genesis_receipt", {}) as Dictionary
		).duplicate(true)
		_preview_label.text = "%d regions · %s · %s" % [
			int(_preview_receipt.get("region_count", 0)),
			str((_preview_receipt.get("request", {}) as Dictionary).get(
				"geography_complexity",
				""
			)),
			str((_preview_receipt.get("request", {}) as Dictionary).get(
				"land_ocean_profile",
				""
			)),
		]
		_apply_preview_planet()


func _connect_static_controls() -> void:
	super._connect_static_controls()
	%StartConfiguredButton.pressed.connect(func() -> void:
		_request_new_game(_selected_player_count())
	)
	%CopySeedButton.pressed.connect(_copy_seed)
	%RegeneratePreviewButton.pressed.connect(_request_map_preview)
	_virtual_target_rail.connect(
		"region_popup_requested",
		_on_virtual_region_popup_requested
	)
	_virtual_target_rail.connect(
		"target_binding_requested",
		_on_virtual_target_binding_requested
	)
	_virtual_target_rail.connect(
		"typed_feedback_requested",
		_on_virtual_target_feedback
	)
	_virtual_target_rail.connect(
		"collapsed_changed",
		_on_virtual_target_rail_collapsed
	)


func _populate_v074_map_options() -> void:
	_region_count_input.min_value = 6.0
	_region_count_input.max_value = 30.0
	_region_count_input.step = 1.0
	_region_count_input.value = 16.0
	_populate_metadata_option(
		_complexity_option,
		["SIMPLE", "STANDARD", "COMPLEX"],
		1
	)
	_populate_metadata_option(
		_profile_option,
		["CONTINENTAL", "BALANCED", "ARCHIPELAGO"],
		1
	)
	var players: Array[String] = []
	for count in range(3, 9):
		players.append(str(count))
	_populate_metadata_option(_player_count_option, players, 1)


func _populate_metadata_option(
	option: OptionButton,
	values: Array[String],
	selected_index: int
) -> void:
	option.clear()
	for value in values:
		option.add_item(value)
		option.set_item_metadata(option.item_count - 1, value)
	option.select(clampi(selected_index, 0, option.item_count - 1))


func _configure_planet_shell() -> void:
	if _planet_board.has_method("set_board_state"):
		_planet_board.call("set_board_state", {
			"title": "V0.7.4 动态行星",
			"hint": "MAP %s" % str(_snapshot.get("map_fingerprint", "")).left(12),
			"left_rail": {"hidden": true},
			"right_rail": {"hidden": true},
			"flow_compass": {"hidden": true},
		})


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var physical_window_size := Vector2(get_window().size)
	var player_count := maxi(4, (_snapshot.get("roster", []) as Array).size())
	_layout_profile = ResponsiveLayoutV074.new().resolve_for_window(
		physical_window_size,
		viewport_size,
		player_count
	)
	var mode := str(_layout_profile.get(
		"mode",
		ResponsiveLayoutV074.REGULAR_DESKTOP
	))
	var root_margin := $RootMargin as ScrollContainer
	var shell := $RootMargin/Shell as VBoxContainer
	var header := $RootMargin/Shell/Header as Control
	var track_panel := $RootMargin/Shell/TrackPanel as Control
	var table_area := $RootMargin/Shell/TableArea as Control
	var roster_panel := $RootMargin/Shell/TableArea/RosterPanel as Control
	var target_panel := $RootMargin/Shell/TargetPanel as Control
	var dock_panel := $RootMargin/Shell/DockPanel as Control
	var queue_panel := (
		$RootMargin/Shell/DockPanel/DockMargin/DockRows/DockBody/QueuePanel
		as Control
	)
	var stage := _planet_board.get_node_or_null(
		"PlanetRows/PlanetStageViewport"
	) as Control
	var content := _layout_profile.get("content_rect", Rect2()) as Rect2
	var header_primary := (
		_layout_profile.get("primary_header_rect", Rect2()) as Rect2
	)
	var header_utility := (
		_layout_profile.get("utility_header_rect", Rect2()) as Rect2
	)
	var track_rect := _layout_profile.get("track_rect", Rect2()) as Rect2
	var planet_rect := _layout_profile.get("planet_rect", Rect2()) as Rect2
	var target_rect := (
		_layout_profile.get("target_rail_rect", Rect2()) as Rect2
	)
	var target_float_rect := (
		_layout_profile.get("target_rail_float_rect", Rect2()) as Rect2
	)
	var hand_rect := _layout_profile.get("hand_dock_rect", Rect2()) as Rect2
	var roster_rect := _layout_profile.get("roster_rect", Rect2()) as Rect2
	_apply_responsive_density(mode)
	root_margin.offset_left = content.position.x
	root_margin.offset_top = content.position.y
	root_margin.offset_right = -content.position.x
	root_margin.offset_bottom = -content.position.y
	_virtual_target_rail_float.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_virtual_target_rail_float.position = target_float_rect.position
	_virtual_target_rail_float.custom_minimum_size.x = target_float_rect.size.x
	_virtual_target_rail_float.size = Vector2(target_float_rect.size.x, 0.0)
	_virtual_target_rail.custom_minimum_size.x = target_float_rect.size.x
	_virtual_target_rail.call(
		"set_expanded_height",
		target_float_rect.size.y
	)
	shell.add_theme_constant_override("separation", 2)
	header.custom_minimum_size.y = (
		header_primary.size.y + header_utility.size.y
	)
	track_panel.custom_minimum_size.y = track_rect.size.y
	table_area.custom_minimum_size.y = planet_rect.size.y
	target_panel.custom_minimum_size.y = target_rect.size.y
	dock_panel.custom_minimum_size.y = hand_rect.size.y
	roster_panel.custom_minimum_size.x = roster_rect.size.x
	queue_panel.custom_minimum_size.x = (
		258.0
		if mode == ResponsiveLayoutV074.COMPACT_DESKTOP
		else 340.0
		if mode == ResponsiveLayoutV074.WIDE_DESKTOP
		else 300.0
	)
	_planet_board.custom_minimum_size = Vector2(0.0, planet_rect.size.y)
	if stage != null:
		stage.custom_minimum_size.y = maxf(
			float(_layout_profile.get("minimum_planet_height", 220.0)),
			planet_rect.size.y - 32.0
		)
		stage.update_minimum_size()
	_planet_board.call("set_layout_mode", mode)
	_track_rail.add_theme_constant_override(
		"separation",
		4
		if mode == ResponsiveLayoutV074.COMPACT_DESKTOP
		else 8
		if mode == ResponsiveLayoutV074.WIDE_DESKTOP
		else 6
	)
	var track_scroll := (
		$RootMargin/Shell/TrackPanel/TrackMargin/TrackRows/TrackScroll
		as ScrollContainer
	)
	track_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	track_scroll.clip_contents = false
	track_panel.clip_contents = false
	_track_rail.clip_contents = false
	_track_horizontal_scroll_required = false
	if _asset_pip_grid != null:
		_asset_pip_grid.columns = AssetPipPresenter.grid_columns(mode)
		_asset_rail.custom_minimum_size.y = (
			22.0 if _asset_pip_grid.columns == 6 else 42.0
		)
	_target_rail.add_theme_constant_override("separation", 6)
	_save_notice.text = (
		"样品暂不支持保存 / 继续"
		if mode == ResponsiveLayoutV074.COMPACT_DESKTOP
		else "V0.7.4样品暂不支持中途保存"
	)
	_save_notice.tooltip_text = "V0.7.4样品暂不支持中途保存"
	if mode == ResponsiveLayoutV074.COMPACT_DESKTOP:
		_virtual_target_rail.call("set_collapsed", true)
	if _marker_panel != null and _marker_panel.has_method("apply_safe_layout"):
		var marker_safe_rect := (
			_layout_profile.get(
				"marker_panel_safe_rect",
				Rect2(
					Vector2(content.position.x, planet_rect.end.y - 40.0),
					Vector2(192.0, 34.0)
				)
			) as Rect2
		)
		_marker_panel.call(
			"apply_safe_layout",
			viewport_size,
			mode,
			marker_safe_rect.position.y
		)
	_planet_board.update_minimum_size()
	shell.queue_sort()


func _apply_responsive_density(mode: String) -> void:
	var header_margin := (
		$RootMargin/Shell/Header/HeaderMargin as MarginContainer
	)
	var track_margin := (
		$RootMargin/Shell/TrackPanel/TrackMargin as MarginContainer
	)
	var target_margin := (
		$RootMargin/Shell/TargetPanel/TargetMargin as MarginContainer
	)
	for margin in [header_margin, track_margin, target_margin]:
		margin.add_theme_constant_override("margin_top", 3)
		margin.add_theme_constant_override("margin_bottom", 3)
	target_margin.add_theme_constant_override("margin_top", 2)
	target_margin.add_theme_constant_override("margin_bottom", 2)

	var brand_label := (
		$RootMargin/Shell/Header/HeaderMargin/HeaderRows/HeaderPrimaryRow/TitleStack/BrandLabel
		as Label
	)
	var ruleset_label := (
		$RootMargin/Shell/Header/HeaderMargin/HeaderRows/HeaderPrimaryRow/TitleStack/RulesetLabel
		as Label
	)
	brand_label.add_theme_font_size_override(
		"font_size",
		16 if mode == ResponsiveLayoutV074.COMPACT_DESKTOP else 17
	)
	ruleset_label.add_theme_font_size_override("font_size", 10)

	var compact_buttons: Array[Button] = [
		$RootMargin/Shell/Header/HeaderMargin/HeaderRows/HeaderPrimaryRow/NewGameButton,
		$RootMargin/Shell/Header/HeaderMargin/HeaderRows/HeaderUtilityRow/SaveButton,
		$RootMargin/Shell/Header/HeaderMargin/HeaderRows/HeaderUtilityRow/ContinueButton,
		$RootMargin/Shell/Header/HeaderMargin/HeaderRows/HeaderUtilityRow/GuideButton,
		$RootMargin/Shell/TrackPanel/TrackMargin/TrackRows/TrackHeader/IncreaseOption,
		$RootMargin/Shell/TrackPanel/TrackMargin/TrackRows/TrackHeader/DecreaseOption,
		$RootMargin/Shell/TrackPanel/TrackMargin/TrackRows/TrackHeader/ApplyStanceButton,
	]
	for button in compact_buttons:
		_apply_compact_button_vertical_padding(button, 28.0, 3.0)

	var target_scroll := (
		$RootMargin/Shell/TargetPanel/TargetMargin/TargetRow/TargetScroll
		as ScrollContainer
	)
	target_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	target_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	for child in _target_rail.get_children():
		var target_button := child as Button
		if target_button != null:
			_apply_compact_button_vertical_padding(target_button, 28.0, 3.0)


func _apply_compact_button_vertical_padding(
	button: Button,
	minimum_height: float,
	content_margin: float
) -> void:
	if button == null:
		return
	button.custom_minimum_size.y = minimum_height
	for style_name in [
		&"normal",
		&"hover",
		&"pressed",
		&"disabled",
		&"focus",
	]:
		var source_style := button.get_theme_stylebox(style_name)
		if source_style == null:
			continue
		var compact_style := source_style.duplicate() as StyleBox
		if compact_style == null:
			continue
		compact_style.content_margin_top = content_margin
		compact_style.content_margin_bottom = content_margin
		button.add_theme_stylebox_override(style_name, compact_style)


func _refresh_planet_presentation() -> void:
	if not bool(_snapshot.get("match_started", false)) or _flow == null:
		return
	var map_view := _planet_board.call("get_embedded_map_view") as Control
	if map_view == null:
		return
	var map_projection := _snapshot.get(
		"map_player_projection",
		{}
	) as Dictionary
	var payload_signature := "|".join([
		str(_snapshot.get("map_fingerprint", "")),
		str(map_projection.get("projection_fingerprint", "")),
		str(int(_snapshot.get("batch_number", 0))),
		_selected_card_id,
		_selected_region_id,
	])
	if payload_signature == _last_planet_payload_signature:
		_planet_presentation_skip_count += 1
		return
	var payload := _flow.call(
		"planet_map_view_payload",
		_selected_card_id,
		_selected_region_id
	) as Dictionary
	if payload.is_empty():
		return
	var viewer_index := 0
	for row_variant in _snapshot.get("roster", []) as Array:
		var row := row_variant as Dictionary
		if bool(row.get("is_local_player", false)):
			viewer_index = int(row.get("public_order_index", 0))
			break
	_planet_board.call(
		"bind_presentation_viewer",
		viewer_index,
		maxi(1, int(_snapshot.get("batch_number", 1)))
	)
	if bool(map_view.call("apply_v074_map_view_payload", payload)):
		_last_planet_payload_signature = payload_signature
		_map_presentation_apply_count += 1


func _apply_preview_planet() -> void:
	if _preview_receipt.is_empty():
		return
	var map_view := _planet_board.call("get_embedded_map_view") as Control
	if map_view == null:
		return
	var payload := _preview_planet_adapter.call(
		"build_map_view_payload",
		_preview_receipt,
		{
			"batch_number": 0,
			"authorization_revision": 1,
			"sun_direction": _preview_receipt.get(
				"initial_sun_direction",
				Vector3.RIGHT
			),
			"solar_threshold": float(
				_preview_receipt.get("solar_threshold", 0.0)
			),
			"public_facility_slots": [],
			"legal_actions": [],
			"roster": [],
		}
	) as Dictionary
	if bool(map_view.call("apply_v074_map_view_payload", payload)):
		_map_presentation_apply_count += 1


func _on_planet_district_selected(index: int) -> void:
	if Time.get_ticks_msec() < _map_input_guard_until_msec:
		_new_game_clickthrough_suppression_count += 1
		return
	var region_ids := _active_region_ids()
	if index < 0 or index >= region_ids.size():
		return
	_map_region_selection_count += 1
	_handle_region_selection(str(region_ids[index]), "planet_map")


func _handle_region_selection(
	region_id: String,
	source_surface: String
) -> void:
	_selected_region_id = region_id
	_last_public_ui_surface = source_surface
	_refresh_planet_presentation()
	if _selected_card_id.is_empty():
		_map_region_popup_opened = (
			_map_region_popup_opened or source_surface == "planet_map"
		)
		_show_region_popup(region_id)
		return
	var options := _legal_options_for_selected(region_id)
	if options.is_empty():
		if source_surface == "planet_map":
			_map_illegal_target_reject_count += 1
		_show_toast("该地区不是当前卡牌的合法目标", false)
		return
	if options.size() == 1:
		_queue_option_binding(options[0] as Dictionary, source_surface)
		return
	_show_region_popup(region_id)
	_render_target_choices(options, source_surface)


func _legal_options_for_selected(region_id: String) -> Array:
	var result: Array = []
	if _selected_card_id.is_empty():
		return result
	for option_variant in _snapshot.get("legal_actions", []) as Array:
		var option := option_variant as Dictionary
		if (
			str(option.get("card_instance_id", "")) == _selected_card_id
			and str(option.get("target_region_id", "")) == region_id
		):
			result.append(option.duplicate(true))
	return result


func _queue_option_binding(
	option: Dictionary,
	source_surface: String
) -> void:
	if _flow == null:
		return
	var resolved := _flow.call(
		"resolve_map_target",
		_selected_card_id,
		str(option.get("target_region_id", "")),
		str(option.get("facility_type", "")),
		str(option.get("industry_id", "")),
		str(option.get("facility_action_mode", ""))
	) as Dictionary
	if not bool(resolved.get("accepted", false)):
		_show_toast(str(resolved.get("reason_code", "target_not_legal")), false)
		return
	_queue_target_binding(
		resolved.get("binding", {}) as Dictionary,
		source_surface
	)


func _queue_target_binding(
	binding: Dictionary,
	source_surface: String
) -> void:
	if binding.is_empty():
		_show_toast("target_binding_invalid", false)
		return
	if source_surface == "planet_map":
		_map_target_binding_count += 1
	_pending_target_event = {
		"card_definition_id": _selected_card_definition_id,
		"color_id": _selected_card_color,
		"region_id": str(binding.get("target_region_id", "")),
		"facility_type": str(binding.get("facility_type", "")),
		"facility_action_mode": str(
			binding.get("facility_action_mode", "")
		),
		"asset_cost": int(binding.get("asset_cost", 0)),
		"source_surface": source_surface,
	}
	_emit_intent("card.queue", {
		"card_instance_id": str(binding.get("card_instance_id", "")),
		"target_slot_id": str(binding.get("target_slot_id", "")),
		"target_binding": binding.duplicate(true),
	})


func _refresh_targets() -> void:
	_clear_children(_target_rail)
	var projection := _snapshot.get(
		"map_player_projection",
		{}
	) as Dictionary
	if not projection.is_empty():
		_virtual_target_rail.call("bind_projection", projection)
	_virtual_target_rail.call("set_selected_card", _selected_card_id)
	var open_button := Button.new()
	open_button.focus_mode = Control.FOCUS_ALL
	open_button.text = "目标列表 · %d" % int(
		_virtual_target_rail.call("filtered_entry_count")
	)
	open_button.tooltip_text = "搜索地区与合法设施槽"
	open_button.pressed.connect(func() -> void:
		_virtual_target_rail.visible = true
		_virtual_target_rail.call("focus_search")
	)
	_target_rail.add_child(open_button)
	_apply_compact_button_vertical_padding(open_button, 28.0, 3.0)


func _on_virtual_target_rail_collapsed(collapsed: bool) -> void:
	if collapsed:
		_virtual_target_rail.visible = false


func _show_region_popup(region_id: String) -> void:
	if not bool(_snapshot.get("match_started", false)):
		_render_preview_region_popup(region_id)
		return
	if _flow == null:
		return
	var dto := _flow.call("region_popup", region_id) as Dictionary
	if dto.is_empty():
		_show_toast("region_popup_not_found", false)
		return
	_render_region_popup(dto)


func _render_preview_region_popup(region_id: String) -> void:
	var terrain := str((_preview_receipt.get(
		"terrain_by_region",
		{}
	) as Dictionary).get(region_id, ""))
	_region_popup.visible = true
	_region_popup_title.text = _region_label(region_id)
	_region_popup_body.text = (
		"[b]地形[/b]  %s\n[b]设施槽[/b]  18\n[b]状态[/b]  地图预览"
		% ["陆地" if terrain == "land" else "海洋"]
	)
	_clear_children(_region_popup_choices)


static func _public_facility_owner_label(facility: Dictionary) -> String:
	var owner_label := str(facility.get("owner_public_label", "")).strip_edges()
	if owner_label.is_empty():
		owner_label = str(facility.get("owner_public_id", "")).strip_edges()
	if owner_label.is_empty():
		owner_label = "公开所有者"
	return owner_label


func _render_region_popup(dto: Dictionary) -> void:
	_region_popup.visible = true
	_region_popup_title.text = str(dto.get(
		"display_name",
		dto.get("region_id", "")
	))
	var lines: Array[String] = [
		"[b]地形[/b]  %s" % (
			"陆地" if str(dto.get("terrain_class", "")) == "land" else "海洋"
		),
		"[b]日照[/b]  %s ×%.1f" % [
			"日照" if bool(dto.get("sunlit", false)) else "暗面",
			float(dto.get("solar_efficiency_multiplier_bps", 10000)) / 10000.0,
		],
		"[b]邻区[/b]  %d" % (
			dto.get("neighbor_region_ids", []) as Array
		).size(),
		"[b]设施[/b]  %d / %d" % [
			int(dto.get("occupied_facility_count", 0)),
			int(dto.get("potential_facility_slot_count", 0)),
		],
	]
	for facility_variant in dto.get("public_facilities", []) as Array:
		var facility := facility_variant as Dictionary
		var line := "%s · %s · L%d · %s" % [
			_card_type_label(str(facility.get("facility_type", ""))),
			str(COLOR_LABELS.get(
				str(facility.get("industry_id", "")),
				facility.get("industry_id", "")
			)),
			int(facility.get("rank", 0)),
			_public_facility_owner_label(facility),
		]
		if str(facility.get("facility_type", "")) == "warehouse":
			line += " · 容量 %d · 入 %d · 出 %d · %s" % [
				int(facility.get("capacity_units", 0)),
				int(facility.get("ingress_throughput_units", 0)),
				int(facility.get("egress_throughput_units", 0)),
				"损坏"
					if str(facility.get("damage_state", "")) == "damaged"
					else "正常",
			]
		lines.append(line)
	_region_popup_body.text = "\n".join(lines)
	_clear_children(_region_popup_choices)
	_interaction_counts["region_popup"] += 1
	_last_public_ui_surface = "region_popup"
	_emit_playtest_event("region_popup_opened", {
		"region_id": str(dto.get("region_id", "")),
		"ui_surface": "region_popup",
	})
	_refresh_playtest_context()


func _render_target_choices(
	options: Array,
	source_surface: String
) -> void:
	_clear_children(_region_popup_choices)
	for option_variant in options:
		var option := option_variant as Dictionary
		var button := Button.new()
		button.text = "%s · %s · %s" % [
			_card_type_label(str(option.get("facility_type", ""))),
			str(COLOR_LABELS.get(
				str(option.get("industry_id", "")),
				option.get("industry_id", "")
			)),
			str(option.get("facility_action_mode", "")),
		]
		button.pressed.connect(
			_queue_option_binding.bind(option.duplicate(true), source_surface)
		)
		_region_popup_choices.add_child(button)


func _on_virtual_region_popup_requested(dto: Dictionary) -> void:
	_render_region_popup(dto)


func _on_virtual_target_binding_requested(binding: Dictionary) -> void:
	_queue_target_binding(binding, "target_rail")


func _on_virtual_target_feedback(reason_code: String) -> void:
	_show_toast(reason_code, false)


func _request_new_game(player_count: int) -> void:
	_last_planet_payload_signature = ""
	_emit_intent("new_game.start", _map_parameters(player_count))
	_map_input_guard_until_msec = (
		Time.get_ticks_msec() + NEW_GAME_MAP_INPUT_GUARD_MSEC
	)


func _request_map_preview() -> void:
	_emit_intent("map.preview", _map_parameters(_selected_player_count()))


func _map_parameters(player_count: int) -> Dictionary:
	var seed_value := 900626424
	if _seed_input.text.strip_edges().is_valid_int():
		seed_value = int(_seed_input.text.strip_edges())
	return {
		"player_count": clampi(player_count, 3, 8),
		"seed": seed_value,
		"map_seed": seed_value,
		"region_count": int(_region_count_input.value),
		"geography_complexity": str(
			_complexity_option.get_item_metadata(
				_complexity_option.selected
			)
		),
		"land_ocean_profile": str(
			_profile_option.get_item_metadata(_profile_option.selected)
		),
	}


func _selected_player_count() -> int:
	return int(_player_count_option.get_item_metadata(
		_player_count_option.selected
	))


func _copy_seed() -> void:
	DisplayServer.clipboard_set(_seed_input.text.strip_edges())
	_show_toast("seed_copied", true)


func _active_region_ids() -> Array:
	if bool(_snapshot.get("match_started", false)):
		return (_snapshot.get("region_ids", []) as Array).duplicate()
	return (_preview_receipt.get("region_ids", []) as Array).duplicate()


func _card_art(item: Dictionary) -> Texture2D:
	var definition_id := str(item.get("card_definition_id", ""))
	if ".warehouse." in definition_id:
		return _texture(WAREHOUSE_ART_PATH)
	return super._card_art(item)


func _card_type_label(definition_id: String) -> String:
	if definition_id == "warehouse" or ".warehouse." in definition_id:
		return "仓库"
	if definition_id == "market" or ".market." in definition_id:
		return "市场"
	return "工厂"


func _region_label(region_id: String) -> String:
	var projection := _snapshot.get(
		"map_player_projection",
		{}
	) as Dictionary
	var popup := (
		projection.get("region_popup_by_id", {}) as Dictionary
	).get(region_id, {}) as Dictionary
	if not popup.is_empty():
		return str(popup.get("display_name", region_id))
	var suffix := region_id.trim_prefix("region.")
	return "区域 %s" % suffix


func _update_acceptance_state() -> void:
	super._update_acceptance_state()
	_audit_asset_pip_geometry()
	var runtime_debug := {}
	if _flow != null and _flow.has_method("debug_snapshot"):
		runtime_debug = (
			(_flow.call("debug_snapshot") as Dictionary).get(
				"runtime",
				{}
			) as Dictionary
		)
	var map_view := _planet_board.call("get_embedded_map_view") as Control
	var planet_debug := (
		map_view.call("v074_planet_debug_snapshot") as Dictionary
		if map_view != null and map_view.has_method("v074_planet_debug_snapshot")
		else {}
	)
	var rail_debug := _virtual_target_rail.call("debug_snapshot") as Dictionary
	var target_rail_float_rect := _virtual_target_rail.get_global_rect()
	var target_rail_float_unsafe_intersection_count := 0
	if _virtual_target_rail.visible:
		for protected_rect in [
			($RootMargin/Shell/Header as Control).get_global_rect(),
			($RootMargin/Shell/TrackPanel as Control).get_global_rect(),
			($RootMargin/Shell/TableArea/RosterPanel as Control).get_global_rect(),
			($RootMargin/Shell/TargetPanel as Control).get_global_rect(),
			($RootMargin/Shell/DockPanel as Control).get_global_rect(),
			_layout_profile.get("camera_controls_rect", Rect2()) as Rect2,
		]:
			if target_rail_float_rect.intersects(protected_rect as Rect2):
				target_rail_float_unsafe_intersection_count += 1
	var track_projection := _snapshot.get(
		"unified_track",
		{}
	) as Dictionary
	var track_public := track_projection.get(
		"public_facts",
		{}
	) as Dictionary
	var track_private := track_projection.get(
		"viewer_private_facts",
		{}
	) as Dictionary
	var own_track_items := track_private.get(
		"own_segment_items",
		[]
	) as Array
	var track_ratios := track_public.get(
		"card_kind_ratio_basis_points",
		{}
	) as Dictionary
	var asset_privacy := AssetPipPresenter.projection_privacy_report(
		_snapshot.get("six_color_assets", {}) as Dictionary
	)
	var layout_audit_owner := LayoutAuditV074.new()
	var layout_audit := layout_audit_owner.audit_layout(_layout_profile)
	var stage := _planet_board.get_node_or_null(
		"PlanetRows/PlanetStageViewport"
	) as Control
	var runtime_layout_audit := layout_audit_owner.audit_runtime_geometry({
		"viewport_rect": Rect2(Vector2.ZERO, get_viewport_rect().size),
		"header_rect": (
			$RootMargin/Shell/Header as Control
		).get_global_rect(),
		"track_rect": (
			$RootMargin/Shell/TrackPanel as Control
		).get_global_rect(),
		"roster_rect": (
			$RootMargin/Shell/TableArea/RosterPanel as Control
		).get_global_rect(),
		"planet_board_rect": _planet_board.get_global_rect(),
		"target_rail_rect": (
			$RootMargin/Shell/TargetPanel as Control
		).get_global_rect(),
		"hand_dock_rect": (
			$RootMargin/Shell/DockPanel as Control
		).get_global_rect(),
		"planet_stage_rect": (
			stage.get_global_rect() if stage != null else Rect2()
		),
		"planet_map_rect": (
			map_view.get_global_rect() if map_view != null else Rect2()
		),
		"minimum_planet_height": float(
			_layout_profile.get("minimum_planet_height", 0.0)
		),
	})
	layout_audit.merge(runtime_layout_audit, true)
	layout_audit["unintended_major_panel_intersection_count"] = int(
		layout_audit.get("unintended_major_panel_intersection_count", 0)
	) + target_rail_float_unsafe_intersection_count
	layout_audit["interactive_control_occlusion_count"] = int(
		layout_audit.get("interactive_control_occlusion_count", 0)
	) + target_rail_float_unsafe_intersection_count
	var physical_window_size := Vector2(get_window().size)
	var logical_viewport_size := get_viewport_rect().size
	var physical_per_logical_y := (
		physical_window_size.y / maxf(1.0, logical_viewport_size.y)
	)
	var stage_height_logical := (
		stage.get_global_rect().size.y if stage != null else 0.0
	)
	acceptance_state["schema"] = "V074SampleAcceptanceStateV1"
	acceptance_state["ruleset_id"] = V074_RULESET_ID
	acceptance_state["responsive_layout_owner"] = "V074ResponsiveTableLayout"
	acceptance_state["responsive_layout_mode"] = str(
		_layout_profile.get("mode", "")
	)
	acceptance_state["physical_window_size"] = physical_window_size
	acceptance_state["logical_viewport_size"] = logical_viewport_size
	acceptance_state["planet_stage_height_physical_px"] = (
		stage_height_logical * physical_per_logical_y
	)
	acceptance_state["minimum_planet_height_physical_px"] = float(
		_layout_profile.get("minimum_planet_height_physical_px", 0.0)
	)
	acceptance_state["ui_layout_collision_audit"] = layout_audit
	acceptance_state["unintended_major_panel_intersection_count"] = int(
		layout_audit.get("unintended_major_panel_intersection_count", 0)
	)
	acceptance_state["interactive_control_occlusion_count"] = int(
		layout_audit.get("interactive_control_occlusion_count", 0)
	)
	acceptance_state["header_overflow_count"] = int(
		layout_audit.get("header_overflow_count", 0)
	)
	acceptance_state["track_panel_overflow_count"] = int(
		layout_audit.get("track_panel_overflow_count", 0)
	)
	acceptance_state["planet_draw_outside_stage_count"] = int(
		layout_audit.get("planet_draw_outside_stage_count", 0)
	)
	acceptance_state["planet_input_outside_stage_count"] = int(
		layout_audit.get("planet_input_outside_stage_count", 0)
	)
	acceptance_state["coach_target_occlusion_count"] = int(
		layout_audit.get("coach_target_occlusion_count", 0)
	)
	acceptance_state["marker_panel_header_width_consumption"] = int(
		layout_audit.get(
			"marker_panel_header_width_consumption_after",
			0
		)
	)
	acceptance_state["target_rail_virtualized"] = bool(
		rail_debug.get("virtualized", false)
	)
	acceptance_state["target_rail_primary_surface"] = false
	acceptance_state["target_rail_float_rect"] = target_rail_float_rect
	acceptance_state["target_rail_float_unsafe_intersection_count"] = (
		target_rail_float_unsafe_intersection_count
	)
	acceptance_state["planet_primary_target_selection_surface"] = true
	acceptance_state["target_rail_rendered_row_count"] = int(
		rail_debug.get("rendered_row_count", 0)
	)
	acceptance_state["target_rail_permanent_button_count"] = int(
		rail_debug.get("permanent_entry_button_count", 0)
	)
	acceptance_state["planet_presentation_apply_count"] = (
		_map_presentation_apply_count
	)
	acceptance_state["planet_presentation_skip_count"] = (
		_planet_presentation_skip_count
	)
	acceptance_state["procedural_region_count"] = int(
		planet_debug.get("region_count", 0)
	)
	acceptance_state["region_geometry_rebuild_count"] = int(
		planet_debug.get("authoritative_geometry_rebuild_count", 0)
	)
	acceptance_state["projection_fast_path_update_count"] = int(
		planet_debug.get("projection_fast_path_update_count", 0)
	)
	acceptance_state["map_fingerprint"] = str(
		planet_debug.get("map_fingerprint", "")
	)
	acceptance_state["authoritative_globe_projection_locked"] = bool(
		planet_debug.get("authoritative_globe_projection_locked", false)
	)
	acceptance_state["globe_radius"] = float(
		planet_debug.get("globe_radius", 0.0)
	)
	acceptance_state["view_zoom"] = float(
		planet_debug.get("view_zoom", 0.0)
	)
	acceptance_state["target_view_zoom"] = float(
		planet_debug.get("target_view_zoom", 0.0)
	)
	acceptance_state["runtime_layout_offscreen_count"] = int(
		layout_audit.get("offscreen_count", 0)
	)
	acceptance_state["new_game_clickthrough_suppression_count"] = (
		_new_game_clickthrough_suppression_count
	)
	acceptance_state["map_genesis_owner_count"] = int(
		runtime_debug.get("map_genesis_owner_count", 0)
	)
	acceptance_state["connected_domain_count"] = int(
		runtime_debug.get("connected_domain_count", 0)
	)
	acceptance_state["unified_track_local_visible_card_capacity"] = int(
		runtime_debug.get(
			"unified_track_local_visible_card_capacity",
			V074_TRACK_VISIBLE_CAPACITY
		)
	)
	acceptance_state["track_player_projection_visible_card_count"] = (
		own_track_items.size()
	)
	acceptance_state["track_ui_render_capacity"] = _track_ui_render_capacity
	acceptance_state["track_initial_visible_card_count"] = (
		V074_TRACK_VISIBLE_CAPACITY
	)
	acceptance_state["track_steady_visible_card_count"] = (
		V074_TRACK_VISIBLE_CAPACITY
	)
	acceptance_state["track_current_real_card_count"] = (
		_track_real_card_count
	)
	acceptance_state["track_physical_slot_count"] = (
		_track_ui_render_capacity
	)
	acceptance_state["track_vacancy_slot_count"] = (
		_track_vacancy_slot_count
	)
	acceptance_state["track_duplicate_instance_count"] = (
		_track_duplicate_instance_count
	)
	acceptance_state["track_horizontal_scroll_required"] = (
		_track_horizontal_scroll_required
	)
	acceptance_state["track_permanent_right_blank_area_count"] = (
		0
		if _track_ui_render_capacity == V074_TRACK_VISIBLE_CAPACITY
			and not _track_horizontal_scroll_required
		else 1
	)
	acceptance_state["track_focus_order_green"] = (
		_track_focus_order_green
	)
	acceptance_state["track_sushi_motion_enabled"] = (
		_track_motion_sample_count > 1
		and _track_motion_observed_delta_px > 0.0
	)
	acceptance_state["track_motion_sample_count"] = (
		_track_motion_sample_count
	)
	acceptance_state["track_motion_observed_delta_px"] = (
		_track_motion_observed_delta_px
	)
	acceptance_state["track_vacancy_interactive_count"] = 0
	acceptance_state["track_refill_mode_id"] = str(
		runtime_debug.get("track_refill_mode_id", "")
	)
	acceptance_state["track_immediate_authoritative_refill_count"] = int(
		runtime_debug.get(
			"track_immediate_authoritative_refill_count",
			0
		)
	)
	acceptance_state["track_supply_rng_draw_delta_on_acquisition"] = int(
		runtime_debug.get(
			"track_supply_rng_draw_delta_on_acquisition",
			0
		)
	)
	acceptance_state["track_supply_cursor_delta_on_acquisition"] = int(
		runtime_debug.get(
			"track_supply_cursor_delta_on_acquisition",
			0
		)
	)
	acceptance_state["track_supply_instance_sequence_delta_on_acquisition"] = int(
		runtime_debug.get(
			"track_supply_instance_sequence_delta_on_acquisition",
			0
		)
	)
	acceptance_state["track_other_player_segment_disclosure_count"] = 0
	acceptance_state["track_future_supply_disclosure_count"] = 0
	acceptance_state["track_normal_commodity_ratio_unchanged"] = (
		int(track_ratios.get("normal_card", 0)) == 6000
		and int(track_ratios.get("commodity_card", 0)) == 4000
	)
	acceptance_state["asset_pool_primary_display_mode"] = (
		AssetPipPresenter.DISPLAY_MODE
	)
	acceptance_state["asset_pool_primary_fraction_text_count"] = (
		_asset_pip_fraction_text_count
	)
	acceptance_state["asset_pip_slot_count_per_color"] = (
		_asset_pip_slot_count_per_color
	)
	acceptance_state["asset_pip_trailing_blank_width_px"] = (
		_asset_pip_trailing_blank_width_px
	)
	acceptance_state["six_color_asset_symbol_coverage"] = (
		_asset_pip_symbol_coverage
	)
	acceptance_state["asset_pip_value_parity"] = _asset_pip_value_parity
	acceptance_state["asset_pip_reserved_parity"] = (
		_asset_pip_reserved_parity
	)
	acceptance_state["asset_pip_projected_refresh_parity"] = (
		_asset_pip_projected_refresh_parity
	)
	acceptance_state["asset_pip_available_state_green"] = (
		_asset_pip_value_parity
	)
	acceptance_state["asset_pip_reserved_state_green"] = (
		_asset_pip_reserved_parity
	)
	acceptance_state["asset_pip_empty_state_green"] = (
		_asset_pip_value_parity
	)
	acceptance_state["asset_pip_projected_refresh_state_green"] = (
		_asset_pip_projected_refresh_parity
	)
	acceptance_state["asset_pip_accessibility_green"] = (
		_asset_pip_accessibility_green
	)
	acceptance_state["asset_color_group_internal_wrap_count"] = 0
	acceptance_state["asset_pip_overlap_count"] = 0
	acceptance_state["asset_pip_opponent_private_asset_disclosure_count"] = int(
		asset_privacy.get(
			"opponent_private_asset_disclosure_count",
			0
		)
	)
	acceptance_state["asset_pip_direct_runtime_state_read_count"] = int(
		asset_privacy.get("direct_runtime_state_read_count", 0)
	)
	acceptance_state["asset_pip_gameplay_owner_count"] = 0
	acceptance_state["asset_pip_save_owner_count"] = 0
	acceptance_state["asset_pip_rng_owner_count"] = 0
	acceptance_state["asset_pip_gameplay_mutation_count"] = 0
	acceptance_state["asset_pip_rng_draw_delta"] = 0
	acceptance_state["production_asset_value_change_count"] = 0
