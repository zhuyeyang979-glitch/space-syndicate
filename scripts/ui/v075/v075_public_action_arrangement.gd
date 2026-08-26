extends SpaceSyndicateCardResolutionTrack
class_name V075PublicActionArrangement

signal public_entry_hovered(entry: Dictionary)
signal card_drop_requested(payload: Dictionary)
signal resolution_focus_ready(receipt: Dictionary, focus_global_rect: Rect2)
signal card_transition_started(transition_id: String, evidence: Dictionary)
signal card_transition_finished(transition_id: String, evidence: Dictionary)
signal resolution_presentation_started(receipt: Dictionary, evidence: Dictionary)
signal resolution_presentation_finished(receipt_id: String, evidence: Dictionary)

const InteractiveCardFaceScene := preload(
	"res://scenes/ui/v075/V075InteractiveCardFace.tscn"
)
const CardDefinitions := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)
const PresentationReceiptIdentity := preload(
	"res://scripts/v075/presentation/v075_presentation_receipt_identity_v2.gd"
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
const DRAWER_MAX_VIEWPORT_HEIGHT_RATIO := 0.78
const DRAWER_MAX_VIEWPORT_WIDTH_RATIO := 0.28
const COLLAPSED_HANDLE_WIDTH := 52.0
const COLLAPSED_HANDLE_HEIGHT := 48.0
const DRAWER_SAFE_EDGE_MARGIN := 6.0
const RESOLUTION_FOCUS_SCALE := 1.32
const RESOLUTION_FOCUS_MS := 240
const RESOLUTION_EFFECT_MS := 420
const RESOLUTION_SETTLED_MS := 260
const RESOLUTION_AUTO_CLOSE_SECONDS := 1.05

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
var _last_user_toggle_reason := ""
var _popout_initialized := false
var _popout_mode := "COLLAPSED"
var _peek_generation := 0
var _submission_window_active := false
var _drag_drop_active := false
var _popout_host: Control
var _pending_source_transitions: Dictionary = {}
var _started_source_transition_ids: Dictionary = {}
var _inflight_source_transition_card_ids: Dictionary = {}
var _pending_anchor_transitions: Dictionary = {}
var _inflight_anchor_transition_ids: Dictionary = {}
var _active_transition_records: Dictionary = {}
var _presentation_session_generation := 0
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
var _target_selection_collapse_active := false
var _resolution_window_active := false
var _resolution_batch_id := ""
var _resolution_revision := -1
var _resolution_receipt_queue: Array[Dictionary] = []
var _resolution_seen_receipts: Dictionary = {}
var _resolution_current_receipt: Dictionary = {}
var _resolution_focus_face: V075InteractiveCardFace
var _resolution_stage := "IDLE"
var _resolution_generation := 0
var _resolution_focus_global_rect := Rect2()
var _resolution_focus_count := 0
var _resolution_effect_presented_count := 0
var _resolution_terminal_count := 0
var _resolution_current_terminal_count := 0
var _resolution_duplicate_suppression_count := 0
var _resolution_collision_count := 0
var _resolution_prestart_failure_count := 0
var _resolution_stage_history: Array[String] = []


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
	_popout_card_rail.add_theme_constant_override(
		"separation",
		int(round(CARD_OVERLAP))
	)
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
	privacy_text := "匿名牌只显示公开状态；归属公开后才显示名称。",
	projection_context: Dictionary = {}
) -> void:
	_build_popout()
	var raw_phase := str(projection_context.get("phase", ""))
	var projection_signature := {
		"phase": raw_phase,
		"batch_id": str(projection_context.get("batch_id", "")),
		"revision": int(projection_context.get("revision", -1)),
	}
	var state := {
		"title": "公开排列",
		"phase": phase_text,
		"summary": summary_text,
		"entries": entries,
		"privacy_hint": privacy_text,
		"empty_text": "等待玩家出牌 · 牌会在这里形成排列",
	}
	var signature := var_to_str({
		"state": state,
		"projection_context": projection_signature,
	})
	if signature == _last_public_signature:
		return
	var had_content := not _last_public_signature.is_empty()
	var previous_entry_count := _last_public_entry_count
	_last_public_signature = signature
	_last_entries = entries.duplicate(true)
	_arrangement_update_count += 1
	_last_public_entry_count = entries.size()
	_last_public_phase = phase_text
	var resolving_phase := raw_phase == "resolving" or phase_text == "结算中"
	var submission_phase := raw_phase == "submission" or phase_text in ["30秒·悬停", "submission"]
	if not str(projection_context.get("batch_id", "")).is_empty():
		_resolution_batch_id = str(projection_context.get("batch_id", ""))
	_resolution_revision = int(projection_context.get("revision", _resolution_revision))
	if submission_phase and not entries.is_empty():
		# The public batch is a 30-second inspectable arrangement.  Keep the
		# bounded drawer available for the whole submission window; the user may
		# still explicitly collapse it or use the map-target collapse path.
		_submission_window_active = true
		_cancel_peek()
		if not _popout_user_toggled or _drag_drop_active:
			_set_popout_expanded(true, false)
	elif _submission_window_active and not submission_phase and not resolving_phase:
		_submission_window_active = false
		if not _resolution_window_active and not _popout_pinned and not _drag_drop_active and not _popout_user_toggled:
			_set_popout_expanded(false, true)
	if resolving_phase and not entries.is_empty():
		# A locked public batch is a player-facing resolution state.  Expand the
		# existing bounded overlay automatically; this is presentation only and
		# does not alter the authoritative phase or queue.
		_resolution_window_active = true
		_target_selection_collapse_active = false
		_popout_user_toggled = false
		_last_user_toggle_reason = "resolution_auto_open"
		_cancel_peek()
		if not _popout_expanded:
			_set_popout_expanded(true, true)
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
		and not resolving_phase
		and not _popout_user_toggled
		and not _popout_pinned
		and (previous_entry_count < entries.size() or not had_content)
	):
		# New public cards get a short, discoverable PEEK.  The stable default
		# remains collapsed, so repeated projection refreshes cannot reopen the
		# drawer forever or cover the planet.
		_schedule_peek()
	if resolving_phase and not entries.is_empty():
		_update_resolution_header()


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


