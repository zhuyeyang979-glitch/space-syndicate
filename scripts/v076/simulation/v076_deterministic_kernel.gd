@tool
extends Node
class_name V076DeterministicKernel

const AuthorityCommand := preload("res://scripts/v076/simulation/v076_authority_command_v1.gd")
const DomainRng := preload("res://scripts/v076/simulation/v076_domain_rng.gd")
const StateCodec := preload("res://scripts/v076/simulation/v076_authority_state_codec.gd")

const SCHEMA_VERSION := 1
const TICK_RATE_HZ := 20
const TICK_DURATION_US := 50_000

var _configured := false
var _root_seed := 0
var _current_tick := 0
var _elapsed_remainder_us := 0
var _next_authority_sequence := 1
var _domain_handlers: Dictionary = {}
var _initial_domain_states: Dictionary = {}
var _domain_states: Dictionary = {}
var _domain_rngs: Dictionary = {}
var _pending_commands: Array = []
var _accepted_commands: Array = []
var _accepted_command_hashes: Dictionary = {}
var _executed_command_hashes: Dictionary = {}
var _execution_log: Array = []
var _tick_hashes: Array = []
var _rejection_count := 0
var _last_rejection := ""


func configure(root_seed: int) -> Dictionary:
	if _configured:
		return {"accepted": false, "reason": "kernel_already_configured"}
	var seed_validation := StateCodec.validate({"root_seed": root_seed})
	if not bool(seed_validation.get("valid", false)):
		return {"accepted": false, "reason": "kernel_root_seed_invalid"}
	_root_seed = root_seed
	_configured = true
	return {"accepted": true, "reason": "", "tick_rate_hz": TICK_RATE_HZ, "tick_duration_us": TICK_DURATION_US}


func register_domain(domain_id: String, initial_state: Dictionary, handler_script: Variant) -> Dictionary:
	if not _configured:
		return {"accepted": false, "reason": "kernel_not_configured"}
	if domain_id.is_empty() or _domain_handlers.has(domain_id):
		return {"accepted": false, "reason": "domain_identity_invalid_or_duplicate"}
	var handler_validation := _validate_handler_script(domain_id, handler_script)
	if not bool(handler_validation.get("valid", false)):
		return {"accepted": false, "reason": str(handler_validation.get("reason", "domain_handler_contract_missing"))}
	var validation := StateCodec.validate(initial_state, "$.domains.%s" % domain_id)
	if not bool(validation.get("valid", false)):
		return {"accepted": false, "reason": str(validation.get("reason", "")), "path": str(validation.get("path", ""))}
	var rng := DomainRng.new()
	var rng_result := rng.configure(_root_seed, domain_id)
	if not bool(rng_result.get("accepted", false)):
		return rng_result
	_domain_handlers[domain_id] = handler_script
	_initial_domain_states[domain_id] = initial_state.duplicate(true)
	_domain_states[domain_id] = initial_state.duplicate(true)
	_domain_rngs[domain_id] = rng
	return {"accepted": true, "reason": "", "domain_id": domain_id}


func submit_command(command: Dictionary) -> Dictionary:
	var validation := AuthorityCommand.validate(command)
	if not bool(validation.get("valid", false)):
		return _reject(str(validation.get("reason", "command_invalid")))
	var domain_id := str(command.get("domain_id", ""))
	if not _domain_handlers.has(domain_id):
		return _reject("command_domain_not_registered")
	if int(command.get("scheduled_tick", 0)) <= _current_tick:
		return _reject("command_tick_not_future")
	var command_id := str(command.get("command_id", ""))
	var command_sha := AuthorityCommand.fingerprint(command)
	if command_sha.is_empty():
		return _reject("command_identity_empty")
	if _accepted_command_hashes.has(command_id):
		if str(_accepted_command_hashes[command_id]) == command_sha:
			return {"accepted": true, "reason": "", "duplicate": true, "command_sha256": command_sha}
		return _reject("command_id_payload_collision")
	_accepted_command_hashes[command_id] = command_sha
	_pending_commands.append(command.duplicate(true))
	_accepted_commands.append(command.duplicate(true))
	return {"accepted": true, "reason": "", "duplicate": false, "command_sha256": command_sha}


