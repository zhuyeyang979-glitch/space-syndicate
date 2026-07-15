extends SceneTree

const BRIDGE_SCRIPT := preload("res://scripts/runtime/commodity_flow_world_bridge.gd")
const FLOW_SCRIPT := preload("res://scripts/runtime/commodity_flow_runtime_controller.gd")
const PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")

var _checks := 0
var _failures: Array[String] = []


class RuntimeWorld:
	extends Node
	var players: Array = []


class RoleFlowBridge:
	extends "res://scripts/runtime/commodity_flow_world_bridge.gd"
	var facts: Dictionary = {}

	func capture_flow_facts() -> Dictionary:
		return facts.duplicate(true)


func _init() -> void:
	var world := RuntimeWorld.new()
	world.players = [
		_player("深海菌毯", 55),
		_player("重力陶瓷", 45),
	]
	root.add_child(world)
	var bridge := BRIDGE_SCRIPT.new()
	root.add_child(bridge)
	bridge.call("bind_world", world)

	var public_batch := {
		"batch_id": "role-cash-batch-1",
		"receipts": [
			_sale_receipt("commodity-sale-role-1", 0, "深海菌毯", 725),
			_sale_receipt("commodity-sale-role-2", 1, "星露莓", 300),
		],
	}
	var public_before := public_batch.duplicate(true)
	var first: Dictionary = bridge.call("apply_sale_receipt_batch", public_batch)
	var owner: Dictionary = world.players[0]
	var non_match: Dictionary = world.players[1]
	_expect(bool(first.get("applied", false)) and not bool(first.get("duplicate", true)), "matching CommodityFlow batch applies once")
	_expect(int(owner.get("cash_cents", 0)) == 10000 + 725 + 5500, "matching role receives the configured 55 cash in addition to sale proceeds")
	_expect(int(owner.get("cash", 0)) == 162, "whole-cash compatibility field follows authoritative cents")
	_expect(int(owner.get("total_role_income", 0)) == 55, "role income total increases by the configured amount")
	_expect(int(owner.get("last_cycle_income", 0)) == 55 and int(owner.get("last_cashflow_income", 0)) == 55 and int(owner.get("total_city_income", 0)) == 55, "cashflow compatibility counters receive the role amount")
	_expect(int(non_match.get("cash_cents", 0)) == 10000 + 300 and int(non_match.get("total_role_income", 0)) == 0, "non-matching role receives only ordinary sale proceeds")

	var role_rows := _ledger_rows(owner, "role_resource_cash")
	_expect(role_rows.size() == 1, "private player ledger records exactly one role resource-cash receipt")
	var role_receipt: Dictionary = role_rows[0] if not role_rows.is_empty() else {}
	_expect(int(role_receipt.get("ledger_delta_cents", 0)) == 5500 and str(role_receipt.get("source_receipt_id", "")) == "commodity-sale-role-1", "ledger receipt binds the exact amount to its Sale Receipt")
	_expect(str(role_receipt.get("commodity_id", "")) == "深海菌毯" and str(role_receipt.get("market_region_id", "")) == "region.private", "owner-private ledger retains product and region evidence")
	_expect(public_batch == public_before and not _contains_private_role_fields(public_batch), "public CommodityFlow receipt remains unchanged and exposes no role-beneficiary data")
	_expect(not first.has("role_receipt") and not first.has("player_index") and not first.has("commodity_id"), "bridge result does not project the private role receipt")

	var replay: Dictionary = bridge.call("apply_sale_receipt_batch", public_batch)
	owner = world.players[0]
	_expect(bool(replay.get("applied", false)) and bool(replay.get("duplicate", false)), "same batch id replays idempotently")
	_expect(int(owner.get("cash_cents", 0)) == 16225 and int(owner.get("total_role_income", 0)) == 55 and _ledger_rows(owner, "role_resource_cash").size() == 1, "batch replay repeats neither cash, role total, nor ledger receipt")

	var rebound := {
		"batch_id": "role-cash-batch-2",
		"receipts": [_sale_receipt("commodity-sale-role-1", 0, "深海菌毯", 0)],
	}
	var rebound_result: Dictionary = bridge.call("apply_sale_receipt_batch", rebound)
	owner = world.players[0]
	_expect(bool(rebound_result.get("applied", false)) and int(owner.get("total_role_income", 0)) == 55, "same source receipt cannot settle role income again under another batch id")
	_expect(_ledger_rows(owner, "role_resource_cash").size() == 1, "source-receipt exact-once guard prevents a second role ledger receipt")

	var debug: Dictionary = bridge.call("debug_snapshot")
	var service_debug: Dictionary = debug.get("role_resource_cash_settlement", {}) if debug.get("role_resource_cash_settlement", {}) is Dictionary else {}
	_expect(bool(service_debug.get("service_authoritative", false)) and (service_debug.get("public_receipt_fields_added", []) as Array).is_empty(), "explicit service owns the rule and declares a zero-field public projection")
	_verify_real_commodity_flow_chain()

	world.queue_free()
	bridge.queue_free()
	print("ROLE_RESOURCE_CASH_COMMODITY_SETTLEMENT_V06_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(_failures.size())


func _verify_real_commodity_flow_chain() -> void:
	var world := RuntimeWorld.new()
	world.players = [_player("星露莓", 35)]
	root.add_child(world)
	var bridge := RoleFlowBridge.new()
	var facility := {
		"facility_id": "role-cash-factory",
		"region_id": "region.role-cash",
		"facility_type": "factory",
		"industry_id": "life",
		"rank": 1,
		"active": true,
		"owner_player_index": 0,
		"owner_kind": "player",
	}
	bridge.facts = {
		"game_time": 0.0,
		"regions": [{
			"region_id": "region.role-cash",
			"revision": 1,
			"lifecycle_state": "active",
			"integrity_basis_points": 10000,
			"neighbor_region_ids": [],
		}],
		"facilities": [facility.duplicate(true)],
		"destroyed_facility_ids": [],
		"price_cents_by_commodity": {"星露莓": 1000},
		"route_candidates": [],
	}
	root.add_child(bridge)
	bridge.call("bind_world", world)
	var flow := FLOW_SCRIPT.new()
	root.add_child(flow)
	flow.call("set_world_bridge", bridge)
	var configured: Dictionary = flow.call("configure", PROFILE.call("debug_snapshot"))
	_expect(bool(configured.get("configured", false)), "real CommodityFlow owner configures for role settlement")
	var install: Dictionary = flow.call("install_commodity", {
		"transaction_id": "role-cash-install",
		"facility_id": "role-cash-factory",
		"facility": facility.duplicate(true),
		"region_id": "region.role-cash",
		"commodity_id": "星露莓",
		"direction": "production",
		"installer_player_index": 0,
		"source_card_rank": 1,
		"color": "life",
	})
	_expect(bool(install.get("committed", false)) and bool(flow.call("finalize_commodity_installation", install).get("finalized", false)), "real production installation commits and finalizes")
	var receipt_count := 0
	for second in range(1, 61):
		bridge.facts["game_time"] = float(second)
		var tick: Dictionary = flow.call("advance_world", 1.0)
		_expect(bool(tick.get("advanced", false)), "real CommodityFlow tick %d advances" % second)
		receipt_count += int(tick.get("receipt_count", 0))
	var player: Dictionary = world.players[0]
	_expect(receipt_count == 1, "real local production emits one authoritative regional Sale Receipt")
	_expect(int(player.get("cash_cents", 0)) == 10000 + 100 + 3500 and int(player.get("total_role_income", 0)) == 35, "real controller-to-bridge chain settles sale cash and role cash together")
	_expect(_ledger_rows(player, "role_resource_cash").size() == 1, "real controller chain writes exactly one private role ledger receipt")
	var public_receipts: Array = flow.call("recent_sale_receipts_snapshot", -1)
	var public_receipt: Dictionary = public_receipts[0] if public_receipts.size() == 1 and public_receipts[0] is Dictionary else {}
	_expect(not public_receipt.has("commodity_owner") and not _contains_private_role_fields(public_receipt), "public CommodityFlow projection hides owner and all role settlement evidence")
	flow.queue_free()
	bridge.queue_free()
	world.queue_free()


func _player(product_id: String, amount: int) -> Dictionary:
	return {
		"cash": 100,
		"cash_cents": 10000,
		"total_role_income": 0,
		"role_card": {
			"name": "private-role",
			"resource_cash_product": product_id,
			"resource_cash_amount": amount,
		},
		"v06_transaction_ledger": [],
	}


func _sale_receipt(receipt_id: String, owner_index: int, commodity_id: String, owner_net_cash: int) -> Dictionary:
	return {
		"receipt_id": receipt_id,
		"trade_kind": "local_production_baseline",
		"commodity_owner": owner_index,
		"commodity_id": commodity_id,
		"market_region_id": "region.private",
		"owner_net_cash": owner_net_cash,
		"rent_rows": [],
	}


func _ledger_rows(player: Dictionary, category: String) -> Array:
	var result: Array = []
	for row_variant in player.get("v06_transaction_ledger", []):
		if row_variant is Dictionary and str((row_variant as Dictionary).get("category", "")) == category:
			result.append((row_variant as Dictionary).duplicate(true))
	return result


func _contains_private_role_fields(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) in ["role_card", "role_name", "role_receipt", "resource_cash_amount", "resource_cash_product"]:
				return true
			if _contains_private_role_fields((value as Dictionary)[key_variant]):
				return true
	elif value is Array:
		for item_variant in value:
			if _contains_private_role_fields(item_variant):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)
