extends RefCounted
class_name FullRunEconomyContinuationPlanner

const OBSERVATION := preload("res://scripts/viewmodels/public_economy_continuation_observation_v1.gd")

const PLAN_SCHEMA_VERSION := 1
const VICTORY_LOCK_STATES := ["qualification", "audit", "resolved"]


static func observation_from_public_sources(source: Dictionary) -> Dictionary:
	if typeof(source.get("viewer_index")) != TYPE_INT \
			or not (source.get("infrastructure") is Dictionary) \
			or not (source.get("installations") is Array) \
			or not (source.get("own_receipts") is Array) \
			or not (source.get("waste") is Dictionary) \
			or not (source.get("public_progress") is Dictionary):
		return {}
	var viewer_index := int(source.get("viewer_index", -1))
	if viewer_index < 0:
		return {}
	var infrastructure: Dictionary = source.get("infrastructure", {}) \
		if source.get("infrastructure", {}) is Dictionary else {}
	var installations: Array = source.get("installations", []) \
		if source.get("installations", []) is Array else []
	var own_receipts: Array = source.get("own_receipts", []) \
		if source.get("own_receipts", []) is Array else []
	var waste: Dictionary = source.get("waste", {}) if source.get("waste", {}) is Dictionary else {}
	var progress: Dictionary = source.get("public_progress", {}) \
		if source.get("public_progress", {}) is Dictionary else {}
	if typeof(infrastructure.get("available")) != TYPE_BOOL \
			or not bool(infrastructure.get("available", false)) \
			or not (infrastructure.get("facilities") is Array) \
			or typeof(waste.get("available")) != TYPE_BOOL \
			or not bool(waste.get("available", false)) \
			or not (waste.get("commodity_rows") is Array) \
			or not _nonnegative_integer_field(infrastructure, "revision") \
			or not _nonnegative_integer_field(waste, "flow_revision") \
			or not _nonnegative_integer_field(waste, "waste_revision"):
		return {}
	var progress_row := _public_progress_row(progress)
	if progress_row.is_empty():
		return {}
	var own_facility_keys := {}
	for facility_variant in infrastructure.get("facilities", []) as Array:
		if not (facility_variant is Dictionary):
			continue
		var facility := facility_variant as Dictionary
		if int(facility.get("owner_player_index", -1)) != viewer_index \
				or not bool(facility.get("active", false)):
			continue
		var key := _facility_join_key(
			str(facility.get("region_id", "")),
			str(facility.get("facility_type", "")),
			str(facility.get("industry_id", ""))
		)
		own_facility_keys[key] = int(own_facility_keys.get(key, 0)) + 1
	var ordered_installations: Array = installations.duplicate(true)
	ordered_installations.sort_custom(func(left: Variant, right: Variant) -> bool:
		return str((left as Dictionary).get("installation_id", "")) \
			< str((right as Dictionary).get("installation_id", "")) \
			if left is Dictionary and right is Dictionary else false
	)
	var facility_rows: Array = []
	for installation_variant in ordered_installations:
		if not (installation_variant is Dictionary):
			continue
		var installation := installation_variant as Dictionary
		var direction := str(installation.get("direction", ""))
		var facility_kind := "factory" if direction == "production" else ("market" if direction == "demand" else "")
		var key := _facility_join_key(
			str(installation.get("region_id", "")),
			facility_kind,
			str(installation.get("color", ""))
		)
		var remaining := int(own_facility_keys.get(key, 0))
		if remaining <= 0 or facility_kind.is_empty() or not bool(installation.get("active", false)):
			continue
		own_facility_keys[key] = remaining - 1
		var facility_instance_id := str(
			installation.get("facility_id", installation.get("installation_id", ""))
		).strip_edges()
		facility_rows.append({
			"facility_instance_id": facility_instance_id,
			"facility_kind": facility_kind,
			"commodity_id": str(installation.get("commodity_id", "")),
			"industry_id": str(installation.get("color", "")),
			"region_id": str(installation.get("region_id", "")),
			"direction": direction,
			"base_units_per_minute": maxf(0.0, float(installation.get("base_units_per_minute", 0.0))),
			"active": true,
		})
	var by_commodity := {}
	for row_variant in facility_rows:
		var row := row_variant as Dictionary
		var commodity_id := str(row.get("commodity_id", ""))
		if commodity_id.is_empty():
			continue
		var bucket := _commodity_bucket(by_commodity, commodity_id, str(row.get("industry_id", "")))
		var capacity := maxf(0.0, float(row.get("base_units_per_minute", 0.0)))
		if str(row.get("direction", "")) == "production":
			bucket["public_production_capacity"] = float(bucket.get("public_production_capacity", 0.0)) + capacity
		else:
			bucket["public_demand_capacity"] = float(bucket.get("public_demand_capacity", 0.0)) + capacity
		by_commodity[commodity_id] = bucket
	# V0.6 bootstraps anonymous public demand installations. They are legal
	# player-visible capacity, but they are not attributed to another player and
	# therefore do not enter the viewer's facility rows.
	for installation_variant in ordered_installations:
		if not (installation_variant is Dictionary):
			continue
		var installation := installation_variant as Dictionary
		if not bool(installation.get("active", false)) \
				or str(installation.get("owner_kind", "")) != "public" \
				or str(installation.get("direction", "")) != "demand":
			continue
		var commodity_id := str(installation.get("commodity_id", "")).strip_edges()
		var industry_id := str(installation.get("color", "")).strip_edges()
		if commodity_id.is_empty() or industry_id.is_empty():
			return {}
		var bucket := _commodity_bucket(by_commodity, commodity_id, industry_id)
		if not str(bucket.get("industry_id", "")).is_empty() \
				and str(bucket.get("industry_id", "")) != industry_id:
			return {}
		bucket["public_demand_capacity"] = float(bucket.get("public_demand_capacity", 0.0)) \
			+ maxf(0.0, float(installation.get("base_units_per_minute", 0.0)))
		by_commodity[commodity_id] = bucket
	for receipt_variant in own_receipts:
		if not (receipt_variant is Dictionary):
			continue
		var receipt := receipt_variant as Dictionary
		if int(receipt.get("commodity_owner", -1)) != viewer_index:
			continue
		var commodity_id := str(receipt.get("commodity_id", ""))
		if not by_commodity.has(commodity_id):
			continue
		var bucket := by_commodity[commodity_id] as Dictionary
		var units := maxf(0.0, float(receipt.get("units", 0.0)))
		bucket["public_settled_units"] = float(bucket.get("public_settled_units", 0.0)) + units
		if not str(receipt.get("route_id", "")).is_empty():
			bucket["public_transport_units"] = float(bucket.get("public_transport_units", 0.0)) + units
		by_commodity[commodity_id] = bucket
	for waste_variant in waste.get("commodity_rows", []) as Array:
		if not (waste_variant is Dictionary):
			continue
		var waste_row := waste_variant as Dictionary
		var commodity_id := str(waste_row.get("commodity_id", ""))
		if not by_commodity.has(commodity_id):
			continue
		var bucket := by_commodity[commodity_id] as Dictionary
		bucket["public_waste_units"] = maxf(0.0, float(waste_row.get("cumulative_wasted_units", 0.0)))
		by_commodity[commodity_id] = bucket
	var commodity_rows: Array = []
	var commodity_ids: Array = by_commodity.keys()
	commodity_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	for commodity_id_variant in commodity_ids:
		commodity_rows.append((by_commodity[commodity_id_variant] as Dictionary).duplicate(true))
	var revision_source := {
		"infrastructure_revision": int(infrastructure.get("revision", 0)),
		"flow_revision": int(waste.get("flow_revision", 0)),
		"waste_revision": int(waste.get("waste_revision", 0)),
		"facilities": facility_rows,
		"commodity_rows": commodity_rows,
		"progress": progress_row,
	}
	var observation_source := {
		"schema_version": OBSERVATION.SCHEMA_VERSION,
		"source_revision": _source_revision(revision_source),
		"visibility_scope": "viewer_safe_aggregate",
		"commodity_rows": commodity_rows,
		"facility_rows": facility_rows,
		"public_progress": progress_row,
	}
	return OBSERVATION.normalize(observation_source)


