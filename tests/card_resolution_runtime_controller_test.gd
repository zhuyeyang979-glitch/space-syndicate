extends SceneTree

const CONTROLLER_SCENE := "res://scenes/runtime/CardResolutionRuntimeController.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(CONTROLLER_SCENE) as PackedScene
	_expect(packed != null, "controller scene loads")
	if packed == null:
		_finish()
		return
	var controller := packed.instantiate() as Node
	_expect(controller != null, "controller scene instantiates")
	if controller == null:
		_finish()
		return
	root.add_child(controller)
	controller.call("configure", {
		"total_window_seconds": 30.0,
		"lock_seconds": 5.0,
		"display_seconds": 5.0,
		"counter_seconds": 5.0,
	})
	var idle_facts := _facts(true, false)
	_expect(str(controller.call("current_phase", idle_facts)) == "idle", "empty controller reports idle")

	controller.call("begin_group_window", 30.0, 2, 7)
	var queue_facts := _facts(false, false)
	var organize_commands: Array = controller.call("tick", 0.0, queue_facts)
	_expect(str(controller.call("current_phase", queue_facts)) == "organize" and _has_transition(organize_commands, "show_group_window"), "30-second window starts in organize phase")
	_expect(bool(controller.call("submissions_open", queue_facts)), "organize phase accepts submissions")

	controller.set("simultaneous_timer", 6.0)
	var lock_commands: Array = controller.call("tick", 1.0, queue_facts)
	_expect(str(controller.call("current_phase", queue_facts)) == "lock" and _has_transition(lock_commands, "enter_lock"), "25/5 boundary enters lock once")
	_expect(not bool(controller.call("submissions_open", queue_facts)) and bool(controller.call("bidding_open", queue_facts)), "lock rejects cards while keeping bids open")

	controller.set("simultaneous_timer", 0.1)
	controller.set("batch_locked", false)
	var close_commands: Array = controller.call("tick", 0.2, queue_facts)
	var repeated_close_commands: Array = controller.call("tick", 0.0, queue_facts)
	_expect(_transition_count(close_commands, "lock_batch") == 1 and _transition_count(repeated_close_commands, "lock_batch") == 0, "window expiry requests lock_batch only once")

	controller.call("reset_state")
	controller.call("begin_active_display", 0.1)
	var counterable_facts := _facts(true, true, true, "resolution_10")
	var begin_counter_commands: Array = controller.call("tick", 0.2, counterable_facts)
	_expect(_has_transition(begin_counter_commands, "begin_counter") and str(controller.call("current_phase", counterable_facts)) == "counter", "counterable active card enters counter phase")

	controller.call("reset_state")
	controller.call("begin_active_display", 0.1)
	var plain_active_facts := _facts(true, true, false, "resolution_11")
	var complete_commands: Array = controller.call("tick", 0.2, plain_active_facts)
	var repeated_complete_commands: Array = controller.call("tick", 0.0, plain_active_facts)
	_expect(_transition_count(complete_commands, "complete_active") == 1 and _transition_count(repeated_complete_commands, "complete_active") == 0, "non-counterable active card completes only once")

	controller.call("reset_state")
	controller.call("begin_counter", 0.1)
	var counter_commands: Array = controller.call("tick", 0.2, counterable_facts)
	var repeated_counter_commands: Array = controller.call("tick", 0.0, counterable_facts)
	_expect(_transition_count(counter_commands, "complete_active") == 1 and _transition_count(repeated_counter_commands, "complete_active") == 0, "counter timeout completes only once")

	controller.call("reset_state")
	controller.set("batch_locked", true)
	var start_commands: Array = controller.call("tick", 0.0, queue_facts)
	var repeated_start_commands: Array = controller.call("tick", 0.0, queue_facts)
	_expect(_transition_count(start_commands, "start_next") == 1 and _transition_count(repeated_start_commands, "start_next") == 0, "locked batch requests start_next only once")

	controller.call("apply_save_data", {
		"card_resolution_timer": 3.5,
		"card_resolution_counter_window_active": true,
		"card_resolution_counter_timer": 2.5,
		"card_resolution_simultaneous_timer": 4.0,
		"card_resolution_auction_timer": 4.0,
		"card_resolution_auction_open": true,
		"card_resolution_batch_locked": false,
		"card_resolution_batch_reference_player": 3,
		"card_group_window_sequence": 12,
		"last_card_resolution_player_index": 1,
	})
	var saved: Dictionary = controller.call("to_save_data")
	_expect(is_equal_approx(float(saved.get("card_resolution_timer", 0.0)), 3.5) and int(saved.get("card_group_window_sequence", 0)) == 12, "save data round-trips existing field names")
	controller.call("apply_save_data", {
		"card_resolution_simultaneous_timer": 0.0,
		"card_resolution_auction_timer": 4.0,
		"card_resolution_auction_open": true,
	})
	_expect(is_equal_approx(float(controller.get("simultaneous_timer")), 4.0), "legacy auction-only save maps to shared-window remaining time")

	var external_players := [{"cash": 900}]
	var external_districts := [{"id": 2, "city": {"owner": 0}}]
	controller.call("tick", 0.0, {
		"queue_empty": true,
		"active_present": false,
		"players": external_players,
		"districts": external_districts,
	})
	_expect(int((external_players[0] as Dictionary).get("cash", 0)) == 900 and int((external_districts[0] as Dictionary).get("id", -1)) == 2, "controller does not mutate gameplay state")
	var snapshot: Dictionary = controller.call("debug_snapshot")
	_expect(_is_pure_data(snapshot) and _is_pure_data(saved), "debug and save snapshots contain pure data only")
	_expect(bool(snapshot.get("controller_authoritative", false)) and not bool(snapshot.get("legacy_state_fallback_used", true)), "controller identifies itself as the authoritative scene owner")

	controller.queue_free()
	_finish()


func _facts(queue_empty: bool, active_present: bool, counterable: bool = false, active_id: String = "") -> Dictionary:
	return {
		"queue_empty": queue_empty,
		"active_present": active_present,
		"active_counterable": counterable,
		"active_id": active_id,
		"lock_duration": 5.0,
		"counter_duration": 5.0,
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
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("CARD RESOLUTION CONTROLLER: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Card resolution runtime controller test passed.")
		quit(0)
		return
	push_error("Card resolution runtime controller test failed:\n- %s" % "\n- ".join(_failures))
	quit(1)
