extends Control
class_name V075CombatPlayerSurface

signal private_target_selection_requested(request: Dictionary)
signal military_mission_selected(option: Dictionary)
signal responsive_minimum_resolved(preferred_height: float)
signal combat_observatory_animation_finished(
	receipt_id: String,
	evidence: Dictionary
)

const CATALOG := preload(
	"res://resources/presentation/alpha01_card_illustration_catalog.tres"
)
const ResponsiveAcceptanceAudit := preload(
	"res://scripts/ui/v075/v075_responsive_acceptance_audit.gd"
)
const CapabilityCatalog := preload(
	"res://scripts/v075/combat/v075_combat_capability_catalog.gd"
)
const COLOR_LABELS := {
	"life": "生命",
	"energy": "能源",
	"industry": "工业",
	"technology": "科技",
	"commerce": "商业",
	"shipping": "航运",
}
const COLOR_VALUES := {
	"life": Color("#76d89b"),
	"energy": Color("#f3cd68"),
	"industry": Color("#f08a74"),
	"technology": Color("#7fb6ff"),
	"commerce": Color("#d993ef"),
	"shipping": Color("#67d8d5"),
}
const RANK_LABELS := ["", "I", "II", "III", "IV"]
const PRESENTATION_HISTORY_LIMIT := 4
const COMBAT_OBSERVATORY_WINDOW_LIMIT := 6
const COMBAT_OBSERVATORY_MINIMUM_CONCURRENT_VIEWS := 3
const COMBAT_OBSERVATORY_EVIDENCE_LIMIT := 64
const COMBAT_OBSERVATORY_WINDOW_SIZE := Vector2(238.0, 116.0)
const COMBAT_OBSERVATORY_DEFAULT_DURATION_MS := 520
const COMBAT_OBSERVATORY_MINIMUM_DURATION_MS := 140
const COMBAT_OBSERVATORY_MAXIMUM_DURATION_MS := 2200
const COMBAT_OBSERVATORY_TERMINAL_PHASES := [
	"victory_pending",
	"victory_resolved",
	"final_settlement",
	"terminal",
]
const PRIVATE_TWO_COLUMN_MIN_CONTENT_WIDTH := 620.0
const LAYOUT_EPSILON := 0.5

@onready var _public_panel: PanelContainer = %PublicMonsterPanel
@onready var _name_label: Label = %MonsterName
@onready var _rank_label: Label = %MonsterRank
@onready var _status_label: Label = %MonsterStatus
@onready var _preferred_icon: TextureRect = %PreferredColorIcon
@onready var _preferred_label: Label = %PreferredColorLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _armor_label: Label = %ArmorLabel
@onready var _region_label: Label = %RegionLabel
@onready var _target_label: Label = %TargetLabel
@onready var _path_label: Label = %PathLabel
@onready var _unlocked_label: Label = %UnlockedSkillCount
@onready var _batch_used_badge: Label = %BatchUsedBadge
@onready var _info_grid: GridContainer = (
	$Rows/PublicMonsterPanel/Margin/Rows/InfoRow
)
@onready var _private_grid: GridContainer = %PrivateGrid
@onready var _rows: VBoxContainer = $Rows
@onready var _skill_dock: V075MonsterPrivateSkillDock = %SkillDock
@onready var _military_panel: V075MilitaryMissionPanel = %MilitaryPanel
@onready var _presentation_strip: PanelContainer = %PresentationStrip
@onready var _cue_icon: TextureRect = %CueIcon
@onready var _presentation_label: Label = %PresentationLabel
@onready var _cue_asset_label: Label = %CueAssetLabel
@onready var _cue_progress: ProgressBar = %CueProgress
@onready var _combat_observatory: PanelContainer = %CombatObservatory
@onready var _observatory_status: Label = %ObservatoryStatus
@onready var _observatory_previous_button: Button = %PreviousObservatoryWindow
@onready var _observatory_next_button: Button = %NextObservatoryWindow
@onready var _observatory_scroll: ScrollContainer = %ObservatoryWindowScroll
@onready var _observatory_window_rail: HBoxContainer = %ObservatoryWindowRail
@onready var _observatory_empty_label: Label = %ObservatoryEmptyLabel

var _projection: Dictionary = {}
var _selected_public_monster: Dictionary = {}
var _layout_mode := "COMPACT"
var _viewer_is_owner := false
var _viewer_can_submit_military := false
var _last_cue: Dictionary = {}
var _presentation_history: Array[String] = []
var _presentation_cue_fingerprints: Dictionary = {}
var _presentation_cue_applied_count := 0
var _presentation_cue_duplicate_count := 0
var _presentation_cue_collision_count := 0
var _presentation_cue_rejected_count := 0
var _presentation_animation_count := 0
var _presentation_tween: Tween
var _combat_observatory_windows: Dictionary = {}
var _combat_observatory_order: Array[String] = []
var _combat_observatory_tweens: Dictionary = {}
var _combat_observatory_finished_ids: Dictionary = {}
var _combat_observatory_evidence: Array[Dictionary] = []
var _active_combat_observatory_receipt_id := ""
var _combat_observatory_window_create_count := 0
var _combat_observatory_window_evict_count := 0
var _combat_observatory_expand_count := 0
var _combat_observatory_collapse_count := 0
var _combat_observatory_pin_count := 0
var _combat_observatory_unpin_count := 0
var _combat_observatory_switch_count := 0
var _combat_observatory_duplicate_count := 0
var _combat_observatory_collision_count := 0
var _combat_observatory_privacy_rejection_count := 0
var _combat_observatory_terminal_rejection_count := 0
var _combat_observatory_identity_rejection_count := 0
var _combat_observatory_animation_start_count := 0
var _combat_observatory_animation_finish_count := 0
var _combat_observatory_finish_duplicate_count := 0
var _combat_observatory_rect_evidence_count := 0
var _combat_observatory_source_anchor_count := 0
var _combat_observatory_target_anchor_count := 0
var _combat_observatory_missing_anchor_count := 0
var _combat_observatory_instant_mode_rejection_count := 0
var _combat_observatory_overflow_count := 0
var _combat_observatory_terminal_phase := ""
var _layout_settle_scheduled := false
var _last_resolved_preferred_height := -1.0
var _presentation_reduced_motion := false
var _presentation_screen_shake_enabled := true
var _presentation_policy_apply_count := 0


func _ready() -> void:
	_apply_styles()
	_presentation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_presentation_label.max_lines_visible = PRESENTATION_HISTORY_LIMIT
	_skill_dock.private_target_selection_requested.connect(
		_on_private_target_selection_requested
	)
	_military_panel.mission_selected.connect(
		_on_military_mission_selected
	)
	_observatory_previous_button.pressed.connect(
		_switch_combat_observatory_window.bind(-1)
	)
	_observatory_next_button.pressed.connect(
		_switch_combat_observatory_window.bind(1)
	)
	resized.connect(_resolve_layout)
	_resolve_layout()
	_refresh_combat_observatory_header()
	if _projection.is_empty():
		_render_empty()


func set_presentation_motion_policy(
	reduced_motion: bool,
	screen_shake_enabled: bool = true
) -> void:
	_presentation_reduced_motion = reduced_motion
	_presentation_screen_shake_enabled = screen_shake_enabled
	_presentation_policy_apply_count += 1


func presentation_motion_policy_snapshot() -> Dictionary:
	return {
		"schema": "V076CombatPresentationMotionPolicyV1",
		"motion_mode": (
			"REDUCED_MOTION"
			if _presentation_reduced_motion
			else "FULL_MOTION"
		),
		"reduced_motion": _presentation_reduced_motion,
		"screen_shake_enabled": (
			_presentation_screen_shake_enabled
			and not _presentation_reduced_motion
		),
		"apply_count": _presentation_policy_apply_count,
		"production_ui_instant_test_mode_reachable": false,
	}


func apply_projection(
	projection: Dictionary,
	preferred_source_instance_id := ""
) -> void:
	_projection = projection.duplicate(true)
	var projected_phase := str(projection.get(
		"phase",
		projection.get("combat_phase", "")
	))
	if projected_phase in COMBAT_OBSERVATORY_TERMINAL_PHASES:
		set_terminal_phase(projected_phase)
	_selected_public_monster = _select_public_monster(
		projection.get("public_monsters", []) as Array,
		preferred_source_instance_id
	)
	_render_public_monster()
	_render_private_surfaces()
	_resolve_layout()
	call_deferred("_resolve_layout")


