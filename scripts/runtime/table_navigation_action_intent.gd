extends RefCounted
class_name TableNavigationActionIntent

const KIND_REGION_DETAIL := &"region_detail"
const KIND_CARD_BROWSER := &"card_browser"
const KIND_COMPENDIUM_HUB := &"compendium_hub"
const KIND_CARD_DETAIL := &"card_detail"
const ALLOWED_KINDS := [KIND_REGION_DETAIL, KIND_CARD_BROWSER, KIND_COMPENDIUM_HUB, KIND_CARD_DETAIL]

var request_id := ""
var action_kind: StringName = &""
var source_surface: StringName = &"game_screen"
var target_card_name := ""


static func from_action_id(action_id: String, source: StringName = &"game_screen") -> TableNavigationActionIntent:
	var normalized := action_id.strip_edges()
	var intent := TableNavigationActionIntent.new()
	intent.source_surface = source
	match normalized:
		"codex_region":
			intent.action_kind = KIND_REGION_DETAIL
		"codex_cards":
			intent.action_kind = KIND_CARD_BROWSER
		"inspect":
			intent.action_kind = KIND_COMPENDIUM_HUB
		_:
			if normalized.begins_with("track_open_"):
				intent.action_kind = KIND_CARD_DETAIL
				intent.target_card_name = normalized.substr("track_open_".length()).strip_edges()
			else:
				return null
	return intent


func validation_report() -> Dictionary:
	if request_id.strip_edges().is_empty() or request_id.length() > 128:
		return {"valid": false, "reason_code": "request_id_invalid"}
	if not ALLOWED_KINDS.has(action_kind):
		return {"valid": false, "reason_code": "action_kind_invalid"}
	if String(source_surface).is_empty() or String(source_surface).length() > 80:
		return {"valid": false, "reason_code": "source_surface_invalid"}
	if action_kind == KIND_CARD_DETAIL and target_card_name.strip_edges().is_empty():
		return {"valid": false, "reason_code": "target_card_missing"}
	if target_card_name.length() > 160:
		return {"valid": false, "reason_code": "target_card_invalid"}
	return {"valid": true, "reason_code": "ok"}


func fingerprint() -> String:
	return "%s|%s|%s" % [String(action_kind), String(source_surface), target_card_name]


func to_dictionary() -> Dictionary:
	return {
		"request_id": request_id,
		"action_kind": String(action_kind),
		"source_surface": String(source_surface),
		"target_card_name": target_card_name,
	}


static func from_dictionary(data: Dictionary) -> TableNavigationActionIntent:
	var intent := TableNavigationActionIntent.new()
	intent.request_id = str(data.get("request_id", "")).strip_edges()
	intent.action_kind = StringName(str(data.get("action_kind", "")).strip_edges())
	intent.source_surface = StringName(str(data.get("source_surface", "game_screen")).strip_edges())
	intent.target_card_name = str(data.get("target_card_name", "")).strip_edges()
	return intent
