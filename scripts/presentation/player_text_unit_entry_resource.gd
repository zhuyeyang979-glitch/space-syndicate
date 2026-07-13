extends Resource
class_name PlayerTextUnitEntryResource

@export var unit_id: String = ""
@export var value_kind: String = "integer"
@export var scale: int = 1
@export_range(0, 4, 1) var decimal_places: int = 0
@export var suffix_message_key: String = ""
@export var accessible_suffix_message_key: String = ""
@export var join_with_space: bool = false


func to_snapshot() -> Dictionary:
	return {
		"unit_id": unit_id,
		"value_kind": value_kind,
		"scale": scale,
		"decimal_places": decimal_places,
		"suffix_message_key": suffix_message_key,
		"accessible_suffix_message_key": accessible_suffix_message_key,
		"join_with_space": join_with_space,
	}
