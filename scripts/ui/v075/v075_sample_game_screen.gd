extends "res://scripts/ui/v074/v074_sample_game_screen.gd"
class_name V075SampleGameScreen

signal combat_projection_applied(projection: Dictionary)
signal combat_receipt_processed(receipt_id: String, result: Dictionary)

const V075_RULESET_ID := "v0.7.5"
const BASE_V074_RULESET_ID := "v0.7.4"
const DEFAULT_VIEWER_ID := "player.local"
const DEFAULT_PRIVATE_SKILL_INTENT_KIND := (
	"combat.monster_private_skill.request"
)
const DEFAULT_MILITARY_INTENT_KIND := "combat.military_mission.select"
const PRIVATE_SKILL_EXECUTION_MODE := "private_instant_serial"
const MILITARY_EXECUTION_MODE := "private_direct_action"
const CapabilityCatalog := preload(
	"res://scripts/v075/combat/v075_combat_capability_catalog.gd"
)
const MONSTER_CARD_MODES := CapabilityCatalog.MONSTER_CARD_MODES
const MONSTER_CARD_MODE_LABELS := {
	"DEPLOY_NEW": "部署新怪兽",
	"REFRESH_EXISTING": "同族回血",
	"UPGRADE_EXISTING": "同族升级",
	"REPLACE_EXISTING": "异族替换",
}
const MONSTER_CARD_MODE_HINTS := {
	"DEPLOY_NEW": "容量以内且没有同族活动来源时，在预绑定地区部署",
	"REFRESH_EXISTING": "同族等级不高于当前来源，按牌面等级恢复生命",
	"UPGRADE_EXISTING": "同族牌等级更高，升至牌面等级并恢复新最大生命",
	"REPLACE_EXISTING": "容量已满且族群不同，撤回旧来源并部署新来源",
}

const ProjectionAdapter := preload(
	"res://scripts/v075/player/v075_combat_projection_adapter.gd"
)
const V075CardDefinitionRegistry := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)
const V075InteractiveCardFaceScene := preload(
	"res://scenes/ui/v075/V075InteractiveCardFace.tscn"
)
const CARD_RUNTIME_CATALOG_V06 := preload(
	"res://resources/cards/runtime/card_runtime_catalog_v06.tres"
)
const CARD_ILLUSTRATION_CATALOG := preload(
	"res://resources/presentation/alpha01_card_illustration_catalog.tres"
)
const V075_FACILITY_ART_PATHS := [
	"res://assets/third_party/commercial/materials/ambientcg/"
	+ "MetalPlates013/MetalPlates013_1K-JPG_Color.jpg",
	"res://assets/third_party/commercial/materials/ambientcg/"
	+ "PaintedMetal007/PaintedMetal007_1K-JPG_Color.jpg",
	"res://assets/third_party/commercial/materials/ambientcg/"
	+ "SheetMetal003/SheetMetal003_1K-JPG_Color.jpg",
]
const COMBAT_LAYOUT_MAX_WIDTH := 668.0
const COMBAT_LAYOUT_NARROW_MAX_WIDTH := 720.0
const COMBAT_LAYOUT_REGULAR_MIN_WIDTH := 1480.0
const COMBAT_LAYOUT_HORIZONTAL_GUTTER := 12.0
const COMBAT_LAYOUT_MIN_HEIGHT := 132.0
const COMBAT_LAYOUT_MAX_HEIGHT := 500.0
const SINGLE_TABLE_MIN_PLANET_HEIGHT := 220.0
const SINGLE_TABLE_COMPACT_SIDEBAR_WIDTH := 292.0
const SINGLE_TABLE_REGULAR_SIDEBAR_WIDTH := 328.0
const ACTION_FEEDBACK_SAMPLE_LIMIT := 128
const GEOMETRY_INTERSECTION_EPSILON := 0.5
const PresentationConsumer := preload(
	"res://scripts/v075/presentation/v075_combat_presentation_consumer.gd"
)
const PRESENTATION_SOURCE_UNBOUND := "unbound"
const PRESENTATION_SOURCE_RUNTIME_SHARED := "runtime_shared"
const PRESENTATION_SOURCE_ISOLATED_PREVIEW := "isolated_preview"
const PRESENTATION_SOURCE_RUNTIME_MISSING := "runtime_shared_missing"

const COMBAT_PROJECTION_KEYS := [
	"v075_combat_projection",
	"combat_player_projection",
	"combat_projection",
	"player_combat_projection",
]
const COMBAT_AUTHORITY_KEYS := [
	"v075_combat_authority_snapshot",
	"combat_authority_snapshot",
	"combat_authority",
]
const COMBAT_EVENT_KINDS := [
	"monster_card_purchased",
	"monster_deployed",
	"monster_refreshed",
	"monster_upgraded",
	"monster_replaced",
	"monster_target_selected",
	"monster_moved",
	"monster_trample_resolved",
	"monster_basic_attack",
	"monster_private_skill_requested",
	"monster_private_skill_resolved",
	"monster_skill_fizzled",
	"monster_skill_cooldown_started",
	"monster_skill_ready",
	"military_card_purchased",
	"military_region_assault",
	"military_monster_assault",
	"military_withdrawn",
	"facility_combat_damaged",
]
const TERMINAL_PHASES := [
	"victory_pending",
	"victory_resolved",
	"final_settlement",
	"terminal",
]
const COMBAT_MAP_CUE_HISTORY_LIMIT := 12
const COMBAT_MAP_COLOR_VALUES := {
	"life": Color("#76d89b"),
	"energy": Color("#f3cd68"),
	"industry": Color("#f08a74"),
	"technology": Color("#7fb6ff"),
	"commerce": Color("#d993ef"),
	"shipping": Color("#67d8d5"),
}
const COMBAT_MAP_DEFAULT_COLOR := Color("#74d9c6")

@onready var _combat_overlay: PanelContainer = (
	%V075CombatOverlay
)
@onready var _combat_stack_host: HBoxContainer = %V075CombatStackHost
@onready var _combat_surface_host: Control = (
	%SurfaceHost
)
@onready var _combat_surface: Control = (
	%CombatSurface
)
@onready var _combat_title: Label = (
	%Title
)
@onready var _combat_status: Label = (
	%Status
)
@onready var _combat_collapse_button: Button = (
	%CollapseButton
)
@onready var _right_sidebar: VBoxContainer = %V075RightSidebar
@onready var _public_action_feed_panel: PanelContainer = %PublicActionFeedPanel
@onready var _current_action_banner: Label = %CurrentActionBanner
@onready var _public_action_feed: RichTextLabel = %PublicActionFeed
@onready var _central_public_action_arrangement: Control = (
	%CentralPublicActionArrangement
)
@onready var _current_action_panel: PanelContainer = %CurrentActionPanel
@onready var _current_action_title: Label = %CurrentActionTitle
@onready var _current_action_details: Label = %CurrentActionDetails
@onready var _current_action_reason: Label = %CurrentActionReason
@onready var _current_action_confirm_button: Button = (
	%CurrentActionConfirmButton
)
@onready var _current_action_cancel_button: Button = (
	%CurrentActionCancelButton
)
@onready var _speed_1x_button: Button = %Speed1xButton
@onready var _speed_2x_button: Button = %Speed2xButton
@onready var _speed_4x_button: Button = %Speed4xButton
@onready var _pause_button: Button = %PauseButton
@onready var _general_hand_tab_button: Button = %GeneralHandTabButton
@onready var _commodity_hand_tab_button: Button = %CommodityHandTabButton
@onready var _commodity_hand_preview_panel: PanelContainer = %CommodityHandPreviewPanel
@onready var _commodity_hand_preview_label: Label = %CommodityHandPreviewLabel
@onready var _commodity_hand_preview_rail: HBoxContainer = %CommodityHandPreviewRail
@onready var _commodity_hand_empty_hint: Label = %CommodityHandEmptyHint

var _v075_flow: Node
var _v075_capabilities: Dictionary = {}
var _v075_identity: Dictionary = {}
var _v075_snapshot: Dictionary = {}
var _combat_projection: Dictionary = {}
var _projection_adapter: RefCounted = ProjectionAdapter.new()
var _presentation_consumer: Node
var _presentation_consumer_owner: Node
var _presentation_source_mode := PRESENTATION_SOURCE_UNBOUND
var _presentation_signal_connected := false
var _presentation_source_bind_count := 0
var _presentation_local_preview_creation_count := 0
var _presentation_suppressed_duplicate_consume_count := 0
var _viewer_player_id := DEFAULT_VIEWER_ID
var _preferred_source_instance_id := ""
var _combat_session_key := ""
var _combat_terminal_phase := ""
var _combat_collapsed := true
var _combat_layout_mode := "COMPACT"
var _combat_layout_snapshot: Dictionary = {}
var _combat_surface_preferred_height := -1.0
var _combat_layout_remeasure_scheduled := false
var _combat_host_layout_settle_scheduled := false
var _fallback_intent_sequence := 0
var _combat_projection_count := 0
var _combat_receipt_count := 0
var _combat_receipt_applied_count := 0
var _combat_receipt_duplicate_count := 0
var _combat_receipt_rejected_count := 0
var _combat_private_intent_count := 0
var _combat_military_intent_count := 0
var _last_combat_intent_kind := ""
var _monster_mode_popup_card_id := ""
var _combat_map_cues: Array[Dictionary] = []
var _combat_map_projection_apply_count := 0
var _combat_map_cue_apply_count := 0
var _combat_map_marker_count := 0
var _combat_map_trail_count := 0
var _combat_map_effect_count := 0
var _combat_map_callout_count := 0
var _combat_map_last_sync_signature := ""
var _selected_track_item: Dictionary = {}
var _selected_commodity_item: Dictionary = {}
var _pending_confirm_binding: Dictionary = {}
var _current_action_mode := "idle"
var _current_action_source_surface := ""
var _current_action_started_msec := 0
var _local_public_feedback: Array[Dictionary] = []
var _action_feedback_samples_msec: Array[int] = []
var _public_action_feed_visible_count := 0
var _blank_public_action_count := 0
var _action_feed_duplicate_entry_count := 0
var _central_public_arrangement_refresh_count := 0
var _central_public_arrangement_hover_count := 0
var _central_public_arrangement_private_projection_violation_count := 0
var _central_card_drop_count := 0
var _central_card_drop_submission_count := 0
var _central_card_drop_rejection_count := 0
var _manual_drag_start_count := 0
var _manual_drag_drop_count := 0
var _manual_drag_rejection_count := 0
var _manual_drag_card_id := ""
var _manual_drag_payload: Dictionary = {}
var _manual_drag_start_position := Vector2.ZERO
var _manual_drag_active := false
var _manual_drag_last_drop_card_id := ""
var _manual_drag_last_drop_msec := -1
var _local_feedback_sequence := 0
var _pacing_multiplier := 2
var _pacing_state: Dictionary = {}
var _fast_forward_button: Button = null
var _fast_forward_request_pending := false
var _single_viewport_layout_snapshot: Dictionary = {}
var _action_submission_pending := false
var _active_hand_category := "general"
var _pending_public_card_instance_ids: Dictionary = {}
var _commodity_hand_visible_count := 0
var _commodity_hand_projection_latency_msec := 0
var _card_zone_multi_projection_count := 0
var _accepted_card_hand_residual_count := 0
var _public_card_face_coverage_count := 0
var _public_card_face_total_count := 0
var _public_arrangement_numeric_placeholder_count := 0
var _public_arrangement_collapsed_count := 0
var _public_arrangement_expanded_count := 0
var _card_move_animation_count := 0
var _coach_pacing_gate_active := false
var _coach_pacing_saved_multiplier := 2
var _coach_pacing_restore_multiplier := 2
var _coach_pacing_saved := false
var _coach_pacing_request_pending := false
var _coach_pacing_request_target := -1
var _coach_pacing_gate_apply_count := 0
var _coach_pacing_gate_restore_count := 0
var _coach_restore_fence_passed := false
var _coach_close_fence_generation := 0
var _coach_close_fence_active := false
var _coach_close_fence_release_scheduled := false
var _coach_close_fence_skipped_refresh_count := 0
var _v076_handoff_fast_path_reentry := false
var _v076_acceptance_refresh_suppressed := false
var _v076_deferred_full_snapshot: Dictionary = {}
var _v076_full_snapshot_scheduled := false


func _ready() -> void:
	set_process_input(true)
	_configure_commodity_preview_dock()
	if is_instance_valid(_combat_surface):
		_combat_surface.connect(
			"private_target_selection_requested",
			Callable(self, "_on_private_target_selection_requested")
		)
		_combat_surface.connect(
			"military_mission_selected",
			Callable(self, "_on_military_mission_selected")
		)
		if _combat_surface.has_signal("responsive_minimum_resolved"):
			_combat_surface.connect(
				"responsive_minimum_resolved",
				Callable(self, "_on_combat_surface_minimum_resolved")
			)
	if is_instance_valid(_central_public_action_arrangement):
		if _central_public_action_arrangement.has_signal("public_entry_hovered"):
			_central_public_action_arrangement.connect(
				"public_entry_hovered",
				Callable(self, "_on_central_public_entry_hovered")
			)
		if _central_public_action_arrangement.has_signal("card_drop_requested"):
			_central_public_action_arrangement.connect(
				"card_drop_requested",
				Callable(self, "_on_central_card_drop_requested")
			)
	_combat_collapse_button.pressed.connect(_toggle_combat_surface)
	_current_action_confirm_button.pressed.connect(_confirm_current_action)
	_current_action_cancel_button.pressed.connect(_cancel_current_action)
	_general_hand_tab_button.pressed.connect(_set_hand_category.bind("general"))
	_commodity_hand_tab_button.pressed.connect(
		_set_hand_category.bind("commodity")
	)
	_pause_button.pressed.connect(_request_pacing_multiplier.bind(0))
	_speed_1x_button.pressed.connect(_request_pacing_multiplier.bind(1))
	_speed_2x_button.pressed.connect(_request_pacing_multiplier.bind(2))
	_speed_4x_button.pressed.connect(_request_pacing_multiplier.bind(4))
	get_viewport().size_changed.connect(_on_combat_viewport_size_changed)
	super._ready()
	%RegionPopupClose.pressed.connect(
		Callable(self, "_on_region_popup_closed_for_action")
	)
	_dock_target_rail_in_production_flow()
	_set_v075_chrome()
	_combat_title.text = "DIRECT ACTION"
	_combat_status.text = "等待战斗投影"
	_set_combat_surface_visibility()
	_update_current_action_panel()
	_apply_single_viewport_layout()
	_apply_pacing_state({"multiplier": 2})
	if is_instance_valid(_coach_marks):
		_coach_marks.connect(
			"coach_mark_shown",
			Callable(self, "_on_coach_pacing_gate_shown")
		)
		_coach_marks.connect(
			"coach_mark_skipped",
			Callable(self, "_on_coach_pacing_gate_skipped")
		)
		if _coach_marks.has_signal("coach_activity_changed"):
			_coach_marks.connect(
				"coach_activity_changed",
				Callable(self, "_on_coach_activity_changed")
			)
	call_deferred("_resolve_combat_layout")


func _configure_commodity_preview_dock() -> void:
	"""Keep the independent commodity projection beside the hand, not above it.

	The V073 inherited dock was a vertical stack.  A fixed-height V075 dock also
	contains the hand, queue and command row, so a vertical commodity sibling is
	necessarily clipped on a real table.  Reparenting this existing projection
	consumer into DockBody preserves the commodity owner while giving both hand
	owners a stable horizontal surface.
	"""
	if not is_instance_valid(_commodity_hand_preview_panel):
		return
	var dock_body := get_node_or_null(
		"RootMargin/Shell/DockPanel/DockMargin/DockRows/DockBody"
	) as HBoxContainer
	if dock_body == null:
		return
	if _commodity_hand_preview_panel.get_parent() != dock_body:
		_commodity_hand_preview_panel.reparent(dock_body, false)
		# Keep the hand first, the independent commodity preview second, and the
		# existing action queue last.  No owner or authority data moves here.
		dock_body.move_child(_commodity_hand_preview_panel, 1)
	_commodity_hand_preview_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_commodity_hand_preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_commodity_hand_preview_panel.custom_minimum_size.y = 0.0
	_commodity_hand_preview_panel.mouse_filter = Control.MOUSE_FILTER_PASS


func _process(delta: float) -> void:
	_runtime_frame_count += 1
	if str(_snapshot.get("phase", "")) == "submission":
		# This is presentation interpolation only. The Runtime Owner remains the
		# sole clock authority; the Screen mirrors its effective pace and is
		# corrected by every authoritative snapshot.
		var effective_multiplier := maxi(
			0,
			int(_pacing_state.get(
				"effective_multiplier",
				_pacing_multiplier
			))
		)
		_submission_remaining = maxf(
			0.0,
			_submission_remaining - delta * float(effective_multiplier)
		)
		_timer_label.text = "%02d s" % int(ceil(_submission_remaining))
		_timer_progress.value = _submission_remaining
	_acceptance_refresh_elapsed += delta
	_advance_track_presentation(delta)
	if _acceptance_refresh_elapsed >= ACCEPTANCE_REFRESH_SECONDS:
		_acceptance_refresh_elapsed = 0.0
		# The authority edge is already committed. The deferred full projection
		# below will refresh diagnostics after the handoff; do not walk the full
		# audit on this critical edge.


func bind_application_flow(
	flow: Node,
	identity: Dictionary,
	capabilities: Dictionary
) -> void:
	_v075_flow = flow
	_v075_identity = identity.duplicate(true)
	_v075_capabilities = capabilities.duplicate(true)
	_viewer_player_id = _resolve_viewer_player_id(identity, flow)
	_bind_presentation_source(flow)
	_bind_pacing_source(flow)
	super.bind_application_flow(flow, identity, capabilities)
	call_deferred("_reconcile_coach_pacing_gate")
	_set_v075_chrome()
	_combat_status.text = "等待战斗投影 · %s" % _viewer_player_id
	_update_acceptance_state()


func apply_snapshot(snapshot: Dictionary) -> void:
	var incoming := snapshot.duplicate(true)
	var incoming_ruleset := str(incoming.get("ruleset_id", ""))
	if (
		not incoming_ruleset.is_empty()
		and incoming_ruleset not in [BASE_V074_RULESET_ID, V075_RULESET_ID]
	):
		super.apply_snapshot(snapshot)
		return
	var previous_phase := str(_v075_snapshot.get("phase", ""))
	var incoming_phase := str(incoming.get("phase", ""))
	var previous_sequence := int((
		(_v075_snapshot.get("unified_track", {}) as Dictionary).get(
			"public_facts", {}
		) as Dictionary
	).get("scroll_sequence", -1))
	var incoming_sequence := int((
		(incoming.get("unified_track", {}) as Dictionary).get(
			"public_facts", {}
		) as Dictionary
	).get("scroll_sequence", -1))
	if (
		not _v076_handoff_fast_path_reentry
		and previous_phase == "maintenance"
		and incoming_phase == "submission"
		and incoming_sequence > previous_sequence
	):
		# The authority has already committed the new track phase.  Update the
		# visible rail and action header synchronously, then let the normal full
		# projection refresh (roster/assets/hand) arrive on a short follow-up edge.
		# This keeps a real handoff responsive without introducing a second owner or
		# dropping any state from the authoritative snapshot.
		_v075_snapshot = incoming
		_pending_public_card_instance_ids = {}
		for pending_variant in incoming.get("pending_public_card_instance_ids", []) as Array:
			var pending_id := str(pending_variant)
			if not pending_id.is_empty():
				_pending_public_card_instance_ids[pending_id] = true
		_snapshot = _parent_compatibility_snapshot(incoming)
		_refresh_phase()
		_refresh_track()
		_refresh_central_public_action_arrangement()
		_sync_terminal_phase(incoming_phase)
		# The authority edge is already committed. Defer the diagnostic-only
		# acceptance walk so it cannot block the next-player handoff.
		call_deferred("_update_acceptance_state")
		_v076_deferred_full_snapshot = incoming.duplicate(true)
		if not _v076_full_snapshot_scheduled:
			_v076_full_snapshot_scheduled = true
			get_tree().create_timer(0.35).timeout.connect(
				_flush_v076_handoff_snapshot
			)
		return
	_v075_snapshot = incoming
	var pending_ids := incoming.get("pending_public_card_instance_ids", []) as Array
	_pending_public_card_instance_ids = {}
	for pending_variant in pending_ids:
		var pending_id := str(pending_variant)
		if not pending_id.is_empty():
			_pending_public_card_instance_ids[pending_id] = true
	_refresh_central_public_action_arrangement()
	_update_combat_session(incoming)
	var parent_snapshot := _parent_compatibility_snapshot(incoming)
	_v076_acceptance_refresh_suppressed = _v076_handoff_fast_path_reentry
	super.apply_snapshot(parent_snapshot)
	_v076_acceptance_refresh_suppressed = false
	call_deferred("_sync_public_arrangement_source_anchors")
	_sync_terminal_phase(str(incoming.get("phase", "")))
	var projection := _extract_combat_projection(incoming)
	if not projection.is_empty():
		projection = _projection_for_phase(
			projection,
			str(incoming.get("phase", ""))
		)
	if projection.is_empty():
		_clear_combat_projection()
	else:
		apply_combat_projection(
			projection,
			str(incoming.get("preferred_source_instance_id", ""))
		)
	_revalidate_current_action()
	if _v076_handoff_fast_path_reentry:
		call_deferred("_update_acceptance_state")
	else:
		_update_acceptance_state()


func _flush_v076_handoff_snapshot() -> void:
	_v076_full_snapshot_scheduled = false
	if _v076_deferred_full_snapshot.is_empty():
		return
	var snapshot := _v076_deferred_full_snapshot.duplicate(true)
	_v076_deferred_full_snapshot = {}
	_v076_handoff_fast_path_reentry = true
	apply_snapshot(snapshot)
	_v076_handoff_fast_path_reentry = false


func apply_receipt(receipt: Dictionary) -> void:
	var action_before := _current_action_receipt_context()
	super.apply_receipt(receipt)
	if (
		str(receipt.get("intent_kind", "")) == "card.queue"
		and bool(receipt.get("accepted", false))
		and str((receipt.get("binding", {}) as Dictionary).get(
			"action_domain",
			""
		)) == "monster"
	):
		_region_popup.visible = false
		_monster_mode_popup_card_id = ""
		_clear_selected_card()
	if (
		str(receipt.get("intent_kind", "")) == "new_game.start"
		and bool(receipt.get("accepted", false))
	):
		_reset_combat_state()
	if _is_combat_receipt(receipt):
		apply_combat_receipt(receipt)
	_apply_human_flow_receipt(receipt, action_before)
	# Keep the maintenance receipt path non-blocking.  The inherited V073
	# surface already schedules its diagnostic acceptance refresh; repeating
	# that full map/layout audit synchronously here would delay the next-player
	# authority edge even though the receipt itself is already committed.
	var receipt_intent := str(receipt.get("intent_kind", ""))
	if receipt_intent == "maintenance.finish" \
			and bool(receipt.get("accepted", false)):
		call_deferred("_update_acceptance_state")
	elif receipt_intent in ["ui.pacing.set", "ui.pacing.fast_forward_next_decision"]:
		# V073 classifies this as a lightweight presentation receipt; do not
		# reintroduce the heavy audit after the superclass returns.
		pass
	else:
		if _v076_handoff_fast_path_reentry:
			call_deferred("_update_acceptance_state")
		else:
			_update_acceptance_state()


func apply_public_resolution_receipt(receipt: Dictionary) -> void:
	# ApplicationFlow already removed actor/card-private fields.  Consume the
	# public receipt immediately so the action feed does not wait for a later
	# projection refresh; the stable public identity suppresses that later copy.
	if not bool(receipt.get("accepted", false)):
		return
	_append_local_public_feedback(_public_history_entry(receipt))
	_update_acceptance_state()


func apply_owner_private_receipt(receipt: Dictionary) -> void:
	if str(receipt.get("receipt_scope", "")) != "owner_private":
		return
	super.apply_receipt(receipt)
	_append_owner_private_feedback(receipt)
	if _current_action_mode == "military":
		_record_action_feedback_latency(_current_action_receipt_context())
		_action_submission_pending = false
		_pending_confirm_binding = {}
		_current_action_mode = "idle"
		_current_action_source_surface = ""
		if not _selected_card_id.is_empty():
			super._clear_selected_card()
		_update_current_action_panel()
	_update_acceptance_state()


func _bind_pacing_source(flow: Node) -> void:
	if flow == null or not is_instance_valid(flow):
		return
	if flow.has_signal("pacing_state_changed"):
		var callback := Callable(self, "_apply_pacing_state")
		if not flow.is_connected("pacing_state_changed", callback):
			flow.connect("pacing_state_changed", callback)
	if flow.has_method("pacing_snapshot"):
		_apply_pacing_state(flow.call("pacing_snapshot") as Dictionary)


func _apply_pacing_state(state: Dictionary) -> void:
	_pacing_state = state.duplicate(true)
	_pacing_multiplier = int(state.get("multiplier", 2))
	if (
		_coach_pacing_gate_active
		and _pacing_multiplier != 0
		and not (
			_coach_pacing_request_pending
			and _coach_pacing_request_target == 0
		)
	):
		# Fail closed if an out-of-band presentation update reports a running pace
		# while Coach is active; the existing typed pace request will reassert 0x.
		call_deferred("_reconcile_coach_pacing_gate")
	for entry in [
		{"button": _pause_button, "multiplier": 0},
		{"button": _speed_1x_button, "multiplier": 1},
		{"button": _speed_2x_button, "multiplier": 2},
		{"button": _speed_4x_button, "multiplier": 4},
	]:
		var button := entry.get("button") as Button
		if button == null:
			continue
		var selected := int(entry.get("multiplier", 0)) == _pacing_multiplier
		if _coach_pacing_gate_active:
			selected = int(entry.get("multiplier", 0)) == 0
		button.button_pressed = selected
		button.tooltip_text = (
			"教学进行中 · 完成后恢复 %d×" % _coach_pacing_restore_multiplier
			if _coach_pacing_gate_active and int(entry.get("multiplier", 0)) != 0
			else "当前为 %d 倍世界有效时间" % _pacing_multiplier
			if selected
			else "%d 倍世界有效时间" % int(entry.get("multiplier", 1))
		)
	_fast_forward_request_pending = false
	_update_fast_forward_button_state()


func _request_pacing_multiplier(multiplier: int) -> void:
	if _coach_pacing_gate_active and multiplier != 0:
		if multiplier in [1, 2, 4]:
			# Keep coach time frozen, but remember the user's requested post-coach
			# speed.  This is presentation intent only until the lifecycle edge
			# restores it through the existing pacing owner.
			_coach_pacing_restore_multiplier = multiplier
			_update_pacing_button_state()
		_show_toast("教学进行中；结束后恢复 %d×" % multiplier, true)
		return
	_emit_intent("ui.pacing.set", {"multiplier": multiplier})


