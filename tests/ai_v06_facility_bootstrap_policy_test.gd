extends SceneTree

const AI_SCRIPT := preload("res://scripts/runtime/ai_runtime_controller.gd")
const PORT_SCRIPT := preload("res://scripts/runtime/ai_v06_economy_action_port.gd")
const WORLD_BRIDGE_SCRIPT := preload("res://scripts/runtime/ai_runtime_world_bridge.gd")
const MONSTER_SCRIPT := preload("res://scripts/runtime/monster_runtime_controller.gd")

const ACTOR_ONE := "ai.one"
const ACTOR_TWO := "ai.two"
const FACILITY_CARD_ID := "facility.factory.commerce.rank_1"
const FACILITY_EFFECT_KIND := "build_upgrade_or_repair_facility"

var _checks := 0
var _failures: Array[String] = []


class FakeWorld:
	extends Node

	var players: Array = [
		{"actor_id": ACTOR_ONE, "is_ai": true, "eliminated": false, "action_cooldown": 0.0},
		{"actor_id": ACTOR_TWO, "is_ai": true, "eliminated": false, "action_cooldown": 0.0},
	]
	var districts: Array = [
		{"region_id": "region.alpha", "destroyed": false, "lifecycle_state": "active"},
	]
	var game_time := 0.0
	var configured_ai_player_count := 2
	var configured_player_count := 2
	var card_resolution_auction_open := false
	var card_resolution_batch_locked := false
	var card_resolution_counter_window_active := false
	var resolved_card_history: Array = []
	var selected_card_resolution_id := -1
	var rng := RandomNumberGenerator.new()

	func _init() -> void:
		rng.seed = 60501

	func _player_is_ai(player_index: int) -> bool:
		return player_index >= 0 and player_index < players.size() and bool((players[player_index] as Dictionary).get("is_ai", false))

	func _player_is_eliminated(player_index: int) -> bool:
		return player_index < 0 or player_index >= players.size() or bool((players[player_index] as Dictionary).get("eliminated", false))

	func _runtime_session_finished() -> bool:
		return false

	func _configured_human_player_count() -> int:
		return 0


