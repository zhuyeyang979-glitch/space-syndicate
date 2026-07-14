@tool
extends Node
class_name CardResolutionQueueRuntimeService

const SharedCardGroupWindowScript := preload("res://scripts/cards/shared_card_group_window.gd")
const INDUSTRY_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping"]

var _ruleset_id := ""
var _configured := false
var _current_queue: Array = []
var _next_queue: Array = []
var _active_entry: Dictionary = {}
var _resolution_sequence := 0
var _revision := 0
var _plan_count := 0
var _commit_count := 0
var _rejection_count := 0
var _last_reason := ""
var _capacity_reservations_by_group: Dictionary = {}
var _reservation_transaction_ids: Dictionary = {}
var _released_reservation_ids: Dictionary = {}
var _wager_receipt_ids: Dictionary = {}
var _last_wager_receipt: Dictionary = {}


func configure(ruleset_snapshot: Dictionary) -> void:
	_ruleset_id = str(ruleset_snapshot.get("ruleset_id", ""))
	var card_group: Dictionary = ruleset_snapshot.get("card_group", {}) if ruleset_snapshot.get("card_group", {}) is Dictionary else {}
	_configured = _ruleset_id == "v0.5" \
		and int(card_group.get("group_seconds", -1)) == 8 \
		and int(card_group.get("organize_seconds", -1)) == 6 \
		and int(card_group.get("lock_seconds", -1)) == 2 \
		and card_group.get("priority_bid_options_cents", []) == SharedCardGroupWindowScript.PRIORITY_BID_OPTIONS_CENTS
	reset_state()


func reset_state() -> void:
	_current_queue.clear()
	_next_queue.clear()
	_active_entry.clear()
	_capacity_reservations_by_group.clear()
	_reservation_transaction_ids.clear()
	_released_reservation_ids.clear()
	_wager_receipt_ids.clear()
	_last_wager_receipt.clear()
	_resolution_sequence = 0
	_revision += 1
	_plan_count = 0
	_commit_count = 0
	_rejection_count = 0
	_last_reason = ""


