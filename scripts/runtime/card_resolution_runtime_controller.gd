extends Node
class_name CardResolutionRuntimeController

const SharedCardGroupWindowScript := preload("res://scripts/cards/shared_card_group_window.gd")

signal phase_changed(phase: String, snapshot: Dictionary)
signal state_changed(snapshot: Dictionary)

@export_range(0.0, 120.0, 0.5) var total_window_seconds := SharedCardGroupWindowScript.TOTAL_SECONDS
@export_range(0.0, 30.0, 0.5) var lock_seconds := SharedCardGroupWindowScript.LOCK_SECONDS
@export_range(0.0, 30.0, 0.5) var display_seconds := 5.0
@export_range(0.0, 30.0, 0.5) var counter_seconds := 5.0

var simultaneous_timer := 0.0
var auction_timer := 0.0
var auction_open := false
var batch_locked := false
var counter_window_active := false
var counter_timer := 0.0
var active_display_timer := 0.0
var window_sequence := 0
var batch_reference_player := -1
var last_resolution_player_index := -1
var ready_players: Dictionary = {}

var _last_facts: Dictionary = {}
var _last_phase := "idle"
var _active_token := ""
var _completion_requested := false
var _start_next_requested := false
var _lock_batch_requested := false
var _hide_requested := false
var _lock_entry_announced := false


func configure(config: Dictionary) -> void:
	total_window_seconds = maxf(0.0, float(config.get("total_window_seconds", total_window_seconds)))
	lock_seconds = maxf(0.0, float(config.get("lock_seconds", lock_seconds)))
	display_seconds = maxf(0.0, float(config.get("display_seconds", display_seconds)))
	counter_seconds = maxf(0.0, float(config.get("counter_seconds", counter_seconds)))
	if int(total_window_seconds) != 8 or int(lock_seconds) != 2:
		push_error("CardResolutionRuntimeController requires the v0.5 8/6/2 card window.")


func reset_state() -> void:
	simultaneous_timer = 0.0
	auction_timer = 0.0
	auction_open = false
	batch_locked = false
	counter_window_active = false
	counter_timer = 0.0
	active_display_timer = 0.0
	window_sequence = 0
	batch_reference_player = -1
	last_resolution_player_index = -1
	ready_players.clear()
	_last_facts = {}
	_last_phase = "idle"
	_reset_transition_latches()


func begin_group_window(duration: float = -1.0, reference_player: int = -1, sequence: int = -1) -> void:
	simultaneous_timer = maxf(0.0, total_window_seconds if duration < 0.0 else duration)
	auction_timer = 0.0
	auction_open = false
	batch_locked = false
	batch_reference_player = reference_player
	if sequence >= 0:
		window_sequence = sequence
	_lock_batch_requested = false
	_start_next_requested = false
	_hide_requested = false
	_lock_entry_announced = false
	ready_players.clear()


func set_player_ready(player_index: int, ready_state: bool, active_player_indices: Array) -> Dictionary:
	if player_index < 0 or not active_player_indices.has(player_index):
		return {"changed": false, "reason": "invalid_ready_player", "all_ready": false}
	if ready_state:
		ready_players[str(player_index)] = true
	else:
		ready_players.erase(str(player_index))
	return {
		"changed": true,
		"reason": "",
		"player_index": player_index,
		"ready": ready_state,
		"all_ready": all_players_ready(active_player_indices),
		"ready_count": _ready_count(active_player_indices),
		"active_player_count": active_player_indices.size(),
	}


func all_players_ready(active_player_indices: Array) -> bool:
	if active_player_indices.is_empty():
		return false
	for player_index_variant in active_player_indices:
		if not bool(ready_players.get(str(int(player_index_variant)), false)):
			return false
	return true


func clear_ready_players() -> void:
	ready_players.clear()


func begin_active_display(duration: float = -1.0) -> void:
	active_display_timer = maxf(0.0, display_seconds if duration < 0.0 else duration)
	counter_window_active = false
	counter_timer = 0.0
	_completion_requested = false


func begin_counter(duration: float = -1.0) -> void:
	counter_window_active = true
	counter_timer = maxf(0.0, counter_seconds if duration < 0.0 else duration)
	_completion_requested = false


