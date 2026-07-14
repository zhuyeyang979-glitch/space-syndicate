extends SceneTree

const PROFILE_PATH := "res://resources/rules/space_syndicate_ruleset_v06.tres"
const PRODUCT_CATALOG_PATH := "res://resources/content/product_industry_catalog_v05.tres"
const FLOW_SCRIPT := preload("res://scripts/runtime/commodity_flow_runtime_controller.gd")
const SINK_SCRIPT := preload("res://scripts/cards/v06/production/commodity_flow_atomic_batch_sink_v06.gd")

var _checks := 0
var _failures: Array[String] = []
var _product_id := ""
var _industry_id := ""


class CapturingWorldBridge:
	extends Node

	var facts: Dictionary = {}
	var batches: Array = []
	var applied_batch_ids: Dictionary = {}

	func capture_flow_facts() -> Dictionary:
		return facts.duplicate(true)

	func apply_sale_receipt_batch(batch: Dictionary) -> Dictionary:
		var batch_id := str(batch.get("batch_id", ""))
		if batch_id.is_empty():
			return {"applied": false, "reason": "batch_id_missing"}
		if applied_batch_ids.has(batch_id):
			return {"applied": true, "duplicate": true, "batch_id": batch_id}
		applied_batch_ids[batch_id] = true
		batches.append(batch.duplicate(true))
		return {"applied": true, "duplicate": false, "batch_id": batch_id}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow_script := load("res://scripts/runtime/commodity_flow_runtime_controller.gd") as Script
	_expect(flow_script != null and flow_script.can_instantiate(), "CommodityFlow production owner parses and can be instantiated")
	if flow_script == null or not flow_script.can_instantiate():
		_finish()
		return
	var catalog := load(PRODUCT_CATALOG_PATH)
	var product_ids: Array = catalog.call("product_ids") if catalog != null and catalog.has_method("product_ids") else []
	if not product_ids.is_empty():
		_product_id = str(product_ids.front())
		_industry_id = str(catalog.call("industry_for_product", _product_id))
	_expect(not _product_id.is_empty() and not _industry_id.is_empty(), "real product catalog resolves a product and industry")
	_verify_fail_closed_without_owner()
	_verify_order_real_flow_exact_once_and_settled_rollback_boundary()
	_verify_supply_pending_rollback_is_atomic()
	_verify_save_load_preserves_exact_once_journal()
	_verify_shared_capacity_is_aggregated()
	_verify_invalid_child_is_zero_effect()
	_finish()


func _verify_fail_closed_without_owner() -> void:
	var sink = SINK_SCRIPT.new()
	var prepared: Dictionary = sink.prepare_batch(_plan("tx-no-owner", "extra_demand", 1, {}))
	_expect(not bool(prepared.get("prepared", true)) and str(prepared.get("reason_code", "")) == "commodity_flow_owner_unavailable", "sink fails closed without the authoritative CommodityFlow owner")