func preferred_content_height() -> float:
	if not is_instance_valid(_rows):
		return 410.0
	var content_height := _rows.get_combined_minimum_size().y + 20.0
	return maxf(410.0, content_height)


func show_presentation_cue(
	cue: Dictionary,
	animation_cue: Dictionary = {}
) -> Dictionary:
	var cue_id := str(cue.get("presentation_receipt_id", "")).strip_edges()
	if cue_id.is_empty():
		_presentation_cue_rejected_count += 1
		_combat_observatory_identity_rejection_count += 1
		return _presentation_cue_result(
			false,
			"presentation_cue_identity_missing"
		)
	if not _combat_observatory_terminal_phase.is_empty():
		_presentation_cue_rejected_count += 1
		_combat_observatory_terminal_rejection_count += 1
		return _presentation_cue_result(
			false,
			"post_terminal_combat_observatory_cue_rejected"
		)
	if (
		(cue.has("audience_scope") and str(cue.get(
			"audience_scope",
			""
		)) != "PUBLIC")
		or (cue.has("presentation_only") and not bool(cue.get(
			"presentation_only",
			false
		)))
		or _count_private_skill_keys(cue) > 0
	):
		_presentation_cue_rejected_count += 1
		_combat_observatory_privacy_rejection_count += 1
		return _presentation_cue_result(
			false,
			"presentation_cue_private_field_rejected"
		)
	if not animation_cue.is_empty():
		var animation_receipt_id := str(animation_cue.get(
			"receipt_id",
			""
		)).strip_edges()
		if animation_receipt_id != cue_id:
			_presentation_cue_rejected_count += 1
			_combat_observatory_identity_rejection_count += 1
			return _presentation_cue_result(
				false,
				"combat_observatory_animation_identity_mismatch"
			)
		if (
			(animation_cue.has("privacy_class") and str(
				animation_cue.get("privacy_class", "")
			) != "PUBLIC")
			or _count_private_skill_keys(animation_cue) > 0
		):
			_presentation_cue_rejected_count += 1
			_combat_observatory_privacy_rejection_count += 1
			return _presentation_cue_result(
				false,
				"combat_observatory_animation_private"
			)
		if bool(animation_cue.get("instant_test_mode", false)):
			_presentation_cue_rejected_count += 1
			_combat_observatory_instant_mode_rejection_count += 1
			return _presentation_cue_result(
				false,
				"combat_observatory_instant_mode_not_production_reachable"
			)
	# Observer correlation is transport-only metadata. It must not become a
	# second Presentation identity dialect at the local animation surface.
	var semantic_cue := cue.duplicate(true)
	semantic_cue.erase("observer_correlation_id")
	semantic_cue.erase("observer_correlation_fingerprint")
	var fingerprint := _canonical_cue_json(semantic_cue).sha256_text()
	if _presentation_cue_fingerprints.has(cue_id):
		if str(_presentation_cue_fingerprints.get(cue_id, "")) == fingerprint:
			_presentation_cue_duplicate_count += 1
			_combat_observatory_duplicate_count += 1
			return _presentation_cue_result(
				false,
				"presentation_cue_duplicate"
			)
		_presentation_cue_collision_count += 1
		_combat_observatory_collision_count += 1
		return _presentation_cue_result(
			false,
			"presentation_cue_identity_collision"
		)
	var window := _create_combat_observatory_window(
		cue_id,
		cue,
		animation_cue,
		fingerprint
	)
	if window == null:
		_presentation_cue_rejected_count += 1
		return _presentation_cue_result(
			false,
			"combat_observatory_window_unavailable"
		)
	_presentation_cue_fingerprints[cue_id] = fingerprint
	_presentation_cue_applied_count += 1
	_last_cue = cue.duplicate(true)
	var payload := cue.get("public_payload", {}) as Dictionary
	var summary := str(payload.get("public_summary", ""))
	if summary.is_empty():
		summary = _cue_summary(str(cue.get("event_kind", "")), payload)
	if not summary.is_empty():
		_presentation_history.push_front(summary)
		while _presentation_history.size() > PRESENTATION_HISTORY_LIMIT:
			_presentation_history.pop_back()
	_presentation_label.text = "\n".join(_presentation_history)
	var asset_keys := cue.get("asset_keys", []) as Array
	_cue_asset_label.text = _presentation_asset_caption(asset_keys)
	_cue_icon.texture = _first_cue_texture(asset_keys)
	_cue_icon.modulate = _cue_color(str(cue.get("event_kind", "")))
	_cue_icon.visible = _cue_icon.texture != null
	_cue_progress.value = 0.0
	if _presentation_tween != null and _presentation_tween.is_valid():
		_presentation_tween.kill()
	_presentation_tween = create_tween()
	_presentation_tween.set_trans(Tween.TRANS_SINE)
	_presentation_tween.set_ease(Tween.EASE_OUT)
	_presentation_tween.tween_property(
		_cue_progress,
		"value",
		100.0,
		0.16 if _presentation_reduced_motion else 0.34
	)
	_presentation_animation_count += 1
	_presentation_strip.visible = not _presentation_history.is_empty()
	_combat_observatory.visible = true
	_observatory_empty_label.visible = false
	select_combat_observatory_window(cue_id)
	call_deferred("_start_combat_observatory_animation", cue_id)
	_refresh_combat_observatory_header()
	_schedule_layout_settle()
	var result := _presentation_cue_result(true, "none")
	result["combat_window_created"] = true
	result["combat_window_count"] = _combat_observatory_windows.size()
	result["animation_pending"] = true
	return result


func reset_presentation_cues() -> void:
	_clear_combat_observatory_windows(false, "new_match_reset")
	_presentation_cue_fingerprints.clear()
	_presentation_cue_applied_count = 0
	_presentation_cue_duplicate_count = 0
	_presentation_cue_collision_count = 0
	_presentation_cue_rejected_count = 0
	_presentation_animation_count = 0
	_last_cue = {}
	_presentation_history.clear()
	_presentation_label.text = ""
	_cue_asset_label.text = ""
	_cue_icon.texture = null
	_cue_icon.visible = false
	_cue_progress.value = 0.0
	if _presentation_tween != null and _presentation_tween.is_valid():
		_presentation_tween.kill()
	_presentation_strip.visible = false
	_combat_observatory_finished_ids.clear()
	_combat_observatory_evidence.clear()
	_active_combat_observatory_receipt_id = ""
	_combat_observatory_window_create_count = 0
	_combat_observatory_window_evict_count = 0
	_combat_observatory_expand_count = 0
	_combat_observatory_collapse_count = 0
	_combat_observatory_pin_count = 0
	_combat_observatory_unpin_count = 0
	_combat_observatory_switch_count = 0
	_combat_observatory_duplicate_count = 0
	_combat_observatory_collision_count = 0
	_combat_observatory_privacy_rejection_count = 0
	_combat_observatory_terminal_rejection_count = 0
	_combat_observatory_identity_rejection_count = 0
	_combat_observatory_animation_start_count = 0
	_combat_observatory_animation_finish_count = 0
	_combat_observatory_finish_duplicate_count = 0
	_combat_observatory_rect_evidence_count = 0
	_combat_observatory_source_anchor_count = 0
	_combat_observatory_target_anchor_count = 0
	_combat_observatory_missing_anchor_count = 0
	_combat_observatory_instant_mode_rejection_count = 0
	_combat_observatory_overflow_count = 0
	_combat_observatory_terminal_phase = ""
	_combat_observatory.visible = false
	_observatory_empty_label.visible = true
	_refresh_combat_observatory_header()
	_schedule_layout_settle()


func set_terminal_phase(phase: String) -> bool:
	if phase not in COMBAT_OBSERVATORY_TERMINAL_PHASES:
		return false
	if _combat_observatory_terminal_phase.is_empty():
		_combat_observatory_terminal_phase = phase
	_refresh_combat_observatory_header()
	return _combat_observatory_terminal_phase == phase


func select_combat_observatory_window(receipt_id: String) -> bool:
	if not _combat_observatory_windows.has(receipt_id):
		return false
	if _active_combat_observatory_receipt_id != receipt_id:
		_active_combat_observatory_receipt_id = receipt_id
		_combat_observatory_switch_count += 1
	for window_id in _combat_observatory_order:
		_apply_combat_observatory_window_style(window_id)
	call_deferred("_ensure_combat_observatory_window_visible", receipt_id)
	_refresh_combat_observatory_header()
	return true