func tick(delta: float, facts: Dictionary) -> Array:
	_last_facts = _sanitize_facts(facts)
	_prepare_transition_latches(_last_facts)
	var commands: Array = []
	var step := maxf(0.0, delta)
	var active_present := bool(_last_facts.get("active_present", false))
	if active_present:
		if counter_window_active:
			counter_timer = maxf(0.0, counter_timer - step)
			commands.append(_command("show_active", {"stage": "counter", "remaining": counter_timer}))
			if counter_timer <= 0.0 and not _completion_requested:
				_completion_requested = true
				commands.append(_command("complete_active", {"stage": "counter"}))
		else:
			active_display_timer = maxf(0.0, active_display_timer - step)
			commands.append(_command("show_active", {"stage": "reveal", "remaining": active_display_timer}))
			if active_display_timer <= 0.0 and not _completion_requested:
				if bool(_last_facts.get("active_counterable", false)):
					begin_counter(float(_last_facts.get("counter_duration", counter_seconds)))
					commands.append(_command("begin_counter", {"remaining": counter_timer}))
					if counter_timer <= 0.0:
						_completion_requested = true
						commands.append(_command("complete_active", {"stage": "counter"}))
				else:
					_completion_requested = true
					commands.append(_command("complete_active", {"stage": "reveal"}))
		_publish_state(_last_facts)
		return commands

	counter_window_active = false
	counter_timer = 0.0
	if batch_locked:
		if not _start_next_requested:
			_start_next_requested = true
			commands.append(_command("start_next"))
		_publish_state(_last_facts)
		return commands

	if bool(_last_facts.get("queue_empty", true)):
		auction_open = false
		auction_timer = 0.0
		if not _hide_requested:
			_hide_requested = true
			commands.append(_command("hide_overlay"))
		_publish_state(_last_facts)
		return commands
	var active_player_indices: Array = _last_facts.get("active_player_indices", []) if _last_facts.get("active_player_indices", []) is Array else []
	if SharedCardGroupWindowScript.phase_for_remaining(simultaneous_timer, lock_seconds) == "organize" \
		and all_players_ready(active_player_indices) \
		and not _lock_batch_requested:
		_lock_batch_requested = true
		batch_locked = true
		auction_open = false
		auction_timer = 0.0
		simultaneous_timer = 0.0
		commands.append(_command("all_ready_lock", {"ready_count": active_player_indices.size()}))
		commands.append(_command("lock_batch"))
		_publish_state(_last_facts)
		return commands

	var previous_remaining := simultaneous_timer
	if simultaneous_timer > 0.0:
		simultaneous_timer = maxf(0.0, simultaneous_timer - step)
	var effective_lock_seconds := maxf(0.0, float(_last_facts.get("lock_duration", lock_seconds)))
	var phase := SharedCardGroupWindowScript.phase_for_remaining(simultaneous_timer, effective_lock_seconds)
	if phase == "lock":
		auction_open = true
		auction_timer = simultaneous_timer
		if not _lock_entry_announced and previous_remaining > effective_lock_seconds:
			_lock_entry_announced = true
			commands.append(_command("enter_lock"))
	elif phase == "organize":
		auction_open = false
		auction_timer = 0.0
		_lock_entry_announced = false
	commands.append(_command("show_group_window", {"remaining": simultaneous_timer, "window_phase": phase}))
	if simultaneous_timer <= 0.0 and not _lock_batch_requested:
		_lock_batch_requested = true
		batch_locked = true
		auction_open = false
		auction_timer = 0.0
		commands.append(_command("lock_batch"))
	_publish_state(_last_facts)
	return commands


func current_phase(facts: Dictionary = {}) -> String:
	var state_facts := _sanitize_facts(facts) if not facts.is_empty() else _last_facts
	if bool(state_facts.get("active_present", false)):
		return "counter" if counter_window_active else "resolving"
	if batch_locked:
		return "resolving"
	if bool(state_facts.get("queue_empty", true)):
		return "idle"
	return SharedCardGroupWindowScript.phase_for_remaining(
		simultaneous_timer,
		maxf(0.0, float(state_facts.get("lock_duration", lock_seconds)))
	)


func submissions_open(facts: Dictionary = {}) -> bool:
	var state_facts := _sanitize_facts(facts) if not facts.is_empty() else _last_facts
	return not batch_locked \
		and not bool(state_facts.get("active_present", false)) \
		and not bool(state_facts.get("queue_empty", true)) \
		and SharedCardGroupWindowScript.submissions_open(
			simultaneous_timer,
			maxf(0.0, float(state_facts.get("lock_duration", lock_seconds)))
		)


func bidding_open(facts: Dictionary = {}) -> bool:
	var state_facts := _sanitize_facts(facts) if not facts.is_empty() else _last_facts
	var remaining := simultaneous_timer
	if remaining <= 0.0 and auction_open:
		remaining = auction_timer
	return not batch_locked \
		and not bool(state_facts.get("active_present", false)) \
		and not bool(state_facts.get("queue_empty", true)) \
		and SharedCardGroupWindowScript.bidding_open(remaining, maxf(0.0, float(state_facts.get("lock_duration", lock_seconds))))


func to_save_data() -> Dictionary:
	return {
		"card_resolution_timer": active_display_timer,
		"card_resolution_counter_window_active": counter_window_active,
		"card_resolution_counter_timer": counter_timer,
		"card_resolution_simultaneous_timer": simultaneous_timer,
		"card_resolution_auction_timer": auction_timer,
		"card_resolution_auction_open": auction_open,
		"card_resolution_batch_locked": batch_locked,
		"card_resolution_batch_reference_player": batch_reference_player,
		"card_group_window_sequence": window_sequence,
		"last_card_resolution_player_index": last_resolution_player_index,
		"card_group_ready_players": ready_players.duplicate(true),
	}


