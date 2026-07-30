extends SceneTree

const ADAPTER_SCRIPT := preload("res://scripts/cards/v06/production/card_player_state_production_adapter_v06.gd")
const ASSET_CONTROLLER_SCRIPT := preload("res://scripts/runtime/player_mana_runtime_controller.gd")
const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const PROFILE_PATH := "res://resources/rules/space_syndicate_ruleset_v06.tres"
const CARD_ID := "facility.road.rank_1"
const ASSET_IDS: Array[String] = ["life", "energy", "industry", "technology", "commerce", "shipping"]

var _checks := 0
var _failures: Array[String] = []


class TestWorld:
	extends WorldSessionState


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog: Resource = load(CATALOG_PATH)
	_expect(catalog != null and bool(catalog.call("reload").get("valid", false)), "v0.6 card catalog is ready")
	if catalog == null:
		_finish()
		return
	_verify_commit_consume_finalize(catalog)
	_verify_finalized_compensation(catalog)
	_verify_release_from_committed_and_pending(catalog)
	_verify_replay_collision_and_slot_drift(catalog)
	_verify_catalog_purity_and_instance_guards(catalog)
	_verify_restore_like_roundtrip(catalog)
	_verify_candidate_world_preflight(catalog)
	_finish()


func _verify_commit_consume_finalize(catalog: Resource) -> void:
	var fixture := _fixture(catalog, "instance:normal:1")
	var adapter: CardPlayerStateProductionAdapterV06 = fixture.get("adapter")
	var world: WorldSessionState = fixture.get("world")
	var request := _request(catalog, _slot_card(world), "normal")
	var before := world.players.duplicate(true)
	var plan := adapter.plan_facility_card_escrow(request)
	_expect(bool(plan.get("planned", false)) and world.players == before, "planning is detached and read-only")
	var committed := adapter.commit_facility_card_escrow(plan)
	var committed_fingerprint := str(committed.get("escrow_fingerprint", ""))
	_expect(bool(committed.get("committed", false)) and committed_fingerprint.length() == 64, "commit moves the facility card into durable escrow")
	var player: Dictionary = world.players[0] as Dictionary
	_expect((player.get("slots", []) as Array)[0] == null, "commit leaves the exact source slot empty")
	var escrows: Dictionary = player.get("facility_card_escrows", {}) as Dictionary
	var record: Dictionary = escrows.get(str(request.get("escrow_id", "")), {}) as Dictionary
	_expect(str(record.get("state_id", "")) == "committed_resolution_escrow" and record.get("card_record") is Dictionary, "committed escrow retains the private full card")
	var commit_replay := adapter.commit_facility_card_escrow(plan)
	_expect(bool(commit_replay.get("committed", false)) and bool(commit_replay.get("idempotent_replay", false)) and str(commit_replay.get("escrow_fingerprint", "")) == committed_fingerprint, "same plan commit replay is idempotent")

	var snapshot := adapter.facility_card_escrow_snapshot(str(request.get("escrow_id", "")))
	_expect(bool(snapshot.get("found", false)) and str((snapshot.get("escrow", {}) as Dictionary).get("runtime_instance_id", "")) == "instance:normal:1", "private snapshot returns the exact escrow instance")
	((snapshot.get("escrow", {}) as Dictionary).get("card_record", {}) as Dictionary)["runtime_instance_id"] = "detached:mutation"
	var snapshot_again := adapter.facility_card_escrow_snapshot(str(request.get("escrow_id", "")))
	_expect(str(((snapshot_again.get("escrow", {}) as Dictionary).get("card_record", {}) as Dictionary).get("runtime_instance_id", "")) == "instance:normal:1", "snapshot is a detached deep copy")

	var consumed := adapter.consume_facility_card_escrow(str(request.get("escrow_id", "")), committed_fingerprint)
	var pending_fingerprint := str(consumed.get("escrow_fingerprint", ""))
	_expect(bool(consumed.get("consumed", false)) and not bool(consumed.get("terminal", true)) and pending_fingerprint != committed_fingerprint, "consume advances to pending finalization without terminal deletion")
	var pending_snapshot := adapter.facility_card_escrow_snapshot(str(request.get("escrow_id", "")))
	var pending_record: Dictionary = pending_snapshot.get("escrow", {}) as Dictionary
	_expect(str(pending_record.get("state_id", "")) == "consumed_pending_finalization" and pending_record.get("card_record") is Dictionary, "pending finalization still retains rollback card data")
	var consume_replay := adapter.consume_facility_card_escrow(str(request.get("escrow_id", "")), committed_fingerprint)
	_expect(bool(consume_replay.get("consumed", false)) and bool(consume_replay.get("idempotent_replay", false)) and str(consume_replay.get("escrow_fingerprint", "")) == pending_fingerprint, "consume retry accepts the committed predecessor fingerprint exactly once")
	var finalize_preflight := adapter.preflight_finalize_facility_card_escrow(
		str(request.get("escrow_id", "")),
		pending_fingerprint
	)
	_expect(bool(finalize_preflight.get("ready", false)) and not bool(finalize_preflight.get("already_finalized", true)), "finalize preflight proves the pending escrow transition without mutation")
	_expect(not bool(adapter.preflight_finalize_facility_card_escrow(str(request.get("escrow_id", "")), "0".repeat(64)).get("ready", true)), "finalize preflight rejects a stale escrow fingerprint")

	var finalized := adapter.finalize_facility_card_escrow(str(request.get("escrow_id", "")), pending_fingerprint)
	_expect(bool(finalized.get("finalized", false)) and bool(finalized.get("terminal", false)), "finalize removes the pending private record")
	player = world.players[0] as Dictionary
	_expect((player.get("facility_card_escrows", {}) as Dictionary).is_empty(), "finalize clears the pending escrow map")
	var receipts: Dictionary = player.get("facility_card_escrow_receipts", {}) as Dictionary
	var receipt: Dictionary = receipts.get(str(request.get("escrow_id", "")), {}) as Dictionary
	var receipt_text := JSON.stringify(receipt)
	_expect(str(receipt.get("state_id", "")) == "consumed_finalized" and not receipt_text.contains("card_record") and not receipt_text.contains("machine") and not receipt_text.contains("developer"), "terminal receipt contains no private card body")
	var finalize_replay := adapter.finalize_facility_card_escrow(str(request.get("escrow_id", "")), pending_fingerprint)
	_expect(bool(finalize_replay.get("finalized", false)) and bool(finalize_replay.get("idempotent_replay", false)), "finalize terminal replay is idempotent")
	var terminal_preflight := adapter.preflight_finalize_facility_card_escrow(
		str(request.get("escrow_id", "")),
		pending_fingerprint
	)
	_expect(bool(terminal_preflight.get("ready", false)) and bool(terminal_preflight.get("already_finalized", false)), "finalize preflight recognizes the exact terminal replay")
	_free_fixture(fixture)


