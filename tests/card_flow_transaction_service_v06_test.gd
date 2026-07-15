extends SceneTree

const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const SERVICE_SCRIPT := preload("res://scripts/cards/v06/card_flow_transaction_service_v06.gd")
const STATE_PORT_SCRIPT := preload("res://scripts/cards/v06/card_player_state_port_v06.gd")
const QUOTE_AUTHORITY_FIXTURE_SCRIPT := preload("res://scripts/tools/card_market_quote_authority_fixture.gd")

var _failures: Array[String] = []
var _checks := 0


class BoundEffectHandler:
	extends RefCounted

	var prepare_calls := 0
	var commit_calls := 0
	var abort_calls := 0
	var rollback_calls := 0
	var fail_prepare := false
	var fail_commit := false
	var corrupt_prepare_field := ""
	var corrupt_commit_field := ""
	var rollback_succeeds := true

	func prepare_effect(intent: Dictionary) -> Dictionary:
		prepare_calls += 1
		var receipt := intent.duplicate(true)
		receipt["prepared"] = not fail_prepare
		receipt["handler_token"] = "prepared-%d" % prepare_calls
		if not corrupt_prepare_field.is_empty():
			receipt[corrupt_prepare_field] = "corrupt"
		return receipt

	func commit_effect(prepared: Dictionary) -> Dictionary:
		commit_calls += 1
		var receipt := prepared.duplicate(true)
		receipt["committed"] = not fail_commit
		if not corrupt_commit_field.is_empty():
			receipt[corrupt_commit_field] = "corrupt"
		return receipt

	func abort_prepared_effect(_prepared: Dictionary) -> void:
		abort_calls += 1

	func rollback_effect(_receipt: Dictionary) -> Dictionary:
		rollback_calls += 1
		return {
			"rolled_back": rollback_succeeds,
			"committed": false,
			"reason_code": "rolled_back" if rollback_succeeds else "simulated_owner_rollback_failure",
		}


class CommitRejectingStatePort:
	extends RefCounted

	var inner: Object
	var commit_calls := 0

	func _init(state_port: Object) -> void:
		inner = state_port

	func register_player(actor_id: String, initial_state: Dictionary) -> Dictionary:
		return inner.call("register_player", actor_id, initial_state) as Dictionary

	func read_player(actor_id: String) -> Dictionary:
		return inner.call("read_player", actor_id) as Dictionary

	func reserve_transaction(transaction_id: String, intent_hash: String, expected_revisions: Dictionary, actor_ids: Array) -> Dictionary:
		return inner.call("reserve_transaction", transaction_id, intent_hash, expected_revisions, actor_ids) as Dictionary

	func commit_reserved(_reservation_id: String, _next_states: Dictionary, _effect_receipt: Dictionary) -> Dictionary:
		commit_calls += 1
		return {"committed": false, "reason_code": "player_revision_changed"}

	func abort_reserved(reservation_id: String, reason_code: String = "reservation_aborted") -> Dictionary:
		return inner.call("abort_reserved", reservation_id, reason_code) as Dictionary

	func replay_result(transaction_id: String, intent_hash: String) -> Dictionary:
		return inner.call("replay_result", transaction_id, intent_hash) as Dictionary


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	_expect(catalog != null and bool(catalog.reload().get("valid", false)), "catalog is ready")
	if catalog == null:
		_finish()
		return
	_verify_belt_concurrency_and_full_hand_merge(catalog)
	_verify_market_atomic_refresh_and_journal(catalog)
	_verify_authoritative_manual_merge(catalog)
	_verify_effect_two_phase_success(catalog)
	_verify_effect_receipt_and_rollback(catalog)
	_verify_injected_state_port_and_cross_player_lock(catalog)
	_verify_effect_rollback_when_state_port_commit_fails(catalog)
	_verify_effect_compensation_failure_is_honest(catalog)
	_finish()