class FakeEconomyDelegate:
	extends RefCounted

	var player_states: Dictionary = {}
	var market_states: Dictionary = {}
	var source_states: Dictionary = {}
	var market_snapshot_revision_offset: Dictionary = {}
	var player_snapshot_revision_offset: Dictionary = {}
	var call_log: Array[Dictionary] = []
	var purchase_requests: Array[Dictionary] = []
	var play_requests: Array[Dictionary] = []
	var purchase_calls := 0
	var play_calls := 0
	var mutation_count := 0
	var mutation_origins: Array[String] = []
	var journal: Dictionary = {}

	func _init() -> void:
		for actor_id in [ACTOR_ONE, ACTOR_TWO]:
			player_states[actor_id] = {
				"revision": 11,
				"cash": 20,
				"cards": [],
			}
			market_states[actor_id] = {
				"revision": 7,
				"listing": {
					"canonical": true,
					"bootstrap_eligible": true,
					"item_id": "listing.%s.7" % actor_id,
					"card_id": FACILITY_CARD_ID,
					"category_id": "facility",
					"rank": 1,
					"effect_kind": FACILITY_EFFECT_KIND,
					"purchase_cash": 4,
					"target_region_id": "region.alpha",
					"legal_region_ids": ["region.alpha"],
				},
			}
			source_states[actor_id] = {
				"revision": 3,
				"has_source": false,
				"bootstrap_finalized": false,
				"legal_region_ids": ["region.alpha"],
			}

	func market_snapshot(actor_id: String) -> Dictionary:
		_record_call("market_snapshot", actor_id)
		if not market_states.has(actor_id):
			return _failure("fake_market_missing")
		var result := (market_states[actor_id] as Dictionary).duplicate(true)
		result["revision"] = int(result.get("revision", 0)) + int(market_snapshot_revision_offset.get(actor_id, 0))
		result["available"] = true
		result["reason_code"] = "fake_market_ready"
		return result

	func purchase_rank_i_facility(
		actor_id: String,
		item_id: String,
		transaction_id: String,
		expected_market_revision: int,
		expected_player_revision: int,
		expected_source_revision: int
	) -> Dictionary:
		purchase_calls += 1
		_record_call("purchase_rank_i_facility", actor_id)
		purchase_requests.append({
			"actor_id": actor_id,
			"item_id": item_id,
			"transaction_id": transaction_id,
			"expected_market_revision": expected_market_revision,
			"expected_player_revision": expected_player_revision,
			"expected_source_revision": expected_source_revision,
		})
		if journal.has(transaction_id):
			return (journal[transaction_id] as Dictionary).duplicate(true)
		if not player_states.has(actor_id) or not market_states.has(actor_id) or not source_states.has(actor_id):
			return _failure("fake_actor_missing")
		var player := player_states[actor_id] as Dictionary
		var market := market_states[actor_id] as Dictionary
		var source := source_states[actor_id] as Dictionary
		var listing := market.get("listing", {}) as Dictionary
		if expected_market_revision != int(market.get("revision", -1)):
			return _failure("market_revision_stale", int(market.get("revision", 0)))
		if expected_player_revision != int(player.get("revision", -1)):
			return _failure("player_revision_stale", int(player.get("revision", 0)))
		if expected_source_revision != int(source.get("revision", -1)) or bool(source.get("has_source", false)):
			return _failure("source_revision_stale", int(source.get("revision", 0)))
		if item_id != str(listing.get("item_id", "")):
			return _failure("listing_changed", int(market.get("revision", 0)))
		var price := int(listing.get("purchase_cash", -1))
		if price < 0 or int(player.get("cash", -1)) < price:
			return _failure("cash_insufficient", int(player.get("revision", 0)))
		var cards: Array = (player.get("cards", []) as Array).duplicate(true)
		cards.append({
			"slot_index": cards.size(),
			"runtime_instance_id": "runtime.%s.%s" % [actor_id, item_id],
			"card_id": str(listing.get("card_id", "")),
			"category_id": str(listing.get("category_id", "")),
			"rank": int(listing.get("rank", 0)),
			"effect_kind": str(listing.get("effect_kind", "")),
			"bootstrap_eligible": bool(listing.get("bootstrap_eligible", false)),
		})
		player["cash"] = int(player.get("cash", 0)) - price
		player["cards"] = cards
		player["revision"] = int(player.get("revision", 0)) + 1
		market["revision"] = int(market.get("revision", 0)) + 1
		player_states[actor_id] = player
		market_states[actor_id] = market
		mutation_count += 1
		mutation_origins.append("purchase_rank_i_facility")
		var result := {
			"available": true,
			"revision": int(player.get("revision", 0)),
			"reason_code": "committed",
			"committed": true,
		}
		journal[transaction_id] = result.duplicate(true)
		return result

	func player_snapshot(actor_id: String) -> Dictionary:
		_record_call("player_snapshot", actor_id)
		if not player_states.has(actor_id):
			return _failure("fake_player_missing")
		var state := (player_states[actor_id] as Dictionary).duplicate(true)
		return {
			"available": true,
			"revision": int(state.get("revision", 0)) + int(player_snapshot_revision_offset.get(actor_id, 0)),
			"reason_code": "fake_player_ready",
			"cash": int(state.get("cash", 0)),
			"cards": (state.get("cards", []) as Array).duplicate(true),
		}

	func play_runtime_card(request: Dictionary) -> Dictionary:
		play_calls += 1
		var actor_id := str(request.get("actor_id", ""))
		_record_call("play_runtime_card", actor_id)
		play_requests.append(request.duplicate(true))
		var transaction_id := str(request.get("transaction_id", ""))
		if journal.has(transaction_id):
			return (journal[transaction_id] as Dictionary).duplicate(true)
		if not player_states.has(actor_id) or not source_states.has(actor_id):
			return _failure("fake_actor_missing")
		var player := player_states[actor_id] as Dictionary
		var source := source_states[actor_id] as Dictionary
		if int(request.get("expected_player_revision", -1)) != int(player.get("revision", -1)):
			return _failure("player_revision_stale", int(player.get("revision", 0)))
		if int(request.get("expected_source_revision", -1)) != int(source.get("revision", -1)) or bool(source.get("has_source", false)):
			return _failure("source_revision_stale", int(source.get("revision", 0)))
		if str(request.get("region_id", "")) != "region.alpha":
			return _failure("region_invalid", int(player.get("revision", 0)))
		var cards: Array = (player.get("cards", []) as Array).duplicate(true)
		var slot_index := int(request.get("slot_index", -1))
		if slot_index < 0 or slot_index >= cards.size() or not (cards[slot_index] is Dictionary):
			return _failure("card_binding_missing", int(player.get("revision", 0)))
		var card := cards[slot_index] as Dictionary
		if str(card.get("runtime_instance_id", "")) != str(request.get("runtime_instance_id", "")):
			return _failure("card_binding_changed", int(player.get("revision", 0)))
		cards.remove_at(slot_index)
		player["cards"] = cards
		player["revision"] = int(player.get("revision", 0)) + 1
		source["has_source"] = true
		source["bootstrap_finalized"] = true
		source["revision"] = int(source.get("revision", 0)) + 1
		player_states[actor_id] = player
		source_states[actor_id] = source
		mutation_count += 1
		mutation_origins.append("play_runtime_card")
		var result := {
			"available": true,
			"revision": int(player.get("revision", 0)),
			"reason_code": "committed",
			"committed": true,
			"finalized": true,
			"effect_finalization": {"finalized": true},
		}
		journal[transaction_id] = result.duplicate(true)
		return result

	func economic_source_snapshot(actor_id: String) -> Dictionary:
		_record_call("economic_source_snapshot", actor_id)
		if not source_states.has(actor_id):
			return _failure("fake_source_missing")
		var source := source_states[actor_id] as Dictionary
		return {
			"available": true,
			"revision": int(source.get("revision", 0)),
			"reason_code": "fake_source_ready",
			"has_source": bool(source.get("has_source", false)),
			"bootstrap_finalized": bool(source.get("bootstrap_finalized", false)),
			"target_region_id": str(source.get("target_region_id", "")),
			"legal_region_ids": (source.get("legal_region_ids", []) as Array).duplicate(true),
		}

	func owner_snapshot() -> Dictionary:
		return {
			"players": player_states.duplicate(true),
			"markets": market_states.duplicate(true),
			"sources": source_states.duplicate(true),
			"journal": journal.duplicate(true),
			"mutation_count": mutation_count,
		}

	func calls_for_actor(actor_id: String) -> Array[String]:
		var result: Array[String] = []
		for entry_variant in call_log:
			var entry := entry_variant as Dictionary
			if str(entry.get("actor_id", "")) == actor_id:
				result.append(str(entry.get("method", "")))
		return result

	func _record_call(method_name: String, actor_id: String) -> void:
		call_log.append({"method": method_name, "actor_id": actor_id})

	func _failure(reason_code: String, revision: int = 0) -> Dictionary:
		return {
			"available": true,
			"revision": maxi(0, revision),
			"reason_code": reason_code,
			"committed": false,
		}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_port_contract()
	_test_normal_and_forced_share_owner_chain()
	_test_fail_closed_gates()
	_test_force_only_bypasses_cooldown()
	_finish()


