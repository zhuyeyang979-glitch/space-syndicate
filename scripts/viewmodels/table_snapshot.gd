extends RefCounted
class_name TableSnapshot

const DISTRICT_VIEW_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/district_view_snapshot.gd")
const PLAYER_BOARD_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/player_board_snapshot.gd")
const PLANET_BOARD_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/planet_board_snapshot.gd")
const PUBLIC_TRACK_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/public_track_snapshot.gd")
const RIGHT_INSPECTOR_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/right_inspector_snapshot.gd")
const TOP_BAR_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/top_bar_snapshot.gd")

var top_bar: Dictionary = {}
var card_track: Array = []
var planet: Dictionary = {}
var right_inspector: Dictionary = {}
var player_board: Dictionary = {}
var temporary_decision: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	var track_source: Array = data.get("card_track", []) if data.get("card_track", []) is Array else []
	card_track = PUBLIC_TRACK_SNAPSHOT_SCRIPT.new().apply_entries(track_source).to_ui_array()
	var planet_source: Dictionary = data.get("planet", {}) if data.get("planet", {}) is Dictionary else {}
	planet = PLANET_BOARD_SNAPSHOT_SCRIPT.new().apply_dictionary(planet_source).to_ui_dictionary()
	var district: Variant = DISTRICT_VIEW_SNAPSHOT_SCRIPT.new().apply_dictionary(data.get("district", {}) if data.get("district", {}) is Dictionary else {})
	var player: Variant = PLAYER_BOARD_SNAPSHOT_SCRIPT.new().apply_dictionary(data.get("player_board", {}) if data.get("player_board", {}) is Dictionary else {})
	player_board = player.to_ui_dictionary()
	var top_source: Dictionary = _merge_top_bar_source(data.get("top_bar", {}) if data.get("top_bar", {}) is Dictionary else {}, player_board)
	top_bar = TOP_BAR_SNAPSHOT_SCRIPT.new().apply_dictionary(top_source).to_ui_dictionary()
	var inspector_source: Dictionary = data.get("right_inspector", data.get("inspector", {})) if data.get("right_inspector", data.get("inspector", {})) is Dictionary else {}
	inspector_source = inspector_source.duplicate(true)
	if not inspector_source.has("district"):
		inspector_source["district"] = district.to_ui_dictionary()
	if not inspector_source.has("actions"):
		inspector_source["actions"] = data.get("actions", []) if data.get("actions", []) is Array else []
	if not inspector_source.has("logs"):
		inspector_source["logs"] = data.get("logs", []) if data.get("logs", []) is Array else []
	right_inspector = RIGHT_INSPECTOR_SNAPSHOT_SCRIPT.new().apply_dictionary(inspector_source).to_ui_dictionary()
	temporary_decision = _normalize_temporary_decision(data.get("temporary_decision", {}))
	return self


func to_ui_dictionary() -> Dictionary:
	return {
		"top_bar": top_bar,
		"card_track": card_track,
		"planet": planet,
		"right_inspector": right_inspector,
		"player_board": player_board,
		"temporary_decision": temporary_decision,
	}


func _merge_top_bar_source(top_source: Dictionary, player_source: Dictionary) -> Dictionary:
	var merged := top_source.duplicate(true)
	if merged.is_empty():
		merged = player_source.duplicate(true)
	for key in ["identity", "cash_text", "gdp_text", "goal_text", "primary_action"]:
		if not merged.has(key) and player_source.has(key):
			merged[key] = player_source[key]
	if not merged.has("selected_district") and player_source.has("selected_district_summary"):
		merged["selected_district"] = player_source["selected_district_summary"]
	return merged


func _normalize_temporary_decision(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source: Dictionary = value
	if source.is_empty():
		return {}
	var actions: Array = source.get("actions", []) if source.get("actions", []) is Array else []
	var normalized_actions: Array = []
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		var action_id := str(action.get("id", "")).strip_edges()
		if action_id == "":
			continue
		normalized_actions.append({
			"id": action_id,
			"label": str(action.get("label", action.get("text", "选择"))),
			"tooltip": str(action.get("tooltip", "")),
			"disabled": bool(action.get("disabled", false)),
		})
	var chips: Array = source.get("chips", []) if source.get("chips", []) is Array else []
	var normalized_chips: Array = []
	for chip_variant in chips:
		if chip_variant is Dictionary:
			var chip: Dictionary = chip_variant
			var text := str(chip.get("text", chip.get("label", ""))).strip_edges()
			if text != "":
				normalized_chips.append({"text": text, "tooltip": str(chip.get("tooltip", chip.get("tip", ""))), "accent": chip.get("accent", Color("#cbd5e1"))})
		else:
			var chip_text := str(chip_variant).strip_edges()
			if chip_text != "":
				normalized_chips.append({"text": chip_text, "tooltip": ""})
	return {
		"id": str(source.get("id", "")),
		"kind": str(source.get("kind", "")),
		"title": str(source.get("title", "临时决策")),
		"body": str(source.get("body", source.get("summary", ""))),
		"tooltip": str(source.get("tooltip", "")),
		"chips": normalized_chips,
		"actions": normalized_actions,
		"accent": source.get("accent", Color("#facc15")),
	}