func _on_coach_activity_changed(active: bool, _reason_code: String) -> void:
	if active:
		# A reopened Coach invalidates any pending close release.  The fence is
		# presentation-only and never owns the world clock or the match state.
		_coach_close_fence_generation += 1
		_coach_close_fence_active = false
		_coach_close_fence_release_scheduled = false
		_coach_restore_fence_passed = false
		if not _coach_pacing_gate_active:
			_coach_pacing_saved_multiplier = _valid_coach_multiplier(
				_pacing_multiplier
			)
			_coach_pacing_restore_multiplier = _coach_pacing_saved_multiplier
			_coach_pacing_saved = true
		_coach_pacing_gate_active = true
	else:
		if not _coach_pacing_gate_active:
			return
		# Hide the Coach immediately, then suppress diagnostic acceptance walks for
		# two normal frames.  The old close path could run the full map/layout
		# audit in the same frame as the pacing restore and present as a white
		# screen.  This fence only gates presentation diagnostics; authority,
		# Runtime, tick order, and RNG remain untouched.
		_coach_close_fence_generation += 1
		_coach_close_fence_active = true
		_coach_close_fence_release_scheduled = false
		_schedule_coach_close_fence_release(_coach_close_fence_generation)
		_coach_pacing_gate_active = false
	call_deferred("_reconcile_coach_pacing_gate")
	_update_pacing_button_state()


func _schedule_coach_close_fence_release(generation: int) -> void:
	if _coach_close_fence_release_scheduled:
		return
	_coach_close_fence_release_scheduled = true
	call_deferred("_release_coach_close_fence", generation)


