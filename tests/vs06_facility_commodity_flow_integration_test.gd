extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const QA_SAVE_PATH := "user://space_syndicate_design_qa/test_runs/vs06_facility_commodity_flow.save"
const PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const CATALOG := preload("res://resources/cards/runtime/card_runtime_catalog_v06.tres")
const INFRASTRUCTURE_SCRIPT := preload("res://scripts/runtime/region_infrastructure_runtime_controller.gd")
const FLOW_SCRIPT := preload("res://scripts/runtime/commodity_flow_runtime_controller.gd")
const INVENTORY_SCENE := preload("res://scenes/runtime/CommodityCardInventoryRuntimeController.tscn")
const STATE_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/production/card_player_state_production_adapter_v06.gd")
const ASSET_CONTROLLER_SCRIPT := preload("res://scripts/runtime/player_mana_runtime_controller.gd")
const CORE_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/production/core_economic_card_runtime_adapter_v06.gd")

var _checks := 0
var _failures: Array[String] = []


class RuntimeWorld:
	extends Node
	var players: Array = []


class RegionFactsPort:
	extends RefCounted
	var owner: Object

	func _init(infrastructure_owner: Object) -> void:
		owner = infrastructure_owner

	func region_commodity_facts(region_id: String) -> Dictionary:
		var region: Dictionary = owner.call("region_snapshot", region_id)
		return {
			"available": not region.is_empty(),
			"authoritative": not region.is_empty(),
			"reason_code": "available" if not region.is_empty() else "region_not_found",
			"region_id": region_id,
			"region_revision": int(region.get("revision", 0)),
			"production_products": [{"product_id": "星露莓", "industry_id": "life"}],
			"demand_products": [],
			"facts_fingerprint": "facts:region.atomic:life:star-dew",
		}


class FlakyFinalizeInfrastructurePort:
	extends Node
	var target: Object
	var finalize_attempts := 0

	func _init(infrastructure_owner: Object) -> void:
		target = infrastructure_owner

	func region_snapshot(region_id: String) -> Dictionary:
		return target.call("region_snapshot", region_id)

	func facilities_snapshot(include_tombstones := false) -> Array:
		return target.call("facilities_snapshot", include_tombstones)

	func slot_id(region_id: String, facility_type: String, industry_id := "") -> String:
		return str(target.call("slot_id", region_id, facility_type, industry_id))

	func apply_facility_action(request: Dictionary) -> Dictionary:
		return target.call("apply_facility_action", request)

	func rollback_facility_action(receipt: Variant) -> Dictionary:
		return target.call("rollback_facility_action", receipt)

	func finalize_facility_action(receipt: Variant) -> Dictionary:
		finalize_attempts += 1
		if finalize_attempts == 1:
			return {
				"finalized": false,
				"rollback_open": true,
				"reason_code": "injected_facility_finalize_failure",
				"transaction_id": str((receipt as Dictionary).get("transaction_id", "")) if receipt is Dictionary else str(receipt),
			}
		return target.call("finalize_facility_action", receipt)

	func facility_action_lifecycle_snapshot(transaction_id := "") -> Dictionary:
		return target.call("facility_action_lifecycle_snapshot", transaction_id)

	func facility_action_checkpoint_status() -> Dictionary:
		return target.call("facility_action_checkpoint_status")

	func facility_rollback_atomic_ready() -> bool:
		return bool(target.call("facility_rollback_atomic_ready"))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_composite_finalize_failure_is_retryable()
	await _verify_real_main_facility_income_chain()
	_finish()


