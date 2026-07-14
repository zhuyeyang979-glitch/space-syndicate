extends SceneTree

const PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const FLOW_SCRIPT := preload("res://scripts/runtime/commodity_flow_runtime_controller.gd")
const WORLD_BRIDGE_SCRIPT := preload("res://scripts/runtime/commodity_flow_world_bridge.gd")
const PRODUCT_ID := "星露莓"
const BASE_PRICE_CENTS := 1000

var _checks := 0
var _failures: Array[String] = []


class FlowFactsBridge:
	extends Node
	var facts: Dictionary = {}
	var cash_by_player: Dictionary = {}
	var committed_receipts: Array = []
	var applied_batches: Dictionary = {}

	func capture_flow_facts() -> Dictionary:
		return facts.duplicate(true)

	func apply_sale_receipt_batch(batch: Dictionary) -> Dictionary:
		var batch_id := str(batch.get("batch_id", ""))
		if applied_batches.has(batch_id):
			return {"applied": true, "duplicate": true, "batch_id": batch_id}
		var receipts: Array = batch.get("receipts", []) if batch.get("receipts", []) is Array else []
		for receipt_variant in receipts:
			if not (receipt_variant is Dictionary):
				return {"applied": false, "reason": "receipt_invalid"}
			var receipt: Dictionary = receipt_variant
			var owner := int(receipt.get("commodity_owner", -1))
			var owner_cash := int(receipt.get("owner_net_cash", 0))
			if owner >= 0:
				cash_by_player[owner] = int(cash_by_player.get(owner, 0)) + owner_cash
			elif str(receipt.get("economic_owner_kind", "")) != "public_local" or owner_cash != 0:
				return {"applied": false, "reason": "neutral_receipt_invalid"}
			committed_receipts.append(receipt.duplicate(true))
		applied_batches[batch_id] = receipts.size()
		return {"applied": true, "duplicate": false, "batch_id": batch_id, "receipt_count": receipts.size()}


class WorldState:
	extends Node
	var players: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var local_production := _verify_isolated_production_baseline()
	var local_market := _verify_isolated_market_baseline(false)
	var neutral_market := _verify_isolated_market_baseline(true)
	_verify_remote_priority(local_production, local_market)
	_verify_save_load(local_production)
	_verify_world_bridge_exact_once(local_market, neutral_market)
	_verify_modifier_contract()
	_finish()


func _verify_isolated_production_baseline() -> Dictionary:
	var factory := _facility("factory.local", "region.local", "factory", 0, "player")
	var fixture := _flow_fixture([_region("region.local")], [factory], [])
	var flow: Node = fixture.get("flow")
	var bridge: FlowFactsBridge = fixture.get("bridge")
	_install(flow, factory, "production", 0, false)
	var advance := _advance_seconds(flow, bridge, 60)
	var receipts := bridge.committed_receipts.duplicate(true)
	_expect(receipts.size() == 1, "isolated high-rate factory sells only one capped local unit per minute")
	var receipt: Dictionary = receipts[0] if receipts.size() == 1 and receipts[0] is Dictionary else {}
	_expect(str(receipt.get("trade_kind", "")) == "local_production_baseline" and str(receipt.get("source_region_id", "")) == "region.local" and str(receipt.get("market_region_id", "")) == "region.local", "production baseline is explicitly local")
	_expect(str(receipt.get("route_id", "x")).is_empty() and str(receipt.get("market_facility_id", "x")).is_empty() and (receipt.get("rent_rows", []) as Array).is_empty(), "production baseline invents no route, market, or rent")
	_expect(int(receipt.get("value_basis_points", 0)) == 1000 and int(receipt.get("gross_value", 0)) == 100 and int(receipt.get("owner_net_cash", 0)) == 100 and int(receipt.get("gdp_value", 0)) == 100, "production baseline pays and attributes the configured ten-percent value exactly")
	_expect(int(bridge.cash_by_player.get(0, 0)) == 100, "production owner cash ledger equals the authoritative receipt")
	_expect(int(advance.get("backpressured_milliunits", 0)) == 9000, "unabsorbed high-rate production remains in existing backpressure semantics")
	var public_receipts: Array = flow.call("recent_sale_receipts_snapshot", -1)
	var public_receipt: Dictionary = public_receipts[0] if public_receipts.size() == 1 and public_receipts[0] is Dictionary else {}
	_expect(not public_receipt.has("commodity_owner") and not public_receipt.has("source_installation_id") and not public_receipt.has("observer_intents"), "public baseline receipt preserves the existing privacy projection")
	var save: Dictionary = flow.call("to_save_data")
	_expect(int(save.get("local_production_absorption_units_per_minute", 0)) == 1 and int(save.get("local_production_absorption_rate_cap_basis_points", 0)) == 1000 and int(save.get("local_production_baseline_value_basis_points", 0)) == 1000, "production baseline budget and value terms are explicit save fields")
	var saved_backpressure: Dictionary = save.get("backpressured_milliunits_by_source", {}) if save.get("backpressured_milliunits_by_source", {}) is Dictionary else {}
	_expect(int(saved_backpressure.get("a10-install:factory.local", saved_backpressure.get("commodity-installation-00000001", 0))) == 9000 or _dictionary_value_total(saved_backpressure) == 9000, "save data preserves authoritative unsold backpressure without turning it into inventory")
	var result := {"fixture": fixture, "receipt": receipt, "save": save, "backpressured_milliunits": int(advance.get("backpressured_milliunits", 0))}
	return result