func advance_elapsed_us(elapsed_us: int) -> Dictionary:
	if elapsed_us < 0:
		return _reject("negative_elapsed_us")
	_elapsed_remainder_us += elapsed_us
	var advanced := 0
	while _elapsed_remainder_us >= TICK_DURATION_US:
		var result := _advance_one_tick()
		if not bool(result.get("accepted", false)):
			return result
		_elapsed_remainder_us -= TICK_DURATION_US
		advanced += 1
	return {"accepted": true, "reason": "", "advanced_tick_count": advanced, "current_tick": _current_tick}


func advance_ticks(tick_count: int) -> Dictionary:
	if tick_count < 0:
		return _reject("negative_tick_count")
	for _index in range(tick_count):
		var result := _advance_one_tick()
		if not bool(result.get("accepted", false)):
			return result
	return {"accepted": true, "reason": "", "advanced_tick_count": tick_count, "current_tick": _current_tick}


func capture_snapshot() -> Dictionary:
	if _elapsed_remainder_us != 0:
		return {"accepted": false, "reason": "snapshot_requires_tick_boundary", "snapshot": {}, "snapshot_sha256": ""}
	var sorted_pending := _sorted_commands(_pending_commands)
	var sorted_accepted := _sorted_commands(_accepted_commands)
	var snapshot := {
		"schema_version": SCHEMA_VERSION,
		"tick_rate_hz": TICK_RATE_HZ,
		"tick_duration_us": TICK_DURATION_US,
		"root_seed": _root_seed,
		"current_tick": _current_tick,
		"next_authority_sequence": _next_authority_sequence,
		"initial_domain_states": _initial_domain_states.duplicate(true),
		"domain_states": _domain_states.duplicate(true),
		"domain_rng": _rng_snapshots(),
		"pending_commands": sorted_pending,
		"accepted_commands": sorted_accepted,
		"accepted_command_hashes": _accepted_command_hashes.duplicate(true),
		"executed_command_hashes": _executed_command_hashes.duplicate(true),
		"execution_log": _execution_log.duplicate(true),
		"execution_log_cursor": _execution_log.size(),
		"execution_log_sha256": StateCodec.fingerprint(_execution_log),
		"tick_hashes": _tick_hashes.duplicate(true),
		"authority_state_sha256": state_fingerprint(),
	}
	var snapshot_sha := StateCodec.fingerprint(snapshot)
	if snapshot_sha.is_empty() or str(snapshot.get("authority_state_sha256", "")).is_empty() or str(snapshot.get("execution_log_sha256", "")).is_empty():
		return {"accepted": false, "reason": "snapshot_identity_empty", "snapshot": {}, "snapshot_sha256": ""}
	return {"accepted": true, "reason": "", "snapshot": snapshot, "snapshot_sha256": snapshot_sha}