func set_combat_observatory_window_expanded(
	receipt_id: String,
	expanded: bool
) -> bool:
	if not _combat_observatory_windows.has(receipt_id):
		return false
	var record := _combat_observatory_windows.get(receipt_id, {}) as Dictionary
	if bool(record.get("expanded", true)) == expanded:
		return true
	var panel := record.get("panel", null) as PanelContainer
	var body := record.get("body", null) as Control
	var expand_button := record.get("expand_button", null) as Button
	if panel == null or body == null or expand_button == null:
		return false
	record["expanded"] = expanded
	body.visible = expanded
	panel.custom_minimum_size = Vector2(
		COMBAT_OBSERVATORY_WINDOW_SIZE.x,
		COMBAT_OBSERVATORY_WINDOW_SIZE.y if expanded else 48.0
	)
	expand_button.text = "收起" if expanded else "展开"
	if expanded:
		_combat_observatory_expand_count += 1
	else:
		_combat_observatory_collapse_count += 1
	_combat_observatory_windows[receipt_id] = record
	_refresh_combat_observatory_header()
	_schedule_layout_settle()
	return true


func set_combat_observatory_window_pinned(
	receipt_id: String,
	pinned: bool
) -> bool:
	if not _combat_observatory_windows.has(receipt_id):
		return false
	var record := _combat_observatory_windows.get(receipt_id, {}) as Dictionary
	if bool(record.get("pinned", false)) == pinned:
		return true
	var pin_button := record.get("pin_button", null) as Button
	if pin_button == null:
		return false
	record["pinned"] = pinned
	pin_button.set_pressed_no_signal(pinned)
	pin_button.text = "已固定" if pinned else "固定"
	if pinned:
		_combat_observatory_pin_count += 1
	else:
		_combat_observatory_unpin_count += 1
	_combat_observatory_windows[receipt_id] = record
	_apply_combat_observatory_window_style(receipt_id)
	_refresh_combat_observatory_header()
	return true


func _switch_combat_observatory_window(direction: int) -> void:
	if _combat_observatory_order.is_empty():
		return
	var current_index := _combat_observatory_order.find(
		_active_combat_observatory_receipt_id
	)
	if current_index < 0:
		current_index = 0
	var next_index := posmod(
		current_index + (-1 if direction < 0 else 1),
		_combat_observatory_order.size()
	)
	select_combat_observatory_window(
		_combat_observatory_order[next_index]
	)


func _on_combat_observatory_window_selected(receipt_id: String) -> void:
	select_combat_observatory_window(receipt_id)


func _on_combat_observatory_window_expanded(
	expanded: bool,
	receipt_id: String
) -> void:
	set_combat_observatory_window_expanded(receipt_id, expanded)


func _on_combat_observatory_window_pinned(
	pinned: bool,
	receipt_id: String
) -> void:
	set_combat_observatory_window_pinned(receipt_id, pinned)


func _create_combat_observatory_window(
	receipt_id: String,
	cue: Dictionary,
	animation_cue: Dictionary,
	fingerprint: String
) -> PanelContainer:
	if (
		not is_instance_valid(_observatory_window_rail)
	):
		return null
	_evict_oldest_unpinned_combat_observatory_window()
	var event_kind := str(cue.get("event_kind", ""))
	var payload := cue.get("public_payload", {}) as Dictionary
	var summary := str(payload.get("public_summary", "")).strip_edges()
	if summary.is_empty():
		summary = _cue_summary(event_kind, payload)
	if summary.is_empty():
		summary = "公开战斗效果已结算"
	var panel := PanelContainer.new()
	panel.name = "CombatObservatoryWindow_%s" % receipt_id.sha256_text().left(12)
	panel.custom_minimum_size = COMBAT_OBSERVATORY_WINDOW_SIZE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.tooltip_text = summary
	panel.set_meta("presentation_receipt_id", receipt_id)
	panel.set_meta("presentation_only", true)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	margin.add_child(rows)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	rows.add_child(header)
	var select_button := Button.new()
	select_button.name = "SelectWindow"
	select_button.custom_minimum_size = Vector2(88.0, 25.0)
	select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_button.text = _combat_observatory_event_title(event_kind)
	select_button.tooltip_text = "切换到此公开战斗观测窗"
	select_button.pressed.connect(
		_on_combat_observatory_window_selected.bind(receipt_id)
	)
	header.add_child(select_button)
	var pin_button := Button.new()
	pin_button.name = "PinWindow"
	pin_button.custom_minimum_size = Vector2(48.0, 25.0)
	pin_button.toggle_mode = true
	pin_button.text = "固定"
	pin_button.tooltip_text = "固定后自动清理会优先保留此窗口"
	pin_button.toggled.connect(
		_on_combat_observatory_window_pinned.bind(receipt_id)
	)
	header.add_child(pin_button)
	var expand_button := Button.new()
	expand_button.name = "ExpandWindow"
	expand_button.custom_minimum_size = Vector2(48.0, 25.0)
	expand_button.toggle_mode = true
	expand_button.button_pressed = true
	expand_button.text = "收起"
	expand_button.tooltip_text = "展开或收起只读公开细节"
	expand_button.toggled.connect(
		_on_combat_observatory_window_expanded.bind(receipt_id)
	)
	header.add_child(expand_button)
	var body := VBoxContainer.new()
	body.name = "PublicDetails"
	body.add_theme_constant_override("separation", 3)
	rows.add_child(body)
	var summary_label := Label.new()
	summary_label.name = "PublicSummary"
	summary_label.text = summary
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.max_lines_visible = 2
	summary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary_label.add_theme_color_override("font_color", Color("#d7e6ee"))
	summary_label.add_theme_font_size_override("font_size", 11)
	body.add_child(summary_label)
	var route_label := Label.new()
	route_label.name = "PublicTarget"
	route_label.text = _combat_observatory_public_target(payload)
	route_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	route_label.add_theme_color_override("font_color", Color("#7fb8ca"))
	route_label.add_theme_font_size_override("font_size", 10)
	body.add_child(route_label)
	var progress := ProgressBar.new()
	progress.name = "AnimationProgress"
	progress.custom_minimum_size = Vector2(0.0, 6.0)
	progress.show_percentage = false
	progress.value = 0.0
	body.add_child(progress)
	_observatory_window_rail.add_child(panel)
	var record := {
		"receipt_id": receipt_id,
		"fingerprint": fingerprint,
		"event_kind": event_kind,
		"summary": summary,
		"animation_cue": animation_cue.duplicate(true),
		"panel": panel,
		"body": body,
		"select_button": select_button,
		"pin_button": pin_button,
		"expand_button": expand_button,
		"progress": progress,
		"expanded": true,
		"pinned": false,
		"animation_pending": true,
		"start_attempt_count": 0,
		"evidence": {},
	}
	_combat_observatory_windows[receipt_id] = record
	_combat_observatory_order.append(receipt_id)
	_combat_observatory_window_create_count += 1
	_apply_combat_observatory_window_style(receipt_id)
	return panel


func _evict_oldest_unpinned_combat_observatory_window() -> void:
	if _combat_observatory_windows.size() < COMBAT_OBSERVATORY_WINDOW_LIMIT:
		return
	var candidate_id := ""
	for receipt_id in _combat_observatory_order:
		var record := _combat_observatory_windows.get(receipt_id, {}) as Dictionary
		if not bool(record.get("pinned", false)):
			candidate_id = receipt_id
			break
	if candidate_id.is_empty():
		# All visible windows are explicitly pinned. Keep them and allow a bounded
		# visual overflow instead of dropping an authorized public receipt.
		_combat_observatory_overflow_count += 1
		return
	_remove_combat_observatory_window(candidate_id, true)
	_combat_observatory_window_evict_count += 1


func _remove_combat_observatory_window(
	receipt_id: String,
	emit_completion: bool
) -> void:
	if not _combat_observatory_windows.has(receipt_id):
		return
	var record := _combat_observatory_windows.get(receipt_id, {}) as Dictionary
	if _combat_observatory_tweens.has(receipt_id):
		var tween := _combat_observatory_tweens.get(receipt_id) as Tween
		if tween != null and tween.is_valid():
			tween.kill()
		_combat_observatory_tweens.erase(receipt_id)
	if emit_completion and bool(record.get("animation_pending", false)):
		_complete_combat_observatory_animation(receipt_id, "window_evicted")
		record = _combat_observatory_windows.get(receipt_id, {}) as Dictionary
	var panel := record.get("panel", null) as Control
	if panel != null and is_instance_valid(panel):
		panel.queue_free()
	_combat_observatory_windows.erase(receipt_id)
	_combat_observatory_order.erase(receipt_id)
	if _active_combat_observatory_receipt_id == receipt_id:
		_active_combat_observatory_receipt_id = (
			_combat_observatory_order.back()
			if not _combat_observatory_order.is_empty()
			else ""
		)
	_refresh_combat_observatory_header()


