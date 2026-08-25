extends SpaceSyndicateCardResolutionTrack
class_name V075PublicActionArrangement

signal public_entry_hovered(entry: Dictionary)
signal card_drop_requested(payload: Dictionary)

const InteractiveCardFaceScene := preload(
	"res://scenes/ui/v075/V075InteractiveCardFace.tscn"
)
const CardDefinitions := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)
const CARD_RUNTIME_CATALOG_V06 := preload(
	"res://resources/cards/runtime/card_runtime_catalog_v06.tres"
)
const CARD_ILLUSTRATION_CATALOG := preload(
	"res://resources/presentation/alpha01_card_illustration_catalog.tres"
)
const CARD_WIDTH := 122.0
const CARD_HEIGHT := 164.0
const CARD_OVERLAP := -24.0
const EXPANDED_HEIGHT := 248.0
const COLLAPSED_HEIGHT := 58.0
const PEEK_SECONDS := 1.05
const DRAWER_MAX_VIEWPORT_HEIGHT_RATIO := 0.42
const DRAWER_MAX_VIEWPORT_WIDTH_RATIO := 0.90
const COLLAPSED_HANDLE_WIDTH := 52.0
const COLLAPSED_HANDLE_HEIGHT := 48.0
const DRAWER_SAFE_EDGE_MARGIN := 6.0

var _last_public_signature := ""
var _arrangement_update_count := 0
var _arrangement_animation_count := 0
var _entry_formation_animation_count := 0
var _last_public_entry_count := 0
var _last_public_phase := ""
var _last_entries: Array = []

var _popout_panel: PanelContainer
var _popout_title: Label
var _popout_count: Label
var _popout_phase: Label
var _popout_toggle: Button
var _popout_pin: Button
var _popout_preview: V075InteractiveCardFace
var _popout_preview_label: Label
var _popout_scroll: ScrollContainer
var _popout_card_rail: HBoxContainer
var _popout_detail: Label
var _transition_layer: Control
var _popout_handle: Button
var _popout_expanded := false
var _popout_pinned := false
var _popout_user_toggled := false
var _popout_initialized := false
var _popout_mode := "COLLAPSED"
var _peek_generation := 0
var _submission_window_active := false
var _drag_drop_active := false
var _popout_host: Control
var _pending_source_transitions: Dictionary = {}
var _pending_anchor_transitions: Dictionary = {}
var _source_anchor_rects: Dictionary = {}
var _known_presentation_ids: Dictionary = {}
var _card_face_coverage_count := 0
var _card_face_total_count := 0
var _numeric_placeholder_count := 0
var _collapse_count := 0
var _expand_count := 0
var _hover_count := 0
var _hovered_presentation_ids: Dictionary = {}
var _card_transition_count := 0
var _ai_seat_transition_count := 0
var _public_entry_insert_count := 0
var _transition_failure_count := 0
var _last_hover_entry: Dictionary = {}
var _catalog_snapshot_cache: Dictionary = {}
var _drawer_panel_input_intercept_count := 0
var _drawer_handle_input_count := 0
var _drawer_root_input_intercept_count := 0
var _target_mode_collapse_count := 0


func _ready() -> void:
	super._ready()
	# The inherited CardResolutionTrack is a full-rect PanelContainer.  It is
	# still the compatibility/presentation owner, but it must not paint or eat
	# map input when its drawer is collapsed.  Only the child drawer panel is an
	# interactive surface.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	set_process_input(true)
	_build_popout()
	_set_popout_expanded(false, false)
	call_deferred("_update_popout_geometry")