func _fixture(bind_port := true) -> Dictionary:
	var world := FakeWorld.new()
	var bridge: Node = WORLD_BRIDGE_SCRIPT.new()
	var monster: Node = MONSTER_SCRIPT.new()
	var ai: Node = AI_SCRIPT.new()
	var delegate := FakeEconomyDelegate.new()
	var port: RefCounted = PORT_SCRIPT.new()
	get_root().add_child(world)
	get_root().add_child(bridge)
	get_root().add_child(monster)
	get_root().add_child(ai)
	bridge.call("bind_world", world)
	ai.call("set_world_bridge", bridge)
	ai.call("set_monster_runtime_controller", monster)
	ai.call("configure", {}, null)
	var starter_state := {
		ACTOR_ONE: {"state": "summoned", "unit_uid": 101, "transaction_id": "starter.one", "revision": 1},
		ACTOR_TWO: {"state": "summoned", "unit_uid": 102, "transaction_id": "starter.two", "revision": 1},
	}
	monster.set("_monster_starter_state_v06", starter_state)
	monster.set("_monster_card_revision_v06", 2)
	if bind_port:
		port.call("bind_delegate", delegate)
		ai.call("set_v06_economy_action_port", port)
	return {
		"world": world,
		"bridge": bridge,
		"monster": monster,
		"ai": ai,
		"delegate": delegate,
		"port": port,
	}


func _dispose(fixture: Dictionary) -> void:
	for key in ["ai", "monster", "bridge", "world"]:
		var value: Variant = fixture.get(key)
		if value is Node and is_instance_valid(value):
			(value as Node).free()


func _test_port_contract() -> void:
	var port: RefCounted = PORT_SCRIPT.new()
	var unavailable: Dictionary = port.call("capability_snapshot")
	_expect(not bool(unavailable.get("available", true)), "unbound port fails closed")
	var delegate := FakeEconomyDelegate.new()
	var capability: Dictionary = port.call("bind_delegate", delegate)
	_expect(bool(capability.get("available", false)), "all five narrow capabilities make the port ready")
	_expect(str(capability.get("contract_version", "")) == "v0.6-ai-economy-action-port-v1", "port exposes a versioned contract")
	var market: Dictionary = port.call("market_snapshot", ACTOR_ONE)
	_expect(bool(market.get("available", false)) and int(market.get("revision", -1)) >= 0 and not str(market.get("reason_code", "")).is_empty(), "port result has availability revision and reason")


