extends SceneTree

const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const PROFILE_PATH := "res://resources/rules/space_syndicate_ruleset_v06.tres"
const TRANSACTION_SERVICE_SCRIPT := preload("res://scripts/cards/v06/card_flow_transaction_service_v06.gd")
const FACILITY_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/effects/facility_card_effect_adapter_v06.gd")
const COMMODITY_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/effects/commodity_card_effect_adapter_v06.gd")
const INFRASTRUCTURE_SCRIPT := preload("res://scripts/runtime/region_infrastructure_runtime_controller.gd")
const COMMODITY_FLOW_SCRIPT := preload("res://scripts/runtime/commodity_flow_runtime_controller.gd")
const BINDING_KEYS := ["transaction_id", "actor_id", "card_id", "card_instance_id", "effect_kind", "target_hash", "payload_hash", "intent_hash"]

var _checks := 0
var _failures: Array[String] = []
var _infrastructure: Node
var _flow: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	var profile := load(PROFILE_PATH) as SpaceSyndicateRulesetProfileV06
	_expect(catalog != null and bool(catalog.reload().get("valid", false)), "v0.6 card catalog is ready")
	_expect(profile != null, "real v0.6 ruleset profile loads")
	if catalog == null or profile == null:
		_finish()
		return
	var ruleset_snapshot := profile.debug_snapshot()
	_infrastructure = INFRASTRUCTURE_SCRIPT.new()
	_flow = COMMODITY_FLOW_SCRIPT.new()
	root.add_child(_infrastructure)
	root.add_child(_flow)
	_expect(bool(_infrastructure.call("configure", ruleset_snapshot).get("configured", false)), "infrastructure controller accepts the real v0.6 profile")
	_expect(bool(_flow.call("configure", ruleset_snapshot).get("configured", false)), "commodity-flow controller accepts the real v0.6 profile")
	var initialized: Dictionary = _infrastructure.call("initialize_regions", [{
		"region_id": "region-alpha",
		"terrain_id": "temperate",
		"neighbor_region_ids": [],
		"legacy_index": 0,
	}])
	_expect(bool(initialized.get("initialized", false)), "real infrastructure controller initializes a v0.6 region")

	var actor_map := {"syndicate-a": 0, "syndicate-b": 1}
	var facility_adapter = FACILITY_ADAPTER_SCRIPT.new()
	var commodity_adapter = COMMODITY_ADAPTER_SCRIPT.new()
	_expect(bool(facility_adapter.configure(_infrastructure, actor_map).get("configured", false)), "facility adapter configures with explicit actor mapping")
	_expect(bool(commodity_adapter.configure(_flow, _infrastructure, actor_map).get("configured", false)), "commodity adapter configures with explicit actor mapping")

	_verify_successful_facility_and_commodity_play(catalog, facility_adapter, commodity_adapter)
	_verify_invalid_targets_do_not_consume(catalog, facility_adapter, commodity_adapter)
	_verify_warehouse_requires_server_validated_color(catalog, facility_adapter)
	_finish()


