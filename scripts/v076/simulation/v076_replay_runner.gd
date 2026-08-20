@tool
extends RefCounted
class_name V076ReplayRunner

const Kernel := preload("res://scripts/v076/simulation/v076_deterministic_kernel.gd")
const AuthorityCommand := preload("res://scripts/v076/simulation/v076_authority_command_v1.gd")
const StateCodec := preload("res://scripts/v076/simulation/v076_authority_state_codec.gd")


func verify(recipe: Dictionary, expected_recipe_sha256: String, domain_handlers: Dictionary) -> Dictionary:
	if expected_recipe_sha256.is_empty() or StateCodec.fingerprint(recipe) != expected_recipe_sha256:
		return _failure("replay_recipe_hash_mismatch")
	var recipe_validation := _validate_recipe(recipe, domain_handlers)
	if not bool(recipe_validation.get("valid", false)):
		return _failure(str(recipe_validation.get("reason", "replay_recipe_invalid")))
	var kernel := Kernel.new()
	var configured := kernel.configure(int(recipe.get("root_seed", 0)))
	if not bool(configured.get("accepted", false)):
		kernel.free()
		return _failure(str(configured.get("reason", "replay_configure_failed")))
	var initial_states := recipe.get("initial_domain_states", {}) as Dictionary
	var domain_ids: Array = initial_states.keys()
	domain_ids.sort()
	for domain_id_variant in domain_ids:
		var domain_id := str(domain_id_variant)
		if not domain_handlers.has(domain_id):
			kernel.free()
			return _failure("replay_domain_handler_missing")
		var registered := kernel.register_domain(domain_id, initial_states[domain_id] as Dictionary, domain_handlers[domain_id])
		if not bool(registered.get("accepted", false)):
			kernel.free()
			return _failure(str(registered.get("reason", "replay_domain_register_failed")))
	for command_variant in recipe.get("root_commands", []) as Array:
		var submitted := kernel.submit_command(command_variant as Dictionary)
		if not bool(submitted.get("accepted", false)):
			kernel.free()
			return _failure(str(submitted.get("reason", "replay_command_rejected")))
	var advanced := kernel.advance_ticks(int(recipe.get("final_tick", -1)))
	if not bool(advanced.get("accepted", false)):
		kernel.free()
		return _failure(str(advanced.get("reason", "replay_advance_failed")))
	var actual_log := kernel.execution_log()
	var expected_log := recipe.get("expected_execution_log", []) as Array
	var mismatch_count := 0
	if kernel.derived_commands() != recipe.get("expected_derived_commands", []):
		mismatch_count += 1
	if kernel.derived_outbox() != recipe.get("expected_derived_outbox", []):
		mismatch_count += 1
	if str(recipe.get("expected_derived_outbox_sha256", "")) != StateCodec.fingerprint(kernel.derived_outbox()):
		mismatch_count += 1
	if actual_log.size() != expected_log.size():
		mismatch_count += 1
	var shared_count: int = mini(actual_log.size(), expected_log.size())
	for index in range(shared_count):
		var actual := actual_log[index] as Dictionary
		var expected := expected_log[index] as Dictionary
		for field_name in ["authority_sequence", "tick", "command_sha256", "before_state_sha256", "after_state_sha256"]:
			if actual.get(field_name) != expected.get(field_name):
				mismatch_count += 1
	if str(recipe.get("expected_execution_log_sha256", "")) != StateCodec.fingerprint(actual_log):
		mismatch_count += 1
	var actual_terminal_hash := kernel.state_fingerprint()
	if str(recipe.get("expected_terminal_state_sha256", "")) != actual_terminal_hash:
		mismatch_count += 1
	var debug := kernel.debug_snapshot()
	if int(recipe.get("expected_pending_command_count", -1)) != int(debug.get("pending_command_count", -2)):
		mismatch_count += 1
	if int(recipe.get("expected_accepted_command_count", -1)) != int(debug.get("accepted_command_count", -2)):
		mismatch_count += 1
	if int(recipe.get("expected_root_command_count", -1)) != int(debug.get("root_command_count", -2)):
		mismatch_count += 1
	if int(recipe.get("expected_derived_command_count", -1)) != int(debug.get("derived_command_count", -2)):
		mismatch_count += 1
	if int(recipe.get("expected_derived_command_count", -1)) != int(debug.get("derived_outbox_count", -2)):
		mismatch_count += 1
	if int(recipe.get("expected_executed_command_count", -1)) != int(debug.get("executed_command_count", -2)):
		mismatch_count += 1
	var result := {
		"status": "PASS" if mismatch_count == 0 else "FAIL",
		"reason": "" if mismatch_count == 0 else "replay_state_or_log_mismatch",
		"replay_state_hash_mismatch_count": mismatch_count,
		"command_count": actual_log.size(),
		"root_command_count": int(debug.get("root_command_count", -1)),
		"derived_command_count": int(debug.get("derived_command_count", -1)),
		"derived_outbox_count": int(debug.get("derived_outbox_count", -1)),
		"pending_command_count": int(debug.get("pending_command_count", -1)),
		"execution_log_sha256": StateCodec.fingerprint(actual_log),
		"terminal_state_sha256": actual_terminal_hash,
	}
	kernel.free()
	return result


