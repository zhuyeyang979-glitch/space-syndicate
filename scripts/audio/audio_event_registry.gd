extends RefCounted
class_name AudioEventRegistry

const DEFAULT_MAP_PATH := "res://data/audio/audio_event_map.json"
const COMMERCIAL_CONTRACT_PATH := "res://resources/audio/commercial/commercial_audio_event_map.json"

var events: Dictionary = {}
var aliases: Dictionary = {}
var _commercial_contract_ready := false
var _commercial_event_count := 0
var _last_failure_reason := "not_loaded"


func load_default() -> void:
	load_from_file(DEFAULT_MAP_PATH)
	load_commercial_contract(COMMERCIAL_CONTRACT_PATH)


func load_from_file(path: String) -> void:
	events.clear()
	aliases.clear()
	_commercial_contract_ready = false
	_commercial_event_count = 0
	_last_failure_reason = "router_parse_failed"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return
	for event_id_variant in (parsed as Dictionary).keys():
		var event_id := str(event_id_variant).strip_edges()
		var row_variant: Variant = (parsed as Dictionary).get(event_id_variant)
		if event_id.is_empty() or not (row_variant is Dictionary):
			continue
		var row := (row_variant as Dictionary).duplicate(true)
		var mode := str(row.get("mode", "silent"))
		if mode == "alias":
			var canonical_id := str(row.get("canonical_id", "")).strip_edges()
			if not canonical_id.is_empty():
				aliases[event_id] = canonical_id
		elif mode == "contract":
			row["mode"] = "silent"
			row["contract_pending"] = true
		row["router_mode"] = mode
		row["canonical_id"] = str(row.get("canonical_id", event_id))
		events[event_id] = row
	_last_failure_reason = "commercial_contract_not_loaded"


func load_commercial_contract(path: String = COMMERCIAL_CONTRACT_PATH) -> bool:
	_reset_commercial_routes()
	_commercial_contract_ready = false
	_commercial_event_count = 0
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		_last_failure_reason = "commercial_contract_parse_failed"
		return false
	var contract: Dictionary = parsed
	if int(contract.get("schema_version", 0)) != 1 \
			or str(contract.get("contract_id", "")) != "space_syndicate.commercial_audio.events.v1" \
			or not bool(contract.get("presentation_only", false)) \
			or bool(contract.get("randomize", true)) \
			or int(contract.get("rules_rng_draw_count", -1)) != 0:
		_last_failure_reason = "commercial_contract_header_invalid"
		return false
	var rows_variant: Variant = contract.get("events", [])
	if not (rows_variant is Array):
		_last_failure_reason = "commercial_contract_events_invalid"
		return false
	var seen: Dictionary = {}
	var staged_definitions: Dictionary = {}
	for row_variant in rows_variant as Array:
		if not (row_variant is Dictionary):
			_last_failure_reason = "commercial_contract_row_invalid"
			return false
		var row: Dictionary = row_variant
		var event_id := str(row.get("event_id", "")).strip_edges()
		var asset_key := str(row.get("asset_key", "")).strip_edges()
		var volume_db := float(row.get("gain_db", NAN))
		if event_id.is_empty() or asset_key.is_empty() or seen.has(event_id) \
				or not is_finite(volume_db) or not events.has(event_id):
			_last_failure_reason = "commercial_contract_binding_invalid"
			return false
		seen[event_id] = true
		var definition: Dictionary = (events[event_id] as Dictionary).duplicate(true)
		definition["mode"] = "commercial"
		definition["canonical_id"] = event_id
		definition["asset_key"] = asset_key
		definition["volume_db"] = volume_db
		definition["loop"] = bool(row.get("loop", false))
		definition["contract_id"] = str(contract.get("contract_id", ""))
		definition.erase("contract_pending")
		staged_definitions[event_id] = definition
	if seen.size() != 17:
		_last_failure_reason = "commercial_contract_count_invalid"
		return false
	for event_id_variant in staged_definitions.keys():
		events[event_id_variant] = staged_definitions[event_id_variant]
	_commercial_event_count = staged_definitions.size()
	_commercial_contract_ready = true
	_last_failure_reason = ""
	return true