func _start_combat_observatory_animation(receipt_id: String) -> void:
	if not _combat_observatory_windows.has(receipt_id):
		return
	var record := _combat_observatory_windows.get(receipt_id, {}) as Dictionary
	if (
		not bool(record.get("animation_pending", false))
		or _combat_observatory_tweens.has(receipt_id)
	):
		return
	var panel := record.get("panel", null) as PanelContainer
	if panel == null or not is_instance_valid(panel):
		return
	var panel_rect := panel.get_global_rect()
	if not panel_rect.has_area():
		var attempts := int(record.get("start_attempt_count", 0)) + 1
		record["start_attempt_count"] = attempts
		_combat_observatory_windows[receipt_id] = record
		if attempts < 4:
			call_deferred("_start_combat_observatory_animation", receipt_id)
			return
	var animation_cue := record.get("animation_cue", {}) as Dictionary
	var source_info := _combat_observatory_anchor_info(
		animation_cue,
		"source_anchor",
		_presentation_strip,
		"presentation_strip"
	)
	var target_info := _combat_observatory_anchor_info(
		animation_cue,
		"target_anchor",
		panel,
		"observatory_window"
	)
	var source_rect := source_info.get("rect", Rect2()) as Rect2
	var target_rect := target_info.get("rect", Rect2()) as Rect2
	if not source_rect.has_area():
		source_rect = panel_rect
	if not target_rect.has_area():
		target_rect = panel_rect
	# The window itself is the only animation surface.  A separate root-level
	# animation node would overlap the established Rows tree and is therefore forbidden
	# by the responsive collision audit.  Keep the panel inside its HBox rail and
	# use a bounded scale/alpha pulse so three concurrent windows remain visible
	# without changing layout ownership or map topology.
	var base_scale := Vector2.ONE
	var start_scale := Vector2(0.82, 0.82)
	var midpoint_scale := Vector2(0.94, 0.94)
	if _presentation_reduced_motion:
		start_scale = Vector2(0.96, 0.96)
		midpoint_scale = Vector2(0.99, 0.99)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = start_scale
	panel.modulate = Color(
		1.0,
		1.0,
		1.0,
		0.78 if _presentation_reduced_motion else 0.56
	)
	var start_rect := _combat_observatory_control_rect(panel)
	if not start_rect.has_area():
		start_rect = panel_rect
	var duration_ms := clampi(
		int(animation_cue.get(
			"duration_ms",
			COMBAT_OBSERVATORY_DEFAULT_DURATION_MS
		)),
		COMBAT_OBSERVATORY_MINIMUM_DURATION_MS,
		COMBAT_OBSERVATORY_MAXIMUM_DURATION_MS
	)
	var evidence := {
		"schema": "V076CombatObservatoryRectEvidenceV1",
		"presentation_only": true,
		"public_only": true,
		"receipt_id": receipt_id,
		"cue_id": str(animation_cue.get(
			"cue_id",
			record.get("event_kind", "")
		)),
		"event_kind": str(record.get("event_kind", "")),
		"start_rect": start_rect,
		"mid_rect": Rect2(),
		"end_rect": Rect2(),
		"source_anchor_rect": source_rect,
		"target_anchor_rect": target_rect,
		"source_anchor_origin": str(source_info.get("origin", "missing")),
		"target_anchor_origin": str(target_info.get("origin", "missing")),
		"window_rect": start_rect,
		"duration_ms": duration_ms,
		"visual_motion_mode": "panel_scale_alpha",
		"motion_mode": (
			"REDUCED_MOTION"
			if _presentation_reduced_motion
			else "FULL_MOTION"
		),
		"effective_screen_shake_profile": (
			"none"
			if _presentation_reduced_motion
				or not _presentation_screen_shake_enabled
			else str(animation_cue.get(
				"effective_screen_shake_profile",
				"none"
			))
		),
		"completion_reason": "pending",
		"gameplay_mutation_count": 0,
		"rng_draw_delta": 0,
		"authority_sequence_delta": 0,
		"deck_order_mutation_count": 0,
		"card_zone_mutation_count": 0,
		"facility_state_mutation_count": 0,
	}
	record["evidence"] = evidence
	record["animation_pending"] = true
	_combat_observatory_windows[receipt_id] = record
	_combat_observatory_animation_start_count += 1
	var progress := record.get("progress", null) as ProgressBar
	if progress != null:
		progress.value = 0.0
	var duration := float(duration_ms) / 1000.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", midpoint_scale, duration * 0.48)
	tween.parallel().tween_property(panel, "modulate:a", 0.84, duration * 0.48)
	if progress != null:
		tween.parallel().tween_property(progress, "value", 52.0, duration * 0.48)
	tween.tween_callback(
		Callable(self, "_capture_combat_observatory_mid_rect").bind(receipt_id)
	)
	tween.tween_property(panel, "scale", base_scale, duration * 0.52)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, duration * 0.52)
	if progress != null:
		tween.parallel().tween_property(progress, "value", 100.0, duration * 0.52)
	tween.tween_callback(
		Callable(self, "_complete_combat_observatory_animation").bind(
			receipt_id,
			"tween_completed"
		)
	)
	_combat_observatory_tweens[receipt_id] = tween
	_refresh_combat_observatory_header()


func _capture_combat_observatory_mid_rect(receipt_id: String) -> void:
	if not _combat_observatory_windows.has(receipt_id):
		return
	var record := _combat_observatory_windows.get(receipt_id, {}) as Dictionary
	var panel := record.get("panel", null) as Control
	var evidence := record.get("evidence", {}) as Dictionary
	if panel != null and is_instance_valid(panel):
		evidence["mid_rect"] = _combat_observatory_control_rect(panel)
	record["evidence"] = evidence
	_combat_observatory_windows[receipt_id] = record


func _complete_combat_observatory_animation(
	receipt_id: String,
	completion_reason: String
) -> void:
	if _combat_observatory_finished_ids.has(receipt_id):
		_combat_observatory_finish_duplicate_count += 1
		return
	if not _combat_observatory_windows.has(receipt_id):
		return
	var record := _combat_observatory_windows.get(receipt_id, {}) as Dictionary
	var panel := record.get("panel", null) as PanelContainer
	var evidence := (record.get("evidence", {}) as Dictionary).duplicate(true)
	if panel != null and is_instance_valid(panel):
		# A completion callback may also be reached by bounded eviction.  Restore
		# the stable rail scale before recording the terminal screen-space Rect.
		panel.scale = Vector2.ONE
		panel.modulate = Color.WHITE
		var current_rect := _combat_observatory_control_rect(panel)
		if not (evidence.get("mid_rect", Rect2()) as Rect2).has_area():
			evidence["mid_rect"] = current_rect
		evidence["end_rect"] = current_rect
		evidence["window_rect"] = current_rect
	var progress := record.get("progress", null) as ProgressBar
	if progress != null and is_instance_valid(progress):
		progress.value = 100.0
	evidence["completion_reason"] = completion_reason
	evidence["completed_msec"] = Time.get_ticks_msec()
	var start_rect := evidence.get("start_rect", Rect2()) as Rect2
	var mid_rect := evidence.get("mid_rect", Rect2()) as Rect2
	var end_rect := evidence.get("end_rect", Rect2()) as Rect2
	var source_rect := evidence.get("source_anchor_rect", Rect2()) as Rect2
	var target_rect := evidence.get("target_anchor_rect", Rect2()) as Rect2
	var rects_complete := (
		start_rect.has_area()
		and mid_rect.has_area()
		and end_rect.has_area()
	)
	evidence["rects_complete"] = rects_complete
	evidence["source_anchor_present"] = source_rect.has_area()
	evidence["target_anchor_present"] = target_rect.has_area()
	if rects_complete:
		_combat_observatory_rect_evidence_count += 1
	if source_rect.has_area():
		_combat_observatory_source_anchor_count += 1
	if target_rect.has_area():
		_combat_observatory_target_anchor_count += 1
	if not source_rect.has_area() or not target_rect.has_area():
		_combat_observatory_missing_anchor_count += 1
	record["evidence"] = evidence
	record["animation_pending"] = false
	_combat_observatory_windows[receipt_id] = record
	_combat_observatory_tweens.erase(receipt_id)
	_combat_observatory_finished_ids[receipt_id] = str(record.get(
		"fingerprint",
		""
	))
	_combat_observatory_animation_finish_count += 1
	_combat_observatory_evidence.append(evidence.duplicate(true))
	while _combat_observatory_evidence.size() > COMBAT_OBSERVATORY_EVIDENCE_LIMIT:
		_combat_observatory_evidence.pop_front()
	_refresh_combat_observatory_header()
	combat_observatory_animation_finished.emit(
		receipt_id,
		evidence.duplicate(true)
	)


