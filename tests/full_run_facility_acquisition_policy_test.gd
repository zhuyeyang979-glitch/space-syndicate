extends SceneTree

const DriverScript := preload("res://scripts/tools/full_run_quality_driver.gd")
const PRODUCT_INDUSTRY_CATALOG: ProductIndustryCatalogResource = preload("res://resources/content/product_industry_catalog_v05.tres")


class FakeInfrastructureController extends Node:
	var revision := 1
	var regions: Array = []
	var facilities: Array = []

	func regions_snapshot() -> Array:
		return regions.duplicate(true)

	func region_snapshot(region_id: String) -> Dictionary:
		for region_variant in regions:
			if region_variant is Dictionary \
					and str((region_variant as Dictionary).get("region_id", "")) == region_id:
				return (region_variant as Dictionary).duplicate(true)
		return {}

	func public_economy_snapshot() -> Dictionary:
		var public_regions: Array = []
		for region_variant in regions:
			if region_variant is Dictionary:
				var region := region_variant as Dictionary
				public_regions.append({
					"region_id": str(region.get("region_id", "")),
					"lifecycle_state": str(region.get("lifecycle_state", "")),
				})
		return {
			"available": true,
			"revision": revision,
			"visibility_scope": "public",
			"regions": public_regions,
			"facilities": facilities.duplicate(true),
		}

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var military_snapshot := _snapshot(
		"unit.military.submarine_fleet.rank_1",
		"unit_v06",
		"district_supply_purchase_card",
		[{
			"card_name": "unit.military.submarine_fleet.rank_1",
			"kind": "unit_v06",
			"actionable": true,
		}]
	)
	var opening_without_facility := DriverScript.district_supply_action_from_snapshot(military_snapshot, true)
	_expect(str(opening_without_facility.get("id", "")) == "district_supply_wait", "opening strategy does not buy an unrelated visible unit")
	_expect(str(opening_without_facility.get("phase", "")).contains("facility_not_visible"), "opening strategy reports the public facility-visibility wait")

	var mixed_snapshot := military_snapshot.duplicate(true)
	(mixed_snapshot["cards"] as Array).append({
		"card_name": "facility.factory.energy.rank_1",
		"kind": "facility",
		"facility_kind": "factory",
		"industry_id": "energy",
		"new_target_available": true,
		"actionable": true,
	})
	var opening_with_facility := DriverScript.district_supply_action_from_snapshot(mixed_snapshot, true)
	_expect(str(opening_with_facility.get("id", "")) == "district_supply_preview_card", "opening strategy selects the visible facility through the Drawer action")
	_expect(str((opening_with_facility.get("payload", {}) as Dictionary).get("card_name", "")) == "facility.factory.energy.rank_1", "facility selection uses only the visible card identity")
	var no_target_snapshot := mixed_snapshot.duplicate(true)
	(no_target_snapshot["cards"] as Array)[1]["new_target_available"] = false
	var opening_without_target := DriverScript.district_supply_action_from_snapshot(no_target_snapshot, true)
	_expect(str(opening_without_target.get("id", "")) == "district_supply_wait", "opening strategy does not buy a factory before the typed query proves a new public target")
	var dark_facility := mixed_snapshot.duplicate(true)
	(dark_facility["cards"] as Array)[1]["actionable"] = false
	var dark_facility_select := DriverScript.district_supply_action_from_snapshot(dark_facility, true)
	_expect(str(dark_facility_select.get("id", "")) == "district_supply_preview_card" and str((dark_facility_select.get("payload", {}) as Dictionary).get("card_name", "")) == "facility.factory.energy.rank_1", "a visible dark-side facility is selected for its typed public reason without submitting an invalid quote")
	var dark_selected := _snapshot(
		"facility.factory.energy.rank_1",
		"facility",
		"",
		[{"card_name": "facility.factory.energy.rank_1", "kind": "facility", "facility_kind": "factory", "industry_id": "energy", "actionable": false}]
	)
	(dark_selected["preview"] as Dictionary)["buy_enabled"] = false
	(dark_selected["preview"] as Dictionary)["action_reason_code"] = "source_region_dark"
	var dark_facility_wait := DriverScript.district_supply_action_from_snapshot(dark_selected, true)
	_expect(str(dark_facility_wait.get("id", "")) == "district_supply_wait" and str(dark_facility_wait.get("phase", "")).contains("reason_source_region_dark"), "a selected dark-side facility waits with its qualitative typed reason")

	var quoted_facility := _snapshot(
		"facility.factory.energy.rank_1",
		"facility",
		"district_supply_purchase_card",
		[{
			"card_name": "facility.factory.energy.rank_1",
			"kind": "facility",
			"facility_kind": "factory",
			"industry_id": "energy",
			"actionable": true,
		}]
	)
	var facility_purchase := DriverScript.district_supply_action_from_snapshot(quoted_facility, true)
	_expect(str(facility_purchase.get("id", "")) == "district_supply_purchase_card", "a quote-backed visible facility remains purchasable during opening")

	var unquoted_facility := quoted_facility.duplicate(true)
	(unquoted_facility["preview"] as Dictionary)["primary_action_id"] = "district_supply_preview_card"
	var facility_quote := DriverScript.district_supply_action_from_snapshot(unquoted_facility, true)
	_expect(str(facility_quote.get("id", "")) == "district_supply_preview_card", "an unquoted visible facility requests its normal production quote")
	var hand_alias := quoted_facility.duplicate(true)
	(hand_alias["cards"] as Array)[0]["kind"] = "facility_v06"
	var alias_purchase := DriverScript.district_supply_action_from_snapshot(hand_alias, true)
	_expect(str(alias_purchase.get("id", "")) == "district_supply_purchase_card", "the private hand-style facility alias remains compatible without name inference")

	var mature_strategy := DriverScript.district_supply_action_from_snapshot(military_snapshot, false)
	_expect(str(mature_strategy.get("id", "")) == "district_supply_purchase_card", "after the facility chain is complete, ordinary visible purchases remain available")
	_expect(DriverScript.recoverable_supply_receipt_reason("locked_quote_changed") and DriverScript.recoverable_supply_receipt_reason("source_region_dark") and DriverScript.recoverable_supply_receipt_reason("card_not_in_supply") and DriverScript.recoverable_supply_receipt_reason("forced_decision_blocks_district_supply"), "volatile quote, illumination, stale listing, and forced-decision preflight receipts remain retryable human interactions")
	_expect(not DriverScript.recoverable_supply_receipt_reason("purchase_target_invalid"), "structural purchase rejection is never hidden as a retryable quote race")
	_expect(not JSON.stringify(opening_without_facility).contains("future") and not JSON.stringify(opening_with_facility).contains("future"), "facility search exposes no future supply-bag data")
	var exhausted_districts := {0: true}
	_expect(DriverScript.next_unexhausted_map_district(0, 4, exhausted_districts) == 1, "facility retargeting selects the next untested public district")
	for district_index in range(4):
		exhausted_districts[district_index] = true
	_expect(DriverScript.next_unexhausted_map_district(3, 4, exhausted_districts) == -1, "facility retargeting stops after every public district was tested once")
	var blocked_cards := [
		{"id": "hand_0", "slot": 0, "name": "工厂设施", "kind": "facility_v06", "facility_kind": "factory", "industry_id": "technology"},
		{"id": "hand_1", "slot": 1, "name": "市场设施", "kind": "facility_v06", "facility_kind": "market", "industry_id": "shipping"},
	]
	var first_signature := DriverScript.facility_card_retry_signature(blocked_cards[0])
	var next_blocked := DriverScript.first_unexhausted_card_by_kind(blocked_cards, "facility_v06", {first_signature: true})
	_expect(str(next_blocked.get("id", "")) == "hand_1", "an exhausted facility card yields to the next owned facility without revisiting hidden supply")
	var production_only := DriverScript.first_unexhausted_card_by_kind(blocked_cards, "facility_v06", {}, "factory")
	_expect(str(production_only.get("id", "")) == "hand_0", "production search uses the typed facility kind and does not infer factory identity from the card id or label")
	_exercise_public_facility_target_query()
	_finish()