func has_event(event_id: String) -> bool:
	return events.has(event_id.strip_edges())


func event_definition(event_id: String) -> Dictionary:
	var requested_id := event_id.strip_edges()
	var raw_variant: Variant = events.get(requested_id)
	if not (raw_variant is Dictionary):
		return _silent_definition(requested_id, requested_id, false)
	var raw: Dictionary = raw_variant
	if str(raw.get("mode", "silent")) != "alias":
		return _public_definition(raw, requested_id, requested_id, false)
	var canonical_id := str(raw.get("canonical_id", aliases.get(requested_id, ""))).strip_edges()
	var canonical_variant: Variant = events.get(canonical_id)
	if not (canonical_variant is Dictionary):
		return _silent_definition(requested_id, canonical_id, true)
	return _public_definition(canonical_variant as Dictionary, requested_id, canonical_id, true)


func canonical_event_id(event_id: String) -> String:
	return str(event_definition(event_id).get("canonical_id", event_id.strip_edges()))


func supported_event_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in events.keys():
		ids.append(str(key))
	ids.sort()
	return ids


func canonical_event_ids() -> Array[String]:
	var ids: Array[String] = []
	for event_id_variant in events.keys():
		var event_id := str(event_id_variant)
		var row: Dictionary = events[event_id]
		if str(row.get("mode", "")) != "alias":
			ids.append(event_id)
	ids.sort()
	return ids


func commercial_contract_ready() -> bool:
	return _commercial_contract_ready


func validation_report() -> Dictionary:
	return {
		"valid": _commercial_contract_ready,
		"commercial_contract_ready": _commercial_contract_ready,
		"commercial_event_count": _commercial_event_count,
		"legacy_alias_count": aliases.size(),
		"supported_event_count": events.size(),
		"last_failure_reason": _last_failure_reason,
		"contains_resource_paths": _contains_resource_path(),
		"presentation_only": true,
		"rules_rng_draw_count": 0,
	}


func _public_definition(source: Dictionary, requested_id: String, canonical_id: String, legacy_alias: bool) -> Dictionary:
	var mode := str(source.get("mode", "silent"))
	if mode != "commercial":
		mode = "silent"
	return {
		"requested_id": requested_id,
		"canonical_id": canonical_id,
		"legacy_alias": legacy_alias,
		"mode": mode,
		"category": str(source.get("category", "unknown")),
		"asset_key": str(source.get("asset_key", "")) if mode == "commercial" else "",
		"volume_db": float(source.get("volume_db", 0.0)) if mode == "commercial" else 0.0,
		"loop": bool(source.get("loop", false)) if mode == "commercial" else false,
	}


func _silent_definition(requested_id: String, canonical_id: String, legacy_alias: bool) -> Dictionary:
	return {
		"requested_id": requested_id,
		"canonical_id": canonical_id,
		"legacy_alias": legacy_alias,
		"mode": "silent",
		"category": "unknown",
		"asset_key": "",
		"volume_db": 0.0,
		"loop": false,
	}


func _contains_resource_path() -> bool:
	for event_id_variant in events.keys():
		if JSON.stringify(events[event_id_variant]).contains("res://"):
			return true
	return false


func _reset_commercial_routes() -> void:
	for event_id_variant in events.keys():
		var row_variant: Variant = events[event_id_variant]
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = (row_variant as Dictionary).duplicate(true)
		if str(row.get("router_mode", "")) != "contract":
			continue
		row["mode"] = "silent"
		row["contract_pending"] = true
		row.erase("asset_key")
		row.erase("volume_db")
		row.erase("loop")
		row.erase("contract_id")
		events[event_id_variant] = row