func _clear_combat_observatory_windows(
	emit_completion: bool,
	completion_reason: String
) -> void:
	for receipt_id in _combat_observatory_order.duplicate():
		_remove_combat_observatory_window(
			receipt_id,
			emit_completion
		)
	for tween_variant in _combat_observatory_tweens.values():
		var tween := tween_variant as Tween
		if tween != null and tween.is_valid():
			tween.kill()
	_combat_observatory_tweens.clear()
	_combat_observatory_windows.clear()
	_combat_observatory_order.clear()
	_active_combat_observatory_receipt_id = ""
	if is_instance_valid(_observatory_window_rail):
		for child in _observatory_window_rail.get_children().duplicate():
			if child != _observatory_empty_label:
				child.queue_free()
	if is_instance_valid(_observatory_empty_label):
		_observatory_empty_label.visible = true
	if is_instance_valid(_combat_observatory):
		_combat_observatory.visible = false
	# The reason is accepted to keep reset/eviction evidence call sites explicit.
	# Reset intentionally emits no finish receipt because the Screen clears its
	# Director queue at the same new-match boundary.
	if completion_reason.is_empty():
		return


func _combat_observatory_anchor_info(
	animation_cue: Dictionary,
	field_name: String,
	fallback_control: Control,
	fallback_origin: String
) -> Dictionary:
	var projection := animation_cue.get("projection", {}) as Dictionary
	var value: Variant = projection.get(
		field_name,
		animation_cue.get(field_name, null)
	)
	var rect := _combat_observatory_anchor_rect(value)
	if rect.has_area():
		return {
			"rect": rect,
			"origin": "director_projection.%s" % field_name,
		}
	if fallback_control != null and is_instance_valid(fallback_control):
		rect = fallback_control.get_global_rect()
		if rect.has_area():
			return {"rect": rect, "origin": fallback_origin}
	return {"rect": Rect2(), "origin": "missing"}


func _combat_observatory_anchor_rect(value: Variant) -> Rect2:
	if value is Rect2:
		return value as Rect2
	if value is Vector2:
		return Rect2((value as Vector2) - Vector2(4.0, 4.0), Vector2(8.0, 8.0))
	if value is Dictionary:
		var source := value as Dictionary
		for rect_field in ["global_rect", "rect", "control_rect"]:
			var rect_value: Variant = source.get(rect_field, null)
			if rect_value is Rect2:
				return rect_value as Rect2
		var position_value: Variant = source.get(
			"global_position",
			source.get("position", null)
		)
		var size_value: Variant = source.get("size", Vector2(8.0, 8.0))
		if position_value is Vector2 and size_value is Vector2:
			return Rect2(position_value as Vector2, size_value as Vector2)
	return Rect2()


func _combat_observatory_control_rect(control: Control) -> Rect2:
	if control == null or not is_instance_valid(control):
		return Rect2()
	# get_global_rect() is intentionally not used here: it can omit scale or
	# rotation on a Control.  The evidence contract needs the actual transformed
	# screen-space bounds for the animated panel at every phase.
	var transform := control.get_global_transform_with_canvas()
	var corners: Array[Vector2] = [
		transform * Vector2.ZERO,
		transform * Vector2(control.size.x, 0.0),
		transform * control.size,
		transform * Vector2(0.0, control.size.y),
	]
	var minimum := corners[0]
	var maximum := corners[0]
	for corner in corners:
		minimum = Vector2(
			minf(minimum.x, corner.x),
			minf(minimum.y, corner.y)
		)
		maximum = Vector2(
			maxf(maximum.x, corner.x),
			maxf(maximum.y, corner.y)
		)
	return Rect2(minimum, maximum - minimum)


func _combat_observatory_event_title(event_kind: String) -> String:
	return {
		"monster_deployed": "怪兽部署",
		"monster_refreshed": "怪兽恢复",
		"monster_upgraded": "怪兽升级",
		"monster_replaced": "怪兽替换",
		"monster_moved": "怪兽移动",
		"monster_trample_resolved": "怪兽践踏",
		"monster_basic_attack": "怪兽攻击",
		"monster_private_skill_resolved": "怪兽技能",
		"monster_damaged": "怪兽受击",
		"monster_downed": "怪兽倒地",
		"monster_destroyed": "怪兽摧毁",
		"monster_withdrawn": "怪兽撤回",
		"military_region_assault": "军队攻区",
		"military_monster_assault": "军队攻怪",
		"military_withdrawn": "军队撤离",
		"facility_combat_damaged": "设施受损",
		"armor_absorbed": "护甲吸收",
	}.get(event_kind, "公开战斗") as String


func _combat_observatory_public_target(payload: Dictionary) -> String:
	for field_name in [
		"target_region_id",
		"destination_region_id",
		"region_id",
		"target_monster_source_instance_id",
		"target_facility_id",
	]:
		var value := str(payload.get(field_name, "")).strip_edges()
		if not value.is_empty():
			return "公开目标 · %s" % value
	return "公开目标 · 战斗区"


func _apply_combat_observatory_window_style(receipt_id: String) -> void:
	if not _combat_observatory_windows.has(receipt_id):
		return
	var record := _combat_observatory_windows.get(receipt_id, {}) as Dictionary
	var panel := record.get("panel", null) as PanelContainer
	if panel == null or not is_instance_valid(panel):
		return
	var active := receipt_id == _active_combat_observatory_receipt_id
	var pinned := bool(record.get("pinned", false))
	var accent := _cue_color(str(record.get("event_kind", "")))
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color(0.07, 0.13, 0.17, 0.99)
		if active
		else Color(0.035, 0.065, 0.09, 0.98)
	)
	style.border_color = Color("#f0c76b") if pinned else accent
	style.set_border_width_all(2 if active or pinned else 1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)


func _ensure_combat_observatory_window_visible(receipt_id: String) -> void:
	if (
		not is_instance_valid(_observatory_scroll)
		or not _combat_observatory_windows.has(receipt_id)
	):
		return
	var record := _combat_observatory_windows.get(receipt_id, {}) as Dictionary
	var panel := record.get("panel", null) as Control
	if panel != null and is_instance_valid(panel):
		_observatory_scroll.ensure_control_visible(panel)


func _refresh_combat_observatory_header() -> void:
	if not is_instance_valid(_observatory_status):
		return
	var pinned_count := 0
	var expanded_count := 0
	var pending_count := 0
	for record_variant in _combat_observatory_windows.values():
		var record := record_variant as Dictionary
		pinned_count += int(bool(record.get("pinned", false)))
		expanded_count += int(bool(record.get("expanded", true)))
		pending_count += int(bool(record.get("animation_pending", false)))
	var window_count := _combat_observatory_windows.size()
	if not _combat_observatory_terminal_phase.is_empty():
		_observatory_status.text = "终局锁定 · %d 个只读窗口" % window_count
	elif window_count == 0:
		_observatory_status.text = "等待公开战斗回执"
	else:
		_observatory_status.text = "%d 个窗口 · %d 动画 · %d 固定 · %d 展开" % [
			window_count,
			pending_count,
			pinned_count,
			expanded_count,
		]
	_observatory_previous_button.disabled = window_count < 2
	_observatory_next_button.disabled = window_count < 2
	_observatory_empty_label.visible = window_count == 0
	_combat_observatory.visible = window_count > 0


func _combat_observatory_debug_windows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for receipt_id in _combat_observatory_order:
		var record := _combat_observatory_windows.get(receipt_id, {}) as Dictionary
		var panel := record.get("panel", null) as Control
		var evidence := record.get("evidence", {}) as Dictionary
		rows.append({
			"receipt_id": receipt_id,
			"event_kind": str(record.get("event_kind", "")),
			"expanded": bool(record.get("expanded", true)),
			"pinned": bool(record.get("pinned", false)),
			"active": receipt_id == _active_combat_observatory_receipt_id,
			"animation_pending": bool(record.get("animation_pending", false)),
			"window_rect": (
				panel.get_global_rect()
				if panel != null and is_instance_valid(panel)
				else Rect2()
			),
			"start_rect": evidence.get("start_rect", Rect2()),
			"mid_rect": evidence.get("mid_rect", Rect2()),
			"end_rect": evidence.get("end_rect", Rect2()),
			"source_anchor_rect": evidence.get("source_anchor_rect", Rect2()),
			"target_anchor_rect": evidence.get("target_anchor_rect", Rect2()),
			"rects_complete": bool(evidence.get("rects_complete", false)),
		})
	return rows


