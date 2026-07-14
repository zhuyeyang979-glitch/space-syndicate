extends SceneTree

const CONTROLLER_SCENE := "res://scenes/runtime/CardResolutionRuntimeController.tscn"

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(CONTROLLER_SCENE) as PackedScene
	_expect(packed != null, "controller scene loads")
	if packed == null:
		_finish()
		return
	var controller := packed.instantiate() as Node
	root.add_child(controller)
	controller.call("configure", {
		"total_window_seconds": 30.0,
		"planning_seconds": 20.0,
		"public_bid_seconds": 5.0,
		"lock_seconds": 5.0,
		"opening_extended_windows": 3,
		"opening_total_window_seconds": 45.0,
		"opening_planning_seconds": 35.0,
		"display_seconds": 5.0,
		"counter_seconds": 5.0,
	})
	var idle_facts := _facts(true, false)
	var queue_facts := _facts(false, false)
	_expect(str(controller.call("current_phase", idle_facts)) == "idle", "empty controller reports idle")

	for sequence in range(3):
		controller.call("reset_state")
		controller.call("begin_group_window", -1.0, 2, sequence)
		_expect(is_equal_approx(float(controller.get("simultaneous_timer")), 45.0), "opening sequence %d starts at forty-five seconds" % sequence)
	controller.call("reset_state")
	controller.call("begin_group_window", -1.0, 2, 3)
	_expect(is_equal_approx(float(controller.get("simultaneous_timer")), 30.0), "sequence three uses standard thirty-second cadence")
	_expect(str(controller.call("current_phase", queue_facts)) == "planning" and bool(controller.call("submissions_open", queue_facts)), "standard window starts in planning")

	controller.set("simultaneous_timer", 11.0)
	var bid_commands: Array = controller.call("tick", 2.0, queue_facts)
	_expect(str(controller.call("current_phase", queue_facts)) == "public_bid" and _transition_count(bid_commands, "enter_public_bid") == 1, "20/5/5 boundary enters public bid once")
	_expect(not bool(controller.call("submissions_open", queue_facts)) and bool(controller.call("bidding_open", queue_facts)), "public bid closes submissions and opens bidding")
	controller.set("simultaneous_timer", 6.0)
	var lock_commands: Array = controller.call("tick", 2.0, queue_facts)
	_expect(str(controller.call("current_phase", queue_facts)) == "lock" and _transition_count(lock_commands, "enter_lock") == 1, "public bid advances into lock once")
	_expect(not bool(controller.call("submissions_open", queue_facts)) and not bool(controller.call("bidding_open", queue_facts)), "lock closes submissions and bidding")

	controller.call("reset_state")
	controller.call("begin_group_window", -1.0, 0, 0)
	var large_delta_commands: Array = controller.call("tick", 60.0, queue_facts)
	var repeated_close: Array = controller.call("tick", 0.0, queue_facts)
	_expect(_transition_count(large_delta_commands, "enter_public_bid") == 1 and _transition_count(large_delta_commands, "enter_lock") == 1 and _transition_count(large_delta_commands, "lock_batch") == 1, "large delta emits every phase boundary and final lock exactly once")
	_expect(_transition_count(repeated_close, "lock_batch") == 0, "closed batch does not repeat lock command")

	controller.call("reset_state")
	controller.call("begin_group_window", -1.0, 0, 3)
	var active_players := [0, 1]
	_set_all_ready(controller, active_players)
	var ready_bid: Array = controller.call("tick", 0.0, _facts(false, false, false, "", active_players))
	_expect(_has_transition(ready_bid, "all_ready_public_bid") and str(controller.call("current_phase", queue_facts)) == "public_bid", "planning ready advances only to public bid")
	_expect((controller.get("ready_players") as Dictionary).is_empty(), "planning ready set clears at phase boundary")
	_set_all_ready(controller, active_players)
	var ready_lock: Array = controller.call("tick", 0.0, _facts(false, false, false, "", active_players))
	_expect(_has_transition(ready_lock, "all_ready_lock") and str(controller.call("current_phase", queue_facts)) == "lock", "public-bid ready advances only to lock")
	_set_all_ready(controller, active_players)
	var ready_close: Array = controller.call("tick", 0.0, _facts(false, false, false, "", active_players))
	_expect(_has_transition(ready_close, "all_ready_lock_batch") and _has_transition(ready_close, "lock_batch"), "lock ready performs the sole early batch lock")

	controller.call("reset_state")
	controller.call("begin_active_display", 0.1)
	var counterable_facts := _facts(true, true, true, "resolution_10")
	var begin_counter_commands: Array = controller.call("tick", 0.2, counterable_facts)
	_expect(_has_transition(begin_counter_commands, "begin_counter") and str(controller.call("current_phase", counterable_facts)) == "counter", "counterable active card enters counter phase")
	controller.call("reset_state")
	controller.call("begin_active_display", 0.1)
	var plain_active_facts := _facts(true, true, false, "resolution_11")
	var complete_commands: Array = controller.call("tick", 0.2, plain_active_facts)
	var repeated_complete: Array = controller.call("tick", 0.0, plain_active_facts)
	_expect(_transition_count(complete_commands, "complete_active") == 1 and _transition_count(repeated_complete, "complete_active") == 0, "active resolution completion remains exact once")

	controller.call("apply_save_data", {
		"card_resolution_timer": 3.5,
		"card_resolution_counter_window_active": false,
		"card_resolution_simultaneous_timer": 24.0,
		"card_resolution_batch_reference_player": 3,
		"card_group_window_sequence": 12,
		"last_card_resolution_player_index": 1,
	})
	var saved: Dictionary = controller.call("to_save_data")
	_expect(is_equal_approx(float(saved.get("card_resolution_simultaneous_timer", 0.0)), 24.0) and int(saved.get("card_group_window_sequence", 0)) == 12, "cadence save data round-trips timer and sequence")
	_expect(int((saved.get("card_group_cadence", {}) as Dictionary).get("total_seconds", 0)) == 30, "save data records deterministic cadence snapshot")
	controller.call("apply_save_data", {
		"card_resolution_simultaneous_timer": 0.0,
		"card_resolution_auction_timer": 4.0,
		"card_resolution_auction_open": true,
		"card_group_window_sequence": 5,
	})
	var migrated: Dictionary = controller.call("debug_snapshot")
	_expect(is_equal_approx(float(controller.get("simultaneous_timer")), 9.0) and str(migrated.get("window_phase", "")) == "public_bid", "legacy auction-only save migrates into public-bid remaining time")
	_expect(str(migrated.get("save_migration_reason", "")) == "legacy_auction_only_to_public_bid", "legacy migration is explicit")

	var external_players := [{"cash": 900}]
	controller.call("tick", 0.0, {"queue_empty": true, "active_present": false, "players": external_players})
	_expect(int((external_players[0] as Dictionary).get("cash", 0)) == 900, "controller does not mutate gameplay state")
	var snapshot: Dictionary = controller.call("debug_snapshot")
	_expect(_is_pure_data(snapshot) and _is_pure_data(saved), "debug and save snapshots contain pure data only")
	_expect(not bool(snapshot.get("owns_cards", true)) and not bool(snapshot.get("owns_cash", true)) and not bool(snapshot.get("owns_bids", true)) and not bool(snapshot.get("owns_queue", true)), "timing controller owns no gameplay state")

	controller.queue_free()
	_finish()