func reset_for_new_game(reason := "new_game") -> void:
	## Pair every already-started surface with one cancellation finish before the
	## Screen clears its bridge/Director ledgers. Pending work has not emitted a
	## start signal and is discarded without fabricating a finish.
	_presentation_session_generation += 1
	_peek_generation += 1
	for transition_id_variant in _active_transition_records.keys().duplicate():
		var transition_id := str(transition_id_variant)
		var record := (
			_active_transition_records.get(transition_id, {}) as Dictionary
		)
		var tween := record.get("tween") as Tween
		if tween != null and tween.is_valid():
			tween.kill()
		var ghost := record.get("ghost") as V075InteractiveCardFace
		var end_rect := (
			ghost.get_global_rect()
			if is_instance_valid(ghost)
			else record.get("target_rect", Rect2()) as Rect2
		)
		card_transition_finished.emit(transition_id, {
			"schema": "V076PublicCardTransitionFinishV1",
			"transition_id": transition_id,
			"end_rect": end_rect,
			"from_ai_seat": bool(record.get("from_ai_seat", false)),
			"terminal_status": "CANCELLED_%s" % reason.to_upper(),
			"presentation_only": true,
			"gameplay_mutation_count": 0,
			"rng_draw_delta": 0,
			"authority_sequence_delta": 0,
		})
		if is_instance_valid(ghost):
			ghost.queue_free()
	_active_transition_records.clear()
	if not _resolution_current_receipt.is_empty():
		var current_receipt_id := str(_resolution_current_receipt.get(
			"presentation_receipt_id",
			""
		))
		if not current_receipt_id.is_empty():
			var end_rect := (
				_resolution_focus_face.get_global_rect()
				if is_instance_valid(_resolution_focus_face)
				else resolution_sidecar_global_rect()
			)
			resolution_presentation_finished.emit(current_receipt_id, {
				"schema": "V076PublicResolutionPresentationFinishV1",
				"receipt_id": current_receipt_id,
				"end_rect": end_rect,
				"terminal_status": "CANCELLED_%s" % reason.to_upper(),
				"presentation_only": true,
				"gameplay_mutation_count": 0,
				"rng_draw_delta": 0,
				"authority_sequence_delta": 0,
			})
	if is_instance_valid(_resolution_focus_face):
		_resolution_focus_face.queue_free()
	_resolution_focus_face = null
	_resolution_generation += 1
	_resolution_receipt_queue.clear()
	_resolution_seen_receipts.clear()
	_resolution_current_receipt = {}
	_resolution_stage = "IDLE"
	_resolution_stage_history = []
	_resolution_focus_global_rect = Rect2()
	_resolution_window_active = false
	_resolution_batch_id = ""
	_resolution_revision = -1
	_resolution_current_terminal_count = 0
	_resolution_focus_count = 0
	_resolution_effect_presented_count = 0
	_resolution_terminal_count = 0
	_resolution_duplicate_suppression_count = 0
	_resolution_collision_count = 0
	_resolution_prestart_failure_count = 0
	_pending_source_transitions.clear()
	_started_source_transition_ids.clear()
	_inflight_source_transition_card_ids.clear()
	_pending_anchor_transitions.clear()
	_inflight_anchor_transition_ids.clear()
	_known_presentation_ids.clear()
	_hovered_presentation_ids.clear()
	_source_anchor_rects.clear()
	_last_entries = []
	_last_public_signature = ""
	_last_public_entry_count = 0
	_last_public_phase = ""
	_submission_window_active = false
	_drag_drop_active = false
	_target_selection_collapse_active = false
	_popout_user_toggled = false
	_popout_pinned = false
	_last_user_toggle_reason = "new_game_reset"
	_card_transition_count = 0
	_ai_seat_transition_count = 0
	_transition_failure_count = 0
	modulate = Color.WHITE
	if is_instance_valid(_popout_card_rail):
		for child in _popout_card_rail.get_children():
			child.queue_free()
	if _popout_initialized:
		_set_popout_expanded(false, false)
		_update_resolution_header()


