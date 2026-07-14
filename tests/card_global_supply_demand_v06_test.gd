extends SceneTree

const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const OWNER_SCRIPT := preload("res://scripts/cards/v06/effects/global_supply_demand_runtime_service_v06.gd")
const ADAPTER_SCRIPT := preload("res://scripts/cards/v06/effects/global_supply_demand_card_effect_adapter_v06.gd")
const TRANSACTION_SERVICE_SCRIPT := preload("res://scripts/cards/v06/card_flow_transaction_service_v06.gd")
const BUDGETS := [20, 40, 80, 160]
const ORDER_FAMILY := "supply_demand.remote_sea_order"
const SUPPLY_FAMILY := "supply_demand.near_land_supply"

var _checks := 0
var _failures: Array[String] = []


class FakeAtomicBatchSink:
	extends RefCounted

	var fail_candidate_id := ""
	var fail_commit := false
	var prepare_calls := 0
	var commit_calls := 0
	var rollback_calls := 0
	var active_batches: Dictionary = {}

	func prepare_batch(plan: Dictionary) -> Dictionary:
		prepare_calls += 1
		var base := _binding(plan)
		for allocation_variant in plan.get("allocations", []):
			var allocation: Dictionary = allocation_variant
			if str(allocation.get("candidate_id", "")) == fail_candidate_id and int(allocation.get("allocated_units", 0)) > 0:
				base["prepared"] = false
				base["reason_code"] = "sink_child_prepare_failed"
				return base
		base["prepared"] = true
		base["reason_code"] = "prepared"
		base["batch_request"] = plan.duplicate(true)
		return base

	func commit_batch(prepared: Dictionary) -> Dictionary:
		commit_calls += 1
		var base := _binding(prepared)
		if fail_commit:
			base["committed"] = false
			base["reason_code"] = "sink_commit_failed"
			return base
		var transaction_id := str(prepared.get("transaction_id", ""))
		if active_batches.has(transaction_id):
			var replay: Dictionary = active_batches[transaction_id]
			replay = replay.duplicate(true)
			replay["duplicate"] = true
			return replay
		var request: Dictionary = prepared.get("batch_request", {}) as Dictionary
		base["committed"] = true
		base["duplicate"] = false
		base["reason_code"] = "committed"
		base["effects"] = (request.get("allocations", []) as Array).duplicate(true)
		active_batches[transaction_id] = base.duplicate(true)
		return base

	func rollback_batch(receipt: Dictionary) -> Dictionary:
		rollback_calls += 1
		var transaction_id := str(receipt.get("transaction_id", ""))
		var existed := active_batches.erase(transaction_id)
		return {"rolled_back": existed, "committed": false, "transaction_id": transaction_id, "reason_code": "rolled_back" if existed else "batch_missing"}

	func _binding(source: Dictionary) -> Dictionary:
		return {
			"transaction_id": str(source.get("transaction_id", "")),
			"intent_hash": str(source.get("intent_hash", "")),
			"plan_hash": str(source.get("plan_hash", "")),
		}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	_expect(catalog != null and bool(catalog.reload().get("valid", false)), "v0.6 catalog is ready")
	if catalog == null:
		_finish()
		return
	_verify_all_eight_ranked_cards(catalog)
	_verify_order_multimodal_distance_rounding_and_replay(catalog)
	_verify_supply_multimodal_and_distance_boundary(catalog)
	_verify_capacity_truncation(catalog)
	_verify_zero_actor_gdp_rejects_without_consumption(catalog)
	_verify_candidate_snapshot_rejects_nested_runtime_objects()
	_verify_sink_child_failure_is_atomic(catalog)
	_verify_missing_sink_fails_closed(catalog)
	_finish()


