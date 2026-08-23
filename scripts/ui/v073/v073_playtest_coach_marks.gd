extends CanvasLayer
class_name V073PlaytestCoachMarks
# MCP_FINALIZE

signal coach_mark_shown(mark_id: String)
signal coach_mark_skipped(mark_id: String, skip_all: bool)

const SAFE_MARGIN := 12.0
const HEADER_SAFE_TOP := 64.0
const CALLOUT_GAP := 10.0
const MARKS := [
	{"id": "normal_hand_limit", "anchor": "dock", "text": "普通手牌上限为 5。"},
	{"id": "separate_inventories", "anchor": "dock", "text": "商品与特殊行动牌不占普通手牌上限。"},
	{"id": "six_color_zero", "anchor": "assets", "text": "六色资产从 0 / 6 开始。"},
	{"id": "starter_free", "anchor": "hand", "text": "Starter 免费，先用它建立设施。"},
	{"id": "paid_l1", "anchor": "track", "text": "普通 L1 需要 1 点对应颜色资产。"},
	{"id": "unified_track", "anchor": "track", "text": "统一轨同时提供普通牌与商品牌。"},
	{"id": "prebound_target", "anchor": "planet", "text": "点击星球地区绑定目标；下方列表是键盘备用入口。"},
	{"id": "lock_freezes", "anchor": "lock", "text": "锁定后，目标与预留资产不会再变化。"},
	{"id": "local_order", "anchor": "queue", "text": "你可以调整自己行动的先后顺序。"},
	{"id": "hidden_round_robin", "anchor": "phase", "text": "结算按固定的隐藏轮转顺序进行。"},
	{"id": "facility_contention", "anchor": "history", "text": "较晚占用同一设施槽的行动可能 Fizzle。"},
	{"id": "fizzle_cost", "anchor": "history", "text": "Fizzle 会释放资产，但卡牌进弃牌且不返还行动槽。"},
	{"id": "solar_only", "anchor": "planet", "text": "日照只改变设施效率，不改变统一轨供应。"},
	{"id": "save_disabled", "anchor": "save", "text": "本样品暂不支持中途保存或继续。"},
]

@onready var _root: Control = %CoachRoot
@onready var _callout: PanelContainer = %CoachCallout
@onready var _step_label: Label = %CoachStep
@onready var _body_label: Label = %CoachBody
@onready var _next_button: Button = %CoachNext
@onready var _skip_button: Button = %CoachSkipAll
@onready var _close_button: Button = %CoachClose

var _anchors: Dictionary = {}
var _index := -1
var _active := false
var _completed := false
var _suspended := false
var _placement_direction := "none"
var _offscreen_count := 0
var _target_occlusion_count := 0
var _primary_input_block_count := 0
var _map_center_occlusion_count := 0
var _placement_signature := ""
var _last_viewport_size := Vector2.ZERO
var _last_callout_position := Vector2.ZERO
var _position_recompute_count := 0
var _pointer_entry_recompute_count := 0
var _step3_pointer_entry_position_delta_px := 0.0
var _step3_next_click_advance_count := 0
var _step3_duplicate_advance_count := 0
var _step3_mouse_event_loss_count := 0
var _pointer_motion_count := 0
var _step3_pointer_motion_count := 0
var _step3_panel_move_on_pointer_count := 0
var _missing_target_count := 0
var _target_available := false
var _last_advance_frame := -1


func _ready() -> void:
	_next_button.pressed.connect(_on_next_pressed)
	_skip_button.pressed.connect(_skip_all)
	_close_button.pressed.connect(_close)
	_root.visible = false
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	set_process_unhandled_key_input(true)
	set_process_input(true)
	set_process(true)


func bind_anchors(anchors: Dictionary) -> void:
	_anchors = anchors.duplicate()
	_invalidate_placement()


func apply_public_context(context: Dictionary) -> void:
	_suspended = bool(context.get("modal_visible", false))
	_refresh_visibility()


func restart_from_settings() -> void:
	_completed = false
	_active = true
	_index = 0
	_show_current()


func set_modal_suspended(suspended: bool) -> void:
	_suspended = suspended
	_refresh_visibility()


func mark_count() -> int:
	return MARKS.size()


