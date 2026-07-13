extends PanelContainer
class_name SpaceSyndicateIntelDossierBoard

signal action_requested(action_id: String)

@onready var header: HBoxContainer = %IntelDossierBoardHeader
@onready var title_label: Label = %IntelDossierBoardTitle
@onready var chip_rail: HFlowContainer = %IntelDossierBoardChipRail
@onready var kpi_grid: GridContainer = %IntelDossierKpiGrid
@onready var action_row: HFlowContainer = %IntelDossierActionRow
@onready var clue_grid: GridContainer = %IntelDossierClueGrid
@onready var control_title: Label = %IntelDossierControlTitle
@onready var control_grid: GridContainer = %IntelDossierControlGrid
@onready var link_title: Label = %IntelDossierLinkTitle
@onready var link_grid: GridContainer = %IntelDossierLinkGrid


func _ready() -> void:
	_style_shell()


func set_dossier(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#c084fc"))
	tooltip_text = str(data.get("tooltip", "情报侦探板：整理城市嫌疑、匿名牌、怪兽资金和公开城市线索，不扫描对手现金、手牌或真实资产。"))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.07), 1, 8))
	title_label.text = str(data.get("title", "情报侦探板"))
	title_label.tooltip_text = str(data.get("title_tooltip", "先扫线索类别，再决定标注城市、猜卡牌归属或跳到图鉴查证。"))
	kpi_grid.columns = clampi(int(data.get("kpi_columns", 4)), 1, 4)
	clue_grid.columns = clampi(int(data.get("clue_columns", 3)), 1, 3)
	control_grid.columns = clampi(int(data.get("control_columns", 1)), 1, 2)
	link_grid.columns = clampi(int(data.get("link_columns", 2)), 1, 3)
	control_title.text = str(data.get("control_title", "私人推理控制｜只修改当前玩家自己的标注"))
	link_title.text = str(data.get("link_title", "公开资料跳转｜只打开可见线索"))
	_render_chips(data.get("chips", []))
	_render_kpis(data.get("kpis", []))
	_render_actions(data.get("actions", []))
	_render_clues(data.get("clues", []))
	_render_control_groups(data.get("control_groups", []))
	_render_links(data.get("links", []))


func _style_shell() -> void:
	header.add_theme_constant_override("separation", 8)
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color("#ede9fe"))
	chip_rail.add_theme_constant_override("h_separation", 5)
	chip_rail.add_theme_constant_override("v_separation", 3)
	kpi_grid.add_theme_constant_override("h_separation", 8)
	kpi_grid.add_theme_constant_override("v_separation", 8)
	action_row.add_theme_constant_override("h_separation", 6)
	action_row.add_theme_constant_override("v_separation", 4)
	clue_grid.add_theme_constant_override("h_separation", 10)
	clue_grid.add_theme_constant_override("v_separation", 10)
	control_title.add_theme_font_size_override("font_size", 12)
	control_title.add_theme_color_override("font_color", Color("#ddd6fe"))
	control_grid.add_theme_constant_override("h_separation", 8)
	control_grid.add_theme_constant_override("v_separation", 8)
	link_title.add_theme_font_size_override("font_size", 12)
	link_title.add_theme_color_override("font_color", Color("#bfdbfe"))
	link_grid.add_theme_constant_override("h_separation", 8)
	link_grid.add_theme_constant_override("v_separation", 8)


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


