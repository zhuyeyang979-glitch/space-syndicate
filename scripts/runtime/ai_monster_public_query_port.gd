@tool
extends Node
class_name AiMonsterPublicQueryPort

const MONSTER_CATALOG_V06 := preload("res://scripts/runtime/monster_catalog_v06.gd")

const MonsterCatalog := preload("res://scripts/runtime/monster_catalog_v06.gd")

@export var monster_runtime_controller_path: NodePath
@export var world_session_state_path: NodePath
@export var region_knowledge_query_port_path: NodePath

var _query_count := 0
var _rejected_query_count := 0


func is_ready() -> bool:
	return _monster() != null and _world() != null and _regions() != null and _regions().is_ready()


func public_roster_snapshot() -> Array:
	_query_count += 1
	if not is_ready():
		_rejected_query_count += 1
		return []
	var result: Array = []
	for actor_variant in _monster().roster_snapshot(false):
		if actor_variant is Dictionary:
			result.append(_public_actor(actor_variant as Dictionary))
	return TablePresentationPureDataPolicy.detached_copy(result)


func public_monster_by_uid(monster_uid: int) -> Dictionary:
	if monster_uid <= 0:
		return {}
	for actor_variant in public_roster_snapshot():
		var actor := actor_variant as Dictionary
		if int(actor.get("uid", 0)) == monster_uid:
			return actor.duplicate(true)
	return {}


func public_monster_by_slot(slot_index: int) -> Dictionary:
	if slot_index < 0:
		return {}
	for actor_variant in public_roster_snapshot():
		var actor := actor_variant as Dictionary
		if int(actor.get("slot", -1)) == slot_index:
			return actor.duplicate(true)
	return {}


func slot_for_uid(monster_uid: int) -> int:
	return int(public_monster_by_uid(monster_uid).get("slot", -1))


func active_monster_count() -> int:
	var result := 0
	for actor_variant in public_roster_snapshot():
		if not bool((actor_variant as Dictionary).get("down", false)):
			result += 1
	return result


func active_wager_ids_snapshot() -> Array:
	if not is_ready():
		return []
	var result := _monster().active_wager_ids_snapshot()
	return TablePresentationPureDataPolicy.detached_copy(result) if result is Array else []


func public_catalog_entry(catalog_index: int) -> Dictionary:
	if not is_ready() or catalog_index < 0:
		return {}
	var source := _monster().monster_codex_public_catalog_source_v06(catalog_index)
	var entry: Dictionary = source.get("entry", {}) if source.get("entry", {}) is Dictionary else {}
	return TablePresentationPureDataPolicy.detached_copy(entry)


func public_catalog_snapshot() -> Array:
	if not is_ready():
		return []
	var result: Array = []
	for catalog_index in range(MONSTER_CATALOG_V06.catalog_size()):
		var entry := public_catalog_entry(catalog_index)
		if not entry.is_empty():
			result.append(entry)
	return TablePresentationPureDataPolicy.detached_copy(result)


func can_summon_at_region(skill: Dictionary, district_index: int) -> bool:
	_query_count += 1
	if not is_ready() or not TablePresentationPureDataPolicy.is_pure_data(skill):
		_rejected_query_count += 1
		return false
	var district := _regions().public_region(district_index)
	if district.is_empty() or bool(district.get("destroyed", false)):
		return false
	if bool(skill.get("starter_play_free", false)):
		return true
	var terrain := str(district.get("terrain", "land"))
	match str(skill.get("summon_access", "any")):
		"monster_zone":
			return _monster().summon_zone_available(district_index)
		"land_monster_zone":
			return _monster().summon_zone_available(district_index, "land")
		"ocean_monster_zone":
			return _monster().summon_zone_available(district_index, "ocean")
		"land":
			return terrain == "land"
		"ocean":
			return terrain == "ocean"
		"any", "":
			return true
	return true


func public_expected_damage_score(monster_uid: int) -> int:
	_query_count += 1
	if not is_ready() or monster_uid <= 0:
		_rejected_query_count += 1
		return 0
	return maxi(0, _monster().public_expected_damage_score(monster_uid))


func public_region_attraction_snapshot(district_index: int) -> Dictionary:
	_query_count += 1
	if not is_ready():
		_rejected_query_count += 1
		return {}
	var snapshot := _monster().region_attraction_public_snapshot_v06(district_index)
	if not TablePresentationPureDataPolicy.is_pure_data(snapshot):
		_rejected_query_count += 1
		return {}
	return TablePresentationPureDataPolicy.detached_copy(snapshot)


func public_resource_match_score(monster_uid: int, district_index: int) -> int:
	return public_resource_match_score_for_actor(public_monster_by_uid(monster_uid), district_index)


