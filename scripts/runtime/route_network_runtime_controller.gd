@tool
extends Node
class_name RouteNetworkRuntimeController

const RULESET_ID := "v0.6"
const STATE_VERSION := 1
const BASIS_POINTS := 10000
const DIRECT_CAPACITY_UNITS_PER_MINUTE := 1000000
const MAX_ROUTES_PER_PAIR := 12
const MAX_PATH_REGION_COUNT := 9
const TRANSPORT_MODES := ["land", "sea", "air"]
const WEATHER_ROUTE_FLOOR := 0.40

var _configured := false
var _world_bridge: Node
var _weather_runtime_controller: Node
var _weather_telemetry_runtime_service: Node
var _transport_throughput_by_rank: Dictionary = {}
var _transport_speed_by_rank: Dictionary = {}
var _cached_topology_revision := ""
var _cached_candidates_by_pair: Dictionary = {}
var _cached_all_candidates: Array = []
var _cached_legacy_index_by_region_id: Dictionary = {}
var _cached_region_weather_context_by_id: Dictionary = {}
var _cached_facility_weather_context_by_id: Dictionary = {}
var _refresh_count := 0
var _rebuild_count := 0
var _query_count := 0


func set_world_bridge(bridge: Node) -> void:
	_world_bridge = bridge


func set_weather_runtime_controller(controller: Node) -> void:
	_weather_runtime_controller = controller


func set_weather_telemetry_runtime_service(service: Node) -> void:
	_weather_telemetry_runtime_service = service


func configure(profile_snapshot: Dictionary) -> Dictionary:
	var identity := _dictionary(profile_snapshot.get("identity", {}))
	var infrastructure := _dictionary(profile_snapshot.get("infrastructure", {}))
	var capabilities := _dictionary(profile_snapshot.get("capabilities", {}))
	_transport_throughput_by_rank = _rank_table(infrastructure.get("transport_throughput_by_rank", {}), false)
	_transport_speed_by_rank = _rank_table(infrastructure.get("transport_speed_multiplier_by_rank", {}), true)
	_configured = str(identity.get("ruleset_id", "")) == RULESET_ID \
		and bool(capabilities.get("continuous_commodity_flow_enabled", false)) \
		and not bool(capabilities.get("legacy_project_slots_enabled", true)) \
		and _transport_throughput_by_rank.size() == 4 \
		and _transport_speed_by_rank.size() == 4
	if not _configured:
		push_error("RouteNetworkRuntimeController requires the v0.6 infrastructure and continuous-flow profile.")
	return {
		"configured": _configured,
		"ruleset_id": RULESET_ID,
		"transport_throughput_by_rank": _transport_throughput_by_rank.duplicate(true),
		"transport_speed_multiplier_by_rank": _transport_speed_by_rank.duplicate(true),
	}


func reset_state() -> void:
	_cached_topology_revision = ""
	_cached_candidates_by_pair.clear()
	_cached_all_candidates.clear()
	_cached_legacy_index_by_region_id.clear()
	_cached_region_weather_context_by_id.clear()
	_cached_facility_weather_context_by_id.clear()
	_refresh_count = 0
	_rebuild_count = 0
	_query_count = 0


func refresh_routes(force := false) -> Dictionary:
	_refresh_count += 1
	var topology := _topology_snapshot()
	if topology.is_empty():
		return {"refreshed": false, "rebuilt": false, "reason": "topology_unavailable"}
	var revision := str(topology.get("topology_revision", ""))
	if not force and not revision.is_empty() and revision == _cached_topology_revision:
		return {
			"refreshed": true,
			"rebuilt": false,
			"topology_revision": revision,
			"route_count": _cached_all_candidates.size(),
		}
	_rebuild_routes(topology)
	return {
		"refreshed": true,
		"rebuilt": true,
		"topology_revision": _cached_topology_revision,
		"route_count": _cached_all_candidates.size(),
	}


