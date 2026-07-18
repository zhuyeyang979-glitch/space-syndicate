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
var _last_group_window_sequence := -1
var _ordinary_card_limit := SharedCardGroupWindowScript.ORDINARY_MAX_CARDS
var _maximum_with_explicit_capability := SharedCardGroupWindowScript.MAXIMUM_WITH_EXPLICIT_CAPABILITY


func configure(ruleset_snapshot: Dictionary) -> void:
	_ruleset_id = str(ruleset_snapshot.get("ruleset_id", ""))
	var card_group: Dictionary = ruleset_snapshot.get("card_group", {}) if ruleset_snapshot.get("card_group", {}) is Dictionary else {}
	_configured = _ruleset_id == "v0.6" \
		and int(card_group.get("group_seconds", -1)) == 30 \
		and int(card_group.get("planning_seconds", -1)) == 20 \
		and int(card_group.get("public_bid_seconds", -1)) == 5 \
		and int(card_group.get("lock_seconds", -1)) == 5 \
		and int(card_group.get("opening_extended_windows", -1)) == 3 \
		and int(card_group.get("opening_group_seconds", -1)) == 45 \
		and int(card_group.get("opening_planning_seconds", -1)) == 35 \
		and int(card_group.get("ordinary_card_limit", card_group.get("standard_group_card_limit", -1))) == 1 \
		and int(card_group.get("maximum_with_explicit_capability", -1)) == 3
	_ordinary_card_limit = int(card_group.get("ordinary_card_limit", SharedCardGroupWindowScript.ORDINARY_MAX_CARDS))
	_maximum_with_explicit_capability = int(card_group.get("maximum_with_explicit_capability", SharedCardGroupWindowScript.MAXIMUM_WITH_EXPLICIT_CAPABILITY))
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
	_last_group_window_sequence = -1


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
		var active_window_sequence := maxi(0, int((_current_queue[0] as Dictionary).get("window_sequence", _last_group_window_sequence)))
		var capability_status := _authoritative_submission_capability(player_index, active_window_sequence, request, facts)
		var capability: Dictionary = capability_status.get("capability", {}) if capability_status.get("capability", {}) is Dictionary else {}
		var requested_limit := int(request.get("max_cards", request.get("group_card_limit", _ordinary_card_limit)))
		var submit_state := SharedCardGroupWindowScript.can_submit(
			_current_queue,
			player_index,
			float(facts.get("simultaneous_timer", 0.0)),
			requested_limit,
			float(facts.get("lock_duration", SharedCardGroupWindowScript.LOCK_SECONDS)),
			float(facts.get("public_bid_duration", SharedCardGroupWindowScript.PUBLIC_BID_SECONDS)),
			capability
		)
		submit_state["capability_reason"] = str(capability_status.get("reason", ""))
		if not bool(submit_state.get("allowed", false)):
			return _submission_rejection(str(submit_state.get("reason", "window_closed")), submit_state)
	var play_cash_cost_cents := maxi(0, int(request.get("play_cash_cost_cents", 0)))
	var financial_margin_cents := maxi(0, int(request.get("financial_margin_cents", 0)))
	var available_cash_cents := maxi(0, int(request.get("available_cash_cents", 0)))
	var financial_cash_required_cents := play_cash_cost_cents + financial_margin_cents
	if available_cash_cents < financial_cash_required_cents:
		return _submission_rejection(
			"insufficient_financial_margin" if financial_margin_cents > 0 else "insufficient_play_cost",
			{
				"cash_required_cents": financial_cash_required_cents,
				"financial_margin_cents": financial_margin_cents,
			}
		)
	var begins_new_batch := not reactive_counter and _current_queue.is_empty()
	var window_sequence := _submission_window_sequence(facts, begins_new_batch, reactive_counter)
	var planned_resolution_id := _resolution_sequence + 1
	var group_identifier := "counter_%d" % planned_resolution_id if reactive_counter else SharedCardGroupWindowScript.group_id(window_sequence, player_index)
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
		"queued_behind_resolution": reactive_counter,
		"play_cash_cost_cents": play_cash_cost_cents,
		"play_cost_paid_on_queue": true,
		"financial_margin_cents": financial_margin_cents,
		"financial_terms_version": str(request.get("financial_terms_version", "")),
		"financial_authorized_cents": available_cash_cents,
		"financial_cash_revision": str(request.get("cash_revision", "%d" % available_cash_cents)),
		"financial_margin_locked_on_queue": false,
		"asset_reservation_id": "",
		"asset_cost": {},
		"asset_debit": {},
		"asset_reservation_required": false,
		"public_owner_revealed": false,
		"public_owner_label": "",
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
		"financial_margin_cents": financial_margin_cents,
		"financial_cash_required_cents": financial_cash_required_cents,
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
		or not bool(commit_receipt.get("asset_authorized", false)):
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
		if bool(plan.get("begins_new_batch", false)):
			_last_group_window_sequence = maxi(_last_group_window_sequence, int(entry.get("window_sequence", 0)))
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
		"asset_reservation_id": str(entry.get("asset_reservation_id", "")),
		"current_count": _current_queue.size(),
		"next_count": _next_queue.size(),
	}


