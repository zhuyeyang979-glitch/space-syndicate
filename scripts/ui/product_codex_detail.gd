extends PanelContainer
class_name SpaceSyndicateProductCodexDetail

const ProductCodexMarketBadgeScene := preload("res://scenes/ui/codex/ProductCodexMarketBadge.tscn")
const ProductCodexKpiCardScene := preload("res://scenes/ui/codex/ProductCodexKpiCard.tscn")
const ProductCodexStrategyCardScene := preload("res://scenes/ui/codex/ProductCodexStrategyCard.tscn")

@onready var header: HBoxContainer = %ProductCodexMarketHeader
@onready var badge_slot: CenterContainer = %ProductCodexMarketBadgeSlot
@onready var title_label: Label = %ProductCodexMarketTitle
@onready var subtitle_label: Label = %ProductCodexMarketSubtitle
@onready var chip_rail: HFlowContainer = %ProductCodexMarketChipRail
@onready var kpi_grid: GridContainer = %ProductCodexMarketKpiGrid
@onready var strategy_grid: GridContainer = %ProductCodexStrategyGrid


func _ready() -> void:
	_style_shell()


func set_product(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#22c55e"))
	var secondary := _dictionary_color(data, "secondary", Color("#f8fafc"))
	tooltip_text = str(data.get("tooltip", "商品市场板：先看价格、供需、路线、期货仓储、怪兽偏好和地图入口。"))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.08), 1, 8))
	title_label.text = str(data.get("title", "商品市场板"))
	subtitle_label.text = str(data.get("subtitle", "价格、供需、策略和公开线索"))
	subtitle_label.add_theme_color_override("font_color", secondary.lightened(0.12))
	_render_badge(data.get("badge", {}), accent, secondary)
	_render_chips(data.get("chips", []))
	_render_kpis(data.get("kpis", []))
	_render_strategies(data.get("strategies", []))


func _style_shell() -> void:
	header.add_theme_constant_override("separation", 10)
	badge_slot.custom_minimum_size = Vector2(230, 0)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color("#f8fafc"))
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 12)
	chip_rail.add_theme_constant_override("h_separation", 5)
	chip_rail.add_theme_constant_override("v_separation", 3)
	kpi_grid.columns = 4
	kpi_grid.add_theme_constant_override("h_separation", 7)
	kpi_grid.add_theme_constant_override("v_separation", 7)
	strategy_grid.columns = 3
	strategy_grid.add_theme_constant_override("h_separation", 7)
	strategy_grid.add_theme_constant_override("v_separation", 7)


func _render_badge(badge_variant: Variant, fallback_accent: Color, fallback_secondary: Color) -> void:
	_clear_children(badge_slot)
	var badge := badge_variant as Dictionary if badge_variant is Dictionary else {}
	var panel := ProductCodexMarketBadgeScene.instantiate() as PanelContainer
	if panel == null:
		return
	panel.name = "ProductCodexMarketBadge"
	badge_slot.add_child(panel)
	if panel.has_method("set_badge"):
		panel.call("set_badge", badge, fallback_accent, fallback_secondary)


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


func _render_strategies(entries_variant: Variant) -> void:
	_clear_children(strategy_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_strategy(entry_variant as Dictionary)


func _add_chip(entry: Dictionary) -> void:
	var text := str(entry.get("text", ""))
	if text.strip_edges() == "":
		return
	var accent := _dictionary_color(entry, "accent", Color("#94a3b8"))
	var fg := _dictionary_color(entry, "fg", accent.lightened(0.18))
	var bg := _dictionary_color(entry, "bg", Color("#020617").lerp(accent, 0.20))
	var chip_width := clampf(float(text.length()) * 7.2 + 18.0, 34.0, 150.0)
	var chip := PanelContainer.new()
	chip.name = "ProductCodexMarketChip"
	chip.custom_minimum_size = Vector2(chip_width, 26)
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.add_theme_stylebox_override("panel", _card_style(accent, bg, 1, 8))
	chip_rail.add_child(chip)
	var margin := _margin(7, 2, 7, 2)
	chip.add_child(margin)
	var label := _label(_short_text(text, 18), 11, fg)
	label.name = "ProductCodexMarketChipLabel"
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = chip.tooltip_text
	margin.add_child(label)


func _add_kpi(entry: Dictionary) -> void:
	var card := ProductCodexKpiCardScene.instantiate() as PanelContainer
	if card == null:
		return
	card.name = "ProductCodexMarketKpiCard"
	kpi_grid.add_child(card)
	if card.has_method("set_kpi"):
		card.call("set_kpi", entry)


func _add_strategy(entry: Dictionary) -> void:
	var card := ProductCodexStrategyCardScene.instantiate() as PanelContainer
	if card == null:
		return
	card.name = "ProductCodexStrategyCard"
	strategy_grid.add_child(card)
	if card.has_method("set_strategy"):
		card.call("set_strategy", entry)


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
	if value is String:
		var text_value := str(value)
		if text_value.begins_with("#"):
			return Color(text_value)
	return fallback


func _short_text(value: String, limit: int) -> String:
	if limit <= 0 or value.length() <= limit:
		return value
	return value.substr(0, max(0, limit - 1)) + "…"


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
