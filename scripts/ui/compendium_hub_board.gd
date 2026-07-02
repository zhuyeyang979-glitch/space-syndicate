extends PanelContainer
class_name SpaceSyndicateCompendiumHubBoard

signal action_requested(action_id: String)

@onready var title_label: Label = %CompendiumHubTitle
@onready var chip_rail: HFlowContainer = %CompendiumHubChipRail
@onready var kpi_grid: GridContainer = %CompendiumHubKpiGrid
@onready var action_title: Label = %CompendiumHubActionTitle
@onready var action_grid: GridContainer = %CompendiumHubActionGrid
@onready var footer_hint: Label = %CompendiumHubFooterHint


func _ready() -> void:
	_style_shell()


func set_hub(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#f472b6"))
	tooltip_text = str(data.get("tooltip", "资料大厅：选择角色、卡牌、商品、区域或怪兽生态资料。"))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.07), 1, 8))
	title_label.text = str(data.get("title", "资料大厅"))
	title_label.tooltip_text = str(data.get("title_tooltip", "图鉴入口页：把长资料集中在 Codex，不挤主桌。"))
	kpi_grid.columns = clampi(int(data.get("kpi_columns", 3)), 1, 4)
	action_grid.columns = clampi(int(data.get("action_columns", 3)), 1, 4)
	action_title.text = str(data.get("action_title", "图鉴分支｜选择一个资料板"))
	footer_hint.text = str(data.get("footer", "图鉴只承载长资料；主桌继续只保留当前行动和短解释。"))
	_render_chips(data.get("chips", []))
	_render_kpis(data.get("kpis", []))
	_render_actions(data.get("actions", []))


func _style_shell() -> void:
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color("#fce7f3"))
	chip_rail.add_theme_constant_override("h_separation", 5)
	chip_rail.add_theme_constant_override("v_separation", 3)
	kpi_grid.add_theme_constant_override("h_separation", 8)
	kpi_grid.add_theme_constant_override("v_separation", 8)
	action_title.add_theme_font_size_override("font_size", 12)
	action_title.add_theme_color_override("font_color", Color("#fde68a"))
	action_grid.add_theme_constant_override("h_separation", 8)
	action_grid.add_theme_constant_override("v_separation", 8)
	footer_hint.add_theme_font_size_override("font_size", 10)
	footer_hint.add_theme_color_override("font_color", Color("#94a3b8"))


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


func _render_actions(entries_variant: Variant) -> void:
	_clear_children(action_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_action_button(entry_variant as Dictionary)


func _add_chip(entry: Dictionary) -> void:
	var text := str(entry.get("text", ""))
	if text.strip_edges() == "":
		return
	var accent := _dictionary_color(entry, "accent", Color("#fce7f3"))
	var chip := PanelContainer.new()
	chip.name = "CompendiumHubChip"
	chip.custom_minimum_size = Vector2(clampf(float(text.length()) * 12.0 + 24.0, 54.0, 190.0), 22)
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.16), 1, 8))
	chip_rail.add_child(chip)
	var margin := _margin(7, 2, 7, 2)
	chip.add_child(margin)
	var label := _label(_short_text(text, 18), 9, accent.lightened(0.16))
	label.name = "CompendiumHubChipLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = chip.tooltip_text
	margin.add_child(label)


func _add_kpi(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#f472b6"))
	var body_text := str(entry.get("body", ""))
	var meta_text := str(entry.get("meta", ""))
	var card := PanelContainer.new()
	card.name = "CompendiumHubKpiCard"
	card.custom_minimum_size = Vector2(0, 86)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = str(entry.get("tooltip", body_text))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	kpi_grid.add_child(card)
	var margin := _margin(10, 8, 10, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := _label(str(entry.get("title", "")), 10, accent.lightened(0.16))
	title.name = "CompendiumHubKpiTitle"
	box.add_child(title)
	var body := _label(_short_text(body_text, 56), 10, Color("#f8fafc"))
	body.name = "CompendiumHubKpiBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.tooltip_text = body_text
	box.add_child(body)
	var meta := _label(_short_text(meta_text, 48), 8, Color("#94a3b8"))
	meta.name = "CompendiumHubKpiMeta"
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.tooltip_text = meta_text
	box.add_child(meta)


func _add_action_button(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#f472b6"))
	var button := Button.new()
	button.name = str(entry.get("name", "CompendiumHubActionButton"))
	button.text = str(entry.get("title", "资料板"))
	button.tooltip_text = str(entry.get("body", ""))
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color("#f8fafc"))
	button.add_theme_stylebox_override("normal", _card_style(accent, Color("#020617").lerp(accent, 0.11), 1, 8))
	button.add_theme_stylebox_override("hover", _card_style(accent.lightened(0.18), Color("#020617").lerp(accent, 0.22), 1, 8))
	button.pressed.connect(Callable(self, "_on_action_pressed").bind(str(entry.get("id", ""))))
	action_grid.add_child(button)


func _on_action_pressed(action_id: String) -> void:
	if action_id.strip_edges() == "":
		return
	action_requested.emit(action_id)


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