func restore_snapshot(snapshot: Dictionary, expected_snapshot_sha256: String) -> Dictionary:
	if _elapsed_remainder_us != 0:
		return {"accepted": false, "reason": "restore_requires_tick_boundary"}
	if expected_snapshot_sha256.is_empty() or StateCodec.fingerprint(snapshot) != expected_snapshot_sha256:
		return {"accepted": false, "reason": "snapshot_hash_mismatch"}
	var shape_validation := _validate_snapshot_shape(snapshot)
	if not bool(shape_validation.get("valid", false)):
		return {"accepted": false, "reason": str(shape_validation.get("reason", "snapshot_shape_invalid"))}
	if int(snapshot.get("schema_version", 0)) != SCHEMA_VERSION or int(snapshot.get("tick_rate_hz", 0)) != TICK_RATE_HZ or int(snapshot.get("tick_duration_us", 0)) != TICK_DURATION_US:
		return {"accepted": false, "reason": "snapshot_kernel_contract_mismatch"}
	if int(snapshot.get("root_seed", 0)) != _root_seed:
		return {"accepted": false, "reason": "snapshot_root_seed_mismatch"}
	var staged_states := (snapshot.get("domain_states", {}) as Dictionary).duplicate(true)
	var staged_initial_states := (snapshot.get("initial_domain_states", {}) as Dictionary).duplicate(true)
	if not _same_string_key_set(staged_states, _domain_handlers) or not _same_string_key_set(staged_initial_states, _domain_handlers):
		return {"accepted": false, "reason": "snapshot_domain_set_mismatch"}
	var state_validation := StateCodec.validate(snapshot)
	if not bool(state_validation.get("valid", false)):
		return {"accepted": false, "reason": str(state_validation.get("reason", "snapshot_invalid"))}
	var staged_tick := int(snapshot.get("current_tick", -1))
	var staged_next_sequence := int(snapshot.get("next_authority_sequence", 0))
	if staged_tick < 0 or staged_next_sequence < 1:
		return {"accepted": false, "reason": "snapshot_cursor_invalid"}
	var staged_pending := (snapshot.get("pending_commands", []) as Array).duplicate(true)
	var staged_accepted_commands := (snapshot.get("accepted_commands", []) as Array).duplicate(true)
	var staged_accepted_hashes := (snapshot.get("accepted_command_hashes", {}) as Dictionary).duplicate(true)
	var staged_executed_hashes := (snapshot.get("executed_command_hashes", {}) as Dictionary).duplicate(true)
	for command_variant in staged_pending + staged_accepted_commands:
		if not (command_variant is Dictionary):
			return {"accepted": false, "reason": "snapshot_command_not_dictionary"}
		var command_validation := AuthorityCommand.validate(command_variant as Dictionary)
		if not bool(command_validation.get("valid", false)):
			return {"accepted": false, "reason": "snapshot_command_invalid"}
	for pending_variant in staged_pending:
		if int((pending_variant as Dictionary).get("scheduled_tick", 0)) <= staged_tick:
			return {"accepted": false, "reason": "snapshot_pending_tick_invalid"}
	for command_id_variant in staged_accepted_hashes.keys():
		if typeof(command_id_variant) != TYPE_STRING or typeof(staged_accepted_hashes[command_id_variant]) != TYPE_STRING or str(staged_accepted_hashes[command_id_variant]).is_empty():
			return {"accepted": false, "reason": "snapshot_accepted_identity_invalid"}
	for command_id_variant in staged_executed_hashes.keys():
		if not staged_accepted_hashes.has(command_id_variant) or staged_executed_hashes[command_id_variant] != staged_accepted_hashes[command_id_variant]:
			return {"accepted": false, "reason": "snapshot_executed_identity_invalid"}
	var rng_snapshots := snapshot.get("domain_rng", {}) as Dictionary
	if not _same_string_key_set(rng_snapshots, _domain_handlers):
		return {"accepted": false, "reason": "snapshot_rng_domain_set_mismatch"}
	var staged_rngs := {}
	for domain_id_variant in _domain_rngs.keys():
		var domain_id := str(domain_id_variant)
		if not rng_snapshots.has(domain_id) or not (rng_snapshots[domain_id] is Dictionary):
			return {"accepted": false, "reason": "snapshot_rng_domain_missing"}
		var rng := DomainRng.new()
		var configured := rng.configure(_root_seed, domain_id)
		if not bool(configured.get("accepted", false)):
			return configured
		var restore_result := rng.restore(rng_snapshots[domain_id] as Dictionary)
		if not bool(restore_result.get("accepted", false)):
			return restore_result
		staged_rngs[domain_id] = rng
	var staged_execution_log := (snapshot.get("execution_log", []) as Array).duplicate(true)
	var staged_tick_hashes := (snapshot.get("tick_hashes", []) as Array).duplicate(true)
	if int(snapshot.get("execution_log_cursor", -1)) != staged_execution_log.size() or str(snapshot.get("execution_log_sha256", "")) != StateCodec.fingerprint(staged_execution_log):
		return {"accepted": false, "reason": "snapshot_execution_log_mismatch"}
	var semantic_validation := _validate_snapshot_semantics(
		staged_tick,
		staged_next_sequence,
		staged_pending,
		staged_accepted_commands,
		staged_accepted_hashes,
		staged_executed_hashes,
		staged_execution_log,
		staged_tick_hashes
	)
	if not bool(semantic_validation.get("valid", false)):
		return {"accepted": false, "reason": str(semantic_validation.get("reason", "snapshot_semantic_mismatch"))}
	var staged_state_sha := _fingerprint_projection(staged_tick, staged_next_sequence, staged_states, staged_rngs, staged_pending, staged_accepted_hashes, staged_executed_hashes)
	if staged_state_sha.is_empty() or str(snapshot.get("authority_state_sha256", "")) != staged_state_sha:
		return {"accepted": false, "reason": "snapshot_authority_state_mismatch"}
	var replay_validation := _validate_snapshot_replay(
		staged_tick,
		staged_initial_states,
		staged_accepted_commands,
		staged_execution_log,
		staged_tick_hashes,
		staged_state_sha
	)
	if not bool(replay_validation.get("valid", false)):
		return {"accepted": false, "reason": str(replay_validation.get("reason", "snapshot_replay_mismatch"))}
	_current_tick = staged_tick
	_next_authority_sequence = staged_next_sequence
	_initial_domain_states = staged_initial_states
	_domain_states = staged_states
	_domain_rngs = staged_rngs
	_pending_commands = staged_pending
	_accepted_commands = staged_accepted_commands
	_accepted_command_hashes = staged_accepted_hashes
	_executed_command_hashes = staged_executed_hashes
	_execution_log = staged_execution_log
	_tick_hashes = staged_tick_hashes
	return {"accepted": true, "reason": "", "current_tick": _current_tick}