func route_candidates_for_regions(commodity_id: String, source_region_id: String, market_region_id: String) -> Array:
	_query_count += 1
	_ensure_cache()
	var result: Array = []
	for candidate_variant in _cached_candidates_by_pair.get(_pair_key(source_region_id, market_region_id), []):
		var candidate: Dictionary = (candidate_variant as Dictionary).duplicate(true)
		candidate["commodity_id"] = commodity_id
		result.append(_project_weather_candidate(candidate))
	return result


func all_route_candidates(commodity_id := "*") -> Array:
	_query_count += 1
	_ensure_cache()
	var result: Array = []
	for candidate_variant in _cached_all_candidates:
		var candidate: Dictionary = (candidate_variant as Dictionary).duplicate(true)
		candidate["commodity_id"] = commodity_id
		result.append(_project_weather_candidate(candidate))
	return result


func active_region_legacy_indices() -> Array:
	var topology := _topology_snapshot()
	var result: Array = []
	for region_variant in topology.get("regions", []):
		if not (region_variant is Dictionary):
			continue
		var region: Dictionary = region_variant
		if str(region.get("lifecycle_state", "active")) == "destroyed" or not bool(region.get("legacy_city_active", false)):
			continue
		var legacy_index := int(region.get("legacy_index", -1))
		if legacy_index >= 0:
			result.append(legacy_index)
	result.sort()
	return result


func routes_for_product(commodity_id: String) -> Array:
	return all_route_candidates(commodity_id)


func routes_for_legacy_region(legacy_index: int, commodity_id := "*") -> Array:
	var topology := _topology_snapshot()
	var region_id := ""
	for region_variant in topology.get("regions", []):
		if region_variant is Dictionary and int((region_variant as Dictionary).get("legacy_index", -1)) == legacy_index:
			region_id = str((region_variant as Dictionary).get("region_id", ""))
			break
	if region_id.is_empty():
		return []
	var result: Array = []
	for candidate_variant in all_route_candidates(commodity_id):
		var candidate: Dictionary = candidate_variant
		if str(candidate.get("source_region_id", "")) == region_id or str(candidate.get("market_region_id", "")) == region_id or (candidate.get("ordered_region_ids", []) as Array).has(region_id):
			result.append(candidate.duplicate(true))
	return result


func route_load_for_legacy_region(legacy_index: int) -> int:
	return routes_for_legacy_region(legacy_index).size()


func to_save_data() -> Dictionary:
	return {
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"topology_revision": _cached_topology_revision,
		"derived_cache_only": true,
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	if not _is_pure_data(data):
		return {"applied": false, "reason": "save_not_pure_data"}
	if int(data.get("state_version", -1)) != STATE_VERSION or str(data.get("ruleset_id", "")) != RULESET_ID:
		return {"applied": false, "reason": "save_header_invalid"}
	_cached_topology_revision = ""
	_cached_candidates_by_pair.clear()
	_cached_all_candidates.clear()
	_cached_legacy_index_by_region_id.clear()
	_cached_region_weather_context_by_id.clear()
	_cached_facility_weather_context_by_id.clear()
	var refresh := refresh_routes(true)
	return {
		"applied": bool(refresh.get("refreshed", false)),
		"reason": str(refresh.get("reason", "")),
		"saved_topology_revision": str(data.get("topology_revision", "")),
		"current_topology_revision": _cached_topology_revision,
	}


func debug_snapshot(_viewer_index := -1) -> Dictionary:
	_ensure_cache()
	return {
		"controller_ready": _configured and _world_bridge != null,
		"controller_authoritative": _configured,
		"runtime_owner": "RouteNetworkRuntimeController",
		"ruleset_id": RULESET_ID,
		"state_version": STATE_VERSION,
		"topology_revision": _cached_topology_revision,
		"route_count": _cached_all_candidates.size(),
		"pair_count": _cached_candidates_by_pair.size(),
		"refresh_count": _refresh_count,
		"rebuild_count": _rebuild_count,
		"query_count": _query_count,
		"owns_route_legality": true,
		"owns_multimodal_pathing": true,
		"owns_route_capacity_derivation": true,
		"owns_route_rent_preview": true,
		"weather_projection_query_time_only": true,
		"weather_projection_floor": WEATHER_ROUTE_FLOOR,
		"weather_provider_ready": _weather_runtime_controller != null and is_instance_valid(_weather_runtime_controller),
		"owns_goods_or_cash": false,
		"rent_rate_pending": _any_rent_rate_pending(),
		"legacy_city_trade_owner_active": false,
		"pure_data": _is_pure_data(to_save_data()),
	}


func _ensure_cache() -> void:
	if _cached_topology_revision.is_empty():
		refresh_routes(true)
	else:
		var topology := _topology_snapshot()
		if not topology.is_empty() and str(topology.get("topology_revision", "")) != _cached_topology_revision:
			_rebuild_routes(topology)


func _rebuild_routes(topology: Dictionary) -> void:
	_cached_candidates_by_pair.clear()
	_cached_all_candidates.clear()
	_cache_weather_projection_facts(topology)
	var regions := _active_regions(topology)
	var graph := _mode_graph(topology, regions)
	var region_ids: Array = regions.keys()
	region_ids.sort()
	for source_variant in region_ids:
		var source_region_id := str(source_variant)
		for market_variant in region_ids:
			var market_region_id := str(market_variant)
			var candidates := _candidates_for_pair(source_region_id, market_region_id, topology, regions, graph)
			if candidates.is_empty():
				continue
			var pair_key := _pair_key(source_region_id, market_region_id)
			_cached_candidates_by_pair[pair_key] = candidates
			for candidate_variant in candidates:
				_cached_all_candidates.append((candidate_variant as Dictionary).duplicate(true))
	_cached_all_candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("route_id", "")) < str(right.get("route_id", ""))
	)
	_cached_topology_revision = str(topology.get("topology_revision", ""))
	_rebuild_count += 1