func _verify_belt_concurrency_and_full_hand_merge(catalog: CardRuntimeCatalogV06Resource) -> void:
	var service = SERVICE_SCRIPT.new(catalog)
	var ring := catalog.card_snapshot("commodity.ring_crystal_battery.rank_1")
	var full_cards := [
		ring,
		catalog.card_snapshot("commodity.star_dew_berry.rank_1"),
		catalog.card_snapshot("facility.road.rank_1"),
		catalog.card_snapshot("interaction.phase_veto.rank_1"),
		catalog.card_snapshot("unit.monster.spore_tide_emperor.rank_1"),
	]
	_expect(bool(service.register_player("A", _state(full_cards, 0)).get("configured", false)), "player A registered")
	_expect(bool(service.register_player("B", _state([], 0)).get("configured", false)), "player B registered")
	_expect(bool(service.configure_belt(7, [{"item_id": "belt-ring-1", "card": ring, "visible_actor_ids": ["A", "B"]}]).get("configured", false)), "belt configured")
	var first := service.claim_belt_card("A", "belt-ring-1", 0, 7, "tx-belt-race-a")
	_expect(bool(first.get("committed", false)), "first claimant commits")
	var first_player: Dictionary = first.get("player_state", {}) if first.get("player_state", {}) is Dictionary else {}
	_expect(_card_count(first_player) == 5, "full-hand automatic merge keeps five cards")
	_expect(_family_rank_count(first_player, "commodity.ring_crystal_battery", 2) == 1, "full-hand claim produces one rank-II card")
	var second := service.claim_belt_card("B", "belt-ring-1", 0, 7, "tx-belt-race-b")
	_expect(not bool(second.get("committed", true)) and str(second.get("reason_code", "")) == "source_revision_changed", "second claimant cannot take the consumed belt item")
	_expect(_card_count(service.player_snapshot("B")) == 0, "losing claimant state is unchanged")
	_expect_feedback(second, "belt race rejection")
	var replay := service.claim_belt_card("A", "belt-ring-1", 0, 7, "tx-belt-race-a")
	_expect(bool(replay.get("committed", false)) and bool(replay.get("idempotent_replay", false)), "same belt intent replays its recorded result")
	_expect(int(service.belt_snapshot().get("revision", -1)) == 8, "idempotent replay does not advance belt twice")
	var collision := service.claim_belt_card("A", "different-item", 0, 7, "tx-belt-race-a")
	_expect(not bool(collision.get("committed", true)) and str(collision.get("reason_code", "")) == "transaction_intent_collision", "same transaction id with another belt intent is rejected")