func debug_snapshot() -> Dictionary:
	var skill_debug := (
		_skill_dock.debug_snapshot()
		if is_instance_valid(_skill_dock)
		else {}
	)
	var military_debug := (
		_military_panel.debug_snapshot()
		if is_instance_valid(_military_panel)
		else {}
	)
	var pending_animation_count := 0
	var expanded_window_count := 0
	var collapsed_window_count := 0
	var pinned_window_count := 0
	for record_variant in _combat_observatory_windows.values():
		var record := record_variant as Dictionary
		pending_animation_count += int(bool(record.get(
			"animation_pending",
			false
		)))
		pinned_window_count += int(bool(record.get("pinned", false)))
		if bool(record.get("expanded", true)):
			expanded_window_count += 1
		else:
			collapsed_window_count += 1
	var combat_window_count := _combat_observatory_windows.size()
	return {
		"schema": "V075CombatPlayerSurfaceDebugV1",
		"layout_mode": _layout_mode,
		"private_grid_columns": (
			_private_grid.columns
			if is_instance_valid(_private_grid)
			else 0
		),
		"viewer_is_owner": _viewer_is_owner,
		"viewer_can_submit_military": _viewer_can_submit_military,
		"selected_source_instance_id": str(
			_selected_public_monster.get("source_instance_id", "")
		),
		"public_monster_visible": _public_panel.visible,
		"public_preferred_color_visible":
			not _preferred_label.text.is_empty(),
		"public_projected_path_visible":
			not _path_label.text.is_empty(),
		"public_unlocked_skill_count_visible":
			not _unlocked_label.text.is_empty(),
		"owner_skill_dock": skill_debug,
		"military_panel": military_debug,
		"public_skill_card_disclosure_count":
			_public_skill_disclosure_count(),
		"military_guard_ui_count": int(
			military_debug.get("guard_ui_count", 0)
		),
		"military_task_button_count": int(
			military_debug.get("task_button_count", 0)
		),
		"military_task_kinds": (
			military_debug.get("task_kinds", []) as Array
		).duplicate(),
		"military_option_identity_count": int(
			military_debug.get("option_identity_count", 0)
		),
		"military_bound_action_ui_count": int(
			military_debug.get("bound_action_ui_count", 0)
		),
		"special_support_placeholder_count": 0,
		"presentation_cue_identity_count":
			_presentation_cue_fingerprints.size(),
		"presentation_cue_applied_count":
			_presentation_cue_applied_count,
		"presentation_cue_duplicate_count":
			_presentation_cue_duplicate_count,
		"presentation_cue_collision_count":
			_presentation_cue_collision_count,
		"presentation_cue_rejected_count":
			_presentation_cue_rejected_count,
		"presentation_animation_count": _presentation_animation_count,
		"presentation_asset_key_visible": not _cue_asset_label.text.is_empty(),
		"presentation_event_kind_visible": not str(
			_last_cue.get("event_kind", "")
		).is_empty(),
		"last_presentation_cue_id": str(
			_last_cue.get("presentation_receipt_id", "")
		),
		"presentation_history_count": _presentation_history.size(),
		"presentation_history": _presentation_history.duplicate(),
		"combat_window_count": combat_window_count,
		"concurrent_combat_view_count": combat_window_count,
		"minimum_concurrent_combat_view_capacity": (
			COMBAT_OBSERVATORY_MINIMUM_CONCURRENT_VIEWS
		),
		"combat_window_capacity": COMBAT_OBSERVATORY_WINDOW_LIMIT,
		"combat_window_create_count": _combat_observatory_window_create_count,
		"combat_window_evict_count": _combat_observatory_window_evict_count,
		"combat_window_overflow_count": _combat_observatory_overflow_count,
		"combat_window_active_count": int(
			not _active_combat_observatory_receipt_id.is_empty()
		),
		"combat_window_pending_count": pending_animation_count,
		"combat_window_finished_count": (
			_combat_observatory_animation_finish_count
		),
		"combat_window_expanded_count": expanded_window_count,
		"combat_window_collapsed_count": collapsed_window_count,
		"combat_window_pinned_count": pinned_window_count,
		"combat_window_expand_action_count": _combat_observatory_expand_count,
		"combat_window_collapse_action_count": _combat_observatory_collapse_count,
		"combat_window_pin_action_count": _combat_observatory_pin_count,
		"combat_window_unpin_action_count": _combat_observatory_unpin_count,
		"combat_window_switch_count": _combat_observatory_switch_count,
		"active_combat_window_receipt_id": (
			_active_combat_observatory_receipt_id
		),
		"combat_window_duplicate_count": _combat_observatory_duplicate_count,
		"combat_window_collision_count": _combat_observatory_collision_count,
		"combat_window_privacy_rejection_count": (
			_combat_observatory_privacy_rejection_count
		),
		"combat_window_terminal_rejection_count": (
			_combat_observatory_terminal_rejection_count
		),
		"combat_window_identity_rejection_count": (
			_combat_observatory_identity_rejection_count
		),
		"combat_window_finish_duplicate_count": (
			_combat_observatory_finish_duplicate_count
		),
		"combat_window_animation_started_count": (
			_combat_observatory_animation_start_count
		),
		"combat_window_animation_finished_count": (
			_combat_observatory_animation_finish_count
		),
		"rect_evidence_count": _combat_observatory_rect_evidence_count,
		"source_anchor_evidence_count": _combat_observatory_source_anchor_count,
		"target_anchor_evidence_count": _combat_observatory_target_anchor_count,
		"missing_anchor_evidence_count": _combat_observatory_missing_anchor_count,
		"combat_window_privacy_violation_count": 0,
		"combat_window_exact_once_green": (
			_combat_observatory_collision_count == 0
			and _combat_observatory_animation_finish_count
				== _combat_observatory_finished_ids.size()
		),
		"combat_window_terminal_phase": _combat_observatory_terminal_phase,
		"combat_window_post_terminal_active_count": 0,
		"combat_window_instant_mode_rejection_count": (
			_combat_observatory_instant_mode_rejection_count
		),
		"combat_window_production_instant_mode_reachable": false,
		"presentation_motion_policy": (
			presentation_motion_policy_snapshot()
		),
		"combat_windows": _combat_observatory_debug_windows(),
		"combat_window_rect_evidence": (
			_combat_observatory_evidence.duplicate(true)
		),
		"presentation_gameplay_mutation_count": 0,
		"presentation_rng_draw_delta": 0,
		"presentation_authority_sequence_delta": 0,
		"presentation_deck_order_mutation_count": 0,
		"presentation_card_zone_mutation_count": 0,
		"presentation_facility_state_mutation_count": 0,
	}


func debug_geometry_audit() -> Dictionary:
	var audit := ResponsiveAcceptanceAudit.audit_control_tree(self)
	audit["schema"] = "V075CombatSurfaceGeometryAuditV2"
	audit["private_grid_columns"] = _private_grid.columns
	audit["layout_mode"] = _layout_mode
	audit["rows_combined_minimum_height"] = (
		_rows.get_combined_minimum_size().y
	)
	audit["preferred_content_height"] = preferred_content_height()
	audit["surface_custom_minimum_height"] = custom_minimum_size.y
	return audit


func _select_public_monster(
	monsters: Array,
	preferred_source_instance_id: String
) -> Dictionary:
	if not preferred_source_instance_id.is_empty():
		for source_variant in monsters:
			if (
				source_variant is Dictionary
				and str(
					(source_variant as Dictionary).get(
						"source_instance_id",
						""
					)
				) == preferred_source_instance_id
			):
				return (source_variant as Dictionary).duplicate(true)
	for source_variant in monsters:
		if source_variant is Dictionary:
			return (source_variant as Dictionary).duplicate(true)
	return {}


