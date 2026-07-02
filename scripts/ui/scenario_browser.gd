extends PanelContainer
class_name SpaceSyndicateScenarioBrowser

signal action_requested(action_id: String)

@onready var title_label: Label = %ScenarioBrowserTitle
@onready var subtitle_label: Label = %ScenarioBrowserSubtitle
@onready var card_grid: GridContainer = %ScenarioBrowserCardGrid
@onready var primary_button: Button = %ScenarioBrowserStartButton
@onready var secondary_row: HFlowContainer = %ScenarioBrowserSecondaryRow

var _primary_action_id := ""


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style(Color("#38bdf8")))
	if primary_button != null:
		primary_button.pressed.connect(_emit_primary)


func set_browser(data: Dictionary) -> void:
	visible = bool(data.get("visible", true))
	if not visible:
		return
	title_label.text = str(data.get("title", "试玩剧本"))
	subtitle_label.text = str(data.get("subtitle", "选择一个固定局面。"))
	_render_cards(data.get("cards", []))
	var primary: Dictionary = data.get("primary_action", {}) if data.get("primary_action", {}) is Dictionary else {}
	_primary_action_id = str(primary.get("id", ""))
	primary_button.text = str(primary.get("label", "开始剧本"))
	primary_button.disabled = bool(primary.get("disabled", _primary_action_id == ""))
	_render_secondary(data.get("secondary_actions", []))


func _render_cards(value: Variant) -> void:
	_clear_children(card_grid)
	var cards: Array = value if value is Array else []
	card_grid.columns = 2
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card: Dictionary = card_variant
		var accent := Color("#facc15") if bool(card.get("selected", false)) else Color("#334155")
		var panel := PanelContainer.new()
		panel.name = "ScenarioBrowserCard"
		panel.custom_minimum_size = Vector2(250, 122)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.tooltip_text = "%s\n%s" % [str(card.get("title", "")), str(card.get("summary", ""))]
		panel.add_theme_stylebox_override("panel", _panel_style(accent))
		card_grid.add_child(panel)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 8)
		panel.add_child(margin)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		margin.add_child(box)
		var button := Button.new()
		button.text = str(card.get("title", "剧本"))
		button.tooltip_text = panel.tooltip_text
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_emit_action.bind(str(card.get("action_id", ""))))
		box.add_child(button)
		var meta := Label.new()
		meta.text = "%s｜%s｜%s" % [str(card.get("category", "")), str(card.get("duration_label", "")), str(card.get("core_system", ""))]
		meta.add_theme_font_size_override("font_size", 10)
		meta.add_theme_color_override("font_color", Color("#bfdbfe"))
		box.add_child(meta)
		var summary := Label.new()
		summary.text = str(card.get("summary", ""))
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.add_theme_font_size_override("font_size", 11)
		summary.add_theme_color_override("font_color", Color("#cbd5e1"))
		box.add_child(summary)


func _render_secondary(value: Variant) -> void:
	_clear_children(secondary_row)
	var actions: Array = value if value is Array else []
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		var button := Button.new()
		button.text = str(action.get("label", "动作"))
		button.pressed.connect(_emit_action.bind(str(action.get("id", ""))))
		secondary_row.add_child(button)


func _emit_primary() -> void:
	_emit_action(_primary_action_id)


func _emit_action(action_id: String) -> void:
	if action_id.strip_edges() != "":
		action_requested.emit(action_id)


func _panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.08)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin(SIDE_LEFT, 0)
	style.set_content_margin(SIDE_TOP, 0)
	style.set_content_margin(SIDE_RIGHT, 0)
	style.set_content_margin(SIDE_BOTTOM, 0)
	return style


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
