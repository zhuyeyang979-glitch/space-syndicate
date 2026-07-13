@tool
extends PanelContainer
class_name SpaceSyndicatePlanetMapScaleHint

@onready var mode_label: Label = %ScaleHintModeLabel
@onready var detail_label: Label = %ScaleHintDetailLabel

var _payload := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("mcp_sceneized_component", "PlanetMapScaleHint")
	_apply_panel_style()
	_apply_labels()


func configure(data: Dictionary) -> void:
	_payload = data.duplicate(true)
	name = "PlanetMapScaleHint"
	visible = true
	_apply_labels()


func debug_snapshot() -> Dictionary:
	return {
		"kind": "scale_hint",
		"sceneized": true,
		"mode": str(_payload.get("mode", "globe")),
		"sceneized_visual_cutover_enabled": bool(_payload.get("sceneized_visual_cutover_enabled", false)),
		"legacy_draw_fallback_used": bool(_payload.get("legacy_draw_fallback_used", false)),
	}


func _apply_labels() -> void:
	if mode_label != null:
		mode_label.text = str(_payload.get("scale_hint_text", _fallback_mode_text()))
	if detail_label != null:
		detail_label.text = str(_payload.get("scale_hint_detail", _fallback_detail_text()))


func _fallback_mode_text() -> String:
	var mode := str(_payload.get("mode", "globe"))
	var globe_blend := float(_payload.get("globe_blend", 1.0))
	if mode == "local" or globe_blend <= 0.001:
		return "局部地表 | 双击看牌架"
	if mode == "transition" or globe_blend < 0.985:
		return "过渡中 | 地表卷成星球"
	return "星球全景 | 滚轮贴近"


func _fallback_detail_text() -> String:
	if bool(_payload.get("legacy_draw_fallback_used", false)):
		return "legacy fallback active"
	if bool(_payload.get("sceneized_visual_cutover_enabled", false)):
		return "sceneized render"
	return "sceneized render disabled"


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617", 0.76)
	style.border_color = Color("#38bdf8", 0.28)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_top = 6
	style.content_margin_right = 10
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