func _verify_order_real_flow_exact_once_and_settled_rollback_boundary() -> void:
	var fixture := _fixture(true, "sea", 3)
	var flow: Node = fixture.flow
	var sink = fixture.sink
	var bridge: CapturingWorldBridge = fixture.bridge
	var baseline_batch_count := bridge.batches.size()
	var plan := _plan("tx-order-real", "extra_demand", 2, fixture.snapshot as Dictionary)
	var prepared: Dictionary = sink.prepare_batch(plan)
	_expect(bool(prepared.get("prepared", false)), "real order batch prepares against active production, market, route and topology facts")
	var committed: Dictionary = sink.commit_batch(prepared)
	_expect(bool(committed.get("committed", false)) and str(committed.get("state", "")) == "pending_flow", "order commit writes one pending batch to the CommodityFlow owner")
	var replay: Dictionary = sink.commit_batch(prepared)
	_expect(bool(replay.get("committed", false)) and bool(replay.get("duplicate", false)), "order transaction replay does not enqueue demand twice")
	_expect(int(flow.debug_snapshot().get("pending_one_shot_demand_count", -1)) == 1, "exact-once replay leaves one pending extra-demand claim")
	var advanced: Dictionary = flow.advance_world(60.0)
	_expect(bool(advanced.get("advanced", false)) and int(advanced.get("receipt_count", 0)) >= 2, "extra demand consumes real factory flow and creates normal sale receipts")
	_expect(bridge.batches.size() > baseline_batch_count, "world bridge receives the post-order CommodityFlow-authored receipt batch")
	var latest_batch: Dictionary = bridge.batches.back() as Dictionary
	var sale: Dictionary = ((latest_batch.get("receipts", []) as Array).front() as Dictionary)
	_expect(str(sale.get("source_factory_id", "")) == "factory-a" and str(sale.get("market_facility_id", "")) == "market-a", "order sale receipt retains real factory and market lineage")
	_expect(int(sale.get("commodity_owner", -1)) == 0 and int(sale.get("gdp_value", 0)) > 0, "GDP and cash entitlement stay with the commodity owner through a normal receipt")
	var settled: Dictionary = flow.card_effect_batch_snapshot("tx-order-real")
	_expect(bool(settled.get("settled", false)) and int(settled.get("consumed_milliunits", 0)) == 2000, "order batch journal records settled real demand without synthesizing an extra receipt")
	var rollback: Dictionary = sink.rollback_batch(committed)
	_expect(not bool(rollback.get("rolled_back", true)) and str(rollback.get("reason_code", "")) == "batch_rollback_closed", "a settled batch closes its rollback window after the real flow tick has paid sale receipts")
	bridge.free()
	flow.free()


func _verify_supply_pending_rollback_is_atomic() -> void:
	var fixture := _fixture(true, "land", 2)
	var flow: Node = fixture.flow
	var sink = fixture.sink
	var plan := _plan("tx-supply-rollback", "physical_supply", 3, fixture.snapshot as Dictionary)
	var prepared: Dictionary = sink.prepare_batch(plan)
	var committed: Dictionary = sink.commit_batch(prepared)
	_expect(bool(committed.get("committed", false)) and int(flow.debug_snapshot().get("pending_one_shot_count", 0)) == 1, "physical supply is pending in the real flow owner before settlement")
	var rollback: Dictionary = sink.rollback_batch(committed)
	_expect(bool(rollback.get("rolled_back", false)) and int(flow.debug_snapshot().get("pending_one_shot_count", -1)) == 0, "pre-tick rollback removes every physical-supply child atomically")
	var rollback_replay: Dictionary = sink.rollback_batch(committed)
	_expect(bool(rollback_replay.get("rolled_back", false)) and bool(rollback_replay.get("duplicate", false)), "rollback itself is exact-once")
	var commit_replay: Dictionary = sink.commit_batch(prepared)
	_expect(not bool(commit_replay.get("committed", true)) and bool(commit_replay.get("rolled_back", false)), "rolled-back transaction cannot be replayed to recreate goods")
	fixture.bridge.free()
	flow.free()


func _verify_save_load_preserves_exact_once_journal() -> void:
	var fixture := _fixture(true, "land", 2)
	var original: Node = fixture.flow
	var prepared: Dictionary = fixture.sink.prepare_batch(_plan("tx-save-load", "physical_supply", 4, fixture.snapshot as Dictionary))
	var committed: Dictionary = fixture.sink.commit_batch(prepared)
	_expect(bool(committed.get("committed", false)), "save/load fixture commits a pending supply batch")
	var save_data: Dictionary = original.to_save_data()
	var restored = FLOW_SCRIPT.new()
	var profile := load(PROFILE_PATH)
	restored.configure(profile.debug_snapshot())
	var restored_bridge := CapturingWorldBridge.new()
	restored_bridge.facts = fixture.bridge.facts.duplicate(true)
	restored.set_world_bridge(restored_bridge)
	var applied: Dictionary = restored.apply_save_data(save_data)
	_expect(bool(applied.get("applied", false)), "CommodityFlow restores pending card batch and terminal transaction journal")
	var restored_sink = SINK_SCRIPT.new()
	restored_sink.configure(restored)
	var replay: Dictionary = restored_sink.commit_batch(prepared)
	_expect(bool(replay.get("committed", false)) and bool(replay.get("duplicate", false)), "save/load replay is recognized without generating a second supply claim")
	_expect(int(restored.debug_snapshot().get("pending_one_shot_count", -1)) == 1 and int(restored.debug_snapshot().get("card_effect_batch_transaction_count", -1)) == 1, "restored exact-once state has one batch and one physical supply")
	fixture.bridge.free()
	original.free()
	restored_bridge.free()
	restored.free()