static func matched_chain_evidence(observation: Dictionary) -> Dictionary:
	var normalized := OBSERVATION.normalize(observation)
	if normalized.is_empty():
		return {
			"observed": false,
			"matched_commodity_count": 0,
			"settled_matched_commodity_count": 0,
			"fingerprint": "",
		}
	var rows: Array = []
	var settled_count := 0
	for row_variant in normalized.get("commodity_rows", []) as Array:
		var row := row_variant as Dictionary
		if float(row.get("public_production_capacity", 0.0)) <= 0.0 \
				or float(row.get("public_demand_capacity", 0.0)) <= 0.0:
			continue
		var settled := float(row.get("public_settled_units", 0.0)) > 0.0
		settled_count += 1 if settled else 0
		rows.append({
			"commodity_id": str(row.get("commodity_id", "")),
			"industry_id": str(row.get("industry_id", "")),
			"settled": settled,
		})
	return {
		"observed": not rows.is_empty(),
		"matched_commodity_count": rows.size(),
		"settled_matched_commodity_count": settled_count,
		"fingerprint": JSON.stringify(rows).sha256_text() if not rows.is_empty() else "",
	}


static func plan(observation: Dictionary) -> Dictionary:
	var plans := ranked_plans(observation)
	return (plans[0] as Dictionary).duplicate(true) if not plans.is_empty() else _plan(
		false,
		"observation_unavailable",
		"",
		"",
		"",
		"",
		0,
		true
	)