func plan_submission(request: Dictionary, facts: Dictionary) -> Dictionary:
	_plan_count += 1
	if not _configured or not _is_data_only(request) or not _is_data_only(facts):
		return _submission_rejection("invalid_submission_request")
	var player_index := int(request.get("player_index", -1))
	var player_count := maxi(0, int(facts.get("player_count", 0)))
	if player_index < 0 or player_index >= player_count:
		return _submission_rejection("invalid_player")
	if bool(request.get("already_queued", false)):
		return _submission_rejection("duplicate_card")
	var reactive_counter := bool(request.get("reactive_counter", false)) \
		and bool(facts.get("counter_window_active", false)) \
		and not _active_entry.is_empty()
	if (bool(facts.get("batch_locked", false)) or not _active_entry.is_empty()) and not reactive_counter:
		return _submission_rejection("active_resolution")
	if reactive_counter and entry_index_for_player(player_index, true) >= 0:
		return _submission_rejection("counter_already_submitted")
	var group_count := SharedCardGroupWindowScript.group_card_count(_current_queue, player_index)
	if not reactive_counter and not _current_queue.is_empty():
		var submit_state := SharedCardGroupWindowScript.can_submit(
			_current_queue,
			player_index,
			float(facts.get("simultaneous_timer", 0.0)),
			int(request.get("group_card_limit", SharedCardGroupWindowScript.STANDARD_MAX_CARDS)),
			float(facts.get("lock_duration", SharedCardGroupWindowScript.LOCK_SECONDS))
		)
		if not bool(submit_state.get("allowed", false)):
			return _submission_rejection(str(submit_state.get("reason", "window_closed")), submit_state)
	var priority_bid_cents := int(request.get("priority_bid_cents", 0))
	if reactive_counter:
		priority_bid_cents = 0
	elif not SharedCardGroupWindowScript.valid_priority_bid_cents(priority_bid_cents):
		return _submission_rejection("invalid_priority_bid", {"allowed_bid_options_cents": SharedCardGroupWindowScript.PRIORITY_BID_OPTIONS_CENTS.duplicate()})
	var queued_index := entry_index_for_player(player_index, false)
	var existing_bid_cents := 0
	if not reactive_counter and queued_index >= 0:
		existing_bid_cents = int((_current_queue[queued_index] as Dictionary).get("priority_bid_cents", 0))
		priority_bid_cents = existing_bid_cents
	var play_cash_cost_cents := maxi(0, int(request.get("play_cash_cost_cents", 0)))
	var financial_margin_cents := maxi(0, int(request.get("financial_margin_cents", 0)))
	var available_cash_cents := maxi(0, int(request.get("available_cash_cents", 0)))
	var escrow_delta_cents := maxi(0, priority_bid_cents - existing_bid_cents)
	var financial_cash_required_cents := play_cash_cost_cents + escrow_delta_cents + financial_margin_cents
	if available_cash_cents < financial_cash_required_cents:
		return _submission_rejection(
			"insufficient_financial_margin" if financial_margin_cents > 0 else "insufficient_cost_and_bid",
			{
				"cash_required_cents": financial_cash_required_cents,
				"financial_margin_cents": financial_margin_cents,
				"priority_bid_escrow_delta_cents": escrow_delta_cents,
			}
		)
	var begins_new_batch := not reactive_counter and _current_queue.is_empty()
	var window_sequence := maxi(0, int(facts.get("window_sequence", 0))) + (1 if begins_new_batch else 0)
	var planned_resolution_id := _resolution_sequence + 1
	var group_identifier := "counter_%d" % planned_resolution_id if reactive_counter else SharedCardGroupWindowScript.group_id(window_sequence, player_index)
	var capacity_reservation: Dictionary = request.get("capacity_reservation", {}) if request.get("capacity_reservation", {}) is Dictionary else {}
	var capacity_status := _capacity_preflight(player_index, capacity_reservation, facts.get("industry_capacity", {}) as Dictionary if facts.get("industry_capacity", {}) is Dictionary else {})
	if not bool(capacity_status.get("allowed", false)):
		return _submission_rejection(str(capacity_status.get("reason", "industry_capacity_insufficient")), capacity_status)
	var reservation_id := "capacity.%d.%d" % [window_sequence, planned_resolution_id]
	var context_variant: Variant = request.get("entry_context", {})
	var entry: Dictionary = (context_variant as Dictionary).duplicate(true) if context_variant is Dictionary else {}
	var skill_variant: Variant = request.get("skill", {})
	var queued_skill: Dictionary = (skill_variant as Dictionary).duplicate(true) if skill_variant is Dictionary else {}
	if queued_skill.is_empty():
		return _submission_rejection("missing_skill")
	queued_skill["queued_for_resolution"] = true
	var consumed_on_queue := not bool(queued_skill.get("persistent", false))
	entry.merge({
		"player_index": player_index,
		"slot_index": int(request.get("slot_index", -1)),
		"queued_order": planned_resolution_id,
		"resolution_id": planned_resolution_id,
		"window_sequence": window_sequence,
		"group_id": group_identifier,
		"group_order": group_count + 1,
		"group_size": group_count + 1,
		"priority_bid_cents": priority_bid_cents,
		"priority_bid_escrowed": priority_bid_cents == 0 or existing_bid_cents == priority_bid_cents,
		"queued_behind_resolution": reactive_counter,
		"locked_priority_bid_cents": 0,
		"play_cash_cost_cents": play_cash_cost_cents,
		"play_cost_paid_on_queue": true,
		"financial_margin_cents": financial_margin_cents,
		"financial_terms_version": str(request.get("financial_terms_version", "")),
		"financial_authorized_cents": available_cash_cents,
		"financial_cash_revision": str(request.get("cash_revision", "%d" % available_cash_cents)),
		"financial_margin_locked_on_queue": false,
		"capacity_reservation": capacity_reservation.duplicate(true),
		"capacity_reservation_id": reservation_id,
		"capacity_reservation_transaction_id": "reserve.%s" % reservation_id,
		"public_owner_revealed": false,
		"public_owner_label": "",
		"guessers": [],
		"consumed_on_queue": consumed_on_queue,
		"skill": queued_skill,
	}, true)
	return {
		"accepted": true,
		"reason": "",
		"expected_revision": _revision,
		"route": "next" if reactive_counter else "current",
		"begins_new_batch": begins_new_batch,
		"next_window_sequence": window_sequence,
		"reference_player": player_index if begins_new_batch else int(facts.get("reference_player", player_index)),
		"player_count": player_count,
		"priority_bid_cents": priority_bid_cents,
		"priority_bid_escrow_delta_cents": escrow_delta_cents,
		"financial_margin_cents": financial_margin_cents,
		"financial_cash_required_cents": financial_cash_required_cents,
		"capacity_reservation": capacity_reservation.duplicate(true),
		"capacity_status": capacity_status.duplicate(true),
		"group_count_before": group_count,
		"consumed_on_queue": consumed_on_queue,
		"entry": entry,
	}