func _project_weather_candidate(candidate: Dictionary) -> Dictionary:
	var projected := candidate.duplicate(true)
	var base_bottleneck := maxi(0, int(candidate.get("bottleneck_units_per_minute", 0)))
	var weather_projection := _weather_projection_for_candidate(candidate)
	var planned_multiplier := maxf(WEATHER_ROUTE_FLOOR, float(weather_projection.get("multiplier", 1.0)))
	var projected_resources: Array = []
	var effective_bottleneck := 2147483647
	for resource_variant in candidate.get("capacity_resources", []):
		if not (resource_variant is Dictionary):
			continue
		var resource := (resource_variant as Dictionary).duplicate(true)
		var base_capacity := maxi(0, int(resource.get("capacity_units_per_minute", 0)))
		var effective_capacity := maxi(0, int(floor(float(base_capacity) * planned_multiplier + 0.000001)))
		resource["base_capacity_units_per_minute"] = base_capacity
		resource["capacity_units_per_minute"] = effective_capacity
		projected_resources.append(resource)
		effective_bottleneck = mini(effective_bottleneck, effective_capacity)
	if projected_resources.is_empty():
		effective_bottleneck = maxi(0, int(floor(float(base_bottleneck) * planned_multiplier + 0.000001)))
	projected["capacity_resources"] = projected_resources
	projected["base_bottleneck_units_per_minute"] = base_bottleneck
	projected["bottleneck_units_per_minute"] = effective_bottleneck if effective_bottleneck < 2147483647 else 0
	projected["route_efficiency_multiplier"] = float(projected["bottleneck_units_per_minute"]) / float(base_bottleneck) if base_bottleneck > 0 else 1.0
	projected["route_efficiency_explanation"] = str(weather_projection.get("explanation", "weather:none"))
	return projected