func _verify_isolated_market_baseline(neutral: bool) -> Dictionary:
	var owner := -1 if neutral else 1
	var owner_kind := "neutral" if neutral else "player"
	var region_id := "region.neutral" if neutral else "region.market"
	var market := _facility("market.%s" % region_id, region_id, "market", owner, owner_kind)
	var fixture := _flow_fixture([_region(region_id)], [market], [])
	var flow: Node = fixture.get("flow")
	var bridge: FlowFactsBridge = fixture.get("bridge")
	_install(flow, market, "demand", owner, neutral)
	_advance_seconds(flow, bridge, 60)
	var receipts := bridge.committed_receipts.duplicate(true)
	_expect(receipts.size() == 1, "isolated %s market turns over one capped local unit per minute" % ("neutral" if neutral else "player"))
	var receipt: Dictionary = receipts[0] if receipts.size() == 1 and receipts[0] is Dictionary else {}
	_expect(str(receipt.get("trade_kind", "")) == "local_market_baseline" and str(receipt.get("route_id", "x")).is_empty() and str(receipt.get("source_factory_id", "x")).is_empty(), "market baseline is explicit and invents no factory or route")
	_expect(int(receipt.get("value_basis_points", 0)) == 500 and int(receipt.get("gdp_value", 0)) == 50, "market baseline contributes the configured five-percent GDP")
	if neutral:
		_expect(int(receipt.get("commodity_owner", 0)) == -1 and int(receipt.get("owner_net_cash", -1)) == 0 and bridge.cash_by_player.is_empty(), "neutral public market contributes GDP without player cash or rent")
	else:
		_expect(int(receipt.get("commodity_owner", -1)) == 1 and int(receipt.get("owner_net_cash", 0)) == 50 and int(bridge.cash_by_player.get(1, 0)) == 50, "player market owner receives the exact local turnover receipt")
	return {"fixture": fixture, "receipt": receipt, "save": flow.call("to_save_data")}