func _test_normal_and_forced_share_owner_chain() -> void:
	var fixture := _fixture()
	var ai: Node = fixture["ai"]
	var world := fixture["world"] as FakeWorld
	var delegate := fixture["delegate"] as FakeEconomyDelegate
	var world_before := {"players": world.players.duplicate(true), "districts": world.districts.duplicate(true)}
	var candidate: Dictionary = ai.call("_ai_v06_facility_bootstrap_candidate", 0, false)
	_expect(bool(candidate.get("available", false)), "field-driven candidate is available after starter with no source")
	_expect(str(candidate.get("policy_kind", "")) == "v06_facility_bootstrap" and str(candidate.get("action_kind", "")) == "purchase_and_play_facility", "candidate identifies policy and action kinds")
	_expect(candidate.has("expected_market_revision") and candidate.has("expected_player_revision") and candidate.has("expected_source_revision"), "candidate binds all authoritative revisions")
	_expect(str(candidate.get("region_id", "")) == "region.alpha", "candidate consumes the authoritative listing target")
	delegate.call_log.clear()
	ai.set("ai_card_decision_timer", 0.0)
	ai.call("_update_ai_decisions", 0.01)
	_expect(bool((delegate.source_states[ACTOR_ONE] as Dictionary).get("has_source", false)), "normal scheduler finalizes the first AI facility")
	_expect(not bool((delegate.source_states[ACTOR_TWO] as Dictionary).get("has_source", false)), "one scheduler cycle bootstraps at most one seat")
	_expect(delegate.purchase_calls == 1 and delegate.play_calls == 1, "normal scheduler uses one purchase and one play")
	var expected_chain: Array[String] = ["economic_source_snapshot", "player_snapshot", "market_snapshot", "purchase_rank_i_facility", "player_snapshot", "play_runtime_card"]
	_expect(delegate.calls_for_actor(ACTOR_ONE) == expected_chain, "normal scheduler follows the narrow production call chain")
	_expect(world.players == world_before["players"] and world.districts == world_before["districts"], "AI does not write legacy players or district city state")
	_expect(delegate.mutation_origins == ["purchase_rank_i_facility", "play_runtime_card"], "only fake owner methods mutate authoritative fixture state")
	var purchases_before := delegate.purchase_calls
	var plays_before := delegate.play_calls
	var repeated: Dictionary = ai.call("_ai_execute_v06_facility_bootstrap_for_player", 0, true)
	_expect(str(repeated.get("reason_code", "")) == "ai_v06_economic_source_already_exists", "same seat stops after one finalized source")
	_expect(delegate.purchase_calls == purchases_before and delegate.play_calls == plays_before, "second same-seat invocation does not buy or play again")
	delegate.call_log.clear()
	var forced: Dictionary = ai.call("execute_v06_facility_bootstrap_cycle", true)
	_expect(int(forced.get("acted", 0)) == 1 and bool((delegate.source_states[ACTOR_TWO] as Dictionary).get("has_source", false)), "later forced cycle advances the other AI seat")
	_expect(delegate.calls_for_actor(ACTOR_TWO) == expected_chain, "forced and normal cycles share the identical owner call chain")
	var purchase_request: Dictionary = delegate.purchase_requests[0]
	_expect(not purchase_request.has("price") and not purchase_request.has("card_payload") and not purchase_request.has("owner_receipt"), "purchase submits only identity transaction and revision bindings")
	var play_request: Dictionary = delegate.play_requests[0]
	_expect(_keys_equal(play_request.keys(), ["actor_id", "slot_index", "runtime_instance_id", "transaction_id", "region_id", "expected_player_revision", "expected_source_revision"]), "play request is restricted to the narrow binding fields")
	var public_snapshot: Dictionary = ai.call("ai_v06_facility_bootstrap_public_snapshot")
	_expect(not _contains_private_key(public_snapshot), "public-safe snapshot excludes actors transactions cash hands routes and scores")
	_dispose(fixture)


