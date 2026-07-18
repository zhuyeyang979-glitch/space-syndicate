@tool
extends Node
class_name RegionCodexPublicSourceService

const SOURCE_ADAPTER_SCRIPT := preload("res://scripts/runtime/region_codex_public_source_adapter.gd")
const DEPENDENCY_KEYS := ["monster", "region_public_bridge", "route", "snapshot", "weather"]

var _region_public_bridge: Node
var _monster: Node
var _weather: Node
var _route: Node
var _snapshot: Node
var _adapter: RefCounted = SOURCE_ADAPTER_SCRIPT.new()
var _configured := false
var _last_error := "dependencies_not_configured"
var _compose_count := 0


func configure(dependencies: Dictionary) -> Dictionary:
	_clear_dependencies()
	var keys := dependencies.keys()
	keys.sort()
	var expected := DEPENDENCY_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		_last_error = "dependency_keys_invalid"
		return {"configured": false, "reason_code": _last_error}
	_region_public_bridge = dependencies.get("region_public_bridge") as Node
	_monster = dependencies.get("monster") as Node
	_weather = dependencies.get("weather") as Node
	_route = dependencies.get("route") as Node
	_snapshot = dependencies.get("snapshot") as Node
	if _region_public_bridge == null or not _region_public_bridge.has_method("region_codex_public_facts"):
		_last_error = "region_public_bridge_invalid"
		_clear_dependencies()
		return {"configured": false, "reason_code": _last_error}
	if _monster == null or not _monster.has_method("region_attraction_public_snapshot_v06"):
		_last_error = "monster_public_owner_invalid"
		_clear_dependencies()
		return {"configured": false, "reason_code": _last_error}
	if _weather == null or not _weather.has_method("district_summary"):
		_last_error = "weather_public_owner_invalid"
		_clear_dependencies()
		return {"configured": false, "reason_code": _last_error}
	if _route == null or not _route.has_method("route_load_for_legacy_region"):
		_last_error = "route_public_owner_invalid"
		_clear_dependencies()
		return {"configured": false, "reason_code": _last_error}
	if _snapshot == null or not _snapshot.has_method("compose_region"):
		_last_error = "snapshot_service_invalid"
		_clear_dependencies()
		return {"configured": false, "reason_code": _last_error}
	_configured = true
	_last_error = ""
	return {"configured": true, "reason_code": "region_codex_public_source_ready"}


func compose_source(region_index: int) -> Dictionary:
	if not _require_ready():
		return {}
	var region_variant: Variant = _region_public_bridge.call("region_codex_public_facts", region_index)
	if not (region_variant is Dictionary):
		_last_error = "region_public_facts_invalid"
		return {}
	var region_facts := (region_variant as Dictionary).duplicate(true)
	if not bool(_adapter.call("accepts_public_input", region_facts)) or not bool(region_facts.get("available", false)):
		_last_error = "region_public_facts_rejected"
		return {}
	var monster_variant: Variant = _monster.call("region_attraction_public_snapshot_v06", region_index)
	if not (monster_variant is Dictionary):
		_last_error = "monster_public_facts_invalid"
		return {}
	var monster_facts := (monster_variant as Dictionary).duplicate(true)
	if not bool(monster_facts.get("available", false)) or int(monster_facts.get("region_index", -1)) != region_index:
		_last_error = "monster_public_region_mismatch"
		return {}
	var weather_variant: Variant = _weather.call("district_summary", region_index)
	if not (weather_variant is String or weather_variant is StringName):
		_last_error = "weather_public_summary_invalid"
		return {}
	var route_variant: Variant = _route.call("route_load_for_legacy_region", region_index)
	if not (route_variant is int) or int(route_variant) < 0:
		_last_error = "route_public_load_invalid"
		return {}
	var value: Variant = _adapter.call("compose_source", region_facts, monster_facts, str(weather_variant), int(route_variant))
	var source := (value as Dictionary).duplicate(true) if value is Dictionary else {}
	if source.is_empty():
		_last_error = "public_source_rejected"
		return {}
	_compose_count += 1
	_last_error = ""
	return source


func compose_region(region_index: int) -> Dictionary:
	var source := compose_source(region_index)
	if source.is_empty():
		return {}
	var value: Variant = _snapshot.call("compose_region", source)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func public_region_count() -> int:
	if not _require_ready():
		return 0
	var value: Variant = _region_public_bridge.call("region_codex_public_facts", 0)
	var facts := value as Dictionary if value is Dictionary else {}
	return maxi(0, int(facts.get("total", 0)))


func stable_item_id_at(region_index: int) -> String:
	return "region:%d" % region_index if region_index >= 0 and region_index < public_region_count() else ""


func index_for_stable_item_id(item_id: String) -> int:
	if not item_id.begins_with("region:"):
		return -1
	var suffix := item_id.trim_prefix("region:")
	if not suffix.is_valid_int():
		return -1
	var region_index := int(suffix)
	return region_index if region_index >= 0 and region_index < public_region_count() else -1


func public_field_schema() -> Dictionary:
	var value: Variant = _adapter.call("public_field_schema")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func debug_snapshot() -> Dictionary:
	var adapter_debug: Dictionary = _adapter.call("debug_snapshot") as Dictionary
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"last_error": _last_error,
		"compose_count": _compose_count,
		"dependency_allowlist": DEPENDENCY_KEYS.duplicate(),
		"dependency_count": DEPENDENCY_KEYS.size() if _configured else 0,
		"owns_public_source_assembly": true,
		"owns_rules": false,
		"owns_save_state": false,
		"has_save_api": false,
		"reads_world_bridge_raw_state": false,
		"reads_viewer_state": false,
		"reads_private_player_state": false,
		"uses_region_public_projection_only": _region_public_bridge != null,
		"uses_monster_public_projection_only": _monster != null,
		"uses_existing_region_formatter": _snapshot != null,
		"commodity_flow_aggregate_omitted": true,
		"contract_aggregate_omitted": true,
		"adapter": adapter_debug.duplicate(true),
	}


func _require_ready() -> bool:
	if _configured:
		return true
	_last_error = "dependencies_not_configured"
	return false


func _clear_dependencies() -> void:
	_region_public_bridge = null
	_monster = null
	_weather = null
	_route = null
	_snapshot = null
	_configured = false
