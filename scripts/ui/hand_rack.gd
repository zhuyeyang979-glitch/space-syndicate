extends "res://scripts/HandLayout.gd"
class_name SpaceSyndicateHandRack

signal card_hovered(card_data: Dictionary)
signal card_unhovered
signal card_selected(card_data: Dictionary)
signal card_unselected(card_data: Dictionary)
signal card_double_selected(card_data: Dictionary)
signal card_drag_preview_started(card_data: Dictionary, screen_position: Vector2)
signal card_drag_preview_moved(card_data: Dictionary, screen_position: Vector2)
signal card_drag_preview_ended(card_data: Dictionary)
signal card_drag_released(card_data: Dictionary, screen_position: Vector2)

# Custom Control layout for card children. Parent Containers size this node;
# this node alone positions its own child cards.

const CARD_FACE_SCENE := preload("res://scenes/ui/CardFace.tscn")
const DRAG_PREVIEW_DEADZONE_PIXELS := 6.0
const DRAG_PREVIEW_ACTIVE_META := "hand_drag_preview_active"
const DRAG_PREVIEW_ORIGIN_META := "hand_drag_preview_origin"
const DRAG_PREVIEW_SCREEN_POSITION_META := "hand_drag_preview_screen_position"

var _pressed_card: Control = null
var _drag_preview_card: Control = null
var _selected_identity := ""
var _press_screen_position: Vector2 = Vector2.ZERO
var _cards_signature: String = ""
var _empty_label: Label = null


func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_unselect_current_card()


func set_cards(cards: Array) -> void:
	var normalized := _normalized_cards(cards)
	var next_signature := _cards_identity_signature(normalized)
	if normalized.is_empty():
		if _cards_signature != next_signature or get_child_count() != 1 or not (get_child(0) is Label):
			_cards_signature = next_signature
			_show_empty_hand()
		return
	if next_signature == _cards_signature and _card_children().size() == normalized.size():
		_update_card_data(normalized)
		relayout(false)
		return
	_cards_signature = next_signature
	_sync_card_nodes(normalized)
	relayout(false)


func _connect_card_signals() -> void:
	super._connect_card_signals()
	for card in _card_children():
		var gui_input_callback: Callable = Callable(self, "_on_card_gui_input").bind(card)
		if not card.gui_input.is_connected(gui_input_callback):
			card.gui_input.connect(gui_input_callback)


func _normalized_cards(cards: Array) -> Array:
	var result: Array = []
	for index in range(cards.size()):
		var card_data: Dictionary = cards[index] if cards[index] is Dictionary else {}
		var normalized := card_data.duplicate(true)
		normalized["_hand_identity"] = _card_identity_key(normalized, index)
		result.append(normalized)
	return result


func _cards_identity_signature(cards: Array) -> String:
	var identities: Array[String] = []
	for index in range(cards.size()):
		var card_data: Dictionary = cards[index] if cards[index] is Dictionary else {}
		identities.append(str(card_data.get("_hand_identity", _card_identity_key(card_data, index))))
	return "|".join(identities) if not identities.is_empty() else "empty"


func _card_identity_key(card_data: Dictionary, index: int) -> String:
	for key in ["id", "card_id", "instance_id", "slot_id"]:
		var value := str(card_data.get(key, "")).strip_edges()
		if value != "":
			return value
	var identity_parts := [
		str(card_data.get("name", "")),
		str(card_data.get("cost", card_data.get("price", card_data.get("play_cost", "")))),
		str(card_data.get("type", card_data.get("category", ""))),
		str(card_data.get("rank", card_data.get("stats", ""))),
		str(index),
	]
	return "::".join(identity_parts)


func _show_empty_hand() -> void:
	_end_drag_preview()
	_clear_hand_children()
	_hovered_card = null
	_selected_card = null
	_pressed_card = null
	_selected_identity = ""
	_empty_label = Label.new()
	_empty_label.name = "PlayerHandEmptySlot"
	_empty_label.text = "暂无手牌｜点选区域牌架或等待补给"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_empty_label)
	relayout(true)


func _sync_card_nodes(cards: Array) -> void:
	if _empty_label != null and is_instance_valid(_empty_label):
		remove_child(_empty_label)
		_empty_label.queue_free()
	_empty_label = null
	var existing_by_key := _existing_card_nodes_by_key()
	var wanted_nodes: Array[Control] = []
	var selected_node: Control = null
	for index in range(cards.size()):
		var card_data: Dictionary = cards[index] if cards[index] is Dictionary else {}
		var identity := str(card_data.get("_hand_identity", _card_identity_key(card_data, index)))
		var card := existing_by_key.get(identity, null) as Control
		if card == null:
			card = CARD_FACE_SCENE.instantiate() as Control
			add_child(card)
		card.name = "MiniHandCardFace%d" % index
		card.set_meta("hand_card_identity", identity)
		_render_card_data(card, card_data)
		_connect_card_node_signals(card)
		wanted_nodes.append(card)
		if _card_data_marks_selected(card_data) or (_selected_identity != "" and identity == _selected_identity):
			selected_node = card
			_selected_identity = identity
	for child in _card_children():
		if not wanted_nodes.has(child):
			if child == _hovered_card:
				_hovered_card = null
			if child == _selected_card:
				_selected_card = null
			if child == _drag_preview_card:
				_drag_preview_card = null
			remove_child(child)
			child.queue_free()
	for index in range(wanted_nodes.size()):
		move_child(wanted_nodes[index], index)
	_sync_card_focus_links()
	if selected_node != null:
		set_selected_card(selected_node)
	elif _selected_identity != "":
		_selected_identity = ""
		clear_selected_card()