static func ranked_plans(observation: Dictionary) -> Array:
	var normalized := OBSERVATION.normalize(observation)
	if normalized.is_empty():
		return [_plan(false, "observation_unavailable", "", "", "", "", 0, true)]
	var source_revision := int(normalized.get("source_revision", 0))
	var progress := normalized.get("public_progress", {}) as Dictionary
	var victory_state := str(progress.get("victory_state", "idle"))
	if bool(progress.get("eligible", false)) or victory_state in VICTORY_LOCK_STATES:
		return [_plan(true, "victory_lifecycle_locked", "", "", "", "", source_revision, true)]
	var active_facilities: Array = []
	for facility_variant in normalized.get("facility_rows", []) as Array:
		if facility_variant is Dictionary and bool((facility_variant as Dictionary).get("active", false)):
			active_facilities.append(facility_variant)
	if active_facilities.is_empty():
		return [_plan(true, "economy_chain_start", "factory", "production", "", "", source_revision, false)]
	var candidates: Array[Dictionary] = []
	for row_variant in normalized.get("commodity_rows", []) as Array:
		var row := row_variant as Dictionary
		var production := float(row.get("public_production_capacity", 0.0))
		var demand := float(row.get("public_demand_capacity", 0.0))
		var waste := float(row.get("public_waste_units", 0.0))
		var desired_kind := ""
		var reason_id := ""
		var priority := 99
		if production > 0.0 and demand <= 0.0:
			desired_kind = "market"
			reason_id = "missing_matching_market"
			priority = 0
		elif demand > 0.0 and production <= 0.0:
			desired_kind = "factory"
			reason_id = "missing_matching_factory"
			priority = 0
		elif waste > 0.0 and production >= demand:
			desired_kind = "market"
			reason_id = "production_waste_dominant"
			priority = 1
		elif production > demand:
			desired_kind = "market"
			reason_id = "demand_capacity_bottleneck"
			priority = 2
		elif demand > production:
			desired_kind = "factory"
			reason_id = "production_capacity_bottleneck"
			priority = 2
		elif int(progress.get("top_k_gdp", 0)) < int(progress.get("required_top_k_gdp", 0)):
			desired_kind = "factory"
			reason_id = "matched_chain_scale_required"
			priority = 3
		if desired_kind.is_empty():
			continue
		candidates.append({
			"priority": priority,
			"capacity_gap": absf(production - demand),
			"waste": waste,
			"commodity_id": str(row.get("commodity_id", "")),
			"industry_id": str(row.get("industry_id", "")),
			"desired_facility_kind": desired_kind,
			"reason_id": reason_id,
		})
	if candidates.is_empty():
		return [_plan(true, "no_complementary_growth_required", "", "", "", "", source_revision, true)]
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_priority := int(left.get("priority", 99))
		var right_priority := int(right.get("priority", 99))
		if left_priority != right_priority:
			return left_priority < right_priority
		var left_gap := float(left.get("capacity_gap", 0.0)) + float(left.get("waste", 0.0))
		var right_gap := float(right.get("capacity_gap", 0.0)) + float(right.get("waste", 0.0))
		if not is_equal_approx(left_gap, right_gap):
			return left_gap > right_gap
		return "%s|%s|%s" % [str(left.get("commodity_id", "")), str(left.get("industry_id", "")), str(left.get("desired_facility_kind", ""))] \
			< "%s|%s|%s" % [str(right.get("commodity_id", "")), str(right.get("industry_id", "")), str(right.get("desired_facility_kind", ""))]
	)
	var result: Array = []
	for selected_variant in candidates:
		var selected := selected_variant as Dictionary
		var kind := str(selected.get("desired_facility_kind", ""))
		result.append(_plan(
			true,
			str(selected.get("reason_id", "")),
			kind,
			"production" if kind == "factory" else "demand",
			str(selected.get("commodity_id", "")),
			str(selected.get("industry_id", "")),
			source_revision,
			false
		))
	return result


