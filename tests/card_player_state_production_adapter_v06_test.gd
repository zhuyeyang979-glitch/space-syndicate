extends SceneTree

const ADAPTER_SCRIPT := preload("res://scripts/cards/v06/production/card_player_state_production_adapter_v06.gd")
const ASSET_CONTROLLER_SCRIPT := preload("res://scripts/runtime/player_mana_runtime_controller.gd")
const TRANSACTION_SERVICE_SCRIPT := preload("res://scripts/cards/v06/card_flow_transaction_service_v06.gd")
const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const PROFILE_PATH := "res://resources/rules/space_syndicate_ruleset_v06.tres"
const ASSET_IDS: Array[String] = ["life", "energy", "industry", "technology", "commerce", "shipping"]

var _checks := 0
var _failures: Array[String] = []


class TestWorld:
	extends Node
	var players: Array = []


class BoundEffectHandler:
	extends RefCounted
	var prepare_calls := 0
	var commit_calls := 0
	var rollback_calls := 0

	func prepare_effect(intent: Dictionary) -> Dictionary:
		prepare_calls += 1
		var result := intent.duplicate(true)
		result["prepared"] = true
		return result

	func commit_effect(prepared: Dictionary) -> Dictionary:
		commit_calls += 1
		var result := prepared.duplicate(true)
		result["committed"] = true
		return result

	func rollback_effect(_receipt: Dictionary) -> void:
		rollback_calls += 1

	func abort_prepared_effect(_prepared: Dictionary) -> void:
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog: Resource = load(CATALOG_PATH)
	_expect(catalog != null and bool(catalog.call("reload").get("valid", false)), "v0.6 catalog is ready")
	if catalog == null:
		_finish()
		return
	_verify_exact_delta_preserves_live_income_and_recovery(catalog)
	_verify_pre_effect_staging_and_abort(catalog)
	_verify_multi_player_atomic_commit_and_failure(catalog)
	_verify_exact_once_survives_save_load(catalog)
	_verify_missing_credit_api_fails_closed(catalog)
	_verify_transaction_service_uses_production_staging(catalog)
	_finish()