func _weather_projection_for_candidate(candidate: Dictionary) -> Dictionary:
	if _weather_runtime_controller == null or not is_instance_valid(_weather_runtime_controller) or not _weather_runtime_controller.has_method("region_effect_snapshot"):
		return {"multiplier": 1.0, "explanation": "weather:none"}
	var event_projection_by_key: Dictionary = {}
	for context_variant in _weather_route_contexts(candidate):
		var route_context := context_variant as Dictionary
		var region_id := str(route_context.get("region_id", ""))
		var legacy_index := int(_cached_legacy_index_by_region_id.get(region_id, -1))
		if legacy_index < 0:
			continue
		var mode := _weather_route_mode(str(route_context.get("route_mode", "")))
		var intervention := _weather_intervention_context(candidate, region_id)
		var effect_context := {
			"route_mode": mode,
			"movement_domain": mode,
			"weather_resistance": float(intervention.get("weather_resistance", 0.0)),
			"weather_exploitation_multiplier": float(intervention.get("weather_exploitation_multiplier", 1.0)),
		}
		var snapshot_variant: Variant = _weather_runtime_controller.call("region_effect_snapshot", legacy_index, effect_context)
		if not (snapshot_variant is Dictionary):
			continue
		var snapshot := snapshot_variant as Dictionary
		if not bool(snapshot.get("available", false)):
			continue
		for effect_variant in snapshot.get("effects", []):
			if not (effect_variant is Dictionary):
				continue
			var effect := effect_variant as Dictionary
			var route_effect: Dictionary = effect.get("route", {}) if effect.get("route", {}) is Dictionary else {}
			var generic_multiplier := float(route_effect.get("generic_multiplier", 1.0))
			var domain_multiplier := float(route_effect.get("%s_multiplier" % mode, 1.0)) if ["land", "ocean", "air"].has(mode) else 1.0
			var multiplier := maxf(0.0, generic_multiplier * domain_multiplier)
			var event_id := int(effect.get("event_id", 0))
			var definition_id := str(effect.get("definition_id", "weather"))
			var event_key := "event:%d" % event_id if event_id > 0 else "definition:%s" % definition_id
			var current: Dictionary = event_projection_by_key.get(event_key, {}) if event_projection_by_key.get(event_key, {}) is Dictionary else {}
			if current.is_empty() or _weather_multiplier_is_stronger(multiplier, float(current.get("multiplier", 1.0))):
				event_projection_by_key[event_key] = {
					"event_id": event_id,
					"definition_id": definition_id,
					"mode": mode,
					"multiplier": multiplier,
				}
	var multiplier := 1.0
	var explanation_parts: Array[String] = []
	var event_keys: Array = event_projection_by_key.keys()
	event_keys.sort()
	for event_key_variant in event_keys:
		var projection := event_projection_by_key[event_key_variant] as Dictionary
		var event_multiplier := float(projection.get("multiplier", 1.0))
		if is_equal_approx(event_multiplier, 1.0):
			continue
		multiplier *= event_multiplier
		var event_id := int(projection.get("event_id", 0))
		if event_id > 0 and _weather_telemetry_runtime_service != null and _weather_telemetry_runtime_service.has_method("observe_public_metric"):
			_weather_telemetry_runtime_service.call("observe_public_metric", event_id, "route_efficiency_delta_percent", (event_multiplier - 1.0) * 100.0)
		explanation_parts.append(_weather_efficiency_explanation(
			str(projection.get("definition_id", "weather")),
			str(projection.get("mode", "generic")),
			event_multiplier
		))
	multiplier = maxf(WEATHER_ROUTE_FLOOR, multiplier)
	return {
		"multiplier": multiplier,
		"explanation": " / ".join(explanation_parts) if not explanation_parts.is_empty() else "weather:none",
	}


func _weather_route_contexts(candidate: Dictionary) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for leg_variant in candidate.get("ordered_legs", []):
		if not (leg_variant is Dictionary):
			continue
		var leg := leg_variant as Dictionary
		var mode := _weather_route_mode(str(leg.get("mode", "")))
		for region_key in ["from_region_id", "to_region_id"]:
			var region_id := str(leg.get(region_key, ""))
			var key := "%s|%s" % [region_id, mode]
			if region_id.is_empty() or seen.has(key):
				continue
			seen[key] = true
			result.append({"region_id": region_id, "route_mode": mode})
	if result.is_empty():
		var fallback_mode := "generic"
		for mode_variant in candidate.get("mode_tags", []):
			var normalized := _weather_route_mode(str(mode_variant))
			if ["land", "ocean", "air"].has(normalized):
				fallback_mode = normalized
				break
		for region_variant in candidate.get("ordered_region_ids", []):
			var region_id := str(region_variant)
			if not region_id.is_empty():
				result.append({"region_id": region_id, "route_mode": fallback_mode})
	return result