func _verify_market_atomic_refresh_and_journal(catalog: CardRuntimeCatalogV06Resource) -> void:
	var quote_authority = QUOTE_AUTHORITY_FIXTURE_SCRIPT.new()
	var unmapped_service = SERVICE_SCRIPT.new(catalog, null, quote_authority)
	var service = SERVICE_SCRIPT.new(catalog, null, quote_authority)
	var warehouse := catalog.card_snapshot("facility.orbital_warehouse.rank_1")
	var road := catalog.card_snapshot("facility.road.rank_1")
	var seaport := catalog.card_snapshot("facility.seaport.rank_1")
	var warehouse_listing := _market_listing("market-warehouse-1", warehouse, 4, "supply-warehouse-1")
	var next_listing := _market_listing("market-road-1", road, 3, "supply-road-1")
	unmapped_service.register_player("unmapped", _state([], 10))
	unmapped_service.configure_market(3, warehouse_listing)
	var unmapped_quote: Dictionary = quote_authority.issue_quote(0, 0, "facility.orbital_warehouse.rank_1", "supply-warehouse-1", 4)
	var unmapped := unmapped_service.purchase_market_card("unmapped", "market-warehouse-1", next_listing, 0, 3, "tx-market-unmapped", unmapped_quote)
	_expect(str(unmapped.get("reason_code", "")) == "market_quote_binding_mismatch" and int(unmapped_service.player_snapshot("unmapped").get("cash", -1)) == 10, "market purchase fails closed when the actor has no explicit authoritative player index")
	service.register_player("A", _state([], 10, {}, 0, 0))
	service.register_player("B", _state([], 10, {}, 0, 1))
	var next_next := _market_listing("market-seaport-2", seaport, 2, "supply-seaport-2")
	service.configure_market(3, warehouse_listing)
	var quote_a: Dictionary = quote_authority.issue_quote(0, 0, "facility.orbital_warehouse.rank_1", "supply-warehouse-1", 4)
	var quote_b: Dictionary = quote_authority.issue_quote(1, 0, "facility.orbital_warehouse.rank_1", "supply-warehouse-1", 4)
	var missing_quote := service.purchase_market_card("A", "market-warehouse-1", next_listing, 0, 3, "tx-market-missing-quote", {})
	_expect(str(missing_quote.get("reason_code", "")) == "market_quote_request_invalid" and int(service.player_snapshot("A").get("cash", -1)) == 10, "market purchase without an authority quote fails closed")
	var forged_quote := quote_a.duplicate(true)
	forged_quote["player_index"] = 1
	var forged := service.purchase_market_card("A", "market-warehouse-1", next_listing, 0, 3, "tx-market-forged-quote", forged_quote)
	_expect(str(forged.get("reason_code", "")) == "market_quote_unauthorized" and int(service.player_snapshot("A").get("cash", -1)) == 10, "forged quote binding cannot debit or receive a card")
	var stale := service.purchase_market_card("A", "market-warehouse-1", next_listing, 0, 2, "tx-market-stale", quote_a)
	_expect(not bool(stale.get("committed", true)) and str(stale.get("reason_code", "")) == "source_revision_changed", "old market revision is rejected")
	_expect_feedback(stale, "old market revision")
	var bought := service.purchase_market_card("A", "market-warehouse-1", next_listing, 0, 3, "tx-market-buy-1", quote_a)
	_expect(bool(bought.get("committed", false)) and bool(bought.get("market_refreshed", false)), "market purchase and refresh commit together")
	var market_after := service.market_snapshot()
	var listing_after: Dictionary = market_after.get("listing", {}) if market_after.get("listing", {}) is Dictionary else {}
	_expect(int(market_after.get("revision", -1)) == 4 and str(listing_after.get("item_id", "")) == "market-road-1", "next listing is installed in the same transaction")
	_expect(int(service.player_snapshot("A").get("cash", -1)) == 6, "market cash is debited exactly once")
	_expect(int(service.player_snapshot("A").get("card_purchase_count", -1)) == 1 and int(service.player_snapshot("A").get("total_card_spend", -1)) == 4, "market purchase records count and locked spend exactly once")
	var competing := service.purchase_market_card("B", "market-warehouse-1", next_listing, 0, 3, "tx-market-competing", quote_b)
	_expect(str(competing.get("reason_code", "")) == "source_revision_changed" and _card_count(service.player_snapshot("B")) == 0, "a second player cannot buy the replaced market listing")
	var replay := service.purchase_market_card("A", "market-warehouse-1", next_listing, 0, 3, "tx-market-buy-1", quote_a)
	_expect(bool(replay.get("committed", false)) and bool(replay.get("idempotent_replay", false)), "market transaction replay returns the journaled success")
	_expect(int(service.market_snapshot().get("revision", -1)) == 4 and int(service.player_snapshot("A").get("cash", -1)) == 6 and int(service.player_snapshot("A").get("card_purchase_count", -1)) == 1 and int(service.player_snapshot("A").get("total_card_spend", -1)) == 4, "market replay neither refreshes, charges, nor records spend twice")
	var changed_next := _market_listing("market-seaport-1", seaport, 2, "supply-seaport-1")
	var collision := service.purchase_market_card("A", "market-warehouse-1", changed_next, 0, 3, "tx-market-buy-1", quote_a)
	_expect(str(collision.get("reason_code", "")) == "transaction_intent_collision", "market transaction intent collision is rejected")
	var road_quote: Dictionary = quote_authority.issue_quote(0, 0, "facility.road.rank_1", "supply-road-1", 3)
	var continuous := service.purchase_market_card("A", "market-road-1", next_next, 1, 4, "tx-market-buy-2", road_quote)
	_expect(bool(continuous.get("committed", false)) and int(service.market_snapshot().get("revision", -1)) == 5, "refreshed listing can be bought immediately using the new revisions")
	_expect(int(service.player_snapshot("A").get("card_purchase_count", -1)) == 2 and int(service.player_snapshot("A").get("total_card_spend", -1)) == 7, "successive market purchases accumulate count and spend")
	var expiring_quote: Dictionary = quote_authority.issue_quote(1, 0, "facility.seaport.rank_1", "supply-seaport-2", 2, 1)
	quote_authority.now_world_us = 1
	var expired := service.purchase_market_card("B", "market-seaport-2", _market_listing("market-road-2", road, 3, "supply-road-2"), 0, 5, "tx-market-expired", expiring_quote)
	_expect(str(expired.get("reason_code", "")) == "market_quote_unauthorized", "expired quote is rejected at the authority boundary")