func build_replay_recipe() -> Dictionary:
	var recipe := {
		"schema_version": SCHEMA_VERSION,
		"root_seed": _root_seed,
		"initial_domain_states": _initial_domain_states.duplicate(true),
		"commands": _sorted_commands(_accepted_commands),
		"final_tick": _current_tick,
		"expected_pending_command_count": _pending_commands.size(),
		"expected_accepted_command_count": _accepted_command_hashes.size(),
		"expected_executed_command_count": _executed_command_hashes.size(),
		"expected_execution_log": _execution_log.duplicate(true),
		"expected_execution_log_sha256": StateCodec.fingerprint(_execution_log),
		"expected_terminal_state_sha256": state_fingerprint(),
	}
	var recipe_sha := StateCodec.fingerprint(recipe)
	if recipe_sha.is_empty() or str(recipe.get("expected_execution_log_sha256", "")).is_empty() or str(recipe.get("expected_terminal_state_sha256", "")).is_empty():
		return {"accepted": false, "reason": "replay_recipe_identity_empty", "recipe": {}, "recipe_sha256": ""}
	return {"accepted": true, "reason": "", "recipe": recipe, "recipe_sha256": recipe_sha}


func state_fingerprint() -> String:
	return StateCodec.fingerprint(_authority_projection())


func current_tick() -> int:
	return _current_tick


func domain_state(domain_id: String) -> Dictionary:
	return (_domain_states.get(domain_id, {}) as Dictionary).duplicate(true)


func execution_log() -> Array:
	return _execution_log.duplicate(true)


func tick_hashes() -> Array:
	return _tick_hashes.duplicate(true)


func debug_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"tick_rate_hz": TICK_RATE_HZ,
		"tick_duration_us": TICK_DURATION_US,
		"current_tick": _current_tick,
		"elapsed_remainder_us": _elapsed_remainder_us,
		"domain_count": _domain_states.size(),
		"pending_command_count": _pending_commands.size(),
		"accepted_command_count": _accepted_commands.size(),
		"executed_command_count": _execution_log.size(),
		"next_authority_sequence": _next_authority_sequence,
		"float_authority_field_count": StateCodec.count_float_fields(_authority_projection()),
		"authority_state_sha256": state_fingerprint(),
		"rejection_count": _rejection_count,
		"last_rejection": _last_rejection,
		"presentation_owns_authority": false,
	}


