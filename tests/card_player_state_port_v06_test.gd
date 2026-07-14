extends SceneTree

const PORT_SCRIPT := preload("res://scripts/cards/v06/card_player_state_port_v06.gd")
const ASSET_KEYS: Array[String] = [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_registration_and_deep_copy()
	_verify_multi_player_steal_commit()
	_verify_competing_reservations_and_abort()
	_verify_revision_cas_and_atomic_failure()
	_verify_explicit_remember_and_replay()
	_verify_localized_feedback()
	_finish()


func _verify_registration_and_deep_copy() -> void:
	var port = PORT_SCRIPT.new()
	var card := _card("commodity.ring_crystal_battery.rank_1", "card:a:ring:1")
	var registered: Dictionary = port.register_player("A", _player_state("A", 3, 11, _assets(1), [card]))
	_expect(bool(registered.get("configured", false)), "valid player state registers")
	var first_read: Dictionary = port.read_player("A")
	var first_state: Dictionary = first_read.get("player_state", {}) as Dictionary
	(first_state.get("assets", {}) as Dictionary)["life"] = 99
	var first_slots: Array = (first_state.get("inventory", {}) as Dictionary).get("slots", []) as Array
	(first_slots[0] as Dictionary)["runtime_instance_id"] = "mutated-outside-port"
	var second_state: Dictionary = port.read_player("A").get("player_state", {}) as Dictionary
	_expect(int((second_state.get("assets", {}) as Dictionary).get("life", -1)) == 1, "read_player returns a deep asset copy")
	_expect(_instance_ids(second_state) == ["card:a:ring:1"], "read_player returns a deep card copy")
	_expect(int(second_state.get("cash", -1)) == 11 and int(second_state.get("revision", -1)) == 3, "cash and revision survive registration exactly")
	_expect(_has_exact_six_assets(second_state), "registered balance contains exactly six colored assets")

	var generic_state := _player_state("G", 0, 0, _assets(0), [])
	(generic_state.get("assets", {}) as Dictionary)["generic"] = 1
	var generic_reject: Dictionary = port.register_player("G", generic_state)
	_expect(str(generic_reject.get("reason_code", "")) == "generic_asset_pool_forbidden", "a seventh generic balance is rejected")
	var duplicate_reject: Dictionary = port.register_player("B", _player_state("B", 0, 0, _assets(0), [card]))
	_expect(str(duplicate_reject.get("reason_code", "")) == "card_instance_duplicate_global", "card instance ids are globally unique")


func _verify_multi_player_steal_commit() -> void:
	var port = PORT_SCRIPT.new()
	var actor_card := _card("facility.road.rank_1", "card:a:road:1")
	var stolen_card := _card("interaction.phase_veto.rank_1", "card:b:veto:1")
	_expect(bool(port.register_player("A", _player_state("A", 0, 10, _assets(2), [actor_card])).get("configured", false)), "steal actor registers")
	_expect(bool(port.register_player("B", _player_state("B", 0, 20, _assets(4), [stolen_card])).get("configured", false)), "steal target registers")
	var reserved: Dictionary = port.reserve_transaction("tx-steal", "intent-steal", {"A": 0, "B": 0}, ["B", "A"])
	_expect(bool(reserved.get("reserved", false)), "two-player steal reserves both players atomically")
	_expect((reserved.get("actor_ids", []) as Array) == ["A", "B"], "reservation actor ids use stable sorted order")
	var duplicate_reserve: Dictionary = port.reserve_transaction("tx-steal", "intent-steal", {"A": 0, "B": 0}, ["A", "B"])
	_expect(str(duplicate_reserve.get("reservation_id", "")) == str(reserved.get("reservation_id", "")) and bool(duplicate_reserve.get("idempotent_replay", false)), "same in-flight transaction replays one reservation")

	var before: Dictionary = reserved.get("before_snapshots", {}) as Dictionary
	var next_a: Dictionary = (before.get("A", {}) as Dictionary).duplicate(true)
	var next_b: Dictionary = (before.get("B", {}) as Dictionary).duplicate(true)
	var next_a_inventory: Dictionary = (next_a.get("inventory", {}) as Dictionary).duplicate(true)
	var next_b_inventory: Dictionary = (next_b.get("inventory", {}) as Dictionary).duplicate(true)
	var next_a_slots: Array = (next_a_inventory.get("slots", []) as Array).duplicate(true)
	var next_b_slots: Array = (next_b_inventory.get("slots", []) as Array).duplicate(true)
	next_a_slots.append((next_b_slots[0] as Dictionary).duplicate(true))
	next_b_slots[0] = null
	next_a_inventory["slots"] = next_a_slots
	next_b_inventory["slots"] = next_b_slots
	next_a["inventory"] = next_a_inventory
	next_b["inventory"] = next_b_inventory
	var commit: Dictionary = port.commit_reserved(
		str(reserved.get("reservation_id", "")),
		{"A": next_a, "B": next_b},
		{"committed": true, "transaction_id": "tx-steal", "intent_hash": "intent-steal", "receipt_id": "steal-1"}
	)
	_expect(bool(commit.get("committed", false)), "multi-player steal commits once")
	var actor_after: Dictionary = port.read_player("A").get("player_state", {}) as Dictionary
	var target_after: Dictionary = port.read_player("B").get("player_state", {}) as Dictionary
	_expect(_instance_ids(actor_after) == ["card:a:road:1", "card:b:veto:1"], "actor receives the exact stolen card instance")
	_expect(_instance_ids(target_after).is_empty(), "target loses the stolen card instance")
	_expect(int(actor_after.get("revision", -1)) == 1 and int(target_after.get("revision", -1)) == 1, "both revisions advance exactly once")
	_expect(int(actor_after.get("cash", -1)) == 10 and int(target_after.get("cash", -1)) == 20, "atomic steal preserves both cash balances")
	_expect(_asset_value(actor_after, "shipping") == 7 and _asset_value(target_after, "shipping") == 9, "atomic steal preserves all six colored balances")

	var repeated_commit: Dictionary = port.commit_reserved(
		str(reserved.get("reservation_id", "")),
		{"A": next_a, "B": next_b},
		{"committed": true}
	)
	_expect(bool(repeated_commit.get("committed", false)) and bool(repeated_commit.get("idempotent_replay", false)), "repeated commit replays the journaled result")
	_expect(int((port.read_player("A").get("player_state", {}) as Dictionary).get("revision", -1)) == 1, "replayed commit does not advance revision again")
	var transaction_replay: Dictionary = port.reserve_transaction("tx-steal", "intent-steal", {"A": 0, "B": 0}, ["A", "B"])
	_expect(bool(transaction_replay.get("committed", false)) and bool(transaction_replay.get("idempotent_replay", false)), "same transaction and intent replay the terminal result")
	var collision: Dictionary = port.reserve_transaction("tx-steal", "intent-other", {"A": 1, "B": 1}, ["A", "B"])
	_expect(str(collision.get("reason_code", "")) == "transaction_intent_collision", "same transaction id with another intent is rejected")


func _verify_competing_reservations_and_abort() -> void:
	var port = PORT_SCRIPT.new()
	port.register_player("A", _player_state("A", 0, 5, _assets(0), []))
	port.register_player("B", _player_state("B", 0, 6, _assets(1), []))
	var first: Dictionary = port.reserve_transaction("tx-lock-1", "intent-lock-1", {"A": 0, "B": 0}, ["A", "B"])
	_expect(bool(first.get("reserved", false)), "first transaction reserves both players")
	var competing: Dictionary = port.reserve_transaction("tx-lock-2", "intent-lock-2", {"B": 0}, ["B"])
	_expect(str(competing.get("reason_code", "")) == "player_busy", "another transaction cannot reserve one member of a locked pair")
	var abort: Dictionary = port.abort_reserved(str(first.get("reservation_id", "")))
	_expect(bool(abort.get("aborted", false)) and not bool(abort.get("committed", true)), "abort returns a terminal non-commit result")
	_expect(int((port.read_player("A").get("player_state", {}) as Dictionary).get("revision", -1)) == 0, "abort leaves player revision unchanged")
	var after_abort: Dictionary = port.reserve_transaction("tx-lock-3", "intent-lock-3", {"B": 0}, ["B"])
	_expect(bool(after_abort.get("reserved", false)), "abort releases every player lock")
	port.abort_reserved(str(after_abort.get("reservation_id", "")))
	var abort_replay: Dictionary = port.replay_result("tx-lock-1", "intent-lock-1")
	_expect(bool(abort_replay.get("aborted", false)) and bool(abort_replay.get("idempotent_replay", false)), "aborted transaction is journaled and replayable")


func _verify_revision_cas_and_atomic_failure() -> void:
	var stale_port = PORT_SCRIPT.new()
	stale_port.register_player("A", _player_state("A", 3, 8, _assets(0), []))
	var stale: Dictionary = stale_port.reserve_transaction("tx-stale", "intent-stale", {"A": 2}, ["A"])
	_expect(str(stale.get("reason_code", "")) == "player_revision_changed", "old revision is rejected before locking")
	var stale_replay: Dictionary = stale_port.reserve_transaction("tx-stale", "intent-stale", {"A": 2}, ["A"])
	_expect(str(stale_replay.get("reason_code", "")) == "player_revision_changed" and bool(stale_replay.get("idempotent_replay", false)), "old-revision rejection is idempotently replayed")

	var port = PORT_SCRIPT.new()
	port.register_player("A", _player_state("A", 0, 8, _assets(0), [_card("commodity.a.rank_1", "card:a:1")]))
	port.register_player("B", _player_state("B", 0, 9, _assets(0), [_card("commodity.b.rank_1", "card:b:1")]))
	var reserved: Dictionary = port.reserve_transaction("tx-atomic", "intent-atomic", {"A": 0, "B": 0}, ["A", "B"])
	var before: Dictionary = reserved.get("before_snapshots", {}) as Dictionary
	var invalid_b: Dictionary = (before.get("B", {}) as Dictionary).duplicate(true)
	(invalid_b.get("assets", {}) as Dictionary)["generic"] = 1
	var rejected: Dictionary = port.commit_reserved(
		str(reserved.get("reservation_id", "")),
		{"A": (before.get("A", {}) as Dictionary).duplicate(true), "B": invalid_b},
		{"committed": true, "transaction_id": "tx-atomic", "intent_hash": "intent-atomic"}
	)
	_expect(str(rejected.get("reason_code", "")) == "generic_asset_pool_forbidden", "invalid target state rejects the whole commit")
	_expect(int((port.read_player("A").get("player_state", {}) as Dictionary).get("revision", -1)) == 0 and int((port.read_player("B").get("player_state", {}) as Dictionary).get("revision", -1)) == 0, "failed commit changes neither player")
	port.abort_reserved(str(reserved.get("reservation_id", "")), "reservation_aborted")


func _verify_explicit_remember_and_replay() -> void:
	var port = PORT_SCRIPT.new()
	var original := {"committed": true, "operation": "bench_external", "nested": {"value": 7}}
	var remembered: Dictionary = port.remember_result("tx-memory", "intent-memory", original)
	_expect(bool(remembered.get("remembered", false)), "explicit result can be journaled")
	(original.get("nested", {}) as Dictionary)["value"] = 99
	var replay: Dictionary = port.replay_result("tx-memory", "intent-memory")
	_expect(bool(replay.get("committed", false)) and int((replay.get("nested", {}) as Dictionary).get("value", -1)) == 7, "journal keeps a deep copy of the remembered result")
	(replay.get("nested", {}) as Dictionary)["value"] = 101
	var replay_again: Dictionary = port.replay_result("tx-memory", "intent-memory")
	_expect(int((replay_again.get("nested", {}) as Dictionary).get("value", -1)) == 7, "replay_result itself returns a deep copy")
	var remember_again: Dictionary = port.remember_result("tx-memory", "intent-memory", {"committed": false})
	_expect(bool(remember_again.get("remembered", false)) and bool(remember_again.get("idempotent_replay", false)), "same transaction and intent remember call is idempotent")
	var collision: Dictionary = port.replay_result("tx-memory", "intent-collision")
	_expect(str(collision.get("reason_code", "")) == "transaction_intent_collision", "journal rejects another intent for the same transaction id")


func _verify_localized_feedback() -> void:
	var port = PORT_SCRIPT.new()
	for reason_code in [
		"player_revision_changed",
		"player_busy",
		"generic_asset_pool_forbidden",
		"transaction_intent_collision",
		"reservation_missing",
		"next_states_mismatch",
		"unknown_reference_reason",
	]:
		var feedback: Dictionary = port.player_feedback(reason_code)
		var reason := str(feedback.get("reason", ""))
		var next_step := str(feedback.get("next_step", ""))
		_expect(not reason.is_empty() and not next_step.is_empty(), "%s includes localized reason and next step" % reason_code)
		_expect(not reason.contains(reason_code) and not next_step.contains(reason_code), "%s does not expose its machine reason code" % reason_code)
		_expect(not reason.contains("法力") and not next_step.contains("法力") and not reason.to_lower().contains("mana") and not next_step.to_lower().contains("mana"), "%s uses asset terminology" % reason_code)
		_expect(not feedback.has("next_action"), "%s keeps recovery text separate from player-board actions" % reason_code)


func _player_state(
	actor_id: String,
	revision: int,
	cash: int,
	assets: Dictionary,
	cards: Array
) -> Dictionary:
	return {
		"actor_id": actor_id,
		"revision": revision,
		"cash": cash,
		"assets": assets.duplicate(true),
		"inventory": {"hand_limit": 5, "slots": cards.duplicate(true)},
	}


func _assets(base: int) -> Dictionary:
	return {
		"life": base + 0,
		"energy": base + 1,
		"industry": base + 2,
		"technology": base + 3,
		"commerce": base + 4,
		"shipping": base + 5,
	}


func _card(card_id: String, runtime_instance_id: String) -> Dictionary:
	return {
		"runtime_instance_id": runtime_instance_id,
		"machine": {
			"card_id": card_id,
			"family_id": card_id.get_slice(".rank_", 0),
			"rank": 1,
			"counts_toward_hand_limit": true,
		},
		"player": {"name": "测试卡牌"},
		"developer": {"fixture": true},
	}


func _instance_ids(player_state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var inventory: Dictionary = player_state.get("inventory", {}) as Dictionary
	for slot_variant in inventory.get("slots", []) as Array:
		if slot_variant is Dictionary:
			result.append(str((slot_variant as Dictionary).get("runtime_instance_id", "")))
	return result


func _has_exact_six_assets(player_state: Dictionary) -> bool:
	var assets: Dictionary = player_state.get("assets", {}) as Dictionary
	if assets.size() != ASSET_KEYS.size() or assets.has("generic"):
		return false
	for key in ASSET_KEYS:
		if not assets.has(key):
			return false
	return true


func _asset_value(player_state: Dictionary, key: String) -> int:
	return int((player_state.get("assets", {}) as Dictionary).get(key, -1))


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CARD_PLAYER_STATE_PORT_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("CARD_PLAYER_STATE_PORT_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