func _verify_authoritative_manual_merge(catalog: CardRuntimeCatalogV06Resource) -> void:
	var service = SERVICE_SCRIPT.new(catalog)
	var ring := catalog.card_snapshot("commodity.ring_crystal_battery.rank_1")
	service.register_player("A", _state([ring, ring], 0, _assets(), 5))
	var stale := service.manual_merge("A", 0, 1, 4, "tx-merge-stale")
	_expect(not bool(stale.get("committed", true)) and str(stale.get("reason_code", "")) == "player_revision_changed", "manual merge rejects an old player revision")
	var merged := service.manual_merge("A", 0, 1, 5, "tx-merge-1")
	_expect(bool(merged.get("committed", false)), "authoritative manual merge commits")
	var player := service.player_snapshot("A")
	_expect(int(player.get("revision", -1)) == 6 and _card_count(player) == 1, "manual merge advances one player revision and removes one card")
	_expect(_family_rank_count(player, "commodity.ring_crystal_battery", 2) == 1, "manual merge resolves the catalog rank-II result")


func _verify_effect_two_phase_success(catalog: CardRuntimeCatalogV06Resource) -> void:
	var service = SERVICE_SCRIPT.new(catalog)
	var warehouse := catalog.card_snapshot("facility.orbital_warehouse.rank_2")
	var assets := _assets()
	assets["shipping"] = 2
	service.register_player("A", _state([warehouse], 0, assets))
	var handler := BoundEffectHandler.new()
	var target := {
		"valid": true,
		"target_kind": "region_unique_facility_slot",
		"target_id": "warehouse-slot-1",
		"generic_asset_allocation": {"shipping": 2},
	}
	var played := service.play_card("A", 0, target, handler, 0, "tx-play-success")
	_expect(bool(played.get("committed", false)), "two-phase effect play commits")
	var player := service.player_snapshot("A")
	var after_assets: Dictionary = player.get("assets", {}) if player.get("assets", {}) is Dictionary else {}
	_expect(_card_count(player) == 0 and int(after_assets.get("shipping", -1)) == 0, "successful effect consumes the card and selected colored asset")
	_expect(not after_assets.has("generic"), "generic cost never creates a seventh asset pool")
	_expect(handler.prepare_calls == 1 and handler.commit_calls == 1, "handler prepare and commit each run once")
	var replay := service.play_card("A", 0, target, handler, 0, "tx-play-success")
	_expect(bool(replay.get("committed", false)) and bool(replay.get("idempotent_replay", false)), "successful effect transaction replays without the card still being present")
	_expect(handler.prepare_calls == 1 and handler.commit_calls == 1, "effect transaction replay does not call the handler again")
	var changed_target := target.duplicate(true)
	changed_target["target_id"] = "warehouse-slot-2"
	var collision := service.play_card("A", 0, changed_target, handler, 0, "tx-play-success")
	_expect(str(collision.get("reason_code", "")) == "transaction_intent_collision", "same effect transaction id cannot target a different facility")