func _advance_one_tick() -> Dictionary:
	if not _configured or _domain_handlers.is_empty():
		return _reject("kernel_or_domains_not_ready")
	var staged_tick := _current_tick + 1
	var due: Array = []
	var remaining: Array = []
	for command_variant in _pending_commands:
		var command := command_variant as Dictionary
		var scheduled_tick := int(command.get("scheduled_tick", 0))
		if scheduled_tick == staged_tick:
			due.append(command)
		elif scheduled_tick > staged_tick:
			remaining.append(command)
		else:
			return _reject("pending_command_missed_tick")
	due.sort_custom(AuthorityCommand.less_than)
	var staged_states := _domain_states.duplicate(true)
	var staged_rngs := _clone_rngs(_domain_rngs)
	if staged_rngs.is_empty() and not _domain_rngs.is_empty():
		return _reject("rng_stage_clone_failed")
	var staged_next_sequence := _next_authority_sequence
	var staged_executed_hashes := _executed_command_hashes.duplicate(true)
	var staged_log := _execution_log.duplicate(true)
	for command_variant in due:
		var command := (command_variant as Dictionary).duplicate(true)
		var command_id := str(command.get("command_id", ""))
		var submitted_command_sha := AuthorityCommand.fingerprint(command)
		if submitted_command_sha.is_empty():
			return _reject("submitted_command_identity_empty")
		if staged_executed_hashes.has(command_id):
			if str(staged_executed_hashes[command_id]) == submitted_command_sha:
				continue
			return _reject("executed_command_id_collision")
		var before_hash := _fingerprint_projection(staged_tick, staged_next_sequence, staged_states, staged_rngs, remaining, _accepted_command_hashes, staged_executed_hashes)
		command["authority_sequence"] = staged_next_sequence
		staged_next_sequence += 1
		var execution_command_sha := StateCodec.fingerprint(command)
		if before_hash.is_empty() or execution_command_sha.is_empty():
			return _reject("execution_identity_empty")
		var domain_id := str(command.get("domain_id", ""))
		var rng: Variant = staged_rngs[domain_id]
		var before_rng: Dictionary = rng.snapshot()
		var handler: Variant = _create_domain_handler(domain_id)
		if handler == null:
			return _reject("domain_handler_script_instantiation_failed")
		var handler_result_variant: Variant = handler.call(
			"v076_apply_command",
			(staged_states[domain_id] as Dictionary).duplicate(true),
			command.duplicate(true),
			rng
		)
		if not (handler_result_variant is Dictionary):
			return _reject("domain_handler_result_not_dictionary")
		var handler_result := handler_result_variant as Dictionary
		if not bool(handler_result.get("accepted", false)) or not (handler_result.get("state") is Dictionary):
			return _reject(str(handler_result.get("reason", "domain_handler_rejected")))
		var next_state := handler_result.get("state") as Dictionary
		var state_validation := StateCodec.validate(next_state, "$.domains.%s" % domain_id)
		if not bool(state_validation.get("valid", false)):
			return _reject(str(state_validation.get("reason", "domain_state_invalid")))
		var receipt: Dictionary = handler_result.get("receipt", {}) as Dictionary
		var receipt_validation := StateCodec.validate(receipt, "$.receipt")
		if not bool(receipt_validation.get("valid", false)):
			return _reject(str(receipt_validation.get("reason", "domain_receipt_invalid")))
		staged_states[domain_id] = next_state.duplicate(true)
		staged_executed_hashes[command_id] = submitted_command_sha
		var after_hash := _fingerprint_projection(staged_tick, staged_next_sequence, staged_states, staged_rngs, remaining, _accepted_command_hashes, staged_executed_hashes)
		if after_hash.is_empty():
			return _reject("after_state_identity_empty")
		staged_log.append({
			"authority_sequence": int(command.get("authority_sequence", 0)),
			"tick": staged_tick,
			"command": command,
			"submitted_command_sha256": submitted_command_sha,
			"command_sha256": execution_command_sha,
			"before_state_sha256": before_hash,
			"after_state_sha256": after_hash,
			"rng_before": before_rng,
			"rng_after": rng.snapshot(),
			"receipt": receipt.duplicate(true),
		})
	_current_tick = staged_tick
	_next_authority_sequence = staged_next_sequence
	_domain_states = staged_states
	_domain_rngs = staged_rngs
	_pending_commands = remaining
	_executed_command_hashes = staged_executed_hashes
	_execution_log = staged_log
	_tick_hashes.append({"tick": _current_tick, "state_sha256": state_fingerprint()})
	return {"accepted": true, "reason": "", "tick": _current_tick, "executed_command_count": due.size()}


func _authority_projection() -> Dictionary:
	return _projection_for(_current_tick, _next_authority_sequence, _domain_states, _domain_rngs, _pending_commands, _accepted_command_hashes, _executed_command_hashes)


func _projection_for(tick: int, next_sequence: int, states: Dictionary, rngs: Dictionary, pending: Array, accepted_hashes: Dictionary, executed_hashes: Dictionary) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"root_seed": _root_seed,
		"current_tick": tick,
		"next_authority_sequence": next_sequence,
		"domain_states": states.duplicate(true),
		"domain_rng": _rng_snapshots_from(rngs),
		"pending_commands": _sorted_commands(pending),
		"accepted_command_hashes": accepted_hashes.duplicate(true),
		"executed_command_hashes": executed_hashes.duplicate(true),
	}