func debug_snapshot() -> Dictionary:
	var contributes_layout := (
		_active
		and not _suspended
		and _root != null
		and is_instance_valid(_root)
		and _root.visible
	)
	return {
		"mark_count": MARKS.size(),
		"active": _active,
		"completed": _completed,
		"current_index": _index,
		"placement_direction": _placement_direction,
		"offscreen_count": _offscreen_count if contributes_layout else 0,
		"target_occlusion_count": _target_occlusion_count if contributes_layout else 0,
		"primary_input_block_count": _primary_input_block_count if contributes_layout else 0,
		"map_center_occlusion_count": _map_center_occlusion_count if contributes_layout else 0,
		"position_recompute_count": _position_recompute_count,
		"pointer_entry_recompute_count": _pointer_entry_recompute_count,
		"step3_pointer_entry_position_delta_px": (
			_step3_pointer_entry_position_delta_px
		),
		"step3_next_button_visible": _next_button.is_visible_in_tree(),
		"step3_next_button_enabled": not _next_button.disabled,
		"step3_next_click_advance_count": _step3_next_click_advance_count,
		"step3_duplicate_advance_count": _step3_duplicate_advance_count,
		"step3_mouse_event_loss_count": _step3_mouse_event_loss_count,
		"pointer_motion_count": _pointer_motion_count,
		"step3_pointer_motion_count": _step3_pointer_motion_count,
		"step3_panel_move_on_pointer_count": (
			_step3_panel_move_on_pointer_count
		),
		"missing_target_count": _missing_target_count,
		"target_available": _target_available,
		"suspended": _suspended,
		"callout_position": _callout.position,
		"gameplay_value_change_count": 0,
		"hidden_info_disclosure_count": 0,
	}


func _process(_delta: float) -> void:
	if not _root.visible:
		return
	var available := _current_anchor_available()
	if _target_available and not available:
		_position_callout("target_disappeared")
		return
	_target_available = available
	var safe_rect := _safe_rect()
	var current_rect := Rect2(
		_callout.position,
		_callout.get_combined_minimum_size().max(_callout.size)
	)
	if not safe_rect.encloses(current_rect):
		_position_callout("safe_zone")


func _input(event: InputEvent) -> void:
	if not _active or _suspended or not _root.visible:
		return
	if event is InputEventMouseMotion:
		_pointer_motion_count += 1
		if _index == 2:
			_step3_pointer_motion_count += 1


func _unhandled_key_input(event: InputEvent) -> void:
	if not _active or _suspended or not _root.visible:
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.is_pressed() or key_event.is_echo():
		return
	if key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_advance()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func _on_next_pressed() -> void:
	if _index == 2:
		_step3_next_click_advance_count += 1
	_advance()


func _advance() -> void:
	if not _active:
		return
	var frame := Engine.get_process_frames()
	if frame == _last_advance_frame:
		if _index == 2:
			_step3_duplicate_advance_count += 1
		return
	_last_advance_frame = frame
	if _index >= MARKS.size() - 1:
		_active = false
		_completed = true
		_root.visible = false
		return
	_index += 1
	_show_current()


func _skip_all() -> void:
	if not _active:
		return
	var mark_id := str((MARKS[_index] as Dictionary).get("id", "unknown"))
	coach_mark_skipped.emit(mark_id, true)
	_active = false
	_completed = true
	_root.visible = false


func _close() -> void:
	if not _active:
		return
	var mark_id := str((MARKS[_index] as Dictionary).get("id", "unknown"))
	coach_mark_skipped.emit(mark_id, false)
	_active = false
	_root.visible = false


func _show_current() -> void:
	if _index < 0 or _index >= MARKS.size():
		return
	var mark := MARKS[_index] as Dictionary
	_step_label.text = "%d / %d" % [_index + 1, MARKS.size()]
	_body_label.text = str(mark.get("text", ""))
	_target_available = _current_anchor_available()
	_next_button.text = "完成" if _index == MARKS.size() - 1 else "下一条"
	_refresh_visibility()
	_invalidate_placement()
	call_deferred("_position_callout", "step")
	_next_button.grab_focus()
	coach_mark_shown.emit(str(mark.get("id", "unknown")))


func _refresh_visibility() -> void:
	_root.visible = _active and not _suspended