func commit_submission(plan: Dictionary, commit_receipt: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(plan) or not _is_data_only(commit_receipt):
		return _commit_rejection("invalid_submission_commit")
	if not bool(plan.get("accepted", false)):
		return _commit_rejection(str(plan.get("reason", "submission_rejected")))
	if int(plan.get("expected_revision", -1)) != _revision:
		return _commit_rejection("queue_revision_drift")
	if not bool(commit_receipt.get("authorized", false)) \
		or not bool(commit_receipt.get("inventory_committed", false)) \
		or not bool(commit_receipt.get("play_cost_authorized", false)) \
		or not bool(commit_receipt.get("financial_margin_authorized", true)) \
		or not bool(commit_receipt.get("priority_bid_escrow_authorized", true)) \
		or not bool(commit_receipt.get("capacity_authorized", true)):
		return _commit_rejection("external_commit_not_ready")
	var entry_variant: Variant = plan.get("entry", {})
	if not (entry_variant is Dictionary) or (entry_variant as Dictionary).is_empty():
		return _commit_rejection("missing_entry")
	var entry: Dictionary = (entry_variant as Dictionary).duplicate(true)
	var reservation_transaction_id := str(entry.get("capacity_reservation_transaction_id", ""))
	if not reservation_transaction_id.is_empty() and _reservation_transaction_ids.has(reservation_transaction_id):
		return _commit_rejection("capacity_reservation_duplicate")
	entry["priority_bid_escrowed"] = true
	_resolution_sequence = int(entry.get("resolution_id", _resolution_sequence + 1))
	if str(plan.get("route", "current")) == "next":
		_next_queue.append(entry)
	else:
		_current_queue.append(entry)
		_current_queue = SharedCardGroupWindowScript.with_priority_bid_cents(_current_queue, int(entry.get("player_index", -1)), int(entry.get("priority_bid_cents", 0)))
		_sort_current(int(plan.get("reference_player", -1)), int(plan.get("player_count", 0)))
	_record_capacity_reservation(entry)
	_revision += 1
	_commit_count += 1
	_last_reason = ""
	return {
		"committed": true,
		"reason": "",
		"revision": _revision,
		"entry": entry.duplicate(true),
		"route": str(plan.get("route", "current")),
		"begins_new_batch": bool(plan.get("begins_new_batch", false)),
		"next_window_sequence": int(plan.get("next_window_sequence", 0)),
		"reference_player": int(plan.get("reference_player", -1)),
		"priority_bid_escrow_delta_cents": int(plan.get("priority_bid_escrow_delta_cents", 0)),
		"capacity_reservation_id": str(entry.get("capacity_reservation_id", "")),
		"current_count": _current_queue.size(),
		"next_count": _next_queue.size(),
	}


func lock_batch(facts: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(facts) or _current_queue.is_empty() or not _active_entry.is_empty():
		return {"locked": false, "reason": "queue_not_lockable"}
	_sort_current(int(facts.get("reference_player", -1)), int(facts.get("player_count", 0)))
	for index in range(_current_queue.size()):
		var entry := (_current_queue[index] as Dictionary).duplicate(true)
		if not bool(entry.get("priority_bid_escrowed", false)):
			return {"locked": false, "reason": "priority_bid_not_escrowed"}
		entry["batch_position"] = index + 1
		entry["locked_priority_bid_cents"] = int(entry.get("priority_bid_cents", 0))
		entry["priority_bid_recipient_kind"] = "public_monster_wager_pool" if int(entry.get("priority_bid_cents", 0)) > 0 else "none"
		_current_queue[index] = entry
	var group_snapshot := groups(int(facts.get("reference_player", -1)), int(facts.get("player_count", 0)))
	var window_sequence := int((_current_queue[0] as Dictionary).get("window_sequence", 0))
	var receipt := SharedCardGroupWindowScript.public_wager_pool_receipt(group_snapshot, window_sequence)
	var receipt_id := str(receipt.get("receipt_id", ""))
	if _wager_receipt_ids.has(receipt_id):
		return {"locked": false, "reason": "wager_pool_receipt_duplicate"}
	_wager_receipt_ids[receipt_id] = true
	_last_wager_receipt = receipt.duplicate(true)
	_revision += 1
	return {
		"locked": true,
		"reason": "",
		"revision": _revision,
		"group_count": group_snapshot.size(),
		"card_count": _current_queue.size(),
		"public_wager_pool_receipt": receipt,
		"current_queue": current_queue(),
	}


func start_next(facts: Dictionary = {}) -> Dictionary:
	if not _configured or not _is_data_only(facts):
		return {"started": false, "reason": "invalid_start_request", "skipped_entries": []}
	if not _active_entry.is_empty():
		return {"started": false, "reason": "active_present", "skipped_entries": []}
	var skipped: Array = []
	var release_receipts: Array = []
	var skill_overrides: Dictionary = facts.get("skill_by_resolution_id", {}) if facts.get("skill_by_resolution_id", {}) is Dictionary else {}
	while not _current_queue.is_empty():
		var entry := (_current_queue.pop_front() as Dictionary).duplicate(true)
		var skill: Dictionary = (entry.get("skill", {}) as Dictionary).duplicate(true) if entry.get("skill", {}) is Dictionary else {}
		var resolution_key := str(int(entry.get("resolution_id", entry.get("queued_order", -1))))
		if skill.is_empty() and skill_overrides.get(resolution_key, {}) is Dictionary:
			skill = (skill_overrides.get(resolution_key, {}) as Dictionary).duplicate(true)
		if skill.is_empty():
			skipped.append(entry)
			var skipped_release := _release_group_if_complete(str(entry.get("group_id", "")))
			if not skipped_release.is_empty():
				release_receipts.append(skipped_release)
			continue
		entry["winning_priority_bid_cents"] = maxi(0, int(entry.get("priority_bid_cents", 0)))
		entry["skill"] = skill
		entry["started_time"] = float(facts.get("game_time", 0.0))
		_active_entry = entry
		_revision += 1
		return {
			"started": true,
			"reason": "",
			"revision": _revision,
			"active_entry": active_entry(),
			"skipped_entries": skipped,
			"capacity_release_receipts": release_receipts,
			"current_count": _current_queue.size(),
		}
	if not skipped.is_empty():
		_revision += 1
	return {
		"started": false,
		"reason": "batch_empty",
		"revision": _revision,
		"skipped_entries": skipped,
		"capacity_release_receipts": release_receipts,
		"batch_empty": true,
	}


func complete_active(resolution_id: int, _result: Dictionary = {}) -> Dictionary:
	if _active_entry.is_empty():
		return {"completed": false, "reason": "active_missing"}
	var active_id := int(_active_entry.get("resolution_id", _active_entry.get("queued_order", -1)))
	if resolution_id >= 0 and active_id != resolution_id:
		return {"completed": false, "reason": "active_resolution_mismatch"}
	var completed := _active_entry.duplicate(true)
	var group_identifier := str(completed.get("group_id", ""))
	_active_entry.clear()
	var release_receipt := _release_group_if_complete(group_identifier)
	_revision += 1
	return {
		"completed": true,
		"reason": "",
		"revision": _revision,
		"entry": completed,
		"capacity_release_receipt": release_receipt,
		"current_remaining": _current_queue.size(),
		"next_waiting": _next_queue.size(),
	}


func promote_next_batch(facts: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(facts):
		return {"promoted": false, "reason": "invalid_promotion_request"}
	if _next_queue.is_empty() or not _active_entry.is_empty() or not _current_queue.is_empty():
		return {"promoted": false, "reason": "next_batch_not_promotable"}
	_current_queue = _next_queue.duplicate(true)
	_next_queue.clear()
	var window_sequence := maxi(0, int(facts.get("window_sequence", 0))) + 1
	var game_time := float(facts.get("game_time", 0.0))
	for index in range(_current_queue.size()):
		var entry := (_current_queue[index] as Dictionary).duplicate(true)
		var player_index := int(entry.get("player_index", -1))
		entry["queued_behind_resolution"] = false
		entry["promoted_time"] = game_time
		entry["window_sequence"] = window_sequence
		entry["group_id"] = SharedCardGroupWindowScript.group_id(window_sequence, player_index)
		entry["group_order"] = _group_count_in_prefix(_current_queue, player_index, index) + 1
		entry["priority_bid_cents"] = 0
		entry["priority_bid_escrowed"] = true
		_current_queue[index] = entry
	_rebuild_capacity_reservations()
	var first_player := int((_current_queue[0] as Dictionary).get("player_index", -1))
	var previous_player := int(facts.get("previous_player", -1))
	var player_count := maxi(0, int(facts.get("player_count", 0)))
	var reference_player := previous_player if previous_player >= 0 and previous_player < player_count else first_player
	_sort_current(reference_player, player_count)
	_revision += 1
	return {
		"promoted": true,
		"reason": "",
		"revision": _revision,
		"window_sequence": window_sequence,
		"reference_player": reference_player,
		"previous_player": previous_player if previous_player >= 0 and previous_player < player_count else -1,
		"current_queue": current_queue(),
	}


func current_queue() -> Array:
	return _current_queue.duplicate(true)


func active_entry() -> Dictionary:
	return _active_entry.duplicate(true)


func next_queue() -> Array:
	return _next_queue.duplicate(true)


func resolution_sequence() -> int:
	return _resolution_sequence


func next_resolution_id() -> int:
	_resolution_sequence += 1
	_revision += 1
	return _resolution_sequence


func replace_state(snapshot: Dictionary) -> Dictionary:
	if not _is_data_only(snapshot):
		return queue_state_snapshot()
	var current_variant: Variant = snapshot.get("current_queue", snapshot.get("card_resolution_queue", _current_queue))
	var next_variant: Variant = snapshot.get("next_queue", snapshot.get("next_card_resolution_queue", _next_queue))
	var active_variant: Variant = snapshot.get("active_entry", snapshot.get("active_card_resolution", _active_entry))
	if current_variant is Array:
		_current_queue = (current_variant as Array).duplicate(true)
	if next_variant is Array:
		_next_queue = (next_variant as Array).duplicate(true)
	if active_variant is Dictionary:
		_active_entry = (active_variant as Dictionary).duplicate(true)
	_resolution_sequence = maxi(0, int(snapshot.get("resolution_sequence", snapshot.get("card_resolution_sequence", _resolution_sequence))))
	_reservation_transaction_ids = (snapshot.get("reservation_transaction_ids", {}) as Dictionary).duplicate(true) if snapshot.get("reservation_transaction_ids", {}) is Dictionary else {}
	_released_reservation_ids = (snapshot.get("released_reservation_ids", {}) as Dictionary).duplicate(true) if snapshot.get("released_reservation_ids", {}) is Dictionary else {}
	_wager_receipt_ids = (snapshot.get("wager_receipt_ids", {}) as Dictionary).duplicate(true) if snapshot.get("wager_receipt_ids", {}) is Dictionary else {}
	_last_wager_receipt = (snapshot.get("last_wager_receipt", {}) as Dictionary).duplicate(true) if snapshot.get("last_wager_receipt", {}) is Dictionary else {}
	_rebuild_capacity_reservations()
	_revision += 1
	return queue_state_snapshot()


func replace_current_queue(entries: Array) -> void:
	_current_queue = entries.duplicate(true)
	_rebuild_capacity_reservations()
	_revision += 1


func replace_next_queue(entries: Array) -> void:
	_next_queue = entries.duplicate(true)
	_rebuild_capacity_reservations()
	_revision += 1


func replace_active_entry(entry: Dictionary) -> void:
	_active_entry = entry.duplicate(true)
	_rebuild_capacity_reservations()
	_revision += 1


func replace_resolution_sequence(value: int) -> void:
	_resolution_sequence = maxi(0, value)
	_revision += 1


func entry_index_for_player(player_index: int, in_next_queue: bool = false) -> int:
	var entries := _next_queue if in_next_queue else _current_queue
	for index in range(entries.size()):
		if entries[index] is Dictionary and int((entries[index] as Dictionary).get("player_index", -1)) == player_index:
			return index
	return -1


func entry_by_id(resolution_id: int) -> Dictionary:
	if _entry_id(_active_entry) == resolution_id:
		return active_entry()
	for entry_variant in _current_queue:
		if entry_variant is Dictionary and _entry_id(entry_variant as Dictionary) == resolution_id:
			return (entry_variant as Dictionary).duplicate(true)
	for entry_variant in _next_queue:
		if entry_variant is Dictionary and _entry_id(entry_variant as Dictionary) == resolution_id:
			return (entry_variant as Dictionary).duplicate(true)
	return {}


func store_entry(entry: Dictionary) -> bool:
	if not _is_data_only(entry):
		return false
	var resolution_id := _entry_id(entry)
	if resolution_id < 0:
		return false
	if _entry_id(_active_entry) == resolution_id:
		_active_entry = entry.duplicate(true)
		_rebuild_capacity_reservations()
		_revision += 1
		return true
	for index in range(_current_queue.size()):
		if _entry_id(_current_queue[index] as Dictionary) == resolution_id:
			_current_queue[index] = entry.duplicate(true)
			_rebuild_capacity_reservations()
			_revision += 1
			return true
	for index in range(_next_queue.size()):
		if _entry_id(_next_queue[index] as Dictionary) == resolution_id:
			_next_queue[index] = entry.duplicate(true)
			_rebuild_capacity_reservations()
			_revision += 1
			return true
	return false


func remove_entry_by_id(resolution_id: int) -> Dictionary:
	for entries in [_next_queue, _current_queue]:
		for index in range(entries.size()):
			if _entry_id(entries[index] as Dictionary) != resolution_id:
				continue
			var removed := (entries[index] as Dictionary).duplicate(true)
			entries.remove_at(index)
			_release_group_if_complete(str(removed.get("group_id", "")))
			_revision += 1
			return removed
	return {}


func move_within_group(resolution_id: int, direction: int, player_index: int, reference_player: int, player_count: int) -> Dictionary:
	if direction == 0:
		return {"moved": false, "reason": "zero_direction"}
	var group_entries: Array = []
	for entry_variant in _current_queue:
		if entry_variant is Dictionary and int((entry_variant as Dictionary).get("player_index", -1)) == player_index:
			group_entries.append((entry_variant as Dictionary).duplicate(true))
	group_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("group_order", a.get("queued_order", 0))) < int(b.get("group_order", b.get("queued_order", 0)))
	)
	var current_position := -1
	for index in range(group_entries.size()):
		if _entry_id(group_entries[index] as Dictionary) == resolution_id:
			current_position = index
			break
	var target_position := current_position + direction
	if current_position < 0 or target_position < 0 or target_position >= group_entries.size():
		return {"moved": false, "reason": "group_boundary"}
	var swap_id := _entry_id(group_entries[target_position] as Dictionary)
	var source_order := int((group_entries[current_position] as Dictionary).get("group_order", current_position + 1))
	var target_order := int((group_entries[target_position] as Dictionary).get("group_order", target_position + 1))
	for index in range(_current_queue.size()):
		var entry := (_current_queue[index] as Dictionary).duplicate(true)
		if _entry_id(entry) == resolution_id:
			entry["group_order"] = target_order
			_current_queue[index] = entry
		elif _entry_id(entry) == swap_id:
			entry["group_order"] = source_order
			_current_queue[index] = entry
	_sort_current(reference_player, player_count)
	_revision += 1
	return {"moved": true, "reason": "", "group_size": group_entries.size(), "revision": _revision}


func set_group_priority_bid_cents(player_index: int, amount_cents: int, facts: Dictionary) -> Dictionary:
	var queued_index := entry_index_for_player(player_index, false)
	if queued_index < 0:
		return {"changed": false, "reason": "group_missing"}
	if not bool(facts.get("bidding_open", false)):
		return {"changed": false, "reason": "bidding_closed"}
	if not SharedCardGroupWindowScript.valid_priority_bid_cents(amount_cents):
		return {"changed": false, "reason": "invalid_priority_bid", "allowed_bid_options_cents": SharedCardGroupWindowScript.PRIORITY_BID_OPTIONS_CENTS.duplicate()}
	var entry := _current_queue[queued_index] as Dictionary
	var old_bid_cents := int(entry.get("priority_bid_cents", 0))
	if amount_cents <= old_bid_cents:
		return {"changed": false, "reason": "bid_not_increased", "old_bid_cents": old_bid_cents}
	var escrow_delta_cents := amount_cents - old_bid_cents
	if int(facts.get("available_cash_cents", 0)) < escrow_delta_cents:
		return {"changed": false, "reason": "insufficient_cash", "old_bid_cents": old_bid_cents}
	if not bool(facts.get("priority_bid_escrow_authorized", false)):
		return {"changed": false, "reason": "priority_bid_escrow_not_authorized", "old_bid_cents": old_bid_cents}
	_current_queue = SharedCardGroupWindowScript.with_priority_bid_cents(_current_queue, player_index, amount_cents)
	for index in range(_current_queue.size()):
		var group_entry := (_current_queue[index] as Dictionary).duplicate(true)
		if int(group_entry.get("player_index", -1)) == player_index:
			group_entry["bid_time"] = float(facts.get("game_time", 0.0))
			group_entry["priority_bid_escrowed"] = true
			_current_queue[index] = group_entry
	_sort_current(int(facts.get("reference_player", -1)), int(facts.get("player_count", 0)))
	_revision += 1
	return {
		"changed": true,
		"reason": "",
		"old_bid_cents": old_bid_cents,
		"new_bid_cents": amount_cents,
		"priority_bid_escrow_delta_cents": escrow_delta_cents,
		"revision": _revision,
	}


func sort_current(reference_player: int, player_count: int) -> Array:
	_sort_current(reference_player, player_count)
	_revision += 1
	return current_queue()


func groups(reference_player: int, player_count: int) -> Array:
	return SharedCardGroupWindowScript.groups_from_entries(_current_queue, reference_player, player_count)


func highest_priority_bid_cents() -> int:
	var highest := 0
	for entry_variant in _current_queue:
		if entry_variant is Dictionary:
			highest = maxi(highest, int((entry_variant as Dictionary).get("priority_bid_cents", 0)))
	return highest


func leading_index(reference_player: int, player_count: int) -> int:
	if _current_queue.is_empty():
		return -1
	var sorted := SharedCardGroupWindowScript.flatten_groups(SharedCardGroupWindowScript.groups_from_entries(_current_queue, reference_player, player_count))
	var leading_id := _entry_id(sorted[0] as Dictionary) if not sorted.is_empty() else -1
	for index in range(_current_queue.size()):
		if _entry_id(_current_queue[index] as Dictionary) == leading_id:
			return index
	return -1


func reserved_capacity_for_player(player_index: int) -> Dictionary:
	var result := _empty_industry_values()
	for group_variant in _capacity_reservations_by_group.values():
		if not (group_variant is Dictionary):
			continue
		var group := group_variant as Dictionary
		if int(group.get("player_index", -1)) != player_index:
			continue
		var industries: Dictionary = group.get("industries", {}) if group.get("industries", {}) is Dictionary else {}
		for industry_id_variant in INDUSTRY_IDS:
			var industry_id := str(industry_id_variant)
			result[industry_id] = int(result.get(industry_id, 0)) + maxi(0, int(industries.get(industry_id, 0)))
	return result


func queue_state_snapshot() -> Dictionary:
	return {
		"current_queue": current_queue(),
		"active_entry": active_entry(),
		"next_queue": next_queue(),
		"resolution_sequence": _resolution_sequence,
		"capacity_reservations_by_group": _capacity_reservations_by_group.duplicate(true),
		"reservation_transaction_ids": _reservation_transaction_ids.duplicate(true),
		"released_reservation_ids": _released_reservation_ids.duplicate(true),
		"wager_receipt_ids": _wager_receipt_ids.duplicate(true),
		"last_wager_receipt": _last_wager_receipt.duplicate(true),
		"revision": _revision,
	}


func public_snapshot() -> Dictionary:
	var current_public: Array = []
	for entry_variant in _current_queue:
		if entry_variant is Dictionary:
			current_public.append(_public_entry(entry_variant as Dictionary))
	var next_public: Array = []
	for entry_variant in _next_queue:
		if entry_variant is Dictionary:
			next_public.append(_public_entry(entry_variant as Dictionary))
	return {
		"current": current_public,
		"active": _public_entry(_active_entry),
		"next": next_public,
		"current_count": _current_queue.size(),
		"active_present": not _active_entry.is_empty(),
		"next_count": _next_queue.size(),
		"last_public_wager_pool_receipt": _public_wager_receipt(_last_wager_receipt),
	}


func to_legacy_save_snapshot() -> Dictionary:
	return {
		"card_resolution_queue": current_queue(),
		"next_card_resolution_queue": next_queue(),
		"active_card_resolution": active_entry(),
		"card_resolution_sequence": _resolution_sequence,
		"card_capacity_reservations_by_group": _capacity_reservations_by_group.duplicate(true),
		"card_capacity_reservation_transactions": _reservation_transaction_ids.duplicate(true),
		"card_capacity_released_reservations": _released_reservation_ids.duplicate(true),
		"card_wager_receipt_ids": _wager_receipt_ids.duplicate(true),
		"card_last_wager_receipt": _last_wager_receipt.duplicate(true),
	}


func apply_legacy_save_snapshot(data: Dictionary) -> void:
	var current := _normalize_legacy_entries(data.get("card_resolution_queue", []) as Array if data.get("card_resolution_queue", []) is Array else [])
	var next := _normalize_legacy_entries(data.get("next_card_resolution_queue", []) as Array if data.get("next_card_resolution_queue", []) is Array else [])
	var active_source: Dictionary = data.get("active_card_resolution", {}) if data.get("active_card_resolution", {}) is Dictionary else {}
	var active := _normalize_legacy_entry(active_source)
	replace_state({
		"current_queue": current,
		"next_queue": next,
		"active_entry": active,
		"resolution_sequence": maxi(0, int(data.get("card_resolution_sequence", 0))),
		"reservation_transaction_ids": (data.get("card_capacity_reservation_transactions", {}) as Dictionary).duplicate(true) if data.get("card_capacity_reservation_transactions", {}) is Dictionary else {},
		"released_reservation_ids": (data.get("card_capacity_released_reservations", {}) as Dictionary).duplicate(true) if data.get("card_capacity_released_reservations", {}) is Dictionary else {},
		"wager_receipt_ids": (data.get("card_wager_receipt_ids", {}) as Dictionary).duplicate(true) if data.get("card_wager_receipt_ids", {}) is Dictionary else {},
		"last_wager_receipt": (data.get("card_last_wager_receipt", {}) as Dictionary).duplicate(true) if data.get("card_last_wager_receipt", {}) is Dictionary else {},
	})


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"ruleset_id": _ruleset_id,
		"current_count": _current_queue.size(),
		"active_present": not _active_entry.is_empty(),
		"next_count": _next_queue.size(),
		"resolution_sequence": _resolution_sequence,
		"capacity_group_count": _capacity_reservations_by_group.size(),
		"reservation_transaction_count": _reservation_transaction_ids.size(),
		"released_reservation_count": _released_reservation_ids.size(),
		"wager_receipt_count": _wager_receipt_ids.size(),
		"revision": _revision,
		"plan_count": _plan_count,
		"commit_count": _commit_count,
		"rejection_count": _rejection_count,
		"last_reason": _last_reason,
		"timing_authority": false,
		"capacity_reservation_authority": true,
		"priority_bid_authority": true,
		"card_effect_authority": false,
		"cash_authority": false,
		"inventory_authority": false,
		"history_authority": false,
		"legacy_queue_fallback_used": false,
	}


