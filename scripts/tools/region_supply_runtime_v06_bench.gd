@tool
extends Node
class_name RegionSupplyRuntimeV06Bench

@onready var controller: RegionSupplyRuntimeController = get_node_or_null("RegionSupplyRuntimeController") as RegionSupplyRuntimeController

var _ran := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_run")


func _run() -> void:
	if _ran:
		return
	_ran = true
	var checks: Array[Dictionary] = []
	checks.append(_check(controller != null, "controller_scene_loaded"))
	if controller == null:
		_finish(checks)
		return
	var configured := controller.configure(
		606120,
		[
			{"region_id": "bench.land", "region_index": 0, "terrain": "land", "active": true},
			{"region_id": "bench.ocean", "region_index": 1, "terrain": "ocean", "active": true},
		],
		[
			{"card_id": "bench.factory", "family_id": "factory", "card_type": "facility_factory", "rank": "I", "price_cash": 10},
			{"card_id": "bench.market", "family_id": "market", "card_type": "facility_market", "rank": "I", "price_cash": 10},
			{"card_id": "bench.route", "family_id": "route", "card_type": "route", "rank": "I", "price_cash": 8},
			{"card_id": "bench.monster", "family_id": "monster", "card_type": "monster", "rank": "I", "price_cash": 12},
			{"card_id": "bench.commodity", "family_id": "commodity", "card_type": "commodity", "rank": "I", "price_cash": 0},
		],
		3
	)
	checks.append(_check(bool(configured.get("configured", false)), "deterministic_owner_configured"))
	var snapshot := controller.public_rack_snapshot()
	checks.append(_check((snapshot.get("regions", []) as Array).size() == 2, "two_public_region_racks"))
	checks.append(_check(not JSON.stringify(snapshot).contains("bags_by_region"), "future_bag_private"))
	var land := controller.public_rack_snapshot("bench.land")
	var slots: Array = ((land.get("regions", []) as Array)[0] as Dictionary).get("slots", [])
	var listing: Dictionary = slots[0]
	var prepared := controller.prepare_slot_refill(
		"bench.land",
		0,
		str(listing.get("item_id", "")),
		str(listing.get("supply_revision", "")),
		"bench-refill"
	)
	var committed := controller.commit_slot_refill("bench-refill")
	var finalized := controller.finalize_slot_refill("bench-refill")
	checks.append(_check(
		bool(prepared.get("prepared", false))
		and bool(committed.get("committed", false))
		and bool(finalized.get("finalized", false)),
		"single_slot_lifecycle"
	))
	checks.append(_check(bool(controller.apply_save_data(controller.to_save_data()).get("applied", false)), "save_roundtrip"))
	_finish(checks)


func _check(passed: bool, case_id: String) -> Dictionary:
	return {"case_id": case_id, "passed": passed}


func _finish(checks: Array[Dictionary]) -> void:
	var failed: Array[String] = []
	for row in checks:
		if not bool(row.get("passed", false)):
			failed.append(str(row.get("case_id", "")))
	var passed_count := checks.size() - failed.size()
	print("REGION_SUPPLY_RUNTIME_V06_BENCH|status=%s|passed=%d|total=%d|failed=%s" % [
		"PASS" if failed.is_empty() else "FAIL",
		passed_count,
		checks.size(),
		JSON.stringify(failed),
	])
	get_tree().quit(0 if failed.is_empty() else 1)
