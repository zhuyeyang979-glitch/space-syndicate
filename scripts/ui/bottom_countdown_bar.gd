extends Control
class_name SpaceSyndicateBottomCountdownBar

@onready var panel: PanelContainer = %BottomCountdownPanel
@onready var timer_label: Label = %CardResolutionRevealTimerLabel
@onready var timer_bar: ProgressBar = %CardResolutionRevealTimerBar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_state({"visible": false})


func set_state(data: Dictionary) -> void:
	if not bool(data.get("visible", false)):
		visible = false
		return
	var accent := Color("#fde68a")
	if data.get("accent", null) is Color:
		accent = data.get("accent", accent) as Color
	var remaining := maxf(0.0, float(data.get("remaining", 0.0)))
	var total := maxf(0.001, float(data.get("total", 1.0)))
	var ratio := clampf(float(data.get("ratio", remaining / total)), 0.0, 1.0)
	visible = true
	timer_label.text = str(data.get("label", "牌桌计时"))
	timer_label.add_theme_color_override("font_color", accent.lightened(0.16))
	timer_label.tooltip_text = str(data.get("label_tooltip", "Current timed table window."))
	timer_bar.value = ratio * 100.0
	timer_bar.tooltip_text = str(data.get("bar_tooltip", "Shorter bar means this table window is closer to ending."))
	_set_styles(accent)


func _set_styles(accent: Color) -> void:
	panel.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.16), 1, 12))
	timer_bar.add_theme_stylebox_override("background", _card_style(Color("#334155"), Color("#020617"), 1, 6))
	timer_bar.add_theme_stylebox_override("fill", _card_style(accent, Color("#020617").lerp(accent, 0.72), 0, 6))


func _card_style(accent: Color, fill: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
