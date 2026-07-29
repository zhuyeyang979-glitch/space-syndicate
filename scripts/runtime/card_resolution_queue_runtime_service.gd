@tool
extends Node
class_name CardResolutionQueueRuntimeService

const SharedCardGroupWindowScript := preload("res://scripts/cards/shared_card_group_window.gd")
const StableTargetEnvelope := preload("res://scripts/runtime/card_resolution_stable_target_envelope.gd")
const StrictState := preload("res://scripts/runtime/save_owner_state_v2_contract.gd")

const RULESET_ID := "v0.6"
const SAVE_STATE_VERSION := 2
const SAVE_KEYS := [
	"schema_version",
	"ruleset_id",
	"revision",
	"current_queue",
	"active_entry",
	"next_queue",
	"resolution_sequence",
	"last_group_window_sequence",
]
const CHECKPOINT_KEYS := [
	"checkpoint_schema_version",
	"save_state",
	"plan_count",
	"commit_count",
	"rejection_count",
	"last_reason",
]
const REQUIRED_ENTRY_KEYS := [
	"player_index", "slot_index", "queued_order", "resolution_id", "window_sequence", "group_id",
	"group_order", "group_size", "queued_behind_resolution", "play_cash_cost_cents",
	"play_cost_paid_on_queue", "financial_margin_cents", "financial_terms_version",
	"financial_authorized_cents", "financial_cash_revision", "financial_margin_locked_on_queue",
	"asset_reservation_id", "asset_cost", "asset_debit", "asset_reservation_required",
	"consumed_on_queue", "skill",
]

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
	_configured = _ruleset_id == RULESET_ID \
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


func capture_runtime_checkpoint() -> Dictionary:
	return {
		"checkpoint_schema_version": SAVE_STATE_VERSION,
		"save_state": to_save_data(),
		"plan_count": _plan_count,
		"commit_count": _commit_count,
		"rejection_count": _rejection_count,
		"last_reason": _last_reason,
	}


func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if not StrictState.is_codec_data(checkpoint) or StrictState.contains_rng_continuation(checkpoint) \
			or not StrictState.has_exact_keys(checkpoint, CHECKPOINT_KEYS) \
			or not (checkpoint.get("checkpoint_schema_version") is int) \
			or int(checkpoint.get("checkpoint_schema_version")) != SAVE_STATE_VERSION \
			or not (checkpoint.get("save_state") is Dictionary) \
			or not (checkpoint.get("plan_count") is int) or int(checkpoint.get("plan_count")) < 0 \
			or not (checkpoint.get("commit_count") is int) or int(checkpoint.get("commit_count")) < 0 \
			or not (checkpoint.get("rejection_count") is int) or int(checkpoint.get("rejection_count")) < 0 \
			or not (checkpoint.get("last_reason") is String):
		return {"restored": false, "reason_code": "card_resolution_queue_checkpoint_invalid"}
	var save_state := checkpoint.get("save_state") as Dictionary
	if not bool(preflight_save_data(save_state).get("accepted", false)):
		return {"restored": false, "reason_code": "card_resolution_queue_checkpoint_invalid"}
	_replace_save_state(save_state)
	_plan_count = int(checkpoint.get("plan_count"))
	_commit_count = int(checkpoint.get("commit_count"))
	_rejection_count = int(checkpoint.get("rejection_count"))
	_last_reason = str(checkpoint.get("last_reason"))
	return {"restored": true, "reason_code": "card_resolution_queue_checkpoint_restored"}


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
	if entry.has("stable_target_envelope"):
		var target_binding := StableTargetEnvelope.validate_entry_binding(entry)
		if not bool(target_binding.get("valid", false)):
			return _submission_rejection(str(target_binding.get("reason_code", "stable_target_invalid")))
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
	var public_group_ids: Dictionary = {}
	var current_public: Array = []
	for entry_variant in _current_queue:
		if entry_variant is Dictionary:
			current_public.append(_public_entry(entry_variant as Dictionary, _anonymous_group_id(entry_variant as Dictionary, public_group_ids)))
	var next_public: Array = []
	for entry_variant in _next_queue:
		if entry_variant is Dictionary:
			next_public.append(_public_entry(entry_variant as Dictionary, _anonymous_group_id(entry_variant as Dictionary, public_group_ids)))
	return {
		"current": current_public,
		"active": _public_entry(_active_entry, _anonymous_group_id(_active_entry, public_group_ids)),
		"next": next_public,
		"current_count": _current_queue.size(),
		"active_present": not _active_entry.is_empty(),
		"next_count": _next_queue.size(),
	}


