@tool
extends Node
class_name AiMilitaryPublicQueryPort

@export var military_runtime_controller_path: NodePath

var _query_count := 0
var _rejected_query_count := 0


func is_ready() -> bool:
	return _military() != null


func public_roster_snapshot() -> Array:
	_query_count += 1
	if not is_ready():
		_rejected_query_count += 1
		return []
	var result: Array = []
	for unit_variant in _military().roster_snapshot(false):
		if unit_variant is Dictionary:
			result.append(_public_unit(unit_variant as Dictionary))
	return TablePresentationPureDataPolicy.detached_copy(result)


func public_unit_by_uid(unit_uid: int) -> Dictionary:
	if unit_uid <= 0:
		return {}
	for unit_variant in public_roster_snapshot():
		var unit := unit_variant as Dictionary
		if int(unit.get("uid", 0)) == unit_uid:
			return unit.duplicate(true)
	return {}


func unit_type_label(unit_or_skill: Dictionary) -> String:
	return _military().unit_type_label(unit_or_skill) if is_ready() else "military"


func can_deploy_at_district(skill: Dictionary, district_index: int) -> bool:
	return is_ready() \
		and TablePresentationPureDataPolicy.is_pure_data(skill) \
		and _military().can_deploy_at_district(skill, district_index)


func terrain_move_multiplier(unit_or_skill: Dictionary, district_index: int) -> float:
	return _military().terrain_move_multiplier(unit_or_skill, district_index) \
		if is_ready() and TablePresentationPureDataPolicy.is_pure_data(unit_or_skill) else 0.0


func mobility_summary(unit_or_skill: Dictionary) -> String:
	return _military().mobility_summary(unit_or_skill) \
		if is_ready() and TablePresentationPureDataPolicy.is_pure_data(unit_or_skill) else ""


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"query_count": _query_count,
		"rejected_query_count": _rejected_query_count,
		"returns_public_roster_only": true,
		"returns_hidden_owner": false,
		"returns_private_target": false,
		"mutates_world": false,
		"consumes_rng": false,
		"references_main": false,
		"owns_state": false,
	}


func _public_unit(source: Dictionary) -> Dictionary:
	var world_position: Variant = source.get("world_position", Vector2.ZERO)
	if not (world_position is Vector2):
		world_position = Vector2.ZERO
	return {
		"uid": int(source.get("uid", 0)),
		"name": str(source.get("name", "military")),
		"rank": int(source.get("rank", 1)),
		"military_type": str(source.get("military_type", "defense")),
		"military_domain": str(source.get("military_domain", "mixed")),
		"movement_traits": _string_values(source.get("movement_traits", [])),
		"terrain_move_multiplier": _numeric_dictionary(source.get("terrain_move_multiplier", {})),
		"position": int(source.get("position", -1)),
		"world_position": world_position,
		"hp": int(source.get("hp", 0)),
		"max_hp": int(source.get("max_hp", source.get("hp", 0))),
		"damage": int(source.get("damage", 0)),
		"range": maxf(0.0, float(source.get("range", 0.0))),
		"move": maxf(0.0, float(source.get("move", 0.0))),
		"remaining_time": maxf(0.0, float(source.get("remaining_time", 0.0))),
		"cooldown_left": maxf(0.0, float(source.get("cooldown_left", 0.0))),
		"public_owner_revealed": bool(source.get("public_owner_revealed", false)),
		"visibility_scope": "public",
	}


func _string_values(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value as Array:
			if item is String or item is StringName:
				var text := str(item).strip_edges()
				if not text.is_empty() and not result.has(text):
					result.append(text)
	return result


func _numeric_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var child: Variant = (value as Dictionary).get(key_variant)
			if child is int or child is float:
				result[str(key_variant)] = child
	return result

func _military() -> MilitaryRuntimeController:
	return get_node_or_null(military_runtime_controller_path) as MilitaryRuntimeController