func _fingerprint_projection(tick: int, next_sequence: int, states: Dictionary, rngs: Dictionary, pending: Array, accepted_hashes: Dictionary, executed_hashes: Dictionary) -> String:
	return StateCodec.fingerprint(_projection_for(tick, next_sequence, states, rngs, pending, accepted_hashes, executed_hashes))


func _rng_snapshots() -> Dictionary:
	return _rng_snapshots_from(_domain_rngs)


func _rng_snapshots_from(rngs: Dictionary) -> Dictionary:
	var snapshots := {}
	for domain_id_variant in rngs.keys():
		var domain_id := str(domain_id_variant)
		var rng: Variant = rngs[domain_id]
		snapshots[domain_id] = rng.snapshot()
	return snapshots


func _clone_rngs(source_rngs: Dictionary) -> Dictionary:
	var clones := {}
	for domain_id_variant in source_rngs.keys():
		var domain_id := str(domain_id_variant)
		var source_rng: Variant = source_rngs[domain_id]
		var clone := DomainRng.new()
		var configured := clone.configure(_root_seed, domain_id)
		if not bool(configured.get("accepted", false)):
			return {}
		var restored := clone.restore(source_rng.snapshot())
		if not bool(restored.get("accepted", false)):
			return {}
		clones[domain_id] = clone
	return clones


func _sorted_commands(commands: Array) -> Array:
	var sorted := commands.duplicate(true)
	sorted.sort_custom(AuthorityCommand.less_than)
	return sorted


func _validate_snapshot_semantics(
	tick: int,
	next_sequence: int,
	pending: Array,
	accepted_commands: Array,
	accepted_hashes: Dictionary,
	executed_hashes: Dictionary,
	snapshot_execution_log: Array,
	snapshot_tick_hashes: Array
) -> Dictionary:
	if _sorted_commands(pending) != pending or _sorted_commands(accepted_commands) != accepted_commands:
		return {"valid": false, "reason": "snapshot_command_inventory_not_canonical"}
	if accepted_commands.size() != accepted_hashes.size() or accepted_hashes.size() != pending.size() + executed_hashes.size():
		return {"valid": false, "reason": "snapshot_command_inventory_count_mismatch"}
	var accepted_ids := {}
	for command_variant in accepted_commands:
		var command := command_variant as Dictionary
		var command_id := str(command.get("command_id", ""))
		var domain_id := str(command.get("domain_id", ""))
		var command_sha := AuthorityCommand.fingerprint(command)
		if command_id.is_empty() or not _domain_handlers.has(domain_id) or command_sha.is_empty() or accepted_ids.has(command_id) or str(accepted_hashes.get(command_id, "")) != command_sha:
			return {"valid": false, "reason": "snapshot_accepted_command_cross_binding_failed"}
		accepted_ids[command_id] = true
	for pending_variant in pending:
		var pending_command := pending_variant as Dictionary
		var pending_id := str(pending_command.get("command_id", ""))
		if not accepted_ids.has(pending_id) or executed_hashes.has(pending_id) or str(accepted_hashes.get(pending_id, "")) != AuthorityCommand.fingerprint(pending_command):
			return {"valid": false, "reason": "snapshot_pending_command_cross_binding_failed"}
	if snapshot_execution_log.size() != executed_hashes.size() or next_sequence != snapshot_execution_log.size() + 1:
		return {"valid": false, "reason": "snapshot_execution_cursor_mismatch"}
	var previous_entry: Dictionary = {}
	for index in range(snapshot_execution_log.size()):
		if not (snapshot_execution_log[index] is Dictionary):
			return {"valid": false, "reason": "snapshot_execution_entry_invalid"}
		var entry := snapshot_execution_log[index] as Dictionary
		if not (entry.get("command") is Dictionary):
			return {"valid": false, "reason": "snapshot_execution_command_shape_invalid"}
		var execution_command := entry.get("command", {}) as Dictionary
		var authority_sequence := int(entry.get("authority_sequence", 0))
		if authority_sequence != index + 1 or int(execution_command.get("authority_sequence", 0)) != authority_sequence:
			return {"valid": false, "reason": "snapshot_authority_sequence_gap"}
		var entry_tick := int(entry.get("tick", 0))
		if entry_tick < 1 or entry_tick > tick or (not previous_entry.is_empty() and entry_tick < int(previous_entry.get("tick", 0))):
			return {"valid": false, "reason": "snapshot_execution_tick_order_invalid"}
		var submitted_command := execution_command.duplicate(true)
		submitted_command.erase("authority_sequence")
		var submitted_validation := AuthorityCommand.validate(submitted_command)
		var command_id := str(submitted_command.get("command_id", ""))
		if not bool(submitted_validation.get("valid", false)) or not _domain_handlers.has(str(submitted_command.get("domain_id", ""))) or str(entry.get("submitted_command_sha256", "")) != AuthorityCommand.fingerprint(submitted_command):
			return {"valid": false, "reason": "snapshot_submitted_command_binding_failed"}
		if str(entry.get("command_sha256", "")) != StateCodec.fingerprint(execution_command) or str(executed_hashes.get(command_id, "")) != str(entry.get("submitted_command_sha256", "")):
			return {"valid": false, "reason": "snapshot_execution_command_binding_failed"}
		if str(entry.get("before_state_sha256", "")).is_empty() or str(entry.get("after_state_sha256", "")).is_empty():
			return {"valid": false, "reason": "snapshot_execution_state_identity_empty"}
		if not previous_entry.is_empty() and int(previous_entry.get("tick", 0)) == entry_tick and str(previous_entry.get("after_state_sha256", "")) != str(entry.get("before_state_sha256", "")):
			return {"valid": false, "reason": "snapshot_execution_hash_chain_broken"}
		previous_entry = entry
	if snapshot_tick_hashes.size() != tick:
		return {"valid": false, "reason": "snapshot_tick_hash_count_mismatch"}
	for index in range(snapshot_tick_hashes.size()):
		if not (snapshot_tick_hashes[index] is Dictionary):
			return {"valid": false, "reason": "snapshot_tick_hash_invalid"}
		var tick_entry := snapshot_tick_hashes[index] as Dictionary
		if int(tick_entry.get("tick", 0)) != index + 1 or str(tick_entry.get("state_sha256", "")).is_empty():
			return {"valid": false, "reason": "snapshot_tick_hash_sequence_invalid"}
	return {"valid": true, "reason": ""}