func _verify_effect_receipt_and_rollback(catalog: CardRuntimeCatalogV06Resource) -> void:
	var warehouse := catalog.card_snapshot("facility.orbital_warehouse.rank_2")
	var target := {
		"valid": true,
		"target_kind": "region_unique_facility_slot",
		"target_id": "warehouse-slot-1",
		"generic_asset_allocation": {"life": 2},
	}
	var assets := _assets()
	assets["life"] = 2

	var receipt_service = SERVICE_SCRIPT.new(catalog)
	receipt_service.register_player("A", _state([warehouse], 0, assets))
	var wrong_receipt := BoundEffectHandler.new()
	wrong_receipt.corrupt_commit_field = "payload_hash"
	var before_wrong := receipt_service.player_snapshot("A")
	var wrong := receipt_service.play_card("A", 0, target, wrong_receipt, 0, "tx-play-wrong-receipt")
	_expect(not bool(wrong.get("committed", true)) and str(wrong.get("reason_code", "")) == "effect_receipt_invalid" and bool(wrong.get("rolled_back", false)), "wrong bound effect receipt is rejected and rolled back")
	_expect(_same_player_resources(before_wrong, receipt_service.player_snapshot("A")), "wrong receipt restores revision, card, cash, and assets")
	_expect(wrong_receipt.rollback_calls == 1, "wrong committed receipt requests handler compensation")
	_expect_feedback(wrong, "wrong effect receipt")

	var failure_service = SERVICE_SCRIPT.new(catalog)
	failure_service.register_player("A", _state([warehouse], 0, assets))
	var failed_handler := BoundEffectHandler.new()
	failed_handler.fail_commit = true
	var before_failure := failure_service.player_snapshot("A")
	var failed := failure_service.play_card("A", 0, target, failed_handler, 0, "tx-play-commit-failure")
	_expect(not bool(failed.get("committed", true)) and str(failed.get("reason_code", "")) == "effect_commit_failed" and not bool(failed.get("rolled_back", true)), "explicit effect commit rejection does not fabricate a rollback")
	_expect(failed_handler.abort_calls == 1 and failed_handler.rollback_calls == 0, "structured zero-effect commit rejection releases the prepared association without fabricating compensation")
	_expect(_same_player_resources(before_failure, failure_service.player_snapshot("A")), "effect commit failure restores the authoritative player snapshot")
	var failure_replay := failure_service.play_card("A", 0, target, failed_handler, 0, "tx-play-commit-failure")
	_expect(bool(failure_replay.get("idempotent_replay", false)) and failed_handler.prepare_calls == 1 and failed_handler.commit_calls == 1, "failed effect transaction is journaled and not executed twice")
	_expect_feedback(failed, "effect commit failure")

	var prepare_service = SERVICE_SCRIPT.new(catalog)
	prepare_service.register_player("A", _state([warehouse], 0, assets))
	var bad_prepare := BoundEffectHandler.new()
	bad_prepare.corrupt_prepare_field = "actor_id"
	var prepared := prepare_service.play_card("A", 0, target, bad_prepare, 0, "tx-play-bad-prepare")
	_expect(str(prepared.get("reason_code", "")) == "effect_receipt_invalid" and _card_count(prepare_service.player_snapshot("A")) == 1, "bad prepare receipt is rejected before local consumption")
	_expect(bad_prepare.commit_calls == 0 and bad_prepare.abort_calls == 1, "bad prepare receipt never reaches effect commit")


func _verify_injected_state_port_and_cross_player_lock(catalog: CardRuntimeCatalogV06Resource) -> void:
	var state_port = STATE_PORT_SCRIPT.new()
	var service = SERVICE_SCRIPT.new(catalog, state_port)
	var ring := catalog.card_snapshot("commodity.ring_crystal_battery.rank_1")
	_expect(bool(service.register_player("A", _state([ring, ring], 7)).get("configured", false)), "service registers player A through the injected state port")
	_expect(bool(service.register_player("B", _state([], 9)).get("configured", false)), "service registers player B through the injected state port")
	_expect(service.player_state_port() == state_port and not _has_script_property(service, "_players"), "injected state port is the only player-state authority")
	var port_a_before: Dictionary = (state_port.read_player("A") as Dictionary).get("player_state", {}) as Dictionary
	_expect(_same_player_resources(port_a_before, service.player_snapshot("A")), "service read is delegated to the injected state port")

	var cross_lock: Dictionary = state_port.reserve_transaction(
		"tx-cross-player-lock",
		"intent-cross-player-lock",
		{"A": 0, "B": 0},
		["A", "B"]
	)
	_expect(bool(cross_lock.get("reserved", false)), "external interaction can atomically lock both players")
	var blocked := service.manual_merge("A", 0, 1, 0, "tx-merge-while-cross-locked")
	_expect(str(blocked.get("reason_code", "")) == "player_busy" and int(service.player_snapshot("A").get("revision", -1)) == 0, "cross-player lock blocks a single-player transaction without partial mutation")
	state_port.abort_reserved(str(cross_lock.get("reservation_id", "")))

	var merged := service.manual_merge("A", 0, 1, 0, "tx-injected-merge")
	var port_a_after: Dictionary = (state_port.read_player("A") as Dictionary).get("player_state", {}) as Dictionary
	_expect(bool(merged.get("committed", false)) and int(port_a_after.get("revision", -1)) == 1 and int(service.player_snapshot("A").get("revision", -1)) == 1, "service and injected port expose one shared player revision")
	var port_replay: Dictionary = state_port.replay_result("tx-injected-merge", str(merged.get("intent_hash", "")))
	var service_replay := service.manual_merge("A", 0, 1, 0, "tx-injected-merge")
	_expect(bool(port_replay.get("idempotent_replay", false)) and bool(service_replay.get("idempotent_replay", false)) and int(service.player_snapshot("A").get("revision", -1)) == 1, "port and service journals replay without executing the merge twice")