func _verify_remote_priority(local_production: Dictionary, local_market: Dictionary) -> void:
	var factory := _facility("factory.remote", "region.source", "factory", 0, "player")
	var market := _facility("market.remote", "region.market", "market", 1, "player")
	var route := {
		"route_id": "route.source-market",
		"commodity_id": PRODUCT_ID,
		"source_region_id": "region.source",
		"market_region_id": "region.market",
		"ordered_legs": [
			{"from_region_id": "region.source", "to_region_id": "region.mid", "mode": "trade"},
			{"from_region_id": "region.mid", "to_region_id": "region.market", "mode": "trade"},
		],
		"mode_tags": ["trade"],
		"shortest_legal_distance": 3,
		"bottleneck_units_per_minute": 100,
		"expected_rents": [],
		"topology_revision": "route-rev-1",
	}
	var fixture := _flow_fixture([_region("region.source"), _region("region.market")], [factory, market], [route])
	var flow: Node = fixture.get("flow")
	var bridge: FlowFactsBridge = fixture.get("bridge")
	_install(flow, factory, "production", 0, false)
	_install(flow, market, "demand", 1, false)
	var advance := _advance_seconds(flow, bridge, 60)
	var receipts := bridge.committed_receipts.duplicate(true)
	var remote_count := _trade_kind_count(receipts, "remote_route")
	var local_count := _trade_kind_count(receipts, "local_production_baseline") + _trade_kind_count(receipts, "local_market_baseline")
	_expect(remote_count == 10 and local_count == 0, "remote matching consumes each supply and demand unit before either local baseline")
	_expect(_receipt_unit_total(receipts) == 10 and int(advance.get("backpressured_milliunits", -1)) == 0, "matched production has no double sale and releases the isolated-factory backpressure")
	var remote_receipt: Dictionary = receipts[0] if not receipts.is_empty() and receipts[0] is Dictionary else {}
	var production_value := int((local_production.get("receipt", {}) as Dictionary).get("gross_value", 0))
	var market_value := int((local_market.get("receipt", {}) as Dictionary).get("gross_value", 0))
	_expect(int(remote_receipt.get("gross_value", 0)) >= production_value * 5 and int(remote_receipt.get("gross_value", 0)) >= market_value * 5, "explicit remote route value remains at least five times either local baseline")
	_expect(int(bridge.cash_by_player.get(0, 0)) == _receipt_owner_cash_total(receipts, 0) and int(bridge.cash_by_player.get(1, 0)) == 0, "remote cash remains receipt-exact and does not pay an unconfigured market rent")
	_free_fixture(fixture)


func _verify_save_load(local_production: Dictionary) -> void:
	var fixture: Dictionary = local_production.get("fixture", {})
	var original_flow: Node = fixture.get("flow")
	var original_bridge: FlowFactsBridge = fixture.get("bridge")
	var saved: Dictionary = original_flow.call("to_save_data")
	var restored_flow := FLOW_SCRIPT.new()
	var restored_bridge := FlowFactsBridge.new()
	restored_bridge.facts = original_bridge.facts.duplicate(true)
	root.add_child(restored_flow)
	root.add_child(restored_bridge)
	restored_flow.call("set_world_bridge", restored_bridge)
	_expect(bool(restored_flow.call("configure", PROFILE.call("debug_snapshot")).get("configured", false)), "restored owner configures with the same baseline terms")
	var applied: Dictionary = restored_flow.call("apply_save_data", saved)
	_expect(bool(applied.get("applied", false)) and (restored_flow.call("to_save_data").get("recent_sale_receipts", []) as Array).size() == 1, "save/load preserves baseline receipts, budget remainder, and unsold-state schema")
	var resumed := _advance_seconds(restored_flow, restored_bridge, 60, 60)
	var restored_save: Dictionary = restored_flow.call("to_save_data")
	var restored_receipts: Array = restored_save.get("recent_sale_receipts", [])
	var resumed_receipt: Dictionary = restored_bridge.committed_receipts[0] if restored_bridge.committed_receipts.size() == 1 and restored_bridge.committed_receipts[0] is Dictionary else {}
	var original_receipt: Dictionary = local_production.get("receipt", {}) if local_production.get("receipt", {}) is Dictionary else {}
	var restored_backpressure: Dictionary = restored_save.get("backpressured_milliunits_by_source", {}) if restored_save.get("backpressured_milliunits_by_source", {}) is Dictionary else {}
	_expect(restored_bridge.committed_receipts.size() == 1 and str(resumed_receipt.get("receipt_id", "")) != str(original_receipt.get("receipt_id", "")) and int(restored_save.get("receipt_sequence", 0)) == 2 and restored_receipts.size() == 1 and int(resumed.get("backpressured_milliunits", 0)) == 9000 and _dictionary_value_total(restored_backpressure) == 18000, "resumed budget emits one new receipt without replay and preserves cumulative unsold backpressure after the observation-window prune")
	var incompatible := saved.duplicate(true)
	incompatible["local_production_baseline_value_basis_points"] = 999
	var before_incompatible := JSON.stringify(restored_flow.call("to_save_data"))
	var rejected: Dictionary = restored_flow.call("apply_save_data", incompatible)
	_expect(not bool(rejected.get("applied", false)) and str(rejected.get("reason", "")) == "local_baseline_terms_mismatch" and before_incompatible == JSON.stringify(restored_flow.call("to_save_data")), "mismatched baseline save terms fail closed without mutation")
	restored_flow.queue_free()
	restored_bridge.queue_free()
	_free_fixture(fixture)


