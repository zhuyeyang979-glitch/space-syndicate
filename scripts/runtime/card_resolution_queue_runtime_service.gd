@tool
extends Node
class_name CardResolutionQueueRuntimeService

const SharedCardGroupWindowScript := preload("res://scripts/cards/shared_card_group_window.gd")

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


func configure(ruleset_snapshot: Dictionary) -> void:
	_ruleset_id = str(ruleset_snapshot.get("ruleset_id", ""))
	_configured = _ruleset_id == "v0.4"
	reset_state()


func reset_state() -> void:
	_current_queue.clear()
	_next_queue.clear()
	_active_entry.clear()
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
			int(request.get("group_card_limit", SharedCardGroupWindowScript.DEFAULT_MAX_CARDS)),
			float(facts.get("lock_duration", SharedCardGroupWindowScript.LOCK_SECONDS))
		)
		if not bool(submit_state.get("allowed", false)):
			return _submission_rejection(str(submit_state.get("reason", "window_closed")), submit_state)
	var desired_bid := maxi(0, int(request.get("desired_bid", 0)))
	if not reactive_counter:
		var queued_index := entry_index_for_player(player_index, false)
		if queued_index >= 0:
			desired_bid = int((_current_queue[queued_index] as Dictionary).get("group_bid", desired_bid))
		elif desired_bid > 0 and SharedCardGroupWindowScript.positive_bid_taken(_current_queue, player_index, desired_bid):
			desired_bid = 0
	var play_cash_cost := maxi(0, int(request.get("play_cash_cost", 0)))
	var available_cash := maxi(0, int(request.get("available_cash", 0)))
	var requested_skill: Dictionary = request.get("skill", {}) if request.get("skill", {}) is Dictionary else {}
	var financial_terms: Dictionary = requested_skill.get("futures_terms", {}) if requested_skill.get("futures_terms", {}) is Dictionary else {}
	if financial_terms.is_empty() and requested_skill.get("gdp_derivative_terms", {}) is Dictionary:
		financial_terms = (requested_skill.get("gdp_derivative_terms", {}) as Dictionary).duplicate(true)
	var financial_margin_cash := maxi(0, int(financial_terms.get("margin_cash", 0)))
	var financial_cash_required := play_cash_cost + desired_bid + financial_margin_cash
	if available_cash < financial_cash_required:
		return _submission_rejection("insufficient_financial_margin" if financial_margin_cash > 0 else "insufficient_cost_and_bid", {"cash_required": financial_cash_required, "financial_margin_cash": financial_margin_cash})
	var begins_new_batch := not reactive_counter and _current_queue.is_empty()
	var window_sequence := maxi(0, int(facts.get("window_sequence", 0))) + (1 if begins_new_batch else 0)
	var planned_resolution_id := _resolution_sequence + 1
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
		"group_id": "counter_%d" % planned_resolution_id if reactive_counter else SharedCardGroupWindowScript.group_id(window_sequence, player_index),
		"group_order": group_count + 1,
		"group_size": group_count + 1,
		"group_bid": desired_bid,
		"tip": desired_bid,
		"tip_recipient": -1,
		"queued_behind_resolution": reactive_counter,
		"winning_bid": 0,
		"play_cash_cost": play_cash_cost,
		"play_cost_paid_on_queue": true,
		"financial_margin_cash": financial_margin_cash,
		"financial_terms_version": str(financial_terms.get("terms_version", "")),
		"financial_authorized_cash": available_cash,
		"financial_cash_revision": str(request.get("cash_revision", "%d" % available_cash)),
		"financial_margin_locked_on_queue": false,
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
		"desired_bid": desired_bid,
		"financial_margin_cash": financial_margin_cash,
		"financial_cash_required": financial_cash_required,
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
		or not bool(commit_receipt.get("financial_margin_authorized", true)):
		return _commit_rejection("external_commit_not_ready")
	var entry_variant: Variant = plan.get("entry", {})
	if not (entry_variant is Dictionary) or (entry_variant as Dictionary).is_empty():
		return _commit_rejection("missing_entry")
	var entry: Dictionary = (entry_variant as Dictionary).duplicate(true)
	_resolution_sequence = int(entry.get("resolution_id", _resolution_sequence + 1))
	if str(plan.get("route", "current")) == "next":
		_next_queue.append(entry)
	else:
		_current_queue.append(entry)
		_current_queue = SharedCardGroupWindowScript.with_group_bid(_current_queue, int(entry.get("player_index", -1)), int(entry.get("group_bid", 0)))
		_sort_current(int(plan.get("reference_player", -1)), int(plan.get("player_count", 0)))
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
		"current_count": _current_queue.size(),
		"next_count": _next_queue.size(),
	}