func _validate_snapshot_shape(snapshot: Dictionary) -> Dictionary:
	var expected_types := {
		"schema_version": TYPE_INT,
		"tick_rate_hz": TYPE_INT,
		"tick_duration_us": TYPE_INT,
		"root_seed": TYPE_INT,
		"current_tick": TYPE_INT,
		"next_authority_sequence": TYPE_INT,
		"initial_domain_states": TYPE_DICTIONARY,
		"domain_states": TYPE_DICTIONARY,
		"domain_rng": TYPE_DICTIONARY,
		"pending_commands": TYPE_ARRAY,
		"accepted_commands": TYPE_ARRAY,
		"accepted_command_hashes": TYPE_DICTIONARY,
		"executed_command_hashes": TYPE_DICTIONARY,
		"execution_log": TYPE_ARRAY,
		"execution_log_cursor": TYPE_INT,
		"execution_log_sha256": TYPE_STRING,
		"tick_hashes": TYPE_ARRAY,
		"authority_state_sha256": TYPE_STRING,
	}
	if snapshot.size() != expected_types.size():
		return {"valid": false, "reason": "snapshot_field_count_mismatch"}
	for field_name_variant in expected_types.keys():
		var field_name := str(field_name_variant)
		if not snapshot.has(field_name) or typeof(snapshot.get(field_name)) != int(expected_types[field_name]):
			return {"valid": false, "reason": "snapshot_field_type_mismatch:%s" % field_name}
	if str(snapshot.get("execution_log_sha256", "")).is_empty() or str(snapshot.get("authority_state_sha256", "")).is_empty():
		return {"valid": false, "reason": "snapshot_required_identity_empty"}
	return {"valid": true, "reason": ""}


