extends RefCounted
class_name TableSnapshot

const REAL_TEMPORARY_DECISION_KINDS := [
	"monster_wager",
	"counter_response",
	"discard_purchase",
	"monster_target_choice",
	"player_target_choice",
]
const VALID_FORCED_PRIORITY_GROUPS := [
	"monster_wager",
	"counter_response",
	"other_choice",
	"public_bid",
]
const VALID_FORCED_PRESENTATION_SURFACES := ["overlay", "card_resolution_track", "player_hint"]

const DISTRICT_VIEW_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/district_view_snapshot.gd")
const PLAYER_BOARD_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/player_board_snapshot.gd")
const PLANET_BOARD_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/planet_board_snapshot.gd")
const PUBLIC_TRACK_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/public_track_snapshot.gd")
const RIGHT_INSPECTOR_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/right_inspector_snapshot.gd")
const TOP_BAR_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/top_bar_snapshot.gd")
const OPTIONAL_ROUTE_PUBLIC_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/optional_route_public_snapshot.gd")
const COMMODITY_SUSHI_TRACK_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/commodity_sushi_track_snapshot.gd")

var top_bar: Dictionary = {}
var card_track: Array = []
var card_resolution_track: Dictionary = {}
var planet: Dictionary = {}
var right_inspector: Dictionary = {}
var player_board: Dictionary = {}
var temporary_decision: Dictionary = {}
var active_forced_decision: Dictionary = {}
var optional_route_presentation: Dictionary = {}
var commodity_sushi_track: Dictionary = {}
var visual_events: Array = []
var visual_event_key := ""
var selection_context: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	var selection_source: Dictionary = data.get("selection_context", {}) if data.get("selection_context", {}) is Dictionary else {}
	selection_context = {
		"revision": maxi(0, int(selection_source.get("revision", 0))),
		"selected_district": int(selection_source.get("selected_district", -1)),
		"district_count": maxi(0, int(selection_source.get("district_count", 0))),
		"selected_trade_product": str(selection_source.get("selected_trade_product", "")),
		"trade_product_ids": _selection_string_array(selection_source.get("trade_product_ids", [])),
		"default_trade_product_id": str(selection_source.get("default_trade_product_id", "")),
		"selected_hand_slot": int(selection_source.get("selected_hand_slot", -1)),
		"hand_slot_count": maxi(0, int(selection_source.get("hand_slot_count", 0))),
		"selected_card_resolution_id": int(selection_source.get("selected_card_resolution_id", -1)),
	}
	var track_source: Array = data.get("card_track", []) if data.get("card_track", []) is Array else []
	card_track = PUBLIC_TRACK_SNAPSHOT_SCRIPT.new().apply_entries(track_source).to_ui_array()
	var card_resolution_source: Dictionary = data.get("card_resolution_track", {}) if data.get("card_resolution_track", {}) is Dictionary else {}
	card_resolution_track = _normalize_card_resolution_track(card_resolution_source, card_track)
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
	active_forced_decision = _normalize_active_forced_decision(data.get("active_forced_decision", {}))
	optional_route_presentation = OPTIONAL_ROUTE_PUBLIC_SNAPSHOT_SCRIPT.new() \
		.apply_dictionary(data.get("optional_route_presentation", {})) \
		.to_ui_dictionary()
	var commodity_source: Dictionary = data.get("commodity_sushi_track", {}) \
		if data.get("commodity_sushi_track", {}) is Dictionary else {}
	var commodity_snapshot: COMMODITY_SUSHI_TRACK_SNAPSHOT_SCRIPT = COMMODITY_SUSHI_TRACK_SNAPSHOT_SCRIPT.new().apply_dictionary(commodity_source)
	commodity_sushi_track = commodity_snapshot.to_dictionary() if commodity_snapshot != null and commodity_snapshot.is_valid() else {}
	visual_events = (data.get("visual_events", []) as Array).duplicate(true) if data.get("visual_events", []) is Array else []
	visual_event_key = str(data.get("visual_event_key", ""))
	return self