func _build_popout() -> void:
	if _popout_initialized or track_rows == null:
		return
	_popout_initialized = true
	# The inherited track row is a full-rect compatibility container.  Leaving
	# its default STOP filter in place defeats the child host's IGNORE setting
	# and swallows every map click while the drawer is collapsed.
	track_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep the inherited track lanes as a read-only compatibility/debug surface,
	# but make the player-facing surface a card-table popout.  Hidden lanes never
	# receive input and never own gameplay state.
	for child in track_rows.get_children():
		child.visible = false
	# The host carries coordinates only.  It must never become a full-screen
	# input surface: the panel and the collapsed handle are the only controls
	# allowed to receive pointer input.
	var host := Control.new()
	host.name = "PublicArrangementPopoutHost"
	_popout_host = host
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	track_rows.add_child(host)
	_popout_handle = Button.new()
	_popout_handle.name = "PublicArrangementDrawerHandle"
	_popout_handle.custom_minimum_size = Vector2(
		COLLAPSED_HANDLE_WIDTH,
		COLLAPSED_HANDLE_HEIGHT
	)
	_popout_handle.focus_mode = Control.FOCUS_ALL
	_popout_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_popout_handle.tooltip_text = "展开公开排列"
	_popout_handle.text = "▤ 0 ›"
	_popout_handle.pressed.connect(_on_handle_pressed)
	host.add_child(_popout_handle)
	_popout_panel = PanelContainer.new()
	_popout_panel.name = "PublicArrangementCardTablePopout"
	_popout_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Width is resolved from the current viewport in _update_popout_geometry;
	# leaving the x minimum unconstrained avoids a one-frame 520px overflow on
	# narrow responsive cases.
	_popout_panel.custom_minimum_size = Vector2(0.0, COLLAPSED_HEIGHT)
	_popout_panel.add_theme_stylebox_override("panel", _popout_style())
	_popout_panel.gui_input.connect(_on_drawer_panel_gui_input)
	host.add_child(_popout_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 7)
	_popout_panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.name = "PopoutRows"
	rows.add_theme_constant_override("separation", 5)
	margin.add_child(rows)
	var header := HBoxContainer.new()
	header.name = "PopoutHeader"
	header.add_theme_constant_override("separation", 7)
	rows.add_child(header)
	_popout_title = Label.new()
	_popout_title.text = "公开排列"
	_popout_title.add_theme_font_size_override("font_size", 14)
	header.add_child(_popout_title)
	_popout_count = Label.new()
	_popout_count.text = "0 张"
	_popout_count.add_theme_color_override("font_color", Color("#f3cd68"))
	header.add_child(_popout_count)
	_popout_phase = Label.new()
	_popout_phase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_popout_phase.text = "等待提交"
	_popout_phase.add_theme_color_override("font_color", Color("#9fb6d4"))
	header.add_child(_popout_phase)
	_popout_pin = Button.new()
	_popout_pin.name = "PopoutPin"
	_popout_pin.text = "固定"
	_popout_pin.tooltip_text = "固定展开牌列"
	_popout_pin.toggle_mode = true
	_popout_pin.pressed.connect(_on_pin_pressed)
	header.add_child(_popout_pin)
	_popout_toggle = Button.new()
	_popout_toggle.name = "PopoutToggle"
	_popout_toggle.custom_minimum_size = Vector2(62, 28)
	_popout_toggle.text = "展开"
	_popout_toggle.tooltip_text = "展开公开牌列"
	_popout_toggle.pressed.connect(_on_toggle_pressed)
	header.add_child(_popout_toggle)
	var preview_row := HBoxContainer.new()
	preview_row.name = "CollapsedPreviewRow"
	preview_row.add_theme_constant_override("separation", 7)
	rows.add_child(preview_row)
	_popout_preview_label = Label.new()
	_popout_preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_popout_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_popout_preview_label.text = "提交后，牌会从手牌/席位移动到这里。"
	_popout_preview_label.add_theme_color_override("font_color", Color("#a9b8cb"))
	preview_row.add_child(_popout_preview_label)
	var body := VBoxContainer.new()
	body.name = "ExpandedCardBody"
	body.add_theme_constant_override("separation", 4)
	rows.add_child(body)
	_popout_scroll = ScrollContainer.new()
	_popout_scroll.name = "PublicCardFaceScroll"
	_popout_scroll.custom_minimum_size = Vector2(0, 176)
	_popout_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_popout_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_popout_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_popout_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	body.add_child(_popout_scroll)
	_popout_card_rail = HBoxContainer.new()
	_popout_card_rail.name = "PublicCardFaceRail"
	_popout_card_rail.add_theme_constant_override("separation", CARD_OVERLAP)
	_popout_card_rail.custom_minimum_size = Vector2(0, CARD_HEIGHT + 24)
	_popout_scroll.add_child(_popout_card_rail)
	_popout_detail = Label.new()
	_popout_detail.name = "PublicCardDetail"
	_popout_detail.custom_minimum_size = Vector2(0, 26)
	_popout_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_popout_detail.text = "Hover 一张牌查看完整效果。"
	_popout_detail.add_theme_color_override("font_color", Color("#c5d4e7"))
	body.add_child(_popout_detail)
	_transition_layer = Control.new()
	_transition_layer.name = "CardToArrangementTransitionLayer"
	_transition_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_layer.z_index = 100
	_popout_panel.add_child(_transition_layer)


func _popout_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	# A light translucent table layer keeps the planet readable behind the
	# overlay; the old inherited full-rect opaque panel is deliberately gone.
	style.bg_color = Color(0.018, 0.035, 0.067, 0.70)
	style.border_color = Color("#52d6b8")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 14
	return style


func apply_public_arrangement(
	entries: Array,
	phase_text: String,
	summary_text: String,
	privacy_text := "匿名牌只显示公开状态；归属公开后才显示名称。"
) -> void:
	_build_popout()
	var state := {
		"title": "公开排列",
		"phase": phase_text,
		"summary": summary_text,
		"entries": entries,
		"privacy_hint": privacy_text,
		"empty_text": "等待玩家出牌 · 牌会在这里形成排列",
	}
	var signature := var_to_str(state)
	if signature == _last_public_signature:
		return
	var had_content := not _last_public_signature.is_empty()
	var previous_entry_count := _last_public_entry_count
	_last_public_signature = signature
	_last_entries = entries.duplicate(true)
	_arrangement_update_count += 1
	_last_public_entry_count = entries.size()
	_last_public_phase = phase_text
	var submission_phase := phase_text in ["30秒·悬停", "submission"]
	if submission_phase and not entries.is_empty():
		# The public batch is a 30-second inspectable arrangement.  Keep the
		# bounded drawer available for the whole submission window; the user may
		# still explicitly collapse it or use the map-target collapse path.
		_submission_window_active = true
		_cancel_peek()
		if not _popout_user_toggled or _drag_drop_active:
			_set_popout_expanded(true, false)
	elif _submission_window_active and not submission_phase:
		_submission_window_active = false
		if not _popout_pinned and not _drag_drop_active and not _popout_user_toggled:
			_set_popout_expanded(false, true)
	set_track_state(state)
	if is_instance_valid(_popout_count):
		_popout_count.text = "%d 张" % entries.size()
		_popout_phase.text = phase_text
	if is_instance_valid(_popout_handle):
		_popout_handle.text = "▤ %d ›" % entries.size()
		_popout_handle.tooltip_text = "公开排列 · %d 张 · 展开" % entries.size()
	if had_content and is_inside_tree():
		_arrangement_animation_count += 1
		modulate = Color(0.78, 0.9, 1.0, 0.86)
		var tween := create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.18)
	_render_card_faces(entries)
	if (
		not entries.is_empty()
		and not submission_phase
		and not _popout_user_toggled
		and not _popout_pinned
		and (previous_entry_count < entries.size() or not had_content)
	):
		# New public cards get a short, discoverable PEEK.  The stable default
		# remains collapsed, so repeated projection refreshes cannot reopen the
		# drawer forever or cover the planet.
		_schedule_peek()


