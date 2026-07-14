extends Node

const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const SERVICE_SCRIPT := preload("res://scripts/cards/v06/card_flow_transaction_service_v06.gd")
const QUOTE_AUTHORITY_FIXTURE_SCRIPT := preload("res://scripts/tools/card_market_quote_authority_fixture.gd")

var _failures := 0


class BenchEffectHandler:
	extends RefCounted

	var fail_commit := false

	func prepare_effect(intent: Dictionary) -> Dictionary:
		var receipt := intent.duplicate(true)
		receipt["prepared"] = true
		return receipt

	func commit_effect(prepared: Dictionary) -> Dictionary:
		var receipt := prepared.duplicate(true)
		receipt["committed"] = not fail_commit
		return receipt


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	var report: Dictionary = catalog.reload() if catalog != null else {"valid": false}
	_check("catalog", bool(report.get("valid", false)), {"cards": report.get("card_count", 0), "families": report.get("family_count", 0)})
	if catalog == null:
		_finish()
		return
	_run_belt_and_market(catalog)
	_run_effect_rollback(catalog)
	_finish()


func _run_belt_and_market(catalog: CardRuntimeCatalogV06Resource) -> void:
	var quote_authority = QUOTE_AUTHORITY_FIXTURE_SCRIPT.new()
	var service = SERVICE_SCRIPT.new(catalog, null, quote_authority)
	var ring := catalog.card_snapshot("commodity.ring_crystal_battery.rank_1")
	service.register_player("A", _state([], 10, {}, 0))
	service.register_player("B", _state([], 10, {}, 1))
	var state_port: Object = service.player_state_port()
	var port_read_variant: Variant = state_port.call("read_player", "A") if state_port != null else {}
	var port_read: Dictionary = port_read_variant as Dictionary if port_read_variant is Dictionary else {}
	var port_player: Dictionary = port_read.get("player_state", {}) if port_read.get("player_state", {}) is Dictionary else {}
	_check("single_player_state_authority", state_port != null and int(port_player.get("cash", -1)) == 10 and not _has_script_property(service, "_players"), {"cash": port_player.get("cash", -1), "private_players_removed": not _has_script_property(service, "_players")})
	service.configure_belt(10, [{"item_id": "belt-ring", "card": ring, "visible_actor_ids": ["A", "B"]}])
	var first := service.claim_belt_card("A", "belt-ring", 0, 10, "bench-belt-a")
	var second := service.claim_belt_card("B", "belt-ring", 0, 10, "bench-belt-b")
	_check("belt_single_winner", bool(first.get("committed", false)) and str(second.get("reason_code", "")) == "source_revision_changed", {"belt_revision": service.belt_snapshot().get("revision", -1), "second_reason": second.get("reason_code", "")})

	var warehouse := catalog.card_snapshot("facility.orbital_warehouse.rank_1")
	var road := catalog.card_snapshot("facility.road.rank_1")
	var warehouse_listing := _market_listing("market-warehouse", warehouse, 4, "bench-supply-warehouse")
	var road_listing := _market_listing("market-road", road, 3, "bench-supply-road")
	service.configure_market(20, warehouse_listing)
	var quote: Dictionary = quote_authority.issue_quote(0, 0, "facility.orbital_warehouse.rank_1", "bench-supply-warehouse", 4)
	var purchase := service.purchase_market_card("A", "market-warehouse", road_listing, 1, 20, "bench-market-a", quote)
	var market := service.market_snapshot()
	var listing: Dictionary = market.get("listing", {}) if market.get("listing", {}) is Dictionary else {}
	_check("market_atomic_refresh", bool(purchase.get("committed", false)) and int(market.get("revision", -1)) == 21 and str(listing.get("item_id", "")) == "market-road", {"cash": service.player_snapshot("A").get("cash", -1), "listing": listing.get("item_id", ""), "revision": market.get("revision", -1)})
	var replay := service.purchase_market_card("A", "market-warehouse", road_listing, 1, 20, "bench-market-a", quote)
	_check("transaction_replay", bool(replay.get("committed", false)) and bool(replay.get("idempotent_replay", false)) and int(service.market_snapshot().get("revision", -1)) == 21, {"idempotent": replay.get("idempotent_replay", false)})