func _verify_release_from_committed_and_pending(catalog: Resource) -> void:
	var committed_fixture := _fixture(catalog, "instance:release:committed", true)
	var committed_adapter: CardPlayerStateProductionAdapterV06 = committed_fixture.get("adapter")
	var committed_world: WorldSessionState = committed_fixture.get("world")
	var committed_request := _request(catalog, _slot_card(committed_world), "release.committed")
	var committed := committed_adapter.commit_facility_card_escrow(committed_adapter.plan_facility_card_escrow(committed_request))
	var released := committed_adapter.release_facility_card_escrow(
		str(committed_request.get("escrow_id", "")),
		str(committed.get("escrow_fingerprint", "")),
		"effect_prepare_failed"
	)
	var restored: Dictionary = _slot_card(committed_world)
	_expect(bool(released.get("released", false)) and str(restored.get("runtime_instance_id", "")) == "instance:release:committed", "release restores the same full card to its original slot")
	_expect(not bool(restored.get("queued_for_resolution", true)) and not restored.has("facility_card_escrow_id") and not restored.has("queue_escrow_id"), "release clears queued and escrow temporary fields")
	var release_replay := committed_adapter.release_facility_card_escrow(
		str(committed_request.get("escrow_id", "")),
		str(committed.get("escrow_fingerprint", "")),
		"effect_prepare_failed"
	)
	_expect(bool(release_replay.get("released", false)) and bool(release_replay.get("idempotent_replay", false)), "release terminal retry is idempotent")
	var release_collision := committed_adapter.release_facility_card_escrow(
		str(committed_request.get("escrow_id", "")),
		str(committed.get("escrow_fingerprint", "")),
		"different_failure"
	)
	_expect(str(release_collision.get("reason_code", "")) == "facility_card_escrow_release_collision", "same release identity with a different reason fails closed")
	_free_fixture(committed_fixture)

	var pending_fixture := _fixture(catalog, "instance:release:pending")
	var pending_adapter: CardPlayerStateProductionAdapterV06 = pending_fixture.get("adapter")
	var pending_world: WorldSessionState = pending_fixture.get("world")
	var pending_request := _request(catalog, _slot_card(pending_world), "release.pending")
	var pending_commit := pending_adapter.commit_facility_card_escrow(pending_adapter.plan_facility_card_escrow(pending_request))
	var consumed := pending_adapter.consume_facility_card_escrow(str(pending_request.get("escrow_id", "")), str(pending_commit.get("escrow_fingerprint", "")))
	var pending_release := pending_adapter.release_facility_card_escrow(
		str(pending_request.get("escrow_id", "")),
		str(consumed.get("escrow_fingerprint", "")),
		"asset_commit_failed"
	)
	_expect(bool(pending_release.get("released", false)) and str(_slot_card(pending_world).get("runtime_instance_id", "")) == "instance:release:pending", "release rolls a consumed-pending escrow back to the original slot")
	_free_fixture(pending_fixture)