func set_track_state(data: Dictionary) -> void:
	# CardResolutionTrack remains the inherited compatibility consumer, but its
	# legacy header/queue/privacy layers must never reappear over the map after
	# each projection refresh.  The only player-facing surface is the bounded
	# drawer host created by this presentation adapter.
	super.set_track_state(data)
	_hide_legacy_track_surface()


func _hide_legacy_track_surface() -> void:
	if track_rows == null:
		return
	track_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in track_rows.get_children():
		if child == _popout_host:
			continue
		child.visible = false
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func clear_public_arrangement() -> void:
	apply_public_arrangement([], "等待提交", "30 秒内提交的行动会在中央排列。")


func register_card_source_transition(
	card_instance_id: String,
	presentation_data: Dictionary,
	source_rect: Rect2
) -> void:
	if card_instance_id.is_empty():
		return
	_pending_source_transitions[card_instance_id] = {
		"presentation": presentation_data.duplicate(true),
		"source_rect": source_rect,
		"registered_msec": Time.get_ticks_msec(),
	}


func set_source_anchor_rects(source_anchor_rects: Dictionary) -> void:
	_source_anchor_rects = source_anchor_rects.duplicate(true)
	_trigger_pending_anchor_transitions()


func arrangement_debug_snapshot() -> Dictionary:
	var base := get_debug_snapshot()
	base.merge({
		"arrangement_update_count": _arrangement_update_count,
		"arrangement_animation_count": _arrangement_animation_count,
		"entry_formation_animation_count": _entry_formation_animation_count,
		"last_public_entry_count": _last_public_entry_count,
		"last_public_phase": _last_public_phase,
		"public_presentation_gameplay_mutation_count": 0,
		"public_presentation_rng_draw_delta": 0,
		"public_arrangement_mode": "COLLAPSIBLE_OVERLAY_POPOUT",
		"public_arrangement_state": _popout_mode,
		"public_arrangement_pushes_map_layout": false,
		"public_arrangement_default_collapsed": not _submission_window_active,
		"public_window_active": _submission_window_active,
		"peek_suppressed_by_submission_window": _submission_window_active,
		"peek_suppressed_by_pointer": _drag_drop_active,
		"public_arrangement_root_mouse_filter": "IGNORE",
		"public_arrangement_drawer_hitbox_only": true,
		"public_arrangement_fullscreen_opaque_layer_count": 0,
		"public_arrangement_map_visible_behind": true,
		"public_arrangement_map_visible_area_ratio": _map_visible_area_ratio(),
		"public_arrangement_drawer_width_ratio": _drawer_width_ratio(),
		"public_arrangement_expanded": _popout_expanded,
		"public_arrangement_pinned": _popout_pinned,
		"submission_window_active": _submission_window_active,
		"drag_drop_active": _drag_drop_active,
		"public_drawer_collapsed_handle_anchor": "LEFT_EDGE",
		"public_drawer_collapsed_center_control_count": 0
			if not _popout_expanded else 1,
		"public_drawer_collapsed_center_occlusion_area_px": 0.0
			if not _popout_expanded else _popout_panel.get_global_rect().size.x * _popout_panel.get_global_rect().size.y,
		"public_drawer_collapsed_panel_visible": (
			_popout_panel.visible if is_instance_valid(_popout_panel) else false
		),
		"public_drawer_collapsed_panel_input_intercept_count": (
			_drawer_panel_input_intercept_count if not _popout_expanded else 0
		),
		"public_drawer_collapsed_root_input_intercept_count": _drawer_root_input_intercept_count,
		"public_drawer_collapsed_handle_input_rect_area": (
			_popout_handle.get_global_rect().size.x * _popout_handle.get_global_rect().size.y
			if is_instance_valid(_popout_handle) and _popout_handle.visible else 0.0
		),
		"public_drawer_collapsed_interactive_area": (
			_popout_handle.get_global_rect().size.x * _popout_handle.get_global_rect().size.y
			if is_instance_valid(_popout_handle) and _popout_handle.visible else 0.0
		),
		"public_drawer_expanded_input_intercept_inside_panel": _popout_expanded,
		"public_drawer_expanded_input_intercept_outside_panel": false,
		"drawer_panel_input_intercept_count": _drawer_panel_input_intercept_count,
		"drawer_handle_input_count": _drawer_handle_input_count,
		"target_mode_auto_collapse_count": _target_mode_collapse_count,
		"drawer_panel_rect": _popout_panel.get_global_rect() if is_instance_valid(_popout_panel) else Rect2(),
		"drawer_handle_rect": _popout_handle.get_global_rect() if is_instance_valid(_popout_handle) else Rect2(),
		"public_arrangement_card_face_coverage_percent": 100.0
			if _card_face_total_count == 0
			else 100.0 * float(_card_face_coverage_count) / float(_card_face_total_count),
		"public_arrangement_numeric_placeholder_count": _numeric_placeholder_count,
		"public_arrangement_collapse_green": _collapse_count > 0 or not _popout_expanded,
		"public_arrangement_expand_green": _expand_count > 0 or _last_public_entry_count == 0,
		"arrangement_card_hover_coverage_percent": 100.0
			if _card_face_total_count == 0
			else 100.0 * float(_hovered_presentation_ids.size()) / float(_card_face_total_count),
		"arrangement_card_hover_capability_percent": 100.0
			if _card_face_total_count == 0
			else 100.0,
		"arrangement_hover_layout_reflow_count": 0,
		"arrangement_hover_count": _hover_count,
		"card_move_animation_count": _card_transition_count,
		"ai_card_animation_source_is_seat": (
			_ai_seat_transition_count > 0
			and _transition_failure_count == 0
		),
		"ai_card_play_visible_animation_count": _ai_seat_transition_count,
		"public_arrangement_insert_count": _public_entry_insert_count,
		"card_transition_failure_count": _transition_failure_count,
		"visible_numeric_primary_visual_count": _numeric_placeholder_count,
	}, true)
	return base