func consume_public_resolution_receipt(receipt: Dictionary) -> Dictionary:
	"""Queue one privacy-sanitized public resolution for the presentation theater.

	The RuntimeOwner remains the only rule/effect authority.  This method only
	validates a stable public identity, records an exact-once presentation
	witness, and drives the existing drawer/card-face controls.
	"""
	if not bool(receipt.get("accepted", false)):
		return {"accepted": false, "reason_code": "resolution_receipt_not_accepted"}
	var receipt_id := str(receipt.get(
		"presentation_receipt_id",
		receipt.get(
			"combat_receipt_id",
			receipt.get("receipt_id", receipt.get("anonymous_action_id", ""))
		)
	)).strip_edges()
	if receipt_id.is_empty():
		return {"accepted": false, "reason_code": "resolution_receipt_identity_missing"}
	var fingerprint_source := receipt.duplicate(true)
	fingerprint_source.erase("presentation_fingerprint")
	var fingerprint := PresentationReceiptIdentity.canonical_sha256(
		fingerprint_source
	)
	if _resolution_seen_receipts.has(receipt_id):
		var prior := str(_resolution_seen_receipts.get(receipt_id, ""))
		if prior == fingerprint:
			_resolution_duplicate_suppression_count += 1
			return {"accepted": true, "replayed": true, "reason_code": "resolution_receipt_duplicate_suppressed"}
		_resolution_collision_count += 1
		return {"accepted": false, "reason_code": "resolution_receipt_identity_collision"}
	_resolution_seen_receipts[receipt_id] = fingerprint
	var queued := receipt.duplicate(true)
	queued["presentation_receipt_id"] = receipt_id
	queued["presentation_fingerprint"] = fingerprint
	if _resolution_current_receipt.is_empty() and _resolution_receipt_queue.is_empty():
		_resolution_stage_history = []
	_resolution_receipt_queue.append(queued)
	_resolution_window_active = true
	_target_selection_collapse_active = false
	_popout_user_toggled = false
	_last_user_toggle_reason = "resolution_receipt_auto_open"
	_cancel_peek()
	if not _popout_expanded:
		_set_popout_expanded(true, true)
	if _resolution_current_receipt.is_empty():
		call_deferred("_start_next_resolution_receipt")
	return {"accepted": true, "queued": true, "receipt_id": receipt_id}


func _start_next_resolution_receipt() -> void:
	if not _resolution_current_receipt.is_empty() or _resolution_receipt_queue.is_empty():
		return
	_resolution_current_receipt = _resolution_receipt_queue.pop_front()
	_resolution_generation += 1
	var generation := _resolution_generation
	_resolution_stage = "QUEUED"
	_resolution_current_terminal_count = 0
	_resolution_stage_history.append("QUEUED")
	_update_resolution_header()
	var entry := _resolution_entry_for_receipt(_resolution_current_receipt)
	_resolution_focus_face = _build_resolution_focus_face(entry)
	if _resolution_focus_face == null:
		_fail_resolution_prestart(generation)
		return
	_resolution_stage = "FOCUSED"
	_resolution_stage_history.append("FOCUSED")
	_update_resolution_header()
	var target_size := _resolution_focus_size()
	_resolution_focus_face.size = target_size
	_resolution_focus_face.pivot_offset = target_size * 0.5
	_resolution_focus_face.position = _resolution_focus_position(target_size)
	_resolution_focus_face.scale = Vector2(0.82, 0.82)
	_resolution_focus_face.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var resolution_receipt_id := str(_resolution_current_receipt.get(
		"presentation_receipt_id", ""
	))
	var source_rect := resolution_sidecar_global_rect()
	var target_rect := _resolution_focus_face.get_global_rect()
	if (
		resolution_receipt_id.is_empty()
		or not source_rect.has_area()
		or not target_rect.has_area()
	):
		_fail_resolution_prestart(generation)
		return
	var focus_tween := create_tween()
	focus_tween.set_trans(Tween.TRANS_CUBIC)
	focus_tween.set_ease(Tween.EASE_OUT)
	focus_tween.set_parallel(true)
	focus_tween.tween_property(_resolution_focus_face, "scale", Vector2.ONE, RESOLUTION_FOCUS_MS / 1000.0)
	focus_tween.tween_property(_resolution_focus_face, "modulate", Color.WHITE, RESOLUTION_FOCUS_MS / 1000.0)
	focus_tween.chain().tween_callback(_advance_resolution_stage.bind(generation, entry))
	_resolution_focus_count += 1
	resolution_presentation_started.emit(
		_resolution_current_receipt.duplicate(true),
		{
			"schema": "V076PublicResolutionPresentationStartV1",
			"receipt_id": resolution_receipt_id,
			"source_rect": source_rect,
			"target_rect": target_rect,
			"presentation_only": true,
			"gameplay_mutation_count": 0,
			"rng_draw_delta": 0,
			"authority_sequence_delta": 0,
		}
	)


func _fail_resolution_prestart(generation: int) -> void:
	if generation != _resolution_generation:
		return
	var failed_receipt_id := str(_resolution_current_receipt.get(
		"presentation_receipt_id",
		""
	))
	if not failed_receipt_id.is_empty():
		_resolution_seen_receipts.erase(failed_receipt_id)
	if is_instance_valid(_resolution_focus_face):
		_resolution_focus_face.queue_free()
	_resolution_focus_face = null
	_resolution_focus_global_rect = Rect2()
	_resolution_current_receipt = {}
	_resolution_stage = "IDLE"
	_resolution_prestart_failure_count += 1
	_update_resolution_header()
	if not _resolution_receipt_queue.is_empty():
		call_deferred("_start_next_resolution_receipt")


