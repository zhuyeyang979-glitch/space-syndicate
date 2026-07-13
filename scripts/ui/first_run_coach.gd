extends PanelContainer
class_name SpaceSyndicateFirstRunCoach

signal primary_action_requested(action_id: String)

@onready var expanded_panel: Control = %CoachExpanded
@onready var collapsed_panel: Control = %CoachCollapsed
@onready var phase_label: Label = %CoachPhaseLabel
@onready var progress_label: Label = %CoachProgressLabel
@onready var title_label: Label = %CoachTitle
@onready var body_label: Label = %CoachBody
@onready var chip_row: HFlowContainer = %CoachChipRow
@onready var primary_button: Button = %CoachPrimaryButton
@onready var collapsed_label: Label = %CoachCollapsedLabel

var _current_action_id := ""
var _current_accent := Color("#38bdf8")


func _ready() -> void:
	add_theme_stylebox_override("panel", _coach_panel_style(Color("#38bdf8"), false))
	_ensure_primary_button_connected()


func set_coach(data: Dictionary) -> void:
	var should_show := bool(data.get("visible", not data.is_empty()))
	visible = should_show
	if not should_show:
		return
	var collapsed := bool(data.get("collapsed", false))
	_current_accent = data.get("primary_action", {}).get("accent", _stage_color(str(data.get("stage", "")))) if data.get("primary_action", {}) is Dictionary else _stage_color(str(data.get("stage", "")))
	add_theme_stylebox_override("panel", _coach_panel_style(_current_accent, collapsed))
	tooltip_text = str(data.get("tooltip", data.get("body", "")))
	custom_minimum_size = Vector2(220, 32 if collapsed else 98)
	if expanded_panel != null:
		expanded_panel.visible = not collapsed
	if collapsed_panel != null:
		collapsed_panel.visible = collapsed
	if collapsed:
		if collapsed_label != null:
			collapsed_label.text = "首局引导完成｜需要时从菜单重新打开"
			collapsed_label.tooltip_text = tooltip_text
		_current_action_id = ""
		return
	if phase_label != null:
		phase_label.text = str(data.get("phase_label", "首局"))
		phase_label.add_theme_color_override("font_color", _current_accent.lightened(0.18))
	if progress_label != null:
		progress_label.text = str(data.get("progress_text", "0/8"))
	if title_label != null:
		title_label.text = _short_text(str(data.get("title", "下一步")), 14)
	if body_label != null:
		body_label.text = _short_text(str(data.get("body", "")), 24)
		body_label.tooltip_text = tooltip_text
	_render_chips(data.get("chips", []))
	var action: Dictionary = data.get("primary_action", {}) if data.get("primary_action", {}) is Dictionary else {}
	_current_action_id = str(action.get("id", "")).strip_edges()
	if primary_button != null:
		_ensure_primary_button_connected()
		primary_button.text = _short_text(str(action.get("label", "下一步")), 12)
		primary_button.tooltip_text = str(action.get("tooltip", tooltip_text))
		primary_button.disabled = bool(action.get("disabled", false)) or _current_action_id == ""
		primary_button.add_theme_stylebox_override("normal", _button_style(_current_accent, primary_button.disabled))
		primary_button.add_theme_stylebox_override("hover", _button_style(_current_accent.lightened(0.08), false))
		primary_button.add_theme_stylebox_override("pressed", _button_style(_current_accent.darkened(0.08), false))
		primary_button.add_theme_stylebox_override("disabled", _button_style(Color("#64748b"), true))
		primary_button.add_theme_color_override("font_color", Color("#f8fafc") if not primary_button.disabled else Color("#94a3b8"))


func _on_primary_button_pressed() -> void:
	if _current_action_id == "":
		return
	primary_action_requested.emit(_current_action_id)


func _ensure_primary_button_connected() -> void:
	if primary_button == null:
		return
	var callback := Callable(self, "_on_primary_button_pressed")
	if not primary_button.pressed.is_connected(callback):
		primary_button.pressed.connect(callback)


func _render_chips(value: Variant) -> void:
	if chip_row == null:
		return
	for child in chip_row.get_children():
		chip_row.remove_child(child)
		child.queue_free()
	var chips: Array = value if value is Array else []
	for chip_variant in chips:
		if not (chip_variant is Dictionary):
			continue
		var chip: Dictionary = chip_variant
		var text := str(chip.get("text", chip.get("label", ""))).strip_edges()
		if text == "":
			continue
		var label := Label.new()
		label.name = "FirstRunCoachChip"
		label.text = _short_text(text, 8)
		label.tooltip_text = str(chip.get("tooltip", ""))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		var accent: Color = chip.get("accent", Color("#cbd5e1"))
		label.add_theme_color_override("font_color", accent.lightened(0.20))
		label.add_theme_stylebox_override("normal", _chip_style(accent))
		chip_row.add_child(label)


func _coach_panel_style(accent: Color, collapsed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.12 if collapsed else 0.08)
	style.border_color = Color("#1e293b").lerp(accent, 0.54)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin(SIDE_LEFT, 10.0)
	style.set_content_margin(SIDE_RIGHT, 10.0)
	style.set_content_margin(SIDE_TOP, 5.0)
	style.set_content_margin(SIDE_BOTTOM, 5.0)
	return style


func _button_style(accent: Color, disabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1e293b") if disabled else Color("#0f172a").lerp(accent, 0.38)
	style.border_color = Color("#475569") if disabled else accent.lightened(0.14)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.set_content_margin(SIDE_LEFT, 10.0)
	style.set_content_margin(SIDE_RIGHT, 10.0)
	style.set_content_margin(SIDE_TOP, 5.0)
	style.set_content_margin(SIDE_BOTTOM, 5.0)
	return style


func _chip_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.16)
	style.border_color = Color("#334155").lerp(accent, 0.38)
	style.set_border_width_all(1)
	style.set_corner_radius_all(999)
	style.set_content_margin(SIDE_LEFT, 7.0)
	style.set_content_margin(SIDE_RIGHT, 7.0)
	style.set_content_margin(SIDE_TOP, 2.0)
	style.set_content_margin(SIDE_BOTTOM, 2.0)
	return style


func _short_text(value: String, limit: int) -> String:
	var text := value.strip_edges()
	if text.length() <= limit:
		return text
	return text.substr(0, max(1, limit - 1)) + "…"


func _stage_color(stage: String) -> Color:
	var normalized := stage.replace("_", "")
	match normalized:
		"selectdistrict":
			return Color("#38bdf8")
		"firstsummon":
			return Color("#fb7185")
		"buildcity":
			return Color("#4ade80")
		"openrack":
			return Color("#facc15")
		"buycard":
			return Color("#fde68a")
		"playcard":
			return Color("#c084fc")
		"inspecttrack":
			return Color("#f59e0b")
		"inspectclues":
			return Color("#93c5fd")
	return Color("#22c55e")
