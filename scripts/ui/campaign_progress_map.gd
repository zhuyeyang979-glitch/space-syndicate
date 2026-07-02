extends PanelContainer
class_name SpaceSyndicateCampaignProgressMap

signal action_requested(action_id: String)

@onready var title_label: Label = %CampaignProgressMapTitle
@onready var progress_label: Label = %CampaignProgressMapProgress
@onready var chapter_row: HFlowContainer = %CampaignProgressMapChapterRow


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style(Color("#facc15")))


func set_progress_map(data: Dictionary) -> void:
	title_label.text = str(data.get("title", "战役进度"))
	progress_label.text = str(data.get("progress_text", "0/10"))
	_clear_children(chapter_row)
	var chapters: Array = data.get("chapters", []) if data.get("chapters", []) is Array else []
	for chapter_variant in chapters:
		if not (chapter_variant is Dictionary):
			continue
		var chapter: Dictionary = chapter_variant
		var accent := Color("#22c55e") if bool(chapter.get("completed", false)) else Color("#facc15") if bool(chapter.get("current", false)) else Color("#38bdf8")
		if not bool(chapter.get("unlocked", false)):
			accent = Color("#64748b")
		var button := Button.new()
		button.text = "%02d %s" % [int(chapter.get("order", 0)), "✓" if bool(chapter.get("completed", false)) else "●" if bool(chapter.get("current", false)) else "锁" if not bool(chapter.get("unlocked", false)) else "○"]
		button.tooltip_text = "%s\n%s" % [str(chapter.get("title", "")), str(chapter.get("subtitle", ""))]
		button.custom_minimum_size = Vector2(84, 42)
		button.disabled = not bool(chapter.get("unlocked", false))
		button.add_theme_color_override("font_color", accent.lightened(0.12))
		button.pressed.connect(_emit_action.bind("campaign_chapter_%s" % str(chapter.get("id", ""))))
		chapter_row.add_child(button)


func _emit_action(action_id: String) -> void:
	if action_id.strip_edges() != "":
		action_requested.emit(action_id)


func _panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.08)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