func _verify_all_eight_ranked_cards(catalog: CardRuntimeCatalogV06Resource) -> void:
	for family_id in [ORDER_FAMILY, SUPPLY_FAMILY]:
		for rank_index in range(4):
			var resolved_family_id := str(family_id)
			var rank := rank_index + 1
			var card_id := "%s.rank_%d" % [resolved_family_id, rank]
			var card := catalog.card_snapshot(card_id)
			var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
			var player_text: Dictionary = card.get("player", {}) if card.get("player", {}) is Dictionary else {}
			var effect_kind := str(machine.get("effect_kind", ""))
			var is_order: bool = resolved_family_id == ORDER_FAMILY
			var expected_budget := int(BUDGETS[rank_index])
			var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
			_expect(not card.is_empty(), "%s exists" % card_id)
			_expect(int(payload.get("budget_units" if is_order else "spawn_units", 0)) == expected_budget, "%s preserves the 20/40/80/160 ladder" % card_id)
			var player_json := JSON.stringify(player_text).to_lower()
			_expect(player_json.contains("资产") and not player_json.contains("法力") and not player_json.contains("mana"), "%s uses player-facing asset terminology" % card_id)

			var owner = OWNER_SCRIPT.new()
			var sink := FakeAtomicBatchSink.new()
			owner.set_batch_sink(sink)
			var candidate := _candidate(
				"rank-candidate-%d-%s" % [rank, "order" if is_order else "supply"],
				"market" if is_order else "factory",
				"星露莓",
				"life",
				0,
				100,
				["sea"] if is_order else ["land"],
				3 if is_order else 2,
				1000,
				9
			)
			var snapshot_revision := 100 + rank + (0 if is_order else 10)
			_expect(bool(owner.replace_authoritative_candidates(snapshot_revision, [candidate]).get("configured", false)), "%s receives an authoritative candidate snapshot" % card_id)
			var adapter = ADAPTER_SCRIPT.new()
			adapter.configure(owner, {"actor-a": 0})
			var service = TRANSACTION_SERVICE_SCRIPT.new(catalog)
			var assets := _assets(20)
			service.register_player("actor-a", _state([card], assets))
			var target := {
				"valid": true,
				"target_kind": str(machine.get("target_kind", "")),
				"candidate_snapshot_revision": snapshot_revision,
				"player_index": 777,
			}
			var result: Dictionary = service.play_card("actor-a", 0, target, adapter, 0, "tx-rank-%s-%d" % ["order" if is_order else "supply", rank])
			_expect(bool(result.get("committed", false)), "%s commits through the two-phase card transaction" % card_id)
			var state: Dictionary = result.get("player_state", {}) if result.get("player_state", {}) is Dictionary else {}
			_expect(_card_count(state) == 0, "%s is consumed after the one-time batch commits" % card_id)
			var asset_key := "shipping" if is_order else "industry"
			var asset_cost: Dictionary = machine.get("asset_cost", {}) if machine.get("asset_cost", {}) is Dictionary else {}
			var after_assets: Dictionary = state.get("assets", {}) if state.get("assets", {}) is Dictionary else {}
			_expect(int(after_assets.get(asset_key, -1)) == 20 - int(asset_cost.get(asset_key, 0)), "%s spends the correct colored assets" % card_id)
			var effect_receipt: Dictionary = result.get("effect_receipt", {}) if result.get("effect_receipt", {}) is Dictionary else {}
			var owner_receipt: Dictionary = effect_receipt.get("owner_receipt", {}) if effect_receipt.get("owner_receipt", {}) is Dictionary else {}
			_expect(int(owner_receipt.get("budget_units", 0)) == expected_budget and int(owner_receipt.get("allocated_units", 0)) == expected_budget, "%s resolves its full one-time budget with ample capacity" % card_id)
			_expect(bool(owner_receipt.get("does_not_change_permanent_rates", false)), "%s does not alter permanent production or demand rates" % card_id)
			_expect(str(owner_receipt.get("one_time_effect_kind", "")) == ("extra_demand" if is_order else "physical_supply"), "%s writes the correct one-time effect kind" % card_id)
			_expect(int(owner_receipt.get("actor_player_index", -1)) == 0, "%s uses the adapter actor mapping instead of target player fields" % card_id)
			if is_order and rank == 1:
				var rollback: Dictionary = adapter.rollback_effect(effect_receipt)
				_expect(bool(rollback.get("rolled_back", false)) and sink.active_batches.is_empty(), "adapter rollback compensates the atomic batch sink")