func _verify_invalid_child_is_zero_effect() -> void:
	var fixture := _fixture(true, "sea", 3)
	var invalid := _plan("tx-invalid-child", "extra_demand", 2, fixture.snapshot as Dictionary)
	(invalid.allocations[0] as Dictionary)["market_facility_id"] = "missing-market"
	var before: Dictionary = fixture.flow.to_save_data()
	var prepared: Dictionary = fixture.sink.prepare_batch(invalid)
	_expect(not bool(prepared.get("prepared", true)) and str(prepared.get("reason_code", "")) == "batch_child_candidate_binding_changed", "one invalid child is rejected by the authoritative candidate binding gate during prepare")
	var after: Dictionary = fixture.flow.to_save_data()
	_expect(before == after, "failed child prepare changes no goods, demand, receipt, revision or journal state")
	fixture.bridge.free()
	fixture.flow.free()


func _verify_shared_capacity_is_aggregated() -> void:
	var fixture := _fixture(true, "sea", 3)
	var facts: Dictionary = (fixture.bridge as CapturingWorldBridge).facts.duplicate(true)
	var facilities: Array = facts.get("facilities", []) as Array
	facilities.append({
		"facility_id": "market-b",
		"facility_type": "market",
		"industry_id": _industry_id,
		"region_id": "region-market",
		"owner_player_index": 6,
		"rank": 4,
		"active": true,
	})
	facts["facilities"] = facilities
	(fixture.bridge as CapturingWorldBridge).facts = facts
	var snapshot: Dictionary = fixture.flow.card_effect_candidates_snapshot()
	var market_candidates: Array[Dictionary] = []
	var market_ids: Dictionary = {}
	for candidate_variant in snapshot.get("candidates", []) as Array:
		if not (candidate_variant is Dictionary):
			continue
		var candidate: Dictionary = candidate_variant
		var facility: Dictionary = candidate.get("facility", {}) if candidate.get("facility", {}) is Dictionary else {}
		var facility_id := str(facility.get("facility_id", ""))
		if str(facility.get("facility_type", "")) == "market" and not market_ids.has(facility_id):
			market_ids[facility_id] = true
			market_candidates.append(candidate.duplicate(true))
	_expect(bool(snapshot.get("valid", false)) and market_candidates.size() >= 2, "shared-capacity fixture obtains two distinct real market candidates")
	if market_candidates.size() < 2:
		fixture.bridge.free()
		fixture.flow.free()
		return
	var first_units := int(market_candidates[0].get("available_capacity_units", 0))
	var second_units := int(market_candidates[1].get("available_capacity_units", 0))
	var allocated_units := mini(first_units, second_units)
	var plan := {
		"ready": true,
		"transaction_id": "tx-shared-capacity",
		"intent_hash": "intent-tx-shared-capacity",
		"plan_hash": "plan-tx-shared-capacity",
		"candidate_snapshot_revision": int(snapshot.get("revision", -1)),
		"candidate_snapshot_fingerprint": str(snapshot.get("fingerprint", "")),
		"one_time_effect_kind": "extra_demand",
		"allocations": [
			_allocation_from_candidate(market_candidates[0], "extra_demand", allocated_units),
			_allocation_from_candidate(market_candidates[1], "extra_demand", allocated_units),
		],
	}
	var before: Dictionary = fixture.flow.to_save_data()
	var prepared: Dictionary = fixture.sink.prepare_batch(plan)
	_expect(allocated_units > 0 and not bool(prepared.get("prepared", true)) and str(prepared.get("reason_code", "")) == "batch_shared_capacity_exceeded", "individually legal real candidates cannot exceed their shared aggregate capacity")
	_expect(before == fixture.flow.to_save_data(), "aggregate capacity rejection has zero goods, journal, receipt or revision side effects")
	fixture.bridge.free()
	fixture.flow.free()