func lock_batch(facts: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(facts) or _current_queue.is_empty() or not _active_entry.is_empty():
		return {"locked": false, "reason": "queue_not_lockable"}
	_sort_current(int(facts.get("reference_player", -1)), int(facts.get("player_count", 0)))
	for index in range(_current_queue.size()):
		var entry := (_current_queue[index] as Dictionary).duplicate(true)
		entry["batch_position"] = index + 1
		_current_queue[index] = entry
	var group_snapshot := groups(int(facts.get("reference_player", -1)), int(facts.get("player_count", 0)))
	_revision += 1
	return {
		"locked": true,
		"reason": "",
		"revision": _revision,
		"group_count": group_snapshot.size(),
		"card_count": _current_queue.size(),
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
	var window_sequence := _next_promoted_window_sequence(facts)
	var game_time := float(facts.get("game_time", 0.0))
	for index in range(_current_queue.size()):
		var entry := (_current_queue[index] as Dictionary).duplicate(true)
		var player_index := int(entry.get("player_index", -1))
		entry["queued_behind_resolution"] = false
		entry["promoted_time"] = game_time
		entry["window_sequence"] = window_sequence
		entry["group_id"] = SharedCardGroupWindowScript.group_id(window_sequence, player_index)
		entry["group_order"] = _group_count_in_prefix(_current_queue, player_index, index) + 1
		_current_queue[index] = entry
	var first_player := int((_current_queue[0] as Dictionary).get("player_index", -1))
	var previous_player := int(facts.get("previous_player", -1))
	var player_count := maxi(0, int(facts.get("player_count", 0)))
	var reference_player := previous_player if previous_player >= 0 and previous_player < player_count else first_player
	_sort_current(reference_player, player_count)
	_last_group_window_sequence = window_sequence
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
	_last_group_window_sequence = int(snapshot.get("last_group_window_sequence", snapshot.get("card_group_last_window_sequence", _infer_last_started_window_sequence())))
	_revision += 1
	return queue_state_snapshot()


func replace_current_queue(entries: Array) -> void:
	_current_queue = entries.duplicate(true)
	_last_group_window_sequence = maxi(_last_group_window_sequence, _maximum_window_sequence(_current_queue))
	_revision += 1


func replace_next_queue(entries: Array) -> void:
	_next_queue = entries.duplicate(true)
	_revision += 1


func replace_active_entry(entry: Dictionary) -> void:
	_active_entry = entry.duplicate(true)
	_last_group_window_sequence = maxi(_last_group_window_sequence, int(_active_entry.get("window_sequence", -1)))
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
	for entries in [_next_queue, _current_queue]:
		for index in range(entries.size()):
			if _entry_id(entries[index] as Dictionary) != resolution_id:
				continue
			var removed := (entries[index] as Dictionary).duplicate(true)
			entries.remove_at(index)
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


func sort_current(reference_player: int, player_count: int) -> Array:
	_sort_current(reference_player, player_count)
	_revision += 1
	return current_queue()


func groups(reference_player: int, player_count: int) -> Array:
	return SharedCardGroupWindowScript.groups_from_entries(_current_queue, reference_player, player_count)


func leading_index(reference_player: int, player_count: int) -> int:
	if _current_queue.is_empty():
		return -1
	var sorted := SharedCardGroupWindowScript.flatten_groups(SharedCardGroupWindowScript.groups_from_entries(_current_queue, reference_player, player_count))
	var leading_id := _entry_id(sorted[0] as Dictionary) if not sorted.is_empty() else -1
	for index in range(_current_queue.size()):
		if _entry_id(_current_queue[index] as Dictionary) == leading_id:
			return index
	return -1


func queue_state_snapshot() -> Dictionary:
	return {
		"current_queue": current_queue(),
		"active_entry": active_entry(),
		"next_queue": next_queue(),
		"resolution_sequence": _resolution_sequence,
		"last_group_window_sequence": _last_group_window_sequence,
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
		"card_group_last_window_sequence": _last_group_window_sequence,
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
		"last_group_window_sequence": int(data.get("card_group_last_window_sequence", _infer_started_sequence_from_entries(current, active))),
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
		"last_group_window_sequence": _last_group_window_sequence,
		"ordinary_card_limit": _ordinary_card_limit,
		"maximum_with_explicit_capability": _maximum_with_explicit_capability,
		"revision": _revision,
		"plan_count": _plan_count,
		"commit_count": _commit_count,
		"rejection_count": _rejection_count,
		"last_reason": _last_reason,
		"timing_authority": false,
		"asset_reservation_authority": false,
		"priority_bid_authority": false,
		"card_effect_authority": false,
		"cash_authority": false,
		"inventory_authority": false,
		"history_authority": false,
		"legacy_queue_fallback_used": false,
	}


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


func _authoritative_submission_capability(player_index: int, window_sequence: int, request: Dictionary, facts: Dictionary) -> Dictionary:
	var capability_variant: Variant = facts.get("extra_submission_capability", {})
	if not bool(facts.get("extra_submission_capability_authoritative", false)) or not (capability_variant is Dictionary):
		return {"valid": false, "reason": "authoritative_capability_missing", "capability": {}}
	var capability := (capability_variant as Dictionary).duplicate(true)
	var capability_id := str(capability.get("capability_id", "")).strip_edges()
	var actor_id := str(request.get("actor_id", "")).strip_edges()
	var owner_revision := int(capability.get("owner_revision", -1))
	var current_owner_revision := int(facts.get("extra_submission_capability_owner_revision", -2))
	var activation_sequence := int(capability.get("activation_window_sequence", -1))
	var expiry_sequence := int(capability.get("expiry_window_sequence", -1))
	var base_limit := int(capability.get("base_limit", -1))
	var bonus_limit := int(capability.get("bonus_limit", -1))
	var hard_cap := int(capability.get("hard_cap", -1))
	var expected_effective := clampi(base_limit + bonus_limit, _ordinary_card_limit, _maximum_with_explicit_capability)
	var checks := [
		{"ok": not capability_id.is_empty(), "reason": "capability_id_missing"},
		{"ok": not actor_id.is_empty() and str(capability.get("actor_id", "")) == actor_id, "reason": "capability_actor_mismatch"},
		{"ok": int(capability.get("player_index", -1)) == player_index, "reason": "capability_player_mismatch"},
		{"ok": int(capability.get("window_sequence", -1)) == window_sequence, "reason": "capability_window_mismatch"},
		{"ok": owner_revision >= 0 and owner_revision == current_owner_revision, "reason": "capability_revision_stale"},
		{"ok": activation_sequence >= 0 and window_sequence >= activation_sequence, "reason": "capability_not_active"},
		{"ok": expiry_sequence >= activation_sequence and window_sequence <= expiry_sequence, "reason": "capability_expired"},
		{"ok": base_limit == _ordinary_card_limit, "reason": "capability_base_limit_invalid"},
		{"ok": bonus_limit > 0, "reason": "capability_bonus_invalid"},
		{"ok": hard_cap == _maximum_with_explicit_capability, "reason": "capability_hard_cap_invalid"},
		{"ok": int(capability.get("effective_limit", -1)) == expected_effective, "reason": "capability_effective_limit_invalid"},
	]
	for check_variant in checks:
		var check := check_variant as Dictionary
		if not bool(check.get("ok", false)):
			return {"valid": false, "reason": str(check.get("reason", "capability_invalid")), "capability": {}}
	return {
		"valid": true,
		"reason": "",
		"capability": {
			"extra_submission_capability": capability_id,
			"max_cards": expected_effective,
		},
	}


func _submission_window_sequence(facts: Dictionary, begins_new_batch: bool, reactive_counter: bool) -> int:
	if reactive_counter:
		return maxi(0, _last_group_window_sequence + 1)
	if begins_new_batch:
		return maxi(maxi(0, int(facts.get("window_sequence", 0))), _last_group_window_sequence + 1)
	if not _current_queue.is_empty():
		return maxi(0, int((_current_queue[0] as Dictionary).get("window_sequence", _last_group_window_sequence)))
	return maxi(0, _last_group_window_sequence)


func _next_promoted_window_sequence(facts: Dictionary) -> int:
	return maxi(_last_group_window_sequence + 1, maxi(0, int(facts.get("window_sequence", _last_group_window_sequence))) + 1)


func _infer_last_started_window_sequence() -> int:
	return _infer_started_sequence_from_entries(_current_queue, _active_entry)


func _infer_started_sequence_from_entries(current_entries: Array, active: Dictionary) -> int:
	return maxi(_maximum_window_sequence(current_entries), int(active.get("window_sequence", -1)))


func _maximum_window_sequence(entries: Array) -> int:
	var result := -1
	for entry_variant in entries:
		if entry_variant is Dictionary:
			result = maxi(result, int((entry_variant as Dictionary).get("window_sequence", -1)))
	return result


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
		"queued_behind_resolution": bool(entry.get("queued_behind_resolution", false)),
		"public_owner_revealed": bool(entry.get("public_owner_revealed", false)),
		"public_owner_label": str(entry.get("public_owner_label", "")) if bool(entry.get("public_owner_revealed", false)) else "",
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
	entry.erase("priority_bid_cents")
	entry.erase("priority_bid_escrowed")
	entry.erase("locked_priority_bid_cents")
	entry.erase("priority_bid_recipient_kind")
	entry.erase("winning_priority_bid_cents")
	entry.erase("capacity_reservation")
	entry.erase("capacity_reservation_id")
	entry.erase("capacity_reservation_transaction_id")
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