func _update_card_data(cards: Array) -> void:
	var nodes := _card_children()
	var selected_node: Control = null
	for index in range(mini(nodes.size(), cards.size())):
		var card_data: Dictionary = cards[index] if cards[index] is Dictionary else {}
		var identity := str(card_data.get("_hand_identity", _card_identity_key(card_data, index)))
		_render_card_data(nodes[index], card_data)
		_connect_card_node_signals(nodes[index])
		if _card_data_marks_selected(card_data) or (_selected_identity != "" and identity == _selected_identity):
			selected_node = nodes[index]
			_selected_identity = identity
	_sync_card_focus_links()
	if selected_node != null:
		set_selected_card(selected_node)
	elif _selected_identity != "" and get_selected_card() == null:
		_selected_identity = ""
		clear_selected_card()


func _existing_card_nodes_by_key() -> Dictionary:
	var result := {}
	for child in _card_children():
		var identity := str(child.get_meta("hand_card_identity", ""))
		if identity != "":
			result[identity] = child
	return result


func _render_card_data(card: Control, card_data: Dictionary) -> void:
	var display_data := card_data.duplicate(true)
	display_data.erase("_hand_identity")
	if str(display_data.get("presentation", "")).strip_edges() == "":
		display_data["presentation"] = "mini_hand"
	if str(display_data.get("detail_policy", "")).strip_edges() == "":
		display_data["detail_policy"] = "right_inspector"
	if card.has_method("set_card_data"):
		card.call("set_card_data", display_data)
	card.set_meta("hand_card_drag_disabled", not _card_data_drag_valid(display_data))


func _connect_card_node_signals(card: Control) -> void:
	card.focus_mode = Control.FOCUS_ALL
	card.set_meta("runtime_focus_kind", "hand_card")
	if card.has_signal("card_clicked"):
		var clicked := Callable(self, "_on_card_clicked").bind(card)
		if not card.is_connected("card_clicked", clicked):
			card.connect("card_clicked", clicked)
	if card.has_signal("card_double_clicked"):
		var double_clicked := Callable(self, "_on_card_double_clicked").bind(card)
		if not card.is_connected("card_double_clicked", double_clicked):
			card.connect("card_double_clicked", double_clicked)
	var focus_entered := Callable(self, "_on_card_focus_entered").bind(card)
	if not card.focus_entered.is_connected(focus_entered):
		card.focus_entered.connect(focus_entered)
	var focus_exited := Callable(self, "_on_card_focus_exited").bind(card)
	if not card.focus_exited.is_connected(focus_exited):
		card.focus_exited.connect(focus_exited)


func _clear_hand_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func get_drag_preview_card() -> Control:
	if _drag_preview_card == null:
		return null
	if not is_instance_valid(_drag_preview_card) or _drag_preview_card.get_parent() != self:
		_drag_preview_card = null
		return null
	return _drag_preview_card


func _on_card_mouse_entered(card: Control) -> void:
	super._on_card_mouse_entered(card)
	if card.has_method("get_card_data"):
		card_hovered.emit(card.call("get_card_data"))
	else:
		card_hovered.emit({})


func _on_card_mouse_exited(card: Control) -> void:
	super._on_card_mouse_exited(card)
	card_unhovered.emit()


func _on_card_focus_entered(card: Control) -> void:
	if card == null or card.get_parent() != self:
		return
	set_hovered_card(card)
	card_hovered.emit(_card_data_for(card))


func _on_card_focus_exited(card: Control) -> void:
	if card == null or card.get_parent() != self:
		return
	if _hovered_card == card:
		set_hovered_card(null)
	card_unhovered.emit()


func _on_card_clicked(card_data: Dictionary, card: Control) -> void:
	_select_card_node(card)
	card_selected.emit(card_data)


func _on_card_double_clicked(card_data: Dictionary, card: Control) -> void:
	_select_card_node(card)
	card_double_selected.emit(card_data)


func _on_card_gui_input(event: InputEvent, card: Control) -> void:
	if event != null and event.is_action_pressed("ui_accept"):
		_activate_focused_card(card)
		accept_event()
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		var screen_position := _event_screen_position(event, card)
		if mouse_button.pressed:
			_pressed_card = card
			_press_screen_position = screen_position
			card.set_meta("hand_card_pressed", true)
			set_drag_drop_valid(_card_drag_drop_valid(card))
			return
		card.remove_meta("hand_card_pressed")
		_end_drag_preview(screen_position, true)
		_pressed_card = null
	elif event is InputEventMouseMotion:
		if _pressed_card == null or _pressed_card != card:
			return
		var screen_position := _event_screen_position(event, card)
		if _drag_preview_card == null and screen_position.distance_to(_press_screen_position) >= DRAG_PREVIEW_DEADZONE_PIXELS:
			_begin_drag_preview(card, screen_position)
		elif _drag_preview_card == card:
			_move_drag_preview(card, screen_position)