static func facility_matches_plan(card: Dictionary, continuation_plan: Dictionary) -> bool:
	if not bool(continuation_plan.get("ready", false)) or bool(continuation_plan.get("stop", false)):
		return false
	var desired_kind := str(continuation_plan.get("desired_facility_kind", ""))
	var desired_industry := str(continuation_plan.get("industry_id", ""))
	return str(card.get("facility_kind", "")) == desired_kind \
		and (desired_industry.is_empty() or str(card.get("industry_id", "")) == desired_industry)


static func first_matching_facility(cards: Array, continuation_plan: Dictionary, actionable_only := false) -> Dictionary:
	var matches: Array[Dictionary] = []
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		if str(card.get("card_id", "")).strip_edges().is_empty() \
				or str(card.get("kind", "")) not in ["facility", "facility_v06", "public_facility"] \
				or not facility_matches_plan(card, continuation_plan) \
				or actionable_only and not bool(card.get("actionable", false)):
			continue
		matches.append(card.duplicate(true))
	matches.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return "%s|%s|%06d" % [str(left.get("card_id", "")), str(left.get("card_instance_ref", left.get("id", ""))), int(left.get("slot", -1))] \
			< "%s|%s|%06d" % [str(right.get("card_id", "")), str(right.get("card_instance_ref", right.get("id", ""))), int(right.get("slot", -1))]
	)
	return matches[0] if not matches.is_empty() else {}


static func matching_target_candidates(
	candidates: Array,
	region_facts: Array,
	continuation_plan: Dictionary
) -> Array:
	var desired_commodity := str(continuation_plan.get("commodity_id", ""))
	if desired_commodity.is_empty():
		return _sorted_target_candidates(candidates)
	var rows_key := "production_products" \
		if str(continuation_plan.get("desired_facility_kind", "")) == "factory" else "demand_products"
	var compatible_regions := {}
	for facts_variant in region_facts:
		if not (facts_variant is Dictionary):
			continue
		var facts := facts_variant as Dictionary
		for product_variant in facts.get(rows_key, []) as Array:
			if product_variant is Dictionary \
					and str((product_variant as Dictionary).get("product_id", "")) == desired_commodity:
				compatible_regions[str(facts.get("region_id", ""))] = true
	var result: Array = []
	for candidate_variant in candidates:
		if candidate_variant is Dictionary \
				and bool(compatible_regions.get(str((candidate_variant as Dictionary).get("region_id", "")), false)):
			result.append((candidate_variant as Dictionary).duplicate(true))
	return _sorted_target_candidates(result)


static func retry_signature(
	card: Dictionary,
	continuation_plan: Dictionary,
	target: Dictionary = {},
	failure_reason_id := ""
) -> String:
	var identity := str(card.get("card_instance_ref", card.get("id", ""))).strip_edges()
	var card_id := str(card.get("card_id", "")).strip_edges()
	if identity.is_empty() or card_id.is_empty():
		return ""
	var target_source_revision := maxi(0, int(continuation_plan.get("target_source_revision", 0)))
	if target_source_revision <= 0:
		target_source_revision = maxi(0, int(continuation_plan.get("source_revision", 0)))
	return "%s|%s|%s|%s|%s|%s|%d|%d|%s" % [
		identity,
		card_id,
		str(card.get("facility_kind", "")),
		str(card.get("industry_id", "")),
		str(continuation_plan.get("commodity_id", "")),
		str(target.get("region_id", "")),
		maxi(0, int(target.get("region_revision", 0))),
		target_source_revision,
		failure_reason_id.strip_edges(),
	]


