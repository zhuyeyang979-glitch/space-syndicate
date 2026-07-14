extends SceneTree

const SharedCardGroupWindowScript := preload("res://scripts/cards/shared_card_group_window.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(SharedCardGroupWindowScript.TOTAL_SECONDS == 8.0, "v0.5 card-group window lasts eight seconds")
	_expect(SharedCardGroupWindowScript.ORGANIZE_SECONDS == 6.0 and SharedCardGroupWindowScript.LOCK_SECONDS == 2.0, "window owns six organize seconds and two lock seconds")
	_expect(SharedCardGroupWindowScript.phase_for_remaining(8.0) == "organize", "window starts in organize phase")
	_expect(SharedCardGroupWindowScript.phase_for_remaining(2.0) == "lock", "final two seconds are lock phase")
	_expect(not SharedCardGroupWindowScript.submissions_open(2.0) and not SharedCardGroupWindowScript.bidding_open(2.0), "lock phase rejects cards and bid changes")
	_expect(SharedCardGroupWindowScript.PRIORITY_BID_OPTIONS_CENTS == [0, 5000, 10000], "priority bids are fixed at 0/50/100 cash")
	_expect(SharedCardGroupWindowScript.valid_priority_bid_cents(5000) and not SharedCardGroupWindowScript.valid_priority_bid_cents(2500), "only authored bid tiers are legal")

	var entries := [
		_entry(0, 1, 10000, 2),
		_entry(0, 2, 10000, 1),
		_entry(1, 3, 5000, 1),
		_entry(2, 4, 5000, 1),
		_entry(3, 5, 0, 1),
	]
	var one_card_state: Dictionary = SharedCardGroupWindowScript.can_submit([entries[0]], 0, 8.0, 2)
	_expect(bool(one_card_state.get("allowed", false)), "standard play permits a second card")
	var full_state: Dictionary = SharedCardGroupWindowScript.can_submit([entries[0], entries[1]], 0, 8.0, 2)
	_expect(not bool(full_state.get("allowed", true)) and str(full_state.get("reason", "")) == "group_full", "standard group stops at two cards")
	var tutorial_state: Dictionary = SharedCardGroupWindowScript.can_submit([entries[0]], 0, 8.0, 1)
	_expect(not bool(tutorial_state.get("allowed", true)), "tutorial group stops at one card")

	var groups: Array = SharedCardGroupWindowScript.groups_from_entries(entries, 0, 4)
	var flat: Array = SharedCardGroupWindowScript.flatten_groups(groups)
	_expect(groups.size() == 4, "entries become one group per player")
	_expect(int((groups[0] as Dictionary).get("priority_bid_cents", 0)) == 10000, "highest fixed bid resolves first")
	_expect(int((groups[1] as Dictionary).get("player_index", -1)) == 1 and int((groups[2] as Dictionary).get("player_index", -1)) == 2, "equal bids use clockwise reference order")
	_expect(int((flat[0] as Dictionary).get("player_index", -1)) == 0 and int((flat[1] as Dictionary).get("player_index", -1)) == 0, "same-player cards remain contiguous")
	_expect(int((flat[0] as Dictionary).get("resolution_id", 0)) == 2 and int((flat[0] as Dictionary).get("group_order", 0)) == 1, "player-arranged order is stable")

	var receipt: Dictionary = SharedCardGroupWindowScript.public_wager_pool_receipt(groups, 7)
	_expect(int(receipt.get("total_cents", 0)) == 20000 and str(receipt.get("recipient_kind", "")) == "public_monster_wager_pool", "all group bids enter the next public monster wager pool")
	_expect((receipt.get("records", []) as Array).size() == 4, "receipt records one exact-once transaction per group including zero bids")
	var public_groups: Array = SharedCardGroupWindowScript.public_group_snapshot(groups)
	_expect(not _contains_private_runtime_value(public_groups), "public group snapshot contains no player identity or runtime objects")
	_finish()


func _entry(player_index: int, resolution_id: int, bid_cents: int, group_order: int) -> Dictionary:
	return {
		"player_index": player_index,
		"resolution_id": resolution_id,
		"queued_order": resolution_id,
		"window_sequence": 7,
		"group_id": SharedCardGroupWindowScript.group_id(7, player_index),
		"priority_bid_cents": bid_cents,
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
