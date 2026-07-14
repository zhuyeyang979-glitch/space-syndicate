extends PanelContainer
class_name SpaceSyndicateCommodityBeltSlot

signal claim_requested(card_key: String)
signal focused(card_view_model: Dictionary)

@onready var accent_bar: ColorRect = %AccentBar
@onready var glyph_label: Label = %GlyphLabel
@onready var name_label: Label = %NameLabel
@onready var meta_label: Label = %MetaLabel
@onready var claim_label: Label = %ClaimLabel

var _card_view_model: Dictionary = {}


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	focus_entered.connect(_emit_focused)
	mouse_entered.connect(_emit_focused)


func set_view_model(view_model: Dictionary) -> void:
	_card_view_model = view_model.duplicate(true)
	var accent := _color_from(view_model.get("accent", "#38bdf8"), Color("#38bdf8"))
	accent_bar.color = accent
	glyph_label.text = str(view_model.get("glyph", "◉"))
	glyph_label.add_theme_color_override("font_color", accent.lightened(0.12))
	name_label.text = str(view_model.get("name", "可见商品"))
	meta_label.text = "%s · %s" % [str(view_model.get("industry", "商品")), str(view_model.get("rank", "I"))]
	claim_label.text = str(view_model.get("action_label", "可领取"))
	claim_label.add_theme_color_override("font_color", Color("#fde68a"))
	tooltip_text = "%s，%s。%s" % [name_label.text, meta_label.text, claim_label.text]
	set_meta("player_assistive_name", "%s，%s，%s" % [name_label.text, meta_label.text, claim_label.text])
	add_theme_stylebox_override("panel", _slot_style(accent))


func get_player_view_model() -> Dictionary:
	return _card_view_model.duplicate(true)


func _emit_focused() -> void:
	if not _card_view_model.is_empty():
		focused.emit(_card_view_model.duplicate(true))


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var card_key := str(_card_view_model.get("card_key", ""))
			if card_key != "":
				claim_requested.emit(card_key)
			accept_event()


func _slot_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#07111f").lerp(accent, 0.095)
	style.border_color = accent.darkened(0.18)
	style.set_border_width_all(1)
	style.border_width_bottom = 2
	style.set_corner_radius_all(9)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	return style


func _color_from(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value as Color
	if value is String and str(value).begins_with("#"):
		return Color(str(value))
	return fallback
