extends PanelContainer
class_name SpaceSyndicateCardTrack

@onready var card_track_row: HBoxContainer = %CardTrackRow

func set_entries(entries: Array) -> void:
	for child in card_track_row.get_children():
		card_track_row.remove_child(child)
		child.queue_free()
	if entries.is_empty():
		_add_track_label("牌轨空", "等待匿名卡牌或公共事件。")
		return
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
		_add_track_label(str(entry.get("label", "匿名牌")), str(entry.get("tooltip", "")))


func _add_track_label(text: String, tooltip: String) -> void:
	var label := Label.new()
	label.custom_minimum_size = Vector2(92, 0)
	label.text = text
	label.tooltip_text = tooltip
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card_track_row.add_child(label)
