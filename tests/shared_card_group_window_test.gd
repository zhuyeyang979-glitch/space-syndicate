extends SceneTree

const SharedCardGroupWindowScript := preload("res://scripts/cards/shared_card_group_window.gd")

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(SharedCardGroupWindowScript.TOTAL_SECONDS == 30.0, "standard v0.6 card window lasts thirty seconds")
	_expect(SharedCardGroupWindowScript.PLANNING_SECONDS == 20.0 and SharedCardGroupWindowScript.PUBLIC_BID_SECONDS == 5.0 and SharedCardGroupWindowScript.LOCK_SECONDS == 5.0, "standard cadence is 20 planning, 5 public bid, and 5 lock seconds")
	_expect(SharedCardGroupWindowScript.ORGANIZE_SECONDS == SharedCardGroupWindowScript.PLANNING_SECONDS, "organize seconds remain a read-only planning alias")
	for sequence in range(3):
		var opening: Dictionary = SharedCardGroupWindowScript.cadence_for_sequence(sequence)
		_expect(bool(opening.get("extended", false)) and int(opening.get("total_seconds", 0)) == 45 and int(opening.get("planning_seconds", 0)) == 35, "opening sequence %d uses 45/35/5/5" % sequence)
	var standard: Dictionary = SharedCardGroupWindowScript.cadence_for_sequence(3)
	_expect(not bool(standard.get("extended", true)) and int(standard.get("total_seconds", 0)) == 30, "sequence three switches to standard cadence")
	_expect(SharedCardGroupWindowScript.phase_for_remaining(30.0) == "planning", "window starts in planning phase")
	_expect(SharedCardGroupWindowScript.phase_for_remaining(10.0) == "public_bid", "middle five seconds expose public bid only")
	_expect(SharedCardGroupWindowScript.phase_for_remaining(5.0) == "lock", "final five seconds are lock phase")
	_expect(SharedCardGroupWindowScript.submissions_open(10.1) and not SharedCardGroupWindowScript.submissions_open(10.0), "submissions close at the public-bid boundary")
	_expect(SharedCardGroupWindowScript.bidding_open(10.0) and not SharedCardGroupWindowScript.bidding_open(5.0), "bidding opens only in public_bid")
	_expect(SharedCardGroupWindowScript.STANDARD_MAX_CARDS == 1 and SharedCardGroupWindowScript.MAXIMUM_WITH_EXPLICIT_CAPABILITY == 3, "ordinary limit is one and explicit capability hard limit is three")

	var entries := [
		_entry(0, 1, 2),
		_entry(0, 2, 1),
		_entry(0, 6, 3),
		_entry(1, 3, 1),
		_entry(2, 4, 1),
		_entry(3, 5, 1),
	]
	var forged_limit: Dictionary = SharedCardGroupWindowScript.can_submit([entries[0]], 0, 30.0, 3)
	_expect(not bool(forged_limit.get("allowed", true)) and int(forged_limit.get("card_limit", 0)) == 1, "requested max without capability cannot exceed one")
	var capability := {"extra_submission_capability": "qa.extra_submission", "max_cards": 3}
	var second_state: Dictionary = SharedCardGroupWindowScript.can_submit([entries[0]], 0, 30.0, 3, 5.0, 5.0, capability)
	_expect(bool(second_state.get("allowed", false)) and int(second_state.get("card_limit", 0)) == 3, "explicit capability permits a second card")
	var third_state: Dictionary = SharedCardGroupWindowScript.can_submit([entries[0], entries[1]], 0, 30.0, 3, 5.0, 5.0, capability)
	_expect(bool(third_state.get("allowed", false)), "explicit capability permits a third card")
	var full_state: Dictionary = SharedCardGroupWindowScript.can_submit([entries[0], entries[1], entries[2]], 0, 30.0, 3, 5.0, 5.0, capability)
	_expect(not bool(full_state.get("allowed", true)) and str(full_state.get("reason", "")) == "group_full", "explicit capability still stops at three cards")
	var bid_state: Dictionary = SharedCardGroupWindowScript.can_submit([], 1, 10.0)
	_expect(not bool(bid_state.get("allowed", true)) and str(bid_state.get("reason", "")) == "public_bid_phase", "public bid rejects card submission with a stable reason")

	var groups: Array = SharedCardGroupWindowScript.groups_from_entries(entries, 0, 4)
	var flat: Array = SharedCardGroupWindowScript.flatten_groups(groups)
	_expect(groups.size() == 4, "entries become one group per player")
	_expect([int((groups[0] as Dictionary).get("player_index", -1)), int((groups[1] as Dictionary).get("player_index", -1)), int((groups[2] as Dictionary).get("player_index", -1)), int((groups[3] as Dictionary).get("player_index", -1))] == [1, 2, 3, 0], "groups use rotating clockwise seat priority with reference seat last")
	_expect(int((flat[3] as Dictionary).get("player_index", -1)) == 0 and int((flat[5] as Dictionary).get("player_index", -1)) == 0, "same-player cards remain contiguous")
	_expect(int((flat[3] as Dictionary).get("resolution_id", 0)) == 2 and int((flat[3] as Dictionary).get("group_order", 0)) == 1, "player-arranged order is stable")

	var public_groups: Array = SharedCardGroupWindowScript.public_group_snapshot(groups)
	_expect(not _contains_private_runtime_value(public_groups), "public group snapshot contains no player identity or runtime objects")
	_expect(not str(public_groups).contains("priority_bid"), "public group snapshot does not acquire bid or cash ownership")
	_finish()


func _entry(player_index: int, resolution_id: int, group_order: int) -> Dictionary:
	return {
		"player_index": player_index,
		"resolution_id": resolution_id,
		"queued_order": resolution_id,
		"window_sequence": 7,
		"group_id": SharedCardGroupWindowScript.group_id(7, player_index),
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
	_checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Shared card group window test passed. checks=%d" % _checks)
	else:
		push_error("Shared card group window test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
