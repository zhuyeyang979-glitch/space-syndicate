extends SceneTree

const CardResolutionMainTestHarnessScript := preload("res://tests/helpers/card_resolution_main_test_harness.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var harness := CardResolutionMainTestHarnessScript.new()
	var main := harness.create_main() as Control
	_expect(main != null, "main.gd test harness instantiates the real card-resolution controller scene")
	if main == null:
		_finish()
		return
	var submission_main := harness.create_main() as Control
	_expect(submission_main != null, "submission fixture shares the real card-resolution controller scene")
	if submission_main == null:
		main.free()
		_finish()
		return
	submission_main.set("players", [_submission_player(1000), _submission_player(1000)])
	submission_main.set("game_over", false)
	submission_main.set("districts", [])
	submission_main.set("selected_district", 0)
	submission_main.set("selected_player", 0)
	submission_main.set("card_resolution_force_simultaneous_window", 30.0)
	var submitted_first := bool(submission_main.call("_queue_skill_resolution", 0, 0, -1))
	var submitted_second := bool(submission_main.call("_queue_skill_resolution", 0, 1, -1))
	var submitted_third := bool(submission_main.call("_queue_skill_resolution", 0, 2, -1))
	var submitted_fourth := bool(submission_main.call("_queue_skill_resolution", 0, 3, -1))
	_expect(submitted_first and submitted_second and submitted_third and not submitted_fourth, "runtime submission accepts 0-3 cards per player and rejects the fourth")
	_expect(int(((submission_main.get("players") as Array)[0] as Dictionary).get("cash", 0)) == 900, "runtime submission charges the first card's action fee immediately")
	var submitted_group: Array = submission_main.get("card_resolution_queue") as Array
	_expect(submitted_group.size() == 3 and int((submitted_group[0] as Dictionary).get("group_order", 0)) == 1 and int((submitted_group[2] as Dictionary).get("group_order", 0)) == 3, "runtime submission assigns stable 1-3 group order")
	submission_main.set("card_resolution_force_simultaneous_window", 30.0)
	submission_main.set("card_resolution_simultaneous_timer", 5.0)
	var lock_phase_submission := bool(submission_main.call("_queue_skill_resolution", 1, 0, -1))
	_expect(not lock_phase_submission and ((submission_main.get("players") as Array)[1] as Dictionary).get("slots", [])[0] is Dictionary, "final five seconds reject new cards and leave them in hand")
	submission_main.free()
	main.set("players", [_player(5000), _player(5000), _player(5000), _player(5000)])
	main.set("game_over", false)
	main.set("card_resolution_batch_reference_player", 3)
	main.set("card_resolution_simultaneous_timer", 30.0)
	main.set("card_resolution_batch_locked", false)
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", _group_entries())
	main.call("_sort_card_resolution_queue")
	var sorted: Array = (main.get("card_resolution_queue") as Array).duplicate(true)
	_expect(sorted.size() == 5, "runtime queue keeps all five submitted cards")
	_expect(int((sorted[0] as Dictionary).get("player_index", -1)) == 0 and int((sorted[1] as Dictionary).get("player_index", -1)) == 0, "runtime queue keeps a player's cards contiguous")
	_expect(int((sorted[0] as Dictionary).get("resolution_id", -1)) == 2 and int((sorted[1] as Dictionary).get("resolution_id", -1)) == 1, "runtime queue respects player-arranged group order")
	var raised := bool(main.call("_set_card_bid_for_player", 2, 90, false))
	var lowered := bool(main.call("_set_card_bid_for_player", 2, 70, false))
	var duplicate_tier := bool(main.call("_set_card_bid_for_player", 2, 200, false))
	_expect(raised and not lowered and not duplicate_tier, "runtime group bid can only increase into a unique positive tier")
	main.set("card_resolution_queue", _group_entries())
	main.call("_normalize_card_resolution_queue_bids", 3)
	var chain: Dictionary = main.call("_apply_card_group_bid_chain") as Dictionary
	var players: Array = main.get("players") as Array
	_expect(int((players[0] as Dictionary).get("cash", 0)) == 4900, "highest group nets -100 in the 300/200/80 chain")
	_expect(int((players[1] as Dictionary).get("cash", 0)) == 4880, "second group nets -120 in the 300/200/80 chain")
	_expect(int((players[2] as Dictionary).get("cash", 0)) == 4920, "third group nets -80 in the 300/200/80 chain")
	_expect(int(main.get("public_card_bid_monster_wager_pool")) == 300 and int(chain.get("highest_bid", 0)) == 300, "highest group bid enters the runtime public monster wager pool")
	var state: Dictionary = main.call("_capture_run_state") as Dictionary
	_expect(int(state.get("public_card_bid_monster_wager_pool", 0)) == 300 and state.has("card_group_window_sequence"), "save state preserves the shared window sequence and public pool")
	var paid_player := _player(1000)
	main.set("players", [paid_player])
	main.call("_finish_played_skill", 0, -1, {"name": "测试承诺牌", "kind": "cash_gain", "play_cash": 100, "_play_cost_paid_on_queue": true}, 0.0)
	_expect(int(((main.get("players") as Array)[0] as Dictionary).get("cash", 0)) == 1000, "resolution cleanup does not charge a committed card twice")
	main.free()
	_finish()


func _player(cash: int) -> Dictionary:
	return {
		"name": "测试玩家",
		"cash": cash,
		"slots": [],
		"cash_history": [cash],
		"economic_ledger": [],
		"total_card_spend": 0,
		"total_card_income": 0,
		"queued_card_tip": 0,
		"action_cooldown": 0.0,
		"eliminated": false,
	}


func _submission_player(cash: int) -> Dictionary:
	var player := _player(cash)
	player["slots"] = [
		{"name": "承诺费用牌", "kind": "cash_gain", "cash": 0, "play_cash": 100},
		{"name": "组牌二", "kind": "cash_gain", "cash": 0},
		{"name": "组牌三", "kind": "cash_gain", "cash": 0},
		{"name": "组牌四", "kind": "cash_gain", "cash": 0},
	]
	return player


func _group_entries() -> Array:
	return [
		_entry(0, 1, 300, 2),
		_entry(0, 2, 300, 1),
		_entry(1, 3, 200, 1),
		_entry(2, 4, 80, 1),
		_entry(3, 5, 0, 1),
	]


func _entry(player_index: int, resolution_id: int, bid: int, order: int) -> Dictionary:
	return {
		"player_index": player_index,
		"slot_index": -1,
		"resolution_id": resolution_id,
		"queued_order": resolution_id,
		"window_sequence": 9,
		"group_id": "window_9_group_%d" % player_index,
		"group_order": order,
		"group_bid": bid,
		"tip": bid,
		"play_cost_paid_on_queue": true,
		"skill": {"name": "测试牌%d" % resolution_id, "kind": "cash_gain", "cash": 0},
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Shared card group runtime test passed.")
	else:
		push_error("Shared card group runtime test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