func _verify_effect_rollback_when_state_port_commit_fails(catalog: CardRuntimeCatalogV06Resource) -> void:
	var inner_port = STATE_PORT_SCRIPT.new()
	var rejecting_port := CommitRejectingStatePort.new(inner_port)
	var service = SERVICE_SCRIPT.new(catalog, rejecting_port)
	var warehouse := catalog.card_snapshot("facility.orbital_warehouse.rank_2")
	var assets := _assets()
	assets["shipping"] = 2
	service.register_player("A", _state([warehouse], 0, assets))
	var handler := BoundEffectHandler.new()
	var target := {
		"valid": true,
		"target_kind": "region_unique_facility_slot",
		"target_id": "warehouse-slot-port-cas",
		"generic_asset_allocation": {"shipping": 2},
	}
	var before := service.player_snapshot("A")
	var failed := service.play_card("A", 0, target, handler, 0, "tx-play-port-cas-failure")
	_expect(str(failed.get("reason_code", "")) == "player_state_commit_failed" and bool(failed.get("rolled_back", false)), "unexpected state-port commit failure is surfaced as a compensated play")
	_expect(rejecting_port.commit_calls == 1 and handler.commit_calls == 1 and handler.rollback_calls == 1, "successful domain effect is rolled back when player CAS fails")
	_expect(_same_player_resources(before, service.player_snapshot("A")), "state-port commit failure leaves card, cash, assets, and revision unchanged")
	var replay := service.play_card("A", 0, target, handler, 0, "tx-play-port-cas-failure")
	_expect(bool(replay.get("idempotent_replay", false)) and handler.commit_calls == 1 and handler.rollback_calls == 1, "compensated failure is journaled and never executes twice")