func _verify_exact_delta_preserves_live_income_and_recovery(catalog: Resource) -> void:
	var asset_owner := _asset_owner({0: _assets(3)})
	var card := _card(catalog, "facility.road.rank_1", "card:a:road:1")
	var world := TestWorld.new()
	world.players = [{"actor_id": "A", "cash": 10, "cash_cents": 1055, "slots": [card]}]
	var adapter = ADAPTER_SCRIPT.new()
	_expect(bool(adapter.configure(catalog, asset_owner).get("configured", false)), "production adapter configures against real asset owner API")
	_expect(bool(adapter.bind_world(world).get("bound", false)), "production adapter binds the existing world owner")
	var first := adapter.read_player("A")
	var first_state: Dictionary = first.get("player_state", {}) as Dictionary
	_expect(int(first_state.get("revision", -1)) == 0, "first production read starts a per-player revision")

	# PlayerMana's global revision advances, but no A balance changes.
	asset_owner.advance(1000, 1.0, {"0": {"colors": _zero_gdp()}})
	var after_empty_tick: Dictionary = adapter.read_player("A").get("player_state", {}) as Dictionary
	_expect(int(after_empty_tick.get("revision", -1)) == 0, "global asset tick revision is not reused as player revision")

	var reserved := adapter.reserve_transaction("tx-exact-delta", "intent-exact-delta", {"A": 0}, ["A"])
	_expect(bool(reserved.get("reserved", false)), "player state reserves before production mutation")
	var before: Dictionary = (reserved.get("before_snapshots", {}) as Dictionary).get("A", {}) as Dictionary
	var next := before.duplicate(true)
	next["cash"] = int(before.get("cash", 0)) - 4
	var next_assets: Dictionary = (before.get("assets", {}) as Dictionary).duplicate(true)
	next_assets["shipping"] = int(next_assets.get("shipping", 0)) - 1
	next["assets"] = next_assets
	var next_inventory: Dictionary = (before.get("inventory", {}) as Dictionary).duplicate(true)
	var next_slots: Array = (next_inventory.get("slots", []) as Array).duplicate(true)
	next_slots[0] = null
	next_inventory["slots"] = next_slots
	next["inventory"] = next_inventory

	# Income and shipping recovery happen while the card transaction is reserved.
	var live_players := world.players.duplicate(true)
	(live_players[0] as Dictionary)["cash"] = 15
	(live_players[0] as Dictionary)["cash_cents"] = 1555
	world.players = live_players
	var shipping_gdp := _zero_gdp()
	(shipping_gdp.get("shipping", {}) as Dictionary)["gdp_per_minute"] = 100
	asset_owner.advance(1000, 2.0, {"0": {"colors": shipping_gdp}})
	var prepared := adapter.prepare_reserved_mutations(str(reserved.get("reservation_id", "")), {"A": next})
	_expect(bool(prepared.get("prepared", false)) and int(prepared.get("asset_reservation_count", 0)) == 1, "asset debit is reserved before effect commit")
	var prepared_again := adapter.prepare_reserved_mutations(str(reserved.get("reservation_id", "")), {"A": next})
	_expect(bool(prepared_again.get("idempotent_replay", false)), "pre-effect mutation staging is idempotent")
	var receipt := {"committed": true, "transaction_id": "tx-exact-delta", "intent_hash": "intent-exact-delta"}
	var committed := adapter.commit_reserved(str(reserved.get("reservation_id", "")), {"A": next}, receipt)
	_expect(bool(committed.get("committed", false)), "staged production mutation commits")
	var after: Dictionary = adapter.read_player("A").get("player_state", {}) as Dictionary
	_expect(int(after.get("cash", -1)) == 11, "exact cash debit preserves income received during reservation")
	_expect(int((after.get("assets", {}) as Dictionary).get("shipping", -1)) == 3, "exact asset debit preserves recovery received during reservation")
	_expect(_card_count(after) == 0, "only the exact played card leaves the production hand")
	_expect(int((world.players[0] as Dictionary).get("cash_cents", -1)) == 1155, "whole-unit card debit preserves the authoritative fractional-cent remainder")
	var debug: Dictionary = adapter.debug_snapshot()
	_expect(not bool(debug.get("stores_inventory", true)) and not bool(debug.get("stores_cash", true)) and not bool(debug.get("stores_assets", true)), "adapter keeps no second resource truth")
	adapter.free()
	world.free()
	asset_owner.free()


func _verify_pre_effect_staging_and_abort(catalog: Resource) -> void:
	var asset_owner := _asset_owner({0: _assets(2)})
	var world := TestWorld.new()
	world.players = [{"actor_id": "A", "cash": 8, "slots": [_card(catalog, "facility.road.rank_1", "card:a:abort:1")]}]
	var adapter = ADAPTER_SCRIPT.new()
	adapter.configure(catalog, asset_owner)
	adapter.bind_world(world)
	var initial: Dictionary = adapter.read_player("A").get("player_state", {}) as Dictionary
	var reserved := adapter.reserve_transaction("tx-abort", "intent-abort", {"A": int(initial.get("revision", 0))}, ["A"])
	var next := initial.duplicate(true)
	var next_assets := (initial.get("assets", {}) as Dictionary).duplicate(true)
	next_assets["life"] = int(next_assets.get("life", 0)) - 1
	next["assets"] = next_assets
	var prepared := adapter.prepare_reserved_mutations(str(reserved.get("reservation_id", "")), {"A": next})
	_expect(bool(prepared.get("prepared", false)), "pre-effect stage reserves the exact asset mutation")
	var availability_during: Dictionary = asset_owner.availability_snapshot(0)
	_expect(int((availability_during.get("assets", {}) as Dictionary).get("life", -1)) == 1, "staging hides reserved assets from other actions")
	var aborted := adapter.abort_reserved(str(reserved.get("reservation_id", "")), "effect_prepare_failed")
	_expect(bool(aborted.get("aborted", false)), "aborting the card transaction releases staged mutations")
	var availability_after: Dictionary = asset_owner.availability_snapshot(0)
	_expect(int((availability_after.get("assets", {}) as Dictionary).get("life", -1)) == 2, "abort releases the asset reservation without consuming it")
	_expect(int(adapter.read_player("A").get("player_state", {}).get("cash", -1)) == 8 and _card_count(adapter.read_player("A").get("player_state", {}) as Dictionary) == 1, "abort leaves production cash and hand unchanged")
	adapter.free()
	world.free()
	asset_owner.free()