func _set_all_ready(controller: Node, player_indices: Array) -> void:
	for player_index_variant in player_indices:
		controller.call("set_player_ready", int(player_index_variant), true, player_indices)


func _facts(queue_empty: bool, active_present: bool, counterable: bool = false, active_id: String = "", active_players: Array = []) -> Dictionary:
	return {
		"queue_empty": queue_empty,
		"active_present": active_present,
		"active_counterable": counterable,
		"active_id": active_id,
		"lock_duration": 5.0,
		"public_bid_duration": 5.0,
		"counter_duration": 5.0,
		"active_player_indices": active_players.duplicate(),
	}


func _has_transition(commands: Array, transition: String) -> bool:
	return _transition_count(commands, transition) > 0


func _transition_count(commands: Array, transition: String) -> int:
	var count := 0
	for command_variant in commands:
		var command: Dictionary = command_variant if command_variant is Dictionary else {}
		if str(command.get("transition", "")) == transition:
			count += 1
	return count


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or value is Node or value is Object:
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not _is_pure_data(key_variant) or not _is_pure_data((value as Dictionary)[key_variant]):
				return false
	if value is Array:
		for item in value as Array:
			if not _is_pure_data(item):
				return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("CARD RESOLUTION CONTROLLER: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Card resolution runtime controller test passed. checks=%d" % _checks)
		quit(0)
		return
	push_error("Card resolution runtime controller test failed:\n- %s" % "\n- ".join(_failures))
	quit(1)