func _weather_intervention_context(candidate: Dictionary, region_id: String) -> Dictionary:
	var region_context: Dictionary = _cached_region_weather_context_by_id.get(region_id, {}) if _cached_region_weather_context_by_id.get(region_id, {}) is Dictionary else {}
	var resistance := clampf(float(region_context.get("weather_resistance", 0.0)), 0.0, 1.0)
	var exploitation := maxf(1.0, float(region_context.get("weather_exploitation_multiplier", 1.0)))
	for facility_id_variant in candidate.get("facility_ids", []):
		var facility_context: Dictionary = _cached_facility_weather_context_by_id.get(str(facility_id_variant), {}) if _cached_facility_weather_context_by_id.get(str(facility_id_variant), {}) is Dictionary else {}
		if str(facility_context.get("region_id", "")) != region_id:
			continue
		resistance = maxf(resistance, clampf(float(facility_context.get("weather_resistance", 0.0)), 0.0, 1.0))
		exploitation = maxf(exploitation, maxf(1.0, float(facility_context.get("weather_exploitation_multiplier", 1.0))))
	return {
		"weather_resistance": resistance,
		"weather_exploitation_multiplier": exploitation,
	}


func _cache_weather_projection_facts(topology: Dictionary) -> void:
	_cached_legacy_index_by_region_id.clear()
	_cached_region_weather_context_by_id.clear()
	_cached_facility_weather_context_by_id.clear()
	for region_variant in topology.get("regions", []):
		if not (region_variant is Dictionary):
			continue
		var region := region_variant as Dictionary
		var region_id := str(region.get("region_id", ""))
		if region_id.is_empty():
			continue
		_cached_legacy_index_by_region_id[region_id] = int(region.get("legacy_index", -1))
		_cached_region_weather_context_by_id[region_id] = {
			"weather_resistance": clampf(float(region.get("weather_resistance", 0.0)), 0.0, 1.0),
			"weather_exploitation_multiplier": maxf(1.0, float(region.get("weather_exploitation_multiplier", 1.0))),
		}
	for facility_variant in topology.get("facilities", []):
		if not (facility_variant is Dictionary):
			continue
		var facility := facility_variant as Dictionary
		var facility_id := str(facility.get("facility_id", ""))
		if facility_id.is_empty():
			continue
		_cached_facility_weather_context_by_id[facility_id] = {
			"region_id": str(facility.get("region_id", "")),
			"weather_resistance": clampf(float(facility.get("weather_resistance", 0.0)), 0.0, 1.0),
			"weather_exploitation_multiplier": maxf(1.0, float(facility.get("weather_exploitation_multiplier", 1.0))),
		}


func _weather_multiplier_is_stronger(candidate: float, current: float) -> bool:
	if candidate < 1.0 or current < 1.0:
		return candidate < current
	return candidate > current


func _weather_efficiency_explanation(definition_id: String, mode: String, multiplier: float) -> String:
	var percent := int(round(absf(multiplier - 1.0) * 100.0))
	var direction := "+" if multiplier > 1.0 else "-"
	return "weather:%s:%s:%s%d%%" % [definition_id, mode, direction, percent]


func _weather_route_mode(mode: String) -> String:
	var normalized := mode.strip_edges().to_lower()
	return "ocean" if normalized == "sea" else normalized