func _verify_multi_player_atomic_commit_and_failure(catalog: Resource) -> void:
	var asset_owner := _asset_owner({0: _assets(1), 1: _assets(1)})
	var stolen := _card(catalog, "commodity.ring_crystal_battery.rank_1", "card:b:ring:1")
	var world := TestWorld.new()
	world.players = [
		{"actor_id": "A", "cash": 5, "slots": []},
		{"actor_id": "B", "cash": 6, "slots": [stolen]},
	]
	var adapter = ADAPTER_SCRIPT.new()
	adapter.configure(catalog, asset_owner)
	adapter.bind_world(world)
	var a := adapter.read_player("A").get("player_state", {}) as Dictionary
	var b := adapter.read_player("B").get("player_state", {}) as Dictionary
	var reserved := adapter.reserve_transaction("tx-transfer", "intent-transfer", {"A": int(a.get("revision", 0)), "B": int(b.get("revision", 0))}, ["B", "A"])
	var next_a := a.duplicate(true)
	var next_b := b.duplicate(true)
	var a_inventory := (next_a.get("inventory", {}) as Dictionary).duplicate(true)
	var b_inventory := (next_b.get("inventory", {}) as Dictionary).duplicate(true)
	var a_slots := (a_inventory.get("slots", []) as Array).duplicate(true)
	var b_slots := (b_inventory.get("slots", []) as Array).duplicate(true)
	a_slots.append((b_slots[0] as Dictionary).duplicate(true))
	b_slots[0] = null
	a_inventory["slots"] = a_slots
	b_inventory["slots"] = b_slots
	next_a["inventory"] = a_inventory
	next_b["inventory"] = b_inventory
	var prepared := adapter.prepare_reserved_mutations(str(reserved.get("reservation_id", "")), {"A": next_a, "B": next_b})
	_expect(bool(prepared.get("prepared", false)), "two players stage as one mutation set")
	var committed := adapter.commit_reserved(str(reserved.get("reservation_id", "")), {"A": next_a, "B": next_b}, {"committed": true, "transaction_id": "tx-transfer", "intent_hash": "intent-transfer"})
	_expect(bool(committed.get("committed", false)), "two-player production mutation commits atomically")
	_expect(_card_count(adapter.read_player("A").get("player_state", {}) as Dictionary) == 1 and _card_count(adapter.read_player("B").get("player_state", {}) as Dictionary) == 0, "the same runtime card instance moves between existing owners")

	var a_after := adapter.read_player("A").get("player_state", {}) as Dictionary
	var b_after := adapter.read_player("B").get("player_state", {}) as Dictionary
	var failure_reservation := adapter.reserve_transaction("tx-atomic-fail", "intent-atomic-fail", {"A": int(a_after.get("revision", 0)), "B": int(b_after.get("revision", 0))}, ["A", "B"])
	var invalid_a := a_after.duplicate(true)
	var invalid_b := b_after.duplicate(true)
	invalid_a["cash"] = int(a_after.get("cash", 0)) + 3
	invalid_b["cash"] = 0
	# External debit makes B unable to apply the requested -6 exact delta.
	var live := world.players.duplicate(true)
	(live[1] as Dictionary)["cash"] = 2
	(live[1] as Dictionary)["cash_cents"] = 200
	world.players = live
	var failed := adapter.prepare_reserved_mutations(str(failure_reservation.get("reservation_id", "")), {"A": invalid_a, "B": invalid_b})
	_expect(str(failed.get("reason_code", "")) == "cash_insufficient", "one invalid participant rejects the full staged set")
	_expect(int((world.players[0] as Dictionary).get("cash", -1)) == 5, "failed multi-player prepare does not partially credit the first player")
	adapter.abort_reserved(str(failure_reservation.get("reservation_id", "")))
	adapter.free()
	world.free()
	asset_owner.free()