func _position_callout(_reason := "geometry") -> void:
	if _index < 0 or _index >= MARKS.size():
		return
	var mark := MARKS[_index] as Dictionary
	var anchor := _anchors.get(str(mark.get("anchor", ""))) as Control
	if (
		anchor == null
		or not is_instance_valid(anchor)
		or not anchor.is_visible_in_tree()
	):
		_target_available = false
		_missing_target_count += 1
		var fallback_safe := _safe_rect()
		var fallback_size := _callout.get_combined_minimum_size().max(
			_callout.size
		)
		_callout.position = Vector2(
			maxf(fallback_safe.position.x, fallback_safe.end.x - fallback_size.x),
			fallback_safe.position.y
		)
		_placement_direction = "safe_top_right_missing_target"
		_body_label.text = "%s\n目标暂不可用，可跳过或关闭。" % str(
			mark.get("text", "")
		)
		_placement_signature = _placement_geometry_signature()
		return
	_target_available = true
	_body_label.text = str(mark.get("text", ""))
	var viewport_size := _root.get_viewport_rect().size
	var callout_size := _callout.get_combined_minimum_size().max(
		Vector2(320.0, 110.0)
	)
	_callout.size = callout_size
	var safe_rect := _safe_rect()
	var anchor_rect := anchor.get_global_rect()
	var candidates := _placement_candidates(anchor_rect, callout_size)
	var best_rect := _clamp_to_safe(candidates[0].get("rect", Rect2()), safe_rect)
	var best_direction := str(candidates[0].get("direction", "top"))
	var best_score := INF
	for candidate_variant in candidates:
		var candidate := candidate_variant as Dictionary
		var candidate_rect := _clamp_to_safe(candidate.get("rect", Rect2()) as Rect2, safe_rect)
		var score := _placement_score(candidate_rect, anchor_rect)
		if score < best_score:
			best_score = score
			best_rect = candidate_rect
			best_direction = str(candidate.get("direction", "top"))
	var previous_position := _callout.position
	_callout.position = best_rect.position
	_last_callout_position = _callout.position
	_position_recompute_count += 1
	if _index == 2 and _reason == "pointer_entry":
		_pointer_entry_recompute_count += 1
		_step3_pointer_entry_position_delta_px = maxf(
			_step3_pointer_entry_position_delta_px,
			previous_position.distance_to(_callout.position)
		)
	_placement_direction = best_direction
	_offscreen_count = 0 if safe_rect.encloses(best_rect) else 1
	_target_occlusion_count = 1 if best_rect.intersects(anchor_rect) else 0
	_primary_input_block_count = 0
	var map_center := _map_center_rect()
	_map_center_occlusion_count = 1 if map_center.has_area() and best_rect.intersects(map_center) else 0
	_last_viewport_size = viewport_size
	_placement_signature = _placement_geometry_signature()


func _invalidate_placement() -> void:
	_placement_signature = ""


func _on_viewport_size_changed() -> void:
	_invalidate_placement()
	call_deferred("_position_callout", "viewport")


func _safe_rect() -> Rect2:
	var viewport_size := _root.get_viewport_rect().size
	return Rect2(
		Vector2(SAFE_MARGIN, HEADER_SAFE_TOP),
		Vector2(
			maxf(1.0, viewport_size.x - SAFE_MARGIN * 2.0),
			maxf(1.0, viewport_size.y - HEADER_SAFE_TOP - SAFE_MARGIN)
		)
	)


func _current_anchor_available() -> bool:
	if _index < 0 or _index >= MARKS.size():
		return false
	var mark := MARKS[_index] as Dictionary
	var anchor := _anchors.get(str(mark.get("anchor", ""))) as Control
	return anchor != null and is_instance_valid(anchor) and anchor.is_visible_in_tree()


func _placement_geometry_signature() -> String:
	if _index < 0 or _index >= MARKS.size():
		return "inactive"
	var mark := MARKS[_index] as Dictionary
	var anchor := _anchors.get(str(mark.get("anchor", ""))) as Control
	var anchor_rect := Rect2()
	var anchor_valid := anchor != null and is_instance_valid(anchor)
	if anchor_valid:
		anchor_rect = anchor.get_global_rect()
	var viewport_size := _root.get_viewport_rect().size
	var callout_size := _callout.get_combined_minimum_size().max(
		Vector2(320.0, 110.0)
	)
	return "%d|%s|%.2f,%.2f|%.2f,%.2f,%.2f,%.2f|%.2f,%.2f" % [
		_index,
		str(anchor_valid),
		viewport_size.x,
		viewport_size.y,
		anchor_rect.position.x,
		anchor_rect.position.y,
		anchor_rect.size.x,
		anchor_rect.size.y,
		callout_size.x,
		callout_size.y,
	]