func _render_clues(entries_variant: Variant) -> void:
	_clear_children(clue_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_clue_card(entry_variant as Dictionary)


func _render_actions(entries_variant: Variant) -> void:
	_clear_children(action_row)
	if not (entries_variant is Array):
		action_row.visible = false
		return
	var entries := entries_variant as Array
	action_row.visible = not entries.is_empty()
	for entry_variant in entries:
		if entry_variant is Dictionary:
			_add_action_button(entry_variant as Dictionary)


func _render_control_groups(entries_variant: Variant) -> void:
	_clear_children(control_grid)
	var entries := entries_variant as Array if entries_variant is Array else []
	control_title.visible = not entries.is_empty()
	control_grid.visible = not entries.is_empty()
	for entry_variant in entries:
		if entry_variant is Dictionary:
			_add_control_group(entry_variant as Dictionary)


func _render_links(entries_variant: Variant) -> void:
	_clear_children(link_grid)
	var entries := entries_variant as Array if entries_variant is Array else []
	link_title.visible = not entries.is_empty()
	link_grid.visible = not entries.is_empty()
	for entry_variant in entries:
		if entry_variant is Dictionary:
			_add_link_button(entry_variant as Dictionary)


func _add_chip(entry: Dictionary) -> void:
	var text := str(entry.get("text", ""))
	if text.strip_edges() == "":
		return
	var accent := _dictionary_color(entry, "accent", Color("#c4b5fd"))
	var chip := PanelContainer.new()
	chip.name = "IntelDossierBoardChip"
	chip.custom_minimum_size = Vector2(clampf(float(text.length()) * 7.2 + 18.0, 40.0, 180.0), 22)
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.16), 1, 8))
	chip_rail.add_child(chip)
	var margin := _margin(7, 2, 7, 2)
	chip.add_child(margin)
	var label := _label(_short_text(text, 20), 9, accent.lightened(0.12))
	label.name = "IntelDossierBoardChipLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = chip.tooltip_text
	margin.add_child(label)


func _add_kpi(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#c084fc"))
	var card := PanelContainer.new()
	card.name = "IntelDossierKpiCard"
	card.custom_minimum_size = Vector2(0, 86)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = str(entry.get("tooltip", ""))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	kpi_grid.add_child(card)
	var margin := _margin(10, 8, 10, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)
	var title := _label(str(entry.get("title", "")), 10, accent.lightened(0.16))
	title.name = "IntelDossierKpiTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(title)
	var value_text := str(entry.get("value", ""))
	var value := _label(_short_text(value_text, 24), 18, Color("#f8fafc"))
	value.name = "IntelDossierKpiValue"
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.tooltip_text = value_text
	box.add_child(value)
	var meta_text := str(entry.get("meta", ""))
	var meta := _label(_short_text(meta_text, 32), 9, Color("#94a3b8"))
	meta.name = "IntelDossierKpiMeta"
	meta.autowrap_mode = TextServer.AUTOWRAP_OFF
	meta.clip_text = true
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta.tooltip_text = str(entry.get("tooltip", meta_text))
	box.add_child(meta)


func _add_clue_card(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#a78bfa"))
	var card := PanelContainer.new()
	card.name = "IntelDossierClueCard"
	card.custom_minimum_size = Vector2(0, 146)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = str(entry.get("tooltip", ""))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.08), 1, 8))
	clue_grid.add_child(card)
	var margin := _margin(10, 8, 10, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := _label(str(entry.get("title", "")), 11, accent.lightened(0.18))
	title.name = "IntelDossierClueTitle"
	title.tooltip_text = card.tooltip_text
	box.add_child(title)
	var lines_variant: Variant = entry.get("lines", [])
	var lines := lines_variant as Array if lines_variant is Array else []
	if lines.is_empty():
		lines = ["暂无可读线索"]
	var line_limit := clampi(int(entry.get("line_limit", 4)), 1, 6)
	for i in range(mini(line_limit, lines.size())):
		var line := str(lines[i])
		var label := _label("• %s" % _short_text(line, 48), 9, Color("#cbd5e1"))
		label.name = "IntelDossierClueLine"
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.tooltip_text = line
		box.add_child(label)


func _add_action_button(entry: Dictionary) -> void:
	var action_id := str(entry.get("id", entry.get("action_id", ""))).strip_edges()
	var label_text := str(entry.get("label", action_id)).strip_edges()
	if action_id == "" or label_text == "":
		return
	var disabled := bool(entry.get("disabled", false))
	var accent := _dictionary_color(entry, "accent", Color("#c4b5fd"))
	var button := Button.new()
	button.name = "IntelDossierActionButton"
	button.text = _short_text(label_text, 10)
	button.disabled = disabled
	button.custom_minimum_size = Vector2(92, 28)
	button.tooltip_text = str(entry.get("tooltip", ""))
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color("#f8fafc") if not disabled else Color("#94a3b8"))
	button.add_theme_stylebox_override("normal", _button_style(accent, false, disabled))
	button.add_theme_stylebox_override("hover", _button_style(accent, true, disabled))
	button.add_theme_stylebox_override("pressed", _button_style(accent.lightened(0.12), true, disabled))
	button.add_theme_stylebox_override("disabled", _button_style(accent, false, true))
	button.pressed.connect(func() -> void:
		action_requested.emit(action_id)
	)
	action_row.add_child(button)