func _verify_finalized_compensation(catalog: Resource) -> void:
	var fixture := _fixture(catalog, "instance:compensate:finalized")
	var adapter: CardPlayerStateProductionAdapterV06 = fixture.get("adapter")
	var world: WorldSessionState = fixture.get("world")
	var original_card := _slot_card(world)
	var request := _request(catalog, original_card, "compensate.finalized")
	var committed := adapter.commit_facility_card_escrow(
		adapter.plan_facility_card_escrow(request)
	)
	var consumed := adapter.consume_facility_card_escrow(
		str(request.get("escrow_id", "")),
		str(committed.get("escrow_fingerprint", ""))
	)
	var finalized := adapter.finalize_facility_card_escrow(
		str(request.get("escrow_id", "")),
		str(consumed.get("escrow_fingerprint", ""))
	)
	var before_hostile := world.players.duplicate(true)
	var forged := adapter.compensate_finalized_facility_card_escrow(
		str(request.get("escrow_id", "")),
		"0".repeat(64),
		original_card,
		"facility_effect_finalize_failed"
	)
	_expect(not bool(forged.get("compensated", false)) and world.players == before_hostile, "finalized compensation rejects a forged terminal receipt fingerprint without mutation")
	var changed_card := original_card.duplicate(true)
	changed_card["cooldown_left"] = 99.0
	var changed := adapter.compensate_finalized_facility_card_escrow(
		str(request.get("escrow_id", "")),
		str(finalized.get("receipt_fingerprint", "")),
		changed_card,
		"facility_effect_finalize_failed"
	)
	_expect(not bool(changed.get("compensated", false)) and world.players == before_hostile, "finalized compensation rejects changed private card state without mutation")
	var compensated := adapter.compensate_finalized_facility_card_escrow(
		str(request.get("escrow_id", "")),
		str(finalized.get("receipt_fingerprint", "")),
		original_card,
		"facility_effect_finalize_failed"
	)
	var terminal := adapter.facility_card_escrow_snapshot(str(request.get("escrow_id", "")))
	_expect(bool(compensated.get("compensated", false)) and bool(compensated.get("released", false)) \
			and _slot_card(world) == original_card, "exact finalized compensation restores the detached original card once")
	_expect(bool(terminal.get("terminal", false)) \
			and str((terminal.get("receipt", {}) as Dictionary).get("state_id", "")) == "released" \
			and not JSON.stringify(terminal).contains("card_record"), "compensation replaces the consumed receipt with one private-body-free released terminal receipt")
	_free_fixture(fixture)