func _candidates_for_pair(source_region_id: String, market_region_id: String, topology: Dictionary, regions: Dictionary, graph: Dictionary) -> Array:
	if source_region_id == market_region_id:
		return [_direct_candidate(source_region_id, market_region_id, 0, "local", topology)]
	var source := _dictionary(regions.get(source_region_id, {}))
	var neighbors: Array = source.get("neighbor_region_ids", []) if source.get("neighbor_region_ids", []) is Array else []
	if neighbors.has(market_region_id):
		return [_direct_candidate(source_region_id, market_region_id, 1, "direct", topology)]
	var paths := _enumerate_paths(source_region_id, market_region_id, graph)
	if paths.is_empty():
		return []
	var canonical_distance := 2147483647
	for path_variant in paths:
		canonical_distance = mini(canonical_distance, (path_variant as Dictionary).get("legs", []).size())
	var candidates: Array = []
	for path_variant in paths:
		var candidate := _route_candidate(path_variant as Dictionary, canonical_distance, topology, regions)
		if not candidate.is_empty():
			candidates.append(candidate)
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_arrival := float(left.get("arrival_seconds", 0.0))
		var right_arrival := float(right.get("arrival_seconds", 0.0))
		if not is_equal_approx(left_arrival, right_arrival):
			return left_arrival < right_arrival
		var left_transfers := int(left.get("transfer_count", 0))
		var right_transfers := int(right.get("transfer_count", 0))
		return left_transfers < right_transfers if left_transfers != right_transfers else str(left.get("route_id", "")) < str(right.get("route_id", ""))
	)
	if candidates.size() > MAX_ROUTES_PER_PAIR:
		candidates.resize(MAX_ROUTES_PER_PAIR)
	return candidates


func _direct_candidate(source_region_id: String, market_region_id: String, distance: int, tag: String, topology: Dictionary) -> Dictionary:
	var route_id := "%s:%s>%s" % [tag, source_region_id, market_region_id]
	return {
		"route_id": route_id,
		"commodity_id": "*",
		"source_region_id": source_region_id,
		"market_region_id": market_region_id,
		"ordered_region_ids": [source_region_id] if distance == 0 else [source_region_id, market_region_id],
		"ordered_legs": [] if distance == 0 else [{"from_region_id": source_region_id, "to_region_id": market_region_id, "mode": "direct"}],
		"mode_tags": [tag],
		"facility_ids": [],
		"capacity_resources": [{"resource_id": route_id, "capacity_units_per_minute": DIRECT_CAPACITY_UNITS_PER_MINUTE}],
		"actual_distance": distance,
		"shortest_legal_distance": distance,
		"bottleneck_units_per_minute": DIRECT_CAPACITY_UNITS_PER_MINUTE,
		"arrival_seconds": float(distance),
		"transfer_count": 0,
		"expected_rents": [],
		"rent_rate_pending": false,
		"region_revision_fingerprint": str(topology.get("topology_revision", "")),
	}


func _route_candidate(path: Dictionary, canonical_distance: int, topology: Dictionary, regions: Dictionary) -> Dictionary:
	var region_ids: Array = path.get("region_ids", [])
	var legs: Array = path.get("legs", [])
	if region_ids.size() < 2 or legs.is_empty():
		return {}
	var facility_ids: Array = []
	var mode_tags: Array = []
	var capacity_resources: Array = []
	var expected_rents: Array = []
	var bottleneck := DIRECT_CAPACITY_UNITS_PER_MINUTE
	var arrival_seconds := 0.0
	var rent_pending := false
	var previous_mode := ""
	var transfer_count := 0
	for leg_variant in legs:
		var leg: Dictionary = leg_variant
		var mode := str(leg.get("mode", ""))
		if not mode_tags.has(mode):
			mode_tags.append(mode)
		if not previous_mode.is_empty() and previous_mode != mode:
			transfer_count += 1
		previous_mode = mode
		var leg_speed := 999999.0
		for facility_id_variant in leg.get("facility_ids", []):
			var facility_id := str(facility_id_variant)
			if facility_ids.has(facility_id):
				continue
			facility_ids.append(facility_id)
			var facility := _facility_by_id(topology, facility_id)
			var region := _dictionary(regions.get(str(facility.get("region_id", "")), {}))
			var rank := clampi(int(facility.get("rank", 1)), 1, 4)
			var integrity_bp := clampi(int(region.get("integrity_basis_points", 0)), 0, BASIS_POINTS)
			var capacity := int(floor(float(int(_transport_throughput_by_rank.get(rank, 0))) * float(integrity_bp) / float(BASIS_POINTS)))
			bottleneck = mini(bottleneck, capacity)
			capacity_resources.append({"resource_id": facility_id, "capacity_units_per_minute": capacity})
			leg_speed = minf(leg_speed, float(_transport_speed_by_rank.get(rank, 1.0)))
			var rent_row := _rent_row(facility)
			if bool(rent_row.get("rent_rate_pending", false)):
				rent_pending = true
			expected_rents.append(rent_row)
		arrival_seconds += 1.0 / maxf(0.01, leg_speed if leg_speed < 999999.0 else 1.0)
	mode_tags.sort()
	facility_ids.sort()
	capacity_resources.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("resource_id", "")) < str(right.get("resource_id", "")))
	var route_identity := JSON.stringify({"regions": region_ids, "modes": mode_tags, "legs": legs}).sha256_text().substr(0, 16)
	return {
		"route_id": "route:%s" % route_identity,
		"commodity_id": "*",
		"source_region_id": str(region_ids.front()),
		"market_region_id": str(region_ids.back()),
		"ordered_region_ids": region_ids.duplicate(),
		"ordered_legs": legs.duplicate(true),
		"mode_tags": mode_tags,
		"facility_ids": facility_ids,
		"capacity_resources": capacity_resources,
		"actual_distance": legs.size(),
		"shortest_legal_distance": canonical_distance,
		"bottleneck_units_per_minute": maxi(0, bottleneck),
		"arrival_seconds": arrival_seconds,
		"transfer_count": transfer_count,
		"expected_rents": expected_rents,
		"rent_rate_pending": rent_pending,
		"region_revision_fingerprint": str(topology.get("topology_revision", "")),
	}