func _add_control_group(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#c084fc"))
	var card := PanelContainer.new()
	card.name = "IntelDossierControlGroup"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = str(entry.get("meta", ""))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.08), 1, 8))
	control_grid.add_child(card)
	var margin := _margin(10, 8, 10, 8)
	card.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)
	var title := _label(str(entry.get("title", "城市标注")), 11, accent.lightened(0.16))
	title.name = "IntelDossierControlGroupTitle"
	stack.add_child(title)
	var meta := _label(_short_text(str(entry.get("meta", "")), 72), 9, Color("#94a3b8"))
	meta.name = "IntelDossierControlGroupMeta"
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.tooltip_text = str(entry.get("meta", ""))
	stack.add_child(meta)
	var action_flow := HFlowContainer.new()
	action_flow.name = "IntelDossierControlActionFlow"
	action_flow.add_theme_constant_override("h_separation", 5)
	action_flow.add_theme_constant_override("v_separation", 4)
	stack.add_child(action_flow)
	var actions_variant: Variant = entry.get("actions", [])
	if actions_variant is Array:
		for action_variant in actions_variant:
			if action_variant is Dictionary:
				_add_data_action_button(action_flow, action_variant as Dictionary, "IntelDossierControlActionButton", 86)


func _add_link_button(entry: Dictionary) -> void:
	_add_data_action_button(link_grid, entry, "IntelDossierLinkActionButton", 0)


func _add_data_action_button(parent: Container, entry: Dictionary, node_name: String, minimum_width: float) -> void:
	var action_id := str(entry.get("id", entry.get("action_id", ""))).strip_edges()
	var label_text := str(entry.get("label", action_id)).strip_edges()
	if action_id == "" or label_text == "":
		return
	var disabled := bool(entry.get("disabled", false))
	var accent := _dictionary_color(entry, "accent", Color("#c4b5fd"))
	var button := Button.new()
	button.name = node_name
	button.text = _short_text(label_text, 28 if node_name == "IntelDossierLinkActionButton" else 14)
	button.disabled = disabled
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT if node_name == "IntelDossierLinkActionButton" else HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if node_name == "IntelDossierLinkActionButton" else Control.SIZE_SHRINK_BEGIN
	button.custom_minimum_size = Vector2(minimum_width, 34 if node_name == "IntelDossierLinkActionButton" else 28)
	button.tooltip_text = str(entry.get("tooltip", ""))
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color("#f8fafc") if not disabled else Color("#94a3b8"))
	button.add_theme_stylebox_override("normal", _button_style(accent, false, disabled))
	button.add_theme_stylebox_override("hover", _button_style(accent, true, disabled))
	button.add_theme_stylebox_override("pressed", _button_style(accent.lightened(0.12), true, disabled))
	button.add_theme_stylebox_override("disabled", _button_style(accent, false, true))
	button.pressed.connect(Callable(self, "_on_action_pressed").bind(action_id))
	parent.add_child(button)


func _on_action_pressed(action_id: String) -> void:
	if action_id.strip_edges() != "":
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


func _button_style(accent: Color, hovered: bool, disabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var fill_weight := 0.12
	if hovered:
		fill_weight = 0.24
	if disabled:
		fill_weight = 0.06
	style.bg_color = Color("#020617").lerp(accent, fill_weight)
	style.border_color = Color("#475569") if disabled else accent.lightened(0.16 if hovered else 0.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin(SIDE_LEFT, 7.0)
	style.set_content_margin(SIDE_RIGHT, 7.0)
	style.set_content_margin(SIDE_TOP, 4.0)
	style.set_content_margin(SIDE_BOTTOM, 4.0)
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
