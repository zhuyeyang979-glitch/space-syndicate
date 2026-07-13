extends PanelContainer
class_name SpaceSyndicateDistrictSupplyStatusChip

@onready var label: Label = %DistrictSupplyStatusChipLabel

var _snapshot: Dictionary = {}


func _ready() -> void:
	set_chip({})


func set_chip(data: Dictionary) -> void:
	_snapshot = data.duplicate(true)
	var accent := _variant_color(data.get("accent", "#94a3b8"), Color("#94a3b8"))
	var active := bool(data.get("active", true))
	var foreground := _variant_color(data.get("fg", ""), accent.lightened(0.12) if active else Color("#94a3b8"))
	var background := _variant_color(data.get("bg", ""), Color("#020617").lerp(accent, 0.24 if active else 0.10))
	label.text = str(data.get("text", ""))
	label.add_theme_color_override("font_color", foreground)
	tooltip_text = str(data.get("tooltip", data.get("tip", "")))
	add_theme_stylebox_override("panel", _chip_style(accent if active else Color("#475569"), background))


func debug_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func _variant_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value as Color
	if value is String and str(value).begins_with("#"):
		return Color(str(value))
	return fallback


func _chip_style(accent: Color, fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style