func _capacity_preflight(player_index: int, reservation: Dictionary, capacity_snapshot: Dictionary) -> Dictionary:
	var requested: Dictionary = reservation.get("industries", {}) if reservation.get("industries", {}) is Dictionary else {}
	if requested.is_empty():
		return {"allowed": true, "reason": "", "requested": {}, "reserved_before": reserved_capacity_for_player(player_index)}
	if not bool(capacity_snapshot.get("valid", false)) or int(capacity_snapshot.get("player_index", -1)) != player_index:
		return {"allowed": false, "reason": "industry_capacity_snapshot_missing"}
	var expected_revision := str(reservation.get("capacity_revision", ""))
	if expected_revision.is_empty() or expected_revision != str(capacity_snapshot.get("capacity_revision", "")):
		return {"allowed": false, "reason": "capacity_revision_drift"}
	var reserved_before := reserved_capacity_for_player(player_index)
	var industries: Dictionary = capacity_snapshot.get("industries", {}) if capacity_snapshot.get("industries", {}) is Dictionary else {}
	var available_after := {}
	for industry_key in requested.keys():
		var industry_id := str(industry_key)
		if not INDUSTRY_IDS.has(industry_id):
			return {"allowed": false, "reason": "unknown_industry", "industry_id": industry_id}
		var amount := int(requested.get(industry_id, 0))
		if amount < 0:
			return {"allowed": false, "reason": "invalid_capacity_reservation", "industry_id": industry_id}
		var industry_row: Dictionary = industries.get(industry_id, {}) if industries.get(industry_id, {}) is Dictionary else {}
		var total := maxi(0, int(industry_row.get("total_capacity", 0)))
		var reserved := maxi(0, int(reserved_before.get(industry_id, 0)))
		if reserved + amount > total:
			return {
				"allowed": false,
				"reason": "industry_capacity_insufficient",
				"industry_id": industry_id,
				"required_capacity": amount,
				"total_capacity": total,
				"reserved_capacity": reserved,
				"available_capacity": maxi(0, total - reserved),
			}
		available_after[industry_id] = total - reserved - amount
	return {
		"allowed": true,
		"reason": "",
		"requested": requested.duplicate(true),
		"reserved_before": reserved_before,
		"available_after": available_after,
	}


