extends SceneTree

const SharedCardGroupWindowScript := preload("res://scripts/cards/shared_card_group_window.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(SharedCardGroupWindowScript.phase_for_remaining(30.0) == "organize", "30-second window starts in organize phase")
	_expect(SharedCardGroupWindowScript.phase_for_remaining(5.0) == "lock", "final five seconds are lock phase")
	_expect(not SharedCardGroupWindowScript.submissions_open(5.0), "lock phase rejects new cards")
	_expect(SharedCardGroupWindowScript.bidding_open(0.1), "bidding remains open through the lock phase")
	var entries := [
		_entry(0, 1, 300, 2),
		_entry(0, 2, 300, 1),
		_entry(1, 3, 200, 1),
		_entry(2, 4, 80, 1),
		_entry(3, 5, 0, 1),
	]
	var submit_state: Dictionary = SharedCardGroupWindowScript.can_submit(entries, 0, 20.0, 3)
	_expect(bool(submit_state.get("allowed", false)), "a player may add a third card during organize phase")
	var full_entries := entries.duplicate(true)
	full_entries.append(_entry(0, 6, 300, 3))
	var full_state: Dictionary = SharedCardGroupWindowScript.can_submit(full_entries, 0, 20.0, 3)
	_expect(not bool(full_state.get("allowed", true)) and str(full_state.get("reason", "")) == "group_full", "default group stops at three cards")
	_expect(SharedCardGroupWindowScript.positive_bid_taken(entries, 3, 200), "positive bid tiers must be unique")
	var groups: Array = SharedCardGroupWindowScript.groups_from_entries(entries, 3, 4)
	var flat: Array = SharedCardGroupWindowScript.flatten_groups(groups)
	_expect(groups.size() == 4, "entries become one group per player")
	_expect(int((groups[0] as Dictionary).get("bid", 0)) == 300 and int((groups[1] as Dictionary).get("bid", 0)) == 200, "groups sort by final bid")
	_expect(int((flat[0] as Dictionary).get("player_index", -1)) == 0 and int((flat[1] as Dictionary).get("player_index", -1)) == 0, "same-player cards remain contiguous")
	_expect(int((flat[0] as Dictionary).get("group_order", 0)) == 1 and int((flat[0] as Dictionary).get("resolution_id", 0)) == 2, "player-arranged card order is preserved")
	var chain: Dictionary = SharedCardGroupWindowScript.bid_chain(groups)
	var deltas: Dictionary = chain.get("player_deltas", {}) as Dictionary
	_expect(int(chain.get("public_pool", 0)) == 300, "highest group bid enters the public monster wager pool")
	_expect(int(deltas.get("0", 0)) == -100 and int(deltas.get("1", 0)) == -120 and int(deltas.get("2", 0)) == -80, "300/200/80 bid chain produces the rulebook cash deltas")
	var public_groups: Array = SharedCardGroupWindowScript.public_group_snapshot(groups)
	_expect(not _contains_private_runtime_value(public_groups), "public group snapshot contains no player identity or runtime objects")
	_finish()


func _entry(player_index: int, resolution_id: int, bid: int, group_order: int) -> Dictionary:
	return {
		"player_index": player_index,
		"resolution_id": resolution_id,
		"queued_order": resolution_id,
		"window_sequence": 7,
		"group_id": SharedCardGroupWindowScript.group_id(7, player_index),
		"group_bid": bid,
		"tip": bid,
		"group_order": group_order,
	}


func _contains_private_runtime_value(value: Variant) -> bool:
	if value is Callable or value is Node or value is Object:
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) == "player_index" or _contains_private_runtime_value((value as Dictionary)[key_variant]):
				return true
	if value is Array:
		for item in value as Array:
			if _contains_private_runtime_value(item):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Shared card group window test passed.")
	else:
		push_error("Shared card group window test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
