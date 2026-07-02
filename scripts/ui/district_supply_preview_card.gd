extends PanelContainer
class_name SpaceSyndicateDistrictSupplyPreviewCard

const CardFaceScene := preload("res://scenes/ui/CardFace.tscn")

signal buy_requested(card_name: String)

@onready var title_label: Label = %DistrictSupplyPreviewTitle
@onready var preview_chip_rail: HFlowContainer = %DistrictSupplyPreviewChipRail
@onready var micro_chip_rail: HFlowContainer = %DistrictSupplyPreviewMicroChipRail
@onready var verdict_rail: HFlowContainer = %DistrictSupplyPurchaseVerdictRail
@onready var body_label: Label = %DistrictSupplyPreviewBodyLabel
@onready var facts_label: Label = %DistrictSupplyPreviewFactsLabel
@onready var status_label: Label = %DistrictSupplyPreviewStatusLabel
@onready var card_face_host: CenterContainer = %DistrictSupplyPreviewCardFaceHost
@onready var buy_button: Button = %DistrictSupplyPreviewBuyButton

var _card_name := ""


func _ready() -> void:
	buy_button.pressed.connect(_emit_buy_requested)
	set_preview({})


func set_preview(data: Dictionary) -> void:
	_card_name = str(data.get("card_name", ""))
	var accent := _dictionary_color(data, "accent", Color("#94a3b8"))
	var theme_color := _dictionary_color(data, "theme_color", accent)
	tooltip_text = str(data.get("tooltip", ""))
	title_label.text = str(data.get("title", "Card preview"))
	title_label.tooltip_text = str(data.get("title_tooltip", title_label.text))
	title_label.add_theme_color_override("font_color", Color("#f8fafc"))
	_render_chips(preview_chip_rail, data.get("chips", []), "DistrictSupplyPreviewChip", 8)
	_render_chips(micro_chip_rail, data.get("micro_chips", []), "DistrictSupplyPreviewMicroChip", 7)
	_render_verdicts(data.get("verdicts", []))
	body_label.text = str(data.get("body", ""))
	body_label.tooltip_text = str(data.get("body_tooltip", body_label.text))
	facts_label.text = str(data.get("facts", ""))
	facts_label.visible = facts_label.text != ""
	facts_label.tooltip_text = facts_label.text
	status_label.text = str(data.get("status_text", ""))
	status_label.tooltip_text = str(data.get("status_tooltip", ""))
	status_label.add_theme_color_override("font_color", accent.lightened(0.14))
	buy_button.text = str(data.get("buy_text", "买牌"))
	buy_button.disabled = not bool(data.get("buy_enabled", false))
	buy_button.tooltip_text = str(data.get("buy_tooltip", ""))
	_style_button(buy_button, accent, not buy_button.disabled)
	add_theme_stylebox_override("panel", _card_style(theme_color, Color("#020617").lerp(theme_color, 0.11), 1, 8))
	_render_card_face(data.get("card_face", {}))


func _emit_buy_requested() -> void:
	if _card_name != "":
		buy_requested.emit(_card_name)


func _render_chips(parent: Container, entries_variant: Variant, chip_name: String, font_size: int) -> void:
	_clear_children(parent)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_chip(parent, entry_variant as Dictionary, chip_name, font_size)


func _render_verdicts(entries_variant: Variant) -> void:
	_clear_children(verdict_rail)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_verdict_lamp(entry_variant as Dictionary)


func _render_card_face(entry_variant: Variant) -> void:
	_clear_children(card_face_host)
	if not (entry_variant is Dictionary):
		card_face_host.visible = false
		return
	var entry := entry_variant as Dictionary
	card_face_host.visible = not entry.is_empty()
	if entry.is_empty():
		return
	var face := CardFaceScene.instantiate() as Control
	if face == null:
		return
	face.name = "DistrictSupplyPreviewSceneCardFace"
	face.custom_minimum_size = Vector2(
		float(entry.get("minimum_width", 150.0)),
		float(entry.get("minimum_height", 158.0))
	)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card_face_host.add_child(face)
	if face.has_method("set_card_data"):
		face.call("set_card_data", entry)


func _add_chip(parent: Container, entry: Dictionary, chip_name: String, font_size: int) -> void:
	var text := str(entry.get("text", ""))
	var accent := _dictionary_color(entry, "accent", Color("#94a3b8"))
	var fg := _dictionary_color(entry, "fg", accent.lightened(0.16))
	var bg := _dictionary_color(entry, "bg", Color("#020617").lerp(accent, 0.22))
	var chip_width := clampf(float(text.length()) * float(font_size) * 0.72 + 12.0, 22.0, 118.0)
	var chip := PanelContainer.new()
	chip.name = chip_name
	chip.custom_minimum_size = Vector2(chip_width, 18)
	chip.tooltip_text = str(entry.get("tooltip", entry.get("tip", "")))
	chip.add_theme_stylebox_override("panel", _card_style(accent, bg, 1, 6))
	parent.add_child(chip)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 2)
	chip.add_child(margin)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(maxf(1.0, chip_width - 10.0), 0)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", fg)
	margin.add_child(label)


func _add_verdict_lamp(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#94a3b8"))
	var active := bool(entry.get("active", false))
	var lamp := PanelContainer.new()
	lamp.name = "DistrictSupplyPurchaseVerdictLamp"
	lamp.tooltip_text = str(entry.get("tooltip", entry.get("tip", "")))
	lamp.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.20 if active else 0.08), 1, 6))
	verdict_rail.add_child(lamp)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 2)
	lamp.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	margin.add_child(row)
	var signal_bar := ColorRect.new()
	signal_bar.name = "DistrictSupplyPurchaseVerdictSignal"
	signal_bar.color = accent.lightened(0.16) if active else Color("#334155")
	signal_bar.custom_minimum_size = Vector2(5, 16)
	row.add_child(signal_bar)
	var label := Label.new()
	label.name = "DistrictSupplyPurchaseVerdictLabel"
	label.text = str(entry.get("text", ""))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", accent.lightened(0.18) if active else Color("#94a3b8"))
	row.add_child(label)


func _style_button(button: Button, accent: Color, active: bool) -> void:
	var fill := Color("#020617").lerp(accent, 0.26 if active else 0.10)
	button.add_theme_stylebox_override("normal", _card_style(accent, fill, 1, 8))
	button.add_theme_stylebox_override("hover", _card_style(accent.lightened(0.12), fill.lightened(0.08), 1, 8))
	button.add_theme_stylebox_override("pressed", _card_style(accent.lightened(0.2), fill.darkened(0.08), 1, 8))
	button.add_theme_stylebox_override("disabled", _card_style(Color("#475569"), Color("#0f172a"), 1, 8))
	button.add_theme_color_override("font_color", Color("#f8fafc") if active else Color("#94a3b8"))
	button.add_theme_color_override("font_disabled_color", Color("#64748b"))


func _dictionary_color(data: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = data.get(key, fallback)
	if value is Color:
		return value as Color
	return fallback


func _card_style(accent: Color, fill: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