func _verify_order_multimodal_distance_rounding_and_replay(catalog: CardRuntimeCatalogV06Resource) -> void:
	var owner = OWNER_SCRIPT.new()
	var sink := FakeAtomicBatchSink.new()
	owner.set_batch_sink(sink)
	var candidates := [
		_candidate("a-multimodal", "market", "甲商品", "life", 0, 1, ["land", "sea"], 3, 100, 90, 4, 11),
		_candidate("a-second-route", "market", "甲商品", "life", 0, 1, ["sea"], 4, 100, 96, 4, 14),
		_candidate("b-sea", "market", "乙商品", "energy", 1, 2, ["sea"], 4, 100, 91, 4, 12),
		_candidate("c-sea", "market", "丙商品", "industry", 2, 3, ["sea"], 3, 100, 92, 4, 13),
		_candidate("d-distance-two", "market", "丁商品", "technology", 0, 100, ["sea"], 2, 100, 93),
		_candidate("e-land-only", "market", "戊商品", "commerce", 0, 100, ["land"], 5, 100, 94),
		_candidate("f-factory", "factory", "己商品", "shipping", 0, 100, ["sea"], 5, 100, 95),
	]
	_expect(bool(owner.replace_authoritative_candidates(21, candidates).get("configured", false)), "order fixture candidate snapshot configures")
	var card := catalog.card_snapshot("%s.rank_1" % ORDER_FAMILY)
	var payload: Dictionary = (card.get("machine", {}) as Dictionary).get("effect_payload", {}) as Dictionary
	var plan: Dictionary = owner.preview_batch(_direct_request("tx-order-rounding", "global_order_budget", payload, 21, 0))
	_expect(bool(plan.get("ready", false)), "order preview accepts a positive-GDP actor")
	_expect(int(plan.get("eligible_candidate_count", 0)) == 4, "order filters by market node, sea segment, and distance greater than two")
	var units := _allocated_units_by_candidate(plan)
	_expect(int(units.get("a-multimodal", -1)) + int(units.get("a-second-route", -1)) == 3 and int(units.get("b-sea", -1)) == 7 and int(units.get("c-sea", -1)) == 10, "largest remainder allocates 20 units by goods-level GDP weights 1:2:3 without counting a second route twice")
	_expect(not units.has("d-distance-two") and not units.has("e-land-only") and not units.has("f-factory"), "distance-two, missing-sea, and wrong-node candidates are excluded")
	var receipt: Dictionary = owner.commit_batch(plan)
	_expect(bool(receipt.get("committed", false)) and int(receipt.get("allocated_units", 0)) == 20, "order batch commits atomically")
	var allocations: Array = receipt.get("allocations", []) if receipt.get("allocations", []) is Array else []
	var multimodal: Dictionary = _allocation_by_candidate(allocations, "a-multimodal")
	_expect((multimodal.get("route_mode_tags", []) as Array).has("sea") and (multimodal.get("route_mode_tags", []) as Array).has("land"), "a multimodal route matches when any segment contains sea")
	_expect(str(multimodal.get("topology_revision", "")) == "11" and int(multimodal.get("region_revision", -1)) == 4, "allocation receipt binds route topology and region revisions")
	_expect(int(multimodal.get("beneficiary_player_index", -1)) == 0 and int(multimodal.get("facility_owner_player_index", -1)) == 90 and int(multimodal.get("facility_owner_reward_units", -1)) == 0, "commodity owner benefits while market owner receives no allocation reward")
	var replay: Dictionary = owner.commit_batch(plan)
	_expect(bool(replay.get("committed", false)) and bool(replay.get("duplicate", false)), "owner exact-once journal replays the same batch")
	_expect(owner.batch_receipts_snapshot().size() == 1, "owner replay does not append a second batch")
	var repreview: Dictionary = owner.preview_batch(_direct_request("tx-order-rounding", "global_order_budget", payload, 21, 0))
	var repreview_replay: Dictionary = owner.commit_batch(repreview)
	_expect(bool(repreview_replay.get("committed", false)) and bool(repreview_replay.get("duplicate", false)), "same transaction and intent replays the original result even if a fresh preview has another plan hash")
	var collision_plan := plan.duplicate(true)
	collision_plan["intent_hash"] = "different-intent"
	var collision: Dictionary = owner.commit_batch(collision_plan)
	_expect(not bool(collision.get("committed", true)) and str(collision.get("reason_code", "")) == "transaction_intent_collision", "same transaction id with another intent is rejected")
	_expect(int(owner.debug_snapshot().get("permanent_rate_mutation_count", -1)) == 0, "order owner never mutates permanent rates")


