extends PanelContainer
class_name V073SampleCardButton

signal activated(payload: Dictionary)
signal drag_started(payload: Dictionary)
signal hover_summary(payload: Dictionary)

var _payload: Dictionary = {}
var _selected := false
var _accent := Color("#42d6c6")
var _art: TextureRect
var _badge: Label
var _title: Label
var _meta: Label
var _normal_style: StyleBoxFlat
var _hover_tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(112, 106)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_build_content()
	_apply_style()


func configure(
	payload: Dictionary,
	title_text: String,
	meta_text: String,
	art_texture: Texture2D,
	accent_color: Color,
	badge_text: String = ""
) -> void:
	_payload = payload.duplicate(true)
	_accent = accent_color
	_title.text = title_text
	_meta.text = meta_text
	_badge.text = badge_text
	_badge.visible = not badge_text.is_empty()
	_art.texture = art_texture
	tooltip_text = "%s
%s" % [title_text, meta_text]
	_apply_style()


func set_selected(value: bool) -> void:
	_selected = value
	_apply_style()


func payload() -> Dictionary:
	return _payload.duplicate(true)


func _build_content() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	margin.add_child(rows)
	var art_frame := PanelContainer.new()
	art_frame.custom_minimum_size = Vector2(0, 48)
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = Color("#121a2b")
	art_style.corner_radius_top_left = 4
	art_style.corner_radius_top_right = 4
	art_style.corner_radius_bottom_left = 4
	art_style.corner_radius_bottom_right = 4
	art_frame.add_theme_stylebox_override("panel", art_style)
	rows.add_child(art_frame)
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.add_child(_art)
	_badge = Label.new()
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.add_theme_font_size_override("font_size", 9)
	_badge.add_theme_color_override("font_color", Color("#f9d56e"))
	rows.add_child(_badge)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.add_theme_font_size_override("font_size", 11)
	rows.add_child(_title)
	_meta = Label.new()
	_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_meta.add_theme_font_size_override("font_size", 9)
	_meta.add_theme_color_override("font_color", Color("#aab9cf"))
	rows.add_child(_meta)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			accept_event()
			activated.emit(_payload.duplicate(true))


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _payload.is_empty():
		return null
	var preview := Label.new()
	preview.text = _title.text
	preview.custom_minimum_size = Vector2(132, 44)
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color("#18253b")
	preview_style.border_color = _accent
	preview_style.set_border_width_all(2)
	preview_style.set_corner_radius_all(4)
	preview.add_theme_stylebox_override("normal", preview_style)
	set_drag_preview(preview)
	drag_started.emit(_payload.duplicate(true))
	return {
		"drag_type": "v073_card",
		"payload": _payload.duplicate(true),
	}


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5
	elif what == NOTIFICATION_MOUSE_ENTER:
		z_index = 20
		hover_summary.emit(_payload.duplicate(true))
		_animate_scale(Vector2(1.06, 1.06))
	elif what == NOTIFICATION_MOUSE_EXIT:
		z_index = 0
		_animate_scale(Vector2.ONE)


func _animate_scale(target: Vector2) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_QUAD)
	_hover_tween.set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", target, 0.12)


func _apply_style() -> void:
	_normal_style = StyleBoxFlat.new()
	_normal_style.bg_color = Color("#172033")
	_normal_style.border_color = Color("#f5cd61") if _selected else _accent
	_normal_style.set_border_width_all(3 if _selected else 1)
	_normal_style.set_corner_radius_all(6)
	_normal_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	_normal_style.shadow_size = 5
	add_theme_stylebox_override("panel", _normal_style)
