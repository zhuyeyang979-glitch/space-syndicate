@tool
extends PanelContainer
class_name RoleSeatFallback

@onready var player_name_label: Label = %PublicPlayerName
@onready var role_name_label: Label = %PublicRoleName
@onready var status_label: Label = %PublicStatus


func _ready() -> void:
	_set_mouse_filter_recursive(self)


func set_seat_descriptor(descriptor: Dictionary) -> void:
	var accent: Color = descriptor.get("player_color", Color.WHITE) as Color
	player_name_label.text = str(descriptor.get("public_player_name", "玩家"))
	role_name_label.text = str(descriptor.get("role_name", "外星辛迪加"))
	status_label.text = _status_text(StringName(descriptor.get("public_status", &"waiting")))
	tooltip_text = "%s｜%s｜%s" % [player_name_label.text, role_name_label.text, status_label.text]
	add_theme_stylebox_override("panel", _panel_style(accent, bool(descriptor.get("is_local_player", false)), bool(descriptor.get("is_publicly_active", false))))
	player_name_label.add_theme_color_override("font_color", accent.lightened(0.24))
	status_label.add_theme_color_override("font_color", accent if bool(descriptor.get("is_publicly_active", false)) else Color("#94a3b8"))
	scale = Vector2.ONE * clampf(float(descriptor.get("visual_scale", 1.0)), 0.70, 1.20)
	pivot_offset = Vector2(size.x * 0.5, size.y)


func _status_text(status: StringName) -> String:
	match status:
		&"ready":
			return "已就绪"
		&"active":
			return "公开行动"
		&"eliminated":
			return "已离场"
		&"disconnected":
			return "暂离"
	return "等待"


func _panel_style(accent: Color, is_local: bool, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.18 if active else 0.09)
	style.bg_color.a = 0.90 if is_local else 0.78
	style.border_color = accent if is_local or active else Color("#334155")
	style.set_border_width_all(2 if is_local else 1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = 5
	return style


func _set_mouse_filter_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_filter_recursive(child)