func _verify_exact_once_survives_save_load(catalog: Resource) -> void:
	var asset_owner := _asset_owner({0: _assets(0)})
	var world := TestWorld.new()
	world.players = [{"actor_id": "A", "cash": 9, "slots": [_card(catalog, "commodity.ring_crystal_battery.rank_1", "card:a:once:1")]}]
	var adapter = ADAPTER_SCRIPT.new()
	adapter.configure(catalog, asset_owner)
	adapter.bind_world(world)
	var state := adapter.read_player("A").get("player_state", {}) as Dictionary
	var reserved := adapter.reserve_transaction("tx-once", "intent-once", {"A": int(state.get("revision", 0))}, ["A"])
	var next := state.duplicate(true)
	next["cash"] = 7
	var committed := adapter.commit_reserved(str(reserved.get("reservation_id", "")), {"A": next}, {"committed": true, "transaction_id": "tx-once", "intent_hash": "intent-once"})
	_expect(bool(committed.get("committed", false)), "initial exact-once transaction commits")
	var saved: Dictionary = adapter.to_save_data()
	var restored = ADAPTER_SCRIPT.new()
	restored.configure(catalog, asset_owner)
	restored.bind_world(world)
	_expect(bool(restored.apply_save_data(saved).get("applied", false)), "production journal restores from save data")
	var replay := restored.reserve_transaction("tx-once", "intent-once", {"A": 0}, ["A"])
	_expect(bool(replay.get("committed", false)) and bool(replay.get("idempotent_replay", false)), "saved transaction replays without charging again")
	_expect(int((world.players[0] as Dictionary).get("cash", -1)) == 7, "save-load replay does not repeat the cash delta")
	adapter.free()
	restored.free()
	world.free()
	asset_owner.free()


func _verify_missing_credit_api_fails_closed(catalog: Resource) -> void:
	var asset_owner := _asset_owner({0: _assets(0)})
	var world := TestWorld.new()
	world.players = [{"actor_id": "A", "cash": 4, "slots": []}]
	var adapter = ADAPTER_SCRIPT.new()
	adapter.configure(catalog, asset_owner)
	adapter.bind_world(world)
	var state := adapter.read_player("A").get("player_state", {}) as Dictionary
	var reserved := adapter.reserve_transaction("tx-credit", "intent-credit", {"A": int(state.get("revision", 0))}, ["A"])
	var next := state.duplicate(true)
	var assets := (state.get("assets", {}) as Dictionary).duplicate(true)
	assets["technology"] = 1
	next["assets"] = assets
	var rejected := adapter.prepare_reserved_mutations(str(reserved.get("reservation_id", "")), {"A": next})
	_expect(str(rejected.get("reason_code", "")) == "asset_credit_owner_unavailable", "missing production credit hook fails closed")
	_expect(int((adapter.read_player("A").get("player_state", {}) as Dictionary).get("assets", {}).get("technology", -1)) == 0, "adapter never manufactures a second asset balance")
	var feedback: Dictionary = rejected.get("feedback", {}) as Dictionary
	_expect(not str(feedback.get("reason", "")).is_empty() and not str(feedback.get("next_step", "")).is_empty(), "fail-closed result includes localized reason and next step")
	_expect(not str(feedback.get("reason", "")).contains("mana") and not str(feedback.get("reason", "")).contains("法力"), "player feedback uses asset terminology only")
	adapter.abort_reserved(str(reserved.get("reservation_id", "")))
	adapter.free()
	world.free()
	asset_owner.free()


