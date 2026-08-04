extends CanvasLayer
class_name V073PlaytestCoachMarks
# MCP_FINALIZE

signal coach_mark_shown(mark_id: String)
signal coach_mark_skipped(mark_id: String, skip_all: bool)

const MARKS := [
	{"id": "normal_hand_limit", "anchor": "dock", "text": "普通手牌上限为 5。"},
	{"id": "separate_inventories", "anchor": "dock", "text": "商品与特殊行动牌不占普通手牌上限。"},
	{"id": "six_color_zero", "anchor": "assets", "text": "六色资产从 0 / 6 开始。"},
	{"id": "starter_free", "anchor": "hand", "text": "Starter 免费，先用它建立设施。"},
	{"id": "paid_l1", "anchor": "track", "text": "普通 L1 需要 1 点对应颜色资产。"},
	{"id": "unified_track", "anchor": "track", "text": "统一轨同时提供普通牌与商品牌。"},
	{"id": "prebound_target", "anchor": "targets", "text": "出牌前先选定地区目标。"},
	{"id": "lock_freezes", "anchor": "lock", "text": "锁定后，目标与预留资产不会再变化。"},
	{"id": "local_order", "anchor": "queue", "text": "你可以调整自己行动的先后顺序。"},
	{"id": "hidden_round_robin", "anchor": "phase", "text": "结算按固定的隐藏轮转顺序进行。"},
	{"id": "facility_contention", "anchor": "history", "text": "较晚占用同一设施槽的行动可能 Fizzle。"},
	{"id": "fizzle_cost", "anchor": "history", "text": "Fizzle 会释放资产，但卡牌进弃牌且不返还行动槽。"},
	{"id": "solar_only", "anchor": "targets", "text": "日照只改变设施效率，不改变统一轨供应。"},
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
	var mark := MARKS[_index] as Dictionary
	var anchor := _anchors.get(str(mark.get("anchor", ""))) as Control
	var viewport_size := _root.get_viewport_rect().size
	var callout_size := _callout.size
	var target := Vector2(24.0, 96.0)
	if anchor != null and is_instance_valid(anchor):
		var rect := anchor.get_global_rect()
		target = Vector2(
			rect.position.x + rect.size.x * 0.5 - callout_size.x * 0.5,
			rect.position.y - callout_size.y - 10.0
		)
		if target.y < 64.0:
			target.y = rect.end.y + 10.0
	target.x = clampf(target.x, 12.0, maxf(12.0, viewport_size.x - callout_size.x - 12.0))
	target.y = clampf(target.y, 64.0, maxf(64.0, viewport_size.y - callout_size.y - 12.0))
	_callout.position = target