func _verify_composite_finalize_failure_is_retryable() -> void:
	var infrastructure := INFRASTRUCTURE_SCRIPT.new()
	var flow := FLOW_SCRIPT.new()
	root.add_child(infrastructure)
	root.add_child(flow)
	_expect(bool(infrastructure.call("configure", PROFILE.debug_snapshot()).get("configured", false)), "fault fixture infrastructure configures")
	_expect(bool(flow.call("configure", PROFILE.debug_snapshot()).get("configured", false)), "fault fixture flow configures")
	_expect(bool(infrastructure.call("initialize_regions", [{
		"region_id": "region.atomic",
		"terrain_id": "land",
		"neighbor_region_ids": [],
		"legacy_index": 0,
	}]).get("initialized", false)), "fault fixture region initializes")
	var flaky := FlakyFinalizeInfrastructurePort.new(infrastructure)
	root.add_child(flaky)
	var facts := RegionFactsPort.new(infrastructure)
	var card: Dictionary = CATALOG.card_snapshot("facility.factory.life.rank_1")
	card["runtime_instance_id"] = "vs06-a6:atomic-card"
	_expect(not card.is_empty(), "canonical rank-I life factory exists")
	var assets := ASSET_CONTROLLER_SCRIPT.new()
	root.add_child(assets)
	assets.call("configure", PROFILE.debug_snapshot())
	var state := STATE_ADAPTER_SCRIPT.new()
	root.add_child(state)
	state.call("configure", CATALOG, assets)
	var world := RuntimeWorld.new()
	world.players = [{"id": 0, "actor_id": "A", "name": "Player A", "cash": 20, "cash_cents": 2000, "slots": [card]}]
	root.add_child(world)
	state.call("bind_world", world)
	var inventory := INVENTORY_SCENE.instantiate()
	root.add_child(inventory)
	_expect(bool(inventory.call("configure", PROFILE.debug_snapshot(), state, flow, flaky).get("configured", false)), "real Inventory/CardFlow boundary configures for the composite fixture")
	inventory.call("bind_world", world)
	var core := CORE_ADAPTER_SCRIPT.new()
	root.add_child(core)
	var configured: Dictionary = core.call("configure", inventory, flow, flaky, {"A": 0}, facts)
	_expect(bool(configured.get("configured", false)) and bool(configured.get("facility_product_installation_ready", false)), "composite facility path requires both lifecycle preflights")
	var before: Dictionary = inventory.call("player_snapshot", "A")
	var target := {
		"valid": true,
		"target_kind": "region_unique_facility_slot",
		"region_id": "region.atomic",
		"slot_id": "region.atomic::factory.life",
		"industry_id": "life",
		"game_time": 1.0,
	}
	var result: Dictionary = core.call("play_card", "A", 0, target, int(before.get("revision", -1)), "vs06-a6:atomic-finalize")
	var finalization: Dictionary = result.get("effect_finalization", {}) if result.get("effect_finalization", {}) is Dictionary else {}
	var flow_save: Dictionary = flow.call("to_save_data")
	var flow_receipts: Dictionary = flow_save.get("installation_transaction_receipts", {}) if flow_save.get("installation_transaction_receipts", {}) is Dictionary else {}
	var commodity_receipt: Dictionary = flow_receipts.get("vs06-a6:atomic-finalize:commodity-production", {}) if flow_receipts.get("vs06-a6:atomic-finalize:commodity-production", {}) is Dictionary else {}
	_expect(bool(result.get("committed", false)) and not bool(finalization.get("finalized", true)), "real Inventory/CardFlow preserves a failed composite finalization instead of unwrapping its facility receipt")
	var owner_finalization: Dictionary = finalization.get("owner_result", {}) if finalization.get("owner_result", {}) is Dictionary else {}
	_expect(bool(owner_finalization.get("composite_receipt_preserved", false)), "outer transaction boundary marks the composite receipt as indivisible")
	_expect(bool(commodity_receipt.get("rollback_open", false)) and not bool(commodity_receipt.get("finalized", true)), "facility finalize failure does not close the commodity rollback window")
	_expect(str(infrastructure.call("facility_action_lifecycle_snapshot", "vs06-a6:atomic-finalize").get("state", "")) == "applied", "facility owner remains applied and retryable")
	var retried: Dictionary = core.call("play_card", "A", 0, target, int(before.get("revision", -1)), "vs06-a6:atomic-finalize")
	flow_save = flow.call("to_save_data")
	flow_receipts = flow_save.get("installation_transaction_receipts", {}) if flow_save.get("installation_transaction_receipts", {}) is Dictionary else {}
	commodity_receipt = flow_receipts.get("vs06-a6:atomic-finalize:commodity-production", {}) if flow_receipts.get("vs06-a6:atomic-finalize:commodity-production", {}) is Dictionary else {}
	var retried_finalization: Dictionary = retried.get("effect_finalization", {}) if retried.get("effect_finalization", {}) is Dictionary else {}
	_expect(bool(retried.get("idempotent_replay", false)) and bool(retried_finalization.get("finalized", false)) and flaky.finalize_attempts == 2, "same outer transaction retries composite finalization without repeating mutations")
	_expect(bool(commodity_receipt.get("finalized", false)) and not bool(commodity_receipt.get("rollback_open", true)), "successful retry closes the commodity rollback window")
	_expect(str(infrastructure.call("facility_action_lifecycle_snapshot", "vs06-a6:atomic-finalize").get("state", "")) == "finalized", "successful retry closes the facility rollback window")
	_expect((infrastructure.call("facilities_snapshot", false) as Array).size() == 1 and (flow.call("installations_snapshot", false) as Array).size() == 1, "retry creates neither a second facility nor a second commodity installation")
	infrastructure.queue_free()
	flow.queue_free()
	assets.queue_free()
	state.queue_free()
	world.queue_free()
	inventory.queue_free()
	core.queue_free()
	flaky.queue_free()