func apply_save_data(data: Dictionary) -> void:
	active_display_timer = maxf(0.0, float(data.get("card_resolution_timer", data.get("active_display_timer", 0.0))))
	counter_window_active = bool(data.get("card_resolution_counter_window_active", data.get("counter_window_active", false)))
	counter_timer = maxf(0.0, float(data.get("card_resolution_counter_timer", data.get("counter_timer", 0.0))))
	simultaneous_timer = maxf(0.0, float(data.get("card_resolution_simultaneous_timer", data.get("simultaneous_timer", 0.0))))
	auction_timer = maxf(0.0, float(data.get("card_resolution_auction_timer", data.get("auction_timer", 0.0))))
	auction_open = bool(data.get("card_resolution_auction_open", data.get("auction_open", false)))
	if auction_open and simultaneous_timer <= 0.0 and auction_timer > 0.0:
		simultaneous_timer = auction_timer
	batch_locked = bool(data.get("card_resolution_batch_locked", data.get("batch_locked", false)))
	batch_reference_player = int(data.get("card_resolution_batch_reference_player", data.get("batch_reference_player", -1)))
	window_sequence = int(data.get("card_group_window_sequence", data.get("window_sequence", 0)))
	last_resolution_player_index = int(data.get("last_card_resolution_player_index", data.get("last_resolution_player_index", -1)))
	ready_players = (data.get("card_group_ready_players", {}) as Dictionary).duplicate(true) if data.get("card_group_ready_players", {}) is Dictionary else {}
	_last_facts = {}
	_last_phase = "idle"
	_reset_transition_latches()


func debug_snapshot() -> Dictionary:
	return {
		"controller_missing": false,
		"controller_authoritative": true,
		"legacy_state_fallback_used": false,
		"phase": current_phase(),
		"simultaneous_timer": simultaneous_timer,
		"auction_timer": auction_timer,
		"auction_open": auction_open,
		"batch_locked": batch_locked,
		"counter_window_active": counter_window_active,
		"counter_timer": counter_timer,
		"active_display_timer": active_display_timer,
		"window_sequence": window_sequence,
		"batch_reference_player": batch_reference_player,
		"last_resolution_player_index": last_resolution_player_index,
		"ready_players": ready_players.duplicate(true),
		"config": {
			"total_window_seconds": total_window_seconds,
			"lock_seconds": lock_seconds,
			"display_seconds": display_seconds,
			"counter_seconds": counter_seconds,
		},
		"facts": _last_facts.duplicate(true),
	}


func _prepare_transition_latches(facts: Dictionary) -> void:
	var active_present := bool(facts.get("active_present", false))
	var active_token := str(facts.get("active_id", "")) if active_present else ""
	if not active_present or active_token != _active_token:
		_completion_requested = false
		_active_token = active_token
	if not batch_locked:
		_start_next_requested = false
	if not bool(facts.get("queue_empty", true)):
		_hide_requested = false
	if simultaneous_timer > 0.0 and not batch_locked:
		_lock_batch_requested = false


func _reset_transition_latches() -> void:
	_active_token = ""
	_completion_requested = false
	_start_next_requested = false
	_lock_batch_requested = false
	_hide_requested = false
	_lock_entry_announced = false


func _sanitize_facts(facts: Dictionary) -> Dictionary:
	return {
		"queue_empty": bool(facts.get("queue_empty", true)),
		"active_present": bool(facts.get("active_present", false)),
		"active_counterable": bool(facts.get("active_counterable", false)),
		"active_id": str(facts.get("active_id", "")),
		"lock_duration": maxf(0.0, float(facts.get("lock_duration", lock_seconds))),
		"counter_duration": maxf(0.0, float(facts.get("counter_duration", counter_seconds))),
		"active_player_indices": (facts.get("active_player_indices", []) as Array).duplicate() if facts.get("active_player_indices", []) is Array else [],
	}


func _ready_count(active_player_indices: Array) -> int:
	var count := 0
	for player_index_variant in active_player_indices:
		if bool(ready_players.get(str(int(player_index_variant)), false)):
			count += 1
	return count


func _command(transition: String, details: Dictionary = {}) -> Dictionary:
	var command := {
		"transition": transition,
		"phase": current_phase(_last_facts),
	}
	for key_variant in details.keys():
		command[key_variant] = details[key_variant]
	return command


func _publish_state(facts: Dictionary) -> void:
	var phase := current_phase(facts)
	var snapshot := debug_snapshot()
	if phase != _last_phase:
		_last_phase = phase
		phase_changed.emit(phase, snapshot)
	state_changed.emit(snapshot)