func public_resource_match_score_for_actor(actor: Dictionary, district_index: int) -> int:
	var district := _regions().public_region(district_index) if is_ready() else {}
	if actor.is_empty() or district.is_empty() \
			or not TablePresentationPureDataPolicy.is_pure_data(actor):
		return 0
	var focus: Array = actor.get("resource_focus", []) if actor.get("resource_focus", []) is Array else []
	var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
	var district_products := _string_values(district.get("products", []))
	var district_demands := _string_values(district.get("demands", []))
	var city_products := _string_values(city.get("product_names", city.get("products", [])))
	var city_demands := _string_values(city.get("demand_names", city.get("demands", [])))
	var public_route_products := _string_values(city.get("active_trade_route_products", []))
	var score := 0
	for product_variant in focus:
		var product_id := str(product_variant)
		if district_products.has(product_id):
			score += 1
		if district_demands.has(product_id):
			score += 1
		if city_products.has(product_id):
			score += 2
		if city_demands.has(product_id):
			score += 1
		if public_route_products.has(product_id):
			score += 1
	return mini(score, 8)


func public_distance_to_region(monster_uid: int, district_index: int) -> float:
	var actor := public_monster_by_uid(monster_uid)
	var district := _regions().public_region(district_index) if is_ready() else {}
	if actor.is_empty() or district.is_empty():
		return INF
	return public_distance_between_entities(actor, {"world_position": district.get("center", Vector2.ZERO)})


func public_distance_between_entities(left: Dictionary, right: Dictionary) -> float:
	if not TablePresentationPureDataPolicy.is_pure_data(left) \
			or not TablePresentationPureDataPolicy.is_pure_data(right):
		return INF
	var from_position := _entity_position(left)
	var to_position := _entity_position(right)
	return _spherical_distance(from_position, to_position)


func meters_text(value: float) -> String:
	return MonsterCatalog.meters_text(value)


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"query_count": _query_count,
		"rejected_query_count": _rejected_query_count,
		"returns_public_roster_only": true,
		"returns_public_catalog": true,
		"returns_hidden_owner": false,
		"returns_owner_damage_cash_pool": false,
		"returns_private_target": false,
		"resource_match_uses_public_facts_only": true,
		"summon_legality_uses_public_region_facts": true,
		"expected_damage_owned_by_monster_runtime": true,
		"region_attraction_returns_public_evidence_only": true,
		"mutates_world": false,
		"consumes_rng": false,
		"references_main": false,
		"owns_state": false,
	}


func _public_actor(source: Dictionary) -> Dictionary:
	var world_position := _entity_position(source)
	var result := {
		"uid": int(source.get("uid", 0)),
		"slot": int(source.get("slot", -1)),
		"catalog_index": int(source.get("catalog_index", -1)),
		"name": str(source.get("name", "monster")),
		"rank": int(source.get("rank", 1)),
		"hp": int(source.get("hp", 0)),
		"max_hp": int(source.get("max_hp", 0)),
		"armor": int(source.get("armor", 0)),
		"guard": int(source.get("guard", 0)),
		"ranged_guard": int(source.get("ranged_guard", 0)),
		"tether": int(source.get("tether", 0)),
		"remaining_time": maxf(0.0, float(source.get("remaining_time", 0.0))),
		"move": maxf(0.0, float(source.get("move", 0.0))),
		"position": int(source.get("position", -1)),
		"world_position": world_position,
		"down": bool(source.get("down", false)),
		"bracelet_active": bool(source.get("bracelet_active", false)),
		"weather_resistance": clampf(float(source.get("weather_resistance", 0.0)), 0.0, 1.0),
		"weather_exploitation_multiplier": maxf(1.0, float(source.get("weather_exploitation_multiplier", 1.0))),
		"owner_revealed": bool(source.get("owner_revealed", false)),
		"resource_focus": _string_values(source.get("resource_focus", [])),
		"movement_traits": _string_values(source.get("movement_traits", [])),
		"terrain_move_multiplier": _numeric_dictionary(source.get("terrain_move_multiplier", {})),
		"actor_revision": int(source.get("actor_revision_v06", 0)),
		"visibility_scope": "public",
	}
	return result


func _entity_position(source: Dictionary) -> Vector2:
	var value: Variant = source.get("world_position", Vector2.ZERO)
	if value is Vector2:
		return value
	if value is Dictionary:
		return Vector2(float((value as Dictionary).get("x", 0.0)), float((value as Dictionary).get("y", 0.0)))
	return Vector2.ZERO


func _spherical_distance(from_position: Vector2, to_position: Vector2) -> float:
	var geometry := _world().public_world_geometry_snapshot()
	var width := maxf(1.0, float(geometry.get("width_m", 1.0)))
	var height := maxf(1.0, float(geometry.get("height_m", 1.0)))
	var from_unit := _sphere_unit(from_position, width, height)
	var to_unit := _sphere_unit(to_position, width, height)
	return acos(clampf(from_unit.dot(to_unit), -1.0, 1.0)) * maxf(1.0, width / TAU)


func _sphere_unit(position: Vector2, width: float, height: float) -> Vector3:
	var longitude := fposmod(position.x, width) / width * TAU
	var latitude := PI * 0.5 - clampf(position.y, 0.0, height) / height * PI
	return Vector3(
		cos(latitude) * cos(longitude),
		sin(latitude),
		cos(latitude) * sin(longitude)
	).normalized()


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


func _monster() -> MonsterRuntimeController:
	return get_node_or_null(monster_runtime_controller_path) as MonsterRuntimeController


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _regions() -> AiRegionKnowledgeQueryPort:
	return get_node_or_null(region_knowledge_query_port_path) as AiRegionKnowledgeQueryPort