func _verify_real_main_facility_income_chain() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "main scene loads")
	if packed == null:
		return
	var main := packed.instantiate()
	var save := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	_expect(save != null and bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)), "real-main QA save path is isolated")
	root.add_child(main)
	await _wait_frames(8)
	main.set("configured_player_count", 3)
	main.set("configured_ai_player_count", 2)
	main.set("configured_roguelike_depth", 1)
	main.set("configured_role_indices", [0, 1, 2])
	main.set("configured_starter_monster_indices", [0, 1, 2])
	main.call("_open_new_game_setup_menu")
	await _wait_frames(2)
	main.call("_on_new_game_setup_action_requested", "setup_start")
	await _wait_frames(10)
	main.set_process(false)

	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	_expect(coordinator != null, "real production Coordinator is composed")
	if coordinator == null:
		main.queue_free()
		await process_frame
		return
	var infrastructure: Object = coordinator.call("region_infrastructure_runtime_controller")
	var flow: Object = coordinator.call("commodity_flow_runtime_controller")
	_expect(infrastructure != null and flow != null, "real infrastructure and CommodityFlow owners are reachable")
	var before_cardinality_infrastructure := JSON.stringify(infrastructure.call("to_save_data"))
	var before_cardinality_flow := JSON.stringify(flow.call("to_save_data"))
	var cardinality_reject: Dictionary = coordinator.call("_bootstrap_v06_public_demand_group", infrastructure, flow, {
		"region_id": "region.cardinality-guard",
		"industry_id": "life",
		"products": ["星露莓", "轨道盆景"],
	})
	_expect(str(cardinality_reject.get("reason_code", "")) == "public_demand_group_cardinality_unsupported", "multi-product public demand group fails closed before owner mutation")
	_expect(before_cardinality_infrastructure == JSON.stringify(infrastructure.call("to_save_data")) and before_cardinality_flow == JSON.stringify(flow.call("to_save_data")), "multi-product rejection leaves both owner journals and revisions unchanged")

	var players: Array = main.get("players") if main.get("players") is Array else []
	var actor_id := str((players[0] as Dictionary).get("actor_id", "player.0")) if not players.is_empty() and players[0] is Dictionary else ""
	var district := int(main.call("_first_run_recommended_start_district", 0))
	main.call("_select_district", district)
	coordinator.call("refresh_v06_production_player_bindings", main)
	var public_demands := _installations(flow, "demand", "public")
	_expect(not public_demands.is_empty(), "map demand facts bootstrap neutral public demand installations")
	var stable_refresh_before := JSON.stringify({"infrastructure": infrastructure.call("to_save_data"), "flow": flow.call("to_save_data")})
	main.set("game_time", 91.0)
	var repeated_refresh: Dictionary = coordinator.call("refresh_v06_production_player_bindings", main)
	_expect(bool(repeated_refresh.get("public_demand_ready", false)), "public demand bootstrap replays after world time advances")
	_expect(stable_refresh_before == JSON.stringify({"infrastructure": infrastructure.call("to_save_data"), "flow": flow.call("to_save_data")}), "stable public-demand transaction IDs do not bind changing world time")
	var market_surface: Dictionary = coordinator.call("v06_first_table_facility_market_snapshot", actor_id)
	var listing: Dictionary = market_surface.get("listing", {}) if market_surface.get("listing", {}) is Dictionary else {}
	var purchase: Dictionary = coordinator.call("purchase_v06_first_table_facility_card", actor_id, str(listing.get("item_id", "")), "vs06-a6:purchase")
	_expect(bool(purchase.get("committed", false)), "canonical matching rank-I facility is purchased")
	var player_before_play: Dictionary = coordinator.call("v06_card_player_snapshot", actor_id)
	var slot_index := _find_card_slot(player_before_play, str(purchase.get("card_id", "")))
	var region_id := _selected_region_id(main, district)
	var play_request := {
		"actor_id": actor_id,
		"slot_index": slot_index,
		"transaction_id": "vs06-a6:facility-play",
		"region_id": region_id,
		"game_time": float(main.get("game_time")),
	}
	var facilities_before := (infrastructure.call("facilities_snapshot", false) as Array).size()
	var play: Dictionary = coordinator.call("play_v06_runtime_card", play_request)
	var finalization_result: Dictionary = play.get("effect_finalization", {}) if play.get("effect_finalization", {}) is Dictionary else {}
	_expect(bool(play.get("committed", false)) and bool(finalization_result.get("finalized", false)), "facility card commits and finalizes both permanent owners")
	_expect((infrastructure.call("facilities_snapshot", false) as Array).size() == facilities_before + 1, "facility card creates exactly one real factory")
	var productions := _installations(flow, "production", "player")
	var production: Dictionary = productions.back() if not productions.is_empty() else {}
	var product_id := str(production.get("commodity_id", ""))
	_expect(not product_id.is_empty(), "factory production is bound to an authoritative region product")
	var map_matching_demand := _matching_installation_count(public_demands, product_id) > 0
	if not map_matching_demand:
		var oracle_demand: Dictionary = coordinator.call("_bootstrap_v06_public_demand_group", infrastructure, flow, {
			"region_id": str(production.get("region_id", "")),
			"industry_id": str(production.get("color", "")),
			"products": [product_id],
		})
		_expect(bool(oracle_demand.get("ready", false)), "test oracle can add one neutral demand endpoint through the same authoritative owners")
		public_demands = _installations(flow, "demand", "public")
	_expect(_matching_installation_count(public_demands, product_id) > 0, "permanent production has one exact-product public demand for the flow oracle")
	print("VS06_A6_MAP_MATCH|authoritative_map_match=%s|product=%s" % [map_matching_demand, product_id])

	var receipts_before: Array = flow.call("recent_sale_receipts_snapshot", 0)
	var cash_before := _player_cash_cents(main, 0)
	var ledger_before := _player_ledger(main, 0).size()
	var first_five_receipts := 0
	var sixth_result: Dictionary = {}
	for second in range(1, 7):
		main.set("game_time", float(second))
		var tick: Dictionary = flow.call("advance_world", 1.0, {})
		if second <= 5:
			first_five_receipts += int(tick.get("receipt_count", 0))
		else:
			sixth_result = tick
	_expect(first_five_receipts == 0, "rank-I ten-units-per-minute factory produces no sale in the first five seconds")
	_expect(int(sixth_result.get("receipt_count", 0)) == 1, "the sixth one-second tick commits exactly one Sale Receipt")
	var receipts_after: Array = flow.call("recent_sale_receipts_snapshot", 0)
	_expect(receipts_after.size() == receipts_before.size() + 1, "CommodityFlow ledger gains exactly one receipt")
	var receipt: Dictionary = receipts_after.back() if not receipts_after.is_empty() else {}
	var cash_after := _player_cash_cents(main, 0)
	var new_ledger := _player_ledger(main, 0).slice(ledger_before)
	var receipt_ledger_delta := _ledger_delta_for_receipt(new_ledger, str(receipt.get("receipt_id", "")))
	_expect(cash_after - cash_before == receipt_ledger_delta and receipt_ledger_delta == int(receipt.get("owner_net_cash", 0)), "cash changes only by the exact owner ledger delta from the Sale Receipt")
	var gdp: Dictionary = flow.call("region_gdp_snapshot", str(receipt.get("market_region_id", "")))
	_expect(int(gdp.get("region_gdp_per_minute_cents", 0)) > 0, "real Sale Receipt produces positive region GDP")
	var production_count := productions.size()
	var facility_count_before_replay := (infrastructure.call("facilities_snapshot", false) as Array).size()
	var replay: Dictionary = coordinator.call("play_v06_runtime_card", play_request)
	_expect(bool(replay.get("committed", false)) and bool(replay.get("idempotent_replay", false)), "consumed facility card replays from the single Inventory/CardFlow journal")
	_expect(_installations(flow, "production", "player").size() == production_count and (infrastructure.call("facilities_snapshot", false) as Array).size() == facility_count_before_replay, "facility replay duplicates neither factory nor permanent production")
	_expect((flow.call("recent_sale_receipts_snapshot", 0) as Array).size() == receipts_after.size() and _player_cash_cents(main, 0) == cash_after, "transaction replay does not create a second sale or cash mutation")
	main.queue_free()
	await process_frame


