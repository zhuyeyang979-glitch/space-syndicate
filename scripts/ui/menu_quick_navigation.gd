extends HFlowContainer
class_name SpaceSyndicateMenuQuickNavigation

signal action_requested(action_id: String)

const ACTION_ORDER := [
	"setup",
	"scenario",
	"standings",
	"economy",
	"intel",
	"rules",
	"compendium",
]

@onready var setup_button: Button = %MenuQuickNavSetupButton
@onready var scenario_button: Button = %MenuQuickNavScenarioButton
@onready var standings_button: Button = %MenuQuickNavStandingsButton
@onready var economy_button: Button = %MenuQuickNavEconomyButton
@onready var intel_button: Button = %MenuQuickNavIntelButton
@onready var rules_button: Button = %MenuQuickNavRulesButton
@onready var compendium_button: Button = %MenuQuickNavCompendiumButton

var _buttons: Dictionary = {}
var _entries: Dictionary = {}
var _active_id := ""


func _ready() -> void:
	_buttons = {
		"setup": setup_button,
		"scenario": scenario_button,
		"standings": standings_button,
		"economy": economy_button,
		"intel": intel_button,
		"rules": rules_button,
		"compendium": compendium_button,
	}
	for action_id_variant: Variant in ACTION_ORDER:
		var action_id := str(action_id_variant)
		var button := _buttons.get(action_id) as Button
		if button == null:
			continue
		var callback := Callable(self, "_on_action_pressed").bind(action_id)
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)
	set_navigation({})


func set_navigation(data: Dictionary) -> void:
	_entries.clear()
	_active_id = str(data.get("active_id", "")).strip_edges()
	var entries_variant: Variant = data.get("entries", [])
	if entries_variant is Array:
		for entry_variant: Variant in entries_variant:
			if not (entry_variant is Dictionary):
				continue
			var entry := (entry_variant as Dictionary).duplicate(true)
			var action_id := str(entry.get("id", "")).strip_edges()
			if action_id in ACTION_ORDER:
				_entries[action_id] = entry
	var should_show := bool(data.get("visible", false)) and not _entries.is_empty()
	visible = should_show
	for action_id_variant: Variant in ACTION_ORDER:
		var action_id := str(action_id_variant)
		var button := _buttons.get(action_id) as Button
		if button == null:
			continue
		var entry := _entries.get(action_id, {}) as Dictionary
		button.visible = should_show and not entry.is_empty()
		if entry.is_empty():
			continue
		var label := str(entry.get("label", action_id))
		var tooltip := str(entry.get("tooltip", entry.get("detail", label)))
		var accent := _entry_color(entry, "accent", Color("#38bdf8"))
		button.text = label
		button.disabled = bool(entry.get("disabled", false)) or action_id == _active_id
		button.tooltip_text = "当前页面：%s。可用其他快捷按钮跳到别的分支。" % label if action_id == _active_id else tooltip
		button.custom_minimum_size = Vector2(88, 32)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_button(button, accent, action_id == _active_id)


func set_compact(compact: bool) -> void:
	add_theme_constant_override("h_separation", 4 if compact else 8)
	add_theme_constant_override("v_separation", 4 if compact else 6)
	for button_variant: Variant in _buttons.values():
		var button := button_variant as Button
		if button != null:
			button.custom_minimum_size = Vector2(78 if compact else 88, 30 if compact else 32)
			button.add_theme_font_size_override("font_size", 12 if compact else 13)


func debug_snapshot() -> Dictionary:
	var rendered: Array = []
	for action_id_variant: Variant in ACTION_ORDER:
		var action_id := str(action_id_variant)
		var button := _buttons.get(action_id) as Button
		if button == null or not button.visible:
			continue
		rendered.append({
			"id": action_id,
			"label": button.text,
			"disabled": button.disabled,
		})
	return {
		"visible": visible,
		"active_id": _active_id,
		"rendered": rendered,
	}


func _on_action_pressed(action_id: String) -> void:
	var button := _buttons.get(action_id) as Button
	if button == null or button.disabled or not button.visible:
		return
	action_requested.emit(action_id)


func _entry_color(entry: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = entry.get(key, fallback)
	if value is Color:
		return value as Color
	var color_text := str(value).strip_edges()
	return Color(color_text) if Color.html_is_valid(color_text) else fallback


func _style_button(button: Button, accent: Color, active: bool) -> void:
	var fill := Color("#0b1220").lerp(accent, 0.22 if active else 0.10)
	button.add_theme_stylebox_override("normal", _button_style(accent, fill, 1))
	button.add_theme_stylebox_override("hover", _button_style(accent.lightened(0.18), fill.lightened(0.08), 1))
	button.add_theme_stylebox_override("pressed", _button_style(accent.lightened(0.26), fill.darkened(0.08), 1))
	button.add_theme_stylebox_override("disabled", _button_style(accent.darkened(0.35), Color("#020617").lerp(accent, 0.10), 1))
	button.add_theme_color_override("font_color", Color("#f8fafc"))
	button.add_theme_color_override("font_disabled_color", accent.lightened(0.20))
	button.add_theme_font_size_override("font_size", 13)


func _button_style(accent: Color, fill: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(7)
	style.set_content_margin(SIDE_LEFT, 9.0)
	style.set_content_margin(SIDE_RIGHT, 9.0)
	style.set_content_margin(SIDE_TOP, 5.0)
	style.set_content_margin(SIDE_BOTTOM, 5.0)
	return style