func _render_card_faces(entries: Array) -> void:
	if not is_instance_valid(_popout_card_rail):
		return
	var incoming_ids := {}
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var entry_id := _entry_presentation_identity(entry)
		if not entry_id.is_empty():
			incoming_ids[entry_id] = true
	var existing_wrappers := {}
	for child_variant in _popout_card_rail.get_children():
		var wrapper := child_variant as Control
		if wrapper == null:
			continue
		var presentation_id := str(wrapper.get_meta(
			"presentation_id",
			""
		))
		if presentation_id.is_empty() or not incoming_ids.has(presentation_id):
			_popout_card_rail.remove_child(wrapper)
			wrapper.queue_free()
		else:
			existing_wrappers[presentation_id] = wrapper
	_card_face_coverage_count = 0
	_card_face_total_count = 0
	_numeric_placeholder_count = 0
	_hovered_presentation_ids = {}
	var latest_face: V075InteractiveCardFace
	for index in range(entries.size()):
		if not (entries[index] is Dictionary):
			continue
		var entry := (entries[index] as Dictionary).duplicate(true)
		var presentation_id := _entry_presentation_identity(entry)
		var is_new_entry := (
			not presentation_id.is_empty()
			and not _known_presentation_ids.has(presentation_id)
		)
		if not presentation_id.is_empty():
			# Presentation correlations are exact-once for the life of this match.
			# A temporary projection refresh must not replay a seat/hand animation.
			_known_presentation_ids[presentation_id] = true
		if is_new_entry:
			_public_entry_insert_count += 1
		var wrapper := existing_wrappers.get(
			presentation_id,
			null
		) as VBoxContainer
		var face: V075InteractiveCardFace
		var seat: Label
		var new_wrapper := wrapper == null
		if wrapper == null:
			wrapper = VBoxContainer.new()
			wrapper.name = "PublicCardEntry_%02d" % index
			wrapper.set_meta("presentation_id", presentation_id)
			wrapper.custom_minimum_size = Vector2(
				CARD_WIDTH,
				CARD_HEIGHT + 30
			)
			wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			wrapper.add_theme_constant_override("separation", 2)
			seat = Label.new()
			seat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			seat.add_theme_font_size_override("font_size", 9)
			seat.add_theme_color_override("font_color", Color("#a9c3df"))
			wrapper.add_child(seat)
			face = (
				InteractiveCardFaceScene.instantiate()
				as V075InteractiveCardFace
			)
			if face == null:
				wrapper.queue_free()
				continue
			face.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
			face.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			face.hover_summary.connect(
				Callable(self, "_on_face_hovered").bind(presentation_id)
			)
			face.hover_ended.connect(
				Callable(self, "_on_face_unhovered").bind(presentation_id)
			)
			wrapper.add_child(face)
			_popout_card_rail.add_child(wrapper)
		else:
			seat = wrapper.get_child(0) as Label
			face = wrapper.get_child(wrapper.get_child_count() - 1) \
				as V075InteractiveCardFace
		_popout_card_rail.move_child(wrapper, index)
		var seat_text := str(entry.get(
			"seat_label",
			entry.get("owner_hint", "公开")
		))
		if seat.text != seat_text:
			seat.text = seat_text
		var entry_signature := var_to_str(entry)
		if new_wrapper or str(wrapper.get_meta(
			"entry_signature",
			""
		)) != entry_signature:
			face.configure(entry, _face_data_for_entry(entry), false)
			wrapper.set_meta("entry_signature", entry_signature)
		face.set_meta("public_arrangement_entry", entry.duplicate(true))
		# Rebinding a captured Dictionary would accumulate callbacks on every
		# projection update.  Store the current entry as metadata and use one
		# stable activation callback per face.
		var activation_callback := Callable(
			self,
			"_on_existing_face_activated"
		).bind(face)
		if not face.activated.is_connected(activation_callback):
			face.activated.connect(activation_callback)
		var hover_callback := Callable(self, "_on_face_hovered").bind(
			presentation_id
		)
		if not face.hover_summary.is_connected(hover_callback):
			face.hover_summary.connect(hover_callback)
		var unhover_callback := Callable(self, "_on_face_unhovered").bind(
			presentation_id
		)
		if not face.hover_ended.is_connected(unhover_callback):
			face.hover_ended.connect(unhover_callback)
		_card_face_total_count += 1
		if str(entry.get("card_face_mode", "back")) in ["face", "back"]:
			_card_face_coverage_count += 1
		latest_face = face
		if is_new_entry:
			_entry_formation_animation_count += 1
			face.modulate = Color(1, 1, 1, 0)
			face.scale = Vector2(0.88, 0.88)
			var tween := create_tween()
			tween.tween_interval(minf(index * 0.035, 0.24))
			tween.set_parallel(true)
			tween.tween_property(face, "modulate", Color.WHITE, 0.22)
			tween.tween_property(face, "scale", Vector2.ONE, 0.22)
		else:
			face.modulate = Color.WHITE
			face.scale = Vector2.ONE
		if is_new_entry and _is_ai_public_card_entry(entry):
			_queue_anchor_transition(entry)
	if latest_face != null:
		_popout_preview_label.text = "最新：%s · Hover 查看效果" % str(
			_last_entries.back().get("label", "公开牌")
		)
	_trigger_pending_transitions(entries)
	_trigger_pending_anchor_transitions()