func _emit_resolution_focus_ready(generation: int) -> void:
	if (
		generation != _resolution_generation
		or not is_instance_valid(_resolution_focus_face)
	):
		return
	_resolution_focus_global_rect = _resolution_focus_face.get_global_rect()
	resolution_focus_ready.emit(
		_resolution_current_receipt.duplicate(true),
		_resolution_focus_global_rect
	)


func _advance_resolution_stage(generation: int, _entry: Dictionary) -> void:
	if generation != _resolution_generation or _resolution_current_receipt.is_empty():
		return
	_emit_resolution_focus_ready(generation)
	_resolution_stage = "RESOLVING"
	_resolution_stage_history.append("RESOLVING")
	_update_resolution_header()
	await get_tree().create_timer(RESOLUTION_EFFECT_MS / 2000.0).timeout
	if generation != _resolution_generation:
		return
	_resolution_stage = "EFFECT_PRESENTED"
	_resolution_stage_history.append("EFFECT_PRESENTED")
	_resolution_effect_presented_count += 1
	_update_resolution_header()
	await get_tree().create_timer(RESOLUTION_EFFECT_MS / 2000.0).timeout
	if generation != _resolution_generation:
		return
	var fizzled := _resolution_receipt_is_fizzle(_resolution_current_receipt)
	_resolution_stage = "FIZZLED" if fizzled else "RESOLVED"
	_resolution_stage_history.append(_resolution_stage)
	_resolution_terminal_count += 1
	_resolution_current_terminal_count += 1
	_update_resolution_header()
	await get_tree().create_timer(RESOLUTION_SETTLED_MS / 1000.0).timeout
	_finish_resolution_receipt(generation)


func _finish_resolution_receipt(generation: int) -> void:
	if generation != _resolution_generation:
		return
	var finished_receipt := _resolution_current_receipt.duplicate(true)
	var finished_receipt_id := str(finished_receipt.get(
		"presentation_receipt_id", ""
	))
	var finished_rect := (
		_resolution_focus_face.get_global_rect()
		if is_instance_valid(_resolution_focus_face)
		else Rect2()
	)
	if is_instance_valid(_resolution_focus_face):
		_resolution_focus_face.queue_free()
	_resolution_focus_face = null
	_resolution_focus_global_rect = Rect2()
	_resolution_current_receipt = {}
	_resolution_stage = "IDLE"
	_update_resolution_header()
	if not finished_receipt_id.is_empty():
		resolution_presentation_finished.emit(finished_receipt_id, {
			"schema": "V076PublicResolutionPresentationFinishV1",
			"receipt_id": finished_receipt_id,
			"end_rect": finished_rect,
			"terminal_stage_count": _resolution_current_terminal_count,
			"presentation_only": true,
			"gameplay_mutation_count": 0,
			"rng_draw_delta": 0,
			"authority_sequence_delta": 0,
		})
	if not _resolution_receipt_queue.is_empty():
		call_deferred("_start_next_resolution_receipt")
		return
	_resolution_generation += 1
	var close_generation := _resolution_generation
	await get_tree().create_timer(RESOLUTION_AUTO_CLOSE_SECONDS).timeout
	if close_generation != _resolution_generation or not _resolution_current_receipt.is_empty() or not _resolution_receipt_queue.is_empty():
		return
	_resolution_window_active = false
	if not _popout_pinned and not _drag_drop_active and not _popout_user_toggled:
		_set_popout_expanded(false, true)


func _resolution_entry_for_receipt(receipt: Dictionary) -> Dictionary:
	var receipt_id := str(receipt.get("presentation_receipt_id", receipt.get("receipt_id", "")))
	var anonymous_id := str(receipt.get("anonymous_action_id", ""))
	for entry_variant in _last_entries:
		if not (entry_variant is Dictionary):
			continue
		var entry := (entry_variant as Dictionary).duplicate(true)
		if (
			str(entry.get("source_receipt", "")) == receipt_id
			or str(entry.get("id", "")) == anonymous_id
			or str(entry.get("anonymous_action_id", "")) == anonymous_id
		):
			return entry
	var fallback_entry := {
		"id": anonymous_id if not anonymous_id.is_empty() else receipt_id,
		"presentation_correlation_id": receipt_id,
		"source_receipt": receipt_id,
		"label": _resolution_public_label(receipt),
		"owner_hint": "匿名玩家",
		"seat_label": "匿名玩家",
		"state": "RESOLVING",
		"resolution_status": "resolving",
		"detail": _resolution_public_detail(receipt),
		"summary": _resolution_public_detail(receipt),
		"card_face_mode": "back",
		"projection_role": "public_resolution_receipt",
		"public_batch_entry": true,
		"public_card_face_projection": true,
		"accent": "#7fb6ff",
	}
	return fallback_entry


