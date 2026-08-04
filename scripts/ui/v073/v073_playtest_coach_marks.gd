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


func _ready() -> void:
	_next_button.pressed.connect(_advance)
	_skip_button.pressed.connect(_skip_all)
	_root.visible = false
	set_process(true)


func bind_anchors(anchors: Dictionary) -> void:
	_anchors = anchors.duplicate()


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
	return {
		"mark_count": MARKS.size(),
		"active": _active,
		"completed": _completed,
		"current_index": _index,
		"placement_direction": _placement_direction,
		"offscreen_count": _offscreen_count,
		"target_occlusion_count": _target_occlusion_count,
		"primary_input_block_count": _primary_input_block_count,
		"map_center_occlusion_count": _map_center_occlusion_count,
		"gameplay_value_change_count": 0,
		"hidden_info_disclosure_count": 0,
	}


func _process(_delta: float) -> void:
	if _root.visible:
		_position_callout()


func _advance() -> void:
	if not _active:
		return
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


func _show_current() -> void:
	if _index < 0 or _index >= MARKS.size():
		return
	var mark := MARKS[_index] as Dictionary
	_step_label.text = "%d / %d" % [_index + 1, MARKS.size()]
	_body_label.text = str(mark.get("text", ""))
	_next_button.text = "完成" if _index == MARKS.size() - 1 else "下一条"
	_refresh_visibility()
	coach_mark_shown.emit(str(mark.get("id", "unknown")))


func _refresh_visibility() -> void:
	_root.visible = _active and not _suspended


func _position_callout() -> void:
	if _index < 0 or _index >= MARKS.size():
		return
	var mark := MARKS[_index] as Dictionary
	var anchor := _anchors.get(str(mark.get("anchor", ""))) as Control
	if anchor == null or not is_instance_valid(anchor):
		return
	var viewport_size := _root.get_viewport_rect().size
	var callout_size := _callout.get_combined_minimum_size().max(_callout.size)
	var safe_rect := Rect2(
		Vector2(SAFE_MARGIN, HEADER_SAFE_TOP),
		Vector2(
			maxf(1.0, viewport_size.x - SAFE_MARGIN * 2.0),
			maxf(1.0, viewport_size.y - HEADER_SAFE_TOP - SAFE_MARGIN)
		)
	)
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
	_callout.position = best_rect.position
	_placement_direction = best_direction
	_offscreen_count = 0 if safe_rect.encloses(best_rect) else 1
	_target_occlusion_count = 1 if best_rect.intersects(anchor_rect) else 0
	_primary_input_block_count = 1 if best_rect.has_point(_root.get_viewport().get_mouse_position()) else 0
	var map_center := _map_center_rect()
	_map_center_occlusion_count = 1 if map_center.has_area() and best_rect.intersects(map_center) else 0


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
	var pointer_rect := Rect2(_root.get_viewport().get_mouse_position() - Vector2(22.0, 22.0), Vector2(44.0, 44.0))
	score += _intersection_area(candidate, pointer_rect) * 200.0
	var map_center := _map_center_rect()
	if map_center.has_area():
		score += _intersection_area(candidate, map_center) * 80.0
	var marker := _anchors.get("marker") as Control
	if marker != null and is_instance_valid(marker) and marker.visible:
		score += _intersection_area(candidate, marker.get_global_rect()) * 120.0
	for key in ["track", "hand", "lock", "target_panel", "roster"]:
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