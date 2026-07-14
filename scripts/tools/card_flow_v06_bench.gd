extends Node

const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const POLICY_SCRIPT := preload("res://scripts/cards/v06/card_flow_policy_v06.gd")

var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	var report: Dictionary = catalog.reload() if catalog != null else {"valid": false}
	_check("catalog", bool(report.get("valid", false)), {"cards": report.get("card_count", 0), "families": report.get("family_count", 0), "effect_review_pending": report.get("effect_review_pending_count", 0)})
	if catalog == null:
		_finish()
		return
	var policy := POLICY_SCRIPT.new() as CardFlowPolicyV06
	var ring := catalog.card_snapshot("commodity.ring_crystal_battery.rank_1")
	var full_inventory := {"hand_limit": 5, "slots": [
		ring,
		catalog.card_snapshot("commodity.star_dew_berry.rank_1"),
		catalog.card_snapshot("facility.road.rank_1"),
		catalog.card_snapshot("interaction.phase_veto.rank_1"),
		catalog.card_snapshot("unit.monster.spore_tide_emperor.rank_1"),
	]}
	var auto_plan := policy.plan_receive(full_inventory, ring, catalog)
	_check("full_hand_auto_merge", bool(auto_plan.get("ready", false)) and str(auto_plan.get("result_card_id", "")) == "commodity.ring_crystal_battery.rank_2", {"operation": auto_plan.get("operation", ""), "reason_code": auto_plan.get("reason_code", "")})
	var unmatched_plan := policy.plan_receive(full_inventory, catalog.card_snapshot("commodity.lunar_soil_grape.rank_1"), catalog)
	_check("full_hand_unmatched_reject", not bool(unmatched_plan.get("ready", true)) and str(unmatched_plan.get("reason_code", "")) == "hand_full_no_matching_merge", {"reason_code": unmatched_plan.get("reason_code", "")})

	var belt_player := {"inventory": {"hand_limit": 5, "slots": []}, "cash": 0, "assets": _assets(), "committed_transaction_ids": []}
	var belt_plan := policy.plan_acquisition(belt_player, ring, {"source_kind": "commodity_belt", "transaction_id": "bench-belt-1", "visible": true, "claimable": true, "expected_revision": 2, "current_revision": 2}, catalog)
	var belt_commit := policy.commit_acquisition(belt_player, belt_plan)
	_check("belt_claim", bool(belt_commit.get("committed", false)) and int((belt_commit.get("player_state", {}) as Dictionary).get("cash", -1)) == 0, {"cash_debit": belt_commit.get("cash_debit", -1)})

	var warehouse := catalog.card_snapshot("facility.orbital_warehouse.rank_1")
	var market_player := {"inventory": {"hand_limit": 5, "slots": []}, "cash": 10, "assets": _assets(), "committed_transaction_ids": []}
	var market_plan := policy.plan_acquisition(market_player, warehouse, {"source_kind": "dynamic_market", "transaction_id": "bench-market-1", "listing_card_id": "facility.orbital_warehouse.rank_1", "expected_revision": 4, "current_revision": 4}, catalog)
	var market_commit := policy.commit_acquisition(market_player, market_plan)
	_check("market_purchase", bool(market_commit.get("committed", false)) and int((market_commit.get("player_state", {}) as Dictionary).get("cash", 0)) == 6 and bool(market_commit.get("market_refresh_required", false)), {"cash_debit": market_commit.get("cash_debit", -1), "refresh": market_commit.get("market_refresh_required", false)})

	var ring_player := {"inventory": {"hand_limit": 5, "slots": [ring]}, "cash": 0, "assets": _assets(), "committed_transaction_ids": []}
	var blocked_play := policy.plan_play(ring_player, 0, {"valid": true, "target_kind": "same_industry_factory_or_market"}, [], "bench-play-blocked")
	_check("unowned_effect_rejects_before_consume", not bool(blocked_play.get("ready", true)) and str(blocked_play.get("reason_code", "")) == "effect_owner_unavailable", {"reason_code": blocked_play.get("reason_code", "")})
	var play_plan := policy.plan_play(ring_player, 0, {"valid": true, "target_kind": "same_industry_factory_or_market", "target_id": "factory-energy-1"}, ["install_commodity_rate"], "bench-play-1")
	var play_commit := policy.commit_play(ring_player, play_plan, {"committed": true, "transaction_id": "bench-play-1"})
	_check("effect_then_consume", bool(play_commit.get("committed", false)) and _card_count((play_commit.get("player_state", {}) as Dictionary).get("inventory", {}) as Dictionary) == 0, {"effect_kind": play_commit.get("effect_kind", "")})
	var facility_assets := _assets()
	facility_assets["shipping"] = 1
	var facility_player := {"inventory": {"hand_limit": 5, "slots": [warehouse]}, "cash": 0, "assets": facility_assets, "committed_transaction_ids": []}
	var facility_plan := policy.plan_play(facility_player, 0, {
		"valid": true,
		"target_kind": "region_unique_facility_slot",
		"target_id": "warehouse-slot-shipping-1",
		"generic_asset_allocation": {"shipping": 1},
	}, ["build_upgrade_or_repair_facility"], "bench-play-generic-1")
	var facility_commit := policy.commit_play(facility_player, facility_plan, {"committed": true, "transaction_id": "bench-play-generic-1"})
	var facility_after: Dictionary = facility_commit.get("player_state", {}) if facility_commit.get("player_state", {}) is Dictionary else {}
	var facility_assets_after: Dictionary = facility_after.get("assets", {}) if facility_after.get("assets", {}) is Dictionary else {}
	_check("generic_cost_uses_colored_assets", bool(facility_commit.get("committed", false)) and int(facility_assets_after.get("shipping", -1)) == 0 and not facility_assets_after.has("generic"), {"payment_color": "shipping", "generic_pool_created": facility_assets_after.has("generic")})

	var serialized_player_text := JSON.stringify(catalog.catalog_snapshot().get("cards", []))
	_check("asset_terminology", not serialized_player_text.contains("法力") and not serialized_player_text.to_lower().contains("mana"), {"player_term": "资产"})
	_finish()


func _assets() -> Dictionary:
	return {"life": 0, "energy": 0, "industry": 0, "technology": 0, "commerce": 0, "shipping": 0}


func _card_count(inventory: Dictionary) -> int:
	var count := 0
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_variant in slots:
		if slot_variant is Dictionary:
			count += 1
	return count


func _check(event_name: String, valid: bool, fields: Dictionary) -> void:
	if not valid:
		_failures += 1
	_log(event_name, "OK" if valid else "E_CHECK", fields)


func _finish() -> void:
	var code := "OK" if _failures == 0 else "E_BENCH"
	_log("suite_complete", code, {"failures": _failures})
	set_meta("bench_exit_code", 0 if _failures == 0 else 1)
	_log("awaiting_mcp_stop", code, {"detail": "v0.6 卡牌流程验证完成，等待 Godot MCP 停止项目。"})


func _log(event_name: String, code: String, fields: Dictionary) -> void:
	var parts: Array[String] = ["CARD_FLOW_V06_BENCH", "event=%s" % event_name, "code=%s" % code]
	var keys := fields.keys()
	keys.sort()
	for key in keys:
		parts.append("%s=%s" % [str(key), str(fields.get(key)).replace("|", "/").replace("\n", " ")])
	print("|".join(parts))
