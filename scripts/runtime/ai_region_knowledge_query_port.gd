@tool
extends Node
class_name AiRegionKnowledgeQueryPort

const PUBLIC_DISTRICT_FACTS_SCHEMA_VERSION := 1
const PUBLIC_DISTRICT_FACT_KEYS := [
	"schema_version",
	"source_revision",
	"fingerprint",
	"visibility_scope",
	"district_index",
	"region_index",
	"region_id",
	"name",
	"destroyed",
	"terrain",
	"products",
	"demands",
	"neighbors",
	"city",
]
const PUBLIC_DISTRICT_CITY_FACT_KEYS := [
	"present",
	"active",
	"product_names",
	"demand_names",
]
const ACTOR_CITY_AUTHORIZATION_SCHEMA_VERSION := 1
const ACTOR_CITY_AUTHORIZATION_FACT_KEYS := [
	"schema_version",
	"visibility_scope",
	"actor_index",
	"district_index",
	"region_id",
	"present",
	"active",
	"perceived_owner_index",
	"owner_knowledge",
	"confidence",
	"reason_id",
	"reason_kind",
	"authorized_reveal",
	"owner_revision",
	"fingerprint",
]
const ACTOR_CITY_OWNER_KNOWLEDGE_VALUES := [
	"public_unknown",
	"actor_own",
	"actor_guess",
	"authorized_reveal",
]

@export var world_session_state_path: NodePath
@export var commodity_flow_runtime_controller_path: NodePath

var _capability: AiRegionKnowledgeCapability
var _capability_revision := 0
var _public_query_count := 0
var _private_query_count := 0
var _rejected_query_count := 0


func bind_ai_capability(capability: AiRegionKnowledgeCapability) -> void:
	_capability = capability
	_capability_revision += 1


func is_ready() -> bool:
	return _world() != null and _commodity_flow() != null and _capability != null


func public_district_facts_ready() -> bool:
	return _world() != null


func public_district_facts_snapshot() -> Array:
	if not public_district_facts_ready():
		return []
	var base_rows: Array = []
	for district_index in range(_world().districts.size()):
		if not (_world().districts[district_index] is Dictionary):
			return []
		var row := _project_public_district_fact_row(
			_world().districts[district_index] as Dictionary,
			district_index
		)
		if row.is_empty():
			return []
		base_rows.append(row)
	var source_revision := JSON.stringify([
		"ai_public_district_facts_v1",
		base_rows,
	]).sha256_text()
	var result: Array = []
	for row_variant in base_rows:
		var row := (row_variant as Dictionary).duplicate(true)
		row["source_revision"] = source_revision
		row["fingerprint"] = JSON.stringify([
			"ai_public_district_fact_row_v1",
			source_revision,
			int(row.get("district_index", -1)),
		]).sha256_text()
		if row.keys() != PUBLIC_DISTRICT_FACT_KEYS or not _pure(row):
			return []
		result.append(_copy(row))
	return result


func public_district_fact(district_index: int) -> Dictionary:
	var rows := public_district_facts_snapshot()
	if district_index < 0 or district_index >= rows.size() or not (rows[district_index] is Dictionary):
		return {}
	return (rows[district_index] as Dictionary).duplicate(true)


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
	var snapshot := actor_intelligence_snapshot(capability, actor_index)
	return (snapshot.get("regions", []) as Array).duplicate(true) \
		if snapshot.get("regions", []) is Array else []


func actor_intelligence_snapshot(
	capability: AiRegionKnowledgeCapability,
	actor_index: int
) -> Dictionary:
	_private_query_count += 1
	if not _authorized(capability, actor_index):
		_rejected_query_count += 1
		return {}
	var inference := _world().city_inference_projection(actor_index)
	var guesses := _inference_by_district(inference)
	var result := {
		"schema_version": 1,
		"visibility_scope": "actor_private",
		"actor_index": actor_index,
		"owner_revision": str(inference.get("owner_revision", "")),
		"rules": inference_rules_snapshot(),
		"regions": _project_regions(actor_index, guesses),
	}
	if not _pure(result):
		_rejected_query_count += 1
		return {}
	return _copy(result)