func _mode_graph(topology: Dictionary, regions: Dictionary) -> Dictionary:
	var graph: Dictionary = {}
	var region_ids: Array = regions.keys()
	region_ids.sort()
	for region_id_variant in region_ids:
		graph[str(region_id_variant)] = []
	for source_variant in region_ids:
		var source_id := str(source_variant)
		var source := _dictionary(regions[source_id])
		for neighbor_variant in source.get("neighbor_region_ids", []):
			var target_id := str(neighbor_variant)
			if not regions.has(target_id):
				continue
			var target := _dictionary(regions[target_id])
			var water_edge := _terrain_is_water(str(source.get("terrain_id", ""))) or _terrain_is_water(str(target.get("terrain_id", "")))
			if not water_edge:
				_append_mode_edge(graph, source_id, target_id, "land", topology)
			if water_edge:
				_append_mode_edge(graph, source_id, target_id, "sea", topology)
	for source_variant in region_ids:
		var source_id := str(source_variant)
		for target_variant in region_ids:
			var target_id := str(target_variant)
			if source_id != target_id:
				_append_mode_edge(graph, source_id, target_id, "air", topology)
	for region_id_variant in graph.keys():
		(graph[region_id_variant] as Array).sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var left_key := "%s:%s" % [str(left.get("to_region_id", "")), str(left.get("mode", ""))]
			var right_key := "%s:%s" % [str(right.get("to_region_id", "")), str(right.get("mode", ""))]
			return left_key < right_key
		)
	return graph


func _append_mode_edge(graph: Dictionary, source_id: String, target_id: String, mode: String, topology: Dictionary) -> void:
	var facility_type := _facility_type_for_mode(mode)
	var source_facility := _active_facility(topology, source_id, facility_type)
	var target_facility := _active_facility(topology, target_id, facility_type)
	if source_facility.is_empty() or target_facility.is_empty():
		return
	(graph[source_id] as Array).append({
		"from_region_id": source_id,
		"to_region_id": target_id,
		"mode": mode,
		"facility_ids": [str(source_facility.get("facility_id", "")), str(target_facility.get("facility_id", ""))],
	})


