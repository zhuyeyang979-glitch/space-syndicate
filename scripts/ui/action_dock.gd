extends PanelContainer
class_name SpaceSyndicateActionDock

signal action_requested(action_id: String)

@onready var action_row: HBoxContainer = %ActionRow

func set_actions(actions: Array) -> void:
	for child in action_row.get_children():
		action_row.remove_child(child)
		child.queue_free()
	if actions.is_empty():
		_add_action_button("none", "暂无行动", true, "选择区域或卡牌后出现主要操作。")
		return
	for action_variant in actions:
		var action: Dictionary = action_variant if action_variant is Dictionary else {}
		_add_action_button(
			str(action.get("id", action.get("label", ""))),
			str(action.get("label", "行动")),
			bool(action.get("disabled", false)),
			str(action.get("tooltip", ""))
		)


func _add_action_button(action_id: String, label_text: String, disabled: bool, tooltip: String) -> void:
	var button := Button.new()
	button.text = label_text
	button.disabled = disabled
	button.tooltip_text = tooltip
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		action_requested.emit(action_id)
	)
	action_row.add_child(button)