func _verify_world_bridge_exact_once(local_market: Dictionary, neutral_market: Dictionary) -> void:
	var world := WorldState.new()
	world.players = [
		{"cash": 0, "cash_cents": 0},
		{"cash": 0, "cash_cents": 0},
	]
	var bridge := WORLD_BRIDGE_SCRIPT.new()
	root.add_child(world)
	root.add_child(bridge)
	bridge.call("bind_world", world)
	var player_receipt: Dictionary = (local_market.get("receipt", {}) as Dictionary).duplicate(true)
	var player_batch := {"batch_id": "a10-player-market", "receipts": [player_receipt]}
	var first: Dictionary = bridge.call("apply_sale_receipt_batch", player_batch)
	var replay: Dictionary = bridge.call("apply_sale_receipt_batch", player_batch)
	_expect(bool(first.get("applied", false)) and bool(replay.get("duplicate", false)) and int((world.players[1] as Dictionary).get("cash_cents", 0)) == int(player_receipt.get("owner_net_cash", 0)), "player market receipt applies cash exactly once")
	var neutral_receipt: Dictionary = (neutral_market.get("receipt", {}) as Dictionary).duplicate(true)
	var before_neutral := JSON.stringify(world.players)
	var neutral_result: Dictionary = bridge.call("apply_sale_receipt_batch", {"batch_id": "a10-neutral-market", "receipts": [neutral_receipt]})
	_expect(bool(neutral_result.get("applied", false)) and before_neutral == JSON.stringify(world.players), "production world bridge accepts neutral local GDP without creating player cash")
	var forged := neutral_receipt.duplicate(true)
	forged["owner_net_cash"] = 1
	var forged_result: Dictionary = bridge.call("apply_sale_receipt_batch", {"batch_id": "a10-neutral-forged", "receipts": [forged]})
	_expect(not bool(forged_result.get("applied", false)) and before_neutral == JSON.stringify(world.players), "neutral local receipt cannot smuggle player cash through the world bridge")
	world.queue_free()
	bridge.queue_free()
	_free_fixture(local_market.get("fixture", {}))
	_free_fixture(neutral_market.get("fixture", {}))


func _verify_modifier_contract() -> void:
	var fixture := _flow_fixture([], [], [])
	var flow: Node = fixture.get("flow")
	var capability: Dictionary = flow.call("local_baseline_modifier_capability_snapshot")
	var required_fields: Array = capability.get("required_effect_fields", []) if capability.get("required_effect_fields", []) is Array else []
	_expect(not bool(capability.get("available", true)) and str(capability.get("authoritative_owner", "")) == "CommodityFlowRuntimeController" and required_fields.has("local_production_absorption_delta_units_per_minute") and required_fields.has("local_market_turnover_delta_units_per_minute") and required_fields.has("local_baseline_modifier_seconds"), "future local-demand card fields are reserved by the single flow owner")
	var before := JSON.stringify(flow.call("to_save_data"))
	var rejected: Dictionary = flow.call("prepare_card_effect_batch", {
		"transaction_id": "a10-modifier-not-authored",
		"intent_hash": "intent-a10",
		"plan_hash": "plan-a10",
		"one_time_effect_kind": "local_baseline_modifier",
		"local_production_absorption_delta_units_per_minute": 1,
		"local_market_turnover_delta_units_per_minute": 1,
		"local_baseline_modifier_seconds": 30,
	})
	_expect(str(rejected.get("reason_code", "")) == "local_baseline_modifier_terms_not_authored" and before == JSON.stringify(flow.call("to_save_data")), "unauthored modifier fails closed before prepare and creates no second modifier state")
	_free_fixture(fixture)