func _build_resolution_focus_face(entry: Dictionary) -> V075InteractiveCardFace:
	if not is_instance_valid(_transition_layer):
		return null
	var face := InteractiveCardFaceScene.instantiate() as V075InteractiveCardFace
	if face == null:
		return null
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.z_index = 130
	face.configure(entry, _face_data_for_entry(entry), false)
	_transition_layer.add_child(face)
	return face


func _resolution_focus_position(target_size: Vector2) -> Vector2:
	var panel_size := _popout_panel.size if is_instance_valid(_popout_panel) else Vector2(CARD_WIDTH, CARD_HEIGHT)
	return Vector2(
		maxf(8.0, (panel_size.x - target_size.x) * 0.5),
		maxf(34.0, (panel_size.y - target_size.y) * 0.5 - 4.0)
	)


func _resolution_focus_size() -> Vector2:
	var panel_size := (
		_popout_panel.size
		if is_instance_valid(_popout_panel)
		else Vector2(CARD_WIDTH, CARD_HEIGHT)
	)
	var max_size := Vector2(
		maxf(1.0, panel_size.x - 20.0),
		maxf(1.0, panel_size.y - 58.0)
	)
	var authored := Vector2(CARD_WIDTH, CARD_HEIGHT) * RESOLUTION_FOCUS_SCALE
	var fit_scale := minf(
		1.0,
		minf(max_size.x / authored.x, max_size.y / authored.y)
	)
	return authored * maxf(0.2, fit_scale)


func _resolution_receipt_is_fizzle(receipt: Dictionary) -> bool:
	var outcome := str(receipt.get("outcome_id", "")).to_lower()
	var reason := str(receipt.get("reason_code", "")).to_lower()
	return outcome.contains("fizz") or reason.contains("fizz") or outcome.contains("invalid")


func _resolution_public_label(receipt: Dictionary) -> String:
	var domain := str(receipt.get("action_domain", "facility"))
	var facility_type := str(receipt.get("facility_type", ""))
	if facility_type.is_empty():
		facility_type = str((receipt.get("action_binding", {}) as Dictionary).get("facility_type", ""))
	if not facility_type.is_empty():
		return {"factory": "工厂", "market": "市场", "warehouse": "仓库"}.get(facility_type, facility_type)
	return "战斗行动" if domain in ["monster", "military"] else "公开行动"


func _resolution_public_detail(receipt: Dictionary) -> String:
	var outcome := str(receipt.get("outcome_id", ""))
	var reason := str(receipt.get("reason_code", ""))
	var region := str(receipt.get("target_region_id", receipt.get("region_id", "")))
	var target := " · %s" % region if not region.is_empty() else ""
	if _resolution_receipt_is_fizzle(receipt):
		return "结算失败：%s%s" % [reason if not reason.is_empty() else "目标无效", target]
	if outcome.contains("facility") or bool(receipt.get("facility_created", false)) or bool(receipt.get("facility_upgraded", false)) or bool(receipt.get("facility_repaired", false)):
		return "设施效果已展示%s" % target
	return "公开效果已展示%s" % target


func _update_resolution_header() -> void:
	if not is_instance_valid(_popout_phase):
		return
	if _resolution_stage == "IDLE":
		_popout_phase.text = _last_public_phase
		return
	var label := _resolution_public_label(_resolution_current_receipt)
	var detail := _resolution_public_detail(_resolution_current_receipt)
	_popout_phase.text = "%s · %s" % [_resolution_stage, label]
	if is_instance_valid(_popout_detail):
		_popout_detail.text = "%s · %s" % [label, detail]


func register_card_source_transition(
	card_instance_id: String,
	presentation_data: Dictionary,
	source_rect: Rect2,
	transition_id := ""
) -> void:
	if card_instance_id.is_empty():
		return
	# A queue intent registers once before the projection edge and once after the
	# receipt is consumed.  Once the same card has already started its visible
	# hand -> arrangement move, the second registration is a duplicate.  The
	# ledger is pruned when that card leaves the public row, so a legitimate
	# remove -> requeue of the same instance can animate again.
	var stable_transition_id := str(transition_id).strip_edges()
	if (
		not stable_transition_id.is_empty()
		and _started_source_transition_ids.has(stable_transition_id)
	):
		return
	_pending_source_transitions[card_instance_id] = {
		"presentation": presentation_data.duplicate(true),
		"source_rect": source_rect,
		"transition_id": stable_transition_id,
		"registered_msec": Time.get_ticks_msec(),
	}
	# The human receipt path registers its source after ApplicationFlow has
	# already applied the authoritative projection.  If the target face is
	# therefore already rendered, trigger the transition immediately instead of
	# waiting for an unrelated later snapshot (which can leave the card looking
	# like it simply appeared in the public row).
	if is_inside_tree() and not _last_entries.is_empty():
		_trigger_pending_transitions(_last_entries)


func set_source_anchor_rects(source_anchor_rects: Dictionary) -> void:
	_source_anchor_rects = source_anchor_rects.duplicate(true)
	_trigger_pending_anchor_transitions()


