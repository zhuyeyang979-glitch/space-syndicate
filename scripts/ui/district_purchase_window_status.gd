@tool
extends PanelContainer
class_name DistrictPurchaseWindowStatus

@onready var mode_label: Label = %DistrictPurchaseWindowModeLabel
@onready var timer_label: Label = %DistrictPurchaseWindowTimerLabel
@onready var timer_bar: ProgressBar = %DistrictPurchaseWindowTimerBar
@onready var detail_label: Label = %DistrictPurchaseWindowDetailLabel

const QUOTE_LIFETIME_US := 5_000_000

var _snapshot: Dictionary = {}


func _ready() -> void:
	if not Engine.is_editor_hint():
		set_snapshot({})


func set_snapshot(data: Dictionary) -> void:
	_snapshot = _sanitize_snapshot(data)
	if _snapshot.is_empty():
		visible = false
		return
	visible = true
	var state := str(_snapshot.get("state", "view_only"))
	var quote: Dictionary = _snapshot.get("quote", {}) if _snapshot.get("quote", {}) is Dictionary else {}
	var remaining_world_us := clampi(int(quote.get("remaining_world_us", 0)), 0, QUOTE_LIFETIME_US)
	var quote_active := not bool(_snapshot.get("requires_reselection", false)) and not quote.is_empty() and bool(quote.get("quote_active", false)) and remaining_world_us > 0
	var accent := _accent_for_quote(state, quote, quote_active, remaining_world_us)
	mode_label.text = _mode_text(_snapshot, quote, quote_active)
	timer_label.text = _timer_text(_snapshot, quote, quote_active, remaining_world_us)
	timer_bar.value = (float(remaining_world_us) / float(QUOTE_LIFETIME_US)) * 100.0 if quote_active else 0.0
	detail_label.text = _detail_text(_snapshot, quote, quote_active)
	mode_label.add_theme_color_override("font_color", accent.lightened(0.12))
	timer_label.add_theme_color_override("font_color", accent)
	_set_styles(accent)


func debug_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func _sanitize_snapshot(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	var snapshot := {
		"state": str(data.get("state", "view_only")),
		"active": bool(data.get("active", false)),
		"requires_reselection": bool(data.get("requires_reselection", false)),
	}
	var source_quote: Dictionary = data.get("quote", {}) if data.get("quote", {}) is Dictionary else {}
	if not source_quote.is_empty():
		var quote: Dictionary = {}
		for key in ["quote_id", "quote_active", "locked_eligible", "eligible", "confirmable", "viewable", "availability_kind", "remaining_world_us", "final_price", "multiplier_q2", "same_region_alive_count", "directly_adjacent_alive_count"]:
			if source_quote.has(key):
				quote[key] = source_quote[key]
		snapshot["quote"] = quote
	return snapshot


func _mode_text(data: Dictionary, quote: Dictionary, quote_active: bool) -> String:
	var state := str(data.get("state", "view_only"))
	if bool(data.get("requires_reselection", false)):
		return "供应已变化"
	if quote.is_empty():
		return "等待选择报价"
	if not quote_active:
		return "报价已过期"
	if state == "pending_discard":
		return "等待私密弃牌"
	match str(quote.get("availability_kind", "invalid")):
		"sunlit": return "日照报价已锁定"
		"dark": return "暗面资格已锁定"
		"destroyed": return "来源区域已摧毁"
	return "报价暂不可用"


func _timer_text(data: Dictionary, quote: Dictionary, quote_active: bool, remaining_world_us: int) -> String:
	if bool(data.get("requires_reselection", false)):
		return "需重新选择"
	if quote_active:
		return "%.1f 秒" % (float(remaining_world_us) / 1_000_000.0)
	return "未启动" if quote.is_empty() else "已过期"


func _detail_text(data: Dictionary, quote: Dictionary, quote_active: bool) -> String:
	if bool(data.get("requires_reselection", false)):
		return "牌架供应已变化；重新选择挂牌以生成新的5秒报价。"
	if quote.is_empty():
		return "先选牌生成报价；悬停和界面刷新不会启动5秒锁定。"
	if not quote_active:
		return "报价已过期；重新选择挂牌以锁定新的日照资格和价格。"
	var final_price := maxi(0, int(quote.get("final_price", 0)))
	var multiplier := float(maxi(0, int(quote.get("multiplier_q2", 2)))) / 2.0
	match str(quote.get("availability_kind", "invalid")):
		"sunlit":
			return "日照可买｜最终价 ¥%d｜怪兽压力 ×%.1f｜资格与价格锁定至倒计时结束" % [final_price, multiplier]
		"dark":
			return "暗面仅可查看｜参考价 ¥%d｜怪兽压力 ×%.1f｜暗面资格锁定至倒计时结束" % [final_price, multiplier]
		"destroyed":
			return "来源区域已摧毁｜仅可查看｜参考价 ¥%d" % final_price
	return "当前挂牌不可确认；重新选择以获取最新公开报价。"


func _accent_for_quote(state: String, quote: Dictionary, quote_active: bool, remaining_world_us: int) -> Color:
	if bool(_snapshot.get("requires_reselection", false)):
		return Color("#fbbf24")
	if quote.is_empty():
		return Color("#94a3b8")
	if not quote_active:
		return Color("#f87171")
	if remaining_world_us <= 1_250_000:
		return Color("#fb7185")
	if state == "pending_discard":
		return Color("#fbbf24")
	if str(quote.get("availability_kind", "invalid")) == "sunlit":
		return Color("#4ade80")
	return Color("#93c5fd")


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
