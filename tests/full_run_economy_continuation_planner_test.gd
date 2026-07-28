extends SceneTree

const Planner := preload("res://scripts/tools/full_run_economy_continuation_planner.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var missing_market := Planner.plan(_observation(10, 0, 0.0, 1))
	_expect(_kind(missing_market) == "market" and _reason(missing_market) == "missing_matching_market", "factory without matching market selects a market")
	var missing_factory := Planner.plan(_observation(0, 10, 0.0, 0, "market"))
	_expect(_kind(missing_factory) == "factory" and _reason(missing_factory) == "missing_matching_factory", "market without matching factory selects a factory")
	var demand_bottleneck := Planner.plan(_observation(80, 20, 0.0, 3))
	_expect(_kind(demand_bottleneck) == "market" and _reason(demand_bottleneck) == "demand_capacity_bottleneck", "production above demand selects a market")
	var production_bottleneck := Planner.plan(_observation(20, 80, 0.0, 2, "market"))
	_expect(_kind(production_bottleneck) == "factory" and _reason(production_bottleneck) == "production_capacity_bottleneck", "demand above production selects a factory")
	var waste_pressure := Planner.plan(_observation(20, 20, 4.0, 3))
	_expect(_kind(waste_pressure) == "market" and _reason(waste_pressure) == "production_waste_dominant", "waste pressure forbids another same-product factory and selects a market")
	var balanced_floor := Planner.plan(_observation(20, 20, 0.0, 2))
	_expect(_kind(balanced_floor) == "factory" and _reason(balanced_floor) == "production_floor_incomplete", "a balanced chain below the minimum production proof may scale production")
	var initial := Planner.plan(_empty_observation())
	_expect(_kind(initial) == "factory" and str(initial.get("industry_id", "")).is_empty(), "an empty economy starts with a typed factory without guessing a name")
	var tied_observation := _observation(10, 0, 0.0, 1)
	var beta_row := ((tied_observation.get("commodity_rows", []) as Array)[0] as Dictionary).duplicate(true)
	beta_row["commodity_id"] = "commodity.beta"
	beta_row["industry_id"] = "shipping"
	(tied_observation.get("commodity_rows", []) as Array).append(beta_row)
	var beta_facility := _facility("production-beta", "factory", "production", 10.0)
	beta_facility["commodity_id"] = "commodity.beta"
	beta_facility["industry_id"] = "shipping"
	(tied_observation.get("facility_rows", []) as Array).append(beta_facility)
	var tied_plan := Planner.plan(tied_observation)
	var tied_ranked_plans := Planner.ranked_plans(tied_observation)
	var reordered_tie := tied_observation.duplicate(true)
	(reordered_tie.get("commodity_rows", []) as Array).reverse()
	(reordered_tie.get("facility_rows", []) as Array).reverse()
	_expect(str(tied_plan.get("commodity_id", "")) == "commodity.alpha" and Planner.plan(reordered_tie) == tied_plan, "equal-priority choices use stable semantic IDs instead of source row order")
	_expect(
		tied_ranked_plans.size() == 2 \
			and str((tied_ranked_plans[0] as Dictionary).get("commodity_id", "")) \
				== "commodity.alpha" \
			and str((tied_ranked_plans[1] as Dictionary).get("commodity_id", "")) \
				== "commodity.beta",
		"ranked complementary plans preserve the same deterministic priority order for bounded visible fallback"
	)

	var cards := [
		{"id": "hand_0", "card_instance_ref": "card.instance.alpha", "card_id": "facility.factory.energy.rank_1", "kind": "facility_v06", "facility_kind": "factory", "industry_id": "energy", "actionable": true, "display_name": "任意本地化A"},
		{"id": "hand_1", "card_instance_ref": "card.instance.beta", "card_id": "facility.market.energy.rank_1", "kind": "facility_v06", "facility_kind": "market", "industry_id": "energy", "actionable": true, "display_name": "任意本地化B"},
		{"id": "hand_2", "card_instance_ref": "card.instance.gamma", "card_id": "facility.market.shipping.rank_1", "kind": "facility_v06", "facility_kind": "market", "industry_id": "shipping", "actionable": true},
	]
	var selected := Planner.first_matching_facility(cards, missing_market, true)
	_expect(str(selected.get("card_id", "")) == "facility.market.energy.rank_1", "matching hand facility wins before unrelated factory or market")
	selected["industry_id"] = "mutated"
	_expect(str((cards[1] as Dictionary).get("industry_id", "")) == "energy", "selected facility results are deep-detached from the authorized card projection")
	var localized_cards := cards.duplicate(true)
	(localized_cards[1] as Dictionary)["display_name"] = "完全不同的文字"
	(localized_cards[1] as Dictionary)["tooltip"] = "颜色与图标也不同"
	_expect(str(Planner.first_matching_facility(localized_cards, missing_market, true).get("card_id", "")) == str(selected.get("card_id", "")), "display name tooltip and color never affect the semantic choice")
	var disabled_cards := cards.duplicate(true)
	(disabled_cards[1] as Dictionary)["actionable"] = false
	_expect(Planner.first_matching_facility(disabled_cards, missing_market, true).is_empty(), "an unrelated facility is not substituted for a disabled matching facility")
	var missing_stable_card_id := (cards[1] as Dictionary).duplicate(true)
	missing_stable_card_id.erase("card_id")
	_expect(Planner.first_matching_facility([missing_stable_card_id], missing_market, true).is_empty(), "facility selection fails closed without a stable card ID")

	var candidates := [
		{"region_id": "region.alpha", "public_index": 2, "region_revision": 7},
		{"region_id": "region.beta", "public_index": 1, "region_revision": 9},
	]
	var facts := [
		{"region_id": "region.alpha", "production_products": [], "demand_products": [{"product_id": "commodity.other"}]},
		{"region_id": "region.beta", "production_products": [], "demand_products": [{"product_id": "commodity.alpha"}]},
	]
	var compatible := Planner.matching_target_candidates(candidates, facts, missing_market)
	_expect(compatible.size() == 1 and str((compatible[0] as Dictionary).get("region_id", "")) == "region.beta", "typed target filtering retries another public region with the matching commodity")
	_expect(Planner.matching_target_candidates(candidates, facts, demand_bottleneck).size() == 1, "market target matching remains deterministic for the same commodity")
	var unbound_candidates := candidates.duplicate(true)
	unbound_candidates.reverse()
	var initial_targets := Planner.matching_target_candidates(unbound_candidates, facts, initial)
	_expect(int((initial_targets[0] as Dictionary).get("public_index", -1)) == 1 and int((initial_targets[1] as Dictionary).get("public_index", -1)) == 2, "an unbound initial plan still returns targets in deterministic public-index order")

	var signature_a := Planner.retry_signature(cards[1], missing_market, compatible[0], "public_facility_slot_occupied")
	var changed_target := (compatible[0] as Dictionary).duplicate(true)
	changed_target["region_revision"] = 10
	var signature_b := Planner.retry_signature(cards[1], missing_market, changed_target, "public_facility_slot_occupied")
	var changed_plan := missing_market.duplicate(true)
	changed_plan["target_source_revision"] = 99
	var signature_c := Planner.retry_signature(cards[1], changed_plan, compatible[0], "public_facility_slot_occupied")
	_expect(not signature_a.is_empty() and signature_a != signature_b and signature_a != signature_c, "target and source revision changes create new retry identities")
	var changed_observation_revision := missing_market.duplicate(true)
	changed_observation_revision["source_revision"] = int(missing_market.get("source_revision", 0)) + 1
	_expect(signature_a != Planner.retry_signature(cards[1], changed_observation_revision, compatible[0], "public_facility_slot_occupied"), "observation revision participates when no target-specific revision is bound")
	var renamed := (cards[1] as Dictionary).duplicate(true)
	renamed["display_name"] = "不会进入签名"
	_expect(signature_a == Planner.retry_signature(renamed, missing_market, compatible[0], "public_facility_slot_occupied"), "retry identity excludes localized display text")
	_expect(Planner.retry_signature({"card_id": "facility.market.energy.rank_1"}, missing_market).is_empty(), "missing stable card instance identity fails closed")

	var rack := {
		"region_id": "region.alpha",
		"district_index": 2,
		"supply_revision": 5,
		"cards": [cards[1]],
	}
	var rack_signature := Planner.rack_plan_signature(rack, missing_market)
	_expect(rack_signature == Planner.rack_plan_signature(rack, missing_market), "unchanged rack plus plan has one stable signature")
	var changed_rack := rack.duplicate(true)
	changed_rack["supply_revision"] = 6
	_expect(rack_signature != Planner.rack_plan_signature(changed_rack, missing_market), "a real rack revision admits a new evaluation")
	var string_revision_rack := rack.duplicate(true)
	string_revision_rack["supply_revision"] = "rack-revision-a"
	var string_revision_signature := Planner.rack_plan_signature(string_revision_rack, missing_market)
	string_revision_rack["supply_revision"] = "rack-revision-b"
	_expect(string_revision_signature != Planner.rack_plan_signature(string_revision_rack, missing_market), "opaque authoritative rack revision tokens are preserved in the signature")
	var dynamic_projection_rack := rack.duplicate(true)
	var dynamic_card := (cards[1] as Dictionary).duplicate(true)
	dynamic_card["actionable"] = not bool(dynamic_card.get("actionable", false))
	dynamic_card["target_source_revision"] = 999
	dynamic_card["continuation_target_available"] = false
	dynamic_projection_rack["cards"] = [dynamic_card]
	_expect(
		rack_signature == Planner.rack_plan_signature(dynamic_projection_rack, missing_market),
		"quote, target, and daylight projections do not change stable rack identity"
	)
	var multi_card_rack := rack.duplicate(true)
	multi_card_rack["cards"] = [cards[1], cards[2]]
	var reordered_rack := multi_card_rack.duplicate(true)
	(reordered_rack.get("cards", []) as Array).reverse()
	_expect(Planner.rack_plan_signature(multi_card_rack, missing_market) == Planner.rack_plan_signature(reordered_rack, missing_market), "rack signatures canonicalize card rows before hashing")
	_expect(rack_signature != Planner.rack_plan_signature(rack, missing_factory), "a changed complementary plan admits a new rack evaluation")

	var locked := _observation(10, 0, 3.0, 3)
	(locked.get("public_progress", {}) as Dictionary)["eligible"] = true
	_expect(bool(Planner.plan(locked).get("stop", false)), "eligible locks all further facility growth")
	for state in ["qualification", "audit", "resolved"]:
		var lifecycle := _observation(10, 0, 3.0, 3)
		(lifecycle.get("public_progress", {}) as Dictionary)["victory_state"] = state
		_expect(bool(Planner.plan(lifecycle).get("stop", false)), "%s locks all further facility growth" % state)
	var cooldown := _observation(10, 0, 3.0, 3)
	(cooldown.get("public_progress", {}) as Dictionary)["victory_state"] = "cooldown"
	_expect(not bool(Planner.plan(cooldown).get("stop", true)) and _kind(Planner.plan(cooldown)) == "market", "cooldown may resume a legal complementary plan")
	_finish()


func _observation(
	production: float,
	demand: float,
	waste: float,
	production_facility_count: int,
	base_kind := "factory"
) -> Dictionary:
	var facilities: Array = []
	for index in range(production_facility_count):
		facilities.append(_facility("production-%d" % index, "factory", "production", 10.0))
	if base_kind == "market" or demand > 0.0:
		facilities.append(_facility("demand-0", "market", "demand", demand))
	return {
		"schema_version": 1,
		"source_revision": 7,
		"visibility_scope": "viewer_safe_aggregate",
		"commodity_rows": [{
			"commodity_id": "commodity.alpha",
			"industry_id": "energy",
			"public_production_capacity": production,
			"public_demand_capacity": demand,
			"public_settled_units": 2.0,
			"public_transport_units": 0.0,
			"public_waste_units": waste,
		}],
		"facility_rows": facilities,
		"public_progress": {
			"top_k_gdp": 59,
			"required_top_k_gdp": 108,
			"controlled_regions": 3,
			"required_regions": 3,
			"eligible": false,
			"victory_state": "idle",
		},
	}


func _empty_observation() -> Dictionary:
	var result := _observation(0, 0, 0, 0)
	result["commodity_rows"] = []
	result["facility_rows"] = []
	return result


func _facility(id: String, kind: String, direction: String, capacity: float) -> Dictionary:
	return {
		"facility_instance_id": id,
		"facility_kind": kind,
		"commodity_id": "commodity.alpha",
		"industry_id": "energy",
		"region_id": "region.%s" % id,
		"direction": direction,
		"base_units_per_minute": capacity,
		"active": true,
	}


func _kind(plan: Dictionary) -> String:
	return str(plan.get("desired_facility_kind", ""))


func _reason(plan: Dictionary) -> String:
	return str(plan.get("reason_id", ""))


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	for failure in _failures:
		push_error("FULL_RUN_ECONOMY_CONTINUATION_PLANNER: %s" % failure)
	print("FULL_RUN_ECONOMY_CONTINUATION_PLANNER|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(_failures.size())
