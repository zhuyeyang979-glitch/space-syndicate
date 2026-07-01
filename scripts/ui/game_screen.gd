extends Control
class_name SpaceSyndicateGameScreen

signal end_turn_requested
signal action_requested(action_id: String)
signal card_selected(card_data: Dictionary)

@onready var top_bar: Node = %TopBar
@onready var card_track: Node = %CardTrack
@onready var planet_board: Node = %PlanetBoard
@onready var right_inspector: Node = %RightInspector
@onready var player_board: Node = %PlayerBoard

func _ready() -> void:
	if top_bar.has_signal("end_turn_requested"):
		top_bar.connect("end_turn_requested", Callable(self, "_on_end_turn_requested"))
	if right_inspector.has_signal("action_requested"):
		right_inspector.connect("action_requested", Callable(self, "_on_action_requested"))
	if player_board.has_signal("card_selected"):
		player_board.connect("card_selected", Callable(self, "_on_card_selected"))


func apply_state(data: Dictionary) -> void:
	if top_bar.has_method("set_state"):
		top_bar.call("set_state", data.get("top_bar", {}))
	if card_track.has_method("set_entries"):
		var track_entries: Variant = data.get("card_track", [])
		card_track.call("set_entries", track_entries if track_entries is Array else [])
	if planet_board.has_method("set_board_state"):
		planet_board.call("set_board_state", data.get("planet", {}))
	if right_inspector.has_method("set_context"):
		var inspector: Dictionary = data.get("right_inspector", data.get("inspector", {})) if data.get("right_inspector", data.get("inspector", {})) is Dictionary else {}
		if inspector.is_empty():
			inspector = {
				"title": "右侧说明书",
				"district": data.get("district", {}) if data.get("district", {}) is Dictionary else {},
				"actions": data.get("actions", []) if data.get("actions", []) is Array else [],
				"logs": data.get("logs", []) if data.get("logs", []) is Array else [],
			}
		right_inspector.call("set_context", inspector)
	if player_board.has_method("set_player_state"):
		player_board.call("set_player_state", data.get("player_board", {}))


func _on_end_turn_requested() -> void:
	end_turn_requested.emit()


func _on_action_requested(action_id: String) -> void:
	action_requested.emit(action_id)


func _on_card_selected(card_data: Dictionary) -> void:
	if right_inspector.has_method("show_card"):
		right_inspector.call("show_card", card_data)
	card_selected.emit(card_data)