func actor_city_authorization_snapshot(
	capability: AiRegionKnowledgeCapability,
	actor_index: int
) -> Array:
	_private_query_count += 1
	if not _authorized(capability, actor_index):
		_rejected_query_count += 1
		return []
	var inference := _world().city_inference_projection(actor_index)
	var guesses := _inference_by_district(inference)
	var owner_revision := str(inference.get("owner_revision", ""))
	var result: Array = []
	for district_index in range(_world().districts.size()):
		if not (_world().districts[district_index] is Dictionary):
			_rejected_query_count += 1
			return []
		var district := _world().districts[district_index] as Dictionary
		var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
		var authorization := _actor_city_owner_authorization(city, district_index, actor_index, guesses)
		var row := {
			"schema_version": ACTOR_CITY_AUTHORIZATION_SCHEMA_VERSION,
			"visibility_scope": "actor_private",
			"actor_index": actor_index,
			"district_index": district_index,
			"region_id": _string_scalar(district.get("region_id", ""), "region.%03d" % district_index),
			"present": not city.is_empty(),
			"active": not city.is_empty() and _bool_scalar(city.get("active", true), true),
			"perceived_owner_index": int(authorization.get("perceived_owner_index", -1)),
			"owner_knowledge": str(authorization.get("owner_knowledge", "public_unknown")),
			"confidence": int(authorization.get("confidence", 0)),
			"reason_id": str(authorization.get("reason_id", "")),
			"reason_kind": str(authorization.get("reason_kind", "none")),
			"authorized_reveal": bool(authorization.get("authorized_reveal", false)),
			"owner_revision": owner_revision,
			"fingerprint": "",
		}
		row["fingerprint"] = JSON.stringify([
			"ai_actor_city_authorization_v1",
			row,
		]).sha256_text()
		if row.keys() != ACTOR_CITY_AUTHORIZATION_FACT_KEYS or not _pure(row):
			_rejected_query_count += 1
			return []
		result.append(_copy(row))
	return result


func actor_city_authorization_for_district(
	capability: AiRegionKnowledgeCapability,
	actor_index: int,
	district_index: int
) -> Dictionary:
	for row_variant in actor_city_authorization_snapshot(capability, actor_index):
		if row_variant is Dictionary and int((row_variant as Dictionary).get("district_index", -1)) == district_index:
			return (row_variant as Dictionary).duplicate(true)
	return {}


func inference_rules_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"confidence_low": WorldSessionState.CITY_GUESS_CONFIDENCE_LOW,
		"confidence_medium": WorldSessionState.CITY_GUESS_CONFIDENCE_MEDIUM,
		"confidence_high": WorldSessionState.CITY_GUESS_CONFIDENCE_HIGH,
		"confidence_default": WorldSessionState.CITY_GUESS_CONFIDENCE_MEDIUM,
		"reason_ids": WorldSessionState.CITY_GUESS_REASON_IDS.duplicate(),
		"reason_product": "product",
		"reason_route": "route",
		"reason_card": "card",
		"reason_monster": "monster",
		"reason_role": "role",
		"reason_intuition": "intuition",
		"reason_default": "intuition",
	}


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
		"public_district_facts_ready": public_district_facts_ready(),
		"capability_revision": _capability_revision,
		"public_query_count": _public_query_count,
		"private_query_count": _private_query_count,
		"rejected_query_count": _rejected_query_count,
		"public_district_facts_schema_version": PUBLIC_DISTRICT_FACTS_SCHEMA_VERSION,
		"public_district_facts_literal_zero_mutation": true,
		"public_district_facts_exposes_owner": false,
		"public_district_facts_exposes_damage": false,
		"public_district_facts_exposes_panic": false,
		"actor_city_authorization_schema_version": ACTOR_CITY_AUTHORIZATION_SCHEMA_VERSION,
		"actor_city_authorization_owner_knowledge_values": ACTOR_CITY_OWNER_KNOWLEDGE_VALUES.duplicate(),
		"actor_city_authorization_stores_state": false,
		"actor_city_authorization_exposes_hidden_owner": false,
		"hidden_owner_truth_exposed": false,
		"rival_private_economy_exposed": false,
		"future_supply_bag_exposed": false,
		"mutable_world_collection_exposed": false,
		"references_main": false,
	}


func _project_public_district_fact_row(source: Dictionary, district_index: int) -> Dictionary:
	var raw_city: Dictionary = source.get("city", {}) if source.get("city", {}) is Dictionary else {}
	var city: Dictionary = {}
	if not raw_city.is_empty():
		city = {
			"present": true,
			"active": _bool_scalar(raw_city.get("active", true), true),
			"product_names": _product_names(raw_city.get("products", [])),
			"demand_names": _string_values(raw_city.get("demands", [])),
		}
		if city.keys() != PUBLIC_DISTRICT_CITY_FACT_KEYS:
			return {}
	var result := {
		"schema_version": PUBLIC_DISTRICT_FACTS_SCHEMA_VERSION,
		"source_revision": "",
		"fingerprint": "",
		"visibility_scope": "public",
		"district_index": district_index,
		"region_index": district_index,
		"region_id": _string_scalar(source.get("region_id", ""), "region.%03d" % district_index),
		"name": _string_scalar(source.get("name", ""), "区域%d" % (district_index + 1)),
		"destroyed": _bool_scalar(source.get("destroyed", false)),
		"terrain": _string_scalar(source.get("terrain", ""), "land"),
		"products": _string_values(source.get("products", [])),
		"demands": _string_values(source.get("demands", [])),
		"neighbors": _public_scalar_values(source.get("neighbors", [])),
		"city": city,
	}
	return result if _pure(result) else {}