func _verify_successful_facility_and_commodity_play(catalog: CardRuntimeCatalogV06Resource, facility_adapter: Object, commodity_adapter: Object) -> void:
	var service = TRANSACTION_SERVICE_SCRIPT.new(catalog)
	var factory := catalog.card_snapshot("facility.factory.life.rank_1")
	var commodity := catalog.card_snapshot("commodity.star_dew_berry.rank_1")
	var assets := _assets()
	_expect(bool(service.register_player("syndicate-a", _state([factory, commodity], assets)).get("configured", false)), "test syndicate registers with zero assets for the rank-I bootstrap")

	var facility_target := {
		"valid": true,
		"target_kind": "region_unique_facility_slot",
		"region_id": "region-alpha",
		"slot_id": "region-alpha::factory.life",
		"industry_id": "life",
		"owner_player_index": 99,
		"player_index": 99,
	}
	var facility_result: Dictionary = service.play_card("syndicate-a", 0, facility_target, facility_adapter, 0, "tx-core-facility-1")
	_expect(bool(facility_result.get("committed", false)), "facility card commits through CardFlowTransactionServiceV06")
	_expect(_card_count(facility_result.get("player_state", {}) as Dictionary) == 1, "facility card is consumed only after the owner commits")
	_expect(int((facility_result.get("player_state", {}) as Dictionary).get("assets", {}).get("life", -1)) == 0, "rank-I facility commits without inventing or debiting a life asset")
	_expect(_receipt_binding_complete(facility_result.get("effect_receipt", {}) as Dictionary), "facility effect receipt preserves all transaction bindings")
	var facilities: Array = _infrastructure.call("facilities_snapshot", false)
	_expect(facilities.size() == 1, "facility owner creates exactly one real facility")
	var facility: Dictionary = facilities[0] if not facilities.is_empty() else {}
	_expect(str(facility.get("slot_id", "")) == "region-alpha::factory.life", "facility is created in the server-derived slot")
	_expect(int(facility.get("owner_player_index", -1)) == 0, "facility owner comes from actor mapping, not spoofed target fields")
	var facility_replay: Dictionary = service.play_card("syndicate-a", 0, facility_target, facility_adapter, 0, "tx-core-facility-1")
	_expect(bool(facility_replay.get("committed", false)) and bool(facility_replay.get("idempotent_replay", false)), "repeating the facility transaction returns the journaled result")
	_expect((_infrastructure.call("facilities_snapshot", false) as Array).size() == 1, "facility replay does not build twice")

	var commodity_target := {
		"valid": true,
		"target_kind": "same_industry_factory_or_market",
		"facility_id": str(facility.get("facility_id", "")),
		"direction": "production",
		"installer_player_index": 99,
		"player_index": 99,
	}
	var commodity_result: Dictionary = service.play_card("syndicate-a", 1, commodity_target, commodity_adapter, 1, "tx-core-commodity-1")
	_expect(bool(commodity_result.get("committed", false)), "commodity card commits through CardFlowTransactionServiceV06")
	_expect(_card_count(commodity_result.get("player_state", {}) as Dictionary) == 0, "commodity card is consumed after installation commits")
	_expect(_receipt_binding_complete(commodity_result.get("effect_receipt", {}) as Dictionary), "commodity effect receipt preserves all transaction bindings")
	var installations: Array = _flow.call("installations_snapshot", false)
	_expect(installations.size() == 1, "commodity owner creates exactly one real installation")
	var installation: Dictionary = installations[0] if not installations.is_empty() else {}
	_expect(str(installation.get("commodity_id", "")) == "星露莓" and str(installation.get("direction", "")) == "production", "commodity installation resolves product and direction from card plus facility")
	_expect(str(installation.get("color", "")) == "life", "commodity installation uses the same facility color")
	_expect(int(installation.get("installer_player_index", -1)) == 0, "commodity owner comes from actor mapping, not spoofed target fields")
	var commodity_replay: Dictionary = service.play_card("syndicate-a", 1, commodity_target, commodity_adapter, 1, "tx-core-commodity-1")
	_expect(bool(commodity_replay.get("committed", false)) and bool(commodity_replay.get("idempotent_replay", false)), "repeating the commodity transaction returns the journaled result")
	_expect((_flow.call("installations_snapshot", false) as Array).size() == 1, "commodity replay does not install twice")


func _verify_invalid_targets_do_not_consume(catalog: CardRuntimeCatalogV06Resource, facility_adapter: Object, commodity_adapter: Object) -> void:
	var occupied_service = TRANSACTION_SERVICE_SCRIPT.new(catalog)
	var factory := catalog.card_snapshot("facility.factory.life.rank_1")
	var facility_assets := _assets()
	facility_assets["life"] = 1
	occupied_service.register_player("syndicate-b", _state([factory], facility_assets))
	var occupied_before := occupied_service.player_snapshot("syndicate-b")
	var occupied_target := {
		"valid": true,
		"target_kind": "region_unique_facility_slot",
		"region_id": "region-alpha",
		"slot_id": "region-alpha::factory.life",
		"industry_id": "life",
	}
	var occupied_result: Dictionary = occupied_service.play_card("syndicate-b", 0, occupied_target, facility_adapter, 0, "tx-core-facility-owned")
	_expect(not bool(occupied_result.get("committed", true)) and str(occupied_result.get("reason_code", "")) == "effect_prepare_failed", "another syndicate cannot overwrite an occupied facility slot")
	_expect(_same_player_resources(occupied_before, occupied_service.player_snapshot("syndicate-b")), "invalid facility target consumes neither card nor assets")
	_expect((_infrastructure.call("facilities_snapshot", false) as Array).size() == 1, "invalid facility target leaves infrastructure unchanged")

	var color_service = TRANSACTION_SERVICE_SCRIPT.new(catalog)
	var energy_commodity := catalog.card_snapshot("commodity.ring_crystal_battery.rank_1")
	color_service.register_player("syndicate-b", _state([energy_commodity], _assets()))
	var color_before := color_service.player_snapshot("syndicate-b")
	var facility: Dictionary = (_infrastructure.call("facilities_snapshot", false) as Array)[0]
	var wrong_color_target := {
		"valid": true,
		"target_kind": "same_industry_factory_or_market",
		"facility_id": str(facility.get("facility_id", "")),
	}
	var color_result: Dictionary = color_service.play_card("syndicate-b", 0, wrong_color_target, commodity_adapter, 0, "tx-core-commodity-color")
	_expect(not bool(color_result.get("committed", true)) and str(color_result.get("reason_code", "")) == "effect_prepare_failed", "commodity adapter rejects a different-color facility")
	_expect(_same_player_resources(color_before, color_service.player_snapshot("syndicate-b")), "invalid commodity target consumes neither card nor assets")
	_expect((_flow.call("installations_snapshot", false) as Array).size() == 1, "invalid commodity target leaves installations unchanged")


func _verify_warehouse_requires_server_validated_color(catalog: CardRuntimeCatalogV06Resource, facility_adapter: Object) -> void:
	var service = TRANSACTION_SERVICE_SCRIPT.new(catalog)
	var warehouse := catalog.card_snapshot("facility.orbital_warehouse.rank_1")
	var assets := _assets()
	assets["shipping"] = 1
	service.register_player("syndicate-a", _state([warehouse], assets))
	var missing_color_target := {
		"valid": true,
		"target_kind": "region_unique_facility_slot",
		"region_id": "region-alpha",
		"slot_id": "region-alpha::warehouse.shipping",
		"generic_asset_allocation": {"shipping": 1},
	}
	var before := service.player_snapshot("syndicate-a")
	var result: Dictionary = service.play_card("syndicate-a", 0, missing_color_target, facility_adapter, 0, "tx-core-warehouse-no-color")
	_expect(not bool(result.get("committed", true)), "generic warehouse card requires an explicit server-validated industry slot color")
	_expect(_same_player_resources(before, service.player_snapshot("syndicate-a")), "missing warehouse color consumes neither card nor shipping asset")


func _state(cards: Array, assets: Dictionary) -> Dictionary:
	return {
		"revision": 0,
		"cash": 20,
		"assets": assets.duplicate(true),
		"inventory": {"hand_limit": 5, "slots": cards.duplicate(true)},
	}


func _assets() -> Dictionary:
	return {"life": 0, "energy": 0, "industry": 0, "technology": 0, "commerce": 0, "shipping": 0}


func _card_count(player_state: Dictionary) -> int:
	var inventory: Dictionary = player_state.get("inventory", {}) if player_state.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	var count := 0
	for card_variant in slots:
		if card_variant is Dictionary:
			count += 1
	return count


func _same_player_resources(first: Dictionary, second: Dictionary) -> bool:
	return (
		int(first.get("revision", -1)) == int(second.get("revision", -2))
		and JSON.stringify(first.get("assets", {})) == JSON.stringify(second.get("assets", {}))
		and JSON.stringify(first.get("inventory", {})) == JSON.stringify(second.get("inventory", {}))
	)


func _receipt_binding_complete(receipt: Dictionary) -> bool:
	for key in BINDING_KEYS:
		if str(receipt.get(key, "")).strip_edges().is_empty():
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CARD_CORE_EFFECT_ADAPTERS_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("CARD_CORE_EFFECT_ADAPTERS_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