func _placement_candidates(anchor_rect: Rect2, callout_size: Vector2) -> Array:
	var top_y := anchor_rect.position.y - callout_size.y - CALLOUT_GAP
	var lifted_top_y := top_y - callout_size.y * 0.58
	var bottom_y := anchor_rect.end.y + CALLOUT_GAP
	return [
		{"direction": "top", "rect": Rect2(Vector2(anchor_rect.position.x, lifted_top_y), callout_size)},
		{"direction": "top", "rect": Rect2(Vector2(anchor_rect.get_center().x - callout_size.x * 0.5, lifted_top_y), callout_size)},
		{"direction": "top", "rect": Rect2(Vector2(anchor_rect.end.x - callout_size.x, lifted_top_y), callout_size)},
		{"direction": "top", "rect": Rect2(Vector2(anchor_rect.position.x, top_y), callout_size)},
		{"direction": "top", "rect": Rect2(Vector2(anchor_rect.get_center().x - callout_size.x * 0.5, top_y), callout_size)},
		{"direction": "top", "rect": Rect2(Vector2(anchor_rect.end.x - callout_size.x, top_y), callout_size)},
		{"direction": "bottom", "rect": Rect2(Vector2(anchor_rect.position.x, bottom_y), callout_size)},
		{"direction": "bottom", "rect": Rect2(Vector2(anchor_rect.get_center().x - callout_size.x * 0.5, bottom_y), callout_size)},
		{"direction": "bottom", "rect": Rect2(Vector2(anchor_rect.end.x - callout_size.x, bottom_y), callout_size)},
		{"direction": "left", "rect": Rect2(Vector2(anchor_rect.position.x - callout_size.x - CALLOUT_GAP, anchor_rect.get_center().y - callout_size.y * 0.5), callout_size)},
		{"direction": "right", "rect": Rect2(Vector2(anchor_rect.end.x + CALLOUT_GAP, anchor_rect.get_center().y - callout_size.y * 0.5), callout_size)},
	]


func _clamp_to_safe(rect: Rect2, safe_rect: Rect2) -> Rect2:
	var position := Vector2(
		clampf(rect.position.x, safe_rect.position.x, maxf(safe_rect.position.x, safe_rect.end.x - rect.size.x)),
		clampf(rect.position.y, safe_rect.position.y, maxf(safe_rect.position.y, safe_rect.end.y - rect.size.y))
	)
	return Rect2(position, rect.size)


func _placement_score(candidate: Rect2, anchor_rect: Rect2) -> float:
	var score := _intersection_area(candidate, anchor_rect) * 1000.0
	var map_center := _map_center_rect()
	if map_center.has_area():
		score += _intersection_area(candidate, map_center) * 80.0
	var target_panel := _anchors.get("target_panel") as Control
	if target_panel != null and is_instance_valid(target_panel):
		score += _intersection_area(
			candidate,
			target_panel.get_global_rect()
		) * 1200.0
	var marker := _anchors.get("marker") as Control
	if marker != null and is_instance_valid(marker) and marker.visible:
		score += _intersection_area(candidate, marker.get_global_rect()) * 120.0
	for key in ["track", "hand", "lock", "roster"]:
		var control := _anchors.get(key) as Control
		if control != null and is_instance_valid(control) and control != _anchors.get(str((MARKS[_index] as Dictionary).get("anchor", ""))):
			var weight := 320.0 if key == "roster" else (1200.0 if key == "target_panel" else 4.0)
			score += _intersection_area(candidate, control.get_global_rect()) * weight
	return score


func _map_center_rect() -> Rect2:
	var planet := _anchors.get("planet") as Control
	if planet == null or not is_instance_valid(planet):
		return Rect2()
	var rect := planet.get_global_rect()
	var inset := Vector2(rect.size.x * 0.24, rect.size.y * 0.22)
	return Rect2(rect.position + inset, (rect.size - inset * 2.0).max(Vector2.ZERO))


func _intersection_area(left: Rect2, right: Rect2) -> float:
	if not left.intersects(right):
		return 0.0
	var overlap := left.intersection(right)
	return overlap.size.x * overlap.size.y