func _verify_replay_collision_and_slot_drift(catalog: Resource) -> void:
	var fixture := _fixture(catalog, "instance:collision:1")
	var adapter: CardPlayerStateProductionAdapterV06 = fixture.get("adapter")
	var world: WorldSessionState = fixture.get("world")
	var request := _request(catalog, _slot_card(world), "collision")
	var plan := adapter.plan_facility_card_escrow(request)
	var committed := adapter.commit_facility_card_escrow(plan)
	var plan_replay := adapter.plan_facility_card_escrow(request)
	_expect(bool(plan_replay.get("planned", false)) and bool(plan_replay.get("idempotent_replay", false)), "same escrow and request identity plans idempotently after commit")
	var collision := request.duplicate(true)
	collision["intent_fingerprint"] = _fingerprint({"intent": "collision.changed"})
	var before_collision := world.players.duplicate(true)
	var collision_result := adapter.plan_facility_card_escrow(collision)
	_expect(str(collision_result.get("reason_code", "")) == "facility_card_escrow_collision" and world.players == before_collision, "same escrow ID with changed intent rejects without World mutation")
	var request_collision := request.duplicate(true)
	request_collision["escrow_id"] = "escrow.collision.other"
	var request_collision_result := adapter.plan_facility_card_escrow(request_collision)
	_expect(str(request_collision_result.get("reason_code", "")) == "facility_card_escrow_collision", "same request ID cannot bind a second escrow ID")
	_expect(bool(committed.get("committed", false)), "collision fixture committed before hostile replay")
	_free_fixture(fixture)

	var drift_fixture := _fixture(catalog, "instance:drift:1")
	var drift_adapter: CardPlayerStateProductionAdapterV06 = drift_fixture.get("adapter")
	var drift_world: WorldSessionState = drift_fixture.get("world")
	var drift_request := _request(catalog, _slot_card(drift_world), "drift")
	var drift_plan := drift_adapter.plan_facility_card_escrow(drift_request)
	var drift_players := drift_world.players.duplicate(true)
	(((drift_players[0] as Dictionary).get("slots", []) as Array)[0] as Dictionary)["runtime_instance_id"] = "instance:drift:replacement"
	drift_world.players = drift_players
	var drift_result := drift_adapter.commit_facility_card_escrow(drift_plan)
	_expect(not bool(drift_result.get("committed", false)) and (drift_world.players[0] as Dictionary).get("facility_card_escrows", {}).is_empty(), "slot/card replacement after plan fails CAS without creating escrow")
	_free_fixture(drift_fixture)

	var occupied_fixture := _fixture(catalog, "instance:occupied:1")
	var occupied_adapter: CardPlayerStateProductionAdapterV06 = occupied_fixture.get("adapter")
	var occupied_world: WorldSessionState = occupied_fixture.get("world")
	var occupied_request := _request(catalog, _slot_card(occupied_world), "occupied")
	var occupied_commit := occupied_adapter.commit_facility_card_escrow(occupied_adapter.plan_facility_card_escrow(occupied_request))
	var occupied_players := occupied_world.players.duplicate(true)
	((occupied_players[0] as Dictionary).get("slots", []) as Array)[0] = _card(catalog, "instance:occupied:replacement")
	occupied_world.players = occupied_players
	var occupied_release := occupied_adapter.release_facility_card_escrow(str(occupied_request.get("escrow_id", "")), str(occupied_commit.get("escrow_fingerprint", "")), "effect_failed")
	_expect(str(occupied_release.get("reason_code", "")) == "facility_card_escrow_release_slot_occupied" and bool(occupied_adapter.facility_card_escrow_snapshot(str(occupied_request.get("escrow_id", ""))).get("found", false)), "occupied original slot fails closed without losing escrow")
	_free_fixture(occupied_fixture)


func _verify_catalog_purity_and_instance_guards(catalog: Resource) -> void:
	var mutated_fixture := _fixture(catalog, "instance:catalog:1")
	var mutated_adapter: CardPlayerStateProductionAdapterV06 = mutated_fixture.get("adapter")
	var mutated_world: WorldSessionState = mutated_fixture.get("world")
	var mutated_players := mutated_world.players.duplicate(true)
	var mutated_card: Dictionary = ((mutated_players[0] as Dictionary).get("slots", []) as Array)[0] as Dictionary
	(mutated_card.get("player", {}) as Dictionary)["effect"] = "hostile catalog mutation"
	mutated_world.players = mutated_players
	var mutated_request := _request(catalog, mutated_card, "catalog.mutation")
	var mutated_result := mutated_adapter.plan_facility_card_escrow(mutated_request)
	_expect(str(mutated_result.get("reason_code", "")) == "facility_card_escrow_catalog_record_mismatch", "same-ID player/developer/catalog mutation fails closed")
	_free_fixture(mutated_fixture)

	var empty_fixture := _fixture(catalog, "")
	var empty_adapter: CardPlayerStateProductionAdapterV06 = empty_fixture.get("adapter")
	var empty_world: WorldSessionState = empty_fixture.get("world")
	var empty_request := _request(catalog, _slot_card(empty_world), "empty.instance")
	var empty_result := empty_adapter.plan_facility_card_escrow(empty_request)
	_expect(not bool(empty_result.get("planned", false)) and str(empty_result.get("reason_code", "")).contains("runtime_instance_id"), "empty runtime instance is never synthesized")
	_free_fixture(empty_fixture)

	var impure_fixture := _fixture(catalog, "instance:impure:1")
	var impure_adapter: CardPlayerStateProductionAdapterV06 = impure_fixture.get("adapter")
	var impure_world: WorldSessionState = impure_fixture.get("world")
	var impure_players := impure_world.players.duplicate(true)
	var impure_card: Dictionary = ((impure_players[0] as Dictionary).get("slots", []) as Array)[0] as Dictionary
	var impure_node := Node.new()
	impure_card["hostile_node"] = impure_node
	impure_world.players = impure_players
	var impure_request := _request(catalog, impure_card, "impure")
	var impure_result := impure_adapter.plan_facility_card_escrow(impure_request)
	_expect(not bool(impure_result.get("planned", false)), "Node-bearing card data is rejected")
	impure_node.free()
	_free_fixture(impure_fixture)