func _verify_supply_multimodal_and_distance_boundary(catalog: CardRuntimeCatalogV06Resource) -> void:
	var owner = OWNER_SCRIPT.new()
	var sink := FakeAtomicBatchSink.new()
	owner.set_batch_sink(sink)
	var shortest_distance_candidate := _candidate("supply-multimodal-distance-two", "factory", "甲商品", "life", 0, 5, ["sea", "land"], 5, 100, 80)
	(shortest_distance_candidate["route"] as Dictionary)["shortest_legal_distance"] = 2
	(shortest_distance_candidate["route"] as Dictionary)["topology_revision"] = "topology-supply-2"
	var candidates := [
		shortest_distance_candidate,
		_candidate("supply-distance-three", "factory", "乙商品", "energy", 0, 50, ["land"], 3, 100, 81),
		_candidate("supply-sea-only", "factory", "丙商品", "industry", 0, 50, ["sea"], 1, 100, 82),
	]
	owner.replace_authoritative_candidates(31, candidates)
	var card := catalog.card_snapshot("%s.rank_1" % SUPPLY_FAMILY)
	var payload: Dictionary = (card.get("machine", {}) as Dictionary).get("effect_payload", {}) as Dictionary
	var plan: Dictionary = owner.preview_batch(_direct_request("tx-supply-boundary", "global_supply_spawn", payload, 31, 0))
	_expect(bool(plan.get("ready", false)), "supply preview accepts the exact near-distance boundary from shortest legal distance")
	_expect(int(plan.get("eligible_candidate_count", 0)) == 1, "supply requires factory, a land segment, and distance at most two")
	var units := _allocated_units_by_candidate(plan)
	_expect(int(units.get("supply-multimodal-distance-two", -1)) == 20, "multimodal land segment with shortest distance two receives the full supply budget even when actual path length is five")
	_expect(not units.has("supply-distance-three") and not units.has("supply-sea-only"), "distance three and sea-only routes are excluded from near-land supply")
	var receipt: Dictionary = owner.commit_batch(plan)
	_expect(str(receipt.get("one_time_effect_kind", "")) == "physical_supply" and int(receipt.get("permanent_production_rate_delta", -1)) == 0, "supply creates physical one-time goods without a permanent installation")