func _render_public_monster() -> void:
	if _selected_public_monster.is_empty():
		_render_empty()
		return
	_public_panel.visible = true
	var rank := clampi(
		int(_selected_public_monster.get("rank", 1)),
		1,
		4
	)
	var status := str(
		_selected_public_monster.get("status", "active")
	)
	var color_id := str(
		_selected_public_monster.get(
			"preferred_industry_color",
			""
		)
	)
	var hp := maxi(0, int(_selected_public_monster.get("hp", 0)))
	var max_hp := maxi(
		1,
		int(_selected_public_monster.get("max_hp", 1))
	)
	_name_label.text = str(
		_selected_public_monster.get("display_name", "未命名怪兽")
	)
	_rank_label.text = "L%d · %s" % [rank, RANK_LABELS[rank]]
	_status_label.text = _status_text(status)
	_status_label.add_theme_color_override(
		"font_color",
		_status_color(status)
	)
	_preferred_icon.texture = CATALOG.resource_for_asset_key(
		StringName("icon.asset.%s" % color_id)
	) as Texture2D
	_preferred_icon.modulate = COLOR_VALUES.get(color_id, Color.WHITE)
	_preferred_icon.set_meta(
		"stable_asset_key",
		"icon.asset.%s" % color_id
	)
	_preferred_label.text = "偏好 · %s" % str(
		COLOR_LABELS.get(color_id, color_id)
	)
	_hp_bar.max_value = max_hp
	_hp_bar.value = clampi(hp, 0, max_hp)
	_hp_label.text = "HP %d / %d" % [hp, max_hp]
	_armor_label.text = "护甲 %d" % maxi(
		0,
		int(_selected_public_monster.get("armor", 0))
	)
	_region_label.text = "当前 · %s" % str(
		_selected_public_monster.get("region_id", "未知地区")
	)
	var tracked_region := str(
		_selected_public_monster.get("tracked_region_id", "")
	)
	var tracked_facility := str(
		_selected_public_monster.get("tracked_facility_id", "")
	)
	_target_label.text = (
		"追踪 · %s%s"
		% [
			tracked_region if not tracked_region.is_empty() else "待机",
			" / %s" % tracked_facility
				if not tracked_facility.is_empty()
				else "",
		]
	)
	var path := (
		_selected_public_monster.get("projected_path", []) as Array
	)
	_path_label.text = (
		"路径 · %s" % "  >  ".join(_string_array(path))
		if not path.is_empty()
		else "路径 · 本批待机"
	)
	_unlocked_label.text = "已解锁 %d 招" % maxi(
		0,
		int(
			_selected_public_monster.get(
				"unlocked_skill_count",
				0
			)
		)
	)
	var batch_used := bool(
		_selected_public_monster.get(
			"batch_active_skill_used",
			false
		)
	)
	_batch_used_badge.text = (
		"本批已使用"
		if batch_used
		else "本批可用"
	)
	_batch_used_badge.add_theme_color_override(
		"font_color",
		Color("#efbf70") if batch_used else Color("#72dda7")
	)


func _render_private_surfaces() -> void:
	var viewer_id := str(_projection.get("viewer_player_id", ""))
	var source_id := str(
		_selected_public_monster.get("source_instance_id", "")
	)
	var owner_id := str(
		_selected_public_monster.get("owner_player_id", "")
	)
	_viewer_is_owner = (
		not viewer_id.is_empty()
		and viewer_id == owner_id
		and _positive_int_field(
			_selected_public_monster,
			"source_generation"
		)
	)
	var skill_source := {}
	if _viewer_is_owner:
		for source_variant in _projection.get(
			"own_monster_skill_sources",
			[]
		) as Array:
			if (
				source_variant is Dictionary
				and str(
					(source_variant as Dictionary).get(
						"source_instance_id",
						""
					)
				) == source_id
				and str(
					(source_variant as Dictionary).get(
						"owner_player_id",
						""
					)
				) == viewer_id
				and _positive_int_field(
					source_variant as Dictionary,
					"source_generation"
				)
				and (source_variant as Dictionary).get("source_generation")
					== _selected_public_monster.get("source_generation")
			):
				skill_source = (
					source_variant as Dictionary
				).duplicate(true)
				break
	_skill_dock.configure(
		skill_source,
		_viewer_is_owner and not skill_source.is_empty(),
		bool(_projection.get("combat_requests_allowed", false))
	)
	var military_options: Array = []
	for option_variant in _projection.get(
		"military_task_options",
		[]
	) as Array:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		if str(option.get("owner_player_id", "")) != viewer_id:
			continue
		if str(option.get("action_domain", "military")) != "military":
			continue
		military_options.append(option.duplicate(true))
	_viewer_can_submit_military = not military_options.is_empty()
	_military_panel.configure(military_options, _viewer_can_submit_military)


func _render_empty() -> void:
	_public_panel.visible = false
	_viewer_is_owner = false
	_viewer_can_submit_military = false
	_skill_dock.clear_private_data()
	_military_panel.configure([], false)


func _resolve_layout() -> void:
	if not is_instance_valid(_private_grid):
		return
	var width := size.x
	var available_width := maxf(0.0, width - 20.0)
	var required_two_column_width := maxf(
		PRIVATE_TWO_COLUMN_MIN_CONTENT_WIDTH,
		_skill_dock.get_combined_minimum_size().x
		+ _military_panel.get_combined_minimum_size().x
		+ float(_private_grid.get_theme_constant("h_separation"))
	)
	var two_column := available_width >= required_two_column_width
	_layout_mode = "WIDE" if two_column else "COMPACT"
	var private_columns := 2 if two_column else 1
	# The three public-fact groups are a row at normal widths and a readable
	# vertical stack at the 480px acceptance viewport. No child is clipped.
	var info_columns := 1 if available_width < 520.0 else 3
	var column_count_changed := (
		_private_grid.columns != private_columns
		or _info_grid.columns != info_columns
	)
	_private_grid.columns = private_columns
	_info_grid.columns = info_columns
	if column_count_changed:
		_private_grid.queue_sort()
		_info_grid.queue_sort()
		_rows.queue_sort()
	_schedule_layout_settle()


func _schedule_layout_settle() -> void:
	if _layout_settle_scheduled:
		return
	_layout_settle_scheduled = true
	# GridContainer publishes its new combined minimum after the queued sort.
	# The outer production ScrollContainer must consume that settled value,
	# otherwise a one-column layout can be clipped at the previous height.
	call_deferred("_prepare_settled_layout_minimum")


func _prepare_settled_layout_minimum() -> void:
	_private_grid.update_minimum_size()
	_info_grid.update_minimum_size()
	_rows.update_minimum_size()
	_private_grid.queue_sort()
	_info_grid.queue_sort()
	_rows.queue_sort()
	call_deferred("_publish_settled_layout_minimum")


func _publish_settled_layout_minimum() -> void:
	_layout_settle_scheduled = false
	var resolved_height := preferred_content_height()
	if (
		_last_resolved_preferred_height >= 0.0
		and absf(resolved_height - _last_resolved_preferred_height)
			<= LAYOUT_EPSILON
	):
		return
	_last_resolved_preferred_height = resolved_height
	responsive_minimum_resolved.emit(resolved_height)


func _apply_styles() -> void:
	var public_style := StyleBoxFlat.new()
	public_style.bg_color = Color(0.035, 0.055, 0.09, 0.97)
	public_style.border_color = Color(0.26, 0.5, 0.66, 0.75)
	public_style.set_border_width_all(1)
	public_style.set_corner_radius_all(6)
	public_style.content_margin_left = 12.0
	public_style.content_margin_top = 10.0
	public_style.content_margin_right = 12.0
	public_style.content_margin_bottom = 10.0
	_public_panel.add_theme_stylebox_override("panel", public_style)
	_public_panel.set_meta("stable_asset_key", "ui.panel.primary")
	var strip_style := StyleBoxFlat.new()
	strip_style.bg_color = Color(0.07, 0.11, 0.14, 0.96)
	strip_style.border_color = Color(0.3, 0.73, 0.7, 0.65)
	strip_style.set_border_width_all(1)
	strip_style.set_corner_radius_all(4)
	strip_style.content_margin_left = 9.0
	strip_style.content_margin_top = 5.0
	strip_style.content_margin_right = 9.0
	strip_style.content_margin_bottom = 5.0
	_presentation_strip.add_theme_stylebox_override(
		"panel",
		strip_style
	)
	_presentation_strip.set_meta(
		"stable_asset_key",
		"ui.panel.popup"
	)
	var observatory_style := StyleBoxFlat.new()
	observatory_style.bg_color = Color(0.025, 0.05, 0.075, 0.985)
	observatory_style.border_color = Color(0.28, 0.69, 0.68, 0.72)
	observatory_style.set_border_width_all(1)
	observatory_style.set_corner_radius_all(6)
	_combat_observatory.add_theme_stylebox_override(
		"panel",
		observatory_style
	)
	_combat_observatory.set_meta(
		"stable_asset_key",
		"ui.panel.combat_observatory"
	)