func _failure(reason: String) -> Dictionary:
	return {
		"status": "FAIL",
		"reason": reason,
		"replay_state_hash_mismatch_count": 1,
		"command_count": 0,
		"execution_log_sha256": "",
		"terminal_state_sha256": "",
	}


func _validate_recipe(recipe: Dictionary, domain_handlers: Dictionary) -> Dictionary:
	var expected_types := {
		"schema_version": TYPE_INT,
		"root_seed": TYPE_INT,
		"initial_domain_states": TYPE_DICTIONARY,
		"root_commands": TYPE_ARRAY,
		"expected_derived_commands": TYPE_ARRAY,
		"expected_derived_outbox": TYPE_ARRAY,
		"expected_derived_outbox_sha256": TYPE_STRING,
		"final_tick": TYPE_INT,
		"expected_pending_command_count": TYPE_INT,
		"expected_accepted_command_count": TYPE_INT,
		"expected_root_command_count": TYPE_INT,
		"expected_derived_command_count": TYPE_INT,
		"expected_executed_command_count": TYPE_INT,
		"expected_execution_log": TYPE_ARRAY,
		"expected_execution_log_sha256": TYPE_STRING,
		"expected_terminal_state_sha256": TYPE_STRING,
	}
	if recipe.size() != expected_types.size():
		return {"valid": false, "reason": "replay_recipe_field_count_mismatch"}
	for field_name_variant in expected_types.keys():
		var field_name := str(field_name_variant)
		if not recipe.has(field_name) or typeof(recipe.get(field_name)) != int(expected_types[field_name]):
			return {"valid": false, "reason": "replay_recipe_field_type_mismatch:%s" % field_name}
	if int(recipe.get("schema_version", 0)) != Kernel.SCHEMA_VERSION:
		return {"valid": false, "reason": "replay_recipe_schema_mismatch"}
	var closed_validation := StateCodec.validate(recipe)
	if not bool(closed_validation.get("valid", false)):
		return {"valid": false, "reason": str(closed_validation.get("reason", "replay_recipe_closed_data_invalid"))}
	var initial_states := recipe.get("initial_domain_states", {}) as Dictionary
	if initial_states.is_empty() or initial_states.size() != domain_handlers.size():
		return {"valid": false, "reason": "replay_recipe_domain_count_mismatch"}
	for domain_id_variant in initial_states.keys():
		if typeof(domain_id_variant) != TYPE_STRING or not (initial_states[domain_id_variant] is Dictionary) or not domain_handlers.has(str(domain_id_variant)):
			return {"valid": false, "reason": "replay_recipe_domain_binding_invalid"}
	var root_commands := recipe.get("root_commands", []) as Array
	var derived_commands := recipe.get("expected_derived_commands", []) as Array
	var command_ids := {}
	for command_inventory_variant in [root_commands, derived_commands]:
		for command_variant in command_inventory_variant as Array:
			if not (command_variant is Dictionary):
				return {"valid": false, "reason": "replay_recipe_command_shape_invalid"}
			var command := command_variant as Dictionary
			var command_validation := AuthorityCommand.validate(command)
			var command_id := str(command.get("command_id", ""))
			if not bool(command_validation.get("valid", false)) or not initial_states.has(str(command.get("domain_id", ""))) or command_ids.has(command_id):
				return {"valid": false, "reason": "replay_recipe_command_invalid"}
			command_ids[command_id] = true
	var expected_outbox := recipe.get("expected_derived_outbox", []) as Array
	if (
		expected_outbox.size() != derived_commands.size()
		or str(recipe.get("expected_derived_outbox_sha256", "")).is_empty()
		or str(recipe.get("expected_derived_outbox_sha256", "")) != StateCodec.fingerprint(expected_outbox)
	):
		return {"valid": false, "reason": "replay_recipe_derived_outbox_identity_mismatch"}
	var final_tick := int(recipe.get("final_tick", -1))
	var pending_count := int(recipe.get("expected_pending_command_count", -1))
	var accepted_count := int(recipe.get("expected_accepted_command_count", -1))
	var root_count := int(recipe.get("expected_root_command_count", -1))
	var derived_count := int(recipe.get("expected_derived_command_count", -1))
	var executed_count := int(recipe.get("expected_executed_command_count", -1))
	if (
		final_tick < 0
		or pending_count < 0
		or executed_count < 0
		or root_count != root_commands.size()
		or derived_count != derived_commands.size()
		or accepted_count != root_count + derived_count
		or accepted_count != pending_count + executed_count
	):
		return {"valid": false, "reason": "replay_recipe_count_contract_mismatch"}
	var expected_log := recipe.get("expected_execution_log", []) as Array
	if expected_log.size() != executed_count or str(recipe.get("expected_execution_log_sha256", "")).is_empty() or str(recipe.get("expected_execution_log_sha256", "")) != StateCodec.fingerprint(expected_log):
		return {"valid": false, "reason": "replay_recipe_log_identity_mismatch"}
	if str(recipe.get("expected_terminal_state_sha256", "")).is_empty():
		return {"valid": false, "reason": "replay_recipe_terminal_identity_empty"}
	return {"valid": true, "reason": ""}