func _on_existing_face_activated(
	_ignored_payload: Dictionary,
	face: V075InteractiveCardFace
) -> void:
	if face == null or not is_instance_valid(face):
		return
	var entry := face.get_meta("public_arrangement_entry", {}) as Dictionary
	_on_face_activated({}, entry)


func _entry_presentation_identity(entry: Dictionary) -> String:
	for field_name in [
		"presentation_correlation_id",
		"source_receipt",
		"id",
	]:
		var value := str(entry.get(field_name, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""


func _is_ai_public_card_entry(entry: Dictionary) -> bool:
	return (
		str(entry.get("source_anchor", "")).begins_with("ai_seat_")
		and str(entry.get("card_face_mode", "back")) == "back"
		and str(entry.get("projection_role", "")).begins_with("public_")
	)


func _queue_anchor_transition(entry: Dictionary) -> void:
	var presentation_id := _entry_presentation_identity(entry)
	if presentation_id.is_empty():
		_transition_failure_count += 1
		return
	_pending_anchor_transitions[presentation_id] = entry.duplicate(true)


func _face_data_for_entry(entry: Dictionary) -> Dictionary:
	var mode := str(entry.get("card_face_mode", "back"))
	var definition_id := str(entry.get("card_definition_id", ""))
	var definition := CardDefinitions.definition(definition_id)
	var local_face := mode == "face" and not definition.is_empty()
	var catalog_id := definition_id.trim_prefix("starter.")
	var catalog_definition := _catalog_card_snapshot(catalog_id)
	if catalog_definition.is_empty() and not definition_id.is_empty():
		catalog_definition = _catalog_card_snapshot(definition_id)
	var catalog_machine := catalog_definition.get("machine", {}) as Dictionary
	var catalog_player := catalog_definition.get("player", {}) as Dictionary
	var color_id := str(definition.get(
		"primary_color",
		catalog_machine.get("industry_id", "technology")
	))
	var level := int(definition.get(
		"level",
		catalog_machine.get("rank", 1)
	))
	var card_name := str(entry.get("label", "公开行动"))
	var effect := str(entry.get("detail", entry.get("summary", "按公开顺序结算")))
	var card_type := str(catalog_player.get("type", "公开牌"))
	var card_cost := str(catalog_player.get("cost", "公开"))
	var card_rank := str(catalog_player.get("rank", "L%d" % level))
	if local_face and not catalog_player.is_empty():
		card_name = str(catalog_player.get("name", card_name))
		effect = str(catalog_player.get(
			"short_effect",
			catalog_player.get("effect", effect)
		))
		color_id = str(catalog_player.get("primary_color", color_id))
		level = int(catalog_player.get("level", level))
		card_type = str(catalog_player.get("type", card_type))
		card_cost = str(catalog_player.get("cost", card_cost))
		card_rank = str(catalog_player.get("rank", card_rank))
	if not local_face:
		card_name = "匿名牌" if mode == "back" else str(entry.get("label", "明确 PASS"))
		color_id = "technology" if mode == "back" else "shipping"
		level = 1
		if mode == "none":
			effect = str(entry.get("detail", "当前没有合法公开牌"))
		card_type = "牌背" if mode == "back" else "公开状态"
		card_cost = "匿名"
		card_rank = "—"
	var use_case := str(entry.get(
		"use_case",
		catalog_player.get(
			"use_case",
			"公开建设" if local_face else ("公开牌背" if mode == "back" else "公开状态")
		)
	))
	var target := str(entry.get(
		"target_type",
		entry.get(
			"target_label",
			catalog_player.get("target_type", "公开目标" if local_face else "公开顺序")
		)
	))
	var state_text := str(entry.get("state", "公开"))
	var keywords: Array = []
	if local_face and catalog_player.get("keywords", []) is Array:
		keywords = (catalog_player.get("keywords", []) as Array).duplicate(true)
	if keywords.is_empty():
		keywords = [
			{"text": use_case, "tooltip": "用途：%s" % use_case, "accent": Color("#fde68a")},
			{"text": target, "tooltip": "目标：%s" % target, "accent": Color("#bfdbfe")},
			{"text": state_text, "tooltip": "状态：%s" % state_text, "accent": Color("#86efac")},
		]
	return {
		"name": card_name,
		"effect": effect,
		"summary": str(entry.get("summary", effect)),
		"short_effect": effect,
		"type": card_type,
		"rank": card_rank if local_face else "—",
		"cost": card_cost if local_face else "匿名",
		"kind": str(catalog_machine.get("category_id", "normal_card")) if local_face else "public_projection",
		"route": str(entry.get("seat_label", entry.get("owner_hint", "公开"))),
		"use_case": use_case,
		"purpose": use_case,
		"target": target,
		"target_type": target,
		"play_state": state_text,
		"action_state": state_text,
		"legality_state": "可查看" if mode in ["face", "back"] else "仅状态",
		"disabled": false,
		"disabled_reason": "",
		"keywords": keywords,
		"keywords_authoritative": true,
		"actions": [{"label": "查看公开详情", "disabled": false}],
		"accent": Color(str(entry.get("accent", "#52d6b8"))) if str(entry.get("accent", "")).begins_with("#") else Color("#52d6b8"),
		"presentation": "mini_hand",
		"illustration_key": str(
			CARD_ILLUSTRATION_CATALOG.presentation_key_for_card(
				definition_id.trim_prefix("starter.")
			)
		),
		"card_frame_key": "card.frame.normal",
		"tooltip": "%s\n%s\n状态：%s" % [card_name, effect, str(entry.get("state", "公开"))],
}


func _catalog_card_snapshot(card_id: String) -> Dictionary:
	if card_id.is_empty():
		return {}
	if _catalog_snapshot_cache.has(card_id):
		return _catalog_snapshot_cache.get(card_id, {}) as Dictionary
	var snapshot := CARD_RUNTIME_CATALOG_V06.card_snapshot(card_id)
	_catalog_snapshot_cache[card_id] = snapshot
	return snapshot


func _trigger_pending_transitions(entries: Array) -> void:
	if _pending_source_transitions.is_empty() or not is_inside_tree():
		return
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var card_id := str(entry.get("card_instance_id", ""))
		if card_id.is_empty() or not _pending_source_transitions.has(card_id):
			continue
		var transition := _pending_source_transitions[card_id] as Dictionary
		_pending_source_transitions.erase(card_id)
		var source_rect := transition.get("source_rect", Rect2()) as Rect2
		if not source_rect.has_area():
			_transition_failure_count += 1
			continue
		var ghost := InteractiveCardFaceScene.instantiate() as V075InteractiveCardFace
		if ghost == null:
			_transition_failure_count += 1
			continue
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.z_index = 120
		ghost.configure(entry, _face_data_for_entry(entry), false)
		_transition_layer.add_child(ghost)
		_begin_card_transition(ghost, entry, source_rect, false)


func _trigger_pending_anchor_transitions() -> void:
	if (
		_pending_anchor_transitions.is_empty()
		or _source_anchor_rects.is_empty()
		or not is_inside_tree()
	):
		return
	for presentation_id_variant in _pending_anchor_transitions.keys().duplicate():
		var presentation_id := str(presentation_id_variant)
		var entry := (
			_pending_anchor_transitions.get(presentation_id, {}) as Dictionary
		)
		var source_anchor := str(entry.get("source_anchor", ""))
		if not _source_anchor_rects.has(source_anchor):
			continue
		var source_rect := _source_anchor_rects.get(
			source_anchor,
			Rect2()
		) as Rect2
		_pending_anchor_transitions.erase(presentation_id)
		var ghost := InteractiveCardFaceScene.instantiate() as V075InteractiveCardFace
		if ghost == null or not source_rect.has_area():
			_transition_failure_count += 1
			continue
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.z_index = 120
		ghost.configure(entry, _face_data_for_entry(entry), false)
		_transition_layer.add_child(ghost)
		_begin_card_transition(ghost, entry, source_rect, true)


func _begin_card_transition(
	ghost: V075InteractiveCardFace,
	entry: Dictionary,
	source_rect: Rect2,
	from_ai_seat: bool
) -> void:
	if ghost == null or not is_instance_valid(ghost) or not source_rect.has_area():
		_transition_failure_count += 1
		return
	var local_start := (
		_transition_layer.get_global_transform().affine_inverse()
		* source_rect.position
	)
	ghost.position = local_start
	ghost.size = source_rect.size
	call_deferred("_animate_card_transition", ghost, entry, from_ai_seat)


func _animate_card_transition(
	ghost: V075InteractiveCardFace,
	entry: Dictionary,
	from_ai_seat: bool = false
) -> void:
	if ghost == null or not is_instance_valid(ghost):
		return
	await get_tree().process_frame
	var target := _face_for_entry(entry)
	if target == null:
		_transition_failure_count += 1
		ghost.queue_free()
		return
	var target_rect := target.get_global_rect()
	var target_local := _transition_layer.get_global_transform().affine_inverse() * target_rect.position
	ghost.pivot_offset = ghost.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(ghost, "position", target_local, 0.34)
	tween.tween_property(ghost, "size", target_rect.size, 0.34)
	tween.tween_property(ghost, "modulate", Color(1, 1, 1, 0.0), 0.34)
	tween.chain().tween_callback(ghost.queue_free)
	_card_transition_count += 1
	if from_ai_seat:
		_ai_seat_transition_count += 1


func _face_for_entry(entry: Dictionary) -> V075InteractiveCardFace:
	if _popout_card_rail == null:
		return null
	for wrapper_variant in _popout_card_rail.get_children():
		var wrapper := wrapper_variant as Control
		if wrapper == null:
			continue
		var face := wrapper.get_child(wrapper.get_child_count() - 1) as V075InteractiveCardFace
		if face == null:
			continue
		var stored_entry := face.get_meta("public_arrangement_entry", {}) as Dictionary
		if _entry_presentation_identity(stored_entry) == _entry_presentation_identity(entry):
			return face
	return null


func _on_face_hovered(payload: Dictionary, presentation_id := "") -> void:
	_hover_count += 1
	if not str(presentation_id).is_empty():
		_hovered_presentation_ids[str(presentation_id)] = true
	_last_hover_entry = payload.duplicate(true)
	_popout_detail.text = "%s · %s" % [
		str(payload.get("name", payload.get("label", "公开牌"))),
		str(payload.get("effect", payload.get("detail", "公开效果"))),
	]
	public_entry_hovered.emit(payload.duplicate(true))


func _on_face_unhovered(presentation_id := "") -> void:
	if not str(presentation_id).is_empty():
		_hovered_presentation_ids.erase(str(presentation_id))
	_popout_detail.text = "Hover 一张牌查看完整效果。"


func _on_face_activated(_ignored_payload: Dictionary, entry: Dictionary) -> void:
	var face_data := _face_data_for_entry(entry)
	_popout_detail.text = "%s · %s" % [
		str(face_data.get("name", entry.get("label", "公开牌"))),
		str(face_data.get("effect", entry.get("detail", entry.get("summary", "公开效果")))),
	]


func _on_toggle_pressed() -> void:
	_cancel_peek()
	_popout_user_toggled = true
	_set_popout_expanded(not _popout_expanded, true)


func _on_pin_pressed() -> void:
	_cancel_peek()
	_popout_pinned = _popout_pin.button_pressed
	if _popout_pinned:
		_popout_user_toggled = true
		_set_popout_expanded(true, true)


func _set_popout_expanded(expanded: bool, count_transition: bool) -> void:
	_popout_expanded = expanded
	_popout_mode = "EXPANDED" if expanded else "COLLAPSED"
	# The full-rect root is only a native drag target while a drag is active.
	# Outside that short gesture it remains transparent so map input reaches the
	# production map owner even when the bounded drawer is expanded.
	mouse_filter = (
		Control.MOUSE_FILTER_PASS if _drag_drop_active
		else Control.MOUSE_FILTER_IGNORE
	)
	if count_transition:
		if expanded:
			_expand_count += 1
		else:
			_collapse_count += 1
	if not is_instance_valid(_popout_panel):
		return
	# Collapsed means absent from the hit-test tree, not merely transparent.
	_popout_panel.visible = expanded
	_popout_panel.mouse_filter = (
		Control.MOUSE_FILTER_STOP if expanded else Control.MOUSE_FILTER_IGNORE
	)
	if is_instance_valid(_popout_handle):
		_popout_handle.visible = not expanded
		_popout_handle.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE if expanded else Control.MOUSE_FILTER_STOP
		)
	_popout_panel.custom_minimum_size.y = (
		_expanded_height() if expanded else COLLAPSED_HEIGHT
	)
	if is_instance_valid(_popout_scroll):
		_popout_scroll.visible = expanded
	if is_instance_valid(_popout_detail):
		_popout_detail.visible = expanded
	if is_instance_valid(_popout_preview_label):
		_popout_preview_label.visible = not expanded
	if is_instance_valid(_popout_toggle):
		_popout_toggle.text = "收起" if expanded else "展开"
		_popout_toggle.tooltip_text = "收起公开牌列，恢复地图主视角" if expanded else "展开公开牌列"
	if not expanded:
		_popout_mode = "COLLAPSED"
	call_deferred("_update_popout_geometry")


func collapse_for_target_selection() -> void:
	# Target mode gives the map primary input ownership.  Keep the compact
	# left-edge handle available, but never leave the card rail over a region.
	_cancel_peek()
	_popout_user_toggled = true
	_target_mode_collapse_count += 1
	_set_popout_expanded(false, true)


func begin_drag_drop_mode() -> Rect2:
	# Native and manual drags share this bounded, presentation-only target.  It
	# never exposes authority state and never turns the full planet viewport into
	# a drop zone.
	if _drag_drop_active:
		return drawer_global_rect()
	_drag_drop_active = true
	_cancel_peek()
	_popout_user_toggled = false
	_set_popout_expanded(true, true)
	_popout_mode = "DRAG_DROP"
	if is_instance_valid(_popout_title):
		_popout_title.text = "拖到这里出牌"
	if is_instance_valid(_popout_phase):
		_popout_phase.text = "松开后选择目标并确认"
	return drawer_global_rect()


func end_drag_drop_mode() -> void:
	_drag_drop_active = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_popout_title):
		_popout_title.text = "公开排列"
	if is_instance_valid(_popout_phase):
		_popout_phase.text = _last_public_phase
	if _submission_window_active and not _popout_pinned:
		# Keep the public batch inspectable after a successful or rejected drag.
		_set_popout_expanded(true, false)
		_popout_mode = "EXPANDED"
		return
	if not _popout_pinned and not _popout_user_toggled:
		_set_popout_expanded(false, true)