func _record_capacity_reservation(entry: Dictionary) -> void:
	var transaction_id := str(entry.get("capacity_reservation_transaction_id", ""))
	if transaction_id.is_empty():
		return
	_reservation_transaction_ids[transaction_id] = true
	var reservation: Dictionary = entry.get("capacity_reservation", {}) if entry.get("capacity_reservation", {}) is Dictionary else {}
	var industries: Dictionary = reservation.get("industries", {}) if reservation.get("industries", {}) is Dictionary else {}
	if industries.is_empty():
		return
	var group_id := str(entry.get("group_id", ""))
	var group: Dictionary = _capacity_reservations_by_group.get(group_id, {
		"group_id": group_id,
		"player_index": int(entry.get("player_index", -1)),
		"industries": _empty_industry_values(),
		"reservation_ids": [],
	})
	var totals: Dictionary = group.get("industries", {}) if group.get("industries", {}) is Dictionary else _empty_industry_values()
	for industry_id_variant in INDUSTRY_IDS:
		var industry_id := str(industry_id_variant)
		totals[industry_id] = int(totals.get(industry_id, 0)) + maxi(0, int(industries.get(industry_id, 0)))
	var reservation_ids: Array = group.get("reservation_ids", []) if group.get("reservation_ids", []) is Array else []
	var reservation_id := str(entry.get("capacity_reservation_id", ""))
	if not reservation_id.is_empty() and not reservation_ids.has(reservation_id):
		reservation_ids.append(reservation_id)
	group["industries"] = totals
	group["reservation_ids"] = reservation_ids
	_capacity_reservations_by_group[group_id] = group


