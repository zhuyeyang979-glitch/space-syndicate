extends PanelContainer
class_name V074AssetPipGroup

const Presenter := preload(
	"res://scripts/ui/v074/v074_asset_pip_presenter.gd"
)
const PIP_SIZE := Vector2(12.0, 12.0)

var _model: Dictionary = {}
var _color_id := ""
var _display_name := ""
var _rendered_projected_refresh_pip_count := 0


func configure(
	color_id: String,
	display_name: String,
	symbol_texture: Texture2D,
	lock_texture: Texture2D,
	accent_color: Color,
	model: Dictionary
) -> void:
	_clear_children()
	_color_id = color_id
	_display_name = display_name
	_model = model.duplicate(true)
	name = "AssetPips_%s" % color_id
	var refresh_count := int(model.get("projected_refresh", 0))
	var pip_strip_width := (
		PIP_SIZE.x * Presenter.PIP_SLOT_COUNT
		+ float(Presenter.PIP_SLOT_COUNT - 1)
	)
	_rendered_projected_refresh_pip_count = 0
	custom_minimum_size = Vector2(
		6.0 + 16.0 + 2.0 + pip_strip_width,
		20.0
	)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_HELP
	var details := Presenter.tooltip_text(display_name, model)
	tooltip_text = details
	set_meta("accessibility_label", details)
	set_meta("asset_color_id", color_id)
	set_meta("asset_pip_model", model.duplicate(true))
	var group_style := StyleBoxFlat.new()
	group_style.bg_color = Color(0.04, 0.07, 0.12, 0.76)
	group_style.border_color = Color(
		accent_color.r,
		accent_color.g,
		accent_color.b,
		0.52
	)
	group_style.set_border_width_all(1)
	group_style.set_corner_radius_all(4)
	group_style.content_margin_left = 3.0
	group_style.content_margin_top = 2.0
	group_style.content_margin_right = 3.0
	group_style.content_margin_bottom = 2.0
	add_theme_stylebox_override("panel", group_style)

	var row := HBoxContainer.new()
	row.name = "PipRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_theme_constant_override("separation", 2)
	add_child(row)

	var identity_icon := TextureRect.new()
	identity_icon.name = "IdentityIcon"
	identity_icon.custom_minimum_size = Vector2(16.0, 16.0)
	identity_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	identity_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	identity_icon.texture = symbol_texture
	identity_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(identity_icon)

	var pips := HBoxContainer.new()
	pips.name = "SixPips"
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pips.add_theme_constant_override("separation", 1)
	row.add_child(pips)
	var pip_states := model.get("pip_states", []) as Array
	var available_count := int(model.get("available", 0))
	for pip_index in range(pip_states.size()):
		var projected_refresh := (
			pip_index >= available_count
			and pip_index < available_count + refresh_count
		)
		if projected_refresh:
			_rendered_projected_refresh_pip_count += 1
		pips.add_child(_build_pip(
			str(pip_states[pip_index]),
			projected_refresh,
			symbol_texture,
			lock_texture,
			accent_color
		))


func debug_snapshot() -> Dictionary:
	return {
		"schema": "V074AssetPipGroupDebugV1",
		"color_id": _color_id,
		"display_name": _display_name,
		"pip_slot_count": (
			_model.get("pip_states", []) as Array
		).size(),
		"available_count": int(_model.get("available", 0)),
		"reserved_count": int(_model.get("reserved", 0)),
		"empty_count": int(_model.get("empty", 0)),
		"projected_refresh_count": int(
			_model.get("projected_refresh", 0)
		),
		"rendered_projected_refresh_pip_count": (
			_rendered_projected_refresh_pip_count
		),
		"focus_enabled": focus_mode == Control.FOCUS_ALL,
		"accessibility_label_present": not str(
			get_meta("accessibility_label", "")
		).is_empty(),
		"rendered_width": size.x,
		"minimum_width": get_combined_minimum_size().x,
		"trailing_blank_width": maxf(
			0.0,
			size.x - get_combined_minimum_size().x
		),
	}


func _build_pip(
	state: String,
	projected_refresh: bool,
	symbol_texture: Texture2D,
	lock_texture: Texture2D,
	accent_color: Color
) -> Control:
	var pip := Control.new()
	pip.name = "Pip_%s%s" % [
		state,
		"_projected_refresh" if projected_refresh else "",
	]
	pip.custom_minimum_size = PIP_SIZE
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.set_meta("projected_refresh_preview", projected_refresh)

	var background := Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	match state:
		Presenter.PIP_AVAILABLE:
			style.bg_color = Color(
				accent_color.r,
				accent_color.g,
				accent_color.b,
				0.32
			)
			style.border_color = accent_color
		Presenter.PIP_RESERVED:
			style.bg_color = Color(
				accent_color.r,
				accent_color.g,
				accent_color.b,
				0.18
			)
			style.border_color = Color("#f4cd66")
		_:
			style.bg_color = Color(0.05, 0.08, 0.13, 0.72)
			style.border_color = Color(
				accent_color.r,
				accent_color.g,
				accent_color.b,
				0.24
			)
	if projected_refresh:
		style.border_color = Color(0.46, 0.95, 0.86, 0.92)
		style.border_width_bottom = 2
	background.add_theme_stylebox_override("panel", style)
	pip.add_child(background)

	var symbol := TextureRect.new()
	symbol.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	symbol.offset_left = 2.0
	symbol.offset_top = 2.0
	symbol.offset_right = -2.0
	symbol.offset_bottom = -2.0
	symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	symbol.texture = symbol_texture
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if state == Presenter.PIP_RESERVED:
		symbol.modulate = Color(1.0, 1.0, 1.0, 0.62)
	elif state == Presenter.PIP_EMPTY:
		symbol.modulate = Color(1.0, 1.0, 1.0, 0.12)
	if projected_refresh:
		symbol.modulate = Color(
			1.0,
			1.0,
			1.0,
			0.72 if state == Presenter.PIP_RESERVED else 0.38
		)
	pip.add_child(symbol)

	if state == Presenter.PIP_RESERVED:
		var lock := TextureRect.new()
		lock.name = "ReservationLock"
		lock.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		lock.offset_left = -7.0
		lock.offset_top = -7.0
		lock.offset_right = 0.0
		lock.offset_bottom = 0.0
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.texture = lock_texture
		lock.modulate = Color("#ffe49a")
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.add_child(lock)
	return pip


func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
