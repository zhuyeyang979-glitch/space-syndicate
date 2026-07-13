@tool
extends PanelContainer
class_name DistrictPurchaseWindowStatus

@onready var mode_label: Label = %DistrictPurchaseWindowModeLabel
@onready var timer_label: Label = %DistrictPurchaseWindowTimerLabel
@onready var timer_bar: ProgressBar = %DistrictPurchaseWindowTimerBar
@onready var detail_label: Label = %DistrictPurchaseWindowDetailLabel

var _snapshot: Dictionary = {}


func _ready() -> void:
	if not Engine.is_editor_hint():
		set_snapshot({})


func set_snapshot(data: Dictionary) -> void:
	_snapshot = data.duplicate(true)
	if data.is_empty():
		visible = false
		return
	visible = true
	var state := str(data.get("state", "view_only"))
	var raw_remaining := maxf(0.0, float(data.get("remaining_seconds", 0.0)))
	var duration := maxf(0.001, float(data.get("duration_seconds", maxf(raw_remaining, 1.0))))
	var remaining := clampf(raw_remaining, 0.0, duration)
	var accent := _accent_for_state(state, remaining, duration)
	mode_label.text = _mode_text(state)
	timer_label.text = _timer_text(state, remaining)
	timer_bar.value = (remaining / duration) * 100.0 if bool(data.get("active", false)) else 0.0
	detail_label.text = _detail_text(data)
	mode_label.add_theme_color_override("font_color", accent.lightened(0.12))
	timer_label.add_theme_color_override("font_color", accent)
	_set_styles(accent)


func debug_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func _mode_text(state: String) -> String:
	match state:
		"active": return "购买资格已锁定"
		"suspended": return "购买计时已暂停"
		"pending_discard": return "等待私密弃牌"
		"expired": return "购买资格已超时"
		"closed": return "购买资格已关闭"
	return "只读牌架"


func _timer_text(state: String, remaining: float) -> String:
	if ["active", "suspended", "pending_discard"].has(state):
		return "%.1f 秒" % remaining
	return "无活动计时"


func _detail_text(data: Dictionary) -> String:
	var state := str(data.get("state", "view_only"))
	if state == "view_only":
		return "可以查看卡牌；当前区域没有可锁定的购买渠道。"
	if state == "expired":
		return "继续查看牌架；重新打开当前区域可再次检查购买资格。"
	if state == "closed":
		return "购买资格已失效；切换区域或重新打开牌架可重新判定。"
	var access_text := _access_text(str(data.get("access_kind", "none")))
	var channel_text := "｜渠道优惠" if bool(data.get("channel_discount_applied", false)) else ""
	var reselection_text := "｜牌架已变化，请重新选牌" if bool(data.get("requires_reselection", false)) else ""
	return "%s%s｜锁定倍率 ×%.2f%s" % [access_text, channel_text, float(data.get("locked_price_multiplier", 1.0)), reselection_text]


func _access_text(access_kind: String) -> String:
	match access_kind:
		"landed": return "怪兽落地区"
		"adjacent": return "怪兽相邻区"
		"extended": return "远程补给区"
		"global": return "全局采购区"
	return "不可购买"


func _accent_for_state(state: String, remaining: float, duration: float) -> Color:
	if state == "active" and remaining <= minf(3.0, duration * 0.25):
		return Color("#fb7185")
	if state == "active":
		return Color("#4ade80")
	if state in ["suspended", "pending_discard"]:
		return Color("#fbbf24")
	if state in ["expired", "closed"]:
		return Color("#f87171")
	return Color("#94a3b8")


func _set_styles(accent: Color) -> void:
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10)))
	timer_bar.add_theme_stylebox_override("background", _card_style(Color("#334155"), Color("#020617")))
	timer_bar.add_theme_stylebox_override("fill", _card_style(accent, Color("#020617").lerp(accent, 0.72), 0))


func _card_style(accent: Color, fill: Color, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	return style