func _verify_restore_like_roundtrip(catalog: Resource) -> void:
	var fixture := _fixture(catalog, "instance:restore:1")
	var adapter: CardPlayerStateProductionAdapterV06 = fixture.get("adapter")
	var world: WorldSessionState = fixture.get("world")
	var request := _request(catalog, _slot_card(world), "restore")
	var committed := adapter.commit_facility_card_escrow(adapter.plan_facility_card_escrow(request))
	var saved_players := world.players.duplicate(true)
	var restored_world := TestWorld.new()
	restored_world.players = saved_players.duplicate(true)
	var restored_assets := _asset_owner()
	var restored_adapter := ADAPTER_SCRIPT.new() as CardPlayerStateProductionAdapterV06
	restored_adapter.configure(catalog, restored_assets)
	restored_adapter.set_world_session_state(restored_world)
	var restored_snapshot := restored_adapter.facility_card_escrow_snapshot(str(request.get("escrow_id", "")))
	_expect(bool(restored_snapshot.get("found", false)) and str((restored_snapshot.get("escrow", {}) as Dictionary).get("escrow_fingerprint", "")) == str(committed.get("escrow_fingerprint", "")), "deep-copied World player state restores the exact private escrow")
	var restored_release := restored_adapter.release_facility_card_escrow(str(request.get("escrow_id", "")), str(committed.get("escrow_fingerprint", "")), "cold_restore_rollback")
	_expect(bool(restored_release.get("released", false)) and str(_slot_card(restored_world).get("runtime_instance_id", "")) == "instance:restore:1", "restored adapter can roll back the saved escrow without a local mirror")
	restored_adapter.free()
	restored_world.free()
	restored_assets.free()
	_free_fixture(fixture)


func _verify_candidate_world_preflight(catalog: Resource) -> void:
	var fixture := _fixture(catalog, "instance:preflight:1")
	var adapter: CardPlayerStateProductionAdapterV06 = fixture.get("adapter")
	var world: WorldSessionState = fixture.get("world")
	var request := _request(catalog, _slot_card(world), "preflight")
	var committed := adapter.commit_facility_card_escrow(adapter.plan_facility_card_escrow(request))
	var accepted := adapter.preflight_facility_card_escrow_world_state({"players": world.players.duplicate(true)})
	_expect(bool(committed.get("committed", false)) and bool(accepted.get("accepted", false)) \
		and int(accepted.get("active_escrow_count", 0)) == 1, "detached candidate world preflight accepts one exact catalog-bound escrow")

	var resigned_world := {"players": world.players.duplicate(true)}
	var resigned_player := ((resigned_world.get("players") as Array)[0] as Dictionary)
	var resigned_escrows := resigned_player.get("facility_card_escrows") as Dictionary
	var resigned_record := resigned_escrows.get(str(request.get("escrow_id", ""))) as Dictionary
	var resigned_card := resigned_record.get("card_record") as Dictionary
	(resigned_card.get("player") as Dictionary)["effect"] = "hostile resigned presentation"
	resigned_record["source_slot_fingerprint"] = _fingerprint(resigned_card)
	resigned_record["escrow_fingerprint"] = ""
	resigned_record["escrow_fingerprint"] = _fingerprint(_without_field(resigned_record, "escrow_fingerprint"))
	var resigned_result := adapter.preflight_facility_card_escrow_world_state(resigned_world)
	_expect(not bool(resigned_result.get("accepted", true)) \
		and str(resigned_result.get("reason_code", "")) == "facility_card_escrow_catalog_record_mismatch", "same-ID escrow payload mutation remains rejected after attacker recomputes local fingerprints")

	var consumed := adapter.consume_facility_card_escrow(
		str(request.get("escrow_id", "")),
		str(committed.get("escrow_fingerprint", ""))
	)
	var pending_result := adapter.preflight_facility_card_escrow_world_state({"players": world.players.duplicate(true)})
	_expect(bool(consumed.get("consumed", false)) and not bool(pending_result.get("accepted", true)) \
		and str(pending_result.get("reason_code", "")) == "facility_card_escrow_checkpoint_unstable", "consumed-pending escrow cannot become a save boundary")
	_free_fixture(fixture)