func _enumerate_paths(source_region_id: String, market_region_id: String, graph: Dictionary) -> Array:
	var results: Array = []
	var stack: Array = [{"region_ids": [source_region_id], "legs": []}]
	while not stack.is_empty() and results.size() < MAX_ROUTES_PER_PAIR * 4:
		var state: Dictionary = stack.pop_back()
		var region_ids: Array = state.get("region_ids", [])
		var current_id := str(region_ids.back())
		if current_id == market_region_id:
			results.append(state)
			continue
		if region_ids.size() >= MAX_PATH_REGION_COUNT:
			continue
		var edges: Array = graph.get(current_id, [])
		for edge_index in range(edges.size() - 1, -1, -1):
			var edge: Dictionary = edges[edge_index]
			var next_id := str(edge.get("to_region_id", ""))
			if region_ids.has(next_id):
				continue
			var next_regions := region_ids.duplicate()
			next_regions.append(next_id)
			var next_legs: Array = (state.get("legs", []) as Array).duplicate(true)
			next_legs.append(edge.duplicate(true))
			stack.append({"region_ids": next_regions, "legs": next_legs})
	results.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_legs: Array = left.get("legs", [])
		var right_legs: Array = right.get("legs", [])
		return left_legs.size() < right_legs.size() if left_legs.size() != right_legs.size() else JSON.stringify(left) < JSON.stringify(right)
	)
	return results


func _active_regions(topology: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for region_variant in topology.get("regions", []):
		if not (region_variant is Dictionary):
			continue
		var region: Dictionary = region_variant
		if str(region.get("lifecycle_state", "active")) != "destroyed":
			result[str(region.get("region_id", ""))] = region.duplicate(true)
	return result


func _active_facility(topology: Dictionary, region_id: String, facility_type: String) -> Dictionary:
	for facility_variant in topology.get("facilities", []):
		if not (facility_variant is Dictionary):
			continue
		var facility: Dictionary = facility_variant
		if bool(facility.get("active", false)) and str(facility.get("region_id", "")) == region_id and str(facility.get("facility_type", "")) == facility_type:
			return facility.duplicate(true)
	return {}


func _facility_by_id(topology: Dictionary, facility_id: String) -> Dictionary:
	for facility_variant in topology.get("facilities", []):
		if facility_variant is Dictionary and str((facility_variant as Dictionary).get("facility_id", "")) == facility_id:
			return (facility_variant as Dictionary).duplicate(true)
	return {}


func _rent_row(facility: Dictionary) -> Dictionary:
	var amount := maxi(0, int(facility.get("rent_per_unit_cents", facility.get("rent_rate_cents", 0))))
	var basis_points := maxi(0, int(facility.get("rent_basis_points", 0)))
	var pending := amount <= 0 and basis_points <= 0
	return {
		"facility_id": str(facility.get("facility_id", "")),
		"facility_type": str(facility.get("facility_type", "")),
		"recipient_player_index": int(facility.get("owner_player_index", -1)),
		"amount_per_unit_cents": amount,
		"rent_basis_points": basis_points,
		"rent_rate_pending": pending,
	}


func _any_rent_rate_pending() -> bool:
	for candidate_variant in _cached_all_candidates:
		if bool((candidate_variant as Dictionary).get("rent_rate_pending", false)):
			return true
	return false


func _topology_snapshot() -> Dictionary:
	if _world_bridge == null or not _world_bridge.has_method("capture_route_topology"):
		return {}
	var value: Variant = _world_bridge.call("capture_route_topology")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _facility_type_for_mode(mode: String) -> String:
	match mode:
		"land": return "road"
		"sea": return "port"
		"air": return "spaceport"
	return ""


func _terrain_is_water(terrain_id: String) -> bool:
	var normalized := terrain_id.to_lower()
	return normalized.contains("water") or normalized.contains("ocean") or normalized.contains("sea") or normalized.contains("coast")


func _pair_key(source_region_id: String, market_region_id: String) -> String:
	return "%s>%s" % [source_region_id, market_region_id]


func _rank_table(value: Variant, allow_float: bool) -> Dictionary:
	var result: Dictionary = {}
	if not (value is Dictionary):
		return result
	var labels := ["I", "II", "III", "IV"]
	for index in range(labels.size()):
		var raw: Variant = (value as Dictionary).get(labels[index], 0)
		var amount: Variant
		if allow_float:
			amount = float(raw)
		else:
			amount = int(raw)
		if float(amount) <= 0.0:
			return {}
		result[index + 1] = amount
	return result


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item_variant in value:
			if not _is_pure_data(item_variant):
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
		return true
	return false