static func rack_plan_signature(snapshot: Dictionary, continuation_plan: Dictionary) -> String:
	var rows: Array = []
	for card_variant in snapshot.get("cards", []) as Array:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		rows.append({
			"card_id": str(card.get("card_id", card.get("card_name", ""))),
			"slot": int(card.get("slot", -1)),
			"kind": str(card.get("kind", "")),
			"facility_kind": str(card.get("facility_kind", "")),
			"industry_id": str(card.get("industry_id", "")),
		})
	rows.sort_custom(func(left: Variant, right: Variant) -> bool:
		return JSON.stringify(left) < JSON.stringify(right)
	)
	return JSON.stringify({
		"region_id": str(snapshot.get("region_id", "")),
		"district_index": int(snapshot.get("district_index", -1)),
		"rack_source_revision": str(snapshot.get(
			"supply_revision",
			snapshot.get(
				"rack_revision",
				snapshot.get("rack_source_revision", snapshot.get("revision", ""))
			)
		)),
		"plan": {
			"commodity_id": str(continuation_plan.get("commodity_id", "")),
			"industry_id": str(continuation_plan.get("industry_id", "")),
			"desired_facility_kind": str(continuation_plan.get("desired_facility_kind", "")),
		},
		"cards": rows,
	}).sha256_text()


static func _sorted_target_candidates(candidates: Array) -> Array:
	var result: Array = []
	for candidate_variant in candidates:
		if candidate_variant is Dictionary:
			result.append((candidate_variant as Dictionary).duplicate(true))
	result.sort_custom(func(left: Variant, right: Variant) -> bool:
		var left_row := left as Dictionary
		var right_row := right as Dictionary
		var left_index := int(left_row.get("public_index", -1))
		var right_index := int(right_row.get("public_index", -1))
		if left_index != right_index:
			return left_index < right_index
		return str(left_row.get("region_id", "")) < str(right_row.get("region_id", ""))
	)
	return result


static func _public_progress_row(source: Dictionary) -> Dictionary:
	var aliases := [
		["top_k_gdp_per_minute", "top_k_gdp"],
		["required_top_k_gdp_per_minute", "required_top_k_gdp"],
		["controlled_region_count", "controlled_regions"],
		["required_region_count", "required_regions"],
	]
	for alias_variant in aliases:
		var alias := alias_variant as Array
		var value: Variant = source.get(str(alias[0]), source.get(str(alias[1]), null))
		if typeof(value) != TYPE_INT or int(value) < 0:
			return {}
	if typeof(source.get("eligible")) != TYPE_BOOL \
			or typeof(source.get("victory_state")) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return {}
	var victory_state := str(source.get("victory_state", ""))
	if victory_state not in ["idle", "qualification", "audit", "cooldown", "resolved"]:
		return {}
	return {
		"top_k_gdp": int(source.get("top_k_gdp_per_minute", source.get("top_k_gdp", 0))),
		"required_top_k_gdp": int(source.get("required_top_k_gdp_per_minute", source.get("required_top_k_gdp", 0))),
		"controlled_regions": int(source.get("controlled_region_count", source.get("controlled_regions", 0))),
		"required_regions": int(source.get("required_region_count", source.get("required_regions", 0))),
		"eligible": bool(source.get("eligible", false)),
		"victory_state": victory_state,
	}


static func _nonnegative_integer_field(source: Dictionary, field: String) -> bool:
	return typeof(source.get(field)) == TYPE_INT and int(source.get(field, -1)) >= 0


static func _commodity_bucket(by_commodity: Dictionary, commodity_id: String, industry_id: String) -> Dictionary:
	return (by_commodity.get(commodity_id, {
		"commodity_id": commodity_id,
		"industry_id": industry_id,
		"public_production_capacity": 0.0,
		"public_demand_capacity": 0.0,
		"public_settled_units": 0.0,
		"public_transport_units": 0.0,
		"public_waste_units": 0.0,
	}) as Dictionary).duplicate(true)


static func _facility_join_key(region_id: String, facility_kind: String, industry_id: String) -> String:
	return "%s|%s|%s" % [region_id.strip_edges(), facility_kind.strip_edges(), industry_id.strip_edges()]


static func _source_revision(value: Dictionary) -> int:
	return int(JSON.stringify(value).sha256_text().left(15).hex_to_int())


static func _plan(
	ready: bool,
	reason_id: String,
	desired_kind: String,
	desired_direction: String,
	commodity_id: String,
	industry_id: String,
	source_revision: int,
	stop: bool
) -> Dictionary:
	var result := {
		"schema_version": PLAN_SCHEMA_VERSION,
		"ready": ready,
		"reason_id": reason_id,
		"desired_facility_kind": desired_kind,
		"desired_direction": desired_direction,
		"commodity_id": commodity_id,
		"industry_id": industry_id,
		"source_revision": maxi(0, source_revision),
		"target_source_revision": 0,
		"stop": stop,
	}
	result["plan_fingerprint"] = JSON.stringify(result).sha256_text()
	return result