func _validate_snapshot_replay(
	tick: int,
	initial_states: Dictionary,
	accepted_commands: Array,
	expected_execution_log: Array,
	expected_tick_hashes: Array,
	expected_state_sha256: String
) -> Dictionary:
	var verifier: Variant = (get_script() as Script).new()
	var configured: Dictionary = verifier.configure(_root_seed)
	if not bool(configured.get("accepted", false)):
		verifier.free()
		return {"valid": false, "reason": "snapshot_replay_configure_failed"}
	var domain_ids: Array = initial_states.keys()
	domain_ids.sort()
	for domain_id_variant in domain_ids:
		var domain_id := str(domain_id_variant)
		if not _domain_handlers.has(domain_id):
			verifier.free()
			return {"valid": false, "reason": "snapshot_replay_domain_missing"}
		var registered: Dictionary = verifier.register_domain(domain_id, initial_states[domain_id] as Dictionary, _domain_handlers[domain_id])
		if not bool(registered.get("accepted", false)):
			verifier.free()
			return {"valid": false, "reason": "snapshot_replay_domain_rejected"}
	for command_variant in accepted_commands:
		var submitted: Dictionary = verifier.submit_command(command_variant as Dictionary)
		if not bool(submitted.get("accepted", false)) or bool(submitted.get("duplicate", false)):
			verifier.free()
			return {"valid": false, "reason": "snapshot_replay_command_rejected"}
	var advanced: Dictionary = verifier.advance_ticks(tick)
	if not bool(advanced.get("accepted", false)):
		verifier.free()
		return {"valid": false, "reason": "snapshot_replay_advance_failed"}
	var replay_green: bool = (
		verifier.state_fingerprint() == expected_state_sha256
		and verifier.execution_log() == expected_execution_log
		and verifier.tick_hashes() == expected_tick_hashes
	)
	verifier.free()
	return {"valid": replay_green, "reason": "" if replay_green else "snapshot_replay_evidence_mismatch"}


func _validate_handler_script(domain_id: String, handler_script: Variant) -> Dictionary:
	# The kernel accepts an instantiable Script, not a user-controlled factory.
	# Every reducer is therefore created by Script.new(); cached or rotating child
	# instances cannot satisfy the registration API.
	if handler_script == null or not (handler_script is Script) or not handler_script.can_instantiate():
		return {"valid": false, "reason": "domain_handler_script_not_instantiable"}
	var sample_a: Variant = handler_script.new()
	var sample_b: Variant = handler_script.new()
	if sample_a == null or sample_b == null or not (sample_a is RefCounted) or not (sample_b is RefCounted) or sample_a == sample_b:
		return {"valid": false, "reason": "domain_handler_script_did_not_create_fresh_handler"}
	if not sample_a.has_method("v076_domain_contract") or not sample_a.has_method("v076_apply_command"):
		return {"valid": false, "reason": "domain_handler_script_contract_missing"}
	if not sample_b.has_method("v076_domain_contract") or not sample_b.has_method("v076_apply_command"):
		return {"valid": false, "reason": "domain_handler_script_contract_missing"}
	var contract_variant: Variant = sample_a.call("v076_domain_contract", domain_id)
	if not (contract_variant is Dictionary):
		return {"valid": false, "reason": "domain_handler_contract_not_dictionary"}
	var contract := contract_variant as Dictionary
	var expected_contract := {
		"schema_version": 1,
		"domain_id": domain_id,
		"stateless_handler": true,
		"deterministic": true,
		"replay_safe": true,
		"external_side_effects_allowed": false,
		"owns_presentation": false,
	}
	if contract != expected_contract:
		return {"valid": false, "reason": "domain_handler_purity_contract_rejected"}
	if sample_b.call("v076_domain_contract", domain_id) != expected_contract:
		return {"valid": false, "reason": "domain_handler_purity_contract_rejected"}
	return {"valid": true, "reason": ""}


func _create_domain_handler(domain_id: String) -> Variant:
	if not _domain_handlers.has(domain_id):
		return null
	var handler_script: Variant = _domain_handlers[domain_id]
	if not (handler_script is Script) or not handler_script.can_instantiate():
		return null
	var handler: Variant = handler_script.new()
	if handler == null or not (handler is RefCounted) or not handler.has_method("v076_apply_command"):
		return null
	return handler


func _same_string_key_set(left: Dictionary, right: Dictionary) -> bool:
	var left_keys: Array = left.keys()
	var right_keys: Array = right.keys()
	left_keys.sort()
	right_keys.sort()
	return left_keys == right_keys


func _reject(reason: String) -> Dictionary:
	_rejection_count += 1
	_last_rejection = reason
	return {"accepted": false, "reason": reason}