func _verify_capacity_truncation(catalog: CardRuntimeCatalogV06Resource) -> void:
	var owner = OWNER_SCRIPT.new()
	var sink := FakeAtomicBatchSink.new()
	owner.set_batch_sink(sink)
	owner.replace_authoritative_candidates(41, [
		_candidate("capacity-heavy", "market", "甲商品", "life", 0, 10, ["sea"], 3, 5, 70),
		_candidate("capacity-light", "market", "乙商品", "energy", 1, 1, ["sea"], 3, 100, 71),
	])
	var card := catalog.card_snapshot("%s.rank_1" % ORDER_FAMILY)
	var payload: Dictionary = (card.get("machine", {}) as Dictionary).get("effect_payload", {}) as Dictionary
	var plan: Dictionary = owner.preview_batch(_direct_request("tx-capacity", "global_order_budget", payload, 41, 0))
	var units := _allocated_units_by_candidate(plan)
	_expect(int(units.get("capacity-heavy", -1)) == 5 and int(units.get("capacity-light", -1)) == 15, "capacity-truncated GDP share is redistributed to the remaining legal goods group")
	_expect(int(plan.get("allocated_units", -1)) == 20 and int(plan.get("unallocated_units", -1)) == 0, "redistribution exhausts the printed budget when other real capacity remains")
	var receipt: Dictionary = owner.commit_batch(plan)
	_expect(int(receipt.get("allocated_units", -1)) + int(receipt.get("unallocated_units", -1)) == 20, "committed capacity receipt conserves the card budget")
	var exhausted_owner = OWNER_SCRIPT.new()
	var exhausted_sink := FakeAtomicBatchSink.new()
	exhausted_owner.set_batch_sink(exhausted_sink)
	exhausted_owner.replace_authoritative_candidates(42, [
		_candidate("exhausted-a", "market", "甲商品", "life", 0, 10, ["sea"], 3, 5, 70),
		_candidate("exhausted-b", "market", "乙商品", "energy", 1, 1, ["sea"], 3, 6, 71),
	])
	var exhausted_plan: Dictionary = exhausted_owner.preview_batch(_direct_request("tx-capacity-exhausted", "global_order_budget", payload, 42, 0))
	_expect(int(exhausted_plan.get("allocated_units", -1)) == 11 and int(exhausted_plan.get("unallocated_units", -1)) == 9, "only aggregate real-capacity exhaustion produces explicit unallocated units")

	var shared_owner = OWNER_SCRIPT.new()
	var shared_sink := FakeAtomicBatchSink.new()
	shared_owner.set_batch_sink(shared_sink)
	var shared_a := _candidate("shared-a", "market", "甲商品", "life", 0, 1, ["sea"], 3, 100, 70)
	var shared_b := _candidate("shared-b", "market", "乙商品", "energy", 1, 1, ["sea"], 3, 100, 71)
	(shared_a["route"] as Dictionary)["capacity_resources"] = [{"resource_id": "shared-port", "available_units": 10}]
	(shared_b["route"] as Dictionary)["capacity_resources"] = [{"resource_id": "shared-port", "available_units": 10}]
	shared_owner.replace_authoritative_candidates(43, [shared_b, shared_a])
	var shared_plan: Dictionary = shared_owner.preview_batch(_direct_request("tx-shared-capacity", "global_order_budget", payload, 43, 0))
	_expect(int(shared_plan.get("allocated_units", -1)) == 10 and int(shared_plan.get("unallocated_units", -1)) == 10, "two goods groups cannot oversell one shared port capacity resource")


func _verify_zero_actor_gdp_rejects_without_consumption(catalog: CardRuntimeCatalogV06Resource) -> void:
	var owner = OWNER_SCRIPT.new()
	owner.replace_authoritative_candidates(51, [
		_candidate("actor-zero-gdp", "market", "甲商品", "life", 0, 0, ["sea"], 3, 100, 60),
		_candidate("other-positive-gdp", "market", "乙商品", "energy", 1, 100, ["sea"], 3, 100, 61),
	])
	var adapter = ADAPTER_SCRIPT.new()
	adapter.configure(owner, {"actor-a": 0})
	var card := catalog.card_snapshot("%s.rank_1" % ORDER_FAMILY)
	var service = TRANSACTION_SERVICE_SCRIPT.new(catalog)
	service.register_player("actor-a", _state([card], _assets(10)))
	var before := service.player_snapshot("actor-a")
	var result: Dictionary = service.play_card("actor-a", 0, {
		"valid": true,
		"target_kind": "global_matching_goods",
		"candidate_snapshot_revision": 51,
	}, adapter, 0, "tx-zero-gdp")
	_expect(not bool(result.get("committed", true)) and str(result.get("reason_code", "")) == "effect_prepare_failed", "actor with no positive matching product GDP cannot play the order")
	_expect(_same_player_resources(before, service.player_snapshot("actor-a")), "zero-GDP rejection consumes neither card nor shipping assets")
	_expect(owner.batch_receipts_snapshot().is_empty(), "zero-GDP rejection writes no one-time batch")