func arrangement_debug_snapshot() -> Dictionary:
	var base := get_debug_snapshot()
	var sidecar_rect := resolution_sidecar_global_rect()
	var focus_rect := resolution_focus_global_rect()
	var center_guard := _planet_center_guard_rect()
	var center_overlap := (
		sidecar_rect.intersection(center_guard)
		if sidecar_rect.has_area() and center_guard.has_area()
		else Rect2()
	)
	base.merge({
		"active_transition_count": _active_transition_records.size(),
		"pending_source_transition_count": _pending_source_transitions.size(),
		"inflight_source_transition_count": (
			_inflight_source_transition_card_ids.size()
		),
		"pending_anchor_transition_count": _pending_anchor_transitions.size(),
		"inflight_anchor_transition_count": (
			_inflight_anchor_transition_ids.size()
		),
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
		"public_arrangement_user_toggled": _popout_user_toggled,
		"public_arrangement_user_toggle_reason": _last_user_toggle_reason,
		"submission_window_active": _submission_window_active,
		"drag_drop_active": _drag_drop_active,
		"public_drawer_collapsed_handle_anchor": "LEFT_EDGE",
		"resolution_sidecar_anchor": "RIGHT_EDGE_SAFE_RAIL",
		"resolution_sidecar_max_width_ratio": DRAWER_MAX_VIEWPORT_WIDTH_RATIO,
		"resolution_sidecar_max_height_ratio": DRAWER_MAX_VIEWPORT_HEIGHT_RATIO,
		"resolution_sidecar_pushes_map_layout": false,
		"resolution_sidecar_panel_rect": sidecar_rect,
		"resolution_sidecar_center_guard_rect": center_guard,
		"resolution_sidecar_center_occlusion_area_px": (
			center_overlap.size.x * center_overlap.size.y
			if center_overlap.has_area()
			else 0.0
		),
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
		"target_selection_collapse_active": _target_selection_collapse_active,
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
		"resolution_window_active": _resolution_window_active,
		"resolution_stage": _resolution_stage,
		"resolution_batch_id": _resolution_batch_id,
		"resolution_revision": _resolution_revision,
		"resolution_queue_count": _resolution_receipt_queue.size(),
		"resolution_current_receipt_id": str(_resolution_current_receipt.get("presentation_receipt_id", "")),
		"resolution_focus_animation_count": _resolution_focus_count,
		"resolution_focus_global_rect": focus_rect,
		"resolution_focus_within_sidecar": (
			sidecar_rect.has_area()
			and focus_rect.has_area()
			and sidecar_rect.encloses(focus_rect)
		),
		"resolution_focus_over_planet_center": (
			focus_rect.has_area()
			and center_guard.has_area()
			and focus_rect.intersects(center_guard)
		),
		"resolution_effect_presented_count": _resolution_effect_presented_count,
		"resolution_terminal_count": _resolution_terminal_count,
		"resolution_stage_history": _resolution_stage_history.duplicate(),
		"resolution_duplicate_suppression_count": _resolution_duplicate_suppression_count,
		"resolution_collision_count": _resolution_collision_count,
		"resolution_prestart_failure_count": _resolution_prestart_failure_count,
		"resolution_gameplay_mutation_count": 0,
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
	# Exact-once is keyed by the stable public action identity and retired only
	# by an explicit match reset. A transient empty projection must never make a
	# previously animated action eligible to replay.
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
		if _inflight_source_transition_card_ids.has(card_id):
			continue
		var transition := _pending_source_transitions[card_id] as Dictionary
		var entry_transition_id := _entry_presentation_identity(entry)
		var expected_transition_id := str(transition.get(
			"transition_id",
			""
		))
		if (
			entry_transition_id.is_empty()
			or (
				not expected_transition_id.is_empty()
				and expected_transition_id != entry_transition_id
			)
		):
			continue
		if _started_source_transition_ids.has(entry_transition_id):
			_pending_source_transitions.erase(card_id)
			continue
		var source_rect := transition.get("source_rect", Rect2()) as Rect2
		if not source_rect.has_area():
			_transition_failure_count += 1
			continue
		var ghost := InteractiveCardFaceScene.instantiate() as V075InteractiveCardFace
		if ghost == null:
			_transition_failure_count += 1
			continue
		_inflight_source_transition_card_ids[card_id] = true
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.z_index = 120
		ghost.configure(entry, _face_data_for_entry(entry), false)
		_transition_layer.add_child(ghost)
		_begin_card_transition(
			ghost,
			entry,
			source_rect,
			false,
			card_id,
			"SOURCE"
		)


func _trigger_pending_anchor_transitions() -> void:
	if (
		_pending_anchor_transitions.is_empty()
		or _source_anchor_rects.is_empty()
		or not is_inside_tree()
	):
		return
	for presentation_id_variant in _pending_anchor_transitions.keys().duplicate():
		var presentation_id := str(presentation_id_variant)
		if _inflight_anchor_transition_ids.has(presentation_id):
			continue
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
		var ghost := InteractiveCardFaceScene.instantiate() as V075InteractiveCardFace
		if ghost == null or not source_rect.has_area():
			_transition_failure_count += 1
			continue
		_inflight_anchor_transition_ids[presentation_id] = true
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.z_index = 120
		ghost.configure(entry, _face_data_for_entry(entry), false)
		_transition_layer.add_child(ghost)
		_begin_card_transition(
			ghost,
			entry,
			source_rect,
			true,
			presentation_id,
			"ANCHOR"
		)


func _begin_card_transition(
	ghost: V075InteractiveCardFace,
	entry: Dictionary,
	source_rect: Rect2,
	from_ai_seat: bool,
	pending_key: String,
	pending_kind: String
) -> void:
	if ghost == null or not is_instance_valid(ghost) or not source_rect.has_area():
		_transition_failure_count += 1
		_release_transition_attempt(pending_key, pending_kind)
		if is_instance_valid(ghost):
			ghost.queue_free()
		return
	var local_start := (
		_transition_layer.get_global_transform().affine_inverse()
		* source_rect.position
	)
	ghost.position = local_start
	ghost.size = source_rect.size
	call_deferred(
		"_animate_card_transition",
		ghost,
		entry,
		from_ai_seat,
		pending_key,
		pending_kind,
		_presentation_session_generation
	)


func _animate_card_transition(
	ghost: V075InteractiveCardFace,
	entry: Dictionary,
	from_ai_seat: bool,
	pending_key: String,
	pending_kind: String,
	session_generation: int
) -> void:
	if ghost == null or not is_instance_valid(ghost):
		_release_transition_attempt(pending_key, pending_kind)
		return
	await get_tree().process_frame
	if session_generation != _presentation_session_generation:
		_release_transition_attempt(pending_key, pending_kind)
		if is_instance_valid(ghost):
			ghost.queue_free()
		return
	var target := _face_for_entry(entry)
	if target == null:
		_transition_failure_count += 1
		_release_transition_attempt(pending_key, pending_kind)
		ghost.queue_free()
		return
	var target_rect := target.get_global_rect()
	if not target_rect.has_area():
		_transition_failure_count += 1
		_release_transition_attempt(pending_key, pending_kind)
		ghost.queue_free()
		return
	var target_local := _transition_layer.get_global_transform().affine_inverse() * target_rect.position
	var transition_id := _entry_presentation_identity(entry)
	if transition_id.is_empty() or _active_transition_records.has(transition_id):
		_transition_failure_count += 1
		_release_transition_attempt(pending_key, pending_kind)
		ghost.queue_free()
		return
	_commit_transition_attempt(pending_key, pending_kind, transition_id)
	card_transition_started.emit(transition_id, {
		"schema": "V076PublicCardTransitionStartV1",
		"transition_id": transition_id,
		"entry": entry.duplicate(true),
		"source_rect": Rect2(
			_transition_layer.get_global_transform() * ghost.position,
			ghost.size
		),
		"target_rect": target_rect,
		"from_ai_seat": from_ai_seat,
		"presentation_only": true,
		"gameplay_mutation_count": 0,
		"rng_draw_delta": 0,
		"authority_sequence_delta": 0,
	})
	ghost.pivot_offset = ghost.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(ghost, "position", target_local, 0.34)
	tween.tween_property(ghost, "size", target_rect.size, 0.34)
	tween.tween_property(ghost, "modulate", Color(1, 1, 1, 0.0), 0.34)
	_active_transition_records[transition_id] = {
		"tween": tween,
		"ghost": ghost,
		"from_ai_seat": from_ai_seat,
		"target_rect": target_rect,
	}
	tween.chain().tween_callback(
		_emit_card_transition_finished.bind(
			transition_id, target_rect, from_ai_seat, ghost
		)
	)
	_card_transition_count += 1
	if from_ai_seat:
		_ai_seat_transition_count += 1


func _emit_card_transition_finished(
	transition_id: String,
	end_rect: Rect2,
	from_ai_seat: bool,
	ghost: V075InteractiveCardFace
) -> void:
	_active_transition_records.erase(transition_id)
	card_transition_finished.emit(transition_id, {
		"schema": "V076PublicCardTransitionFinishV1",
		"transition_id": transition_id,
		"end_rect": end_rect,
		"from_ai_seat": from_ai_seat,
		"presentation_only": true,
		"gameplay_mutation_count": 0,
		"rng_draw_delta": 0,
		"authority_sequence_delta": 0,
	})
	if is_instance_valid(ghost):
		ghost.queue_free()


func _release_transition_attempt(pending_key: String, pending_kind: String) -> void:
	if pending_kind == "SOURCE":
		_inflight_source_transition_card_ids.erase(pending_key)
	elif pending_kind == "ANCHOR":
		_inflight_anchor_transition_ids.erase(pending_key)


func _commit_transition_attempt(
	pending_key: String,
	pending_kind: String,
	transition_id: String
) -> void:
	_release_transition_attempt(pending_key, pending_kind)
	if pending_kind == "SOURCE":
		_pending_source_transitions.erase(pending_key)
		_started_source_transition_ids[transition_id] = true
	elif pending_kind == "ANCHOR":
		_pending_anchor_transitions.erase(pending_key)


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
	_last_user_toggle_reason = "toggle_button"
	_set_popout_expanded(not _popout_expanded, true)


func _on_pin_pressed() -> void:
	_cancel_peek()
	_popout_pinned = _popout_pin.button_pressed
	if _popout_pinned:
		_popout_user_toggled = true
		_last_user_toggle_reason = "pin_button"
		_set_popout_expanded(true, true)


func _set_popout_expanded(expanded: bool, count_transition: bool) -> void:
	if not expanded and _resolution_window_active:
		# Resolution owns a fail-visible presentation window until its final
		# receipt drains.  Every collapse intent (toggle, Escape, outside click,
		# target selection, drag cleanup, or a stale PEEK timer) converges here, so
		# keep one hard presentation boundary instead of duplicating partial guards
		# across input handlers.  Clearing the transient user override is required:
		# once the final receipt clears `_resolution_window_active`, the existing
		# auto-close path must still be able to collapse normally.
		_cancel_peek()
		_target_selection_collapse_active = false
		_popout_user_toggled = false
		_last_user_toggle_reason = "resolution_collapse_blocked"
		_set_popout_expanded(true, false)
		return
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
	# This is a temporary presentation state, not an explicit user preference.
	# Conflating it with `_popout_user_toggled` kept the drawer collapsed after
	# an accepted card.queue receipt even though the submission window remained
	# active and inspectable.
	_cancel_peek()
	_target_selection_collapse_active = true
	_target_mode_collapse_count += 1
	_set_popout_expanded(false, true)


func restore_after_target_selection() -> void:
	if not _target_selection_collapse_active:
		return
	_target_selection_collapse_active = false
	if (
		_submission_window_active
		and not _popout_pinned
		and not _popout_user_toggled
		and not _drag_drop_active
	):
		_set_popout_expanded(true, false)


func begin_drag_drop_mode() -> Rect2:
	# Native and manual drags share this bounded, presentation-only target.  It
	# never exposes authority state and never turns the full planet viewport into
	# a drop zone.
	if _drag_drop_active:
		return drawer_global_rect()
	_drag_drop_active = true
	_cancel_peek()
	_popout_user_toggled = false
	_last_user_toggle_reason = "drag_drop_reset"
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
	_last_user_toggle_reason = "drawer_handle"
	_set_popout_expanded(true, true)


func _on_drawer_panel_gui_input(event: InputEvent) -> void:
	if _popout_expanded and event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			_drawer_panel_input_intercept_count += 1


func _schedule_peek() -> void:
	if not is_inside_tree() or _popout_pinned or _popout_user_toggled \
		or _submission_window_active or _resolution_window_active:
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
		or _submission_window_active or _resolution_window_active:
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
		# Resolution is a sidecar theatre. Keep it on the right safe rail so the
		# globe center and primary target region remain visible throughout focus.
		_popout_panel.position.x = maxf(
			DRAWER_SAFE_EDGE_MARGIN,
			available_width - drawer_width - DRAWER_SAFE_EDGE_MARGIN
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
		_popout_panel.position.y = maxf(
			DRAWER_SAFE_EDGE_MARGIN,
			(_popout_host.size.y - drawer_height) * 0.5
		)
		_popout_panel.size.y = drawer_height


func _map_visible_area_ratio() -> float:
	if not _popout_expanded:
		return 1.0
	if not is_instance_valid(_popout_host) or not is_instance_valid(_popout_panel):
		return 1.0
	var host_area := _popout_host.size.x * _popout_host.size.y
	if host_area <= 1.0:
		return 1.0
	var panel_size := _popout_panel.get_global_rect().size
	var panel_area := maxf(0.0, panel_size.x) * maxf(0.0, panel_size.y)
	return clampf(1.0 - panel_area / host_area, 0.0, 1.0)


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


func resolution_sidecar_global_rect() -> Rect2:
	return drawer_global_rect()


func resolution_focus_global_rect() -> Rect2:
	if is_instance_valid(_resolution_focus_face):
		_resolution_focus_global_rect = _resolution_focus_face.get_global_rect()
	return _resolution_focus_global_rect


func _planet_center_guard_rect() -> Rect2:
	if get_tree() == null or get_tree().root == null:
		return Rect2()
	var map_view := get_tree().root.find_child("PlanetMapView", true, false) as Control
	if not is_instance_valid(map_view):
		return Rect2()
	var map_rect := map_view.get_global_rect()
	var guard_size := Vector2.ONE * minf(map_rect.size.x, map_rect.size.y) * 0.46
	return Rect2(map_rect.get_center() - guard_size * 0.5, guard_size)


func _input(event: InputEvent) -> void:
	if not _popout_expanded:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			_popout_user_toggled = true
			_last_user_toggle_reason = "escape"
			_set_popout_expanded(false, true)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if (
				not drawer_global_rect().has_point(mouse_event.position)
				and _planet_map_global_rect().has_point(mouse_event.position)
			):
				# An outside click gives the map/hand/track immediate pointer
				# ownership, but it is not the same intent as pressing the drawer's
				# explicit collapse toggle.  Keeping it as a persistent user override
				# prevented the next accepted public card from restoring the still-live
				# submission arrangement.
				_popout_user_toggled = false
				_last_user_toggle_reason = "outside_click_transient"
				_set_popout_expanded(false, true)


func _planet_map_global_rect() -> Rect2:
	if get_tree() == null or get_tree().root == null:
		return Rect2()
	var planet := get_tree().root.find_child(
		"PlanetStageViewport",
		true,
		false
	) as Control
	return planet.get_global_rect() if is_instance_valid(planet) else Rect2()


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
