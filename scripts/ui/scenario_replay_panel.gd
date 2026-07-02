extends PanelContainer
class_name SpaceSyndicateScenarioReplayPanel

signal action_requested(action_id: String)

@onready var title_label: Label = %ScenarioReplayTitle
@onready var snapshot_row: HFlowContainer = %ScenarioReplaySnapshotRow


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style(Color("#f59e0b")))


func set_replay(data: Dictionary) -> void:
	visible = bool(data.get("visible", true))
	if not visible:
		return
	title_label.text = "%s｜关键快照" % str(data.get("title", "剧本复盘"))
	for child in snapshot_row.get_children():
		snapshot_row.remove_child(child)
		child.queue_free()
	var snapshots: Array = data.get("snapshots", []) if data.get("snapshots", []) is Array else []
	for snapshot_variant in snapshots:
		if not (snapshot_variant is Dictionary):
			continue
		var snapshot: Dictionary = snapshot_variant
		var button := Button.new()
		button.name = "ScenarioReplaySnapshotButton"
		button.text = str(snapshot.get("label", snapshot.get("key", "快照")))
		button.disabled = bool(snapshot.get("selected", false))
		button.pressed.connect(_emit_action.bind(str(snapshot.get("action_id", ""))))
		snapshot_row.add_child(button)


func _emit_action(action_id: String) -> void:
	if action_id.strip_edges() != "":
		action_requested.emit(action_id)


func _panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.08)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin(SIDE_LEFT, 8)
	style.set_content_margin(SIDE_TOP, 8)
	style.set_content_margin(SIDE_RIGHT, 8)
	style.set_content_margin(SIDE_BOTTOM, 8)
	return style