func _verify_candidate_snapshot_rejects_nested_runtime_objects() -> void:
	var owner = OWNER_SCRIPT.new()
	var candidate := _candidate("nested-object", "market", "甲商品", "life", 0, 1, ["sea"], 3, 20, 4)
	var nested_object := Node.new()
	(candidate["route"] as Dictionary)["debug_values"] = ["safe", nested_object]
	var result: Dictionary = owner.replace_authoritative_candidates(61, [candidate])
	_expect(not bool(result.get("configured", true)) and str(result.get("reason_code", "")) == "candidate_not_pure_data", "candidate validation rejects a runtime Object hidden after a valid nested value")
	nested_object.free()


func _verify_sink_child_failure_is_atomic(catalog: CardRuntimeCatalogV06Resource) -> void:
	var owner = OWNER_SCRIPT.new()
	var sink := FakeAtomicBatchSink.new()
	sink.fail_candidate_id = "sink-fail-b"
	owner.set_batch_sink(sink)
	owner.replace_authoritative_candidates(71, [
		_candidate("sink-ok-a", "market", "甲商品", "life", 0, 1, ["sea"], 3, 100, 4),
		_candidate("sink-fail-b", "market", "乙商品", "energy", 1, 1, ["sea"], 3, 100, 5),
	])
	var card := catalog.card_snapshot("%s.rank_1" % ORDER_FAMILY)
	var payload: Dictionary = (card.get("machine", {}) as Dictionary).get("effect_payload", {}) as Dictionary
	var plan: Dictionary = owner.preview_batch(_direct_request("tx-sink-child-fail", "global_order_budget", payload, 71, 0))
	var receipt: Dictionary = owner.commit_batch(plan)
	_expect(not bool(receipt.get("committed", true)) and str(receipt.get("reason_code", "")) == "sink_child_prepare_failed", "one rejected child makes the whole sink batch fail")
	_expect(sink.active_batches.is_empty() and sink.commit_calls == 0, "child prepare failure produces zero sink side effects")


func _verify_missing_sink_fails_closed(catalog: CardRuntimeCatalogV06Resource) -> void:
	var owner = OWNER_SCRIPT.new()
	owner.replace_authoritative_candidates(81, [_candidate("missing-sink", "market", "甲商品", "life", 0, 1, ["sea"], 3, 100, 4)])
	var adapter = ADAPTER_SCRIPT.new()
	adapter.configure(owner, {"actor-a": 0})
	var card := catalog.card_snapshot("%s.rank_1" % ORDER_FAMILY)
	var service = TRANSACTION_SERVICE_SCRIPT.new(catalog)
	service.register_player("actor-a", _state([card], _assets(10)))
	var before := service.player_snapshot("actor-a")
	var result: Dictionary = service.play_card("actor-a", 0, {"valid": true, "target_kind": "global_matching_goods", "candidate_snapshot_revision": 81}, adapter, 0, "tx-missing-sink")
	_expect(not bool(result.get("committed", true)) and str(result.get("reason_code", "")) == "effect_commit_failed", "missing production batch sink fails closed")
	_expect(_same_player_resources(before, service.player_snapshot("actor-a")), "missing sink restores the card and shipping assets")