func _verify_effect_compensation_failure_is_honest(catalog: CardRuntimeCatalogV06Resource) -> void:
	var cases := [
		{
			"label": "facility",
			"card": catalog.card_snapshot("facility.orbital_warehouse.rank_2"),
			"assets": {"life": 0, "energy": 0, "industry": 0, "technology": 0, "commerce": 0, "shipping": 2},
			"target": {
				"valid": true,
				"target_kind": "region_unique_facility_slot",
				"target_id": "warehouse-compensation-failure",
				"generic_asset_allocation": {"shipping": 2},
			},
		},
		{
			"label": "commodity_flow",
			"card": catalog.card_snapshot("commodity.ring_crystal_battery.rank_1"),
			"assets": _assets(),
			"target": {
				"valid": true,
				"target_kind": "same_industry_factory_or_market",
				"target_id": "factory-compensation-failure",
			},
		},
	]
	for case_variant in cases:
		var case: Dictionary = case_variant
		var inner_port = STATE_PORT_SCRIPT.new()
		var rejecting_port := CommitRejectingStatePort.new(inner_port)
		var service = SERVICE_SCRIPT.new(catalog, rejecting_port)
		service.register_player("A", _state([case.get("card", {}) as Dictionary], 0, case.get("assets", {}) as Dictionary))
		var handler := BoundEffectHandler.new()
		handler.rollback_succeeds = false
		var label := str(case.get("label", "effect"))
		var before := service.player_snapshot("A")
		var transaction_id := "tx-%s-compensation-failure" % label
		var failed := service.play_card("A", 0, case.get("target", {}) as Dictionary, handler, 0, transaction_id)
		_expect(not bool(failed.get("committed", true)) and str(failed.get("reason_code", "")) == "effect_compensation_failed", "%s rollback failure is a terminal compensation failure" % label)
		_expect(not bool(failed.get("rolled_back", true)) and bool(failed.get("compensation_failed", false)), "%s rollback failure never fabricates rolled_back=true" % label)
		var compensation: Dictionary = failed.get("compensation", {}) if failed.get("compensation", {}) is Dictionary else {}
		var owner_result: Dictionary = compensation.get("owner_result", {}) if compensation.get("owner_result", {}) is Dictionary else {}
		_expect(bool(compensation.get("attempted", false)) and str(owner_result.get("reason_code", "")) == "simulated_owner_rollback_failure", "%s failure retains machine-diagnostic compensation fields" % label)
		_expect(_same_player_resources(before, service.player_snapshot("A")), "%s compensation failure commits no card, cash, asset, or revision mutation" % label)
		var feedback: Dictionary = failed.get("feedback", {}) if failed.get("feedback", {}) is Dictionary else {}
		var player_text := JSON.stringify(feedback)
		_expect(not player_text.contains("effect_compensation_failed") and not player_text.contains("simulated_owner_rollback_failure") and not player_text.contains("facility.") and not player_text.contains("commodity."), "%s player feedback leaks no machine reason, card id, or developer value" % label)
		var replay := service.play_card("A", 0, case.get("target", {}) as Dictionary, handler, 0, transaction_id)
		_expect(bool(replay.get("idempotent_replay", false)) and handler.commit_calls == 1 and handler.rollback_calls == 1, "%s compensation failure is journaled exact-once" % label)


func _state(cards: Array, cash: int, assets: Dictionary = {}, revision: int = 0, player_index: int = -1) -> Dictionary:
	var resolved_assets := _assets() if assets.is_empty() else assets.duplicate(true)
	var state := {
		"revision": revision,
		"cash": cash,
		"assets": resolved_assets,
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


func _card_count(player_state: Dictionary) -> int:
	var inventory: Dictionary = player_state.get("inventory", {}) if player_state.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	var count := 0
	for slot_variant in slots:
		if slot_variant is Dictionary:
			count += 1
	return count


func _family_rank_count(player_state: Dictionary, family_id: String, rank: int) -> int:
	var inventory: Dictionary = player_state.get("inventory", {}) if player_state.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	var count := 0
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var machine: Dictionary = (slot_variant as Dictionary).get("machine", {}) if (slot_variant as Dictionary).get("machine", {}) is Dictionary else {}
		if str(machine.get("family_id", "")) == family_id and int(machine.get("rank", 0)) == rank:
			count += 1
	return count


func _same_player_resources(first: Dictionary, second: Dictionary) -> bool:
	return (
		int(first.get("revision", -1)) == int(second.get("revision", -2))
		and int(first.get("cash", -1)) == int(second.get("cash", -2))
		and JSON.stringify(first.get("assets", {})) == JSON.stringify(second.get("assets", {}))
		and JSON.stringify(first.get("inventory", {})) == JSON.stringify(second.get("inventory", {}))
	)


func _has_script_property(instance: Object, property_name: String) -> bool:
	for property_variant in instance.get_property_list():
		if property_variant is Dictionary \
		and str((property_variant as Dictionary).get("name", "")) == property_name:
			return true
	return false


func _expect_feedback(result: Dictionary, label: String) -> void:
	var feedback: Dictionary = result.get("feedback", {}) if result.get("feedback", {}) is Dictionary else {}
	_expect(str(feedback.get("reason", "")).strip_edges() != "" and str(feedback.get("next_step", "")).strip_edges() != "", "%s has localized why-and-next-step feedback" % label)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CARD_FLOW_TRANSACTION_SERVICE_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("CARD_FLOW_TRANSACTION_SERVICE_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