func to_save_data() -> Dictionary:
	return {
		"schema_version": SAVE_STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"revision": _revision,
		"current_queue": current_queue(),
		"active_entry": active_entry(),
		"next_queue": next_queue(),
		"resolution_sequence": _resolution_sequence,
		"last_group_window_sequence": _last_group_window_sequence,
	}


func preflight_save_data(data: Dictionary) -> Dictionary:
	var validation := _validate_save_data(data)
	if not bool(validation.get("valid", false)):
		var reason_code := str(validation.get("reason_code", "card_resolution_queue_save_invalid"))
		return {"accepted": false, "reason": reason_code, "reason_code": reason_code}
	return {
		"accepted": true,
		"reason": "",
		"reason_code": "card_resolution_queue_save_valid",
		"normalized_state": data.duplicate(true),
	}


## Candidate-only registry preflight. Player slots and resolution lineage are
## checked against normalized sections without reading live queue consumers.
func preflight_restore_dependencies(section_state: Dictionary, all_normalized_states: Dictionary) -> Dictionary:
	var section_preflight := preflight_save_data(section_state)
	if not bool(section_preflight.get("accepted", false)):
		return _restore_dependency_rejection("card_resolution_queue_dependency_section_invalid")
	if not (all_normalized_states.get("session") is Dictionary) \
			or not (all_normalized_states.get("card_resolution_execution") is Dictionary) \
			or not (all_normalized_states.get("card_resolution_history") is Dictionary):
		return _restore_dependency_rejection("card_resolution_queue_dependency_section_missing")
	var context := _queue_restore_dependency_context(
		all_normalized_states.get("session") as Dictionary,
		all_normalized_states.get("card_resolution_execution") as Dictionary,
		all_normalized_states.get("card_resolution_history") as Dictionary
	)
	if not bool(context.get("valid", false)):
		return _restore_dependency_rejection(str(context.get("reason_code", "card_resolution_queue_dependency_context_invalid")))
	var queue_entries: Array = []
	for entry_variant in section_state.get("current_queue") as Array:
		queue_entries.append({"lane": "current", "entry": entry_variant})
	if not (section_state.get("active_entry") as Dictionary).is_empty():
		queue_entries.append({"lane": "active", "entry": section_state.get("active_entry")})
	for entry_variant in section_state.get("next_queue") as Array:
		queue_entries.append({"lane": "next", "entry": entry_variant})
	var queue_ids: Dictionary = {}
	var active_resolution_id := -1
	for row_variant in queue_entries:
		var row := row_variant as Dictionary
		var lane := str(row.get("lane", ""))
		var entry := row.get("entry") as Dictionary
		var slot_result := _validate_queue_restore_slot(entry, context)
		if not bool(slot_result.get("valid", false)):
			return _restore_dependency_rejection(str(slot_result.get("reason_code", "card_resolution_queue_dependency_slot_invalid")))
		var resolution_id := int(entry.get("resolution_id", -1))
		queue_ids[str(resolution_id)] = lane
		if lane == "active":
			active_resolution_id = resolution_id
	var lineage_result := _validate_queue_restore_lineage(
		queue_ids,
		active_resolution_id,
		int(section_state.get("resolution_sequence", 0)),
		section_state.get("active_entry") as Dictionary,
		context
	)
	if not bool(lineage_result.get("valid", false)):
		return _restore_dependency_rejection(str(lineage_result.get("reason_code", "card_resolution_queue_dependency_lineage_invalid")))
	return {
		"accepted": true,
		"reason": "",
		"reason_code": "card_resolution_queue_restore_dependencies_valid",
		"queue_reference_count": queue_ids.size(),
		"execution_lineage_count": int(lineage_result.get("execution_lineage_count", 0)),
		"history_lineage_count": int(lineage_result.get("history_lineage_count", 0)),
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var preflight := preflight_save_data(data)
	if not bool(preflight.get("accepted", false)):
		var rejection := str(preflight.get("reason_code", "card_resolution_queue_save_invalid"))
		return {"applied": false, "reason": rejection, "reason_code": rejection}
	var normalized := (preflight.get("normalized_state", {}) as Dictionary).duplicate(true)
	_replace_save_state(normalized)
	_plan_count = 0
	_commit_count = 0
	_rejection_count = 0
	_last_reason = "save_applied"
	return {
		"applied": true,
		"reason": "card_resolution_queue_state_restored",
		"reason_code": "card_resolution_queue_state_restored",
		"revision": _revision,
		"current_count": _current_queue.size(),
		"active_present": not _active_entry.is_empty(),
		"next_count": _next_queue.size(),
	}


func capture_save_checkpoint() -> Dictionary:
	return to_save_data()


func rollback_save_data(checkpoint: Dictionary) -> Dictionary:
	return apply_save_data(checkpoint)


func _replace_save_state(normalized: Dictionary) -> void:
	_current_queue = (normalized.get("current_queue") as Array).duplicate(true)
	_active_entry = (normalized.get("active_entry") as Dictionary).duplicate(true)
	_next_queue = (normalized.get("next_queue") as Array).duplicate(true)
	_resolution_sequence = int(normalized.get("resolution_sequence"))
	_last_group_window_sequence = int(normalized.get("last_group_window_sequence"))
	_revision = int(normalized.get("revision"))


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
		"save_state_version": SAVE_STATE_VERSION,
		"owns_rng_continuation": false,
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


func _public_entry(entry: Dictionary, public_group_id: String = "") -> Dictionary:
	if entry.is_empty():
		return {}
	var skill: Dictionary = entry.get("skill", {}) if entry.get("skill", {}) is Dictionary else {}
	return {
		"resolution_id": _entry_id(entry),
		"card_name": str(skill.get("name", "")),
		"card_kind": str(skill.get("kind", "")),
		"selected_district": int(entry.get("selected_district", -1)),
		"group_id": public_group_id,
		"group_order": int(entry.get("group_order", 0)),
		"group_size": int(entry.get("group_size", 0)),
		"group_position": int(entry.get("group_position", 0)),
		"queued_behind_resolution": bool(entry.get("queued_behind_resolution", false)),
	}


func _anonymous_group_id(entry: Dictionary, aliases: Dictionary) -> String:
	if entry.is_empty():
		return ""
	var internal_id := str(entry.get("group_id", ""))
	if internal_id.is_empty():
		return ""
	if not aliases.has(internal_id):
		aliases[internal_id] = "public_set_%d" % (aliases.size() + 1)
	return str(aliases.get(internal_id, ""))


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
	entry.erase("public_owner_revealed")
	entry.erase("public_owner_label")
	entry.erase("owner_revealed_time")
	entry.erase("guessers")
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


func _queue_restore_dependency_context(
	session_state: Dictionary,
	execution_state: Dictionary,
	history_state: Dictionary
) -> Dictionary:
	if not (session_state.get("world_session_state") is Dictionary):
		return {"valid": false, "reason_code": "card_resolution_queue_dependency_context_shape_invalid"}
	var world_state := session_state.get("world_session_state") as Dictionary
	if not (world_state.get("players") is Array):
		return {"valid": false, "reason_code": "card_resolution_queue_dependency_player_roster_invalid"}
	var players_by_index: Dictionary = {}
	var players := world_state.get("players") as Array
	for player_index in range(players.size()):
		var player_variant: Variant = players[player_index]
		if not (player_variant is Dictionary) \
				or not ((player_variant as Dictionary).get("id") is int) \
				or int((player_variant as Dictionary).get("id")) != player_index \
				or not ((player_variant as Dictionary).get("slots") is Array):
			return {"valid": false, "reason_code": "card_resolution_queue_dependency_player_roster_invalid"}
		players_by_index[str(player_index)] = player_variant

	var completed_result := _restore_id_set(execution_state.get("completed_resolution_ids"), "execution_completed")
	var inflight_result := _restore_id_set(execution_state.get("inflight_resolution_ids"), "execution_inflight")
	var history_result := _restore_id_set(history_state.get("appended_resolution_ids"), "history")
	if not bool(completed_result.get("valid", false)):
		return completed_result
	if not bool(inflight_result.get("valid", false)):
		return inflight_result
	if not bool(history_result.get("valid", false)):
		return history_result
	if not (execution_state.get("inflight_execution_transactions") is Array) \
			or not (execution_state.get("pending_settlements") is Array) \
			or not (history_state.get("history") is Array):
		return {"valid": false, "reason_code": "card_resolution_queue_dependency_lineage_shape_invalid"}
	var completed_ids := completed_result.get("ids") as Dictionary
	var inflight_ids := inflight_result.get("ids") as Dictionary
	for resolution_key_variant in completed_ids.keys():
		if inflight_ids.has(str(resolution_key_variant)):
			return {"valid": false, "reason_code": "card_resolution_queue_dependency_execution_overlap"}
	var inflight_transactions: Dictionary = {}
	for transaction_variant in execution_state.get("inflight_execution_transactions") as Array:
		if not (transaction_variant is Dictionary):
			return {"valid": false, "reason_code": "card_resolution_queue_dependency_execution_record_invalid"}
		var transaction := transaction_variant as Dictionary
		var resolution_id := int(transaction.get("resolution_id", -1))
		var resolution_key := str(resolution_id)
		if resolution_id <= 0 or inflight_transactions.has(resolution_key) or not inflight_ids.has(resolution_key):
			return {"valid": false, "reason_code": "card_resolution_queue_dependency_execution_record_invalid"}
		inflight_transactions[resolution_key] = transaction
	if inflight_transactions.size() != inflight_ids.size():
		return {"valid": false, "reason_code": "card_resolution_queue_dependency_execution_record_missing"}
	var pending_ids: Dictionary = {}
	for pending_variant in execution_state.get("pending_settlements") as Array:
		if not (pending_variant is Dictionary):
			return {"valid": false, "reason_code": "card_resolution_queue_dependency_settlement_record_invalid"}
		var resolution_id := int((pending_variant as Dictionary).get("resolution_id", -1))
		var resolution_key := str(resolution_id)
		if resolution_id <= 0 or pending_ids.has(resolution_key) or not completed_ids.has(resolution_key):
			return {"valid": false, "reason_code": "card_resolution_queue_dependency_settlement_record_invalid"}
		pending_ids[resolution_key] = true
	var history_ids := history_result.get("ids") as Dictionary
	var authored_history_ids: Dictionary = {}
	for entry_variant in history_state.get("history") as Array:
		if not (entry_variant is Dictionary):
			return {"valid": false, "reason_code": "card_resolution_queue_dependency_history_record_invalid"}
		var resolution_id := int((entry_variant as Dictionary).get("resolution_id", (entry_variant as Dictionary).get("queued_order", -1)))
		var resolution_key := str(resolution_id)
		if resolution_id <= 0 or authored_history_ids.has(resolution_key) or not history_ids.has(resolution_key):
			return {"valid": false, "reason_code": "card_resolution_queue_dependency_history_record_invalid"}
		authored_history_ids[resolution_key] = true
	if authored_history_ids.size() != history_ids.size():
		return {"valid": false, "reason_code": "card_resolution_queue_dependency_history_record_missing"}
	return {
		"valid": true,
		"reason_code": "card_resolution_queue_dependency_context_valid",
		"players_by_index": players_by_index,
		"completed_ids": completed_ids,
		"inflight_ids": inflight_ids,
		"inflight_transactions": inflight_transactions,
		"pending_ids": pending_ids,
		"history_ids": history_ids,
	}


func _restore_id_set(value: Variant, label: String) -> Dictionary:
	if not (value is Array):
		return {"valid": false, "reason_code": "card_resolution_queue_dependency_%s_ids_invalid" % label, "ids": {}}
	var ids: Dictionary = {}
	for id_variant in value as Array:
		if not (id_variant is int) or int(id_variant) <= 0 or ids.has(str(int(id_variant))):
			return {"valid": false, "reason_code": "card_resolution_queue_dependency_%s_ids_invalid" % label, "ids": {}}
		ids[str(int(id_variant))] = true
	return {"valid": true, "ids": ids}


func _validate_queue_restore_slot(entry: Dictionary, context: Dictionary) -> Dictionary:
	var player_key := str(int(entry.get("player_index", -1)))
	var players_by_index := context.get("players_by_index") as Dictionary
	if not players_by_index.has(player_key):
		return {"valid": false, "reason_code": "card_resolution_queue_dependency_player_missing"}
	var player := players_by_index.get(player_key) as Dictionary
	var slots := player.get("slots") as Array
	var slot_index := int(entry.get("slot_index", -1))
	if slot_index < 0 or slot_index >= slots.size():
		return {"valid": false, "reason_code": "card_resolution_queue_dependency_slot_missing"}
	if bool(entry.get("consumed_on_queue", false)):
		return {"valid": true, "reason_code": "card_resolution_queue_dependency_consumed_slot_valid"}
	var slot_variant: Variant = slots[slot_index]
	if not (slot_variant is Dictionary):
		return {"valid": false, "reason_code": "card_resolution_queue_dependency_persistent_slot_missing"}
	var slot := slot_variant as Dictionary
	var skill := entry.get("skill") as Dictionary
	if not bool(slot.get("queued_for_resolution", false)) \
			or str(slot.get("name", "")).is_empty() \
			or str(slot.get("name", "")) != str(skill.get("name", "")):
		return {"valid": false, "reason_code": "card_resolution_queue_dependency_persistent_slot_mismatch"}
	for identity_key in ["card_instance_id", "instance_id", "card_id"]:
		if (slot.has(identity_key) or skill.has(identity_key)) and slot.get(identity_key) != skill.get(identity_key):
			return {"valid": false, "reason_code": "card_resolution_queue_dependency_persistent_slot_mismatch"}
	return {"valid": true, "reason_code": "card_resolution_queue_dependency_slot_valid"}


func _validate_queue_restore_lineage(
	queue_ids: Dictionary,
	active_resolution_id: int,
	authoritative_resolution_sequence: int,
	candidate_active_entry: Dictionary,
	context: Dictionary
) -> Dictionary:
	var completed_ids := context.get("completed_ids") as Dictionary
	var inflight_ids := context.get("inflight_ids") as Dictionary
	var inflight_transactions := context.get("inflight_transactions") as Dictionary
	var pending_ids := context.get("pending_ids") as Dictionary
	var history_ids := context.get("history_ids") as Dictionary
	var maximum_resolution_id := 0
	for source in [queue_ids, completed_ids, inflight_ids, pending_ids, history_ids]:
		for resolution_key_variant in (source as Dictionary).keys():
			maximum_resolution_id = maxi(maximum_resolution_id, int(str(resolution_key_variant)))
	if maximum_resolution_id > authoritative_resolution_sequence:
		return {"valid": false, "reason_code": "card_resolution_queue_dependency_sequence_precedes_lineage"}
	for resolution_key_variant in queue_ids.keys():
		var resolution_key := str(resolution_key_variant)
		var lane := str(queue_ids.get(resolution_key_variant, ""))
		if completed_ids.has(resolution_key) or history_ids.has(resolution_key):
			return {"valid": false, "reason_code": "card_resolution_queue_dependency_terminal_id_still_queued"}
		if lane != "active" and inflight_ids.has(resolution_key):
			return {"valid": false, "reason_code": "card_resolution_queue_dependency_inflight_id_waiting"}
	if active_resolution_id > 0 and inflight_ids.has(str(active_resolution_id)):
		var transaction := inflight_transactions.get(str(active_resolution_id)) as Dictionary
		var transaction_entry: Dictionary = transaction.get("active_entry", {}) if transaction.get("active_entry", {}) is Dictionary else {}
		if int(transaction_entry.get("resolution_id", -1)) != active_resolution_id \
				or str(transaction.get("entry_fingerprint", "")) != JSON.stringify(candidate_active_entry).sha256_text():
			return {"valid": false, "reason_code": "card_resolution_queue_dependency_active_execution_mismatch"}
	for history_key_variant in history_ids.keys():
		var history_key := str(history_key_variant)
		if completed_ids.has(history_key):
			continue
		if not inflight_transactions.has(history_key) \
				or not bool((inflight_transactions.get(history_key) as Dictionary).get("history_appended", false)):
			return {"valid": false, "reason_code": "card_resolution_queue_dependency_history_orphan"}
	return {
		"valid": true,
		"reason_code": "card_resolution_queue_dependency_lineage_valid",
		"execution_lineage_count": completed_ids.size() + inflight_ids.size(),
		"history_lineage_count": history_ids.size(),
	}


func _restore_dependency_rejection(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason": reason_code, "reason_code": reason_code}


func _validate_save_data(data: Dictionary) -> Dictionary:
	if not StrictState.is_codec_data(data) or StrictState.contains_rng_continuation(data):
		return {"valid": false, "reason_code": "card_resolution_queue_save_not_codec_data"}
	if not StrictState.has_exact_keys(data, SAVE_KEYS):
		return {"valid": false, "reason_code": "card_resolution_queue_save_shape_invalid"}
	if not (data.get("schema_version") is int) or int(data.get("schema_version")) != SAVE_STATE_VERSION \
			or not (data.get("ruleset_id") is String) or str(data.get("ruleset_id")) != RULESET_ID:
		return {"valid": false, "reason_code": "card_resolution_queue_save_header_invalid"}
	if not (data.get("revision") is int) or int(data.get("revision")) < 0 \
			or not (data.get("current_queue") is Array) \
			or not (data.get("active_entry") is Dictionary) \
			or not (data.get("next_queue") is Array) \
			or not (data.get("resolution_sequence") is int) or int(data.get("resolution_sequence")) < 0 \
			or not (data.get("last_group_window_sequence") is int) or int(data.get("last_group_window_sequence")) < -1:
		return {"valid": false, "reason_code": "card_resolution_queue_save_fields_invalid"}
	var seen_resolution_ids: Dictionary = {}
	var maximum_resolution_id := 0
	var maximum_window_sequence := -1
	for entries_variant in [data.get("current_queue"), data.get("next_queue")]:
		for entry_variant in entries_variant as Array:
			var entry_validation := _validate_save_entry(entry_variant, seen_resolution_ids)
			if not bool(entry_validation.get("valid", false)):
				return entry_validation
			maximum_resolution_id = maxi(maximum_resolution_id, int(entry_validation.get("resolution_id", 0)))
			maximum_window_sequence = maxi(maximum_window_sequence, int(entry_validation.get("window_sequence", -1)))
	var active := data.get("active_entry") as Dictionary
	if not active.is_empty():
		var active_validation := _validate_save_entry(active, seen_resolution_ids)
		if not bool(active_validation.get("valid", false)):
			return active_validation
		maximum_resolution_id = maxi(maximum_resolution_id, int(active_validation.get("resolution_id", 0)))
		maximum_window_sequence = maxi(maximum_window_sequence, int(active_validation.get("window_sequence", -1)))
	if int(data.get("resolution_sequence")) < maximum_resolution_id:
		return {"valid": false, "reason_code": "card_resolution_queue_sequence_dangling"}
	if int(data.get("last_group_window_sequence")) < maximum_window_sequence:
		return {"valid": false, "reason_code": "card_resolution_queue_window_dangling"}
	return {"valid": true, "reason_code": "card_resolution_queue_save_valid"}


func _validate_save_entry(entry_variant: Variant, seen_resolution_ids: Dictionary) -> Dictionary:
	if not (entry_variant is Dictionary):
		return {"valid": false, "reason_code": "card_resolution_queue_entry_not_dictionary"}
	var entry := entry_variant as Dictionary
	if not StrictState.is_codec_data(entry) or StrictState.contains_rng_continuation(entry):
		return {"valid": false, "reason_code": "card_resolution_queue_entry_not_codec_data"}
	for key_variant in REQUIRED_ENTRY_KEYS:
		if not entry.has(str(key_variant)):
			return {"valid": false, "reason_code": "card_resolution_queue_entry_field_missing"}
	for key in ["player_index", "slot_index", "queued_order", "resolution_id", "window_sequence", "group_order", "group_size", "play_cash_cost_cents", "financial_margin_cents", "financial_authorized_cents"]:
		if not (entry.get(key) is int):
			return {"valid": false, "reason_code": "card_resolution_queue_entry_type_invalid"}
	var resolution_id := int(entry.get("resolution_id"))
	if int(entry.get("player_index")) < 0 or int(entry.get("slot_index")) < 0 \
			or resolution_id <= 0 or int(entry.get("queued_order")) != resolution_id \
			or int(entry.get("window_sequence")) < 0 \
			or int(entry.get("group_order")) <= 0 or int(entry.get("group_size")) <= 0 \
			or int(entry.get("group_order")) > int(entry.get("group_size")) \
			or int(entry.get("play_cash_cost_cents")) < 0 \
			or int(entry.get("financial_margin_cents")) < 0 \
			or int(entry.get("financial_authorized_cents")) < 0:
		return {"valid": false, "reason_code": "card_resolution_queue_entry_value_invalid"}
	if seen_resolution_ids.has(str(resolution_id)):
		return {"valid": false, "reason_code": "card_resolution_queue_resolution_duplicate"}
	seen_resolution_ids[str(resolution_id)] = true
	for key in ["queued_behind_resolution", "play_cost_paid_on_queue", "financial_margin_locked_on_queue", "asset_reservation_required", "consumed_on_queue"]:
		if not (entry.get(key) is bool):
			return {"valid": false, "reason_code": "card_resolution_queue_entry_type_invalid"}
	for key in ["group_id", "financial_terms_version", "financial_cash_revision", "asset_reservation_id"]:
		if not (entry.get(key) is String):
			return {"valid": false, "reason_code": "card_resolution_queue_entry_type_invalid"}
	if str(entry.get("group_id")).is_empty() \
			or not (entry.get("asset_cost") is Dictionary) \
			or not (entry.get("asset_debit") is Dictionary) \
			or not (entry.get("skill") is Dictionary) \
			or (entry.get("skill") as Dictionary).is_empty():
		return {"valid": false, "reason_code": "card_resolution_queue_entry_binding_dangling"}
	if bool(entry.get("asset_reservation_required")) and str(entry.get("asset_reservation_id")).is_empty():
		return {"valid": false, "reason_code": "card_resolution_queue_reservation_dangling"}
	if entry.has("stable_target_envelope"):
		var target_validation := StableTargetEnvelope.validate_entry_binding(entry)
		if not bool(target_validation.get("valid", false)):
			return {"valid": false, "reason_code": "card_resolution_queue_target_dangling"}
	return {
		"valid": true,
		"reason_code": "card_resolution_queue_entry_valid",
		"resolution_id": resolution_id,
		"window_sequence": int(entry.get("window_sequence")),
	}


func _is_data_only(value: Variant) -> bool:
	return StrictState.is_codec_data(value)
