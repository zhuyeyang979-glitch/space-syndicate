extends Node

const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const OWNER_SCRIPT := preload("res://scripts/cards/v06/effects/global_supply_demand_runtime_service_v06.gd")
const ADAPTER_SCRIPT := preload("res://scripts/cards/v06/effects/global_supply_demand_card_effect_adapter_v06.gd")
const TRANSACTION_SERVICE_SCRIPT := preload("res://scripts/cards/v06/card_flow_transaction_service_v06.gd")

var _checks := 0
var _failures: Array[String] = []


class AtomicBenchSink:
	extends RefCounted
	var batches: Dictionary = {}

	func prepare_batch(plan: Dictionary) -> Dictionary:
		return {"prepared": true, "transaction_id": plan.get("transaction_id", ""), "intent_hash": plan.get("intent_hash", ""), "plan_hash": plan.get("plan_hash", ""), "plan": plan.duplicate(true)}

	func commit_batch(prepared: Dictionary) -> Dictionary:
		var transaction_id := str(prepared.get("transaction_id", ""))
		var receipt := {"committed": true, "transaction_id": transaction_id, "intent_hash": prepared.get("intent_hash", ""), "plan_hash": prepared.get("plan_hash", ""), "effects": ((prepared.get("plan", {}) as Dictionary).get("allocations", []) as Array).duplicate(true)}
		batches[transaction_id] = receipt.duplicate(true)
		return receipt

	func rollback_batch(receipt: Dictionary) -> Dictionary:
		var transaction_id := str(receipt.get("transaction_id", ""))
		return {"rolled_back": batches.erase(transaction_id), "transaction_id": transaction_id}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	_check(catalog != null and bool(catalog.reload().get("valid", false)), "catalog")
	if catalog == null:
		_finish()
		return
	var planner = OWNER_SCRIPT.new()
	var sink := AtomicBenchSink.new()
	_check(bool(planner.set_batch_sink(sink).get("configured", false)), "sink_contract")
	var candidates := [
		_candidate("order", "market", "星露莓", "life", ["land", "sea"], 3),
		_candidate("supply", "factory", "环晶电池", "energy", ["land"], 2),
	]
	_check(bool(planner.replace_authoritative_candidates(1, candidates).get("configured", false)), "candidate_snapshot")
	var adapter = ADAPTER_SCRIPT.new()
	_check(bool(adapter.configure(planner, {"bench-actor": 0}).get("configured", false)), "adapter")
	var order := _play(catalog, adapter, "supply_demand.remote_sea_order.rank_1", "global_matching_goods", 1, "bench-order")
	_check(bool(order.get("committed", false)), "order_play")
	var order_owner: Dictionary = ((order.get("effect_receipt", {}) as Dictionary).get("owner_receipt", {}) as Dictionary)
	_check(str(order_owner.get("one_time_effect_kind", "")) == "extra_demand" and int(order_owner.get("allocated_units", 0)) == 20, "order_batch")
	var supply := _play(catalog, adapter, "supply_demand.near_land_supply.rank_1", "global_matching_factories", 1, "bench-supply")
	_check(bool(supply.get("committed", false)), "supply_play")
	var supply_owner: Dictionary = ((supply.get("effect_receipt", {}) as Dictionary).get("owner_receipt", {}) as Dictionary)
	_check(str(supply_owner.get("one_time_effect_kind", "")) == "physical_supply" and int(supply_owner.get("allocated_units", 0)) == 20, "supply_batch")
	_check(sink.batches.size() == 2, "atomic_sink_two_batches")
	_check(int(planner.debug_snapshot().get("permanent_rate_mutation_count", -1)) == 0, "no_permanent_rate_mutation")
	_finish()


func _play(catalog: CardRuntimeCatalogV06Resource, adapter: Object, card_id: String, target_kind: String, snapshot_revision: int, transaction_id: String) -> Dictionary:
	var service = TRANSACTION_SERVICE_SCRIPT.new(catalog)
	var assets := {"life": 10, "energy": 10, "industry": 10, "technology": 10, "commerce": 10, "shipping": 10}
	service.register_player("bench-actor", {"revision": 0, "cash": 20, "assets": assets, "inventory": {"hand_limit": 5, "slots": [catalog.card_snapshot(card_id)]}})
	return service.play_card("bench-actor", 0, {"valid": true, "target_kind": target_kind, "candidate_snapshot_revision": snapshot_revision}, adapter, 0, transaction_id)


func _candidate(candidate_id: String, facility_type: String, product_id: String, industry_id: String, modes: Array, distance: int) -> Dictionary:
	var facility_id := "facility-%s" % candidate_id
	var region_id := "region-%s" % candidate_id
	return {
		"candidate_id": candidate_id,
		"facility": {"facility_id": facility_id, "facility_type": facility_type, "industry_id": industry_id, "region_id": region_id, "owner_player_index": 9, "active": true},
		"region": {"region_id": region_id, "revision": 1, "lifecycle_state": "active"},
		"product": {"product_id": product_id, "industry_id": industry_id},
		"commodity_owner_player_index": 0,
		"matching_product_gdp_30s": 100,
		"available_capacity_units": 100,
		"route": {
			"route_id": "route-%s" % candidate_id,
			"source_facility_id": facility_id if facility_type == "factory" else "source-%s" % candidate_id,
			"market_facility_id": facility_id if facility_type == "market" else "market-%s" % candidate_id,
			"mode_tags": modes,
			"shortest_legal_distance": distance,
			"topology_revision": "bench-topology-1",
			"capacity_resources": [{"resource_id": "capacity-%s" % candidate_id, "available_units": 100}],
			"expected_owner_net_cash": 100,
			"arrival_milliseconds": 1000,
			"transfer_count": maxi(0, modes.size() - 1),
		},
	}


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("CARD_GLOBAL_SUPPLY_DEMAND_V06_BENCH|status=PASS|checks=%d|failures=0|production_batch_sink=BLOCKED" % _checks)
		return
	print("CARD_GLOBAL_SUPPLY_DEMAND_V06_BENCH|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
