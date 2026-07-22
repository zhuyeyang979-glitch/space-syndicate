@tool
extends Node
class_name AiRegionKnowledgeQueryPort

const PUBLIC_DISTRICT_KEYS := [
	"region_id",
	"name",
	"center",
	"polygon",
	"area_m2",
	"radius_m",
	"destroyed",
	"miasma",
	"terrain",
	"terrain_label",
	"products",
	"demands",
	"neighbors",
	"transport_score",
	"damage",
	"panic",
]
const PUBLIC_CITY_KEYS := [
	"active",
	"level",
	"products",
	"demands",
	"last_income",
	"competition_matches",
	"trade_disrupted_routes",
	"trade_route_damage",
	"trade_routes",
	"public_clues",
	"last_public_clue",
]

@export var world_session_state_path: NodePath

var _capability: AiRegionKnowledgeCapability
var _capability_revision := 0
var _public_query_count := 0
var _private_query_count := 0
var _rejected_query_count := 0


func bind_ai_capability(capability: AiRegionKnowledgeCapability) -> void:
	_capability = capability
	_capability_revision += 1


func is_ready() -> bool:
	return _world() != null and _capability != null


func region_count() -> int:
	_public_query_count += 1
	return _world().districts.size() if _world() != null else 0


func public_regions_snapshot() -> Array:
	_public_query_count += 1
	return _project_regions(-1, {})


func regions_for_actor(
	capability: AiRegionKnowledgeCapability,
	actor_index: int
) -> Array:
	_private_query_count += 1
	if not _authorized(capability, actor_index):
		_rejected_query_count += 1
		return []
	var inference := _world().city_inference_projection(actor_index)
	var guesses := _inference_by_district(inference)
	return _project_regions(actor_index, guesses)


func region_for_actor(
	capability: AiRegionKnowledgeCapability,
	actor_index: int,
	district_index: int
) -> Dictionary:
	var rows := regions_for_actor(capability, actor_index)
	if district_index < 0 or district_index >= rows.size() or not (rows[district_index] is Dictionary):
		return {}
	return (rows[district_index] as Dictionary).duplicate(true)


func public_region(district_index: int) -> Dictionary:
	var rows := public_regions_snapshot()
	if district_index < 0 or district_index >= rows.size() or not (rows[district_index] is Dictionary):
		return {}
	return (rows[district_index] as Dictionary).duplicate(true)


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"capability_revision": _capability_revision,
		"public_query_count": _public_query_count,
		"private_query_count": _private_query_count,
		"rejected_query_count": _rejected_query_count,
		"hidden_owner_truth_exposed": false,
		"rival_private_economy_exposed": false,
		"future_supply_bag_exposed": false,
		"mutable_world_collection_exposed": false,
		"references_main": false,
	}


func _project_regions(actor_index: int, guesses: Dictionary) -> Array:
	var result: Array = []
	if _world() == null:
		return result
	for district_index in range(_world().districts.size()):
		var source: Dictionary = _world().districts[district_index] \
			if _world().districts[district_index] is Dictionary else {}
		var row := _allowlist(source, PUBLIC_DISTRICT_KEYS)
		row["district_index"] = district_index
		row["region_index"] = district_index
		row["region_id"] = str(source.get("region_id", "region.%03d" % district_index))
		var raw_city: Dictionary = source.get("city", {}) if source.get("city", {}) is Dictionary else {}
		row["city"] = _project_city(raw_city, district_index, actor_index, guesses)
		row["visibility_scope"] = "actor_scoped" if actor_index >= 0 else "public"
		if not _pure(row):
			row = {
				"district_index": district_index,
				"region_index": district_index,
				"region_id": str(source.get("region_id", "region.%03d" % district_index)),
				"name": str(source.get("name", "区域%d" % (district_index + 1))),
				"destroyed": bool(source.get("destroyed", false)),
				"city": {},
				"visibility_scope": "actor_scoped" if actor_index >= 0 else "public",
			}
		result.append(_copy(row))
	return result


func _project_city(
	source: Dictionary,
	district_index: int,
	actor_index: int,
	guesses: Dictionary
) -> Dictionary:
	if source.is_empty():
		return {}
	var result := _allowlist(source, PUBLIC_CITY_KEYS)
	result["present"] = true
	result["owner"] = -1
	result["owner_knowledge"] = "public_unknown"
	if actor_index >= 0:
		var actual_owner := int(source.get("owner", -1))
		if actual_owner == actor_index:
			result["owner"] = actor_index
			result["owner_knowledge"] = "actor_own"
		elif guesses.has(district_index):
			var inference := guesses[district_index] as Dictionary
			result["owner"] = int(inference.get("suspected_player_index", -1))
			result["owner_knowledge"] = "authorized_reveal" \
				if bool(inference.get("authorized_reveal", false)) else "actor_guess"
			result["owner_confidence"] = int(inference.get("confidence", 0))
			result["owner_reason_id"] = str(inference.get("reason_id", ""))
	return result


func _inference_by_district(projection: Dictionary) -> Dictionary:
	var result := {}
	for row_variant in projection.get("records", []) as Array:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		var district_index := int(row.get("district_index", -1))
		if district_index >= 0:
			result[district_index] = row.duplicate(true)
	return result


func _authorized(capability: AiRegionKnowledgeCapability, actor_index: int) -> bool:
	return capability != null \
		and capability == _capability \
		and _world() != null \
		and actor_index >= 0 \
		and actor_index < _world().players.size() \
		and _world().players[actor_index] is Dictionary \
		and (bool((_world().players[actor_index] as Dictionary).get("is_ai", false)) \
			or str((_world().players[actor_index] as Dictionary).get("seat_type", "human")) == "ai")


func _allowlist(source: Dictionary, keys: Array) -> Dictionary:
	var result := {}
	for key_variant in keys:
		var key := str(key_variant)
		if source.has(key) and _pure(source[key]):
			result[key] = _copy(source[key])
	return result


func _copy(value: Variant) -> Variant:
	return TablePresentationPureDataPolicy.detached_copy(value)


func _pure(value: Variant) -> bool:
	return TablePresentationPureDataPolicy.is_pure_data(value)


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState
