extends Node

const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const PROFILE_PATH := "res://resources/rules/space_syndicate_ruleset_v06.tres"
const TRANSACTION_SERVICE_SCRIPT := preload("res://scripts/cards/v06/card_flow_transaction_service_v06.gd")
const FACILITY_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/effects/facility_card_effect_adapter_v06.gd")
const COMMODITY_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/effects/commodity_card_effect_adapter_v06.gd")
const INFRASTRUCTURE_SCRIPT := preload("res://scripts/runtime/region_infrastructure_runtime_controller.gd")
const COMMODITY_FLOW_SCRIPT := preload("res://scripts/runtime/commodity_flow_runtime_controller.gd")

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	var profile := load(PROFILE_PATH) as SpaceSyndicateRulesetProfileV06
	_check(catalog != null and bool(catalog.reload().get("valid", false)), "catalog")
	_check(profile != null, "profile")
	if catalog == null or profile == null:
		_finish()
		return
	var infrastructure: Node = INFRASTRUCTURE_SCRIPT.new()
	var flow: Node = COMMODITY_FLOW_SCRIPT.new()
	add_child(infrastructure)
	add_child(flow)
	var profile_snapshot := profile.debug_snapshot()
	_check(bool(infrastructure.call("configure", profile_snapshot).get("configured", false)), "infrastructure_config")
	_check(bool(flow.call("configure", profile_snapshot).get("configured", false)), "flow_config")
	_check(bool(infrastructure.call("initialize_regions", [{"region_id": "bench-region", "terrain_id": "temperate", "neighbor_region_ids": [], "legacy_index": 0}]).get("initialized", false)), "region_init")

	var actors := {"bench-syndicate": 0}
	var facility_adapter = FACILITY_ADAPTER_SCRIPT.new()
	var commodity_adapter = COMMODITY_ADAPTER_SCRIPT.new()
	_check(bool(facility_adapter.configure(infrastructure, actors).get("configured", false)), "facility_adapter")
	_check(bool(commodity_adapter.configure(flow, infrastructure, actors).get("configured", false)), "commodity_adapter")
	var service = TRANSACTION_SERVICE_SCRIPT.new(catalog)
	var assets := {"life": 1, "energy": 0, "industry": 0, "technology": 0, "commerce": 0, "shipping": 0}
	var cards := [catalog.card_snapshot("facility.factory.life.rank_1"), catalog.card_snapshot("commodity.star_dew_berry.rank_1")]
	_check(bool(service.register_player("bench-syndicate", {"revision": 0, "cash": 20, "assets": assets, "inventory": {"hand_limit": 5, "slots": cards}}).get("configured", false)), "player_register")
	var facility_target := {"valid": true, "target_kind": "region_unique_facility_slot", "region_id": "bench-region", "slot_id": "bench-region::factory.life", "industry_id": "life", "owner_player_index": 999}
	var facility_result: Dictionary = service.play_card("bench-syndicate", 0, facility_target, facility_adapter, 0, "bench-facility-tx")
	_check(bool(facility_result.get("committed", false)), "facility_play")
	var facilities: Array = infrastructure.call("facilities_snapshot", false)
	_check(facilities.size() == 1 and int((facilities[0] as Dictionary).get("owner_player_index", -1)) == 0, "facility_owner_mapping")
	var facility: Dictionary = facilities[0] if not facilities.is_empty() else {}
	var commodity_target := {"valid": true, "target_kind": "same_industry_factory_or_market", "facility_id": str(facility.get("facility_id", "")), "installer_player_index": 999}
	var commodity_result: Dictionary = service.play_card("bench-syndicate", 1, commodity_target, commodity_adapter, 1, "bench-commodity-tx")
	_check(bool(commodity_result.get("committed", false)), "commodity_play")
	var installations: Array = flow.call("installations_snapshot", false)
	_check(installations.size() == 1 and int((installations[0] as Dictionary).get("installer_player_index", -1)) == 0, "commodity_owner_mapping")
	var replay: Dictionary = service.play_card("bench-syndicate", 1, commodity_target, commodity_adapter, 1, "bench-commodity-tx")
	_check(bool(replay.get("idempotent_replay", false)) and (flow.call("installations_snapshot", false) as Array).size() == 1, "idempotent_replay")
	_finish()


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("CARD_CORE_EFFECT_ADAPTERS_V06_BENCH|status=PASS|checks=%d|failures=0|terminology=assets" % _checks)
		return
	print("CARD_CORE_EFFECT_ADAPTERS_V06_BENCH|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