func to_ui_dictionary() -> Dictionary:
	return {
		"selection_context": selection_context.duplicate(true),
		"top_bar": top_bar,
		"card_track": card_track,
		"card_resolution_track": card_resolution_track,
		"planet": planet,
		"right_inspector": right_inspector,
		"player_board": player_board,
		"temporary_decision": temporary_decision,
		"active_forced_decision": active_forced_decision,
		"optional_route_presentation": optional_route_presentation,
		"commodity_sushi_track": commodity_sushi_track,
		"visual_events": visual_events,
		"visual_event_key": visual_event_key,
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


func _selection_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for entry_variant in value:
		var entry := str(entry_variant).strip_edges()
		if not entry.is_empty() and not result.has(entry):
			result.append(entry)
	return result


func _normalize_temporary_decision(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source: Dictionary = value
	if source.is_empty():
		return {}
	var decision_id := str(source.get("id", "")).strip_edges()
	var decision_kind := str(source.get("kind", "")).strip_edges()
	if decision_id.is_empty() or not REAL_TEMPORARY_DECISION_KINDS.has(decision_kind):
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
	var result := {
		"id": decision_id,
		"kind": decision_kind,
		"title": str(source.get("title", "临时决策")),
		"body": str(source.get("body", source.get("summary", ""))),
		"tooltip": str(source.get("tooltip", "")),
		"chips": normalized_chips,
		"actions": normalized_actions,
		"accent": source.get("accent", Color("#facc15")),
	}
	for key in ["wager", "contract", "choice", "details"]:
		var detail_value: Variant = source.get(key, {})
		if detail_value is Dictionary:
			result[key] = (detail_value as Dictionary).duplicate(true)
	var sections: Variant = source.get("sections", [])
	if sections is Array:
		result["sections"] = (sections as Array).duplicate(true)
	return result


func _normalize_active_forced_decision(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source := value as Dictionary
	var decision_id := str(source.get("id", "")).strip_edges()
	var kind := str(source.get("kind", "")).strip_edges()
	var priority_group := str(source.get("priority_group", "")).strip_edges()
	var presentation_surface := str(source.get("presentation_surface", "")).strip_edges()
	var expected_priority_group := _priority_group_for_decision_kind(kind)
	if decision_id.is_empty() \
		or kind.is_empty() \
		or priority_group.is_empty() \
		or not VALID_FORCED_PRIORITY_GROUPS.has(priority_group) \
		or not VALID_FORCED_PRESENTATION_SURFACES.has(presentation_surface):
		return {}
	if kind == "private_forced_decision":
		if bool(source.get("visible_to_viewer", true)) or presentation_surface != "player_hint":
			return {}
	elif expected_priority_group.is_empty() or priority_group != expected_priority_group:
		return {}
	return {
		"id": decision_id,
		"kind": kind,
		"decision_revision": int(source.get("decision_revision", 0)),
		"priority_group": priority_group,
		"visible_to_viewer": bool(source.get("visible_to_viewer", false)),
		"presentation_surface": presentation_surface,
		"blocks_global_time": bool(source.get("blocks_global_time", false)),
		"blocks_player_actions": bool(source.get("blocks_player_actions", false)),
		"blocks_card_resolution": bool(source.get("blocks_card_resolution", false)),
	}


func _priority_group_for_decision_kind(kind: String) -> String:
	match kind:
		"monster_wager":
			return "monster_wager"
		"counter_response":
			return "counter_response"
		"discard_purchase", "monster_target_choice", "player_target_choice":
			return "other_choice"
		"public_bid", "card_order_bid":
			return "public_bid"
		"private_forced_decision":
			return ""
	return ""


func _normalize_card_resolution_track(source: Dictionary, fallback_entries: Array) -> Dictionary:
	var entries_source: Variant = source.get("entries", fallback_entries)
	var entries: Array = PUBLIC_TRACK_SNAPSHOT_SCRIPT.new().apply_entries(entries_source if entries_source is Array else fallback_entries).to_ui_array()
	var result := {
		"title": str(source.get("title", "公共结算轨")),
		"phase": str(source.get("phase", "等待")),
		"summary": str(source.get("summary", "匿名出牌、竞价、展示和历史线索。")),
		"privacy_hint": str(source.get("privacy_hint", "未公开归属前只显示公开线索。")),
		"empty_text": str(source.get("empty_text", "牌轨空闲，等待玩家出牌。")),
		"auction_open": bool(source.get("auction_open", false)),
		"entries": entries,
	}
	var auction_source: Dictionary = source.get("auction_response", {}) if source.get("auction_response", {}) is Dictionary else {}
	result["auction_response"] = {
		"active": bool(auction_source.get("active", false)),
		"summary": str(auction_source.get("summary", "")),
		"actions": _normalize_card_resolution_actions(auction_source.get("actions", [])),
	}
	for key in ["history_entries", "active_entries", "queue_entries", "next_entries"]:
		var lane_source: Variant = source.get(key, [])
		if lane_source is Array:
			result[key] = PUBLIC_TRACK_SNAPSHOT_SCRIPT.new().apply_entries(lane_source).to_ui_array()
	return result


func _normalize_card_resolution_actions(value: Variant) -> Array:
	var source: Array = value if value is Array else []
	var result: Array = []
	for action_variant in source:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		var action_id := str(action.get("id", action.get("action_id", ""))).strip_edges()
		var label := str(action.get("label", action.get("text", action_id))).strip_edges()
		if action_id == "" and label == "":
			continue
		result.append({
			"id": action_id,
			"label": label if label != "" else action_id,
			"disabled": bool(action.get("disabled", false)),
			"tooltip": str(action.get("tooltip", "")),
			"reason": str(action.get("reason", action.get("disabled_reason", ""))),
			"disabled_reason": str(action.get("disabled_reason", action.get("reason", ""))),
		})
	return result
