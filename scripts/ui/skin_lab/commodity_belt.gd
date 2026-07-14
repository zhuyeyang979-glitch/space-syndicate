extends PanelContainer
class_name SpaceSyndicateCommodityBelt

signal claim_requested(card_key: String, belt_revision: int)
signal visible_card_focused(card_view_model: Dictionary)

@export var motion_speed := 7.0
@export var motion_enabled := true

@onready var slot_flow: HBoxContainer = %SlotFlow
@onready var visibility_label: Label = %VisibilityLabel
@onready var rank_hint_label: Label = %RankHintLabel

var _belt_revision := 1
var _motion_offset := 0.0


func _ready() -> void:
	set_process(motion_enabled)
	_connect_visible_slots()


func set_view_snapshot(snapshot: Dictionary) -> void:
	_belt_revision = int(snapshot.get("revision", _belt_revision))
	visibility_label.text = str(snapshot.get("visibility_label", "清晰区 3 / 8"))
	rank_hint_label.text = str(snapshot.get("rank_hint", "领先档 · 反应窗口较短"))
	var obscured: Array = snapshot.get("obscured", []) if snapshot.get("obscured", []) is Array else []
	var visible_cards: Array = snapshot.get("visible", []) if snapshot.get("visible", []) is Array else []
	var obscured_nodes := _obscured_slots()
	for index in range(obscured_nodes.size()):
		var node := obscured_nodes[index]
		var safe_data: Dictionary = obscured[index] if index < obscured.size() and obscured[index] is Dictionary else {}
		if node.has_method("set_safe_snapshot"):
			node.call("set_safe_snapshot", safe_data)
	var visible_nodes := _visible_slots()
	for index in range(visible_nodes.size()):
		var node := visible_nodes[index]
		var view_model: Dictionary = visible_cards[index] if index < visible_cards.size() and visible_cards[index] is Dictionary else {}
		if node.has_method("set_view_model"):
			node.call("set_view_model", view_model)


func set_motion_enabled(enabled: bool) -> void:
	motion_enabled = enabled
	set_process(enabled)
	if not enabled:
		_motion_offset = 0.0
		_update_motion_position()


func get_debug_snapshot() -> Dictionary:
	var hidden_safe: Array = []
	for node in _obscured_slots():
		if node.has_method("get_safe_debug_snapshot"):
			hidden_safe.append(node.call("get_safe_debug_snapshot"))
	return {
		"component": "CommodityBelt",
		"revision": _belt_revision,
		"motion_enabled": motion_enabled,
		"visible_slot_count": _visible_slots().size(),
		"obscured_slot_count": _obscured_slots().size(),
		"obscured_safe_payloads": hidden_safe,
	}


func _process(delta: float) -> void:
	_motion_offset = fmod(_motion_offset + delta * motion_speed, 38.0)
	_update_motion_position()


func _update_motion_position() -> void:
	if slot_flow != null:
		slot_flow.position.x = -_motion_offset


func _connect_visible_slots() -> void:
	for node in _visible_slots():
		if node.has_signal("claim_requested"):
			var claim_callback := Callable(self, "_on_slot_claim_requested")
			if not node.is_connected("claim_requested", claim_callback):
				node.connect("claim_requested", claim_callback)
		if node.has_signal("focused"):
			var focus_callback := Callable(self, "_on_slot_focused")
			if not node.is_connected("focused", focus_callback):
				node.connect("focused", focus_callback)


func _obscured_slots() -> Array[Control]:
	var result: Array[Control] = []
	for node in [%ObscuredSlot1, %ObscuredSlot2, %ObscuredSlot3, %ObscuredSlot4, %ObscuredSlot5]:
		if node is Control:
			result.append(node as Control)
	return result


func _visible_slots() -> Array[Control]:
	var result: Array[Control] = []
	for node in [%VisibleSlot1, %VisibleSlot2, %VisibleSlot3]:
		if node is Control:
			result.append(node as Control)
	return result


func _on_slot_claim_requested(card_key: String) -> void:
	claim_requested.emit(card_key, _belt_revision)


func _on_slot_focused(card_view_model: Dictionary) -> void:
	visible_card_focused.emit(card_view_model.duplicate(true))