func _run_effect_rollback(catalog: CardRuntimeCatalogV06Resource) -> void:
	var service = SERVICE_SCRIPT.new(catalog)
	var warehouse := catalog.card_snapshot("facility.orbital_warehouse.rank_1")
	var assets := _assets()
	assets["shipping"] = 1
	service.register_player("A", _state([warehouse], 0, assets))
	var handler := BenchEffectHandler.new()
	handler.fail_commit = true
	var target := {
		"valid": true,
		"target_kind": "region_unique_facility_slot",
		"target_id": "warehouse-slot-bench",
		"generic_asset_allocation": {"shipping": 1},
	}
	var result := service.play_card("A", 0, target, handler, 0, "bench-play-rollback")
	var player := service.player_snapshot("A")
	var player_assets: Dictionary = player.get("assets", {}) if player.get("assets", {}) is Dictionary else {}
	_check("effect_commit_rollback", str(result.get("reason_code", "")) == "effect_commit_failed" and bool(result.get("rolled_back", false)) and _card_count(player) == 1 and int(player_assets.get("shipping", -1)) == 1 and int(player.get("revision", -1)) == 0, {"card_count": _card_count(player), "reason": result.get("reason_code", ""), "revision": player.get("revision", -1), "shipping": player_assets.get("shipping", -1)})
	_check("six_color_assets", not player_assets.has("generic"), {"generic_pool": player_assets.has("generic"), "term": "资产"})


func _state(cards: Array, cash: int, assets: Dictionary = {}, player_index: int = -1) -> Dictionary:
	var state := {
		"revision": 0,
		"cash": cash,
		"assets": _assets() if assets.is_empty() else assets.duplicate(true),
		"inventory": {"hand_limit": 5, "slots": cards.duplicate(true)},
	}
	if player_index >= 0:
		state["player_index"] = player_index
	return state


func _market_listing(item_id: String, card: Dictionary, price_cash: int, supply_revision: String) -> Dictionary:
	return {
		"item_id": item_id,
		"card": card,
		"price_cash": price_cash,
		"source_district_index": 0,
		"source_region_id": "region.alpha",
		"supply_revision": supply_revision,
	}


func _assets() -> Dictionary:
	return {"life": 0, "energy": 0, "industry": 0, "technology": 0, "commerce": 0, "shipping": 0}


func _card_count(player: Dictionary) -> int:
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	var count := 0
	for card_variant in slots:
		if card_variant is Dictionary:
			count += 1
	return count


func _has_script_property(instance: Object, property_name: String) -> bool:
	for property_variant in instance.get_property_list():
		if property_variant is Dictionary and str((property_variant as Dictionary).get("name", "")) == property_name:
			return true
	return false


func _check(event_name: String, valid: bool, fields: Dictionary) -> void:
	if not valid:
		_failures += 1
	_log(event_name, "OK" if valid else "E_CHECK", fields)


func _finish() -> void:
	var code := "OK" if _failures == 0 else "E_BENCH"
	_log("suite_complete", code, {"failures": _failures})
	set_meta("bench_exit_code", 0 if _failures == 0 else 1)
	_log("awaiting_mcp_stop", code, {"detail": "v0.6 原子卡牌事务验证完成，等待 Godot MCP 停止项目。"})


func _log(event_name: String, code: String, fields: Dictionary) -> void:
	var parts: Array[String] = ["CARD_FLOW_TRANSACTION_V06_BENCH", "event=%s" % event_name, "code=%s" % code]
	var keys := fields.keys()
	keys.sort()
	for key in keys:
		parts.append("%s=%s" % [str(key), str(fields.get(key)).replace("|", "/").replace("\n", " ")])
	print("|".join(parts))
