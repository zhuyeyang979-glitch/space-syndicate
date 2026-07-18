extends RefCounted
class_name ProductCodexPublicSourceAdapter

const FORBIDDEN_KEYS := {
	"viewer": true,
	"viewer_index": true,
	"selected_player": true,
	"selected_district": true,
	"player": true,
	"players": true,
	"player_index": true,
	"cash": true,
	"hand": true,
	"discard": true,
	"private_inventory": true,
	"owner": true,
	"owner_id": true,
	"owner_index": true,
	"owner_player_index": true,
	"hidden_owner": true,
	"hidden_owner_id": true,
	"city_guesses": true,
	"private_clue": true,
	"private_plan": true,
	"ai_plan": true,
	"ai_private_plan": true,
	"ai_route_plan": true,
	"quote": true,
	"quote_id": true,
	"quote_fingerprint": true,
	"camera": true,
	"view_center": true,
	"view_zoom": true,
	"solar": true,
	"sun_phase": true,
	"world_bridge": true,
	"raw_world": true,
}

const PRIVATE_VALUE_SENTINELS := [
	"PRIVATE_SENTINEL",
	"private_sentinel",
	"hidden_owner",
	"owner_player_index",
	"city_guess",
	"ai_private",
	"ai_plan",
	"quote_fingerprint",
	"secret",
]

const TOP_LEVEL_KEYS := [
	"valid",
	"unavailable_reason",
	"index",
	"total",
	"selected",
	"name",
	"profile",
	"market",
	"strategy_rankings",
	"monster_focus_names",
	"related_card_names",
	"supply_district_names",
	"demand_district_names",
	"public_clue_lines",
	"public_clue_labels",
]


func accepts_public_input(value: Variant) -> bool:
	return _is_public_value(value)


func compose_source(source: Dictionary) -> Dictionary:
	if not _is_public_value(source):
		return {}
	if not bool(source.get("valid", false)):
		return {"valid": false, "name": str(source.get("name", "")), "index": int(source.get("index", -1)), "total": maxi(0, int(source.get("total", 0)))}
	if str(source.get("name", "")).strip_edges().is_empty():
		return {}
	var result := {}
	for key in TOP_LEVEL_KEYS:
		if source.has(key):
			result[key] = _public_duplicate(source[key])
	result["valid"] = true
	result["index"] = maxi(0, int(result.get("index", 0)))
	result["total"] = maxi(1, int(result.get("total", 1)))
	result["selected"] = bool(result.get("selected", false))
	result["name"] = str(result.get("name", ""))
	result["profile"] = _dictionary(result.get("profile", {})).duplicate(true)
	result["market"] = _dictionary(result.get("market", {})).duplicate(true)
	result["strategy_rankings"] = _array(result.get("strategy_rankings", [])).duplicate(true)
	result["monster_focus_names"] = _string_array(result.get("monster_focus_names", []))
	result["related_card_names"] = _string_array(result.get("related_card_names", []))
	result["supply_district_names"] = _string_array(result.get("supply_district_names", []))
	result["demand_district_names"] = _string_array(result.get("demand_district_names", []))
	result["public_clue_lines"] = _string_array(result.get("public_clue_lines", []))
	result["public_clue_labels"] = _string_array(result.get("public_clue_labels", []))
	return result


func compose_browser_source(request: Dictionary, entries: Array, preview: Dictionary, summaries: Array) -> Dictionary:
	if not _is_public_value(request) or not _is_public_value(entries) or not _is_public_value(preview) or not _is_public_value(summaries):
		return {}
	return {
		"columns": clampi(int(request.get("columns", 3)), 1, 6),
		"selected_index": maxi(0, int(request.get("selected_index", 0))),
		"can_page": bool(request.get("can_page", false)),
		"page_label": str(request.get("page_label", "")),
		"summary_text": str(request.get("summary_text", "")),
		"summaries": summaries.duplicate(true),
		"entries": entries.duplicate(true),
		"preview": preview.duplicate(true),
	}


func public_field_schema() -> Dictionary:
	return {
		"top_level": TOP_LEVEL_KEYS.duplicate(),
		"forbidden_keys": FORBIDDEN_KEYS.keys(),
		"private_value_sentinels": PRIVATE_VALUE_SENTINELS.duplicate(),
	}


func debug_snapshot() -> Dictionary:
	return {
		"adapter_ready": true,
		"reads_runtime_nodes": false,
		"reads_world_bridge": false,
		"reads_player_state": false,
		"reads_private_inventory": false,
		"reads_ai_plan": false,
		"reads_market_quote": false,
		"reads_camera": false,
		"reads_solar": false,
		"owns_rules": false,
		"owns_save_state": false,
	}


func _is_public_value(value: Variant) -> bool:
	if value == null or value is bool or value is int or value is float or value is Color:
		return true
	if value is String or value is StringName:
		var text := str(value)
		for sentinel in PRIVATE_VALUE_SENTINELS:
			if text.findn(str(sentinel)) >= 0:
				return false
		return true
	if value is Array:
		for item: Variant in value:
			if not _is_public_value(item):
				return false
		return true
	if value is Dictionary:
		for key_variant: Variant in value:
			var key := str(key_variant)
			if FORBIDDEN_KEYS.has(key.to_lower()):
				return false
			if not _is_public_value(key_variant) or not _is_public_value(value[key_variant]):
				return false
		return true
	return false


func _public_duplicate(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return value as Array if value is Array else []


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for item: Variant in value as Array:
		var text := str(item).strip_edges()
		if text != "":
			result.append(text)
	return result