func _fixture(with_continuous_demand: bool, route_mode: String, distance: int) -> Dictionary:
	var profile := load(PROFILE_PATH)
	var flow = FLOW_SCRIPT.new()
	flow.configure(profile.debug_snapshot())
	var bridge := CapturingWorldBridge.new()
	bridge.facts = _facts(route_mode, distance)
	flow.set_world_bridge(bridge)
	var factory: Dictionary = bridge.facts.facilities[0]
	var production: Dictionary = flow.install_commodity({
		"transaction_id": "install-production-%s-%d" % [route_mode, distance],
		"facility": factory,
		"facility_id": "factory-a",
		"region_id": "region-source",
		"commodity_id": _product_id,
		"direction": "production",
		"installer_player_index": 0,
		"source_card_rank": 4,
		"color": _industry_id,
		"region_revision": 1,
	})
	_expect(bool(production.get("committed", false)), "fixture installs a real production commodity on the source factory")
	if with_continuous_demand:
		var market: Dictionary = bridge.facts.facilities[1]
		var demand: Dictionary = flow.install_commodity({
			"transaction_id": "install-demand-%s-%d" % [route_mode, distance],
			"facility": market,
			"facility_id": "market-a",
			"region_id": "region-market",
			"commodity_id": _product_id,
			"direction": "demand",
			"installer_player_index": 1,
			# Keep a small permanent demand to seed real GDP lineage while leaving
			# production headroom for the one-shot order exercised below.
			"source_card_rank": 1,
			"color": _industry_id,
			"region_revision": 1,
		})
		_expect(bool(demand.get("committed", false)), "fixture installs a real market demand when the supply settlement needs one")
	var sink = SINK_SCRIPT.new()
	_expect(bool(sink.configure(flow).get("configured", false)), "production sink binds only to the authoritative CommodityFlow batch API")
	var seeded: Dictionary = flow.advance_world(60.0)
	_expect(bool(seeded.get("advanced", false)) and int(seeded.get("receipt_count", 0)) > 0, "fixture seeds authoritative GDP lineage through a normal real sale")
	var snapshot: Dictionary = flow.card_effect_candidates_snapshot()
	_expect(bool(snapshot.get("valid", false)) and int(snapshot.get("revision", -1)) >= 0 and not str(snapshot.get("fingerprint", "")).is_empty(), "fixture obtains a revisioned authoritative card candidate snapshot")
	return {"flow": flow, "bridge": bridge, "sink": sink, "snapshot": snapshot}


func _facts(route_mode: String, distance: int) -> Dictionary:
	return {
		"game_time": 100.0,
		"regions": [
			{"region_id": "region-source", "revision": 1, "lifecycle_state": "active", "integrity_basis_points": 10000},
			{"region_id": "region-market", "revision": 1, "lifecycle_state": "active", "integrity_basis_points": 10000},
		],
		"facilities": [
			{"facility_id": "factory-a", "facility_type": "factory", "industry_id": _industry_id, "region_id": "region-source", "owner_player_index": 4, "rank": 4, "active": true},
			{"facility_id": "market-a", "facility_type": "market", "industry_id": _industry_id, "region_id": "region-market", "owner_player_index": 5, "rank": 4, "active": true},
		],
		"destroyed_facility_ids": [],
		"price_cents_by_commodity": {_product_id: 1000},
		"route_candidates": [{
			"route_id": "route-main",
			"commodity_id": "*",
			"source_region_id": "region-source",
			"market_region_id": "region-market",
			"mode_tags": [route_mode],
			"shortest_legal_distance": distance,
			"bottleneck_units_per_minute": 1000,
			"capacity_resources": [{"resource_id": "capacity-main", "capacity_units_per_minute": 1000}],
			"expected_rents": [],
			"arrival_seconds": 1.0,
			"transfer_count": 0,
			"region_revision_fingerprint": "topology-1",
		}],
	}