func _project_regions(actor_index: int, guesses: Dictionary) -> Array:
	var result: Array = []
	if _world() == null:
		return result
	for district_index in range(_world().districts.size()):
		var source: Dictionary = _world().districts[district_index] \
			if _world().districts[district_index] is Dictionary else {}
		var row := _project_public_district(source, district_index)
		var raw_city: Dictionary = source.get("city", {}) if source.get("city", {}) is Dictionary else {}
		row["city"] = _project_city(raw_city, district_index, actor_index, guesses)
		var gdp_snapshot := _commodity_flow().region_gdp_snapshot(str(row["region_id"])) \
			if _commodity_flow() != null else {}
		row["current_gdp_per_minute"] = int(gdp_snapshot.get("region_gdp_per_minute", 0))
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
	var result := {
		"active": _bool_scalar(source.get("active", true), true),
		"level": _int_scalar(source.get("level", 0)),
		"last_income": _int_scalar(source.get("last_income", 0)),
		"competition_matches": _int_scalar(source.get("competition_matches", 0)),
		"trade_disrupted_routes": _int_scalar(source.get("trade_disrupted_routes", 0)),
		"trade_route_damage": _int_scalar(source.get("trade_route_damage", 0)),
		"warehouse_stockpile_count": maxi(0, _int_scalar(source.get("warehouse_stockpile_count", 0))),
		"warehouse_stockpile_units": maxi(0, _int_scalar(source.get("warehouse_stockpile_units", 0))),
	}
	result["product_names"] = _product_names(source.get("products", []))
	result["demand_names"] = _string_values(source.get("demands", []))
	result["warehouse_stockpile_products"] = _string_values(source.get("warehouse_stockpile_products", []))
	result["public_clues"] = _normalized_public_clues(source.get("public_clues", []))
	result["last_public_clue"] = str(_normalize_public_clue(source.get("last_public_clue", "")).get("text", ""))
	result["present"] = true
	var authorization := _actor_city_owner_authorization(source, district_index, actor_index, guesses)
	result["owner"] = int(authorization.get("perceived_owner_index", -1))
	result["owner_knowledge"] = str(authorization.get("owner_knowledge", "public_unknown"))
	if str(result["owner_knowledge"]) in ["actor_guess", "authorized_reveal"]:
		result["owner_confidence"] = int(authorization.get("confidence", 0))
		result["owner_reason_id"] = str(authorization.get("reason_id", ""))
	return result


func _actor_city_owner_authorization(
	source: Dictionary,
	district_index: int,
	actor_index: int,
	guesses: Dictionary
) -> Dictionary:
	var result := {
		"perceived_owner_index": -1,
		"owner_knowledge": "public_unknown",
		"confidence": 0,
		"reason_id": "",
		"reason_kind": "none",
		"authorized_reveal": false,
	}
	if source.is_empty() or actor_index < 0:
		return result
	var actual_owner := int(source.get("owner", -1))
	if actual_owner == actor_index:
		result["perceived_owner_index"] = actor_index
		result["owner_knowledge"] = "actor_own"
		result["reason_kind"] = "actor_own"
		return result
	if not guesses.has(district_index) or not (guesses[district_index] is Dictionary):
		return result
	var inference := guesses[district_index] as Dictionary
	var perceived_owner := int(inference.get("suspected_player_index", -1))
	if _world() == null or perceived_owner < 0 or perceived_owner >= _world().players.size() or perceived_owner == actor_index:
		return result
	var authorized_reveal := bool(inference.get("authorized_reveal", false))
	result["perceived_owner_index"] = perceived_owner
	result["owner_knowledge"] = "authorized_reveal" if authorized_reveal else "actor_guess"
	result["confidence"] = int(inference.get("confidence", 0))
	result["reason_id"] = str(inference.get("reason_id", ""))
	result["reason_kind"] = str(inference.get("reason_kind", "public_reveal" if authorized_reveal else "manual"))
	result["authorized_reveal"] = authorized_reveal
	return result