func lock_batch(facts: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(facts) or _current_queue.is_empty() or not _active_entry.is_empty():
		return {"locked": false, "reason": "queue_not_lockable"}
	_normalize_current_bids(facts)
	_sort_current(int(facts.get("reference_player", -1)), int(facts.get("player_count", 0)))
	for index in range(_current_queue.size()):
		var entry := (_current_queue[index] as Dictionary).duplicate(true)
		entry["batch_position"] = index + 1
		entry["locked_bid"] = int(entry.get("group_bid", entry.get("tip", 0)))
		_current_queue[index] = entry
	var group_snapshot := groups(int(facts.get("reference_player", -1)), int(facts.get("player_count", 0)))
	var bid_chain := SharedCardGroupWindowScript.bid_chain(group_snapshot)
	_revision += 1
	return {
		"locked": true,
		"reason": "",
		"revision": _revision,
		"group_count": group_snapshot.size(),
		"card_count": _current_queue.size(),
		"bid_chain_plan": bid_chain.duplicate(true),
		"current_queue": current_queue(),
	}


func start_next(facts: Dictionary = {}) -> Dictionary:
	if not _configured or not _is_data_only(facts):
		return {"started": false, "reason": "invalid_start_request", "skipped_entries": []}
	if not _active_entry.is_empty():
		return {"started": false, "reason": "active_present", "skipped_entries": []}
	var skipped: Array = []
	var skill_overrides: Dictionary = facts.get("skill_by_resolution_id", {}) if facts.get("skill_by_resolution_id", {}) is Dictionary else {}
	while not _current_queue.is_empty():
		var entry := (_current_queue.pop_front() as Dictionary).duplicate(true)
		var skill: Dictionary = (entry.get("skill", {}) as Dictionary).duplicate(true) if entry.get("skill", {}) is Dictionary else {}
		var resolution_key := str(int(entry.get("resolution_id", entry.get("queued_order", -1))))
		if skill.is_empty() and skill_overrides.get(resolution_key, {}) is Dictionary:
			skill = (skill_overrides.get(resolution_key, {}) as Dictionary).duplicate(true)
		if skill.is_empty():
			skipped.append(entry)
			continue
		entry["winning_bid"] = maxi(0, int(entry.get("group_bid", entry.get("tip", 0))))
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
			"current_count": _current_queue.size(),
		}
	if not skipped.is_empty():
		_revision += 1
	return {
		"started": false,
		"reason": "batch_empty",
		"revision": _revision,
		"skipped_entries": skipped,
		"batch_empty": true,
	}