func _release_group_if_complete(group_id: String) -> Dictionary:
	if group_id.is_empty() or _group_is_live(group_id) or not _capacity_reservations_by_group.has(group_id):
		return {}
	var group := (_capacity_reservations_by_group.get(group_id, {}) as Dictionary).duplicate(true)
	var release_id := "release.%s" % group_id
	if _released_reservation_ids.has(release_id):
		return {}
	_released_reservation_ids[release_id] = true
	_capacity_reservations_by_group.erase(group_id)
	return {
		"transaction_id": release_id,
		"group_id": group_id,
		"player_index": int(group.get("player_index", -1)),
		"industries": (group.get("industries", {}) as Dictionary).duplicate(true) if group.get("industries", {}) is Dictionary else {},
		"released": true,
	}


func _group_is_live(group_id: String) -> bool:
	if str(_active_entry.get("group_id", "")) == group_id:
		return true
	for entries in [_current_queue, _next_queue]:
		for entry_variant in entries:
			if entry_variant is Dictionary and str((entry_variant as Dictionary).get("group_id", "")) == group_id:
				return true
	return false


func _rebuild_capacity_reservations() -> void:
	_capacity_reservations_by_group.clear()
	for entries in [_current_queue, [_active_entry] if not _active_entry.is_empty() else [], _next_queue]:
		for entry_variant in entries:
			if entry_variant is Dictionary:
				_record_capacity_reservation(entry_variant as Dictionary)