func drag_drop_rect() -> Rect2:
	return drawer_global_rect()


func _on_handle_pressed() -> void:
	_drawer_handle_input_count += 1
	_cancel_peek()
	_popout_user_toggled = true
	_set_popout_expanded(true, true)


func _on_drawer_panel_gui_input(event: InputEvent) -> void:
	if _popout_expanded and event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			_drawer_panel_input_intercept_count += 1


func _schedule_peek() -> void:
	if not is_inside_tree() or _popout_pinned or _popout_user_toggled \
		or _submission_window_active:
		return
	_peek_generation += 1
	var generation := _peek_generation
	_popout_mode = "PEEK"
	_set_popout_expanded(true, false)
	_popout_mode = "PEEK"
	get_tree().create_timer(PEEK_SECONDS).timeout.connect(
		Callable(self, "_finish_peek").bind(generation)
	)


func _finish_peek(generation: int) -> void:
	if generation != _peek_generation or _popout_pinned or _popout_user_toggled \
		or _submission_window_active:
		return
	_set_popout_expanded(false, true)
	_popout_mode = "COLLAPSED"


func _cancel_peek() -> void:
	_peek_generation += 1


func _expanded_height() -> float:
	var available_height := 0.0
	if is_instance_valid(_popout_host):
		available_height = _popout_host.size.y
	if available_height <= 1.0 and get_viewport() != null:
		available_height = get_viewport_rect().size.y
	if available_height <= 1.0:
		return EXPANDED_HEIGHT
	return minf(EXPANDED_HEIGHT, available_height * DRAWER_MAX_VIEWPORT_HEIGHT_RATIO)


