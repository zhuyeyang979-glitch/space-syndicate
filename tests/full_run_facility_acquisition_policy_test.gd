extends SceneTree

const DriverScript := preload("res://scripts/tools/full_run_quality_driver.gd")

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
		"actionable": true,
	})
	var opening_with_facility := DriverScript.district_supply_action_from_snapshot(mixed_snapshot, true)
	_expect(str(opening_with_facility.get("id", "")) == "district_supply_preview_card", "opening strategy selects the visible facility through the Drawer action")
	_expect(str((opening_with_facility.get("payload", {}) as Dictionary).get("card_name", "")) == "facility.factory.energy.rank_1", "facility selection uses only the visible card identity")
	var dark_facility := mixed_snapshot.duplicate(true)
	(dark_facility["cards"] as Array)[1]["actionable"] = false
	var dark_facility_wait := DriverScript.district_supply_action_from_snapshot(dark_facility, true)
	_expect(str(dark_facility_wait.get("id", "")) == "district_supply_wait", "a visible dark-side facility remains viewable but never produces an invalid quote request")

	var quoted_facility := _snapshot(
		"facility.factory.energy.rank_1",
		"facility",
		"district_supply_purchase_card",
		[{
			"card_name": "facility.factory.energy.rank_1",
			"kind": "facility",
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
	_expect(DriverScript.recoverable_supply_receipt_reason("locked_quote_changed") and DriverScript.recoverable_supply_receipt_reason("source_region_dark"), "volatile quote and illumination receipts remain retryable human interactions")
	_expect(not DriverScript.recoverable_supply_receipt_reason("purchase_target_invalid"), "structural purchase rejection is never hidden as a retryable quote race")
	_expect(not JSON.stringify(opening_without_facility).contains("future") and not JSON.stringify(opening_with_facility).contains("future"), "facility search exposes no future supply-bag data")
	_finish()


func _snapshot(preview_card: String, preview_kind: String, primary_action_id: String, cards: Array) -> Dictionary:
	return {
		"preview": {
			"card_name": preview_card,
			"kind": preview_kind,
			"buy_enabled": true,
			"primary_action_id": primary_action_id,
			"action_reason_code": "",
		},
		"cards": cards.duplicate(true),
	}


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