func _test_fail_closed_gates() -> void:
	var cases := [
		{"name": "port unavailable", "setup": "port", "expected": "ai_v06_economy_port_unavailable"},
		{"name": "starter incomplete", "setup": "starter", "expected": "ai_v06_starter_not_completed"},
		{"name": "source exists", "setup": "source", "expected": "ai_v06_economic_source_already_exists"},
		{"name": "bootstrap already finalized", "setup": "bootstrap_finalized", "expected": "ai_v06_facility_bootstrap_already_finalized"},
		{"name": "cash insufficient", "setup": "cash", "expected": "ai_v06_facility_cash_insufficient"},
		{"name": "authoritative target unavailable", "setup": "target", "expected": "ai_v06_facility_authoritative_target_unavailable"},
		{"name": "stale market revision", "setup": "market_revision", "expected": "market_revision_stale"},
		{"name": "stale player revision", "setup": "player_revision", "expected": "player_revision_stale"},
	]
	for case_variant in cases:
		var case := case_variant as Dictionary
		var fixture := _fixture(str(case.get("setup", "")) != "port")
		var ai: Node = fixture["ai"]
		var monster: Node = fixture["monster"]
		var delegate := fixture["delegate"] as FakeEconomyDelegate
		match str(case.get("setup", "")):
			"starter":
				var starter_state: Dictionary = monster.get("_monster_starter_state_v06")
				starter_state[ACTOR_ONE] = {"state": "not_summoned", "unit_uid": 0, "transaction_id": "", "revision": 0}
				monster.set("_monster_starter_state_v06", starter_state)
			"source":
				(delegate.source_states[ACTOR_ONE] as Dictionary)["has_source"] = true
			"bootstrap_finalized":
				(delegate.source_states[ACTOR_ONE] as Dictionary)["bootstrap_finalized"] = true
			"cash":
				(delegate.player_states[ACTOR_ONE] as Dictionary)["cash"] = 3
			"target":
				var listing := (delegate.market_states[ACTOR_ONE] as Dictionary).get("listing", {}) as Dictionary
				listing.erase("target_region_id")
				listing["legal_region_ids"] = []
				(delegate.market_states[ACTOR_ONE] as Dictionary)["listing"] = listing
				(delegate.source_states[ACTOR_ONE] as Dictionary)["legal_region_ids"] = []
			"market_revision":
				delegate.market_snapshot_revision_offset[ACTOR_ONE] = -1
			"player_revision":
				delegate.player_snapshot_revision_offset[ACTOR_ONE] = -1
		var before := delegate.owner_snapshot()
		var result: Dictionary = ai.call("_ai_execute_v06_facility_bootstrap_for_player", 0, true)
		var after := delegate.owner_snapshot()
		_expect(str(result.get("reason_code", "")) == str(case.get("expected", "")), "%s reports its exact failure" % str(case.get("name", "gate")))
		_expect(before == after, "%s has zero owner side effects" % str(case.get("name", "gate")))
		_dispose(fixture)


func _test_force_only_bypasses_cooldown() -> void:
	var fixture := _fixture()
	var ai: Node = fixture["ai"]
	var world := fixture["world"] as FakeWorld
	var delegate := fixture["delegate"] as FakeEconomyDelegate
	(world.players[0] as Dictionary)["action_cooldown"] = 9.0
	var normal: Dictionary = ai.call("_ai_execute_v06_facility_bootstrap_for_player", 0, false)
	_expect(str(normal.get("reason_code", "")) == "ai_v06_facility_action_cooldown" and delegate.mutation_count == 0, "normal action respects cooldown")
	var forced: Dictionary = ai.call("_ai_execute_v06_facility_bootstrap_for_player", 0, true)
	_expect(bool(forced.get("finalized", false)), "force bypasses cooldown through the same action")
	_expect(delegate.purchase_calls == 1 and delegate.play_calls == 1, "force does not bypass purchase or play owners")
	_dispose(fixture)


func _keys_equal(actual: Array, expected: Array) -> bool:
	var left: Array[String] = []
	var right: Array[String] = []
	for key_variant in actual:
		left.append(str(key_variant))
	for key_variant in expected:
		right.append(str(key_variant))
	left.sort()
	right.sort()
	return left == right


func _contains_private_key(value: Variant) -> bool:
	var forbidden := ["actor_id", "transaction_id", "cash", "hand", "slots", "score", "route", "plan", "pressure"]
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			for token in forbidden:
				if key.contains(token):
					return true
			if _contains_private_key((value as Dictionary).get(key_variant)):
				return true
	elif value is Array:
		for item_variant in value as Array:
			if _contains_private_key(item_variant):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AI V0.6 FACILITY BOOTSTRAP POLICY TEST PASS: %d checks" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("AI V0.6 FACILITY BOOTSTRAP POLICY TEST FAIL: %s" % failure)
	print("AI V0.6 FACILITY BOOTSTRAP POLICY TEST FAIL: %d/%d" % [_failures.size(), _checks])
	quit(1)