func _plan(transaction_id: String, effect_kind: String, allocated_units: int, snapshot: Dictionary) -> Dictionary:
	var facility_type := "market" if effect_kind == "extra_demand" else "factory"
	var candidate: Dictionary = {}
	for candidate_variant in snapshot.get("candidates", []) as Array:
		if not (candidate_variant is Dictionary):
			continue
		var facility: Dictionary = (candidate_variant as Dictionary).get("facility", {}) if (candidate_variant as Dictionary).get("facility", {}) is Dictionary else {}
		if str(facility.get("facility_type", "")) == facility_type:
			candidate = (candidate_variant as Dictionary).duplicate(true)
			break
	return {
		"ready": true,
		"transaction_id": transaction_id,
		"intent_hash": "intent-%s" % transaction_id,
		"plan_hash": "plan-%s" % transaction_id,
		"candidate_snapshot_revision": int(snapshot.get("revision", -1)),
		"candidate_snapshot_fingerprint": str(snapshot.get("fingerprint", "")),
		"one_time_effect_kind": effect_kind,
		"allocations": [_allocation_from_candidate(candidate, effect_kind, allocated_units)],
	}


func _allocation_from_candidate(candidate: Dictionary, effect_kind: String, allocated_units: int) -> Dictionary:
	var facility_type := "market" if effect_kind == "extra_demand" else "factory"
	var facility: Dictionary = candidate.get("facility", {}) if candidate.get("facility", {}) is Dictionary else {}
	var region: Dictionary = candidate.get("region", {}) if candidate.get("region", {}) is Dictionary else {}
	var product: Dictionary = candidate.get("product", {}) if candidate.get("product", {}) is Dictionary else {}
	var route: Dictionary = candidate.get("route", {}) if candidate.get("route", {}) is Dictionary else {}
	var capacity_resource_ids: Array[String] = []
	for resource_variant in route.get("capacity_resources", []) as Array:
		if resource_variant is Dictionary:
			capacity_resource_ids.append(str((resource_variant as Dictionary).get("resource_id", "")))
	return {
		"candidate_id": str(candidate.get("candidate_id", "")),
		"goods_key": "%08d|%s" % [int(candidate.get("commodity_owner_player_index", -1)), str(product.get("product_id", ""))],
		"product_id": str(product.get("product_id", "")),
		"industry_id": str(product.get("industry_id", "")),
		"commodity_owner_player_index": int(candidate.get("commodity_owner_player_index", -1)),
		"matching_product_gdp_30s": int(candidate.get("matching_product_gdp_30s", -1)),
		"beneficiary_player_index": int(candidate.get("commodity_owner_player_index", -1)),
		"facility_owner_player_index": int(facility.get("owner_player_index", -1)),
		"facility_owner_reward_units": 0,
		"permanent_rate_delta": 0,
		"facility_id": str(facility.get("facility_id", "")),
		"facility_type": facility_type,
		"source_facility_id": str(route.get("source_facility_id", "")),
		"market_facility_id": str(route.get("market_facility_id", "")),
		"region_id": str(region.get("region_id", "")),
		"region_revision": int(region.get("revision", -1)),
		"route_id": str(route.get("route_id", "")),
		"topology_revision": str(route.get("topology_revision", "")),
		"route_mode_tags": (route.get("mode_tags", []) as Array).duplicate(true),
		"shortest_legal_distance": int(route.get("shortest_legal_distance", -1)),
		"capacity_resource_ids": capacity_resource_ids,
		"allocated_units": allocated_units,
		"one_time_effect_kind": effect_kind,
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("COMMODITY_FLOW_ATOMIC_BATCH_SINK_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("COMMODITY_FLOW_ATOMIC_BATCH_SINK_V06_TEST|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	quit(1)