func _submission_rejection(reason: String, details: Dictionary = {}) -> Dictionary:
	_last_reason = reason
	var result := {"accepted": false, "reason": reason, "expected_revision": _revision}
	result.merge(details.duplicate(true), false)
	return result


func _commit_rejection(reason: String) -> Dictionary:
	_rejection_count += 1
	_last_reason = reason
	return {"committed": false, "reason": reason, "revision": _revision}


func _sort_current(reference_player: int, player_count: int) -> void:
	_current_queue = SharedCardGroupWindowScript.flatten_groups(
		SharedCardGroupWindowScript.groups_from_entries(_current_queue, reference_player, player_count)
	)


func _group_count_in_prefix(entries: Array, player_index: int, end_exclusive: int) -> int:
	var prefix: Array = []
	for index in range(clampi(end_exclusive, 0, entries.size())):
		prefix.append(entries[index])
	return SharedCardGroupWindowScript.group_card_count(prefix, player_index)


func _entry_id(entry: Dictionary) -> int:
	return int(entry.get("resolution_id", entry.get("queued_order", -1))) if not entry.is_empty() else -1


func _public_entry(entry: Dictionary) -> Dictionary:
	if entry.is_empty():
		return {}
	var skill: Dictionary = entry.get("skill", {}) if entry.get("skill", {}) is Dictionary else {}
	return {
		"resolution_id": _entry_id(entry),
		"card_name": str(skill.get("name", "")),
		"card_kind": str(skill.get("kind", "")),
		"selected_district": int(entry.get("selected_district", -1)),
		"contract_source_district": int(entry.get("contract_source_district", -1)),
		"contract_target_district": int(entry.get("contract_target_district", -1)),
		"group_id": str(entry.get("group_id", "")),
		"group_order": int(entry.get("group_order", 0)),
		"group_size": int(entry.get("group_size", 0)),
		"group_position": int(entry.get("group_position", 0)),
		"priority_bid_cents": int(entry.get("priority_bid_cents", 0)),
		"queued_behind_resolution": bool(entry.get("queued_behind_resolution", false)),
		"public_owner_revealed": bool(entry.get("public_owner_revealed", false)),
		"public_owner_label": str(entry.get("public_owner_label", "")) if bool(entry.get("public_owner_revealed", false)) else "",
	}