func _status_text(status: String) -> String:
	return {
		"active": "活动",
		"downed": "倒地",
		"destroyed": "已摧毁",
		"withdrawn": "已撤回",
		"hungry": "饥饿追踪",
	}.get(status, status)


func _status_color(status: String) -> Color:
	return {
		"active": Color("#72dda7"),
		"hungry": Color("#efbf70"),
		"downed": Color("#e38a73"),
		"destroyed": Color("#bd6570"),
		"withdrawn": Color("#8896a7"),
	}.get(status, Color("#b7c4d2"))


func _cue_summary(
	event_kind: String,
	payload: Dictionary
) -> String:
	match event_kind:
		"monster_deployed":
			return "怪兽已部署"
		"monster_refreshed":
			return "同族怪兽恢复 %d%% 最大生命" % int(
				payload.get("refresh_percent", 0)
			)
		"monster_upgraded":
			return "怪兽升级至 L%d" % int(
				payload.get("new_rank", payload.get("source_rank", 1))
			)
		"monster_replaced":
			return "旧怪兽撤回 · 新怪兽已部署"
		"monster_moved":
			return "怪兽沿公开路径移动"
		"monster_trample_resolved":
			return "践踏 %s · %d 伤害" % [
				str(payload.get("region_id", "")),
				int(payload.get(
					"region_damage_budget",
					payload.get("damage_amount", 0)
				)),
			]
		"monster_basic_attack":
			return "基础攻击 · %d 伤害" % int(
				payload.get("damage_amount", 0)
			)
		"monster_private_skill_resolved":
			return "怪兽释放技能 · 公开效果已结算"
		"monster_skill_cooldown_started":
			return "怪兽技能进入冷却"
		"monster_skill_ready":
			return "怪兽技能冷却完成"
		"monster_damaged":
			return "怪兽受到 %d 伤害" % int(
				payload.get("damage_amount", 0)
			)
		"monster_downed":
			return "怪兽倒地"
		"monster_destroyed":
			return "怪兽被摧毁"
		"monster_withdrawn":
			return "怪兽已撤回"
		"military_region_assault":
			return "军队完成地区攻击"
		"military_monster_assault":
			return "军队完成怪兽攻击"
		"military_withdrawn":
			return "军队任务完成 · 已撤离并弃置"
		"facility_combat_damaged":
			return "%s设施受损" % str(
				payload.get("facility_type", "")
			)
		"armor_absorbed":
			return "护甲吸收伤害"
	return ""


func _first_cue_texture(asset_keys: Array) -> Texture2D:
	for key_variant in asset_keys:
		var resource := CATALOG.resource_for_asset_key(
			StringName(str(key_variant))
		)
		if resource is Texture2D:
			return resource as Texture2D
	var fallback := CATALOG.resource_for_asset_key(&"icon.board.target")
	return fallback as Texture2D if fallback is Texture2D else null


func _presentation_asset_caption(asset_keys: Array) -> String:
	if asset_keys.is_empty():
		return "效果"
	var captions: Array[String] = []
	for key_variant in asset_keys.slice(0, mini(2, asset_keys.size())):
		var key := str(key_variant)
		var suffix := key.rsplit(".", true, 1)[-1]
		captions.append(suffix.replace("_", " "))
	return " · ".join(captions)


func _cue_color(event_kind: String) -> Color:
	if event_kind.begins_with("military_"):
		return Color("#ef9a74")
	if event_kind == "facility_combat_damaged":
		return Color("#e4bd69")
	if event_kind == "monster_trample_resolved":
		return Color("#d9a36b")
	if event_kind == "monster_private_skill_resolved":
		return Color("#ba9bff")
	return Color("#74d9c6")


func _public_skill_disclosure_count() -> int:
	var count := 0
	for source_variant in _projection.get(
		"public_monsters",
		[]
	) as Array:
		count += _count_private_skill_keys(source_variant)
	return count


func _count_private_skill_keys(value: Variant) -> int:
	var count := 0
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			var key := str(key_variant).to_lower()
			if (
				"skill_definition" in key
				or "asset_cost" in key
				or "cooldown" in key
				or "skill_card" in key
				or "future_skill" in key
				or "request_sequence" in key
				or "internal_order" in key
				or "private_target" in key
			):
				count += 1
			count += _count_private_skill_keys(
				dictionary.get(key_variant)
			)
	elif value is Array:
		for child_variant in value as Array:
			count += _count_private_skill_keys(child_variant)
	return count


func _presentation_cue_result(
	applied: bool,
	reason_code: String
) -> Dictionary:
	return {
		"applied": applied,
		"reason_code": reason_code,
		"applied_cue_count": _presentation_cue_applied_count,
		"duplicate_cue_count": _presentation_cue_duplicate_count,
		"collision_cue_count": _presentation_cue_collision_count,
		"rejected_cue_count": _presentation_cue_rejected_count,
		"combat_window_count": _combat_observatory_windows.size(),
		"concurrent_combat_view_count": _combat_observatory_windows.size(),
		"combat_window_duplicate_count": _combat_observatory_duplicate_count,
		"combat_window_collision_count": _combat_observatory_collision_count,
		"combat_window_privacy_rejection_count": (
			_combat_observatory_privacy_rejection_count
		),
		"combat_window_terminal_rejection_count": (
			_combat_observatory_terminal_rejection_count
		),
	}


func _canonical_cue_json(value: Variant) -> String:
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
					_canonical_cue_json(dictionary.get(key)),
				]
			)
		return "{%s}" % ",".join(fields)
	if value is Array:
		var items: Array[String] = []
		for item in value as Array:
			items.append(_canonical_cue_json(item))
		return "[%s]" % ",".join(items)
	return JSON.stringify(value)


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


func _on_private_target_selection_requested(request: Dictionary) -> void:
	var canonical_request := _current_private_skill_request(request)
	if canonical_request.is_empty():
		return
	private_target_selection_requested.emit(canonical_request)


func _on_military_mission_selected(option: Dictionary) -> void:
	if (
		not _viewer_can_submit_military
		or option.is_empty()
		or str(option.get("owner_player_id", "")) != str(
			_projection.get("viewer_player_id", "")
		)
		or not CapabilityCatalog.is_military_mission_kind(option.get("task_kind"))
	):
		return
	var canonical_option := _current_military_option(option)
	if canonical_option.is_empty():
		return
	military_mission_selected.emit(canonical_option)


func _current_private_skill_request(candidate: Dictionary) -> Dictionary:
	if not _viewer_is_owner or candidate.is_empty():
		return {}
	var viewer_id := str(_projection.get("viewer_player_id", ""))
	var source_id := str(_selected_public_monster.get(
		"source_instance_id",
		""
	))
	var source_generation := int(_selected_public_monster.get(
		"source_generation",
		0
	))
	var skill_id := str(candidate.get("skill_definition_id", ""))
	if (
		viewer_id.is_empty()
		or source_id.is_empty()
		or not _positive_int_field(
			_selected_public_monster,
			"source_generation"
		)
		or str(candidate.get("source_instance_id", "")) != source_id
		or not _positive_int_field(candidate, "source_generation")
		or candidate.get("source_generation")
			!= _selected_public_monster.get("source_generation")
		or skill_id.is_empty()
	):
		return {}
	for source_variant in _projection.get(
		"own_monster_skill_sources",
		[]
	) as Array:
		if not (source_variant is Dictionary):
			continue
		var source := source_variant as Dictionary
		if (
			str(source.get("source_instance_id", "")) != source_id
			or str(source.get("owner_player_id", "")) != viewer_id
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
			var candidate_binding := candidate.get("target_binding", {}) as Dictionary
			var expected_contract := skill.get("target_contract", {}) as Dictionary
			var candidate_contract := candidate.get("target_contract", {}) as Dictionary
			if (
				expected_binding.is_empty()
				or not _same_flat_dictionary(
					candidate_binding,
					expected_binding
				)
				or not _same_flat_dictionary(
					candidate_contract,
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
	var viewer_id := str(_projection.get("viewer_player_id", ""))
	if (
		viewer_id.is_empty()
		or str(candidate.get("owner_player_id", "")) != viewer_id
		or str(candidate.get("action_domain", "")) != "military"
		or not _card_action_binding_valid(candidate, viewer_id)
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
	for option_variant in _projection.get("military_task_options", []) as Array:
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