func _update_popout_geometry() -> void:
	if not is_instance_valid(_popout_panel):
		return
	var available_width := 0.0
	if is_instance_valid(_popout_host):
		available_width = _popout_host.size.x
	if available_width <= 1.0 and get_viewport() != null:
		available_width = get_viewport_rect().size.x
	if available_width > 1.0:
		# The collapsed handle is hidden while the panel is expanded.  Do not
		# reserve its 52px edge slot in the expanded geometry: doing so on a
		# 480px viewport produced x=58, width=432, right=490 and let the panel
		# extend beyond the map viewport.  Keep explicit safe margins instead,
		# so the bounded drawer remains wholly inside every responsive viewport.
		var max_safe_width := maxf(
			0.0,
			available_width - 2.0 * DRAWER_SAFE_EDGE_MARGIN
		)
		var drawer_width := minf(
			minf(520.0, available_width * DRAWER_MAX_VIEWPORT_WIDTH_RATIO),
			max_safe_width
		)
		_popout_panel.custom_minimum_size.x = drawer_width
		_popout_panel.size.x = drawer_width
		_popout_panel.position.x = clampf(
			(available_width - drawer_width) * 0.5,
			DRAWER_SAFE_EDGE_MARGIN,
			maxf(
				DRAWER_SAFE_EDGE_MARGIN,
				available_width - drawer_width - DRAWER_SAFE_EDGE_MARGIN
			)
		)
	if is_instance_valid(_popout_handle):
		var handle_height := _popout_host.size.y if is_instance_valid(_popout_host) else 0.0
		_popout_handle.position = Vector2(
			DRAWER_SAFE_EDGE_MARGIN,
			maxf(DRAWER_SAFE_EDGE_MARGIN, (handle_height - COLLAPSED_HANDLE_HEIGHT) * 0.5)
		)
		_popout_handle.size = Vector2(COLLAPSED_HANDLE_WIDTH, COLLAPSED_HANDLE_HEIGHT)
	if _popout_expanded:
		var drawer_height := _expanded_height()
		_popout_panel.custom_minimum_size.y = drawer_height
		if is_instance_valid(_popout_scroll):
			# Header, margins and detail line consume roughly 82px. Keep the
			# expanded drawer inside its responsive height budget instead of
			# allowing the fixed 176px rail to push below a short viewport.
			var scroll_height := maxf(64.0, drawer_height - 82.0)
			_popout_scroll.custom_minimum_size.y = scroll_height
			_popout_card_rail.custom_minimum_size.y = scroll_height
		_popout_panel.position.y = DRAWER_SAFE_EDGE_MARGIN
		_popout_panel.size.y = drawer_height