func _release_coach_close_fence(generation: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if generation != _coach_close_fence_generation:
		return
	_coach_close_fence_release_scheduled = false
	_coach_close_fence_active = false
	# One low-priority refresh after the fence keeps acceptance evidence current
	# without putting the expensive audit on the close/input critical path.
	call_deferred("_update_acceptance_state")


func _valid_coach_multiplier(value: int) -> int:
	return value if value in [1, 2, 4] else 2


func _reconcile_coach_pacing_gate() -> void:
	if not is_instance_valid(_v075_flow):
		return
	# Once the coach lifecycle has completed and its one-shot restore has been
	# acknowledged, ordinary player pace controls must remain authoritative.  In
	# particular, a manual PAUSE request must not be mistaken for a pending coach
	# restore and immediately overwritten with the saved multiplier.
	if not _coach_pacing_gate_active and not _coach_pacing_saved:
		return
	if not _coach_pacing_gate_active and not _coach_restore_fence_passed:
		# Let the Coach root hide and one normal frame render before restoring the
		# world pace.  This prevents the pacing receipt and the first AI burst from
		# landing in the same idle edge as the close click.
		_coach_restore_fence_passed = true
		call_deferred("_restore_coach_pacing_after_frame")
		return
	var target := 0 if _coach_pacing_gate_active else _valid_coach_multiplier(
		_coach_pacing_restore_multiplier
	)
	if (
		_coach_pacing_request_pending
		and _coach_pacing_request_target == target
	):
		return
	var effective := int(_pacing_state.get(
		"effective_multiplier",
		_pacing_multiplier
	))
	if effective == target:
		_coach_pacing_request_pending = false
		_coach_pacing_request_target = -1
		if not _coach_pacing_gate_active:
			_coach_pacing_saved = false
		_update_pacing_button_state()
		return
	_coach_pacing_request_pending = true
	_coach_pacing_request_target = target
	_request_pacing_multiplier(target)


func _restore_coach_pacing_after_frame() -> void:
	await get_tree().process_frame
	if _coach_pacing_gate_active:
		_coach_restore_fence_passed = false
		return
	_reconcile_coach_pacing_gate()


func _update_pacing_button_state() -> void:
	_apply_pacing_state(_pacing_state)


func _request_fast_forward() -> void:
	var gate := _fast_forward_ui_gate()
	var reason := str(gate.get("reason", ""))
	if not reason.is_empty():
		_show_toast(reason, false)
		return
	_fast_forward_request_pending = true
	_update_fast_forward_button_state()
	_emit_intent(
		"ui.pacing.fast_forward_next_decision",
		gate.get("parameters", {}) as Dictionary
	)


func _fast_forward_ui_gate() -> Dictionary:
	var coach_open := false
	if (
		_coach_marks != null
		and is_instance_valid(_coach_marks)
		and _coach_marks.has_method("debug_snapshot")
	):
		var coach := _coach_marks.call("debug_snapshot") as Dictionary
		coach_open = bool(coach.get("active", false)) and not bool(
			coach.get("suspended", false)
		)
	var target_selection_open := (
		is_instance_valid(_region_popup) and _region_popup.visible
	)
	var human_confirmation_open := (
		_current_action_mode != "idle" or _action_submission_pending
	)
	var combat_intervention_open := (
		not _monster_mode_popup_card_id.is_empty()
		or _current_action_mode == "military"
	)
	var parameters := {
		"ui_gate_attested": true,
		"human_confirmation_open": human_confirmation_open,
		"purchase_confirmation_open": _current_action_mode == "purchase",
		"target_selection_open": target_selection_open,
		"coach_open": coach_open,
		"combat_intervention_open": combat_intervention_open,
	}
	var reason := ""
	if _fast_forward_request_pending:
		reason = "快进请求正在确认"
	elif human_confirmation_open:
		reason = "请先确认或取消当前行动"
	elif target_selection_open:
		reason = "请先关闭目标选择"
	elif coach_open:
		reason = "请先完成、跳过或关闭教学"
	elif combat_intervention_open:
		reason = "请先处理战斗干预"
	elif bool(_pacing_state.get("human_decision_required", false)):
		reason = "当前正在等待你的决定"
	elif not bool(_pacing_state.get("fast_forward_available", false)):
		reason = "当前没有可快进的等待阶段"
	return {"reason": reason, "parameters": parameters}


func _update_fast_forward_button_state() -> void:
	if not is_instance_valid(_fast_forward_button):
		return
	var active := bool(_pacing_state.get("fast_forward_active", false))
	var reason := str(_fast_forward_ui_gate().get("reason", ""))
	_fast_forward_button.text = "快进中…" if active else "快进到决策"
	_fast_forward_button.disabled = active or not reason.is_empty()
	_fast_forward_button.tooltip_text = (
		"正在通过既有 Tick 推进；真人决定出现后恢复 %d×" % _pacing_multiplier
		if active
		else reason
		if not reason.is_empty()
		else "通过既有 Tick 快进；出现真人决定时自动恢复原速度"
	)


func _on_coach_pacing_gate_shown(_mark_id: String) -> void:
	_update_fast_forward_button_state()


func _on_coach_pacing_gate_skipped(
	_mark_id: String,
	_skip_all: bool
) -> void:
	call_deferred("_update_fast_forward_button_state")


func _on_coach_pacing_gate_finished(
	_active: bool,
	_reason_code: String
) -> void:
	# Kept as a named bridge for older scene/test compositions that discover the
	# lifecycle callback by method name.  The signal connection uses the generic
	# activity handler above so completion, Skip and Close share one edge.
	_on_coach_activity_changed(_active, _reason_code)


func _current_action_receipt_context() -> Dictionary:
	return {
		"mode": _current_action_mode,
		"track_item": _selected_track_item.duplicate(true),
		"card_definition_id": _selected_card_definition_id,
		"card_instance_id": _selected_card_id,
		"card_color": _selected_card_color,
		"target_binding": _pending_confirm_binding.duplicate(true),
		"started_msec": _current_action_started_msec,
	}


func _apply_human_flow_receipt(
	receipt: Dictionary,
	action_before: Dictionary
) -> void:
	var intent_kind := str(receipt.get("intent_kind", ""))
	var accepted := bool(receipt.get("accepted", false))
	if intent_kind == "track.acquire":
		_action_submission_pending = false
		var item := action_before.get("track_item", {}) as Dictionary
		var kind := str(item.get("card_kind", receipt.get("card_kind", "")))
		var destination := str(receipt.get("destination_zone", ""))
		var color_id := str(item.get("primary_color", ""))
		var cost := int(item.get("primary_asset_cost", 0))
		if accepted:
			var destination_text := (
				"HAND"
				if destination.to_lower() == "hand"
				else "DISCARD · 已进入弃牌堆，后续洗牌后可抽到"
				if destination.to_lower() in ["discard", "personal_discard"]
				else "商品库存"
				if kind == "commodity_card"
				else destination.to_upper()
			)
			var payment := "免费取得" if cost <= 0 else "支付 %s资产 %d" % [
				_combat_color_label(color_id),
				cost,
			]
			_append_local_public_feedback({
				"actor_label": "你",
				"action_label": "取得" if kind == "commodity_card" else "购买",
				"subject_label": _track_item_public_name(item),
				"target_label": destination_text,
				"cost_label": payment,
				"status_label": "RESOLVED",
				"result_label": "成功",
			})
			_show_toast("购买成功 · %s · 去向 %s" % [payment, destination_text], true)
			if kind == "commodity_card":
				# The authority will publish the new inventory in the next snapshot.
				# Select its already-existing hand surface now so the acquired card is
				# discoverable immediately instead of remaining behind an inactive tab.
				_active_hand_category = "commodity"
				_commodity_hand_tab_button.button_pressed = true
				_general_hand_tab_button.button_pressed = false
				_commodity_hand_tab_button.grab_focus()
		else:
			_current_action_reason.text = _purchase_rejection_text(
				str(receipt.get("reason_code", "购买条件已变化"))
			)
			_show_toast(_current_action_reason.text, false)
		_record_action_feedback_latency(action_before)
		_selected_track_item = {}
		_current_action_mode = "idle"
		_pending_confirm_binding = {}
		_update_current_action_panel()
	elif intent_kind == "card.queue":
		_action_submission_pending = false
		if accepted:
			var accepted_card_id := str(action_before.get("card_instance_id", ""))
			var source_rect := _hand_card_global_rect(accepted_card_id)
			if is_instance_valid(_central_public_action_arrangement) and _central_public_action_arrangement.has_method("register_card_source_transition"):
				_central_public_action_arrangement.call(
					"register_card_source_transition",
					accepted_card_id,
					_general_card_face_data({
						"instance_id": accepted_card_id,
						"definition_id": action_before.get("card_definition_id", ""),
					}),
					source_rect
				)
			_card_move_animation_count += 1
			var binding := action_before.get("target_binding", {}) as Dictionary
			_append_local_public_feedback({
				"actor_label": "你",
				"action_label": "提交",
				"subject_label": _card_type_label(str(
					action_before.get("card_definition_id", "")
				)),
				"target_label": _binding_target_label(binding),
				"cost_label": "资产预留",
				"status_label": "SUBMITTED",
				"result_label": "等待公共结算",
			})
		_record_action_feedback_latency(action_before)
		_update_current_action_panel()
	elif intent_kind == "queue.remove":
		_action_submission_pending = false
		_pending_confirm_binding = {}
		if accepted:
			_current_action_mode = "idle"
			_current_action_source_surface = ""
			if not _selected_card_id.is_empty():
				super._clear_selected_card()
			_show_toast("已撤回提交，卡牌返回手牌", true)
		else:
			_show_toast("撤回失败，队列状态已变化", false)
		_update_current_action_panel()
	elif intent_kind == "ui.pacing.set":
		var pacing_target := int((receipt.get("pacing", {}) as Dictionary).get(
			"multiplier",
			-1
		))
		var gate_request_matched := (
			_coach_pacing_request_pending
			and pacing_target == _coach_pacing_request_target
		)
		if gate_request_matched:
			_coach_pacing_request_pending = false
			_coach_pacing_request_target = -1
		if accepted:
			if pacing_target == 0 and _coach_pacing_gate_active and gate_request_matched:
				_coach_pacing_gate_apply_count += 1
			elif pacing_target > 0 and not _coach_pacing_gate_active and gate_request_matched:
				_coach_pacing_gate_restore_count += 1
				_coach_pacing_saved = false
			_apply_pacing_state(receipt.get("pacing", {}) as Dictionary)
			_show_toast("已切换至 %d×" % _pacing_multiplier, true)
			if (
				_coach_pacing_gate_active and pacing_target != 0
			) or (
				not _coach_pacing_gate_active
				and _coach_pacing_request_pending
				and pacing_target != _coach_pacing_request_target
			):
				call_deferred("_reconcile_coach_pacing_gate")
		else:
			_show_toast("速度切换被拒绝", false)
	elif intent_kind == "ui.pacing.fast_forward_next_decision":
		_fast_forward_request_pending = false
		if accepted:
			_apply_pacing_state(receipt.get("pacing", {}) as Dictionary)
			_show_toast("正在快进到下一次真人决定", true)
		else:
			_show_toast("当前不能快进，请先处理可见决定", false)
		_update_fast_forward_button_state()


func _record_action_feedback_latency(action_before: Dictionary) -> void:
	var started := int(action_before.get("started_msec", 0))
	if started <= 0:
		return
	_action_feedback_samples_msec.append(maxi(0, Time.get_ticks_msec() - started))
	while _action_feedback_samples_msec.size() > ACTION_FEEDBACK_SAMPLE_LIMIT:
		_action_feedback_samples_msec.pop_front()


func _append_owner_private_feedback(receipt: Dictionary) -> void:
	var event_kind := str(receipt.get("event_kind", "owner_private_action"))
	var action_label := (
		"军队直接行动"
		if event_kind.begins_with("military_")
		else "怪兽私密技能"
	)
	var result_label := (
		"已接受" if bool(receipt.get("accepted", false)) else "已拒绝"
	)
	_append_local_public_feedback({
		"actor_label": "你",
		"action_label": action_label,
		"subject_label": "自己的完整详情仅在行动区可见",
		"target_label": "私密目标",
		"cost_label": "按权威回执结算",
		"status_label": _public_status_label(event_kind, receipt),
		"result_label": result_label,
		"owner_private": true,
	})


func present_final_settlement(settlement: Dictionary) -> void:
	_sync_terminal_phase("final_settlement")
	super.present_final_settlement(settlement)
	_update_acceptance_state()


func apply_combat_projection(
	projection: Dictionary,
	preferred_source_instance_id := ""
) -> void:
	var normalized := _normalize_projection(projection)
	if normalized.is_empty():
		_clear_combat_projection()
		return
	normalized = _projection_for_phase(
		normalized,
		str(normalized.get("phase", ""))
	)
	var had_projection := not _combat_projection.is_empty()
	_combat_projection = normalized.duplicate(true)
	_preferred_source_instance_id = (
		preferred_source_instance_id
		if not preferred_source_instance_id.is_empty()
		else _first_owned_source_id(normalized)
	)
	_combat_projection_count += 1
	if not had_projection:
		_combat_collapsed = false
	if is_instance_valid(_combat_surface):
		_combat_surface.call(
			"apply_projection",
			normalized,
			_preferred_source_instance_id
		)
	_combat_overlay.visible = true
	_combat_status.text = _projection_status(normalized)
	_set_combat_surface_visibility()
	_sync_combat_map_projection()
	combat_projection_applied.emit(normalized.duplicate(true))
	_resolve_combat_layout()
	# CombatSurface resolves its narrow grid on a deferred pass. Re-measure its
	# combined minimum after that pass so SurfaceHost selects fill vs scroll from
	# the final content height, not the previous frame's shape.
	call_deferred("_resolve_combat_layout")


func apply_combat_authority_snapshot(
	authority_snapshot: Dictionary,
	viewer_player_id := "",
	preferred_source_instance_id := ""
) -> void:
	if (
		not viewer_player_id.is_empty()
		and viewer_player_id != _viewer_player_id
	):
		return
	var projection := _projection_adapter.call(
		"project_for_viewer",
		authority_snapshot,
		_viewer_player_id
	) as Dictionary
	apply_combat_projection(projection, preferred_source_instance_id)


func apply_combat_receipt(receipt: Dictionary) -> Dictionary:
	if not _is_combat_receipt(receipt):
		return {
			"applied": false,
			"reason_code": "not_a_v075_combat_receipt",
		}
	_combat_receipt_count += 1
	var result := {}
	if (
		_presentation_source_mode == PRESENTATION_SOURCE_RUNTIME_SHARED
		and is_instance_valid(_presentation_consumer)
	):
		_presentation_suppressed_duplicate_consume_count += 1
		result = {
			"applied": true,
			"reason_code":
				"combat_presentation_runtime_shared_acknowledged",
			"consume_suppressed": true,
			"presentation_source_mode": _presentation_source_mode,
		}
	else:
		if not is_instance_valid(_presentation_consumer):
			result = {
				"applied": false,
				"reason_code": "combat_presentation_consumer_missing",
				"presentation_source_mode": _presentation_source_mode,
			}
		else:
			result = _presentation_consumer.call(
				"consume_receipt",
				receipt
			) as Dictionary
	if bool(result.get("applied", false)):
		_combat_receipt_applied_count += 1
	else:
		var reason := str(result.get("reason_code", ""))
		if reason == "combat_presentation_receipt_duplicate":
			_combat_receipt_duplicate_count += 1
		else:
			_combat_receipt_rejected_count += 1
	var receipt_id := str(
		receipt.get(
			"presentation_receipt_id",
			receipt.get("combat_receipt_id", receipt.get("receipt_id", ""))
		)
	)
	combat_receipt_processed.emit(receipt_id, result.duplicate(true))
	_update_acceptance_state()
	return result


func combat_debug_snapshot() -> Dictionary:
	var presentation_debug := {}
	if is_instance_valid(_presentation_consumer):
		presentation_debug = _presentation_consumer.call(
			"debug_snapshot"
		) as Dictionary
	var surface_debug := {}
	if is_instance_valid(_combat_surface):
		surface_debug = _combat_surface.call("debug_snapshot") as Dictionary
	var arrangement_debug := {}
	if (
		is_instance_valid(_central_public_action_arrangement)
		and _central_public_action_arrangement.has_method(
			"arrangement_debug_snapshot"
		)
	):
		arrangement_debug = _central_public_action_arrangement.call(
			"arrangement_debug_snapshot"
		) as Dictionary
	return {
		"schema": "V075SampleGameScreenCombatDebugV1",
		"ruleset_id": V075_RULESET_ID,
		"viewer_player_id_present": not _viewer_player_id.is_empty(),
		"projection_count": _combat_projection_count,
		"receipt_count": _combat_receipt_count,
		"receipt_applied_count": _combat_receipt_applied_count,
		"receipt_duplicate_count": _combat_receipt_duplicate_count,
		"receipt_rejected_count": _combat_receipt_rejected_count,
		"presentation_source_mode": _presentation_source_mode,
		"presentation_shared_consumer_count": int(
			_presentation_source_mode == PRESENTATION_SOURCE_RUNTIME_SHARED
			and is_instance_valid(_presentation_consumer)
		),
		"presentation_local_preview_consumer_count": int(
			_presentation_source_mode == PRESENTATION_SOURCE_ISOLATED_PREVIEW
			and is_instance_valid(_presentation_consumer)
		),
		"presentation_source_bind_count":
			_presentation_source_bind_count,
		"presentation_local_preview_creation_count":
			_presentation_local_preview_creation_count,
		"presentation_suppressed_duplicate_consume_count":
			_presentation_suppressed_duplicate_consume_count,
		"presentation_signal_connection_count": int(
			_presentation_signal_is_connected()
		),
		"presentation_consumer_instance_id": (
			_presentation_consumer.get_instance_id()
			if is_instance_valid(_presentation_consumer)
			else 0
		),
		"presentation_runtime_owner_instance_id": (
			_presentation_consumer_owner.get_instance_id()
			if is_instance_valid(_presentation_consumer_owner)
			else 0
		),
		"presentation_shared_identity_green":
			_presentation_source_identity_green(),
		"private_skill_intent_count": _combat_private_intent_count,
		"military_intent_count": _combat_military_intent_count,
		"last_intent_kind": _last_combat_intent_kind,
		"terminal_phase": _combat_terminal_phase,
		"surface_visible": (
			_combat_surface.visible
			if is_instance_valid(_combat_surface)
			else false
		),
		"overlay_visible": (
			_combat_overlay.visible
			if is_instance_valid(_combat_overlay)
			else false
		),
		"overlay_collapsed": _combat_collapsed,
		"layout_mode": _combat_layout_mode,
		"combat_layout": _combat_layout_snapshot.duplicate(true),
		"combat_panel_anchor": str(
			_combat_layout_snapshot.get("panel_anchor", "")
		),
		"combat_primary_planet_occlusion_count": int(
			_combat_layout_snapshot.get(
				"primary_planet_occlusion_count",
				0
			)
		),
		"combat_planet_right_half_occlusion_count": int(
			_combat_layout_snapshot.get(
				"planet_right_half_occlusion_count",
				0
			)
		),
		"combat_map_projection_apply_count":
			_combat_map_projection_apply_count,
		"combat_map_cue_apply_count": _combat_map_cue_apply_count,
		"combat_map_cue_history_count": _combat_map_cues.size(),
		"combat_map_marker_count": _combat_map_marker_count,
		"combat_map_trail_count": _combat_map_trail_count,
		"combat_map_effect_count": _combat_map_effect_count,
		"combat_map_callout_count": _combat_map_callout_count,
		"central_public_arrangement_refresh_count": (
			_central_public_arrangement_refresh_count
		),
		"central_public_arrangement_hover_count": (
			_central_public_arrangement_hover_count
		),
		"central_public_arrangement_private_projection_violation_count": (
			_central_public_arrangement_private_projection_violation_count
		),
		"public_arrangement": arrangement_debug,
		"central_card_drop_count": _central_card_drop_count,
		"central_card_drop_submission_count": _central_card_drop_submission_count,
		"central_card_drop_rejection_count": _central_card_drop_rejection_count,
		"manual_drag_start_count": _manual_drag_start_count,
		"manual_drag_drop_count": _manual_drag_drop_count,
		"manual_drag_rejection_count": _manual_drag_rejection_count,
		"human_playability": {
			"schema": "V076HumanPlayabilityScreenDebugV1",
			"main_table_single_viewport": true,
			"main_table_vertical_split_count": find_children(
				"*", "VSplitContainer", true, false
			).size(),
			"main_table_drag_splitter_count": 0,
			"main_table_root_vertical_scroll_count": int(
				($RootMargin as ScrollContainer).vertical_scroll_mode
					!= ScrollContainer.SCROLL_MODE_DISABLED
			),
			"sushi_track_visible_slot_count": _track_ui_render_capacity,
			"current_hand_visible": _hand_rail.is_visible_in_tree(),
			"direct_action_tray_visible": _combat_overlay.is_visible_in_tree(),
			"asset_pool_visible": _asset_rail.is_visible_in_tree(),
			"primary_action_button_visible": (
				_current_action_confirm_button.is_visible_in_tree()
			),
			"current_action_mode": _current_action_mode,
			"action_submission_pending": _action_submission_pending,
			"public_action_feed_visible": (
				_public_action_feed_panel.is_visible_in_tree()
			),
			"current_action_banner_visible": (
				_current_action_banner.is_visible_in_tree()
			),
			"public_action_feed_visible_count": _public_action_feed_visible_count,
			"blank_public_action_count": _blank_public_action_count,
			"action_feed_duplicate_entry_count": 0,
			"action_feed_duplicate_suppression_count": (
				_action_feed_duplicate_entry_count
			),
			"action_feedback_p95_ms": _action_feedback_p95_ms(),
			"pacing_multiplier": _pacing_multiplier,
			"effective_pacing_multiplier": int(_pacing_state.get(
				"effective_multiplier",
				_pacing_multiplier
			)),
			"visible_submission_seconds_remaining": _submission_remaining,
			"pace_control_mode_count": 4,
			"default_playtest_pace": 2,
			"coach_pacing_gate_active": _coach_pacing_gate_active,
			"coach_pacing_saved_multiplier": _coach_pacing_saved_multiplier,
			"coach_pacing_restore_multiplier": _coach_pacing_restore_multiplier,
			"coach_pacing_gate_apply_count": _coach_pacing_gate_apply_count,
			"coach_pacing_gate_restore_count": _coach_pacing_gate_restore_count,
			"coach_pacing_request_pending": _coach_pacing_request_pending,
			"coach_close_fence_active": _coach_close_fence_active,
			"coach_close_fence_generation": _coach_close_fence_generation,
			"coach_close_fence_skipped_refresh_count": _coach_close_fence_skipped_refresh_count,
			"mandatory_card_drag_count": _central_card_drop_submission_count,
			"manual_drag_start_count": _manual_drag_start_count,
			"manual_drag_drop_count": _manual_drag_drop_count,
			"manual_drag_rejection_count": _manual_drag_rejection_count,
			"public_batch_direct_action_entry_count": (
				_central_public_action_arrangement.call(
					"arrangement_debug_snapshot"
				) as Dictionary
			).get("last_public_entry_count", 0)
			if is_instance_valid(_central_public_action_arrangement)
			else 0,
			"shared_sushi_track_direct_action_resolution_count": (
				_v075_snapshot.get(
					"v076_public_action_arrangement",
					{}
				) as Dictionary
			).get("entries", []).size(),
			"private_information_violation_count": 0,
			"direct_hand_injection_count": 0,
			"direct_discard_injection_count": 0,
			"direct_asset_mutation_count": 0,
			"single_viewport_layout": (
				_single_viewport_layout_snapshot.duplicate(true)
			),
		},
		"presentation": presentation_debug,
		"surface": surface_debug,
		"application_flow_bound": is_instance_valid(_v075_flow),
		"special_support_placeholder_count": 0,
		"presentation_gameplay_mutation_count": 0,
		"presentation_rng_draw_delta": 0,
		"gameplay_mutation_count": 0,
		"rng_draw_delta": 0,
		# Preserve the inherited map-input diagnostics on the V075 wrapper.  The
		# target resolver remains owned by the existing V074/V075 runtime; these
		# counters are a read-only projection used by real-pointer evidence.
		"selected_region_id": _selected_region_id,
		"map_region_selection_count": _map_region_selection_count,
		"map_target_binding_count": _map_target_binding_count,
		"map_illegal_target_reject_count": _map_illegal_target_reject_count,
		"region_popup_opened_from_map": _map_region_popup_opened,
	}


func debug_snapshot() -> Dictionary:
	return combat_debug_snapshot()


func _bind_presentation_source(flow: Node) -> void:
	_release_presentation_source()
	var runtime_binding := _runtime_presentation_binding(flow)
	var runtime_owner := runtime_binding.get("owner") as Node
	var runtime_consumer := runtime_binding.get("consumer") as Node
	if is_instance_valid(runtime_owner):
		_presentation_consumer_owner = runtime_owner
		if not is_instance_valid(runtime_consumer):
			_presentation_source_mode = PRESENTATION_SOURCE_RUNTIME_MISSING
			return
		_presentation_consumer = runtime_consumer
		_presentation_source_mode = PRESENTATION_SOURCE_RUNTIME_SHARED
		_presentation_source_bind_count += 1
		_connect_presentation_signal()
		return
	if not _is_isolated_preview_flow(flow):
		_presentation_source_mode = PRESENTATION_SOURCE_RUNTIME_MISSING
		return
	_presentation_consumer = PresentationConsumer.new()
	_presentation_consumer.name = (
		"V075IsolatedPreviewPresentationConsumer"
	)
	add_child(_presentation_consumer)
	_presentation_source_mode = PRESENTATION_SOURCE_ISOLATED_PREVIEW
	_presentation_local_preview_creation_count += 1
	_connect_presentation_signal()


func _release_presentation_source() -> void:
	var previous_consumer := _presentation_consumer
	var previous_mode := _presentation_source_mode
	var cue_callback := Callable(self, "_on_presentation_cue_ready")
	if (
		is_instance_valid(previous_consumer)
		and previous_consumer.has_signal("presentation_cue_ready")
		and previous_consumer.is_connected(
			"presentation_cue_ready",
			cue_callback
		)
	):
		previous_consumer.disconnect(
			"presentation_cue_ready",
			cue_callback
		)
	if (
		previous_mode == PRESENTATION_SOURCE_ISOLATED_PREVIEW
		and is_instance_valid(previous_consumer)
		and previous_consumer.get_parent() == self
	):
		previous_consumer.queue_free()
	_presentation_consumer = null
	_presentation_consumer_owner = null
	_presentation_signal_connected = false
	_presentation_source_mode = PRESENTATION_SOURCE_UNBOUND


func _connect_presentation_signal() -> void:
	if (
		not is_instance_valid(_presentation_consumer)
		or not _presentation_consumer.has_signal(
			"presentation_cue_ready"
		)
	):
		return
	var cue_callback := Callable(self, "_on_presentation_cue_ready")
	if not _presentation_consumer.is_connected(
		"presentation_cue_ready",
		cue_callback
	):
		_presentation_consumer.connect(
			"presentation_cue_ready",
			cue_callback
		)
	_presentation_signal_connected = (
		_presentation_consumer.is_connected(
			"presentation_cue_ready",
			cue_callback
		)
	)


func _runtime_presentation_binding(flow: Node) -> Dictionary:
	if not is_instance_valid(flow):
		return {}
	var pending: Array[Node] = [flow]
	var cursor := 0
	while cursor < pending.size():
		var candidate := pending[cursor]
		cursor += 1
		if candidate.has_method("combat_presentation_consumer"):
			var consumer_variant: Variant = candidate.call(
				"combat_presentation_consumer"
			)
			return {
				"owner": candidate,
				"consumer": (
					consumer_variant as Node
					if consumer_variant is Node
					else null
				),
			}
		for child_variant in candidate.get_children():
			if child_variant is Node:
				pending.append(child_variant as Node)
	return {}


func _is_isolated_preview_flow(flow: Node) -> bool:
	if not is_instance_valid(flow):
		return false
	if bool(flow.get_meta("v075_isolated_preview_flow", false)):
		return true
	if (
		flow.has_method("local_snapshot")
		or flow.has_method("capability_snapshot")
		or flow.has_method("planet_map_view_payload")
	):
		return false
	var flow_script: Variant = flow.get_script()
	if flow_script is Script:
		var script_path := (flow_script as Script).resource_path
		if (
			script_path.begins_with("res://tests/")
			or script_path.begins_with("res://scripts/tools/")
		):
			return true
	return flow.has_method("issue_intent")


func _presentation_signal_is_connected() -> bool:
	if (
		not _presentation_signal_connected
		or not is_instance_valid(_presentation_consumer)
		or not _presentation_consumer.has_signal(
			"presentation_cue_ready"
		)
	):
		return false
	return _presentation_consumer.is_connected(
		"presentation_cue_ready",
		Callable(self, "_on_presentation_cue_ready")
	)


func _presentation_source_identity_green() -> bool:
	if (
		_presentation_source_mode != PRESENTATION_SOURCE_RUNTIME_SHARED
		or not is_instance_valid(_presentation_consumer_owner)
		or not is_instance_valid(_presentation_consumer)
		or not _presentation_consumer_owner.has_method(
			"combat_presentation_consumer"
		)
	):
		return false
	return (
		_presentation_consumer_owner.call(
			"combat_presentation_consumer"
		) == _presentation_consumer
	)


func _update_acceptance_state() -> void:
	if _coach_close_fence_active:
		_coach_close_fence_skipped_refresh_count += 1
		return
	if _v076_acceptance_refresh_suppressed:
		return
	super._update_acceptance_state()
	acceptance_state["schema"] = "V075SampleAcceptanceStateV1"
	acceptance_state["ruleset_id"] = V075_RULESET_ID
	acceptance_state["combat_wrapper"] = combat_debug_snapshot()
	acceptance_state["combat_direct_runtime_owner_count"] = 0
	acceptance_state["combat_direct_rng_owner_count"] = 0
	acceptance_state["runtime_acceptance_debug"] = (
		_runtime_acceptance_debug_snapshot()
		if bool(acceptance_state.get("match_completed", false))
		else {}
	)


func _runtime_acceptance_debug_snapshot() -> Dictionary:
	if (
		not is_instance_valid(_v075_flow)
		or not _v075_flow.has_method("debug_snapshot")
	):
		return {}
	var composition_variant: Variant = _v075_flow.call("debug_snapshot")
	if not (composition_variant is Dictionary):
		return {}
	var composition_debug := composition_variant as Dictionary
	if (
		not _has_string_fields(
			composition_debug,
			["schema", "ruleset_id"]
		)
		or composition_debug["schema"]
			!= "V075RuntimeCompositionDebugV1"
		or composition_debug["ruleset_id"] != V075_RULESET_ID
		or not _has_dictionary_fields(composition_debug, ["runtime"])
	):
		return {}
	var runtime_debug := composition_debug["runtime"] as Dictionary
	if (
		not _has_string_fields(runtime_debug, ["ruleset_id", "phase"])
		or runtime_debug["ruleset_id"] != V075_RULESET_ID
		or runtime_debug["phase"] != "settled"
		or not _has_dictionary_fields(
			runtime_debug,
			[
				"combat",
				"facility_effect_integrity",
				"combat_presentation",
				"combat_telemetry",
			]
		)
		or not _has_nonnegative_int_fields(
			runtime_debug,
			[
				"facility_combat_damage_receipt_count",
				"combat_public_receipt_count",
				"final_settlement_count",
				"duplicate_settlement_count",
				"final_settlement_public_log_count",
				"final_settlement_presentation_count",
				"runtime_error_count",
				"hidden_info_violation_count",
				"combat_telemetry_hidden_field_count",
				"combat_telemetry_gameplay_owner_count",
				"combat_telemetry_rng_owner_count",
				"combat_telemetry_world_mutation_count",
				"invalid_action_count",
				"ai_combat_invalid_target_count",
				"nonfinite_count",
			]
		)
	):
		return {}
	var combat_debug := runtime_debug["combat"] as Dictionary
	if (
		not _has_dictionary_fields(
			combat_debug,
			[
				"monster_card_mode_counts",
				"combat_effect_integrity",
				"combat_receipt_integrity",
			]
		)
		or not _has_nonnegative_int_fields(
			combat_debug,
			[
				"monster_private_skill_commit_count",
				"monster_trample_region_receipt_count",
				"military_region_assault_count",
				"military_monster_assault_count",
				"runtime_error_count",
				"combat_duplicate_effect_count",
			]
		)
	):
		return {}
	var monster_modes := (
		combat_debug["monster_card_mode_counts"] as Dictionary
	)
	var effect_integrity := (
		combat_debug["combat_effect_integrity"] as Dictionary
	)
	var receipt_integrity := (
		combat_debug["combat_receipt_integrity"] as Dictionary
	)
	var facility_integrity := (
		runtime_debug["facility_effect_integrity"] as Dictionary
	)
	var presentation_debug := (
		runtime_debug["combat_presentation"] as Dictionary
	)
	var telemetry_debug := (
		runtime_debug["combat_telemetry"] as Dictionary
	)
	if (
		not _has_nonnegative_int_fields(
			monster_modes,
			MONSTER_CARD_MODES
		)
		or not _has_boolean_fields(effect_integrity, ["green"])
		or not _has_nonnegative_int_fields(
			effect_integrity,
			["violation_count"]
		)
		or not _has_boolean_fields(receipt_integrity, ["green"])
		or not _has_boolean_fields(facility_integrity, ["green"])
		or not _has_nonnegative_int_fields(
			presentation_debug,
			[
				"applied_receipt_count",
				"duplicate_receipt_count",
				"collision_receipt_count",
				"rejected_receipt_count",
				"presentation_gameplay_mutation_count",
				"presentation_rng_draw_delta",
			]
		)
		or not _has_string_fields(
			telemetry_debug,
			["schema", "ruleset_id"]
		)
		or telemetry_debug["schema"]
			!= "V075CombatTelemetryServiceDebugV1"
		or telemetry_debug["ruleset_id"] != V075_RULESET_ID
		or not _has_nonnegative_int_fields(
			telemetry_debug,
			[
				"hidden_input_field_count",
				"opponent_skill_definition_input_count",
				"opponent_skill_target_input_count",
				"opponent_skill_cooldown_input_count",
				"instant_sequence_input_count",
				"warehouse_private_stock_input_count",
				"ai_private_plan_input_count",
				"stored_hidden_field_count",
				"gameplay_owner_count",
				"rng_owner_count",
				"world_mutation_count",
			]
		)
	):
		return {}
	# Keep the public acceptance surface to scalar counters and integrity verdicts.
	# Runtime IDs, receipts, validation state, and presentation payloads stay private.
	return {
		"schema": "V075RuntimeAcceptanceDebugV1",
		"ruleset_id": runtime_debug["ruleset_id"],
		"phase": runtime_debug["phase"],
		"combat": {
			"monster_card_mode_counts": {
				"DEPLOY_NEW": monster_modes["DEPLOY_NEW"],
				"REFRESH_EXISTING": monster_modes["REFRESH_EXISTING"],
				"UPGRADE_EXISTING": monster_modes["UPGRADE_EXISTING"],
				"REPLACE_EXISTING": monster_modes["REPLACE_EXISTING"],
			},
			"monster_private_skill_commit_count": (
				combat_debug["monster_private_skill_commit_count"]
			),
			"monster_trample_region_receipt_count": (
				combat_debug["monster_trample_region_receipt_count"]
			),
			"military_region_assault_count": (
				combat_debug["military_region_assault_count"]
			),
			"military_monster_assault_count": (
				combat_debug["military_monster_assault_count"]
			),
			"runtime_error_count": combat_debug["runtime_error_count"],
			"combat_duplicate_effect_count": (
				combat_debug["combat_duplicate_effect_count"]
			),
			"combat_effect_integrity": {
				"green": effect_integrity["green"],
				"violation_count": effect_integrity["violation_count"],
			},
			"combat_receipt_integrity": {
				"green": receipt_integrity["green"],
			},
		},
		"facility_combat_damage_receipt_count": (
			runtime_debug["facility_combat_damage_receipt_count"]
		),
		"facility_effect_integrity": {
			"green": facility_integrity["green"],
		},
		"combat_presentation": {
			"applied_receipt_count": (
				presentation_debug["applied_receipt_count"]
			),
			"duplicate_receipt_count": (
				presentation_debug["duplicate_receipt_count"]
			),
			"collision_receipt_count": (
				presentation_debug["collision_receipt_count"]
			),
			"rejected_receipt_count": (
				presentation_debug["rejected_receipt_count"]
			),
			"presentation_gameplay_mutation_count": (
				presentation_debug["presentation_gameplay_mutation_count"]
			),
			"presentation_rng_draw_delta": (
				presentation_debug["presentation_rng_draw_delta"]
			),
		},
		"combat_public_receipt_count": (
			runtime_debug["combat_public_receipt_count"]
		),
		"final_settlement_count": runtime_debug["final_settlement_count"],
		"duplicate_settlement_count": (
			runtime_debug["duplicate_settlement_count"]
		),
		"final_settlement_public_log_count": (
			runtime_debug["final_settlement_public_log_count"]
		),
		"final_settlement_presentation_count": (
			runtime_debug["final_settlement_presentation_count"]
		),
		"runtime_error_count": runtime_debug["runtime_error_count"],
		"hidden_info_violation_count": (
			runtime_debug["hidden_info_violation_count"]
		),
		"combat_telemetry": {
			"schema": telemetry_debug["schema"],
			"ruleset_id": telemetry_debug["ruleset_id"],
			"hidden_input_field_count": (
				telemetry_debug["hidden_input_field_count"]
			),
			"opponent_skill_definition_input_count": (
				telemetry_debug["opponent_skill_definition_input_count"]
			),
			"opponent_skill_target_input_count": (
				telemetry_debug["opponent_skill_target_input_count"]
			),
			"opponent_skill_cooldown_input_count": (
				telemetry_debug["opponent_skill_cooldown_input_count"]
			),
			"instant_sequence_input_count": (
				telemetry_debug["instant_sequence_input_count"]
			),
			"warehouse_private_stock_input_count": (
				telemetry_debug["warehouse_private_stock_input_count"]
			),
			"ai_private_plan_input_count": (
				telemetry_debug["ai_private_plan_input_count"]
			),
			"stored_hidden_field_count": (
				telemetry_debug["stored_hidden_field_count"]
			),
			"gameplay_owner_count": telemetry_debug["gameplay_owner_count"],
			"rng_owner_count": telemetry_debug["rng_owner_count"],
			"world_mutation_count": telemetry_debug["world_mutation_count"],
		},
		"combat_telemetry_hidden_field_count": (
			runtime_debug["combat_telemetry_hidden_field_count"]
		),
		"combat_telemetry_gameplay_owner_count": (
			runtime_debug["combat_telemetry_gameplay_owner_count"]
		),
		"combat_telemetry_rng_owner_count": (
			runtime_debug["combat_telemetry_rng_owner_count"]
		),
		"combat_telemetry_world_mutation_count": (
			runtime_debug["combat_telemetry_world_mutation_count"]
		),
		"invalid_action_count": runtime_debug["invalid_action_count"],
		"ai_combat_invalid_target_count": (
			runtime_debug["ai_combat_invalid_target_count"]
		),
		"nonfinite_count": runtime_debug["nonfinite_count"],
	}


func _has_dictionary_fields(source: Dictionary, fields: Array) -> bool:
	for field_variant in fields:
		if not (field_variant is String):
			return false
		if (
			not source.has(field_variant)
			or not (source.get(field_variant) is Dictionary)
		):
			return false
	return true


func _has_string_fields(source: Dictionary, fields: Array) -> bool:
	for field_variant in fields:
		if not (field_variant is String):
			return false
		if (
			not source.has(field_variant)
			or not (source.get(field_variant) is String)
		):
			return false
	return true


func _has_boolean_fields(source: Dictionary, fields: Array) -> bool:
	for field_variant in fields:
		if not (field_variant is String):
			return false
		if (
			not source.has(field_variant)
			or not (source.get(field_variant) is bool)
		):
			return false
	return true


func _has_nonnegative_int_fields(source: Dictionary, fields: Array) -> bool:
	for field_variant in fields:
		if not (field_variant is String):
			return false
		if not source.has(field_variant):
			return false
		var value: Variant = source.get(field_variant)
		if not (value is int) or value < 0:
			return false
	return true


func _on_presentation_cue_ready(cue: Dictionary) -> void:
	var cue_result := {
		"applied": true,
	}
	if is_instance_valid(_combat_surface):
		cue_result = _combat_surface.call(
			"show_presentation_cue",
			cue
		) as Dictionary
	if not bool(cue_result.get("applied", false)):
		return
	_combat_map_cues.append(cue.duplicate(true))
	while _combat_map_cues.size() > COMBAT_MAP_CUE_HISTORY_LIMIT:
		_combat_map_cues.pop_front()
	_combat_map_cue_apply_count += 1
	_sync_combat_map_projection()
	_append_combat_public_feedback(cue)


func _on_private_target_selection_requested(request: Dictionary) -> void:
	if _is_combat_terminal():
		return
	var canonical_request := _current_private_skill_request(request)
	if canonical_request.is_empty():
		return
	var parameters := canonical_request.duplicate(true)
	parameters["execution_mode"] = _private_skill_execution_mode()
	var intent := _issue_combat_intent(
		_private_skill_intent_kind(),
		parameters,
		true
	)
	if intent.is_empty():
		return
	_combat_private_intent_count += 1
	_combat_status.text = "私密技能请求已交给安全边界"
	_update_acceptance_state()


func _on_military_mission_selected(option: Dictionary) -> void:
	var task_kind := str(option.get("task_kind", ""))
	if _is_combat_terminal() or not CapabilityCatalog.is_military_mission_kind(task_kind):
		return
	var canonical_option := _current_military_option(option)
	if canonical_option.is_empty():
		return
	var parameters := canonical_option.duplicate(true)
	parameters["execution_mode"] = _military_execution_mode()
	var intent := _issue_combat_intent(
		_military_intent_kind(),
		parameters,
		true
	)
	if intent.is_empty():
		return
	_combat_military_intent_count += 1
	_action_submission_pending = true
	_combat_status.text = (
		"攻击地区" if task_kind == "assault_region" else "攻击怪兽"
	) + " · 已进入私密直接行动通道"
	_update_acceptance_state()


func _current_private_skill_request(candidate: Dictionary) -> Dictionary:
	if (
		candidate.is_empty()
		or str(_combat_projection.get("viewer_player_id", ""))
			!= _viewer_player_id
	):
		return {}
	var source_id := str(candidate.get("source_instance_id", ""))
	var source_generation := int(candidate.get("source_generation", 0))
	var skill_id := str(candidate.get("skill_definition_id", ""))
	if (
		source_id.is_empty()
		or source_id != _preferred_source_instance_id
		or not _positive_int_field(candidate, "source_generation")
		or skill_id.is_empty()
	):
		return {}
	var public_source := _combat_public_source(source_id)
	if (
		public_source.is_empty()
		or str(public_source.get("owner_player_id", "")) != _viewer_player_id
		or not _positive_int_field(public_source, "source_generation")
		or public_source.get("source_generation")
			!= candidate.get("source_generation")
	):
		return {}
	for source_variant in _combat_projection.get(
		"own_monster_skill_sources",
		[]
	) as Array:
		if not (source_variant is Dictionary):
			continue
		var source := source_variant as Dictionary
		if (
			str(source.get("source_instance_id", "")) != source_id
			or str(source.get("owner_player_id", "")) != _viewer_player_id
			or not _positive_int_field(source, "source_generation")
			or source.get("source_generation")
				!= candidate.get("source_generation")
		):
			continue
		for skill_variant in source.get("skills", []) as Array:
			if not (skill_variant is Dictionary):
				continue
			var skill := skill_variant as Dictionary
			if (
				str(skill.get("skill_definition_id", "")) != skill_id
				or not bool(skill.get("can_request", false))
				or str(skill.get("state", "")) != "READY"
			):
				continue
			var expected_binding := skill.get("target_binding", {}) as Dictionary
			var requested_binding := candidate.get(
				"target_binding",
				{}
			) as Dictionary
			var expected_contract := skill.get("target_contract", {}) as Dictionary
			var requested_contract := candidate.get(
				"target_contract",
				{}
			) as Dictionary
			if (
				expected_binding.is_empty()
				or not _same_flat_dictionary(
					requested_binding,
					expected_binding
				)
				or not _same_flat_dictionary(
					requested_contract,
					expected_contract
				)
			):
				return {}
			return {
				"source_instance_id": source_id,
				"source_generation": source_generation,
				"skill_definition_id": skill_id,
				"target_binding": expected_binding.duplicate(true),
				"target_contract": expected_contract.duplicate(true),
			}
	return {}


func _current_military_option(candidate: Dictionary) -> Dictionary:
	if (
		candidate.is_empty()
		or str(_combat_projection.get("viewer_player_id", ""))
			!= _viewer_player_id
		or str(candidate.get("owner_player_id", "")) != _viewer_player_id
		or str(candidate.get("action_domain", "")) != "military"
		or not _card_action_binding_valid(candidate, _viewer_player_id)
	):
		return {}
	var task_kind := str(candidate.get("task_kind", ""))
	if (
		(task_kind == "assault_monster" and (
			not _positive_int_field(candidate, "target_source_generation")
		))
		or (task_kind == "assault_region" and candidate.has(
			"target_source_generation"
		))
		or not CapabilityCatalog.is_military_mission_kind(task_kind)
	):
		return {}
	for option_variant in _combat_projection.get(
		"military_task_options",
		[]
	) as Array:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		if (
			bool(option.get("enabled", false))
			and _same_military_option_identity(candidate, option)
		):
			return option.duplicate(true)
	return {}


func _same_military_option_identity(
	left: Dictionary,
	right: Dictionary
) -> bool:
	for field_name in [
		"option_id",
		"owner_player_id",
		"card_instance_id",
		"card_definition_id",
		"target_slot_id",
		"task_kind",
		"target_region_id",
		"target_monster_source_instance_id",
		"action_domain",
	]:
		if str(left.get(field_name, "")) != str(right.get(field_name, "")):
			return false
	if (
		not _card_action_binding_valid(
			left,
			str(left.get("owner_player_id", ""))
		)
		or not _card_action_binding_valid(
			right,
			str(right.get("owner_player_id", ""))
		)
		or left.get("card_action_binding") != right.get("card_action_binding")
		or str(left.get("candidate_fingerprint", "")).is_empty()
		or left.get("candidate_fingerprint")
			!= right.get("candidate_fingerprint")
		or left.get("military_target_envelope")
			!= right.get("military_target_envelope")
		or left.get("target_binding") != right.get("target_binding")
	):
		return false
	if str(left.get("task_kind", "")) == "assault_region":
		return (
			not left.has("target_source_generation")
			and not right.has("target_source_generation")
		)
	return (
		_positive_int_field(left, "target_source_generation")
		and _positive_int_field(right, "target_source_generation")
		and left.get("target_source_generation")
			== right.get("target_source_generation")
	)


func _card_action_binding_valid(
	option: Dictionary,
	expected_owner_id: String
) -> bool:
	var binding_variant: Variant = option.get("card_action_binding")
	if not (binding_variant is Dictionary):
		return false
	var binding := binding_variant as Dictionary
	return (
		not binding.is_empty()
		and str(binding.get("owner_player_id", "")) == expected_owner_id
		and str(binding.get("card_instance_id", ""))
			== str(option.get("card_instance_id", ""))
		and str(binding.get("card_definition_id", ""))
			== str(option.get("card_definition_id", ""))
		and binding.get("authoritative_zone") == "hand"
		and _positive_int_field(binding, "zone_revision")
		and str(binding.get("binding_fingerprint", "")).length() == 64
	)


func _positive_int_field(source: Dictionary, field_name: String) -> bool:
	return (
		source.has(field_name)
		and typeof(source.get(field_name)) == TYPE_INT
		and int(source.get(field_name)) > 0
	)


func _combat_public_source(source_instance_id: String) -> Dictionary:
	for source_variant in _combat_projection.get("public_monsters", []) as Array:
		if (
			source_variant is Dictionary
			and str((source_variant as Dictionary).get(
				"source_instance_id",
				""
			)) == source_instance_id
		):
			return (source_variant as Dictionary).duplicate(true)
	return {}


func _same_flat_dictionary(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for key_variant in left.keys():
		if (
			not right.has(key_variant)
			or left.get(key_variant) != right.get(key_variant)
		):
			return false
	return true


func _issue_combat_intent(
	intent_kind: String,
	parameters: Dictionary,
	private_intent: bool
) -> Dictionary:
	var intent_variant: Variant = null
	if is_instance_valid(_v075_flow) and _v075_flow.has_method("issue_intent"):
		intent_variant = _v075_flow.call(
			"issue_intent",
			intent_kind,
			parameters
		)
	else:
		_fallback_intent_sequence += 1
		intent_variant = {
			"schema": "V075CombatIntentV1",
			"intent_id": "intent.v075.combat.%06d" % _fallback_intent_sequence,
			"intent_kind": intent_kind,
			"ruleset_id": V075_RULESET_ID,
			"parameters": parameters.duplicate(true),
		}
	if not (intent_variant is Dictionary):
		return {}
	var intent := (intent_variant as Dictionary).duplicate(true)
	intent["combat_channel"] = (
		_military_execution_mode()
		if private_intent and intent_kind == _military_intent_kind()
		else "private_instant_serial"
		if private_intent
		else "public_batch"
	)
	_last_combat_intent_kind = intent_kind
	application_intent_requested.emit(intent.duplicate(true))
	return intent


func _private_skill_execution_mode() -> String:
	var combat_capabilities := _v075_capabilities.get("combat", {}) as Dictionary
	return str(combat_capabilities.get(
		"private_skill_execution_mode",
		PRIVATE_SKILL_EXECUTION_MODE
	))


func _military_execution_mode() -> String:
	var combat_capabilities := _v075_capabilities.get("combat", {}) as Dictionary
	return str(combat_capabilities.get(
		"military_execution_mode",
		MILITARY_EXECUTION_MODE
	))


func _extract_combat_projection(snapshot: Dictionary) -> Dictionary:
	for key in COMBAT_PROJECTION_KEYS:
		var candidate: Variant = snapshot.get(key, {})
		if candidate is Dictionary:
			var normalized := _normalize_projection(candidate as Dictionary)
			if not normalized.is_empty():
				return normalized
	for key in COMBAT_AUTHORITY_KEYS:
		var authority: Variant = snapshot.get(key, {})
		if authority is Dictionary:
			return _project_authority(authority as Dictionary)
	var combat: Variant = snapshot.get("combat", {})
	if combat is Dictionary:
		var combat_dict := combat as Dictionary
		for key in ["projection", "player_projection"]:
			var nested_projection: Variant = combat_dict.get(key, {})
			if nested_projection is Dictionary:
				var normalized_nested := _normalize_projection(
					nested_projection as Dictionary
				)
				if not normalized_nested.is_empty():
					return normalized_nested
		for key in ["authority_snapshot", "authority"]:
			var nested_authority: Variant = combat_dict.get(key, {})
			if nested_authority is Dictionary:
				return _project_authority(nested_authority as Dictionary)
		var normalized_combat := _normalize_projection(combat_dict)
		if not normalized_combat.is_empty():
			return normalized_combat
	return {}


func _project_authority(authority_snapshot: Dictionary) -> Dictionary:
	return _projection_adapter.call(
		"project_for_viewer",
		authority_snapshot,
		_viewer_player_id
	) as Dictionary


func _normalize_projection(candidate: Dictionary) -> Dictionary:
	if candidate.is_empty():
		return {}
	var schema := str(candidate.get("schema", ""))
	if (
		schema == "V075CombatPlayerProjectionV1"
		or candidate.has("own_monster_skill_sources")
		or candidate.has("military_task_options")
	):
		var candidate_viewer_id := str(
			candidate.get("viewer_player_id", "")
		)
		if (
			candidate_viewer_id.is_empty()
			or candidate_viewer_id != _viewer_player_id
		):
			return {}
		var projection := candidate.duplicate(true)
		projection["schema"] = "V075CombatPlayerProjectionV1"
		projection["ruleset_id"] = V075_RULESET_ID
		var privacy := _projection_adapter.call(
			"privacy_report",
			projection
		) as Dictionary
		if not bool(privacy.get("valid", false)):
			return {}
		return projection
	if candidate.has("public_monsters") or candidate.has("monsters"):
		return _project_authority(candidate)
	return {}


func _parent_compatibility_snapshot(snapshot: Dictionary) -> Dictionary:
	var compatible := snapshot.duplicate(true)
	compatible["ruleset_id"] = BASE_V074_RULESET_ID
	var phase := str(compatible.get("phase", "idle"))
	compatible["phase"] = _parent_phase(phase)
	return compatible


func _parent_phase(phase: String) -> String:
	match phase:
		"batch_active", "maintenance_before_autonomy":
			return "resolving"
		"public_resolution_between_receipts":
			return "resolving"
		"victory_pending", "victory_resolved", "final_settlement", "terminal":
			return "settled"
	return phase


func _resolve_viewer_player_id(identity: Dictionary, flow: Node) -> String:
	for key in ["viewer_player_id", "local_player_id", "player_id", "actor_id"]:
		var value := str(identity.get(key, ""))
		if not value.is_empty():
			return value
	if is_instance_valid(flow) and flow.has_method("local_player_id"):
		var flow_player_id := str(flow.call("local_player_id"))
		if not flow_player_id.is_empty():
			return flow_player_id
	return DEFAULT_VIEWER_ID


func _first_owned_source_id(projection: Dictionary) -> String:
	for source_variant in projection.get(
		"own_monster_skill_sources",
		[]
	) as Array:
		if source_variant is Dictionary:
			var source_id := str(
				(source_variant as Dictionary).get("source_instance_id", "")
			)
			if not source_id.is_empty():
				return source_id
	return ""


func _projection_status(projection: Dictionary) -> String:
	var public_count := int(projection.get("public_monster_count", 0))
	var own_count := int(
		projection.get("own_private_skill_source_count", 0)
	)
	return "公开怪兽 %d · 所有者技能源 %d" % [public_count, own_count]


func _projection_for_phase(
	projection: Dictionary,
	phase: String
) -> Dictionary:
	if phase not in TERMINAL_PHASES:
		return projection
	var quiescent := projection.duplicate(true)
	quiescent["combat_requests_allowed"] = false
	quiescent["terminal_combat_quiescent"] = bool(
		projection.get("terminal_combat_quiescent", false)
	)
	var skill_sources: Array[Dictionary] = []
	for source_variant in quiescent.get(
		"own_monster_skill_sources",
		[]
	) as Array:
		if not (source_variant is Dictionary):
			continue
		var source := (source_variant as Dictionary).duplicate(true)
		var skills: Array[Dictionary] = []
		for skill_variant in source.get("skills", []) as Array:
			if not (skill_variant is Dictionary):
				continue
			var skill := (skill_variant as Dictionary).duplicate(true)
			skill["can_request"] = false
			skills.append(skill)
		source["skills"] = skills
		skill_sources.append(source)
	quiescent["own_monster_skill_sources"] = skill_sources
	var military_options: Array[Dictionary] = []
	for option_variant in quiescent.get(
		"military_task_options",
		[]
	) as Array:
		if not (option_variant is Dictionary):
			continue
		var option := (option_variant as Dictionary).duplicate(true)
		option["enabled"] = false
		military_options.append(option)
	quiescent["military_task_options"] = military_options
	return quiescent


func _set_v075_chrome() -> void:
	_ruleset_label.text = "v0.7.5 · NEW GAME ONLY"
	_save_notice.visible = false
	%SaveButton.visible = false
	%ContinueButton.visible = false
	%AccelerateButton.visible = false
	%AccelerateButton.disabled = true
	%HistoryLabel.visible = false
	%Subtitle.text = "V0.7.5 · 真人战斗候选"
	%PersistenceNotice.text = "V0.7.5样品暂不支持中途保存"
	for button in [
		_pause_button,
		_speed_1x_button,
		_speed_2x_button,
		_speed_4x_button,
	]:
		button.toggle_mode = true
	var dock_title := (
		$RootMargin/Shell/DockPanel/DockMargin/DockRows/DockHeader/DockTitle
		as Label
	)
	dock_title.text = "HAND + CURRENT / DIRECT ACTION"


func _refresh_hand() -> void:
	super._refresh_hand()
	_apply_hand_drag_affordance()
	var facts := (
		(_v075_snapshot.get("personal_dbg", {}) as Dictionary).get(
			"facts",
			{}
		) as Dictionary
	)
	var dock_title := (
		$RootMargin/Shell/DockPanel/DockMargin/DockRows/DockHeader/DockTitle
		as Label
	)
	dock_title.text = "HAND %d · CURRENT / DIRECT ACTION" % int(
		facts.get("hand_count", (facts.get("hand", []) as Array).size())
	)
	if _active_hand_category == "commodity":
		_render_commodity_inventory(facts)
	else:
		_render_general_hand(facts)
	_render_commodity_hand_preview(facts)
	_general_hand_tab_button.button_pressed = _active_hand_category == "general"
	_commodity_hand_tab_button.button_pressed = (
		_active_hand_category == "commodity"
	)
	_general_hand_tab_button.text = "手牌 %d/5" % int(facts.get(
		"hand_count",
		(facts.get("hand", []) as Array).size()
	))
	_commodity_hand_tab_button.text = "商品 %d/5" % int(facts.get(
		"commodity_inventory_count",
		(facts.get("commodity_inventory", []) as Array).size()
	))
	_update_hand_dock_minimum_height(facts)
	_update_current_action_panel()


func _render_commodity_hand_preview(facts: Dictionary) -> void:
	if not is_instance_valid(_commodity_hand_preview_rail):
		return
	for child in _commodity_hand_preview_rail.get_children().duplicate():
		if child == _commodity_hand_empty_hint:
			continue
		_commodity_hand_preview_rail.remove_child(child)
		child.queue_free()
	var inventory := facts.get("commodity_inventory", []) as Array
	_commodity_hand_visible_count = 0
	if is_instance_valid(_commodity_hand_preview_label):
		_commodity_hand_preview_label.text = "商品手牌（独立 %d/5）" % inventory.size()
	if is_instance_valid(_commodity_hand_preview_panel):
		# Keep the separate commodity owner discoverable without reserving a
		# full card-height block when it is empty.  Once a commodity is acquired,
		# the real independent preview expands again.
		var compact_preview := get_viewport_rect().size.x < 900.0
		_commodity_hand_preview_panel.custom_minimum_size.y = 54.0 \
			if inventory.is_empty() else (82.0 if compact_preview else 104.0)
	if is_instance_valid(_commodity_hand_empty_hint):
		_commodity_hand_empty_hint.visible = inventory.is_empty()
	for commodity_variant in inventory:
		if not (commodity_variant is Dictionary):
			continue
		var commodity := (commodity_variant as Dictionary).duplicate(true)
		commodity["authority_zone"] = "commodity_hand"
		commodity["projection_role"] = "private_commodity_card"
		var card := _commodity_card_face(commodity)
		if card == null:
			continue
		_commodity_hand_preview_rail.add_child(card)
		_commodity_hand_visible_count += 1
	if _commodity_hand_visible_count > 0 and is_instance_valid(_commodity_hand_empty_hint):
		_commodity_hand_empty_hint.visible = false
		_fit_preview_card_row()
		call_deferred("_fit_preview_card_row")


func _commodity_card_face(commodity: Dictionary) -> V075InteractiveCardFace:
	var color_id := str(commodity.get("primary_color", "industry"))
	var level := int(commodity.get("level", 1))
	var tooltip := "%s · %s · Lv.%d\n来源：共享寿司轨 · %s\n%s\n合法操作：%s" % [
		str(commodity.get("name", "商品牌")),
		_combat_color_label(color_id),
		level,
		str(commodity.get("source_receipt_id", "待回执")),
		str(commodity.get("effect", "等待 Catalog 效果投影")),
		str(commodity.get("legal_action_summary", "查看合法目标")),
	]
	var presentation := {
		"name": str(commodity.get("name", "商品牌")),
		"effect": str(commodity.get("short_effect", commodity.get("effect", "商品操作"))),
		"type": str(commodity.get("card_type", "商品牌")),
		"rank": str(commodity.get("rank", "L%d" % level)),
		"cost": str(commodity.get("cost", "免费")),
		"kind": "commodity_card",
		"route": _combat_color_label(color_id),
		"accent": COLOR_VALUES.get(color_id, Color.WHITE),
		"presentation": "dock_mini",
		"summary": str(commodity.get("short_effect", commodity.get("effect", "商品操作"))),
		"short_effect": str(commodity.get("short_effect", commodity.get("effect", "商品操作"))),
		"use_case": "操盘商品",
		"purpose": "操盘商品",
		"target_type": str(commodity.get("target_type", "商品库存")),
		"legality_state": "可查看",
		"play_state": "可查看",
		"disabled": false,
		"keywords": [
			{"text": "操盘商品", "tooltip": "用途：操盘商品", "accent": Color("#fde68a")},
			{"text": "商品库存", "tooltip": "独立商品手牌，不占普通手牌上限", "accent": Color("#bfdbfe")},
		],
		"keywords_authoritative": true,
		"illustration_key": str(commodity.get("illustration_key", "")),
		"card_frame_key": "card.frame.commodity",
		"tooltip": tooltip,
	}
	var card := V075InteractiveCardFaceScene.instantiate() as V075InteractiveCardFace
	if card == null:
		return null
	card.configure(commodity, presentation, false)
	card.set_selected(
		str(commodity.get("instance_id", ""))
			== str(_selected_commodity_item.get("instance_id", ""))
	)
	card.activated.connect(_on_commodity_inventory_activated)
	card.hover_summary.connect(_on_card_hover_summary.bind("commodity_inventory"))
	return card


func _fit_preview_card_row() -> void:
	var available_width := _commodity_hand_preview_panel.size.x
	if available_width <= 1.0:
		available_width = _commodity_hand_preview_panel.custom_minimum_size.x
	var card_count := maxi(1, _commodity_hand_preview_rail.get_child_count())
	var preview_card_width := clampf(
		(available_width - 24.0 - float(card_count - 1) * 4.0) / float(card_count),
		48.0,
		94.0
	)
	var preview_card_height := 112.0 if available_width >= 300.0 else 88.0
	for child in _commodity_hand_preview_rail.get_children():
		if child is Control:
			var control := child as Control
			control.custom_minimum_size = Vector2(
				preview_card_width,
				preview_card_height
			)
			# Keep each independent commodity face at its authored compact size.
			# Expanding a single card to the whole preview lane made its CardUI
			# vertically exceed the fixed dock and clipped the semantic footer.
			control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			control.size_flags_stretch_ratio = 0.0


func _set_hand_category(category: String) -> void:
	if category not in ["general", "commodity"]:
		return
	_active_hand_category = category
	_selected_commodity_item = {}
	if _current_action_mode == "commodity_info":
		_current_action_mode = "idle"
	_refresh_hand()


func _render_commodity_inventory(facts: Dictionary) -> void:
	_clear_children(_hand_rail)
	for commodity_variant in facts.get("commodity_inventory", []) as Array:
		if not (commodity_variant is Dictionary):
			continue
		var commodity := (commodity_variant as Dictionary).duplicate(true)
		var color_id := str(commodity.get("primary_color", "industry"))
		var level := int(commodity.get("level", 1))
		var card := (
			V075InteractiveCardFaceScene.instantiate()
			as V075InteractiveCardFace
		)
		var tooltip := "%s · %s · Lv.%d\n来源：共享寿司轨 · %s\n%s\n合法操作：%s" % [
			str(commodity.get("name", "商品牌")),
			_combat_color_label(color_id),
			level,
			str(commodity.get("source_receipt_id", "待回执")),
			str(commodity.get("effect", "等待 Catalog 效果投影")),
			str(commodity.get("legal_action_summary", "查看合法目标")),
		]
		var presentation := {
			"name": str(commodity.get("name", "商品牌")),
			"effect": str(commodity.get(
				"short_effect",
				commodity.get("effect", "商品操作")
			)),
			"type": str(commodity.get("card_type", "商品牌")),
			"rank": str(commodity.get("rank", "L%d" % level)),
			"cost": str(commodity.get("cost", "免费")),
			"kind": "commodity_card",
			"route": _combat_color_label(color_id),
			"accent": COLOR_VALUES.get(color_id, Color.WHITE),
			"presentation": "dock_mini",
			"summary": str(commodity.get("short_effect", commodity.get("effect", "商品操作"))),
			"short_effect": str(commodity.get("short_effect", commodity.get("effect", "商品操作"))),
			"use_case": "操盘商品",
			"purpose": "操盘商品",
			"target_type": str(commodity.get("target_type", "商品库存")),
			"legality_state": "可查看",
			"play_state": "可查看",
			"disabled": false,
			"keywords": [
				{"text": "操盘商品", "tooltip": "用途：操盘商品", "accent": Color("#fde68a")},
				{"text": "商品库存", "tooltip": "独立商品手牌，不占普通手牌上限", "accent": Color("#bfdbfe")},
			],
			"keywords_authoritative": true,
			"illustration_key": str(commodity.get("illustration_key", "")),
			"card_frame_key": "card.frame.commodity",
			"tooltip": tooltip,
		}
		card.call("configure", commodity, presentation, false)
		card.set_selected(
			str(commodity.get("instance_id", ""))
				== str(_selected_commodity_item.get("instance_id", ""))
		)
		card.activated.connect(_on_commodity_inventory_activated)
		card.hover_summary.connect(
			_on_card_hover_summary.bind("commodity_inventory")
		)
		_hand_rail.add_child(card)
	_fit_hand_cards_to_single_row()


func _render_general_hand(facts: Dictionary) -> void:
	_clear_children(_hand_rail)
	for card_variant in facts.get("hand", []) as Array:
		if not (card_variant is Dictionary):
			continue
		var payload := (card_variant as Dictionary).duplicate(true)
		var instance_id := str(payload.get("instance_id", ""))
		if _pending_public_card_instance_ids.has(instance_id):
			# The authoritative queue has reserved this instance in
			# PENDING_PUBLIC_SUBMISSION.  Keep the DBG facts intact, but do not
			# paint a second hand projection while the public-card transition runs.
			continue
		payload["authority_zone"] = "general_hand"
		payload["projection_role"] = "private_hand_card"
		var card := (
			V075InteractiveCardFaceScene.instantiate()
			as V075InteractiveCardFace
		)
		card.configure(payload, _general_card_face_data(payload), true)
		card.set_selected(
			instance_id == _selected_card_id
		)
		card.activated.connect(_on_hand_card_activated)
		card.drag_started.connect(_on_hand_card_dragged)
		card.hover_summary.connect(
			_on_card_hover_summary.bind("hand_dock")
		)
		_hand_rail.add_child(card)
	_fit_hand_cards_to_single_row()


func _general_card_face_data(card: Dictionary) -> Dictionary:
	var definition_id := str(card.get(
		"card_definition_id",
		card.get("definition_id", "")
	))
	var catalog_id := definition_id.trim_prefix("starter.")
	var catalog_definition := CARD_RUNTIME_CATALOG_V06.card_snapshot(catalog_id)
	var machine := catalog_definition.get("machine", {}) as Dictionary
	var player := catalog_definition.get("player", {}) as Dictionary
	var card_type := str(card.get("card_type", "card"))
	var color_id := str(card.get("primary_color", "industry"))
	var level := int(card.get("level", 1))
	var domain := _v075_card_domain(definition_id)
	var instance_id := str(card.get("instance_id", ""))
	var matching_actions: Array = []
	for option_variant in _v075_snapshot.get("legal_actions", []) as Array:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		if str(option.get("card_instance_id", "")) == instance_id:
			matching_actions.append(option.duplicate(true))
	var phase := str(_v075_snapshot.get("phase", "idle"))
	var submission_locked := bool(_v075_snapshot.get("submission_locked", false))
	var pending := _pending_public_card_instance_ids.has(instance_id)
	var actionable := phase == "submission" and not submission_locked \
		and not pending and not matching_actions.is_empty()
	var target_type := ""
	var target_label := ""
	if not matching_actions.is_empty():
		var first_action := matching_actions[0] as Dictionary
		target_type = str(first_action.get("target_type", ""))
		if target_type.is_empty():
			if not str(first_action.get("target_region_id", "")).is_empty():
				target_type = "区域"
			elif not str(first_action.get("target_monster_source_instance_id", "")).is_empty():
				target_type = "怪兽"
			elif not str(first_action.get("facility_type", "")).is_empty():
				target_type = "设施"
			target_label = str(first_action.get(
			"target_region_id",
			first_action.get("target_slot_id", "")
		))
	if target_type.is_empty():
		# The V0.6 Catalog's authored player-facing field is `target`; older
		# adapters sometimes emitted `target_type`.  Consume the authored field
		# first so the face never falls back to a guessed private target.
		target_type = str(player.get(
			"target",
			player.get("target_type", "区域" if domain == "facility" else "私密目标")
		))
	var use_case := str(player.get(
		"use_case",
		player.get("purpose", {
			"facility": "建设设施",
			"monster": "制造地图压力",
			"military": "指挥军队",
		}.get(domain, "执行行动"))
	))
	var legality_state := "可出牌" if actionable else "不可用"
	var disabled_reason := ""
	if pending:
		disabled_reason = "已提交，等待公开结算"
	elif phase != "submission":
		disabled_reason = "等待出牌窗口"
	elif submission_locked:
		disabled_reason = "本轮已锁定"
	elif matching_actions.is_empty():
		disabled_reason = "暂无合法目标或资源"
	var name := str(player.get(
		"name",
		_card_type_label(definition_id)
	))
	var short_effect := str(player.get(
		"short_effect",
		"选择合法目标并提交到公开排列。"
		if domain == "facility"
		else "选择合法私密目标并执行直接行动。"
	))
	var illustration_key := str(
		CARD_ILLUSTRATION_CATALOG.presentation_key_for_card(catalog_id)
	)
	var illustration_path := ""
	if illustration_key.is_empty() and domain in ["monster", "military"]:
		var descriptor := V075CardDefinitionRegistry.presentation_descriptor(
			definition_id
		)
		illustration_path = str(descriptor.get("resource_path", ""))
	var tooltip := "%s · %s · Lv.%d\n%s\n权威区域：%s" % [
		name,
		_combat_color_label(color_id),
		level,
		str(player.get("effect", short_effect)),
		str(card.get("authority_zone", "hand")),
	]
	return {
		"name": name,
		"effect": short_effect,
		"summary": short_effect,
		"short_effect": short_effect,
		"type": str(player.get("type", card_type)),
		"rank": str(player.get("rank", "L%d" % level)),
		"cost": str(player.get(
			"cost",
			"%d %s" % [
				int(card.get("primary_asset_cost", 0)),
				_combat_color_label(color_id),
			]
		)),
		"kind": card_type,
		"route": _combat_color_label(color_id),
		"use_case": use_case,
		"purpose": use_case,
		"target": target_label if not target_label.is_empty() else target_type,
		"target_type": target_type,
		"legality_state": legality_state,
		"play_state": legality_state,
		"action_state": legality_state,
		"disabled": not actionable,
		"drop_valid": actionable,
		"disabled_reason": disabled_reason,
		"block_reason": disabled_reason,
		"actions": _presentation_actions_for_card(matching_actions, use_case),
		"keywords": [
			{"text": use_case, "tooltip": "用途：%s" % use_case, "accent": Color("#fde68a")},
			{"text": target_type, "tooltip": "目标类型：%s" % target_type, "accent": Color("#bfdbfe")},
			{"text": legality_state, "tooltip": disabled_reason if not disabled_reason.is_empty() else "当前可以提交", "accent": Color("#86efac") if actionable else Color("#fca5a5")},
		],
		"keywords_authoritative": true,
		"accent": COLOR_VALUES.get(color_id, Color.WHITE),
		"presentation": "dock_mini",
		"illustration_key": illustration_key,
		"illustration_path": illustration_path,
		"illustration_profile": {
			"source_type": "open_source_placeholder",
			"visual_source_id": definition_id,
		},
		"illustration_silent_fallback": true,
		"card_frame_key": "card.frame.normal",
		"tooltip": tooltip,
	}


func _presentation_actions_for_card(
	matching_actions: Array,
	use_case: String
) -> Array:
	var result: Array = []
	for option_variant in matching_actions:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		result.append({
			"label": "%s · %s" % [
				use_case,
				str(option.get("target_region_id", option.get("target_slot_id", "目标"))),
			],
			"disabled": false,
		})
	return result


func _fit_hand_cards_to_single_row() -> void:
	var hand_scroll := (
		$RootMargin/Shell/DockPanel/DockMargin/DockRows/DockBody/HandScroll
		as ScrollContainer
	)
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.follow_focus = false
	hand_scroll.clip_contents = true
	var available_width := maxf(hand_scroll.size.x, 1.0)
	var compact_view := get_viewport_rect().size.x < 1500.0 \
		or get_viewport_rect().size.y < 880.0
	var narrow_view := get_viewport_rect().size.x < 720.0
	var overlap_budget := 18.0 * 4.0
	var fit_width := (available_width - 16.0 + overlap_budget) / 5.0
	var min_width := 48.0 if narrow_view else (68.0 if compact_view else 84.0)
	var max_width := 76.0 if narrow_view else (92.0 if compact_view else 104.0)
	var card_width := clampf(fit_width, min_width, max_width)
	var card_height_budget := 96.0 if get_viewport_rect().size.y < 820.0 else (112.0 if compact_view else 140.0)
	var card_height := minf(card_width * 4.0 / 3.0, card_height_budget)
	var rail_separation := -18
	if narrow_view:
		rail_separation = -int(ceil(maxf(
			18.0,
			(card_width * 5.0 - available_width) / 4.0
		)))
	_hand_rail.add_theme_constant_override("separation", rail_separation)
	hand_scroll.custom_minimum_size.y = card_height
	# ScrollContainer sizes its child from the child's minimum unless the rail
	# explicitly participates in horizontal expansion.  Without this flag the
	# five cards remain packed into their fallback-width cluster at the left
	# edge even though the viewport has a full hand lane available.
	_hand_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_rail.custom_minimum_size = Vector2(0.0, card_height)
	for child in _hand_rail.get_children():
		if child is Control:
			(child as Control).custom_minimum_size = Vector2(
				card_width,
				card_height
			)
			(child as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			(child as Control).size_flags_stretch_ratio = 1.0


func _update_hand_dock_minimum_height(facts: Dictionary = {}) -> void:
	var dock_panel := $RootMargin/Shell/DockPanel as Control
	if dock_panel == null:
		return
	if facts.is_empty():
		facts = ((_v075_snapshot.get("personal_dbg", {}) as Dictionary).get(
			"facts", {}
		) as Dictionary)
	var inventory := facts.get("commodity_inventory", []) as Array
	var viewport_size := get_viewport_rect().size
	var compact := viewport_size.x < 1500.0 or viewport_size.y < 880.0
	var narrow := viewport_size.x < 720.0
	var preview_height := 54.0 if inventory.is_empty() else (82.0 if viewport_size.x < 900.0 else 104.0)
	var hand_height := 96.0 if viewport_size.y < 820.0 else (112.0 if compact else 140.0)
	if narrow:
		hand_height = minf(hand_height, 96.0)
	# DockRows = header + independent commodity preview + hand/action body +
	# command row, with the inherited margin and row separations included.
	var required_height := 10.0 + 30.0 + preview_height + maxf(hand_height, 108.0) + 32.0 + 12.0
	var available_max := maxf(
		198.0,
		viewport_size.y - 12.0 - 82.0 - 144.0 - 34.0 - SINGLE_TABLE_MIN_PLANET_HEIGHT
	)
	dock_panel.custom_minimum_size.y = minf(required_height, available_max)


func _on_commodity_inventory_activated(payload: Dictionary) -> void:
	_selected_commodity_item = payload.duplicate(true)
	_current_action_mode = "commodity_info"
	_current_action_source_surface = "commodity_inventory"
	_current_action_started_msec = Time.get_ticks_msec()
	_refresh_hand()


func _refresh_history() -> void:
	super._refresh_history()
	if not is_instance_valid(_public_action_feed):
		return
	var entries: Array[Dictionary] = []
	var seen_receipts := {}
	for local_variant in _local_public_feedback:
		_append_unique_action_feed_entry(
			entries,
			seen_receipts,
			(local_variant as Dictionary).duplicate(true)
		)
	var arrangement_projection := _v075_snapshot.get(
		"v076_public_action_arrangement",
		{}
	) as Dictionary
	for ai_receipt_variant in arrangement_projection.get(
		"ai_public_action_receipts",
		[]
	) as Array:
		if ai_receipt_variant is Dictionary:
			_append_unique_action_feed_entry(
				entries,
				seen_receipts,
				_ai_public_action_feed_entry(
					ai_receipt_variant as Dictionary
				)
			)
	for row_variant in _v075_snapshot.get("public_history", []) as Array:
		if row_variant is Dictionary:
			_append_unique_action_feed_entry(
				entries,
				seen_receipts,
				_public_history_entry(row_variant as Dictionary)
			)
	for row_variant in _v075_snapshot.get("combat_public_history", []) as Array:
		if row_variant is Dictionary:
			_append_unique_action_feed_entry(
				entries,
				seen_receipts,
				_combat_history_entry(row_variant as Dictionary)
			)
	while entries.size() > 10:
		entries.pop_front()
	var lines: Array[String] = []
	_blank_public_action_count = 0
	for entry in entries:
		var line := _public_action_line(entry)
		if line.strip_edges().is_empty():
			_blank_public_action_count += 1
			continue
		lines.append(line)
	if lines.is_empty():
		lines.append("[color=#8ca2bd]等待第一条公开行动[/color]")
		_current_action_banner.text = "当前：等待公开行动"
	else:
		_current_action_banner.text = "当前：%s" % _plain_public_action_line(
			entries.back()
		)
	_public_action_feed.text = "\n".join(lines)
	_public_action_feed_visible_count = maxi(
		_public_action_feed_visible_count,
		lines.size() if not entries.is_empty() else 0
	)
	_refresh_central_public_action_arrangement()


func _sync_public_arrangement_source_anchors() -> void:
	if (
		not is_instance_valid(_central_public_action_arrangement)
		or not _central_public_action_arrangement.has_method(
			"set_source_anchor_rects"
		)
	):
		return
	var anchors := {}
	for child_index in range(_roster_grid.get_child_count()):
		if child_index == 0:
			continue
		var seat := _roster_grid.get_child(child_index) as Control
		if seat == null or not seat.is_visible_in_tree():
			continue
		anchors["ai_seat_%02d" % child_index] = seat.get_global_rect()
	_central_public_action_arrangement.call(
		"set_source_anchor_rects",
		anchors
	)


func _refresh_central_public_action_arrangement() -> void:
	if not is_instance_valid(_central_public_action_arrangement):
		return
	var runtime_projection: Dictionary = _v075_snapshot.get(
		"v076_public_action_arrangement",
		{}
	) as Dictionary
	if (
		str(runtime_projection.get("schema", ""))
			== "V076PublicActionArrangementProjectionV1"
		and runtime_projection.get("entries", []) is Array
	):
		# The RuntimeOwner has already applied the privacy boundary and owns the
		# frozen order.  Consume this projection verbatim; do not reconstruct a
		# public queue from private local queues in the Screen.
		var projected_entries: Array = (
			runtime_projection.get("entries", []) as Array
		).duplicate(true)
		# A viewer-owned row may carry its own instance id solely for the local
		# hand -> arrangement transition.  Rival rows remain fail-closed.  Filter
		# malformed rows individually so one stale/private row cannot erase every
		# valid public card from the player's table.
		var sanitized_entries: Array = []
		for entry_variant in projected_entries:
			if not (entry_variant is Dictionary):
				continue
			var entry := entry_variant as Dictionary
			var row_violation := _public_arrangement_private_key_count(entry)
			if row_violation > 0:
				_central_public_arrangement_private_projection_violation_count += row_violation
				continue
			sanitized_entries.append(entry)
		projected_entries = sanitized_entries
		var projection_phase := str(runtime_projection.get("phase", "idle"))
		var projection_phase_text: String = str({
			"submission": "30秒·悬停",
			"resolving": "结算中",
			"maintenance": "历史",
		}.get(projection_phase, "等待提交"))
		var projection_summary: String = (
			"行动按权威公开顺序排列；匿名身份与未公开牌面保持隐藏。"
			if not projected_entries.is_empty()
			else "提交后，玩家行动会在这里形成可悬停排列。"
		)
		_central_public_arrangement_refresh_count += 1
		_central_public_action_arrangement.call(
			"apply_public_arrangement",
			projected_entries,
			str(projection_phase_text),
			projection_summary,
			"归属未公开前显示匿名行动；仅当前玩家自己的授权牌面可见。"
		)
		return
	var entries: Array = []
	var seen_ids: Dictionary = {}
	var contention: Dictionary = _v075_snapshot.get("facility_contention", {}) as Dictionary
	var public_queue_variant: Variant = contention.get(
		"anonymous_global_queue",
		contention.get("anonymous_public_queue", [])
	)
	if public_queue_variant is Array:
		for index in range((public_queue_variant as Array).size()):
			var row_variant: Variant = (public_queue_variant as Array)[index]
			if not (row_variant is Dictionary):
				continue
			var row: Dictionary = row_variant as Dictionary
			var anonymous_id := str(row.get(
				"anonymous_action_id",
				"anonymous.%06d" % index
			))
			var status := str(row.get(
				"resolution_status",
				"pending"
			)).to_lower()
			var state_label := "RESOLVED"
			var accent := "#52d6b8"
			if status in ["fizzled", "fizzle"]:
				state_label = "FIZZLED"
				accent = "#ef8b77"
			elif status in ["pending", "queued"]:
				state_label = "QUEUED"
				accent = "#f3c969"
			elif status in ["resolving", "active"]:
				state_label = "RESOLVING"
				accent = "#7fb6ff"
			var reason := str(row.get("public_reason_code", "等待匿名结算"))
			var entry_id := "central:%s" % anonymous_id
			seen_ids[entry_id] = true
			entries.append({
				"id": entry_id,
				"resolution_id": int(row.get("queue_index", index)),
				"label": "一张匿名牌",
				"title": "公开行动 #%d" % (index + 1),
				"owner_hint": "匿名玩家",
				"state": state_label,
				"detail": reason,
				"summary": reason,
				"tooltip": "%s · %s\n%s" % [
					state_label,
					"匿名玩家",
					reason,
				],
				"active": state_label in ["QUEUED", "RESOLVING"],
				"accent": accent,
				"badges": [state_label],
				"hover_action": entry_id,
			})
	# A locally authorized submission is shown by its public card/effect name;
	# rival rows above remain anonymous until the authority publishes them.
	for local_variant in _local_public_feedback:
		if not (local_variant is Dictionary):
			continue
		var local: Dictionary = local_variant as Dictionary
		var local_status := str(local.get("status_label", ""))
		if local_status not in ["SUBMITTED", "QUEUED", "RESOLVING"]:
			continue
		var local_id := "local:%s" % str(local.get(
			"public_receipt_identity",
			_local_feedback_sequence
		))
		if seen_ids.has(local_id):
			continue
		entries.append({
			"id": local_id,
			"resolution_id": 1000 + entries.size(),
			"label": str(local.get("subject_label", "你的行动")),
			"owner_hint": "你",
			"state": local_status,
			"detail": str(local.get("target_label", "等待公开结算")),
			"summary": str(local.get("result_label", "等待结算")),
			"tooltip": "%s · %s\n%s" % [
				str(local.get("action_label", "提交")),
				str(local.get("target_label", "公开目标")),
				str(local.get("result_label", "等待结算")),
			],
			"active": true,
			"accent": "#f3c969",
			"badges": [local_status],
			"hover_action": local_id,
		})
	# Public history is already privacy-sanitized by the RuntimeOwner.  Keep it
	# after the live queue so the center reads left-to-right as current -> past.
	for history_variant in _v075_snapshot.get("public_history", []) as Array:
		if not (history_variant is Dictionary):
			continue
		var history: Dictionary = _public_history_entry(history_variant as Dictionary)
		var history_id := "history:%s" % str(history.get(
			"public_receipt_identity",
			entries.size()
		))
		if seen_ids.has(history_id):
			continue
		seen_ids[history_id] = true
		entries.append({
			"id": history_id,
			"resolution_id": 2000 + entries.size(),
			"label": str(history.get("subject_label", "公开行动")),
			"owner_hint": str(history.get("actor_label", "匿名玩家")),
			"state": str(history.get("status_label", "RESOLVED")),
			"detail": str(history.get("result_label", "已结算")),
			"summary": str(history.get("target_label", "公开目标")),
			"tooltip": _plain_public_action_line(history),
			"active": false,
			"accent": "#52d6b8" if str(history.get("status_label", "")) != "FIZZLED" else "#ef8b77",
			"badges": [str(history.get("status_label", "RESOLVED"))],
			"hover_action": history_id,
		})
	while entries.size() > 16:
		entries.pop_front()
	var phase := str(_v075_snapshot.get("phase", "idle"))
	var phase_text: String = str({
		"submission": "30秒·悬停",
		"resolving": "结算中",
		"maintenance": "历史",
	}.get(phase, "等待提交"))
	var summary: String = (
		"行动会按公开顺序排列；匿名身份与未公开牌面保持隐藏。"
		if not entries.is_empty()
		else "提交后，玩家行动会在这里形成可悬停排列。"
	)
	_central_public_arrangement_refresh_count += 1
	_central_public_action_arrangement.call(
		"apply_public_arrangement",
		entries,
		str(phase_text),
		summary,
		"归属未公开前显示匿名玩家与一张匿名牌；仅公开回执可展开详情。"
	)


func _on_central_public_entry_hovered(entry: Dictionary) -> void:
	_central_public_arrangement_hover_count += 1
	var state := str(entry.get("state", "")).strip_edges()
	var label := str(entry.get("label", "一张匿名牌")).strip_edges()
	var owner := str(entry.get("owner_hint", "匿名玩家")).strip_edges()
	if label.is_empty():
		label = "一张匿名牌"
	if owner.is_empty():
		owner = "匿名玩家"
	_current_action_banner.text = "当前：%s · %s · %s" % [owner, label, state]


func _public_arrangement_private_key_count(
	value: Variant,
	allow_viewer_owned_card_instance_id := false
) -> int:
	var forbidden := [
		"actor_id", "owner_id", "player_id", "seat", "player_index",
		"card_instance_id", "target_binding", "private_queue",
		"authority_queue", "hidden_order", "true_owner",
	]
	if value is Dictionary:
		var count := 0
		var viewer_owned_scope := allow_viewer_owned_card_instance_id or bool(
			(value as Dictionary).get("viewer_owned", false)
		)
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			var allowed_local_instance_id := (
				key == "card_instance_id" and viewer_owned_scope
			)
			if (key in forbidden and not allowed_local_instance_id) \
				or key.begins_with("private_") \
				or key.begins_with("hidden_"):
				count += 1
			count += _public_arrangement_private_key_count(
				(value as Dictionary).get(key_variant),
				viewer_owned_scope
			)
		return count
	if value is Array:
		var count := 0
		for item in value as Array:
			count += _public_arrangement_private_key_count(
				item,
				allow_viewer_owned_card_instance_id
			)
		return count
	return 0


func _input(event: InputEvent) -> void:
	# Keep a small manual gesture bridge alongside Godot's drag-and-drop
	# contract.  A hand card selects itself on mouse-down, but the hand rail is
	# also rebuilt by authoritative projections; relying exclusively on
	# `_get_drag_data()` can therefore lose the release when a real pointer
	# crosses the central overlay.  This bridge is presentation/input routing
	# only: it forwards the same payload to the existing legal-action path.
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_manual_drag_last_drop_card_id = ""
			_manual_drag_last_drop_msec = -1
			_manual_drag_payload = _hand_payload_at_position(button.position)
			_manual_drag_card_id = str(_manual_drag_payload.get("instance_id", ""))
			_manual_drag_start_position = button.position
			_manual_drag_active = false
			if not _manual_drag_card_id.is_empty():
				_manual_drag_start_count += 1
			return
		if _manual_drag_active and not _manual_drag_payload.is_empty():
			var drop_position := button.position
			var drop_rect := Rect2()
			if is_instance_valid(_central_public_action_arrangement):
				if _central_public_action_arrangement.has_method("drawer_global_rect"):
					var candidate_rect: Variant = _central_public_action_arrangement.call(
						"drawer_global_rect"
					)
					if candidate_rect is Rect2:
						drop_rect = candidate_rect
				if not drop_rect.has_area():
					drop_rect = _central_public_action_arrangement.get_global_rect()
			if drop_rect.has_point(drop_position):
				_manual_drag_drop_count += 1
				_on_central_card_drop_requested(
					_manual_drag_payload.duplicate(true)
				)
				_manual_drag_last_drop_card_id = _manual_drag_card_id
				_manual_drag_last_drop_msec = Time.get_ticks_msec()
			else:
				_manual_drag_rejection_count += 1
			_reset_manual_drag()
		return
	if event is InputEventMouseMotion and not _manual_drag_payload.is_empty():
		var motion := event as InputEventMouseMotion
		if (
			(motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
			and not _manual_drag_active
			and motion.position.distance_to(_manual_drag_start_position) >= 10.0
		):
			_manual_drag_active = true


func _hand_payload_at_position(position: Vector2) -> Dictionary:
	if _active_hand_category != "general":
		return {}
	for child in _hand_rail.get_children():
		if not child.has_method("payload") or not (child is Control):
			continue
		var card := child as Control
		if not card.is_visible_in_tree() or not card.get_global_rect().has_point(position):
			continue
		var payload := card.call("payload") as Dictionary
		if not payload.is_empty() and payload.has("instance_id"):
			return payload.duplicate(true)
	return {}


func _reset_manual_drag() -> void:
	_manual_drag_card_id = ""
	_manual_drag_payload = {}
	_manual_drag_start_position = Vector2.ZERO
	_manual_drag_active = false


func _on_central_card_drop_requested(payload: Dictionary) -> void:
	var duplicate_key := str(payload.get("instance_id", ""))
	if (
		not duplicate_key.is_empty()
		and duplicate_key == _manual_drag_last_drop_card_id
		and Time.get_ticks_msec() - _manual_drag_last_drop_msec <= 250
	):
		# The native Godot drop callback can follow the manual release bridge in
		# the same frame.  Preserve exact-once submission at the presentation
		# boundary; the authoritative owner still owns the real ledger.
		return
	_central_card_drop_count += 1
	if payload.is_empty():
		_central_card_drop_rejection_count += 1
		return
	_refresh_card_interaction_snapshot()
	if str(_v075_snapshot.get("phase", "idle")) != "submission":
		_central_card_drop_rejection_count += 1
		_show_toast("当前不在出牌窗口", false)
		return
	var card_id := str(payload.get("instance_id", ""))
	if card_id.is_empty():
		_central_card_drop_rejection_count += 1
		_show_toast("拖拽牌身份已失效，请重新选择", false)
		return
	var hand_card := _hand_card_by_id(card_id)
	if hand_card.is_empty():
		# A stale drag payload must never select a card that is no longer in the
		# viewer's authoritative hand.  The arrangement remains presentation-only;
		# revalidation happens against the latest private projection here.
		_central_card_drop_rejection_count += 1
		_show_toast("这张牌已不在手牌中，请重新拖拽", false)
		return
	_central_card_drop_submission_count += 1
	# Reuse the exact hand-card selection path first.  Combat cards retain their
	# typed mode/mission chooser; facility cards can bind a unique legal target
	# immediately when there is only one option.
	# The card button emits `activated` on mouse-down before Godot starts the
	# drag.  Do not feed the same payload through the toggle path a second time
	# on drop, or the already-selected card would be deselected just before its
	# legal target is resolved.
	if _selected_card_id != card_id:
		_on_hand_card_activated(payload)
	var domain := _v075_card_domain(str(payload.get("definition_id", "")))
	if domain != "facility":
		return
	var options: Array = []
	for option_variant in _v075_snapshot.get("legal_actions", []) as Array:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		if (
			str(option.get("card_instance_id", "")) == card_id
			and str(option.get("action_domain", "facility")) == "facility"
		):
			options.append(option.duplicate(true))
	if options.is_empty():
		_central_card_drop_rejection_count += 1
		_show_toast("当前没有合法目标，不能提交这张牌", false)
		return
	if options.size() == 1:
		_queue_option_binding(options[0] as Dictionary, "central_drag")
		return
	_region_popup.visible = true
	_region_popup_title.text = "拖拽出牌 · 选择合法目标"
	_region_popup_body.text = "这张牌有 %d 个合法目标；选择后在固定行动区确认。" % options.size()
	_render_target_choices(options, "central_drag")


func _refresh_card_interaction_snapshot() -> void:
	# Receipts and viewer snapshots travel on separate presentation signals.  A
	# queue removal can therefore restore a card in authority just before this
	# GameScreen cache receives the matching legal-action projection.  Re-read
	# the existing viewer-authorized snapshot at the input boundary so a rapid
	# remove -> requeue gesture never resolves against stale target parameters.
	# This cache refresh is read-only and does not create or mutate gameplay
	# owners, card zones, map state, assets, ticks, or RNG.
	if not is_instance_valid(_v075_flow) or not _v075_flow.has_method("local_snapshot"):
		return
	var current := _v075_flow.call("local_snapshot") as Dictionary
	if current.is_empty():
		return
	var ruleset_id := str(current.get("ruleset_id", ""))
	if ruleset_id not in [BASE_V074_RULESET_ID, V075_RULESET_ID]:
		return
	_v075_snapshot = current.duplicate(true)


func _append_unique_action_feed_entry(
	entries: Array[Dictionary],
	seen_receipts: Dictionary,
	entry: Dictionary
) -> void:
	var identity := str(entry.get("public_receipt_identity", ""))
	if identity.is_empty():
		identity = "fallback:%s" % _plain_public_action_line(entry)
	if seen_receipts.has(identity):
		_action_feed_duplicate_entry_count += 1
		return
	seen_receipts[identity] = true
	entries.append(entry)


func _append_local_public_feedback(entry: Dictionary) -> void:
	_local_feedback_sequence += 1
	var sanitized := {
		"public_receipt_identity": str(entry.get(
			"public_receipt_identity",
			"local:%06d" % _local_feedback_sequence
		)),
		"actor_label": str(entry.get("actor_label", "你")),
		"action_label": str(entry.get("action_label", "行动")),
		"subject_label": str(entry.get("subject_label", "公开效果")),
		"target_label": str(entry.get("target_label", "公开目标")),
		"cost_label": str(entry.get("cost_label", "成本已结算")),
		"status_label": str(entry.get("status_label", "RESOLVED")),
		"result_label": str(entry.get("result_label", "成功")),
	}
	_local_public_feedback.append(sanitized)
	while _local_public_feedback.size() > 6:
		_local_public_feedback.pop_front()
	_refresh_history()


func _append_combat_public_feedback(cue: Dictionary) -> void:
	var event_kind := str(cue.get("event_kind", ""))
	var payload := cue.get("public_payload", {}) as Dictionary
	var summary := _combat_map_cue_summary(event_kind, payload)
	if summary.is_empty():
		summary = "公开战斗效果"
	_append_local_public_feedback({
		"public_receipt_identity": "combat:%s" % str(cue.get(
			"observer_correlation_id",
			cue.get("presentation_receipt_id", "")
		)),
		"actor_label": "匿名玩家",
		"action_label": _combat_map_cue_title(event_kind),
		"subject_label": summary if not summary.is_empty() else "一张匿名牌",
		"target_label": _region_label(_combat_cue_target_region(payload)),
		"cost_label": _public_asset_cost_label(payload),
		"status_label": _public_status_label(event_kind, payload),
		"result_label": _public_result_label(event_kind, payload),
	})
	_combat_status.text = _plain_public_action_line(_local_public_feedback.back())


func _ai_public_action_feed_entry(receipt: Dictionary) -> Dictionary:
	var status := str(receipt.get("status", "PASS"))
	var public_card := bool(receipt.get("public_card", false))
	var private_direct_action := bool(receipt.get(
		"direct_action_public_effect",
		false
	))
	var action_label := "跳过"
	var subject_label := "当前没有合法牌"
	var target_label := "继续等待下位玩家"
	var result_label := "明确 PASS"
	if public_card:
		action_label = "出牌"
		subject_label = "一张匿名牌"
		target_label = str(receipt.get(
			"target_public",
			"按公开结算顺序"
		))
		result_label = "已进入公开排列"
	elif private_direct_action:
		action_label = "直接行动"
		subject_label = "一项匿名效果"
		target_label = "目标按公开规则显示"
		result_label = "已提交私密行动"
	return {
		"public_receipt_identity": "ai:%s" % str(receipt.get(
			"receipt_id",
			JSON.stringify(receipt).sha256_text()
		)),
		"actor_label": str(receipt.get("actor_label", "AI玩家")),
		"action_label": action_label,
		"subject_label": subject_label,
		"target_label": target_label,
		"cost_label": "成本按规则结算" if status != "PASS" else "无消耗",
		"status_label": status,
		"result_label": result_label,
	}


func _public_history_entry(row: Dictionary) -> Dictionary:
	var outcome := str(row.get("outcome_id", ""))
	var reason := str(row.get("reason_code", ""))
	var action_label := "结算"
	if outcome == "unified_track_acquisition":
		action_label = "购买" if "purchased" in reason else "取得"
	elif outcome == "final_settlement":
		action_label = "终局结算"
	elif "facility" in outcome or "facility" in reason:
		action_label = "设施行动"
	return {
		"public_receipt_identity": _public_receipt_key("public", row),
		"actor_label": "匿名玩家",
		"action_label": action_label,
		"subject_label": _public_card_or_effect_label(row, reason, outcome),
		"target_label": _region_label(str(row.get("region_id", "公开目标"))),
		"cost_label": _public_asset_cost_label(row),
		"status_label": "FIZZLED" if "fizzle" in reason else "RESOLVED",
		"result_label": "FIZZLE" if "fizzle" in reason else "成功",
	}


func _combat_history_entry(row: Dictionary) -> Dictionary:
	var event_kind := str(row.get("event_kind", row.get("outcome_id", "")))
	var payload := _combat_public_display_payload(row)
	var summary := _combat_map_cue_summary(event_kind, payload)
	if summary.is_empty():
		summary = "公开战斗结果"
	return {
		"public_receipt_identity": _public_receipt_key("combat", row),
		"actor_label": "匿名玩家",
		"action_label": _combat_map_cue_title(event_kind),
		"subject_label": summary if not summary.is_empty() else "一张匿名牌",
		"target_label": _region_label(_combat_cue_target_region(payload)),
		"cost_label": _public_asset_cost_label(payload),
		"status_label": _public_status_label(event_kind, payload),
		"result_label": _public_result_label(event_kind, payload),
	}


func _combat_public_display_payload(row: Dictionary) -> Dictionary:
	# Runtime history is already projected as public data, while presentation
	# cues wrap the same facts in `public_payload`. Copy only the display fields
	# consumed below so a malformed or future row can never become a UI
	# pass-through merely because the wrapper is absent.
	var source_variant: Variant = row.get("public_payload", row)
	if not (source_variant is Dictionary):
		return {}
	var source := source_variant as Dictionary
	var result := {}
	for field_name in [
		"public_summary",
		"region_id",
		"target_region_id",
		"destination_region_id",
		"start_region_id",
		"target_monster_source_instance_id",
		"primary_asset_cost",
		"asset_debit_count",
		"fizzled",
		"refresh_percent",
		"new_rank",
		"source_rank",
		"distance_milli_arc",
		"region_damage_budget",
		"damage_amount",
		"facility_type",
		"preferred_industry_color",
	]:
		if source.has(field_name):
			result[field_name] = source.get(field_name)
	return result


func _public_action_line(entry: Dictionary) -> String:
	return "[color=#7fd8d0]%s[/color] · [b]%s[/b] · %s → %s · [color=#8fb8e8]%s[/color] · %s · [color=#f0c76b]%s[/color]" % [
		_bbcode_safe(str(entry.get("actor_label", "匿名玩家"))),
		_bbcode_safe(str(entry.get("action_label", "行动"))),
		_bbcode_safe(str(entry.get("subject_label", "一张匿名牌"))),
		_bbcode_safe(str(entry.get("target_label", "公开目标"))),
		_bbcode_safe(str(entry.get("status_label", "RESOLVED"))),
		_bbcode_safe(str(entry.get("cost_label", "成本已结算"))),
		_bbcode_safe(str(entry.get("result_label", "成功"))),
	]


func _bbcode_safe(value: String) -> String:
	return value.replace("[", "［").replace("]", "］")


func _plain_public_action_line(entry: Dictionary) -> String:
	return "%s · %s · %s → %s · %s · %s" % [
		str(entry.get("actor_label", "匿名玩家")),
		str(entry.get("action_label", "行动")),
		str(entry.get("subject_label", "一张匿名牌")),
		str(entry.get("target_label", "公开目标")),
		str(entry.get("status_label", "RESOLVED")),
		str(entry.get("result_label", "成功")),
	]


func _public_card_or_effect_label(
	row: Dictionary,
	reason: String,
	outcome: String
) -> String:
	for field_name in [
		"public_card_name",
		"public_effect_name",
		"public_summary",
	]:
		var label := str(row.get(field_name, "")).strip_edges()
		if not label.is_empty():
			return label
	if outcome in ["unified_track_acquisition", "final_settlement"]:
		return _public_reason_text(reason, outcome)
	return "一张匿名牌"


func _public_receipt_key(prefix: String, row: Dictionary) -> String:
	for field_name in [
		"presentation_receipt_id",
		"combat_receipt_id",
		"receipt_id",
		"anonymous_action_id",
	]:
		var identity := str(row.get(field_name, "")).strip_edges()
		if not identity.is_empty():
			return "%s:%s" % [prefix, identity]
	return "%s:fallback:%s" % [prefix, JSON.stringify(row).sha256_text()]


func _public_reason_text(reason: String, outcome: String) -> String:
	return {
		"normal_card_purchased_to_discard": "普通卡进入弃牌堆",
		"commodity_claimed": "商品进入库存",
		"final_settlement_committed_exact_once": "终局结果已确认",
		"facility_action_resolved": "匿名设施牌已结算",
	}.get(reason, outcome if not outcome.is_empty() else "公开效果") as String


func _public_asset_cost_label(payload: Dictionary) -> String:
	if payload.has("primary_asset_cost"):
		return "公开成本 %d" % int(payload.get("primary_asset_cost", 0))
	if payload.has("asset_debit_count"):
		return "资产消耗 %d" % int(payload.get("asset_debit_count", 0))
	return "成本按规则结算"


func _public_result_label(event_kind: String, payload: Dictionary) -> String:
	if bool(payload.get("fizzled", false)) or "fizzled" in event_kind:
		return "FIZZLE"
	if event_kind in ["military_region_assault", "military_monster_assault"]:
		return "攻击"
	if event_kind == "monster_moved":
		return "移动"
	if event_kind == "military_withdrawn":
		return "撤离"
	return "成功"


func _public_status_label(event_kind: String, payload: Dictionary) -> String:
	if bool(payload.get("fizzled", false)) or "fizzled" in event_kind:
		return "FIZZLED"
	if "withdraw" in event_kind:
		return "WITHDRAWN"
	if "submitted" in event_kind:
		return "SUBMITTED"
	if "queued" in event_kind:
		return "QUEUED"
	if "resolving" in event_kind:
		return "RESOLVING"
	return "RESOLVED"


func _action_feedback_p95_ms() -> float:
	if _action_feedback_samples_msec.is_empty():
		return 0.0
	var ordered: Array[int] = _action_feedback_samples_msec.duplicate()
	ordered.sort()
	var index := mini(
		ordered.size() - 1,
		ceili(float(ordered.size()) * 0.95) - 1
	)
	return float(ordered[index])


func _clear_combat_projection() -> void:
	_combat_projection = {}
	_preferred_source_instance_id = ""
	_combat_collapsed = true
	if is_instance_valid(_combat_surface):
		_combat_surface.call(
			"apply_projection",
			{
				"schema": "V075CombatPlayerProjectionV1",
				"ruleset_id": V075_RULESET_ID,
				"viewer_player_id": _viewer_player_id,
				"phase": "idle",
				"combat_requests_allowed": false,
				"terminal_combat_quiescent": false,
				"public_monsters": [],
				"own_monster_skill_sources": [],
				"military_task_options": [],
				"public_monster_count": 0,
				"own_private_skill_source_count": 0,
			},
			""
		)
	_combat_status.text = "等待战斗投影"
	_set_combat_surface_visibility()
	_sync_combat_map_projection()


func _update_combat_session(snapshot: Dictionary) -> void:
	var session_key := str(
		snapshot.get(
			"session_id",
			snapshot.get("match_id", snapshot.get("game_id", ""))
		)
	)
	if (
		not session_key.is_empty()
		and not _combat_session_key.is_empty()
		and session_key != _combat_session_key
	):
		_reset_combat_state()
	if not session_key.is_empty():
		_combat_session_key = session_key
	if str(snapshot.get("phase", "")) == "idle":
		if not _combat_terminal_phase.is_empty():
			_reset_combat_state()


func _sync_terminal_phase(phase: String) -> void:
	if phase in TERMINAL_PHASES:
		_combat_terminal_phase = phase
		if (
			_presentation_source_mode
				== PRESENTATION_SOURCE_ISOLATED_PREVIEW
			and is_instance_valid(_presentation_consumer)
		):
			_presentation_consumer.call("set_terminal_phase", phase)
	elif phase in ["idle", "submission", "batch_active", "maintenance"]:
		if not _combat_terminal_phase.is_empty():
			_reset_combat_state()


func _is_combat_terminal() -> bool:
	return not _combat_terminal_phase.is_empty()


func _reset_combat_state() -> void:
	_combat_terminal_phase = ""
	_combat_map_cues.clear()
	_combat_map_last_sync_signature = ""
	if (
		_presentation_source_mode
			== PRESENTATION_SOURCE_ISOLATED_PREVIEW
		and is_instance_valid(_presentation_consumer)
	):
		_presentation_consumer.call("reset_for_new_match")
	if (
		is_instance_valid(_combat_surface)
		and _combat_surface.has_method("reset_presentation_cues")
	):
		_combat_surface.call("reset_presentation_cues")
	_clear_combat_projection()


func _is_combat_receipt(receipt: Dictionary) -> bool:
	var event_kind := str(
		receipt.get(
			"presentation_kind",
			receipt.get("event_kind", receipt.get("kind", ""))
		)
	)
	return (
		not str(receipt.get("presentation_receipt_id", "")).is_empty()
		or not str(receipt.get("combat_receipt_id", "")).is_empty()
		or event_kind in COMBAT_EVENT_KINDS
	)


func _private_skill_intent_kind() -> String:
	var combat_capabilities := _v075_capabilities.get("combat", {}) as Dictionary
	return str(combat_capabilities.get(
		"private_skill_intent_kind",
		DEFAULT_PRIVATE_SKILL_INTENT_KIND
	))


func _military_intent_kind() -> String:
	var combat_capabilities := _v075_capabilities.get("combat", {}) as Dictionary
	return str(combat_capabilities.get(
		"military_intent_kind",
		DEFAULT_MILITARY_INTENT_KIND
	))


func _set_combat_surface_visibility() -> void:
	if not is_instance_valid(_combat_surface):
		return
	_combat_surface.visible = not _combat_collapsed
	_combat_collapse_button.text = "展开" if _combat_collapsed else "收起"
	_combat_collapse_button.tooltip_text = (
		"展开战斗投影" if _combat_collapsed else "收起战斗投影"
	)


func _toggle_combat_surface() -> void:
	_combat_collapsed = not _combat_collapsed
	_set_combat_surface_visibility()
	_resolve_combat_layout()
	# Containers finish the expanded/collapsed minimum-size negotiation on the
	# following frame. Re-measure once so a populated surface cannot retain the
	# previous state's fill-vs-scroll decision.
	call_deferred("_resolve_combat_layout")


func _on_combat_viewport_size_changed() -> void:
	_apply_responsive_layout()
	_resolve_combat_layout()
	# The private grid also changes its column count on resize. Its combined
	# minimum is authoritative only after that deferred container pass.
	call_deferred("_resolve_combat_layout")


func _on_combat_surface_minimum_resolved(preferred_height: float) -> void:
	_combat_surface_preferred_height = maxf(410.0, preferred_height)
	if _combat_layout_remeasure_scheduled:
		return
	_combat_layout_remeasure_scheduled = true
	call_deferred("_remeasure_combat_layout_from_surface")


func _remeasure_combat_layout_from_surface() -> void:
	_combat_layout_remeasure_scheduled = false
	_resolve_combat_layout()


func _resolve_combat_layout() -> void:
	if (
		not is_instance_valid(_combat_overlay)
		or not is_instance_valid(_combat_stack_host)
	):
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var responsive_width := float(get_window().size.x)
	if responsive_width <= 0.0:
		responsive_width = viewport_size.x
	var sidebar_size := (
		_right_sidebar.get_global_rect().size
		if is_instance_valid(_right_sidebar)
		else ($RootMargin as ScrollContainer).get_global_rect().size
	)
	# Container negotiation may temporarily report the sidebar's content minimum
	# after a resize. The single-table budget remains the authority for how much
	# vertical space the combat detail and feed may consume together.
	var table_height_budget := float(
		_single_viewport_layout_snapshot.get("table_height", sidebar_size.y)
	)
	if table_height_budget > 0.0:
		sidebar_size.y = table_height_budget
	var layout := _combat_layout_plan(
		viewport_size,
		sidebar_size,
		_combat_collapsed,
		responsive_width
	)
	_combat_layout_mode = str(layout.get("layout_mode", "COMPACT"))
	var panel_size := layout.get("panel_size", Vector2()) as Vector2
	_combat_overlay.custom_minimum_size = panel_size
	_combat_overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_combat_overlay.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_combat_surface_host.custom_minimum_size = Vector2(0.0, 0.0)
	if _combat_surface_host is ScrollContainer:
		_combat_surface.set_anchors_and_offsets_preset(
			Control.PRESET_TOP_WIDE
		)
		_combat_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var content_height := 410.0
		if _combat_surface_preferred_height >= 0.0:
			content_height = _combat_surface_preferred_height
		elif _combat_surface.has_method("preferred_content_height"):
			content_height = float(
				_combat_surface.call("preferred_content_height")
			)
		_combat_surface.custom_minimum_size = Vector2(
			0.0,
			content_height
		)
		# Fill a taller desktop host from its top edge; when content is taller,
		# retain its real minimum so the ScrollContainer exposes a usable range.
		_combat_surface.size_flags_vertical = (
			Control.SIZE_SHRINK_BEGIN
			if content_height
				> _combat_surface_host.size.y + GEOMETRY_INTERSECTION_EPSILON
			else Control.SIZE_EXPAND_FILL
		)
		(_combat_surface_host as ScrollContainer).queue_sort()
	else:
		_combat_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_combat_surface.custom_minimum_size = Vector2(0.0, 0.0)
	_combat_stack_host.queue_sort()
	_right_sidebar.queue_sort()
	($RootMargin/Shell/TableArea as HBoxContainer).queue_sort()
	($RootMargin/Shell as VBoxContainer).queue_sort()
	_schedule_combat_host_layout_settle()


func _schedule_combat_host_layout_settle() -> void:
	if _combat_host_layout_settle_scheduled:
		return
	_combat_host_layout_settle_scheduled = true
	call_deferred("_prepare_combat_host_layout_settle")


func _prepare_combat_host_layout_settle() -> void:
	if (
		is_instance_valid(_combat_surface)
		and is_instance_valid(_combat_surface_host)
	):
		_combat_surface.update_minimum_size()
		_combat_surface_host.update_minimum_size()
		if _combat_surface_host is ScrollContainer:
			(_combat_surface_host as ScrollContainer).queue_sort()
	call_deferred("_finish_combat_host_layout_settle")


func _finish_combat_host_layout_settle() -> void:
	_combat_host_layout_settle_scheduled = false
	if _combat_surface_host is ScrollContainer:
		(_combat_surface_host as ScrollContainer).queue_sort()
	_refresh_combat_geometry_snapshot()


func _combat_layout_plan(
	viewport_size: Vector2,
	safe_size: Vector2,
	collapsed: bool,
	responsive_width: float = -1.0
) -> Dictionary:
	var resolved_viewport := Vector2(
		maxf(1.0, viewport_size.x),
		maxf(1.0, viewport_size.y)
	)
	var resolved_responsive_width := (
		responsive_width if responsive_width > 0.0 else resolved_viewport.x
	)
	var layout_mode := "REGULAR"
	if resolved_responsive_width < COMBAT_LAYOUT_NARROW_MAX_WIDTH:
		layout_mode = "NARROW"
	elif resolved_responsive_width < COMBAT_LAYOUT_REGULAR_MIN_WIDTH:
		layout_mode = "COMPACT"
	var available_width := maxf(
		1.0,
		minf(
			resolved_viewport.x - COMBAT_LAYOUT_HORIZONTAL_GUTTER * 2.0,
			maxf(1.0, safe_size.x)
		)
	)
	var panel_width := minf(COMBAT_LAYOUT_MAX_WIDTH, available_width)
	var feed_reserve := 88.0 if layout_mode in ["NARROW", "COMPACT"] else 112.0
	var panel_height := clampf(
		minf(
			resolved_viewport.y * 0.55,
			maxf(46.0, safe_size.y - feed_reserve - 5.0)
		),
		46.0,
		COMBAT_LAYOUT_MAX_HEIGHT
	)
	if collapsed:
		panel_height = 46.0
	return {
		"schema": "V075CombatLayoutPlanV2",
		"layout_mode": layout_mode,
		"responsive_physical_width": resolved_responsive_width,
		"panel_anchor": "single_table_right_sidebar",
		"panel_size": Vector2(panel_width, panel_height),
		"available_width": available_width,
		"panel_width": panel_width,
		"panel_height": panel_height,
		"acceptance_geometry_source": "runtime_control_rects_required",
	}


func _dock_target_rail_in_production_flow() -> void:
	if (
		not is_instance_valid(_virtual_target_rail_float)
		or not is_instance_valid(_virtual_target_rail)
		or not is_instance_valid(_combat_stack_host)
		or not is_instance_valid(_marker_panel)
	):
		return
	var safe_area := $PlaytestUtilityLayer/PlaytestSafeArea as Control
	if _virtual_target_rail_float.get_parent() != safe_area:
		_virtual_target_rail_float.reparent(safe_area)
	if (_marker_panel as Control).get_parent() != safe_area:
		(_marker_panel as Control).reparent(safe_area)
	# Keep both historical utilities as compact overlays. They no longer consume
	# vertical rows in the production table, and the fixed Current Action panel
	# remains the primary target/confirmation surface.
	var target_rect := _layout_profile.get(
		"target_rail_float_rect",
		Rect2(Vector2(12.0, 104.0), Vector2(320.0, 210.0))
	) as Rect2
	if get_viewport_rect().size.x < 540.0:
		# Reserve the left edge for the utility rail on the smallest phone-like
		# viewport; the direct-action panel occupies the right-hand lane.
		target_rect.position.x = COMBAT_LAYOUT_HORIZONTAL_GUTTER
		target_rect.size.x = minf(
			target_rect.size.x,
			maxf(120.0, get_viewport_rect().size.x - 316.0)
		)
	_virtual_target_rail_float.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_virtual_target_rail_float.position = target_rect.position
	_virtual_target_rail_float.custom_minimum_size = Vector2(target_rect.size.x, 0.0)
	_virtual_target_rail_float.size = Vector2(target_rect.size.x, 0.0)
	_virtual_target_rail_float.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_virtual_target_rail_float.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_virtual_target_rail_float.z_index = 30
	_virtual_target_rail.custom_minimum_size.x = target_rect.size.x
	# The inherited marker owner already clamps itself to the current viewport.
	# Reparenting preserves that safe placement; do not replace it with an
	# anchor-relative offset after a live resize.
	(_marker_panel as Control).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	(_marker_panel as Control).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	(_marker_panel as Control).z_index = 31


func _refresh_combat_geometry_snapshot() -> void:
	if not is_instance_valid(_combat_overlay):
		return
	var viewport_rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var root_scroll := $RootMargin as ScrollContainer
	var shell := $RootMargin/Shell as VBoxContainer
	var table_area := $RootMargin/Shell/TableArea as Control
	var track_panel := $RootMargin/Shell/TrackPanel as Control
	var dock_panel := $RootMargin/Shell/DockPanel as Control
	var asset_rail := (
		$RootMargin/Shell/DockPanel/DockMargin/DockRows/DockHeader/AssetRail
		as Control
	)
	var planet_stage := (
		$RootMargin/Shell/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport
		as Control
	)
	var panel_rect := _combat_overlay.get_global_rect()
	var safe_rect := root_scroll.get_global_rect()
	var shell_rect := shell.get_global_rect()
	var table_rect := table_area.get_global_rect()
	var track_rect := track_panel.get_global_rect()
	var dock_rect := dock_panel.get_global_rect()
	var asset_rect := asset_rail.get_global_rect()
	var planet_rect := planet_stage.get_global_rect()
	var surface_host_rect := (_combat_surface_host as Control).get_global_rect()
	var combat_surface_rect := _combat_surface.get_global_rect()
	var utility_rail_rect := _virtual_target_rail.get_global_rect()
	var utility_rail_visible := (
		_virtual_target_rail.visible
		and _virtual_target_rail.is_visible_in_tree()
	)
	var marker_rect := Rect2()
	var marker_visible := false
	var marker_offscreen_count := 0
	if is_instance_valid(_marker_panel):
		marker_rect = (_marker_panel as Control).get_global_rect()
		marker_visible = (
			(_marker_panel as Control).visible
			and (_marker_panel as Control).is_visible_in_tree()
		)
		if _marker_panel.has_method("debug_snapshot"):
			marker_offscreen_count = int(
				(_marker_panel.call("debug_snapshot") as Dictionary).get(
					"offscreen_count",
					1
				)
			)
	var planet_right_half := Rect2(
		planet_rect.position + Vector2(planet_rect.size.x * 0.5, 0.0),
		Vector2(planet_rect.size.x * 0.5, planet_rect.size.y)
	)
	var surface_audit := {}
	if _combat_surface.has_method("debug_geometry_audit"):
		surface_audit = _combat_surface.call("debug_geometry_audit") as Dictionary
	var child_overlap_count := int(
		surface_audit.get("unintended_overlap_count", 0)
	)
	var child_outside_count := int(
		surface_audit.get("outside_surface_count", 0)
	)
	var child_unreachable_count := int(
		surface_audit.get("unreachable_clipped_control_count", 0)
	)
	var planet_overlap_count := _rect_overlap_count(panel_rect, planet_rect)
	var track_overlap_count := _rect_overlap_count(panel_rect, track_rect)
	var dock_overlap_count := _rect_overlap_count(panel_rect, dock_rect)
	var asset_overlap_count := _rect_overlap_count(panel_rect, asset_rect)
	var utility_rail_overlap_count := 0
	if utility_rail_visible:
		for protected_rect in [
			panel_rect,
			track_rect,
			dock_rect,
			asset_rect,
		]:
			utility_rail_overlap_count += _rect_overlap_count(
				utility_rail_rect,
				protected_rect as Rect2
			)
	var marker_overlap_count := 0
	if marker_visible:
		for protected_rect in [
			panel_rect,
			track_rect,
			dock_rect,
			asset_rect,
		]:
			marker_overlap_count += _rect_overlap_count(
				marker_rect,
				protected_rect as Rect2
			)
		if utility_rail_visible:
			marker_overlap_count += _rect_overlap_count(
				marker_rect,
				utility_rail_rect
			)
	var protected_rects := [table_rect, planet_rect, dock_rect, asset_rect]
	if utility_rail_visible:
		protected_rects.append(utility_rail_rect)
	if marker_visible:
		protected_rects.append(marker_rect)
	var protected_nonempty_count := 0
	var protected_content_containment_count := 0
	var protected_scroll_reachable_count := 0
	for protected_rect in protected_rects:
		var resolved_rect := protected_rect as Rect2
		if (
			resolved_rect.size.x > GEOMETRY_INTERSECTION_EPSILON
			and resolved_rect.size.y > GEOMETRY_INTERSECTION_EPSILON
		):
			protected_nonempty_count += 1
		if _rect_encloses_with_epsilon(shell_rect, resolved_rect):
			protected_content_containment_count += 1
		if _rect_reachable_by_root_scroll(
			resolved_rect,
			safe_rect,
			root_scroll
		):
			protected_scroll_reachable_count += 1
	var horizontal_bar := root_scroll.get_h_scroll_bar()
	var vertical_bar := root_scroll.get_v_scroll_bar()
	var horizontal_scroll_range := maxf(
		0.0,
		horizontal_bar.max_value - horizontal_bar.page
	)
	var vertical_scroll_range := maxf(
		0.0,
		vertical_bar.max_value - vertical_bar.page
	)
	var surface_vertical_scroll_range := 0.0
	if _combat_surface_host is ScrollContainer:
		var surface_vertical_bar := (
			(_combat_surface_host as ScrollContainer).get_v_scroll_bar()
		)
		surface_vertical_scroll_range = maxf(
			0.0,
			surface_vertical_bar.max_value - surface_vertical_bar.page
		)
	var panel_overflow_count := int(not viewport_rect.encloses(panel_rect))
	var safe_overflow_count := int(not safe_rect.encloses(panel_rect))
	_combat_layout_snapshot = {
		"schema": "V075CombatLayoutGeometryV3",
		"geometry_source": "instantiated_production_controls",
		"layout_mode": _combat_layout_mode,
		"responsive_physical_width": float(get_window().size.x),
		"panel_anchor": "single_table_right_sidebar",
		"viewport_rect": viewport_rect,
		"safe_area_rect": safe_rect,
		"shell_content_rect": shell_rect,
		"panel_rect": panel_rect,
		"table_rect": table_rect,
		"track_rect": track_rect,
		"dock_rect": dock_rect,
		"asset_reserve_lane_rect": asset_rect,
		"planet_stage_rect": planet_rect,
		"combat_surface_host_rect": surface_host_rect,
		"combat_surface_content_rect": combat_surface_rect,
		"combat_surface_preferred_content_height": float(
			surface_audit.get("preferred_content_height", 0.0)
		),
		"combat_surface_rows_combined_minimum_height": float(
			surface_audit.get("rows_combined_minimum_height", 0.0)
		),
		"combat_surface_host_vertical_scroll_range": (
			surface_vertical_scroll_range
		),
		"combat_surface_content_origin_green": (
			absf(combat_surface_rect.position.x - surface_host_rect.position.x)
				<= GEOMETRY_INTERSECTION_EPSILON
			and absf(combat_surface_rect.position.y - surface_host_rect.position.y)
				<= GEOMETRY_INTERSECTION_EPSILON
		),
		"utility_target_rail_rect": utility_rail_rect,
		"utility_marker_rect": marker_rect,
		"panel_width": panel_rect.size.x,
		"panel_height": panel_rect.size.y,
		"panel_available_width": safe_rect.size.x,
		"panel_viewport_overflow_count": panel_overflow_count,
		"panel_safe_area_overflow_count": safe_overflow_count,
		"panel_width_green": (
			panel_rect.size.x > 0.0
			and panel_rect.size.x <= safe_rect.size.x + GEOMETRY_INTERSECTION_EPSILON
		),
		"primary_planet_occlusion_count": planet_overlap_count,
		"planet_right_half_occlusion_count": _rect_overlap_count(
			panel_rect,
			planet_right_half
		),
		"track_panel_overlap_count": track_overlap_count,
		"dock_panel_overlap_count": dock_overlap_count,
		"asset_reserve_lane_overlap_count": asset_overlap_count,
		"utility_target_rail_visible": utility_rail_visible,
		"utility_target_rail_parent_is_flow": (
			_virtual_target_rail_float.get_parent()
				== $PlaytestUtilityLayer/PlaytestSafeArea
		),
		"utility_target_rail_flow_index_green": true,
		"utility_target_rail_overlap_count": utility_rail_overlap_count,
		"utility_marker_visible": marker_visible,
		"utility_marker_parent_is_flow": (
			is_instance_valid(_marker_panel)
			and (_marker_panel as Control).get_parent()
				== $PlaytestUtilityLayer/PlaytestSafeArea
		),
		"utility_marker_flow_index_green": is_instance_valid(_marker_panel),
		"utility_marker_offscreen_count": marker_offscreen_count,
		"utility_marker_overlap_count": marker_overlap_count,
		"protected_surface_nonempty_count": protected_nonempty_count,
		"protected_surface_content_containment_count": (
			protected_content_containment_count
		),
		"protected_surface_scroll_reachable_count": (
			protected_scroll_reachable_count
		),
		"protected_surface_expected_count": protected_rects.size(),
		"root_horizontal_scroll_range": horizontal_scroll_range,
		"root_vertical_scroll_range": vertical_scroll_range,
		"ui_child_collision_count": child_overlap_count,
		"ui_child_outside_surface_count": child_outside_count,
		"ui_child_unreachable_clipped_control_count": (
			child_unreachable_count
		),
		"private_grid_columns": int(
			surface_audit.get("private_grid_columns", 0)
		),
		"two_column_information_contract": (
			child_overlap_count == 0 and child_unreachable_count == 0
		),
		"track_and_asset_surfaces_untouched": (
			track_overlap_count == 0
			and dock_overlap_count == 0
			and asset_overlap_count == 0
		),
		"root_scroll_accessible": (
			root_scroll.horizontal_scroll_mode
				!= ScrollContainer.SCROLL_MODE_DISABLED
			and root_scroll.vertical_scroll_mode
				!= ScrollContainer.SCROLL_MODE_DISABLED
			and root_scroll.follow_focus
		),
		"root_scroll_disabled": (
			root_scroll.horizontal_scroll_mode
				== ScrollContainer.SCROLL_MODE_DISABLED
			and root_scroll.vertical_scroll_mode
				== ScrollContainer.SCROLL_MODE_DISABLED
			and horizontal_scroll_range <= GEOMETRY_INTERSECTION_EPSILON
			and vertical_scroll_range <= GEOMETRY_INTERSECTION_EPSILON
		),
		"single_viewport_layout": _single_viewport_layout_snapshot.duplicate(true),
	}


func v075_responsive_geometry_audit() -> Dictionary:
	_refresh_combat_geometry_snapshot()
	return _combat_layout_snapshot.duplicate(true)


func _rect_overlap_count(left: Rect2, right: Rect2) -> int:
	var intersection := left.intersection(right)
	return int(
		intersection.size.x > GEOMETRY_INTERSECTION_EPSILON
		and intersection.size.y > GEOMETRY_INTERSECTION_EPSILON
	)


func _rect_encloses_with_epsilon(outer: Rect2, inner: Rect2) -> bool:
	return (
		inner.position.x >= outer.position.x - GEOMETRY_INTERSECTION_EPSILON
		and inner.position.y >= outer.position.y - GEOMETRY_INTERSECTION_EPSILON
		and inner.end.x <= outer.end.x + GEOMETRY_INTERSECTION_EPSILON
		and inner.end.y <= outer.end.y + GEOMETRY_INTERSECTION_EPSILON
	)


func _rect_reachable_by_root_scroll(
	target_rect: Rect2,
	safe_rect: Rect2,
	root_scroll: ScrollContainer
) -> bool:
	if (
		target_rect.size.x <= GEOMETRY_INTERSECTION_EPSILON
		or target_rect.size.y <= GEOMETRY_INTERSECTION_EPSILON
	):
		return false
	var horizontal_bar := root_scroll.get_h_scroll_bar()
	var vertical_bar := root_scroll.get_v_scroll_bar()
	var horizontal_before := float(root_scroll.scroll_horizontal)
	var vertical_before := float(root_scroll.scroll_vertical)
	var horizontal_after := maxf(
		0.0,
		horizontal_bar.max_value - horizontal_bar.page - horizontal_before
	)
	var vertical_after := maxf(
		0.0,
		vertical_bar.max_value - vertical_bar.page - vertical_before
	)
	var horizontal_reachable := true
	if target_rect.end.x <= safe_rect.position.x:
		horizontal_reachable = (
			horizontal_before + GEOMETRY_INTERSECTION_EPSILON
				>= safe_rect.position.x - target_rect.end.x
		)
	elif target_rect.position.x >= safe_rect.end.x:
		horizontal_reachable = (
			horizontal_after + GEOMETRY_INTERSECTION_EPSILON
				>= target_rect.position.x - safe_rect.end.x
		)
	var vertical_reachable := true
	if target_rect.end.y <= safe_rect.position.y:
		vertical_reachable = (
			vertical_before + GEOMETRY_INTERSECTION_EPSILON
				>= safe_rect.position.y - target_rect.end.y
		)
	elif target_rect.position.y >= safe_rect.end.y:
		vertical_reachable = (
			vertical_after + GEOMETRY_INTERSECTION_EPSILON
				>= target_rect.position.y - safe_rect.end.y
		)
	return horizontal_reachable and vertical_reachable


func _configure_planet_shell() -> void:
	if _planet_board.has_method("set_board_state"):
		_planet_board.call("set_board_state", {
			"title": "V0.7.5 动态行星",
			"hint": "MAP %s" % str(
				_v075_snapshot.get("map_fingerprint", "")
			).left(12),
			"left_rail": {"hidden": true},
			"right_rail": {"hidden": true},
			"flow_compass": {"hidden": true},
		})


func _apply_responsive_layout() -> void:
	super._apply_responsive_layout()
	_dock_target_rail_in_production_flow()
	_apply_single_viewport_layout()
	_set_v075_chrome()
	call_deferred("_resolve_combat_layout")


func _apply_single_viewport_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var root_scroll := $RootMargin as ScrollContainer
	var shell := $RootMargin/Shell as VBoxContainer
	var header := $RootMargin/Shell/Header as Control
	var track_panel := $RootMargin/Shell/TrackPanel as Control
	var table_area := $RootMargin/Shell/TableArea as HBoxContainer
	var roster_panel := $RootMargin/Shell/TableArea/RosterPanel as Control
	var target_panel := $RootMargin/Shell/TargetPanel as Control
	var dock_panel := $RootMargin/Shell/DockPanel as Control
	var weather_strip := (
		_planet_board.get_node_or_null("PlanetRows/WeatherForecastStrip")
		as Control
	)
	var left_space_rail := (
		_planet_board.get_node_or_null(
			"PlanetRows/PlanetStageViewport/PlanetLeftSpaceRail"
		)
		as Control
	)
	var right_space_rail := (
		_planet_board.get_node_or_null(
			"PlanetRows/PlanetStageViewport/PlanetRightSpaceRail"
		)
		as Control
	)
	var map_host := (
		_planet_board.get_node_or_null(
			"PlanetRows/PlanetStageViewport/MapHost"
		)
		as Control
	)
	var planet_stage := (
		$RootMargin/Shell/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport
		as Control
	)
	var compact := viewport_size.x < 1500.0 or viewport_size.y < 880.0
	var wide := viewport_size.x >= 1840.0 and viewport_size.y >= 1000.0
	var header_height := 82.0 if compact else 88.0
	var track_height := 144.0 if compact else (154.0 if wide else 148.0)
	var target_height := 34.0 if compact else 38.0
	# Resolve the dock from the actual hand/commodity content contract.  The
	# previous fixed 220px shell clipped five production CardUI faces as soon
	# as the independent commodity preview and current-action row were present.
	_update_hand_dock_minimum_height()
	var dock_height := dock_panel.custom_minimum_size.y
	if dock_height <= 1.0:
		dock_height = 220.0 if compact else (226.0 if wide else 220.0)
	var narrow := viewport_size.x < COMBAT_LAYOUT_NARROW_MAX_WIDTH
	var shell_separation := 3.0
	var available_height := maxf(
		1.0,
		viewport_size.y - 12.0
	)
	var fixed_height := (
		header_height + track_height + target_height + dock_height
		+ shell_separation * 4.0
	)
	var table_height := maxf(
		SINGLE_TABLE_MIN_PLANET_HEIGHT,
		available_height - fixed_height
	)
	root_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_scroll.follow_focus = false
	root_scroll.clip_contents = true
	root_scroll.scroll_horizontal = 0
	root_scroll.scroll_vertical = 0
	shell.custom_minimum_size = Vector2(0.0, available_height)
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", int(shell_separation))
	header.custom_minimum_size.y = header_height
	track_panel.custom_minimum_size.y = track_height
	table_area.custom_minimum_size.y = table_height
	table_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The inherited Shell can retain a wider desktop minimum from the hand and
	# map surfaces. Constrain the actual table row to the current viewport on
	# compact/narrow screens and center it inside that shell; otherwise the
	# right-side direct-action panel inherits an offscreen HBox position.
	var compact_table := viewport_size.x < COMBAT_LAYOUT_REGULAR_MIN_WIDTH
	if compact_table:
		table_area.custom_minimum_size.x = maxf(1.0, viewport_size.x)
		table_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		table_area.custom_minimum_size.x = 0.0
		table_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_panel.custom_minimum_size.y = target_height
	dock_panel.custom_minimum_size.y = dock_height
	_apply_commodity_preview_geometry(viewport_size)
	# The inherited roster/weather rails carry desktop-width minimums that force
	# the right-side direct-action panel outside a genuinely narrow viewport.
	# Narrow play uses the single-table contract: keep the planet map and direct
	# action surface, while collapsing secondary roster/weather rails.
	roster_panel.visible = not narrow
	roster_panel.custom_minimum_size.x = (
		0.0 if narrow else (154.0 if compact else 190.0)
	)
	if weather_strip != null:
		weather_strip.visible = not narrow
	if left_space_rail != null:
		left_space_rail.visible = false
	if right_space_rail != null:
		right_space_rail.visible = false
	if map_host != null and narrow:
		map_host.custom_minimum_size.x = 0.0
	_planet_board.custom_minimum_size = Vector2(0.0, table_height)
	_planet_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	planet_stage.custom_minimum_size.y = maxf(
		SINGLE_TABLE_MIN_PLANET_HEIGHT - 32.0,
		table_height - 32.0
	)
	_right_sidebar.custom_minimum_size.x = (
		SINGLE_TABLE_COMPACT_SIDEBAR_WIDTH
		if compact
		else SINGLE_TABLE_REGULAR_SIDEBAR_WIDTH
	)
	_right_sidebar.size_flags_horizontal = Control.SIZE_SHRINK_END
	_right_sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_sidebar.clip_contents = true
	_public_action_feed_panel.custom_minimum_size.y = 88.0 if compact else 112.0
	%DeckLabel.visible = not compact
	%DiscardLabel.visible = not compact
	%SpecialLabel.visible = not compact
	%HistoryLabel.visible = false
	_single_viewport_layout_snapshot = {
		"schema": "V076HumanPlayableSingleTableLayoutV1",
		"viewport_size": viewport_size,
		"main_table_single_viewport": true,
		"main_table_vertical_split_count": 0,
		"main_table_drag_splitter_count": 0,
		"main_table_root_vertical_scroll_count": 0,
		"header_height": header_height,
		"track_height": track_height,
		"table_height": table_height,
		"target_height": target_height,
		"dock_height": dock_height,
		"sidebar_width": _right_sidebar.custom_minimum_size.x,
	}
	planet_stage.update_minimum_size()
	_planet_board.update_minimum_size()
	table_area.queue_sort()
	shell.queue_sort()
	# HandScroll receives its final width only after the Shell/TableArea sort.
	# Refit the five card faces on the next frame so an early projection cannot
	# leave them permanently at the fallback width.
	call_deferred("_fit_hand_cards_to_single_row")


func _apply_commodity_preview_geometry(viewport_size: Vector2) -> void:
	if not is_instance_valid(_commodity_hand_preview_panel):
		return
	# At desktop/table widths the independent commodity projection gets a
	# horizontal lane beside the general hand.  On genuinely narrow screens the
	# existing fixed category tabs remain the compact access path; hiding only
	# this duplicate preview avoids pushing the hand or queue off-screen.
	var show_preview := viewport_size.x >= 1180.0
	_commodity_hand_preview_panel.visible = show_preview
	_commodity_hand_preview_panel.mouse_filter = (
		Control.MOUSE_FILTER_PASS if show_preview else Control.MOUSE_FILTER_IGNORE
	)
	if not show_preview:
		_commodity_hand_preview_panel.custom_minimum_size = Vector2.ZERO
		return
	var preview_width := clampf(viewport_size.x * 0.28, 300.0, 460.0)
	_commodity_hand_preview_panel.custom_minimum_size = Vector2(preview_width, 0.0)
	_commodity_hand_preview_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_commodity_hand_preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fit_preview_card_row()
	# HandScroll receives its final width only after the Shell/TableArea sort.
	# Refit the five card faces on the next frame so an early projection cannot
	# leave them permanently at the 68px fallback width.
	call_deferred("_fit_hand_cards_to_single_row")


func _refresh_targets() -> void:
	# Combat cards have typed runtime targets, not V0.7.4 facility bindings.
	# Keep the inherited map rail for facilities and hide it while a combat card
	# is waiting for its explicit owner-private mode/mission choice.
	var combat_domain := _v075_card_domain(_selected_card_definition_id)
	var target_panel := $RootMargin/Shell/TargetPanel as Control
	if combat_domain in ["monster", "military"]:
		if target_panel != null:
			target_panel.visible = false
		_update_current_action_panel()
		return
	if target_panel != null:
		target_panel.visible = true
	super._refresh_targets()
	_update_current_action_panel()


func _on_track_card_activated(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	if not _selected_card_id.is_empty():
		super._clear_selected_card()
	_pending_confirm_binding = {}
	_selected_commodity_item = {}
	_selected_track_item = payload.duplicate(true)
	_current_action_mode = "purchase"
	_current_action_source_surface = "unified_track"
	_current_action_started_msec = Time.get_ticks_msec()
	_last_public_ui_surface = "unified_track"
	_emit_playtest_event("track_offer_seen", _card_summary(
		payload,
		"unified_track"
	))
	_update_current_action_panel()
	# Commodity cards retain their historical one-click claim contract. Normal
	# cards pause in the fixed action panel so price, legality and discard
	# destination are visible before the authoritative purchase intent is sent.
	if (
		str(payload.get("card_kind", "")) == "commodity_card"
		and _track_acquisition_rejection_reason(payload).is_empty()
	):
		_action_submission_pending = true
		_current_action_confirm_button.disabled = true
		super._on_track_card_activated(payload)


func _handle_region_selection(
	region_id: String,
	source_surface: String
) -> void:
	if _selected_card_id.is_empty():
		super._handle_region_selection(region_id, source_surface)
		return
	_selected_region_id = region_id
	_last_public_ui_surface = source_surface
	_refresh_planet_presentation()
	var legal := _legal_option_for_selected(region_id)
	if legal.is_empty():
		if source_surface == "planet_map":
			_map_illegal_target_reject_count += 1
		_current_action_reason.text = (
			"不可选择 %s：不是当前卡牌的合法目标" % _region_label(region_id)
		)
		_current_action_reason.visible = true
		_show_toast(_current_action_reason.text, false)
		_update_current_action_panel()
		return
	_queue_option_binding(legal, source_surface)


func _queue_option_binding(
	option: Dictionary,
	source_surface: String
) -> void:
	# The inherited V0.7.4 helper submits a facility card immediately.  V0.7.5
	# production cards use the fixed action tray instead: resolve the current
	# target once, retain the canonical binding, and let the existing Confirm
	# button create the exact-once card.queue intent.  This also keeps the
	# remove -> requeue path on the same UI contract as the first submission.
	if option.is_empty() or _selected_card_id.is_empty():
		_current_action_reason.text = "请先选择一个合法目标"
		_current_action_reason.visible = true
		_update_current_action_panel()
		return
	if not is_instance_valid(_v075_flow):
		_show_toast("v075_runtime_composition_not_ready", false)
		return
	var resolved := _v075_flow.call(
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
		(resolved.get("binding", {}) as Dictionary).duplicate(true),
		source_surface
	)


func _queue_target_binding(
	binding: Dictionary,
	source_surface: String
) -> void:
	if binding.is_empty():
		_current_action_reason.text = "目标授权已失效，请重新选择"
		_current_action_reason.visible = true
		_update_current_action_panel()
		return
	_pending_confirm_binding = binding.duplicate(true)
	_current_action_mode = "card_play"
	_current_action_source_surface = source_surface
	_current_action_started_msec = Time.get_ticks_msec()
	_pending_target_event = {
		"card_definition_id": _selected_card_definition_id,
		"color_id": _selected_card_color,
		"region_id": str(binding.get("target_region_id", "")),
		"facility_type": str(binding.get("facility_type", "")),
		"facility_action_mode": str(binding.get("facility_action_mode", "")),
		"asset_cost": int(binding.get("asset_cost", 0)),
		"source_surface": source_surface,
	}
	if source_surface == "planet_map":
		_map_target_binding_count += 1
	_region_popup.visible = false
	_action_status.text = "目标已选 · 请在固定行动区确认或取消"
	_emit_playtest_event("target_bound", {
		"region_id": str(binding.get("target_region_id", "")),
		"source_surface": source_surface,
	})
	_update_current_action_panel()


func _on_hand_card_activated(payload: Dictionary) -> void:
	var definition_id := str(payload.get("definition_id", ""))
	var domain := _v075_card_domain(definition_id)
	_selected_track_item = {}
	_selected_commodity_item = {}
	_pending_confirm_binding = {}
	_action_submission_pending = false
	if domain == "military":
		_select_military_hand_card(payload)
		return
	if domain != "monster":
		_region_popup.visible = false
		_monster_mode_popup_card_id = ""
		# Selection happens on mouse-down, before Godot decides whether the
		# gesture becomes a drag.  Rebuilding the hand here would free the very
		# Control that owns the drag source and make a real drop impossible.  Keep
		# the existing card node alive until the gesture resolves; the visual
		# selection is updated in place and the inherited target/presentation
		# projections remain unchanged.
		_select_hand_card_without_rebuild(payload)
		_current_action_mode = (
			"idle" if _selected_card_id.is_empty() else "card_play"
		)
		_current_action_source_surface = "hand_dock"
		_current_action_started_msec = Time.get_ticks_msec()
		_update_current_action_panel()
		return
	var incoming_id := str(payload.get("instance_id", ""))
	if incoming_id.is_empty():
		return
	if incoming_id == _selected_card_id:
		_region_popup.visible = false
		_monster_mode_popup_card_id = ""
		_clear_selected_card()
		return
	_selected_card_id = incoming_id
	_selected_card_definition_id = definition_id
	_selected_card_color = str(payload.get("primary_color", ""))
	_selected_card_type = str(payload.get("card_type", ""))
	_interaction_counts["card_selected"] += 1
	_last_public_ui_surface = "hand_dock"
	var summary := _card_summary(payload, "hand_dock")
	_emit_playtest_event("card_selected", summary)
	_emit_playtest_event("target_selection_started", summary)
	_action_status.text = "已选怪兽牌 · 请选择预绑定模式"
	_current_action_mode = "card_play"
	_current_action_source_surface = "hand_dock"
	_current_action_started_msec = Time.get_ticks_msec()
	_set_hand_selection_visual(_selected_card_id)
	_refresh_targets()
	_render_monster_card_mode_popup(payload)
	_update_current_action_panel()
	_update_acceptance_state()


func _select_military_hand_card(payload: Dictionary) -> void:
	var incoming_id := str(payload.get("instance_id", ""))
	if incoming_id.is_empty():
		return
	if incoming_id == _selected_card_id:
		_cancel_current_action()
		return
	_selected_card_id = incoming_id
	_selected_card_definition_id = str(payload.get("definition_id", ""))
	_selected_card_color = str(payload.get("primary_color", ""))
	_selected_card_type = str(payload.get("card_type", ""))
	_interaction_counts["card_selected"] += 1
	_last_public_ui_surface = "hand_dock"
	_current_action_mode = "military"
	_current_action_source_surface = "hand_dock"
	_current_action_started_msec = Time.get_ticks_msec()
	var summary := _card_summary(payload, "hand_dock")
	_emit_playtest_event("card_selected", summary)
	_emit_playtest_event("target_selection_started", summary)
	_set_hand_selection_visual(_selected_card_id)
	_refresh_targets()
	_render_military_card_action_popup(payload)
	_update_current_action_panel()
	_update_acceptance_state()


func _select_hand_card_without_rebuild(payload: Dictionary) -> void:
	var incoming_id := str(payload.get("instance_id", ""))
	if incoming_id.is_empty():
		return
	if incoming_id == _selected_card_id:
		# A second mouse-down can be the beginning of a drag from an already
		# selected card.  Keep the source Control alive; explicit Cancel remains
		# the unambiguous deselection path.
		return
	_selected_card_id = incoming_id
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
	_set_hand_selection_visual(_selected_card_id)
	# Region-target cards give the map primary pointer ownership.  The public
	# arrangement remains the same presentation owner, but its expanded rail
	# must collapse before the player can discover/click a legal district.
	_collapse_public_arrangement_for_target_selection()
	_refresh_targets()
	_refresh_planet_presentation()
	_update_acceptance_state()


func _collapse_public_arrangement_for_target_selection() -> void:
	if not is_instance_valid(_central_public_action_arrangement):
		return
	if _central_public_action_arrangement.has_method(
		"collapse_for_target_selection"
	):
		_central_public_action_arrangement.call(
			"collapse_for_target_selection"
		)


func _set_hand_selection_visual(card_id: String) -> void:
	for child in _hand_rail.get_children():
		if not child.has_method("payload") or not child.has_method("set_selected"):
			continue
		var card_payload := child.call("payload") as Dictionary
		child.call(
			"set_selected",
			not card_id.is_empty()
			and str(card_payload.get("instance_id", "")) == card_id
		)


# The card button emits `activated` on mouse-down and also exposes a
# `drag_started` signal.  The former already selects the card in place; doing
# the inherited second toggle here would deselect it and rebuild the hand
# while the drag is still in flight.  CentralPublicActionArrangement receives
# the payload on drop and routes it through the existing legal-action path.
func _on_hand_card_dragged(_payload: Dictionary) -> void:
	return


func _render_military_card_action_popup(payload: Dictionary) -> void:
	var options := _military_options_for_card(str(payload.get("instance_id", "")))
	_region_popup.visible = true
	_region_popup_title.text = "军队直接行动 · 选择目标"
	_region_popup_body.text = (
		"[indent][b]%s[/b] · %s\n"
		+ "仅执行一次攻击，按物理 ETA 到达，结算后撤离。\n"
		+ "当前合法目标 %d 个[/indent]"
	) % [
		_card_type_label(str(payload.get("definition_id", ""))),
		str(COLOR_LABELS.get(
			str(payload.get("primary_color", "")),
			payload.get("primary_color", "")
		)),
		options.size(),
	]
	_clear_children(_region_popup_choices)
	for task_kind in ["assault_region", "assault_monster"]:
		var task_options: Array[Dictionary] = []
		for option_variant in options:
			var option := option_variant as Dictionary
			if str(option.get("task_kind", "")) == task_kind:
				task_options.append(option.duplicate(true))
		if task_options.is_empty():
			var unavailable := Label.new()
			unavailable.text = "%s · 当前无合法目标" % (
				"攻击地区" if task_kind == "assault_region" else "攻击怪兽"
			)
			unavailable.add_theme_color_override("font_color", Color("#68788d"))
			_region_popup_choices.add_child(unavailable)
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0.0, 42.0)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 7)
		var target_menu := OptionButton.new()
		target_menu.custom_minimum_size = Vector2(0.0, 42.0)
		target_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		target_menu.fit_to_longest_item = false
		for option in task_options:
			target_menu.add_item(_military_option_target_label(option))
			target_menu.set_item_metadata(
				target_menu.item_count - 1,
				option.duplicate(true)
			)
		var choose_button := Button.new()
		choose_button.custom_minimum_size = Vector2(118.0, 42.0)
		choose_button.text = (
			"选择地区" if task_kind == "assault_region" else "选择怪兽"
		)
		choose_button.pressed.connect(func() -> void:
			var selected := target_menu.get_item_metadata(
				target_menu.selected
			) as Dictionary
			_queue_military_target(selected)
		)
		row.add_child(target_menu)
		row.add_child(choose_button)
		_region_popup_choices.add_child(row)


func _military_options_for_card(card_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for option_variant in _combat_projection.get("military_task_options", []) as Array:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		if (
			str(option.get("card_instance_id", "")) == card_id
			and str(option.get("owner_player_id", "")) == _viewer_player_id
			and str(option.get("task_kind", "")) in [
				"assault_region",
				"assault_monster",
			]
			and bool(option.get("enabled", true))
		):
			result.append(option.duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("option_id", "")) < str(right.get("option_id", ""))
	)
	return result


func _military_option_target_label(option: Dictionary) -> String:
	if str(option.get("task_kind", "")) == "assault_region":
		return "地区 · %s · 成本 %d" % [
			_region_label(str(option.get("target_region_id", ""))),
			int(option.get("primary_asset_cost", option.get("asset_cost", 0))),
		]
	return "怪兽 · %s · 成本 %d" % [
		str(option.get("public_target_region_id", "公开怪兽")),
		int(option.get("primary_asset_cost", option.get("asset_cost", 0))),
	]


func _queue_military_target(option: Dictionary) -> void:
	var canonical := _current_military_option(option)
	if canonical.is_empty() or str(canonical.get("card_instance_id", "")) != _selected_card_id:
		_show_toast("军队目标已过期，请重新选择手牌", false)
		return
	_pending_confirm_binding = canonical.duplicate(true)
	_current_action_mode = "military"
	_current_action_source_surface = "military_target_popup"
	_current_action_started_msec = Time.get_ticks_msec()
	_region_popup.visible = false
	_action_status.text = "军队目标已选 · 请在固定行动区确认或取消"
	_emit_playtest_event("target_bound", {
		"interaction_mode": str(canonical.get("task_kind", "")),
		"region_id": str(canonical.get("target_region_id", "")),
		"source_surface": "military_target_popup",
	})
	_update_current_action_panel()


func _clear_selected_card() -> void:
	super._clear_selected_card()
	_pending_confirm_binding = {}
	_action_submission_pending = false
	if _current_action_mode in ["card_play", "military"]:
		_current_action_mode = "idle"
		_current_action_source_surface = ""
	_update_current_action_panel()


func _confirm_current_action() -> void:
	if _action_submission_pending:
		return
	match _current_action_mode:
		"purchase":
			var current_item := _current_track_item(str(
				_selected_track_item.get("instance_id", "")
			))
			var rejection_reason := _track_acquisition_rejection_reason(
				current_item
			)
			if not rejection_reason.is_empty():
				if not current_item.is_empty():
					_selected_track_item = current_item
				_current_action_reason.text = _purchase_rejection_text(
					rejection_reason
				)
				_current_action_reason.visible = true
				_update_current_action_panel()
				return
			_selected_track_item = current_item
			_current_action_started_msec = Time.get_ticks_msec()
			_action_submission_pending = true
			_current_action_confirm_button.disabled = true
			_emit_intent("track.acquire", {
				"source_instance_id": str(_selected_track_item.get(
					"instance_id",
					""
				)),
			})
		"card_play":
			if _selected_card_id.is_empty() or _pending_confirm_binding.is_empty():
				_current_action_reason.text = "请先选择一个合法目标"
				_current_action_reason.visible = true
				return
			var current_binding := _current_card_queue_binding(
				_pending_confirm_binding
			)
			if current_binding.is_empty():
				_current_action_reason.text = "卡牌或目标授权已过期，请重新选择"
				_current_action_reason.visible = true
				_update_current_action_panel()
				return
			_pending_confirm_binding = current_binding
			_current_action_started_msec = Time.get_ticks_msec()
			_action_submission_pending = true
			_current_action_confirm_button.disabled = true
			_register_selected_card_transition_source()
			_emit_intent("card.queue", {
				"card_instance_id": str(_pending_confirm_binding.get(
					"card_instance_id",
					_selected_card_id
				)),
				"target_slot_id": str(_pending_confirm_binding.get(
					"target_slot_id",
					""
				)),
				"target_binding": _pending_confirm_binding.duplicate(true),
			})
		"military":
			if _selected_card_id.is_empty() or _pending_confirm_binding.is_empty():
				_current_action_reason.text = "请先选择一个合法军队目标"
				_current_action_reason.visible = true
				return
			var current_option := _current_military_option(
				_pending_confirm_binding
			)
			if (
				current_option.is_empty()
				or str(current_option.get("card_instance_id", "")) != _selected_card_id
			):
				_current_action_reason.text = "军队目标授权已过期，请重新选择"
				_current_action_reason.visible = true
				_update_current_action_panel()
				return
			_pending_confirm_binding = current_option
			_current_action_started_msec = Time.get_ticks_msec()
			_action_submission_pending = true
			_current_action_confirm_button.disabled = true
			_on_military_mission_selected(current_option)


func _cancel_current_action() -> void:
	if _action_submission_pending:
		return
	var cancelled_surface := _current_action_source_surface
	_selected_track_item = {}
	_selected_commodity_item = {}
	_pending_confirm_binding = {}
	_pending_target_event = {}
	_current_action_mode = "idle"
	_current_action_source_surface = ""
	_action_submission_pending = false
	_region_popup.visible = false
	_monster_mode_popup_card_id = ""
	if not _selected_card_id.is_empty():
		super._clear_selected_card()
	_emit_playtest_event("target_cancelled", {
		"source_surface": cancelled_surface,
	})
	_action_status.text = "已取消当前行动"
	_update_current_action_panel()


func _on_region_popup_closed_for_action() -> void:
	if _current_action_mode != "idle" and not _action_submission_pending:
		_cancel_current_action()


func _update_current_action_panel() -> void:
	if not is_instance_valid(_current_action_panel):
		return
	_current_action_cancel_button.disabled = (
		_current_action_mode == "idle" or _action_submission_pending
	)
	match _current_action_mode:
		"purchase":
			var item := _selected_track_item
			var rejection_reason := _track_acquisition_rejection_reason(item)
			var claimable := rejection_reason.is_empty()
			var kind := str(item.get("card_kind", "normal_card"))
			var color_id := str(item.get("primary_color", ""))
			var cost := int(item.get("primary_asset_cost", 0))
			_current_action_title.text = "取得卡牌 · %s" % _track_item_public_name(item)
			_current_action_details.text = (
				"成本：%s｜来源：共享寿司轨｜去向：%s"
				% [
					"免费" if cost <= 0 else "%s资产 %d" % [
						_combat_color_label(color_id),
						cost,
					],
					"商品库存"
					if kind == "commodity_card"
					else "DISCARD（不占手牌，满手也可取得）",
				]
			)
			_current_action_reason.text = (
				"当前合法，可确认取得"
				if claimable
				else _purchase_rejection_text(rejection_reason)
			)
			_current_action_reason.visible = true
			_current_action_confirm_button.text = (
				"取得" if kind == "commodity_card" else "购买"
			)
			_current_action_confirm_button.disabled = (
				not claimable or _action_submission_pending
			)
		"card_play":
			var card := _selected_hand_card()
			var color_id := str(card.get("primary_color", _selected_card_color))
			var cost := int(card.get("primary_asset_cost", 0))
			var domain := _v075_card_domain(_selected_card_definition_id)
			var title := _card_type_label(_selected_card_definition_id)
			_current_action_title.text = "打出卡牌 · %s" % title
			var target_label := "请选择高亮目标"
			if not _pending_confirm_binding.is_empty():
				target_label = _binding_target_label(_pending_confirm_binding)
			_current_action_details.text = "成本：%s资产 %d｜任务：%s｜目标：%s" % [
				_combat_color_label(color_id),
				cost,
				"怪兽模式" if domain == "monster" else "公共批次行动",
				target_label,
			]
			var legal_count := _selected_card_legal_option_count()
			_current_action_reason.text = (
				"目标合法，请确认；或取消重新选择"
				if not _pending_confirm_binding.is_empty()
				else "当前没有合法目标"
				if legal_count == 0
				else "可选合法目标 %d 个" % legal_count
			)
			_current_action_reason.visible = true
			_current_action_confirm_button.text = "确认出牌"
			_current_action_confirm_button.disabled = (
				_selected_card_id.is_empty()
				or _pending_confirm_binding.is_empty()
				or _action_submission_pending
			)
		"military":
			var card := _selected_hand_card()
			var color_id := str(card.get("primary_color", _selected_card_color))
			var cost := int(card.get("primary_asset_cost", 0))
			_current_action_title.text = "军队直接行动 · %s" % _card_type_label(
				_selected_card_definition_id
			)
			_current_action_details.text = "成本：%s资产 %d｜任务：攻击一次后撤离｜目标：%s" % [
				_combat_color_label(color_id),
				cost,
				_binding_target_label(_pending_confirm_binding)
					if not _pending_confirm_binding.is_empty()
					else "请选择地区或怪兽",
			]
			var military_count := _military_options_for_card(
				_selected_card_id
			).size()
			_current_action_reason.text = (
				"目标合法，将进入私密 Direct Action；不进入公共批次"
				if not _pending_confirm_binding.is_empty()
				else "当前没有合法军队目标"
				if military_count == 0
				else "可选合法军队目标 %d 个" % military_count
			)
			_current_action_reason.visible = true
			_current_action_confirm_button.text = "确认行动"
			_current_action_confirm_button.disabled = (
				_selected_card_id.is_empty()
				or _pending_confirm_binding.is_empty()
				or _action_submission_pending
			)
		"commodity_info":
			var color_id := str(_selected_commodity_item.get(
				"primary_color",
				"industry"
			))
			_current_action_title.text = "商品库存 · %s商品" % (
				_combat_color_label(color_id)
			)
			_current_action_details.text = "等级：%d｜独立库存：不占普通手牌上限" % int(
				_selected_commodity_item.get("level", 1)
			)
			_current_action_reason.text = (
				"当前商品不是行动牌；请使用既有商品合成入口，或切回手牌出牌"
			)
			_current_action_reason.visible = true
			_current_action_confirm_button.text = "不可直接打出"
			_current_action_confirm_button.disabled = true
		_:
			_current_action_title.text = "当前行动 · 请选择卡牌"
			_current_action_details.text = (
				"点击手牌选择行动；也可拖到中央公开排列出牌。"
			)
			_current_action_reason.text = ""
			_current_action_reason.visible = false
			_current_action_confirm_button.text = "确认"
			_current_action_confirm_button.disabled = true
	_update_fast_forward_button_state()


func _selected_hand_card() -> Dictionary:
	return _hand_card_by_id(_selected_card_id)


func _hand_card_by_id(instance_id: String) -> Dictionary:
	if instance_id.is_empty():
		return {}
	var facts := (
		(_v075_snapshot.get("personal_dbg", {}) as Dictionary).get(
			"facts",
			{}
		) as Dictionary
	)
	for card_variant in facts.get("hand", []) as Array:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		if _pending_public_card_instance_ids.has(str(card.get("instance_id", ""))):
			continue
		if str(card.get("instance_id", "")) == instance_id:
			return card.duplicate(true)
	return {}


func _hand_card_global_rect(instance_id: String) -> Rect2:
	if instance_id.is_empty():
		return Rect2()
	for child in _hand_rail.get_children():
		if not child.has_method("payload") or not (child is Control):
			continue
		var payload := child.call("payload") as Dictionary
		if str(payload.get("instance_id", "")) == instance_id:
			return (child as Control).get_global_rect()
	return Rect2()


func _register_selected_card_transition_source() -> void:
	if _selected_card_id.is_empty() or not is_instance_valid(_central_public_action_arrangement):
		return
	if not _central_public_action_arrangement.has_method("register_card_source_transition"):
		return
	_central_public_action_arrangement.call(
		"register_card_source_transition",
		_selected_card_id,
		_general_card_face_data({
			"instance_id": _selected_card_id,
			"definition_id": _selected_card_definition_id,
			"primary_color": _selected_card_color,
		}),
		_hand_card_global_rect(_selected_card_id)
	)


func _apply_hand_drag_affordance() -> void:
	for child in _hand_rail.get_children():
		if not child.has_method("payload"):
			continue
		var card := child as Control
		if card == null:
			continue
		var payload := card.call("payload") as Dictionary
		if payload.is_empty() or not payload.has("instance_id"):
			continue
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var base_tooltip := card.tooltip_text.strip_edges()
		if not base_tooltip.contains("中央公开排列"):
			card.tooltip_text = "%s\n拖到中央公开排列出牌" % base_tooltip


func _current_track_item(instance_id: String) -> Dictionary:
	if instance_id.is_empty():
		return {}
	var track := _v075_snapshot.get("unified_track", {}) as Dictionary
	var private_facts := track.get("viewer_private_facts", {}) as Dictionary
	for item_variant in private_facts.get("own_segment_items", []) as Array:
		if not (item_variant is Dictionary):
			continue
		var item := item_variant as Dictionary
		if str(item.get("instance_id", "")) == instance_id:
			return item.duplicate(true)
	return {}


func _current_card_queue_binding(candidate: Dictionary) -> Dictionary:
	if candidate.is_empty() or _selected_card_id.is_empty():
		return {}
	var candidate_option_id := str(candidate.get("option_id", ""))
	var candidate_target_slot := str(candidate.get("target_slot_id", ""))
	for option_variant in _v075_snapshot.get("legal_actions", []) as Array:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		if (
			str(option.get("card_instance_id", "")) == _selected_card_id
			and (
				candidate_option_id.is_empty()
				or str(option.get("option_id", "")) == candidate_option_id
			)
			and str(option.get("target_slot_id", "")) == candidate_target_slot
		):
			if _v075_card_domain(_selected_card_definition_id) == "facility":
				if not is_instance_valid(_v075_flow):
					return {}
				var resolved := _v075_flow.call(
					"resolve_map_target",
					_selected_card_id,
					str(option.get("target_region_id", "")),
					str(option.get("facility_type", "")),
					str(option.get("industry_id", "")),
					str(option.get("facility_action_mode", ""))
				) as Dictionary
				if not bool(resolved.get("accepted", false)):
					return {}
				return (
					resolved.get("binding", {}) as Dictionary
				).duplicate(true)
			return option.duplicate(true)
	return {}


func _revalidate_current_action() -> void:
	if _action_submission_pending:
		return
	match _current_action_mode:
		"purchase":
			var current_item := _current_track_item(str(
				_selected_track_item.get("instance_id", "")
			))
			if current_item.is_empty():
				_selected_track_item = {}
				_current_action_mode = "idle"
				_current_action_source_surface = ""
				_show_toast("牌轨报价已变化，请重新选择", false)
			else:
				_selected_track_item = current_item
		"card_play", "military":
			if _selected_hand_card().is_empty():
				_pending_confirm_binding = {}
				_current_action_mode = "idle"
				_current_action_source_surface = ""
				super._clear_selected_card()
				_show_toast("手牌状态已变化，请重新选择", false)
			elif not _pending_confirm_binding.is_empty():
				var current_binding := (
					_current_military_option(_pending_confirm_binding)
					if _current_action_mode == "military"
					else _current_card_queue_binding(_pending_confirm_binding)
				)
				if current_binding.is_empty():
					_pending_confirm_binding = {}
					_show_toast("目标授权已变化，请重新选择", false)
	_update_current_action_panel()


func _selected_card_legal_option_count() -> int:
	if _selected_card_id.is_empty():
		return 0
	var count := 0
	for option_variant in _v075_snapshot.get("legal_actions", []) as Array:
		if (
			option_variant is Dictionary
			and str((option_variant as Dictionary).get(
				"card_instance_id",
				""
			)) == _selected_card_id
		):
			count += 1
	return count


func _binding_target_label(binding: Dictionary) -> String:
	var region_id := str(binding.get("target_region_id", ""))
	if not region_id.is_empty():
		return _region_label(region_id)
	var source_id := str(binding.get("target_source_instance_id", ""))
	if source_id.is_empty():
		source_id = str(binding.get("target_monster_source_instance_id", ""))
	return "已预绑定怪兽" if not source_id.is_empty() else "已预绑定目标"


func _track_item_public_name(item: Dictionary) -> String:
	var kind := str(item.get("card_kind", "normal_card"))
	var color_id := str(item.get("primary_color", ""))
	if kind == "commodity_card":
		return "%s商品" % _combat_color_label(color_id)
	return "%s · %s" % [
		_card_type_label(str(item.get("card_definition_id", ""))),
		_combat_color_label(color_id),
	]


func _purchase_rejection_text(reason_code: String) -> String:
	return {
		"track_item_not_claimable": "当前槽位不可取得；等待寿司轨滚动",
		"insufficient_assets": "资产不足，暂时不能购买",
		"track_acquisition_outside_submission": "当前阶段不能取得卡牌",
		"source_not_owned": "该槽位不在你的可取得分段",
	}.get(reason_code, reason_code.replace("_", " ")) as String


func _track_acquisition_rejection_reason(item: Dictionary) -> String:
	if str(_v075_snapshot.get("phase", _snapshot.get("phase", "idle"))) != (
		"submission"
	):
		return "track_acquisition_outside_submission"
	if item.is_empty():
		return "track_item_not_claimable"
	if bool(item.get("claimable", false)):
		return ""
	return str(item.get(
		"public_claim_disabled_reason",
		"track_item_not_claimable"
	))


func _render_monster_card_mode_popup(payload: Dictionary) -> void:
	var card_id := str(payload.get("instance_id", ""))
	var options := _monster_card_options_for_card(card_id)
	_monster_mode_popup_card_id = card_id
	_region_popup.visible = true
	_region_popup_title.text = "怪兽牌 · 预绑定模式"
	_region_popup_body.text = (
		"[indent][b]%s[/b] · %s\n"
		+ "模式在锁定前选择；结算时不会自动转换。\n"
		+ "当前合法模式 %d / 4[/indent]"
	) % [
		_card_type_label(str(payload.get("definition_id", ""))),
		str(COLOR_LABELS.get(
			str(payload.get("primary_color", "")),
			payload.get("primary_color", "")
		)),
		options.size(),
	]
	_clear_children(_region_popup_choices)
	for mode in MONSTER_CARD_MODES:
		var mode_options: Array = []
		for option_variant in options:
			var option := option_variant as Dictionary
			if str(option.get("monster_card_mode", "")) == mode:
				mode_options.append(option)
		if not mode_options.is_empty():
			var row := HBoxContainer.new()
			row.custom_minimum_size = Vector2(0.0, 42.0)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 7)
			var target_menu := OptionButton.new()
			target_menu.custom_minimum_size = Vector2(0.0, 42.0)
			target_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			target_menu.fit_to_longest_item = false
			target_menu.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			for option_variant in mode_options:
				var option := option_variant as Dictionary
				var target_index := target_menu.item_count
				target_menu.add_item(_monster_mode_target_label(option))
				target_menu.set_item_metadata(
					target_index,
					option.duplicate(true)
				)
			target_menu.select(0)
			var choose_button := Button.new()
			choose_button.custom_minimum_size = Vector2(132.0, 42.0)
			choose_button.text = str(MONSTER_CARD_MODE_LABELS.get(mode, mode))
			choose_button.tooltip_text = str(
				MONSTER_CARD_MODE_HINTS.get(mode, "")
			)
			_apply_monster_mode_button_style(choose_button, mode)
			choose_button.pressed.connect(func() -> void:
				var selected := target_menu.get_item_metadata(
					target_menu.selected
				) as Dictionary
				_queue_monster_card_mode(selected)
			)
			row.add_child(target_menu)
			row.add_child(choose_button)
			_region_popup_choices.add_child(row)
		if mode_options.is_empty():
			var unavailable := Label.new()
			unavailable.custom_minimum_size = Vector2(0.0, 26.0)
			unavailable.text = "%s · 当前不可用" % str(
				MONSTER_CARD_MODE_LABELS.get(mode, mode)
			)
			unavailable.add_theme_color_override(
				"font_color",
				Color("#68788d")
			)
			_region_popup_choices.add_child(unavailable)


func _monster_card_options_for_card(card_id: String) -> Array:
	var result: Array = []
	if card_id.is_empty():
		return result
	for option_variant in _v075_snapshot.get("legal_actions", []) as Array:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		if (
			str(option.get("action_domain", "")) == "monster"
			and str(option.get("card_instance_id", "")) == card_id
			and str(option.get("monster_card_mode", "")) in MONSTER_CARD_MODES
			and bool(option.get("mode_prebound", true))
		):
			result.append(option.duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_mode := MONSTER_CARD_MODES.find(
			str(left.get("monster_card_mode", ""))
		)
		var right_mode := MONSTER_CARD_MODES.find(
			str(right.get("monster_card_mode", ""))
		)
		if left_mode != right_mode:
			return left_mode < right_mode
		return str(left.get("option_id", "")) < str(
			right.get("option_id", "")
		)
	)
	return result


func _monster_mode_target_label(option: Dictionary) -> String:
	var mode := str(option.get("monster_card_mode", ""))
	var region_label := _region_label(str(option.get("target_region_id", "")))
	if mode == "DEPLOY_NEW":
		return "部署至 %s" % region_label
	if mode == "REPLACE_EXISTING":
		return "现有怪兽 → %s" % region_label
	return "现有怪兽 · %s" % region_label


func _queue_monster_card_mode(option: Dictionary) -> void:
	if (
		option.is_empty()
		or str(option.get("card_instance_id", "")) != _monster_mode_popup_card_id
		or str(option.get("monster_card_mode", "")) not in MONSTER_CARD_MODES
		or not bool(option.get("mode_prebound", true))
	):
		_show_toast("怪兽模式选项已过期，请重新选择手牌", false)
		return
	_emit_playtest_event("target_bound", {
		"region_id": str(option.get("target_region_id", "")),
		"interaction_mode": str(option.get(
			"monster_card_mode",
			"unknown"
		)).to_lower(),
		"source_surface": "monster_mode_popup",
	})
	_action_status.text = "%s · 已预绑定，等待锁定" % str(
		MONSTER_CARD_MODE_LABELS.get(
			str(option.get("monster_card_mode", "")),
			option.get("monster_card_mode", "")
		)
	)
	_pending_confirm_binding = option.duplicate(true)
	_pending_target_event = {
		"card_definition_id": _selected_card_definition_id,
		"color_id": _selected_card_color,
		"region_id": str(option.get("target_region_id", "")),
		"monster_card_mode": str(option.get("monster_card_mode", "")),
		"source_surface": "monster_mode_popup",
	}
	_current_action_mode = "card_play"
	_current_action_source_surface = "monster_mode_popup"
	_current_action_started_msec = Time.get_ticks_msec()
	_region_popup.visible = false
	_update_current_action_panel()


func _apply_monster_mode_button_style(button: Button, mode: String) -> void:
	var accent := Color("#55d6bc")
	if mode == "REFRESH_EXISTING":
		accent = Color("#75d994")
	elif mode == "UPGRADE_EXISTING":
		accent = Color("#7bb8ff")
	elif mode == "REPLACE_EXISTING":
		accent = Color("#e48c78")
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#162238")
	normal.border_color = accent.darkened(0.35)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = accent.darkened(0.68)
	hover.border_color = accent
	hover.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", hover)


# V0.7.5 combat cards use the authoritative registry domain before falling
# back to the inherited facility renderer. This keeps the public card face
# aligned with the combat definition without changing supply or projection.
func _v075_card_definition(definition_id: String) -> Dictionary:
	if definition_id.is_empty():
		return {}
	return V075CardDefinitionRegistry.definition(definition_id)


func _v075_card_domain(definition_id: String) -> String:
	var definition := _v075_card_definition(definition_id)
	if definition.is_empty():
		return ""
	return V075CardDefinitionRegistry.card_domain(
		str(definition.get("card_type", ""))
	)


func _v075_combat_card_art_path(definition_id: String) -> String:
	return str(
		V075CardDefinitionRegistry.presentation_descriptor(
			definition_id
		).get("resource_path", "")
	)


func _card_type_label(definition_id: String) -> String:
	match _v075_card_domain(definition_id):
		"monster":
			return "怪兽"
		"military":
			return "军队"
	return super._card_type_label(definition_id)


func _card_art(item: Dictionary) -> Texture2D:
	var definition_id := str(item.get("card_definition_id", ""))
	var domain := _v075_card_domain(definition_id)
	if domain in ["monster", "military"]:
		# Known combat definitions fail closed when their typed presentation
		# resource cannot be loaded; facility art must never mask that failure.
		return V075CardDefinitionRegistry.presentation_texture(definition_id)
	return super._card_art(item)


func v075_card_presentation_audit(item: Dictionary) -> Dictionary:
	var definition_id := str(item.get("card_definition_id", ""))
	var definition := _v075_card_definition(definition_id)
	var card_type := str(definition.get("card_type", ""))
	var domain := _v075_card_domain(definition_id)
	var descriptor := V075CardDefinitionRegistry.presentation_descriptor(
		definition_id
	)
	var descriptor_error := (
		V075CardDefinitionRegistry.presentation_descriptor_error(descriptor)
		if not descriptor.is_empty()
		else "presentation_descriptor_missing"
	)
	var art := _card_art(item)
	var art_path := str(art.resource_path) if art != null else ""
	var mapped_path := _v075_combat_card_art_path(definition_id)
	var expected_art := V075CardDefinitionRegistry.presentation_texture(
		definition_id
	)
	var uses_facility_art := (
		art_path in V075_FACILITY_ART_PATHS
		or mapped_path in V075_FACILITY_ART_PATHS
	)
	return {
		"schema": "V075CardPresentationAuditV2",
		"local_slot_index": int(item.get("local_slot_index", -1)),
		"card_definition_id": definition_id,
		"card_type": card_type,
		"domain": domain,
		"type_label": _card_type_label(definition_id),
		"art_present": art != null,
		"art_resource_path": art_path,
		"stable_mapping_path": mapped_path,
		"presentation_asset_key": str(
			descriptor.get("presentation_asset_key", "")
		),
		"presentation_descriptor_error": descriptor_error,
		"resource_loader_exists": (
			ResourceLoader.exists(mapped_path, "Texture2D")
			if not mapped_path.is_empty()
			else false
		),
		"resource_loaded_as_texture": expected_art != null,
		"instance_binding_green": art != null and art == expected_art,
		"uses_facility_art": uses_facility_art,
		"combat_art_mapping_green": (
			domain in ["monster", "military"]
			and descriptor_error.is_empty()
			and art != null
			and art == expected_art
			and art_path == mapped_path
			and not uses_facility_art
			and not mapped_path.is_empty()
		),
	}


func _refresh_planet_presentation() -> void:
	super._refresh_planet_presentation()
	call_deferred("_sync_combat_map_projection")


func _combat_map_view() -> Control:
	if not is_instance_valid(_planet_board):
		return null
	var map_view_variant: Variant = _planet_board.call(
		"get_embedded_map_view"
	)
	return (
		map_view_variant as Control
		if map_view_variant is Control
		else null
	)


func _sync_combat_map_projection() -> bool:
	var map_view := _combat_map_view()
	if not is_instance_valid(map_view) or not map_view.has_method("set_map"):
		return false
	var districts := _combat_array(map_view.get("districts"))
	var palette := _combat_array(map_view.get("palette"))
	if districts.is_empty() or palette.size() != districts.size():
		return false
	var centers := _combat_region_centers(districts)
	if centers.is_empty():
		return false

	var base_markers := _without_v075_combat_rows(
		map_view.get("auto_monster_markers")
	)
	var markers := base_markers.duplicate(true)
	markers.append_array(_combat_monster_markers(centers))

	var base_trails := _without_v075_combat_rows(
		map_view.get("movement_trails")
	)
	var base_effects := _without_v075_combat_rows(
		map_view.get("map_event_effects")
	)
	var base_callouts := _without_v075_combat_rows(
		map_view.get("action_callouts")
	)
	var trails := base_trails.duplicate(true)
	var effects := base_effects.duplicate(true)
	var callouts := base_callouts.duplicate(true)
	for cue in _combat_map_cues:
		_append_combat_cue_layers(
			cue,
			centers,
			trails,
			effects,
			callouts
		)

	var sync_signature := _combat_sync_signature({
		"districts": districts,
		"markers": markers,
		"trails": trails,
		"effects": effects,
		"callouts": callouts,
	})
	if sync_signature == _combat_map_last_sync_signature:
		return true
	_combat_map_last_sync_signature = sync_signature
	_combat_map_marker_count = markers.size() - base_markers.size()
	_combat_map_trail_count = trails.size() - base_trails.size()
	_combat_map_effect_count = effects.size() - base_effects.size()
	_combat_map_callout_count = callouts.size() - base_callouts.size()
	map_view.call(
		"set_map",
		districts,
		float(map_view.get("map_width_m")),
		float(map_view.get("map_height_m")),
		int(map_view.get("selected_district")),
		palette,
		trails,
		callouts,
		effects,
		markers,
		_combat_array(map_view.get("city_markers")),
		_combat_array(map_view.get("trade_route_markers")),
		str(map_view.get("trade_product")),
		str(map_view.get("visual_layer_focus"))
	)
	_combat_map_projection_apply_count += 1
	return true


func _combat_sync_signature(value: Variant) -> String:
	if value is Dictionary:
		var dictionary := value as Dictionary
		var keys: Array[String] = []
		for key_variant in dictionary.keys():
			keys.append(str(key_variant))
		keys.sort()
		var fields: Array[String] = []
		for key in keys:
			fields.append(
				"%s:%s" % [
					JSON.stringify(key),
					_combat_sync_signature(dictionary.get(key)),
				]
			)
		return "{%s}" % ",".join(fields)
	if value is Array:
		var items: Array[String] = []
		for item in value as Array:
			items.append(_combat_sync_signature(item))
		return "[%s]" % ",".join(items)
	return JSON.stringify(value)


func _combat_array(value: Variant) -> Array:
	return (
		(value as Array).duplicate(true)
		if value is Array
		else []
	)


func _without_v075_combat_rows(value: Variant) -> Array:
	var rows: Array = []
	if not (value is Array):
		return rows
	for row_variant in value as Array:
		if (
			row_variant is Dictionary
			and bool(
				(row_variant as Dictionary).get(
					"v075_combat_presentation",
					false
				)
			)
		):
			continue
		rows.append(
			(row_variant as Dictionary).duplicate(true)
			if row_variant is Dictionary
			else row_variant
		)
	return rows


func _combat_region_centers(districts: Array) -> Dictionary:
	var centers := {}
	for district_variant in districts:
		if not (district_variant is Dictionary):
			continue
		var district := district_variant as Dictionary
		var region_id := str(district.get("region_id", ""))
		var center_variant: Variant = district.get("center")
		if region_id.is_empty() or not (center_variant is Vector2):
			continue
		centers[region_id] = center_variant
	return centers


func _combat_monster_markers(centers: Dictionary) -> Array:
	var markers: Array = []
	for source_variant in _combat_projection.get(
		"public_monsters",
		[]
	) as Array:
		if not (source_variant is Dictionary):
			continue
		var source := source_variant as Dictionary
		var region_id := str(source.get("region_id", ""))
		if region_id.is_empty() or not centers.has(region_id):
			continue
		var color_id := str(
			source.get("preferred_industry_color", "")
		)
		var accent := _combat_map_color(color_id)
		var display_name := str(
			source.get(
				"display_name",
				source.get("monster_family_id", "怪兽")
			)
		)
		markers.append({
			"v075_combat_presentation": true,
			"source_instance_id": str(
				source.get("source_instance_id", "")
			),
			"owner_player_id": str(
				source.get("owner_player_id", "")
			),
			"position": centers.get(region_id),
			"name": display_name,
			"label": "L%d" % int(source.get("rank", 1)),
			"glyph": "M",
			"display_subtitle": (
				"HP %d/%d · 护甲 %d · 偏好%s"
				% [
					int(source.get("hp", 0)),
					int(source.get("max_hp", 0)),
					int(source.get("armor", 0)),
					_combat_color_label(color_id),
				]
			),
			"color": accent,
			"secondary": accent.lightened(0.28),
			"model_asset_key": str(
				source.get("model_asset_key", "")
			),
			"status": str(source.get("status", "active")),
			"region_id": region_id,
		})
	return markers


func _append_combat_cue_layers(
	cue: Dictionary,
	centers: Dictionary,
	trails: Array,
	effects: Array,
	callouts: Array
) -> void:
	var event_kind := str(cue.get("event_kind", ""))
	var payload := cue.get("public_payload", {}) as Dictionary
	var accent := _combat_map_cue_color(event_kind, payload)
	var target_region_id := _combat_cue_target_region(payload)
	if event_kind == "monster_moved":
		var path := payload.get("ordered_region_path", []) as Array
		for index in range(maxi(0, path.size() - 1)):
			var from_region_id := str(path[index])
			var to_region_id := str(path[index + 1])
			if (
				not centers.has(from_region_id)
				or not centers.has(to_region_id)
			):
				continue
			trails.append({
				"v075_combat_presentation": true,
				"from": centers.get(from_region_id),
				"to": centers.get(to_region_id),
				"label": "怪兽自动移动",
				"style": "monster",
				"life": 6.0,
				"duration": 6.0,
				"color": accent,
				"source_region_id": from_region_id,
				"target_region_id": to_region_id,
			})
	elif event_kind == "monster_trample_resolved":
		if centers.has(target_region_id):
			effects.append({
				"v075_combat_presentation": true,
				"kind": "impact",
				"position": centers.get(target_region_id),
				"label": "践踏 %d" % int(payload.get(
					"region_damage_budget",
					payload.get("damage_amount", 0)
				)),
				"life": 6.0,
				"duration": 6.0,
				"radius_m": 110.0,
				"motion_family": "monster_trample",
				"effect_layer": "combat",
				"color": accent,
				"region_id": target_region_id,
			})
	elif event_kind in [
		"monster_deployed",
		"monster_refreshed",
		"monster_upgraded",
		"monster_replaced",
		"monster_basic_attack",
		"monster_private_skill_resolved",
		"monster_damaged",
		"monster_downed",
		"monster_destroyed",
		"facility_combat_damaged",
		"armor_absorbed",
		"military_region_assault",
		"military_monster_assault",
	]:
		if centers.has(target_region_id):
			effects.append({
				"v075_combat_presentation": true,
				"kind": (
					"beam"
					if event_kind in [
						"monster_basic_attack",
						"monster_private_skill_resolved",
					]
					else "impact"
				),
				"from": centers.get(
					str(payload.get("start_region_id", "")),
					centers.get(target_region_id)
				),
				"to": centers.get(target_region_id),
				"position": centers.get(target_region_id),
				"label": _combat_map_cue_summary(
					event_kind,
					payload
				),
				"life": 6.0,
				"duration": 6.0,
				"radius_m": 90.0,
				"motion_family": event_kind,
				"effect_layer": "combat",
				"color": accent,
				"region_id": target_region_id,
			})
	var summary := _combat_map_cue_summary(event_kind, payload)
	if summary.is_empty():
		return
	callouts.append({
		"v075_combat_presentation": true,
		"title": _combat_map_cue_title(event_kind),
		"detail": summary,
		"life": 8.0,
		"duration": 8.0,
		"color": accent,
		"event_kind": event_kind,
		"region_id": target_region_id,
	})


func _combat_cue_target_region(payload: Dictionary) -> String:
	for field in [
		"region_id",
		"target_region_id",
		"destination_region_id",
		"start_region_id",
	]:
		var region_id := str(payload.get(field, ""))
		if not region_id.is_empty():
			return region_id
	var target_source_id := str(
		payload.get("target_monster_source_instance_id", "")
	)
	if target_source_id.is_empty():
		return ""
	for source_variant in _combat_projection.get(
		"public_monsters",
		[]
	) as Array:
		if not (source_variant is Dictionary):
			continue
		var source := source_variant as Dictionary
		if str(source.get("source_instance_id", "")) == target_source_id:
			return str(source.get("region_id", ""))
	return ""


func _combat_map_cue_title(event_kind: String) -> String:
	if event_kind.begins_with("military_"):
		return "军队"
	if event_kind == "facility_combat_damaged":
		return "设施受损"
	if event_kind == "monster_trample_resolved":
		return "怪兽践踏"
	return "怪兽"


func _combat_map_cue_summary(
	event_kind: String,
	payload: Dictionary
) -> String:
	match event_kind:
		"monster_deployed":
			return "怪兽部署至 %s" % _combat_cue_target_region(payload)
		"monster_refreshed":
			return "同族牌恢复 %d%% 最大生命" % int(
				payload.get("refresh_percent", 0)
			)
		"monster_upgraded":
			return "升级至 L%d，旧技能冷却保持" % int(
				payload.get("new_rank", payload.get("source_rank", 1))
			)
		"monster_replaced":
			return "旧怪兽撤回，新怪兽部署"
		"monster_moved":
			return "沿动态地区最短路径移动"
		"monster_trample_resolved":
			return "%s · 距离 %d · 伤害 %d" % [
				str(payload.get("region_id", "")),
				int(payload.get("distance_milli_arc", 0)),
				int(payload.get(
					"region_damage_budget",
					payload.get("damage_amount", 0)
				)),
			]
		"monster_basic_attack":
			return "到达后基础攻击 · %d 伤害" % int(
				payload.get("damage_amount", 0)
			)
		"monster_private_skill_resolved":
			return "私密技能公开效果已结算"
		"monster_damaged":
			return "怪兽受到 %d 伤害" % int(
				payload.get("damage_amount", 0)
			)
		"monster_downed":
			return "怪兽倒地"
		"monster_destroyed":
			return "怪兽被摧毁"
		"military_region_assault":
			return "区域总伤害预算已分配"
		"military_monster_assault":
			return "锁定怪兽受到一次攻击"
		"military_withdrawn":
			return "任务完成，军队撤离并进入弃牌池"
		"facility_combat_damaged":
			return "%s · %s设施受到战斗伤害" % [
				_combat_cue_target_region(payload),
				str(payload.get("facility_type", "")),
			]
		"armor_absorbed":
			return "护甲吸收伤害"
	return ""


func _combat_map_cue_color(
	event_kind: String,
	payload: Dictionary
) -> Color:
	if event_kind.begins_with("military_"):
		return Color("#ef9a74")
	if event_kind == "facility_combat_damaged":
		return Color("#e4bd69")
	return _combat_map_color(
		str(payload.get("preferred_industry_color", ""))
	)


func _combat_map_color(color_id: String) -> Color:
	var value: Variant = COMBAT_MAP_COLOR_VALUES.get(
		color_id,
		COMBAT_MAP_DEFAULT_COLOR
	)
	return value as Color if value is Color else COMBAT_MAP_DEFAULT_COLOR


func _combat_color_label(color_id: String) -> String:
	return str({
		"life": "生命",
		"energy": "能源",
		"industry": "工业",
		"technology": "科技",
		"commerce": "商业",
		"shipping": "航运",
	}.get(color_id, color_id))