func _fixture(catalog: Resource, runtime_instance_id: String, queued := false) -> Dictionary:
	var card := _card(catalog, runtime_instance_id)
	if queued:
		card["queued_for_resolution"] = true
		card["facility_card_escrow_id"] = "temporary"
		card["queue_escrow_id"] = "temporary"
	var world := TestWorld.new()
	world.players = [{
		"actor_id": "player.0",
		"cash": 20,
		"cash_cents": 2000,
		"card_purchase_count": 0,
		"total_card_spend": 0,
		"slots": [card],
	}]
	var assets := _asset_owner()
	var adapter := ADAPTER_SCRIPT.new() as CardPlayerStateProductionAdapterV06
	adapter.configure(catalog, assets)
	adapter.set_world_session_state(world)
	return {"adapter": adapter, "world": world, "assets": assets}


func _free_fixture(fixture: Dictionary) -> void:
	(fixture.get("adapter") as Node).free()
	(fixture.get("world") as Node).free()
	(fixture.get("assets") as Node).free()


func _request(catalog: Resource, card: Dictionary, suffix: String) -> Dictionary:
	var catalog_card: Dictionary = catalog.call("card_snapshot", CARD_ID)
	return {
		"request_id": "request.%s" % suffix,
		"intent_fingerprint": _fingerprint({"intent": suffix}),
		"actor_id": "player.0",
		"actor_player_index": 0,
		"source_slot_index": 0,
		"hand_slot_id": "hand.slot.0",
		"card_semantic_id": CARD_ID,
		"runtime_instance_id": str(card.get("runtime_instance_id", "")),
		"source_record_fingerprint": _fingerprint(catalog_card),
		"source_slot_fingerprint": _fingerprint(card),
		"escrow_id": "escrow.%s" % suffix,
	}


func _slot_card(world: WorldSessionState) -> Dictionary:
	var players: Array = world.players
	if players.is_empty() or not (players[0] is Dictionary):
		return {}
	var slots: Array = (players[0] as Dictionary).get("slots", []) if (players[0] as Dictionary).get("slots", []) is Array else []
	return (slots[0] as Dictionary).duplicate(true) if not slots.is_empty() and slots[0] is Dictionary else {}


func _card(catalog: Resource, runtime_instance_id: String) -> Dictionary:
	var card: Dictionary = catalog.call("card_snapshot", CARD_ID)
	card["runtime_instance_id"] = runtime_instance_id
	return card


func _asset_owner() -> Node:
	var controller := ASSET_CONTROLLER_SCRIPT.new()
	var profile: Resource = load(PROFILE_PATH)
	controller.configure(profile.call("debug_snapshot"))
	var pools := {"0": {}}
	var remainders := {"0": {}}
	for asset_id in ASSET_IDS:
		(pools["0"] as Dictionary)[asset_id] = 5000
		(remainders["0"] as Dictionary)[asset_id] = 0
	var applied: Dictionary = controller.apply_save_data({
		"state_version": 1,
		"ruleset_id": "v0.6",
		"current_game_time": 0.0,
		"revision": 1,
		"pools_by_player": pools,
		"recovery_remainders_by_player": remainders,
		"reservations": {},
		"terminal_receipts": {},
		"advance_once_journal": {},
		"advance_once_order": [],
	})
	_expect(bool(applied.get("applied", false)), "asset owner fixture loads")
	return controller


func _fingerprint(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(_canonicalize(value)).to_utf8_buffer())
	return context.finish().hex_encode()


func _without_field(source: Dictionary, field_id: String) -> Dictionary:
	var result := source.duplicate(true)
	result.erase(field_id)
	return result


func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source: Dictionary = value
		var keys: Array = source.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		var result: Dictionary = {}
		for key_variant in keys:
			result[str(key_variant)] = _canonicalize(source.get(key_variant))
		return result
	if value is Array:
		var result: Array = []
		for item in value as Array:
			result.append(_canonicalize(item))
		return result
	return value


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CARD_PLAYER_STATE_FACILITY_ESCROW_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("CARD_PLAYER_STATE_FACILITY_ESCROW_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