func _public_wager_receipt(receipt: Dictionary) -> Dictionary:
	if receipt.is_empty():
		return {}
	return {
		"receipt_id": str(receipt.get("receipt_id", "")),
		"window_sequence": int(receipt.get("window_sequence", 0)),
		"currency_scale": int(receipt.get("currency_scale", 100)),
		"total_cents": int(receipt.get("total_cents", 0)),
		"recipient_kind": str(receipt.get("recipient_kind", "")),
	}


func _normalize_legacy_entries(entries: Array) -> Array:
	var result: Array = []
	for entry_variant in entries:
		if entry_variant is Dictionary:
			result.append(_normalize_legacy_entry(entry_variant as Dictionary))
	return result


func _normalize_legacy_entry(source: Dictionary) -> Dictionary:
	if source.is_empty():
		return {}
	var entry := source.duplicate(true)
	if not entry.has("priority_bid_cents"):
		entry["priority_bid_cents"] = 0
	entry["priority_bid_escrowed"] = true
	entry.erase("group_bid")
	entry.erase("tip")
	entry.erase("winning_bid")
	entry.erase("locked_bid")
	entry.erase("tip_recipient")
	entry.erase("group_bid_recipient_kind")
	entry.erase("group_bid_recipient_player")
	entry.erase("group_bid_paid")
	entry.erase("tip_paid")
	entry.erase("tip_paid_amount")
	return entry


func _empty_industry_values() -> Dictionary:
	var result := {}
	for industry_id_variant in INDUSTRY_IDS:
		result[str(industry_id_variant)] = 0
	return result


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_data_only(item):
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
		return true
	return false