func _verify_transaction_service_uses_production_staging(catalog: Resource) -> void:
	var asset_owner := _asset_owner({0: _assets(2)})
	var world := TestWorld.new()
	world.players = [{"actor_id": "A", "cash": 10, "cash_cents": 1000, "slots": []}]
	var adapter = ADAPTER_SCRIPT.new()
	adapter.configure(catalog, asset_owner)
	adapter.bind_world(world)
	var service = TRANSACTION_SERVICE_SCRIPT.new(catalog, adapter)
	_expect(bool(service.register_player("A", {}).get("configured", false)), "transaction service registers through the production adapter")
	var warehouse: Dictionary = catalog.call("card_snapshot", "facility.orbital_warehouse.rank_2")
	service.configure_market(4, {"item_id": "market-warehouse", "card": warehouse, "price_cash": 7})
	var next_listing := {"item_id": "market-road", "card": catalog.call("card_snapshot", "facility.road.rank_1"), "price_cash": 3}
	var bought: Dictionary = service.purchase_market_card("A", "market-warehouse", next_listing, 0, 4, "tx-production-buy")
	_expect(bool(bought.get("committed", false)) and int((world.players[0] as Dictionary).get("cash", -1)) == 3, "market purchase uses lazy exact-delta prepare and debits production cash once")
	var bought_state: Dictionary = service.player_snapshot("A")
	var target := {
		"valid": true,
		"target_kind": "region_unique_facility_slot",
		"target_id": "warehouse-slot-production",
		"generic_asset_allocation": {"shipping": 2},
	}
	var handler := BoundEffectHandler.new()
	var played: Dictionary = service.play_card("A", 0, target, handler, int(bought_state.get("revision", -1)), "tx-production-play")
	_expect(bool(played.get("committed", false)), "effect card commits through pre-effect production mutation staging")
	_expect(handler.prepare_calls == 1 and handler.commit_calls == 1 and handler.rollback_calls == 0, "effect commit runs once after state mutation staging succeeds")
	var after: Dictionary = service.player_snapshot("A")
	_expect(_card_count(after) == 0 and int((after.get("assets", {}) as Dictionary).get("shipping", -1)) == 0, "production play consumes the exact card and selected coloured asset")
	var replay: Dictionary = service.play_card("A", 0, target, handler, int(bought_state.get("revision", -1)), "tx-production-play")
	_expect(bool(replay.get("idempotent_replay", false)) and handler.commit_calls == 1, "production transaction replay does not repeat effect or asset debit")
	adapter.free()
	world.free()
	asset_owner.free()


func _asset_owner(balances_by_player: Dictionary) -> Node:
	var controller = ASSET_CONTROLLER_SCRIPT.new()
	var profile: Resource = load(PROFILE_PATH)
	controller.configure(profile.call("debug_snapshot"))
	var pools: Dictionary = {}
	var remainders: Dictionary = {}
	for player_key_variant in balances_by_player.keys():
		var key := str(int(player_key_variant))
		var assets: Dictionary = balances_by_player.get(player_key_variant, {}) as Dictionary
		var pool_row: Dictionary = {}
		var remainder_row: Dictionary = {}
		for asset_id in ASSET_IDS:
			pool_row[asset_id] = int(assets.get(asset_id, 0)) * 1000
			remainder_row[asset_id] = 0
		pools[key] = pool_row
		remainders[key] = remainder_row
	var applied := controller.apply_save_data({
		"state_version": 1,
		"ruleset_id": "v0.6",
		"current_game_time": 0.0,
		"revision": 1,
		"pools_by_player": pools,
		"recovery_remainders_by_player": remainders,
		"reservations": {},
		"terminal_receipts": {},
	})
	_expect(bool(applied.get("applied", false)), "real asset owner fixture loads balances")
	return controller


func _card(catalog: Resource, card_id: String, instance_id: String) -> Dictionary:
	var card: Dictionary = catalog.call("card_snapshot", card_id)
	card["runtime_instance_id"] = instance_id
	return card


func _assets(value: int) -> Dictionary:
	var result: Dictionary = {}
	for asset_id in ASSET_IDS:
		result[asset_id] = value
	return result


func _zero_gdp() -> Dictionary:
	var result: Dictionary = {}
	for asset_id in ASSET_IDS:
		result[asset_id] = {"gdp_per_minute": 0}
	return result


func _card_count(state: Dictionary) -> int:
	var inventory: Dictionary = state.get("inventory", {}) as Dictionary
	var count := 0
	for slot_variant in inventory.get("slots", []) as Array:
		if slot_variant is Dictionary:
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CARD_PLAYER_STATE_PRODUCTION_ADAPTER_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("CARD_PLAYER_STATE_PRODUCTION_ADAPTER_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
