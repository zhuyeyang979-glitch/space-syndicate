extends RefCounted
class_name TableSnapshot

const DISTRICT_VIEW_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/district_view_snapshot.gd")
const PLAYER_BOARD_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/player_board_snapshot.gd")

var top_bar: Dictionary = {}
var card_track: Array = []
var planet: Dictionary = {}
var right_inspector: Dictionary = {}
var player_board: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	top_bar = data.get("top_bar", {}) if data.get("top_bar", {}) is Dictionary else {}
	card_track = data.get("card_track", []) if data.get("card_track", []) is Array else []
	planet = data.get("planet", {}) if data.get("planet", {}) is Dictionary else {}
	var district: Variant = DISTRICT_VIEW_SNAPSHOT_SCRIPT.new().apply_dictionary(data.get("district", {}) if data.get("district", {}) is Dictionary else {})
	right_inspector = data.get("inspector", {}) if data.get("inspector", {}) is Dictionary else {}
	if not right_inspector.has("district"):
		right_inspector["district"] = district.to_ui_dictionary()
	if not right_inspector.has("actions"):
		right_inspector["actions"] = data.get("actions", []) if data.get("actions", []) is Array else []
	if not right_inspector.has("logs"):
		right_inspector["logs"] = data.get("logs", []) if data.get("logs", []) is Array else []
	var player: Variant = PLAYER_BOARD_SNAPSHOT_SCRIPT.new().apply_dictionary(data.get("player_board", {}) if data.get("player_board", {}) is Dictionary else {})
	player_board = player.to_ui_dictionary()
	return self


func to_ui_dictionary() -> Dictionary:
	return {
		"top_bar": top_bar,
		"card_track": card_track,
		"planet": planet,
		"right_inspector": right_inspector,
		"player_board": player_board,
	}
