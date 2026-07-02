extends PanelContainer
class_name SpaceSyndicateCampaignMenu

const FOCUS_TOOLS := preload("res://scripts/ui/focus_tools.gd")

signal action_requested(action_id: String)

@onready var title_label: Label = %CampaignMenuTitle
@onready var subtitle_label: Label = %CampaignMenuSubtitle
@onready var progress_label: Label = %CampaignMenuProgress
@onready var next_label: Label = %CampaignMenuNext
@onready var chapter_grid: GridContainer = %CampaignMenuChapterGrid
@onready var preset_row: HFlowContainer = %CampaignMenuPresetRow
@onready var primary_button: Button = %CampaignMenuPrimaryButton
@onready var secondary_row: HFlowContainer = %CampaignMenuSecondaryRow

var _primary_action_id := ""


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style(Color("#f59e0b")))
	FOCUS_TOOLS.prepare_button(primary_button)
	primary_button.pressed.connect(_emit_primary)


func set_campaign_menu(data: Dictionary) -> void:
	visible = bool(data.get("visible", true))
	if not visible:
		return
	title_label.text = _short_text(str(data.get("title", "新手战役")), 18)
	subtitle_label.text = _short_text(str(data.get("subtitle", data.get("summary", ""))), 28)
	progress_label.text = str(data.get("progress_text", "0/10"))
	next_label.text = _short_text("下一桌｜%s" % str(data.get("next_chapter_title", "")), 24)
	var primary: Dictionary = data.get("primary_action", {}) if data.get("primary_action", {}) is Dictionary else {}
	_primary_action_id = str(primary.get("id", ""))
	primary_button.text = str(primary.get("label", "继续"))
	primary_button.disabled = bool(primary.get("disabled", false)) or _primary_action_id == ""
	_render_chapters(data.get("chapters", []))
	_render_presets(data.get("presets", []))
	_render_secondary(data.get("secondary_actions", []))
	call_deferred("_focus_default_action")


func _render_chapters(value: Variant) -> void:
	_clear_children(chapter_grid)
	var chapters: Array = value if value is Array else []
	chapter_grid.columns = 2
	for chapter_variant in chapters:
		if not (chapter_variant is Dictionary):
			continue
		var chapter: Dictionary = chapter_variant
		var accent := Color("#22c55e") if bool(chapter.get("completed", false)) else Color("#38bdf8")
		if bool(chapter.get("locked", false)):
			accent = Color("#64748b")
		elif bool(chapter.get("current", false)):
			accent = Color("#facc15")
		var card := _card_panel("CampaignChapterCard", accent, Vector2(232, 92))
		card.tooltip_text = "%s\n%s" % [str(chapter.get("title", "")), str(chapter.get("subtitle", ""))]
		chapter_grid.add_child(card)
		var box := _card_box(card)
		var button := Button.new()
		button.text = _short_text("%s%s" % ["✓ " if bool(chapter.get("completed", false)) else "🔒 " if bool(chapter.get("locked", false)) else "", str(chapter.get("title", "关卡"))], 18)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = bool(chapter.get("locked", false))
		FOCUS_TOOLS.prepare_button(button, str(chapter.get("action_id", "")), "CampaignChapterButton")
		button.pressed.connect(_emit_action.bind(str(chapter.get("action_id", ""))))
		box.add_child(button)
		var meta := _label(_short_text(str(chapter.get("meta", "")), 16), 10, accent.lightened(0.18))
		box.add_child(meta)
		var subtitle := _label(_short_text(str(chapter.get("subtitle", "")), 20), 11, Color("#cbd5e1"))
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(subtitle)


func _render_presets(value: Variant) -> void:
	_clear_children(preset_row)
	var presets: Array = value if value is Array else []
	for preset_variant in presets:
		if not (preset_variant is Dictionary):
			continue
		var preset: Dictionary = preset_variant
		var button := Button.new()
		button.text = _short_text(str(preset.get("title", "快速开局")), 8)
		button.tooltip_text = "%s\n%s" % [str(preset.get("detail", "")), str(preset.get("meta", ""))]
		button.custom_minimum_size = Vector2(116, 30)
		FOCUS_TOOLS.prepare_button(button, str(preset.get("action_id", "")), "CampaignPresetButton")
		button.pressed.connect(_emit_action.bind(str(preset.get("action_id", ""))))
		preset_row.add_child(button)


func _render_secondary(value: Variant) -> void:
	_clear_children(secondary_row)
	var actions: Array = value if value is Array else []
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		var button := Button.new()
		button.text = str(action.get("label", "动作"))
		FOCUS_TOOLS.prepare_button(button, str(action.get("id", "")), "CampaignSecondaryButton")
		button.pressed.connect(_emit_action.bind(str(action.get("id", ""))))
		secondary_row.add_child(button)


func _focus_default_action() -> void:
	FOCUS_TOOLS.focus_first_enabled(self, primary_button)


func _emit_primary() -> void:
	_emit_action(_primary_action_id)


func _emit_action(action_id: String) -> void:
	if action_id.strip_edges() != "":
		action_requested.emit(action_id)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _short_text(value: String, limit: int) -> String:
	var text := value.replace("\n", " ").strip_edges()
	if text.length() <= limit:
		return text
	return "%s..." % text.left(maxi(1, limit - 3))


func _card_panel(node_name: String, accent: Color, min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.custom_minimum_size = min_size
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(accent, 0.12))
	return panel


func _card_box(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	return box


func _panel_style(accent: Color, mix: float = 0.08) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, mix)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
