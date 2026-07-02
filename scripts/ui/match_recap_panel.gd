extends PanelContainer
class_name SpaceSyndicateMatchRecapPanel

const FOCUS_TOOLS := preload("res://scripts/ui/focus_tools.gd")

signal action_requested(action_id: String)

@onready var title_label: Label = %MatchRecapTitle
@onready var learned_box: VBoxContainer = %MatchRecapLearned
@onready var action_box: VBoxContainer = %MatchRecapActions
@onready var suggestion_box: VBoxContainer = %MatchRecapSuggestions
@onready var checkpoint_row: HFlowContainer = %MatchRecapCheckpointRow
@onready var secondary_row: HFlowContainer = %MatchRecapSecondaryRow


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style(Color("#a78bfa")))


func set_recap(data: Dictionary) -> void:
	title_label.text = str(data.get("title", "本关复盘"))
	_render_list(learned_box, data.get("learned", []), "学到")
	_render_list(action_box, data.get("key_actions", []), "行动")
	_render_list(suggestion_box, data.get("suggestions", []), "建议")
	_render_actions(checkpoint_row, data.get("checkpoint_actions", []))
	_render_actions(secondary_row, data.get("secondary_actions", []))
	call_deferred("_focus_default_action")


func _render_list(parent: VBoxContainer, value: Variant, prefix: String) -> void:
	_clear_children(parent)
	var entries: Array = value if value is Array else []
	if entries.is_empty():
		entries.append("继续观察牌桌")
	for entry in entries:
		var label := Label.new()
		label.text = "%s｜%s" % [prefix, str(entry)]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("#e9d5ff"))
		parent.add_child(label)


func _render_actions(parent: HFlowContainer, value: Variant) -> void:
	_clear_children(parent)
	var actions: Array = value if value is Array else []
	for action_variant in actions:
		if action_variant is Dictionary:
			var action: Dictionary = action_variant
			var button := Button.new()
			button.text = str(action.get("label", "动作"))
			FOCUS_TOOLS.prepare_button(button, str(action.get("id", "")), "MatchRecapActionButton")
			button.pressed.connect(_emit_action.bind(str(action.get("id", ""))))
			parent.add_child(button)


func _focus_default_action() -> void:
	FOCUS_TOOLS.focus_first_enabled(self)


func _emit_action(action_id: String) -> void:
	if action_id.strip_edges() != "":
		action_requested.emit(action_id)


func _panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.10)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