func _candidate(
	candidate_id: String,
	facility_type: String,
	product_id: String,
	industry_id: String,
	commodity_owner: int,
	gdp_30s: int,
	mode_tags: Array,
	distance: int,
	capacity: int,
	facility_owner: int,
	region_revision := 1,
	route_revision := 1
) -> Dictionary:
	var region_id := "region-%s" % candidate_id
	var facility_id := "facility-%s" % candidate_id
	var source_facility_id := facility_id if facility_type == "factory" else "source-%s" % candidate_id
	var market_facility_id := facility_id if facility_type == "market" else "market-%s" % candidate_id
	return {
		"candidate_id": candidate_id,
		"facility": {
			"facility_id": facility_id,
			"facility_type": facility_type,
			"industry_id": industry_id,
			"region_id": region_id,
			"owner_player_index": facility_owner,
			"active": true,
		},
		"region": {"region_id": region_id, "revision": region_revision, "lifecycle_state": "active"},
		"product": {"product_id": product_id, "industry_id": industry_id},
		"commodity_owner_player_index": commodity_owner,
		"matching_product_gdp_30s": gdp_30s,
		"route": {
			"route_id": "route-%s" % candidate_id,
			"source_facility_id": source_facility_id,
			"market_facility_id": market_facility_id,
			"mode_tags": mode_tags.duplicate(),
			"shortest_legal_distance": distance,
			"topology_revision": str(route_revision),
			"capacity_resources": [{"resource_id": "capacity-%s" % candidate_id, "available_units": capacity}],
			"expected_owner_net_cash": 100,
			"arrival_milliseconds": 1000,
			"transfer_count": maxi(0, mode_tags.size() - 1),
		},
		"available_capacity_units": capacity,
	}


func _direct_request(transaction_id: String, effect_kind: String, payload: Dictionary, snapshot_revision: int, actor_player_index: int) -> Dictionary:
	var binding := {
		"transaction_id": transaction_id,
		"actor_id": "actor-%d" % actor_player_index,
		"card_id": "test.%s" % effect_kind,
		"card_instance_id": "instance-%s" % transaction_id,
		"effect_kind": effect_kind,
		"target_hash": "target-%s" % transaction_id,
		"payload_hash": "payload-%s" % transaction_id,
		"intent_hash": "intent-%s" % transaction_id,
	}
	var request := binding.duplicate(true)
	request["binding"] = binding
	request["actor_player_index"] = actor_player_index
	request["effect_payload"] = payload.duplicate(true)
	request["expected_candidate_snapshot_revision"] = snapshot_revision
	return request


func _allocated_units_by_candidate(plan_or_receipt: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var allocations: Array = plan_or_receipt.get("allocations", []) if plan_or_receipt.get("allocations", []) is Array else []
	for allocation_variant in allocations:
		var allocation: Dictionary = allocation_variant
		result[str(allocation.get("candidate_id", ""))] = int(allocation.get("allocated_units", 0))
	return result


func _allocation_by_candidate(allocations: Array, candidate_id: String) -> Dictionary:
	for allocation_variant in allocations:
		if allocation_variant is Dictionary and str((allocation_variant as Dictionary).get("candidate_id", "")) == candidate_id:
			return (allocation_variant as Dictionary).duplicate(true)
	return {}


func _assets(value: int) -> Dictionary:
	return {"life": value, "energy": value, "industry": value, "technology": value, "commerce": value, "shipping": value}


func _state(cards: Array, assets: Dictionary) -> Dictionary:
	return {"revision": 0, "cash": 20, "assets": assets.duplicate(true), "inventory": {"hand_limit": 5, "slots": cards.duplicate(true)}}


func _card_count(player_state: Dictionary) -> int:
	var inventory: Dictionary = player_state.get("inventory", {}) if player_state.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	var count := 0
	for slot_variant in slots:
		if slot_variant is Dictionary:
			count += 1
	return count


func _same_player_resources(first: Dictionary, second: Dictionary) -> bool:
	return (
		int(first.get("revision", -1)) == int(second.get("revision", -2))
		and JSON.stringify(first.get("assets", {})) == JSON.stringify(second.get("assets", {}))
		and JSON.stringify(first.get("inventory", {})) == JSON.stringify(second.get("inventory", {}))
	)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CARD_GLOBAL_SUPPLY_DEMAND_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("CARD_GLOBAL_SUPPLY_DEMAND_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