func _flow_fixture(regions: Array, facilities: Array, routes: Array) -> Dictionary:
	var flow := FLOW_SCRIPT.new()
	var bridge := FlowFactsBridge.new()
	bridge.facts = {
		"game_time": 0.0,
		"regions": regions.duplicate(true),
		"facilities": facilities.duplicate(true),
		"destroyed_facility_ids": [],
		"price_cents_by_commodity": {PRODUCT_ID: BASE_PRICE_CENTS},
		"route_candidates": routes.duplicate(true),
	}
	root.add_child(flow)
	root.add_child(bridge)
	flow.call("set_world_bridge", bridge)
	var configured: Dictionary = flow.call("configure", PROFILE.call("debug_snapshot"))
	_expect(bool(configured.get("configured", false)), "CommodityFlow fixture configures")
	return {"flow": flow, "bridge": bridge}


func _install(flow: Node, facility: Dictionary, direction: String, player_index: int, public_demand: bool) -> void:
	var request := {
		"transaction_id": "a10-install:%s" % str(facility.get("facility_id", "")),
		"facility_id": str(facility.get("facility_id", "")),
		"facility": facility.duplicate(true),
		"region_id": str(facility.get("region_id", "")),
		"commodity_id": PRODUCT_ID,
		"direction": direction,
		"installer_player_index": player_index,
		"source_card_rank": 1,
		"color": "life",
	}
	var receipt: Dictionary = flow.call("install_public_demand" if public_demand else "install_commodity", request)
	_expect(bool(receipt.get("committed", false)), "%s installation commits" % direction)
	var finalized: Dictionary = flow.call("finalize_commodity_installation", receipt)
	_expect(bool(finalized.get("finalized", false)), "%s installation finalizes" % direction)


func _advance_seconds(flow: Node, bridge: FlowFactsBridge, seconds: int, start_second := 0) -> Dictionary:
	var totals := {"backpressured_milliunits": 0, "gdp_value": 0, "owner_net_cash": 0}
	var all_advanced := true
	var first_failed_second := -1
	for second in range(start_second + 1, start_second + seconds + 1):
		bridge.facts["game_time"] = float(second)
		var result: Dictionary = flow.call("advance_world", 1.0)
		if not bool(result.get("advanced", false)):
			all_advanced = false
			if first_failed_second < 0:
				first_failed_second = second
		for field in totals.keys():
			totals[field] = int(totals.get(field, 0)) + int(result.get(field, 0))
	_expect(all_advanced, "flow advances for the complete interval; first failed second=%d" % first_failed_second)
	return totals


func _facility(facility_id: String, region_id: String, facility_type: String, owner_player_index: int, owner_kind: String) -> Dictionary:
	return {
		"facility_id": facility_id,
		"region_id": region_id,
		"facility_type": facility_type,
		"industry_id": "life",
		"rank": 1,
		"active": true,
		"owner_player_index": owner_player_index,
		"owner_kind": owner_kind,
	}


func _region(region_id: String) -> Dictionary:
	return {
		"region_id": region_id,
		"revision": 1,
		"lifecycle_state": "active",
		"integrity_basis_points": 10000,
		"neighbor_region_ids": [],
	}


func _trade_kind_count(receipts: Array, trade_kind: String) -> int:
	var count := 0
	for receipt_variant in receipts:
		if receipt_variant is Dictionary and str((receipt_variant as Dictionary).get("trade_kind", "")) == trade_kind:
			count += 1
	return count


func _receipt_unit_total(receipts: Array) -> int:
	var total := 0
	for receipt_variant in receipts:
		if receipt_variant is Dictionary:
			total += int((receipt_variant as Dictionary).get("units", 0))
	return total


func _receipt_owner_cash_total(receipts: Array, player_index: int) -> int:
	var total := 0
	for receipt_variant in receipts:
		if receipt_variant is Dictionary and int((receipt_variant as Dictionary).get("commodity_owner", -1)) == player_index:
			total += int((receipt_variant as Dictionary).get("owner_net_cash", 0))
	return total


func _dictionary_value_total(values: Dictionary) -> int:
	var total := 0
	for value_variant in values.values():
		total += int(value_variant)
	return total


func _free_fixture(fixture_variant: Variant) -> void:
	if not (fixture_variant is Dictionary):
		return
	var fixture: Dictionary = fixture_variant
	var flow: Variant = fixture.get("flow")
	var bridge: Variant = fixture.get("bridge")
	if flow is Node:
		(flow as Node).queue_free()
	if bridge is Node:
		(bridge as Node).queue_free()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print("COMMODITY_FLOW_LOCAL_BASELINE_DEMAND_V06_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(_failures.size())
