extends SceneTree

const Observation := preload("res://scripts/viewmodels/public_economy_continuation_observation_v1.gd")
const Planner := preload("res://scripts/tools/full_run_economy_continuation_planner.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := _source()
	var observation := Planner.observation_from_public_sources(source)
	_expect(Observation.is_valid(observation), "authorized public sources produce the closed V1 observation")
	_expect(str(observation.get("visibility_scope", "")) == "viewer_safe_aggregate", "the observation declares its bounded viewer-safe scope")
	var facilities := observation.get("facility_rows", []) as Array
	_expect(facilities.size() == 2, "only the authorized viewer's public factory and market join the observation")
	_expect(str((facilities[0] as Dictionary).get("facility_instance_id", "")) == "facility-own-factory" and str((facilities[1] as Dictionary).get("facility_instance_id", "")) == "facility-own-market", "facility rows use stable instance IDs and deterministic ordering")
	var commodities := observation.get("commodity_rows", []) as Array
	_expect(commodities.size() == 1 and str((commodities[0] as Dictionary).get("commodity_id", "")) == "commodity.alpha", "unrelated rival commodity rows never enter the viewer chain")
	var row := commodities[0] as Dictionary
	_expect(float(row.get("public_production_capacity", 0.0)) == 10.0 and float(row.get("public_demand_capacity", 0.0)) == 20.0, "typed capacity is assembled from the authorized viewer's facilities")
	_expect(float(row.get("public_settled_units", 0.0)) == 3.0 and float(row.get("public_transport_units", 0.0)) == 3.0 and float(row.get("public_waste_units", 0.0)) == 4.5, "settlement, transport and public waste are allowlisted per commodity")
	var public_demand_source := source.duplicate(true)
	(public_demand_source.get("installations", []) as Array).append({
		"installation_id": "public-demand-install",
		"facility_id": "public-demand-market",
		"region_id": "region.public",
		"commodity_id": "commodity.public",
		"color": "shipping",
		"direction": "demand",
		"base_units_per_minute": 10,
		"active": true,
		"owner_kind": "public",
	})
	var public_demand_observation := Planner.observation_from_public_sources(public_demand_source)
	var public_demand_row := _commodity_row(public_demand_observation, "commodity.public")
	_expect(float(public_demand_row.get("public_demand_capacity", 0.0)) == 10.0 and (public_demand_observation.get("facility_rows", []) as Array).size() == 2, "anonymous public baseline demand informs planning without becoming a rival-owned facility row")
	var serialized := JSON.stringify(observation)
	_expect(_pure_data(observation), "the observation contains only stable scalar, Array, and Dictionary data")
	for forbidden in ["999999", "PRIVATE_SENTINEL", "future", "rng", "players", "districts", "owner_player_index", "commodity_owner"]:
		_expect(not serialized.contains(forbidden), "observation excludes forbidden token %s" % forbidden)
	var detached := Observation.detached_copy(observation)
	(detached.get("facility_rows", []) as Array).clear()
	_expect((observation.get("facility_rows", []) as Array).size() == 2, "detached copies cannot mutate the original observation")
	var repeated := Planner.observation_from_public_sources(source)
	_expect(repeated == observation and Observation.fingerprint(repeated) == Observation.fingerprint(observation), "unchanged public sources preserve observation identity")
	var reordered_source := source.duplicate(true)
	(((reordered_source.get("infrastructure", {}) as Dictionary).get("facilities", [])) as Array).reverse()
	(reordered_source.get("installations", []) as Array).reverse()
	(reordered_source.get("own_receipts", []) as Array).reverse()
	((reordered_source.get("waste", {}) as Dictionary).get("commodity_rows", []) as Array).reverse()
	var reordered := Planner.observation_from_public_sources(reordered_source)
	_expect(reordered == observation and Observation.fingerprint(reordered) == Observation.fingerprint(observation), "source row ordering cannot change the canonical observation")
	var private_only_change := source.duplicate(true)
	(((private_only_change.get("infrastructure", {}) as Dictionary).get("facilities", []) as Array)[0] as Dictionary)["cash"] = 111111
	((private_only_change.get("own_receipts", []) as Array)[0] as Dictionary)["owner_net_cash"] = 111111
	(private_only_change.get("public_progress", {}) as Dictionary)["private_target"] = "PRIVATE_SENTINEL_CHANGED"
	var private_change_observation := Planner.observation_from_public_sources(private_only_change)
	_expect(private_change_observation == observation, "private-only source values cannot alter data or leak through the revision")
	var advanced_source := source.duplicate(true)
	(advanced_source.get("waste", {}) as Dictionary)["waste_revision"] = 8
	var advanced := Planner.observation_from_public_sources(advanced_source)
	_expect(int(advanced.get("source_revision", 0)) != int(observation.get("source_revision", 0)), "an authoritative source revision changes the observation identity")
	var progress_source := source.duplicate(true)
	(progress_source.get("public_progress", {}) as Dictionary)["top_k_gdp_per_minute"] = 60
	var progress_advanced := Planner.observation_from_public_sources(progress_source)
	_expect(int(progress_advanced.get("source_revision", 0)) != int(observation.get("source_revision", 0)), "an allowlisted public progress change advances the observation identity")
	var hostile := observation.duplicate(true)
	hostile["cash"] = 999999
	_expect(not Observation.is_valid(hostile), "unknown top-level fields fail closed")
	var float_schema := observation.duplicate(true)
	float_schema["schema_version"] = 1.0
	_expect(not Observation.is_valid(float_schema), "schema versions require the exact integer type")
	var object_identity := observation.duplicate(true)
	(((object_identity.get("commodity_rows", []) as Array)[0]) as Dictionary)["commodity_id"] = self
	_expect(not Observation.is_valid(object_identity), "Object values cannot be coerced into stable semantic IDs")
	var mismatched_industry := observation.duplicate(true)
	(((mismatched_industry.get("facility_rows", []) as Array)[0]) as Dictionary)["industry_id"] = "shipping"
	_expect(not Observation.is_valid(mismatched_industry), "facility and commodity industry bindings must agree")
	_finish()


func _source() -> Dictionary:
	return {
		"viewer_index": 0,
		"infrastructure": {
			"available": true,
			"revision": 5,
			"facilities": [
				{"region_id": "region.alpha", "facility_type": "factory", "industry_id": "energy", "active": true, "owner_player_index": 0, "cash": 999999},
				{"region_id": "region.beta", "facility_type": "market", "industry_id": "energy", "active": true, "owner_player_index": 0},
				{"region_id": "region.gamma", "facility_type": "factory", "industry_id": "shipping", "active": true, "owner_player_index": 2, "hidden_owner": "PRIVATE_SENTINEL"},
			],
		},
		"installations": [
			{"installation_id": "install-1", "facility_id": "facility-own-factory", "region_id": "region.alpha", "commodity_id": "commodity.alpha", "color": "energy", "direction": "production", "base_units_per_minute": 10, "active": true, "owner_kind": "player"},
			{"installation_id": "install-2", "facility_id": "facility-own-market", "region_id": "region.beta", "commodity_id": "commodity.alpha", "color": "energy", "direction": "demand", "base_units_per_minute": 20, "active": true, "owner_kind": "player"},
			{"installation_id": "install-3", "facility_id": "facility-rival", "region_id": "region.gamma", "commodity_id": "commodity.rival", "color": "shipping", "direction": "production", "base_units_per_minute": 80, "active": true, "owner_kind": "player", "future_sequence": "PRIVATE_SENTINEL"},
		],
		"own_receipts": [
			{"commodity_owner": 0, "commodity_id": "commodity.alpha", "units": 3, "route_id": "route.alpha", "owner_net_cash": 999999},
			{"commodity_id": "commodity.rival", "units": 99, "route_id": "route.rival", "ai_score": "PRIVATE_SENTINEL"},
		],
		"waste": {
			"available": true,
			"flow_revision": 11,
			"waste_revision": 7,
			"commodity_rows": [
				{"commodity_id": "commodity.alpha", "cumulative_wasted_units": 4.5},
				{"commodity_id": "commodity.rival", "cumulative_wasted_units": 200.0},
			],
		},
		"public_progress": {
			"top_k_gdp_per_minute": 59,
			"required_top_k_gdp_per_minute": 108,
			"controlled_region_count": 3,
			"required_region_count": 3,
			"eligible": false,
			"victory_state": "idle",
		},
	}


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _commodity_row(observation: Dictionary, commodity_id: String) -> Dictionary:
	for row_variant in observation.get("commodity_rows", []) as Array:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("commodity_id", "")) == commodity_id:
			return (row_variant as Dictionary).duplicate(true)
	return {}


func _pure_data(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return not (value is float) or is_finite(float(value))
		TYPE_ARRAY:
			for child in value as Array:
				if not _pure_data(child):
					return false
			return true
		TYPE_DICTIONARY:
			for key_variant in (value as Dictionary).keys():
				if not _pure_data(key_variant) or not _pure_data((value as Dictionary).get(key_variant)):
					return false
			return true
	return false


func _finish() -> void:
	for failure in _failures:
		push_error("PUBLIC_ECONOMY_CONTINUATION_OBSERVATION_V1: %s" % failure)
	print("PUBLIC_ECONOMY_CONTINUATION_OBSERVATION_V1|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(_failures.size())