func _begin_drag_preview(card: Control, screen_position: Vector2) -> void:
	_drag_preview_card = card
	card.set_meta(DRAG_PREVIEW_ACTIVE_META, true)
	card.set_meta(DRAG_PREVIEW_ORIGIN_META, _press_screen_position)
	card.set_meta(DRAG_PREVIEW_SCREEN_POSITION_META, screen_position)
	set_hovered_card(card)
	set_dragged_card(card, _card_drag_drop_valid(card))
	card_drag_preview_started.emit(_card_data_for(card), screen_position)


func _move_drag_preview(card: Control, screen_position: Vector2) -> void:
	card.set_meta(DRAG_PREVIEW_ACTIVE_META, true)
	card.set_meta(DRAG_PREVIEW_SCREEN_POSITION_META, screen_position)
	set_dragged_card(card, _card_drag_drop_valid(card))
	card_drag_preview_moved.emit(_card_data_for(card), screen_position)


func _end_drag_preview(screen_position: Vector2 = Vector2.INF, emit_release: bool = false) -> void:
	var preview_card := get_drag_preview_card()
	if preview_card != null:
		var release_position := screen_position
		if release_position == Vector2.INF:
			var meta_position: Variant = preview_card.get_meta(DRAG_PREVIEW_SCREEN_POSITION_META, get_viewport().get_mouse_position())
			release_position = meta_position if meta_position is Vector2 else get_viewport().get_mouse_position()
		var card_data := _card_data_for(preview_card)
		preview_card.remove_meta(DRAG_PREVIEW_ACTIVE_META)
		preview_card.remove_meta(DRAG_PREVIEW_ORIGIN_META)
		preview_card.remove_meta(DRAG_PREVIEW_SCREEN_POSITION_META)
		preview_card.remove_meta("hand_card_pressed")
		clear_dragged_card()
		card_drag_preview_ended.emit(card_data)
		if emit_release:
			card_drag_released.emit(card_data, release_position)
	_drag_preview_card = null


func _card_data_for(card: Control) -> Dictionary:
	if card != null and card.has_method("get_card_data"):
		var data_variant: Variant = card.call("get_card_data")
		return data_variant if data_variant is Dictionary else {}
	return {}


func _activate_focused_card(card: Control) -> void:
	if card == null or card.get_parent() != self:
		return
	var card_data := _card_data_for(card)
	if get_selected_card() == card:
		card_double_selected.emit(card_data)
		return
	_select_card_node(card)
	card_selected.emit(card_data)


func _sync_card_focus_links() -> void:
	var nodes := _card_children()
	for index in range(nodes.size()):
		var card := nodes[index]
		if card == null:
			continue
		card.focus_mode = Control.FOCUS_ALL
		card.set_meta("runtime_focus_kind", "hand_card")
		if nodes.size() <= 1:
			card.focus_next = NodePath("")
			card.focus_previous = NodePath("")
			continue
		card.focus_previous = card.get_path_to(nodes[wrapi(index - 1, 0, nodes.size())])
		card.focus_next = card.get_path_to(nodes[wrapi(index + 1, 0, nodes.size())])


func _event_screen_position(event: InputEvent, card: Control) -> Vector2:
	if event is InputEventMouse:
		var mouse_event: InputEventMouse = event as InputEventMouse
		if mouse_event.global_position != Vector2.ZERO:
			return mouse_event.global_position
		if card != null:
			return card.get_global_position() + mouse_event.position
	return get_viewport().get_mouse_position()


func _select_card_node(card: Control) -> void:
	if card == null or card.get_parent() != self:
		return
	if get_selected_card() != null and get_selected_card() != card:
		card_unselected.emit(_card_data_for(get_selected_card()))
	_selected_identity = str(card.get_meta("hand_card_identity", ""))
	set_selected_card(card)


func _unselect_current_card() -> void:
	var selected := get_selected_card()
	if selected == null and _selected_identity == "":
		return
	var previous_data := _card_data_for(selected) if selected != null else {}
	_selected_identity = ""
	clear_selected_card()
	if not previous_data.is_empty():
		card_unselected.emit(previous_data)


func _card_data_marks_selected(card_data: Dictionary) -> bool:
	return bool(card_data.get("selected", card_data.get("focused", false)))


func _card_drag_drop_valid(card: Control) -> bool:
	var data := _card_data_for(card)
	return _card_data_drag_valid(data)


func _card_data_drag_valid(data: Dictionary) -> bool:
	if data.has("drop_enabled"):
		return bool(data.get("drop_enabled", false))
	if data.has("actionable"):
		return bool(data.get("actionable", false))
	var actions: Array = data.get("actions", []) if data.get("actions", []) is Array else []
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		var action_id := str(action.get("id", ""))
		if action_id.begins_with("play_"):
			return not bool(action.get("disabled", false))
	return true
