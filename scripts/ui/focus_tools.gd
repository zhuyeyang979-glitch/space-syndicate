extends RefCounted
class_name SpaceSyndicateFocusTools


static func prepare_button(button: Button, action_id: String = "", node_prefix: String = "FocusButton") -> void:
	if button == null:
		return
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if action_id.strip_edges() != "":
		button.name = safe_node_name(node_prefix, action_id)


static func focus_first_enabled(root: Node, preferred: Button = null) -> Button:
	var candidate := preferred if _button_can_focus(preferred) else first_enabled_button(root)
	if candidate != null:
		candidate.grab_focus()
	return candidate


static func first_enabled_button(root: Node) -> Button:
	if root == null:
		return null
	if root is Button and _button_can_focus(root as Button):
		return root as Button
	for child in root.get_children():
		var candidate := first_enabled_button(child)
		if candidate != null:
			return candidate
	return null


static func safe_node_name(prefix: String, action_id: String) -> String:
	var safe := action_id.strip_edges()
	for token in [" ", "\t", "\n", "\r", "/", "\\", ":", ";", ".", ",", "|", "，", "：", "｜"]:
		safe = safe.replace(token, "_")
	if safe == "":
		safe = "action"
	return "%s_%s" % [prefix, safe]


static func _button_can_focus(button: Button) -> bool:
	return button != null \
		and not button.disabled \
		and button.visible \
		and button.is_inside_tree() \
		and button.focus_mode != Control.FOCUS_NONE
