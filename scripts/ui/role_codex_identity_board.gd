extends PanelContainer
class_name SpaceSyndicateRoleCodexIdentityBoard

const CardFaceScene := preload("res://scenes/ui/CardFace.tscn")

@onready var face_slot: CenterContainer = %RoleCodexIdentityFaceSlot
@onready var title_label: Label = %RoleCodexIdentityTitle
@onready var subtitle_label: Label = %RoleCodexIdentitySubtitle
@onready var chip_rail: HFlowContainer = %RoleCodexIdentityChipRail
@onready var kpi_grid: GridContainer = %RoleCodexAbilityKpiGrid
@onready var route_grid: GridContainer = %RoleCodexRouteCardGrid


func _ready() -> void:
	_style_shell()


func set_role(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#38bdf8"))
	tooltip_text = str(data.get("tooltip", "公开身份牌：先看牌路、能力、信息边界和开局打法，再决定是否选择这个角色。"))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.08), 1, 8))
	title_label.text = str(data.get("title", "外星辛迪加"))
	title_label.tooltip_text = str(data.get("title_tooltip", title_label.text))
	subtitle_label.text = str(data.get("subtitle", "未知外星人｜通用经营"))
	subtitle_label.add_theme_color_override("font_color", accent.lightened(0.18))
	kpi_grid.columns = clampi(int(data.get("kpi_columns", 4)), 1, 4)
	route_grid.columns = clampi(int(data.get("route_columns", 3)), 1, 3)
	_render_card_face(data.get("face", {}))
	_render_chips(data.get("chips", []))
	_render_kpis(data.get("kpis", []))
	_render_routes(data.get("routes", []))


func _style_shell() -> void:
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color("#f8fafc"))
	subtitle_label.add_theme_font_size_override("font_size", 12)
	chip_rail.add_theme_constant_override("h_separation", 5)
	chip_rail.add_theme_constant_override("v_separation", 3)
	kpi_grid.add_theme_constant_override("h_separation", 7)
	kpi_grid.add_theme_constant_override("v_separation", 7)
	route_grid.add_theme_constant_override("h_separation", 7)
	route_grid.add_theme_constant_override("v_separation", 7)


func _render_card_face(face_variant: Variant) -> void:
	_clear_children(face_slot)
	if not (face_variant is Dictionary):
		return
	var entry := face_variant as Dictionary
	if entry.is_empty():
		return
	var face := CardFaceScene.instantiate() as Control
	if face == null:
		return
	face.name = "RoleCodexSceneCardFace"
	face.custom_minimum_size = Vector2(
		float(entry.get("minimum_width", 230.0)),
		float(entry.get("minimum_height", 270.0))
	)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	face_slot.add_child(face)
	if face.has_method("set_card_data"):
		face.call("set_card_data", entry)


func _render_chips(entries_variant: Variant) -> void:
	_clear_children(chip_rail)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_chip(entry_variant as Dictionary)


func _render_kpis(entries_variant: Variant) -> void:
	_clear_children(kpi_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_kpi(entry_variant as Dictionary)


func _render_routes(entries_variant: Variant) -> void:
	_clear_children(route_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_route_card(entry_variant as Dictionary)


func _add_chip(entry: Dictionary) -> void:
	var text := str(entry.get("text", ""))
	if text.strip_edges() == "":
		return
	var accent := _dictionary_color(entry, "accent", Color("#e0f2fe"))
	var fill := _dictionary_color(entry, "fill", Color("#020617").lerp(accent, 0.20))
	var chip := PanelContainer.new()
	chip.name = "RoleCodexIdentityChip"
	chip.custom_minimum_size = Vector2(clampf(float(text.length()) * 12.0 + 22.0, 58.0, 200.0), 26)
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.add_theme_stylebox_override("panel", _card_style(accent, fill, 1, 8))
	chip_rail.add_child(chip)
	var margin := _margin(7, 2, 7, 2)
	chip.add_child(margin)
	var label := _label(_short_text(text, 18), 11, accent.lightened(0.16))
	label.name = "RoleCodexIdentityChipLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = chip.tooltip_text
	margin.add_child(label)


func _add_kpi(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#93c5fd"))
	var value_text := str(entry.get("value", ""))
	var meta_text := str(entry.get("meta", ""))
	var card := PanelContainer.new()
	card.name = "RoleCodexAbilityKpiCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 82)
	card.tooltip_text = str(entry.get("tooltip", "%s｜%s｜%s" % [entry.get("title", ""), value_text, meta_text]))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	kpi_grid.add_child(card)
	var margin := _margin(9, 7, 9, 7)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)
	var title := _label(str(entry.get("title", "")), 12, accent.lightened(0.18))
	title.name = "RoleCodexAbilityKpiTitle"
	box.add_child(title)
	var value := _label(_short_text(value_text, 36), 12, Color("#f8fafc"))
	value.name = "RoleCodexAbilityKpiValue"
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.tooltip_text = value_text
	box.add_child(value)
	var meta := _label(_short_text(meta_text, 42), 11, Color("#94a3b8"))
	meta.name = "RoleCodexAbilityKpiMeta"
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.tooltip_text = meta_text
	box.add_child(meta)


func _add_route_card(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#93c5fd"))
	var body_text := str(entry.get("body", ""))
	var card := PanelContainer.new()
	card.name = "RoleCodexRouteCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 94)
	card.tooltip_text = str(entry.get("tooltip", body_text))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.08), 1, 8))
	route_grid.add_child(card)
	var margin := _margin(9, 8, 9, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := _label(str(entry.get("title", "")), 13, accent.lightened(0.14))
	title.name = "RoleCodexRouteCardTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(title)
	var body := _label(_short_text(body_text, 90), 12, Color("#e5e7eb"))
	body.name = "RoleCodexRouteCardBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.tooltip_text = card.tooltip_text
	box.add_child(body)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _card_style(accent: Color, fill: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _dictionary_color(data: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = data.get(key, fallback)
	if value is Color:
		return value as Color
	return fallback


func _short_text(value: String, limit: int) -> String:
	if limit <= 0 or value.length() <= limit:
		return value
	return value.substr(0, max(0, limit - 1)) + "…"


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