func complete_active(resolution_id: int, _result: Dictionary = {}) -> Dictionary:
	if _active_entry.is_empty():
		return {"completed": false, "reason": "active_missing"}
	var active_id := int(_active_entry.get("resolution_id", _active_entry.get("queued_order", -1)))
	if resolution_id >= 0 and active_id != resolution_id:
		return {"completed": false, "reason": "active_resolution_mismatch"}
	var completed := _active_entry.duplicate(true)
	_active_entry.clear()
	_revision += 1
	return {
		"completed": true,
		"reason": "",
		"revision": _revision,
		"entry": completed,
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
		entry["group_bid"] = int(entry.get("group_bid", entry.get("tip", 0)))
		_current_queue[index] = entry
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
	_revision += 1
	return queue_state_snapshot()


func replace_current_queue(entries: Array) -> void:
	_current_queue = entries.duplicate(true)
	_revision += 1


func replace_next_queue(entries: Array) -> void:
	_next_queue = entries.duplicate(true)
	_revision += 1


func replace_active_entry(entry: Dictionary) -> void:
	_active_entry = entry.duplicate(true)
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
		_revision += 1
		return true
	for index in range(_current_queue.size()):
		if _entry_id(_current_queue[index] as Dictionary) == resolution_id:
			_current_queue[index] = entry.duplicate(true)
			_revision += 1
			return true
	for index in range(_next_queue.size()):
		if _entry_id(_next_queue[index] as Dictionary) == resolution_id:
			_next_queue[index] = entry.duplicate(true)
			_revision += 1
			return true
	return false


func remove_entry_by_id(resolution_id: int) -> Dictionary:
	for index in range(_next_queue.size()):
		if _entry_id(_next_queue[index] as Dictionary) == resolution_id:
			var removed_next := (_next_queue[index] as Dictionary).duplicate(true)
			_next_queue.remove_at(index)
			_revision += 1
			return removed_next
	for index in range(_current_queue.size()):
		if _entry_id(_current_queue[index] as Dictionary) == resolution_id:
			var removed_current := (_current_queue[index] as Dictionary).duplicate(true)
			_current_queue.remove_at(index)
			_revision += 1
			return removed_current
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


func set_group_bid(player_index: int, amount: int, facts: Dictionary) -> Dictionary:
	var queued_index := entry_index_for_player(player_index, false)
	if queued_index < 0:
		return {"changed": false, "reason": "group_missing"}
	if not bool(facts.get("bidding_open", false)):
		return {"changed": false, "reason": "bidding_closed"}
	var clamped := maxi(0, amount)
	var entry := _current_queue[queued_index] as Dictionary
	var old_bid := int(entry.get("group_bid", entry.get("tip", 0)))
	if clamped <= old_bid:
		return {"changed": false, "reason": "bid_not_increased", "old_bid": old_bid}
	if SharedCardGroupWindowScript.positive_bid_taken(_current_queue, player_index, clamped):
		return {"changed": false, "reason": "positive_bid_taken", "old_bid": old_bid}
	if int(facts.get("available_cash", 0)) < clamped:
		return {"changed": false, "reason": "insufficient_cash", "old_bid": old_bid}
	_current_queue = SharedCardGroupWindowScript.with_group_bid(_current_queue, player_index, clamped)
	for index in range(_current_queue.size()):
		var group_entry := (_current_queue[index] as Dictionary).duplicate(true)
		if int(group_entry.get("player_index", -1)) == player_index:
			group_entry["bid_time"] = float(facts.get("game_time", 0.0))
			_current_queue[index] = group_entry
	_sort_current(int(facts.get("reference_player", -1)), int(facts.get("player_count", 0)))
	_revision += 1
	return {"changed": true, "reason": "", "old_bid": old_bid, "new_bid": clamped, "revision": _revision}


func sort_current(reference_player: int, player_count: int) -> Array:
	_sort_current(reference_player, player_count)
	_revision += 1
	return current_queue()


func normalize_bids(facts: Dictionary) -> Dictionary:
	_normalize_current_bids(facts)
	_sort_current(int(facts.get("reference_player", -1)), int(facts.get("player_count", 0)))
	_revision += 1
	return {"normalized": true, "revision": _revision, "current_queue": current_queue()}


func groups(reference_player: int, player_count: int) -> Array:
	return SharedCardGroupWindowScript.groups_from_entries(_current_queue, reference_player, player_count)


func bid_chain_plan(reference_player: int, player_count: int) -> Dictionary:
	return SharedCardGroupWindowScript.bid_chain(groups(reference_player, player_count)).duplicate(true)


func highest_bid() -> int:
	var highest := 0
	for entry_variant in _current_queue:
		if entry_variant is Dictionary:
			highest = maxi(highest, int((entry_variant as Dictionary).get("group_bid", (entry_variant as Dictionary).get("tip", 0))))
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


func apply_bid_chain_receipts(records: Array) -> void:
	var by_group := {}
	for record_variant in records:
		if record_variant is Dictionary:
			by_group[str((record_variant as Dictionary).get("group_id", ""))] = (record_variant as Dictionary).duplicate(true)
	for index in range(_current_queue.size()):
		var entry := (_current_queue[index] as Dictionary).duplicate(true)
		var record: Dictionary = by_group.get(str(entry.get("group_id", "")), {}) as Dictionary
		entry["winning_bid"] = int(entry.get("group_bid", entry.get("tip", 0)))
		entry["group_bid_paid"] = int(record.get("paid", 0))
		entry["tip_paid"] = int(record.get("paid", 0)) > 0
		entry["tip_paid_amount"] = int(record.get("paid", 0))
		entry["group_bid_recipient_kind"] = str(record.get("recipient_kind", "none"))
		entry["group_bid_recipient_player"] = int(record.get("recipient_player_index", -1))
		_current_queue[index] = entry
	_revision += 1


func queue_state_snapshot() -> Dictionary:
	return {
		"current_queue": current_queue(),
		"active_entry": active_entry(),
		"next_queue": next_queue(),
		"resolution_sequence": _resolution_sequence,
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
	}


func to_legacy_save_snapshot() -> Dictionary:
	return {
		"card_resolution_queue": current_queue(),
		"next_card_resolution_queue": next_queue(),
		"active_card_resolution": active_entry(),
		"card_resolution_sequence": _resolution_sequence,
	}


func apply_legacy_save_snapshot(data: Dictionary) -> void:
	replace_state({
		"current_queue": (data.get("card_resolution_queue", []) as Array).duplicate(true) if data.get("card_resolution_queue", []) is Array else [],
		"next_queue": (data.get("next_card_resolution_queue", []) as Array).duplicate(true) if data.get("next_card_resolution_queue", []) is Array else [],
		"active_entry": (data.get("active_card_resolution", {}) as Dictionary).duplicate(true) if data.get("active_card_resolution", {}) is Dictionary else {},
		"resolution_sequence": maxi(0, int(data.get("card_resolution_sequence", 0))),
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
		"revision": _revision,
		"plan_count": _plan_count,
		"commit_count": _commit_count,
		"rejection_count": _rejection_count,
		"last_reason": _last_reason,
		"timing_authority": false,
		"card_effect_authority": false,
		"cash_authority": false,
		"inventory_authority": false,
		"history_authority": false,
		"legacy_queue_fallback_used": false,
	}


func _submission_rejection(reason: String, details: Dictionary = {}) -> Dictionary:
	_last_reason = reason
	var result := {
		"accepted": false,
		"reason": reason,
		"expected_revision": _revision,
	}
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


func _normalize_current_bids(facts: Dictionary) -> void:
	var reference_player := int(facts.get("reference_player", -1))
	var player_count := int(facts.get("player_count", 0))
	var groups_snapshot := SharedCardGroupWindowScript.groups_from_entries(_current_queue, reference_player, player_count)
	var cash_by_player: Dictionary = facts.get("cash_by_player", {}) if facts.get("cash_by_player", {}) is Dictionary else {}
	var unpaid_by_resolution: Dictionary = facts.get("unpaid_cost_by_resolution", {}) if facts.get("unpaid_cost_by_resolution", {}) is Dictionary else {}
	var used_positive := {}
	for group_variant in groups_snapshot:
		if not (group_variant is Dictionary):
			continue
		var group := group_variant as Dictionary
		var player_index := int(group.get("player_index", -1))
		var affordable := maxi(0, int(cash_by_player.get(str(player_index), 0)))
		for entry_variant in group.get("cards", []):
			if entry_variant is Dictionary and not bool((entry_variant as Dictionary).get("play_cost_paid_on_queue", false)):
				affordable = maxi(0, affordable - maxi(0, int(unpaid_by_resolution.get(str(_entry_id(entry_variant as Dictionary)), 0))))
		var normalized := mini(maxi(0, int(group.get("bid", 0))), affordable)
		if normalized > 0 and used_positive.has(normalized):
			normalized = 0
		if normalized > 0:
			used_positive[normalized] = true
		_current_queue = SharedCardGroupWindowScript.with_group_bid(_current_queue, player_index, normalized)


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
		"target_player": int(entry.get("target_player", -1)),
		"group_id": str(entry.get("group_id", "")),
		"group_order": int(entry.get("group_order", 0)),
		"group_size": int(entry.get("group_size", 0)),
		"group_position": int(entry.get("group_position", 0)),
		"group_bid": int(entry.get("group_bid", entry.get("tip", 0))),
		"financial_margin_cash": int(entry.get("financial_margin_cash", 0)),
		"financial_terms_version": str(entry.get("financial_terms_version", "")),
		"financial_cash_revision": str(entry.get("financial_cash_revision", "")),
		"queued_behind_resolution": bool(entry.get("queued_behind_resolution", false)),
		"public_owner_revealed": bool(entry.get("public_owner_revealed", false)),
		"public_owner_label": str(entry.get("public_owner_label", "")) if bool(entry.get("public_owner_revealed", false)) else "",
	}


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