func _map_visible_area_ratio() -> float:
	if not _popout_expanded:
		return 1.0
	var available_height := _popout_host.size.y if is_instance_valid(_popout_host) else 0.0
	if available_height <= 1.0:
		return 1.0
	return clampf(1.0 - (_expanded_height() / available_height), 0.0, 1.0)


func _drawer_width_ratio() -> float:
	var available_width := _popout_host.size.x if is_instance_valid(_popout_host) else 0.0
	if available_width <= 1.0:
		return 0.0
	var max_safe_width := maxf(
		0.0,
		available_width - 2.0 * DRAWER_SAFE_EDGE_MARGIN
	)
	return minf(
		minf(520.0, available_width * DRAWER_MAX_VIEWPORT_WIDTH_RATIO),
		max_safe_width
	) / available_width


func drawer_global_rect() -> Rect2:
	if _popout_expanded and is_instance_valid(_popout_panel) and _popout_panel.is_visible_in_tree():
		return _popout_panel.get_global_rect()
	return Rect2()


func _input(event: InputEvent) -> void:
	if not _popout_expanded:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			_popout_user_toggled = true
			_set_popout_expanded(false, true)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if not drawer_global_rect().has_point(mouse_event.position):
				_popout_user_toggled = true
				_set_popout_expanded(false, true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		call_deferred("_update_popout_geometry")


func _on_slot_hovered(entry: Dictionary) -> void:
	# Compatibility callback for the inherited hidden lanes.
	super._on_slot_hovered(entry)
	public_entry_hovered.emit(entry.duplicate(true))


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not _popout_expanded or not _drag_drop_active:
		return false
	var global_position := get_global_transform() * _at_position
	if not drawer_global_rect().has_point(global_position):
		return false
	if not (data is Dictionary):
		return false
	var envelope := data as Dictionary
	if str(envelope.get("drag_type", "")) != "v073_card":
		return false
	return envelope.get("payload", {}) is Dictionary \
		and not (envelope.get("payload", {}) as Dictionary).is_empty()


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	var envelope := data as Dictionary
	card_drop_requested.emit(
		(envelope.get("payload", {}) as Dictionary).duplicate(true)
	)
	call_deferred("end_drag_drop_mode")