func _snapshot(preview_card: String, preview_kind: String, primary_action_id: String, cards: Array) -> Dictionary:
	var normalized_cards := cards.duplicate(true)
	for card_variant in normalized_cards:
		if card_variant is Dictionary \
				and str((card_variant as Dictionary).get("facility_kind", "")) == "factory" \
				and not (card_variant as Dictionary).has("new_target_available"):
			(card_variant as Dictionary)["new_target_available"] = true
	return {
		"preview": {
			"card_name": preview_card,
			"kind": preview_kind,
			"buy_enabled": true,
			"primary_action_id": primary_action_id,
			"action_reason_code": "",
		},
		"cards": normalized_cards,
	}


func _exercise_public_facility_target_query() -> void:
	var energy_product := _first_product_for_industry("energy")
	var technology_product := _first_product_for_industry("technology")
	var state := WorldSessionState.new()
	state.replace_districts([
		{"region_id": "region.alpha", "products": [energy_product], "demands": [], "destroyed": false},
		{"region_id": "region.beta", "products": [energy_product], "demands": [], "destroyed": false},
		{"region_id": "region.gamma", "products": [technology_product], "demands": [], "destroyed": false},
		{"region_id": "region.delta", "products": [energy_product], "demands": [], "destroyed": true},
		{"region_id": "region.epsilon", "products": [energy_product], "demands": [], "destroyed": true},
	], true)
	var infrastructure := FakeInfrastructureController.new()
	for index in range(state.districts.size()):
		var district := state.districts[index] as Dictionary
		infrastructure.regions.append({
			"region_id": str(district.get("region_id", "")),
			"legacy_index": index,
			"revision": index + 1,
			"lifecycle_state": "ruined" if index == 4 else ("legacy_unmapped" if index == 3 else "active"),
		})
	infrastructure.facilities = [{
		"region_id": "region.beta",
		"facility_type": "factory",
		"industry_id": "energy",
		"rank": 1,
		"active": true,
		"owner_visibility": "public",
		"owner_kind": "player",
		"owner_player_index": 2,
	}]
	var bridge := RegionInfrastructureWorldBridge.new()
	bridge.set_controller(infrastructure)
	bridge.set_world_session_state(state)
	var ports := TablePresentationQueryPorts.new()
	ports.region_infrastructure_public_query = bridge
	var first := ports.public_new_facility_target_candidates(&"factory", &"energy")
	var first_data := first.to_dictionary()
	var expected_candidates := [
		{"region_id": "region.alpha", "public_index": 0, "region_revision": 1},
		{"region_id": "region.epsilon", "public_index": 4, "region_revision": 5},
	]
	_expect(first.is_valid() and bool(first_data.get("available", false)) and first_data.get("candidates", []) == expected_candidates, "typed target query excludes occupied, mismatched, and invalid-lifecycle regions while retaining a real ruined/destroyed projection")
	_expect(TablePresentationPureDataPolicy.is_pure_data(first_data) and not JSON.stringify(first_data).contains("owner") and not JSON.stringify(first_data).contains("facility_id") and not JSON.stringify(first_data).contains("slot_id"), "typed target snapshot is pure public data with no owner, facility, or slot identity")
	var repeated := ports.public_new_facility_target_candidates(&"factory", &"energy").to_dictionary()
	_expect(repeated == first_data, "unchanged public target inputs preserve deterministic ordering and source revision")
	_expect(DriverScript.next_public_facility_candidate(first_data.get("candidates", []), {0: true}).get("public_index", -1) == 4, "driver consumes ordered typed candidates and skips an explicitly attempted public index")
	infrastructure.revision = 2
	infrastructure.facilities.append({
		"region_id": "region.alpha",
		"facility_type": "factory",
		"industry_id": "energy",
		"rank": 1,
		"active": true,
		"owner_visibility": "public",
		"owner_kind": "neutral",
		"owner_player_index": -1,
	})
	var changed := ports.public_new_facility_target_candidates(&"factory", &"energy").to_dictionary()
	_expect(changed.get("candidates", []) == [expected_candidates[1]] and int(changed.get("source_revision", -1)) != int(first_data.get("source_revision", -1)), "public occupancy revision removes the candidate and changes the source revision exactly once")
	var invalid := ports.public_new_facility_target_candidates(&"factory", &"unknown").to_dictionary()
	_expect(not bool(invalid.get("available", true)) and (invalid.get("candidates", []) as Array).is_empty(), "unknown typed industry fails closed without blind region fallback")
	ports.free()
	bridge.free()
	infrastructure.free()
	state.free()


func _first_product_for_industry(industry_id: String) -> String:
	for product_id_variant in PRODUCT_INDUSTRY_CATALOG.product_ids():
		var product_id := str(product_id_variant)
		if PRODUCT_INDUSTRY_CATALOG.industry_for_product(product_id) == industry_id:
			return product_id
	return ""


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	printerr("FAIL: %s" % message)


func _finish() -> void:
	print("Full-run facility acquisition policy checks: %d" % _checks)
	if _failures.is_empty():
		print("FULL_RUN_FACILITY_ACQUISITION_POLICY_TEST_COMPLETE")
		quit(0)
		return
	printerr("Full-run facility acquisition policy failures: %s" % ", ".join(_failures))
	quit(1)
