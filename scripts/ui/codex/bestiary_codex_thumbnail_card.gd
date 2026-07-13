extends PanelContainer
class_name SpaceSyndicateBestiaryCodexThumbnailCard

signal preview_requested(catalog_index: int)
signal detail_requested(catalog_index: int)

@onready var name_label: Label = %BestiaryThumbnailName
@onready var art_view: Control = %BestiaryThumbnailArtView
@onready var stat_label: Label = %BestiaryThumbnailStats
@onready var identity_label: Label = %BestiaryThumbnailIdentity

var _catalog_index := -1


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	gui_input.connect(_on_gui_input)


func set_entry(data: Dictionary) -> void:
	_catalog_index = int(data.get("catalog_index", -1))
	var accent := _dictionary_color(data, "accent", Color("#fb7185"))
	var selected := bool(data.get("selected", false))
	add_theme_stylebox_override("panel", _card_style(Color("#fef3c7") if selected else accent, Color("#0b1120").lerp(accent, 0.14), 2 if selected else 1))
	tooltip_text = str(data.get("tooltip", "Monster detail"))
	name_label.text = str(data.get("name", "Monster"))
	stat_label.text = str(data.get("stats", "HP0 | Move0"))
	identity_label.text = str(data.get("identity", "General"))
	if art_view != null and art_view.has_method("set_monster"):
		var art_variant: Variant = data.get("art", {})
		var art := art_variant as Dictionary if art_variant is Dictionary else {}
		art_view.call("set_monster", str(art.get("name", data.get("name", "Monster"))), str(art.get("style", "Autonomous monster.")), int(art.get("hp", 0)), int(art.get("armor", 0)), str(art.get("move_text", "")), art.get("profile", {}) as Dictionary, true)


func _on_mouse_entered() -> void:
	if _catalog_index >= 0:
		preview_requested.emit(_catalog_index)


func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT or _catalog_index < 0:
		return
	if mouse_event.double_click:
		detail_requested.emit(_catalog_index)
	else:
		preview_requested.emit(_catalog_index)


func _card_style(accent: Color, fill: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(7)
	return style


func _dictionary_color(data: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = data.get(key, fallback)
	if value is Color:
		return value as Color
	var color_text := str(value)
	return Color(color_text) if Color.html_is_valid(color_text) else fallback