func _installations(flow: Object, direction: String, owner_kind: String) -> Array:
	var result: Array = []
	for value in flow.call("installations_snapshot", false):
		if value is Dictionary and str(value.get("direction", "")) == direction and str(value.get("owner_kind", "")) == owner_kind:
			result.append((value as Dictionary).duplicate(true))
	return result


func _matching_installation_count(rows: Array, product_id: String) -> int:
	var count := 0
	for value in rows:
		if value is Dictionary and str(value.get("commodity_id", "")) == product_id:
			count += 1
	return count


func _find_card_slot(player: Dictionary, card_id: String) -> int:
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_index in range(slots.size()):
		if slots[slot_index] is Dictionary:
			var machine: Dictionary = slots[slot_index].get("machine", {}) if slots[slot_index].get("machine", {}) is Dictionary else {}
			if str(machine.get("card_id", "")) == card_id:
				return slot_index
	return -1


func _selected_region_id(main: Node, district: int) -> String:
	var districts: Array = main.get("districts") if main.get("districts") is Array else []
	if district < 0 or district >= districts.size() or not (districts[district] is Dictionary):
		return ""
	return str((districts[district] as Dictionary).get("region_id", "region.%03d" % district))


func _player_cash_cents(main: Node, player_index: int) -> int:
	var players: Array = main.get("players") if main.get("players") is Array else []
	var player: Dictionary = players[player_index] if player_index >= 0 and player_index < players.size() and players[player_index] is Dictionary else {}
	return int(player.get("cash_cents", int(player.get("cash", 0)) * 100))


func _player_ledger(main: Node, player_index: int) -> Array:
	var players: Array = main.get("players") if main.get("players") is Array else []
	var player: Dictionary = players[player_index] if player_index >= 0 and player_index < players.size() and players[player_index] is Dictionary else {}
	return (player.get("v06_transaction_ledger", []) as Array).duplicate(true) if player.get("v06_transaction_ledger", []) is Array else []


func _ledger_delta_for_receipt(rows: Array, receipt_id: String) -> int:
	var total := 0
	for value in rows:
		if value is Dictionary and str(value.get("transaction_id", "")) == receipt_id:
			total += int(value.get("ledger_delta_cents", 0))
	return total


func _wait_frames(count: int) -> void:
	for _index in range(maxi(0, count)):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print("VS06_FACILITY_COMMODITY_FLOW_INTEGRATION_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(_failures.size())