func _product_names(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for product_variant in value as Array:
		if product_variant is Dictionary:
			var product_name := _string_scalar((product_variant as Dictionary).get("name", ""), "未知商品")
			if not product_name.is_empty():
				result.append(product_name)
		elif product_variant is String or product_variant is StringName:
			var product_name := str(product_variant).strip_edges()
			if not product_name.is_empty():
				result.append(product_name)
	return result


func _string_values(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for item in value as Array:
		if item is String or item is StringName:
			var normalized := str(item).strip_edges()
			if not normalized.is_empty():
				result.append(normalized)
	return result


func _normalized_public_clues(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for clue_variant in value as Array:
		var clue := _normalize_public_clue(clue_variant)
		if not clue.is_empty():
			result.append(clue)
	return result


func _normalize_public_clue(value: Variant) -> Dictionary:
	var source: Dictionary = value as Dictionary if value is Dictionary else {}
	var text_value: Variant = source.get("text", source.get("clue", "")) if value is Dictionary else value
	var text := _string_scalar(text_value)
	if text.is_empty():
		return {}
	var time_value: Variant = source.get("time", source.get("game_time", -1.0))
	var clue_time := float(time_value) if time_value is int or time_value is float else -1.0
	if not is_finite(clue_time):
		clue_time = -1.0
	var products := _string_values(source.get("products", []))
	if products.is_empty():
		for product_variant in ProductMarketRuntimeController.PRODUCT_CATALOG:
			var product_name := str(product_variant)
			if not product_name.is_empty() and text.contains(product_name):
				products.append(product_name)
	var cycle_value: Variant = source.get("cycle", 0)
	var clue_kind := _string_scalar(source.get("kind", ""), _public_clue_kind(text))
	return {
		"text": text,
		"time": clue_time,
		"cycle": int(cycle_value) if cycle_value is int or cycle_value is float else 0,
		"kind": clue_kind,
		"products": products,
	}


func _string_scalar(value: Variant, fallback := "") -> String:
	if value is String or value is StringName:
		var normalized := str(value).strip_edges()
		return normalized if not normalized.is_empty() else str(fallback)
	return str(fallback)


func _project_public_district(source: Dictionary, district_index: int) -> Dictionary:
	return {
		"district_index": district_index,
		"region_index": district_index,
		"region_id": _string_scalar(source.get("region_id", ""), "region.%03d" % district_index),
		"name": _string_scalar(source.get("name", ""), "区域%d" % (district_index + 1)),
		"center": source.get("center", Vector2.ZERO) if source.get("center", Vector2.ZERO) is Vector2 else Vector2.ZERO,
		"polygon": _vector2_values(source.get("polygon", [])),
		"area_m2": _float_scalar(source.get("area_m2", 0.0)),
		"radius_m": _float_scalar(source.get("radius_m", 0.0)),
		"destroyed": _bool_scalar(source.get("destroyed", false)),
		"miasma": _bool_scalar(source.get("miasma", false)),
		"terrain": _string_scalar(source.get("terrain", "")),
		"terrain_label": _string_scalar(source.get("terrain_label", "")),
		"products": _string_values(source.get("products", [])),
		"demands": _string_values(source.get("demands", [])),
		"neighbors": _public_scalar_values(source.get("neighbors", [])),
		"transport_score": _float_scalar(source.get("transport_score", 0.0)),
		"damage": _int_scalar(source.get("damage", 0)),
		"panic": _int_scalar(source.get("panic", 0)),
	}


func _vector2_values(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value as Array:
			if item is Vector2:
				result.append(item)
	return result


func _public_scalar_values(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value as Array:
			if item is int or item is String or item is StringName:
				result.append(item)
	return result


func _int_scalar(value: Variant, fallback := 0) -> int:
	return int(value) if value is int or value is float else int(fallback)


func _float_scalar(value: Variant, fallback := 0.0) -> float:
	if not (value is int or value is float):
		return float(fallback)
	var normalized := float(value)
	return normalized if is_finite(normalized) else float(fallback)


func _bool_scalar(value: Variant, fallback := false) -> bool:
	return bool(value) if value is bool else bool(fallback)


func _public_clue_kind(text: String) -> String:
	if text.contains("合约"):
		return "合约"
	if text.contains("商路") or text.contains("断路") or text.contains("黑客"):
		return "商路"
	if text.contains("需求压力") or text.contains("市场") or text.contains("价格"):
		return "市场"
	if text.contains("GDP") or text.contains("生产") or text.contains("交通") or text.contains("消费"):
		return "经营"
	return "公开"


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
		and not bool((_world().players[actor_index] as Dictionary).get("eliminated", false)) \
		and (bool((_world().players[actor_index] as Dictionary).get("is_ai", false)) \
			or str((_world().players[actor_index] as Dictionary).get("seat_type", "human")) == "ai")


func _copy(value: Variant) -> Variant:
	return TablePresentationPureDataPolicy.detached_copy(value)


func _pure(value: Variant) -> bool:
	return TablePresentationPureDataPolicy.is_pure_data(value)


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _commodity_flow() -> CommodityFlowRuntimeController:
	return get_node_or_null(commodity_flow_runtime_controller_path) as CommodityFlowRuntimeController
