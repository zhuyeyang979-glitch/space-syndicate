extends Node

const AuthorityCommand := preload("res://scripts/v076/simulation/v076_authority_command_v1.gd")
const Kernel := preload("res://scripts/v076/simulation/v076_deterministic_kernel.gd")
const ReplayRunner := preload("res://scripts/v076/simulation/v076_replay_runner.gd")

const REPLAY_TARGET := 2000


class CounterDomain extends RefCounted:
	func v076_domain_contract(domain_id: String) -> Dictionary:
		return {
			"schema_version": 1,
			"domain_id": domain_id,
			"stateless_handler": true,
			"deterministic": true,
			"replay_safe": true,
			"external_side_effects_allowed": false,
			"owns_presentation": false,
			"derived_only_command_types": [],
		}

	func v076_apply_command(state: Dictionary, command: Dictionary, rng: Variant) -> Dictionary:
		var payload := command.get("payload", {}) as Dictionary
		match str(command.get("command_type", "")):
			"add":
				state["value"] = int(state.get("value", 0)) + int(payload.get("amount", 0))
			"draw_add":
				state["value"] = int(state.get("value", 0)) + rng.randi_range(1, int(payload.get("maximum", 1)))
			_:
				return {"accepted": false, "reason": "unknown_bench_command", "outcome": "REJECT", "state": state, "receipt": {}, "derived_commands": []}
		return {
			"accepted": true,
			"reason": "",
			"outcome": "COMMIT",
			"state": state,
			"receipt": {"kind": str(command.get("command_type", "")), "value": int(state.get("value", 0))},
			"derived_commands": [],
		}


func _ready() -> void:
	var result := _run_bench()
	print("V076_DETERMINISTIC_KERNEL_BENCH|%s" % JSON.stringify(result))
	if str(result.get("status", "FAIL")) != "PASS":
		push_error("V076 deterministic kernel Bench failed: %s" % str(result.get("reason", "unknown")))
	# Keep the development-only Bench alive long enough for the external MCP
	# observer to persist and inspect the final receipt before clean stop.
	await get_tree().create_timer(10.0).timeout
	get_tree().quit(0 if str(result.get("status", "FAIL")) == "PASS" else 1)


func _run_bench() -> Dictionary:
	var kernel := Kernel.new()
	add_child(kernel)
	if not bool(kernel.configure(76001).get("accepted", false)):
		return {"status": "FAIL", "reason": "configure_failed"}
	if not bool(kernel.register_domain("combat", {"value": 0}, CounterDomain).get("accepted", false)):
		return {"status": "FAIL", "reason": "domain_register_failed"}
	var command_specs := [
		["cmd-3", "draw_add", 2, 3, {"maximum": 9}],
		["cmd-1", "add", 1, 1, {"amount": 4}],
		["cmd-2", "add", 1, 2, {"amount": 7}],
	]
	for spec_variant in command_specs:
		var spec := spec_variant as Array
		var built := AuthorityCommand.build(str(spec[0]), "combat", str(spec[1]), "player.local", int(spec[2]), 10, int(spec[3]), spec[4] as Dictionary)
		if not bool(built.get("accepted", false)) or not bool(kernel.submit_command(built.get("command", {}) as Dictionary).get("accepted", false)):
			return {"status": "FAIL", "reason": "command_submit_failed"}
	var advanced := kernel.advance_elapsed_us(1_000_000)
	if not bool(advanced.get("accepted", false)) or kernel.current_tick() != 20:
		return {"status": "FAIL", "reason": "twenty_hz_contract_failed"}
	var recipe_envelope := kernel.build_replay_recipe()
	var recipe := recipe_envelope.get("recipe", {}) as Dictionary
	var recipe_sha := str(recipe_envelope.get("recipe_sha256", ""))
	var runner := ReplayRunner.new()
	var mismatch_count := 0
	for _replay_index in range(REPLAY_TARGET):
		var replay := runner.verify(recipe, recipe_sha, {"combat": CounterDomain})
		if str(replay.get("status", "")) != "PASS" or int(replay.get("command_count", -1)) != 3 or int(replay.get("pending_command_count", -1)) != 0:
			mismatch_count += 1
		else:
			mismatch_count += int(replay.get("replay_state_hash_mismatch_count", 1))
	var debug := kernel.debug_snapshot()
	return {
		"status": "PASS" if mismatch_count == 0 and int(debug.get("float_authority_field_count", -1)) == 0 else "FAIL",
		"reason": "" if mismatch_count == 0 else "replay_mismatch",
		"tick_rate_hz": int(debug.get("tick_rate_hz", 0)),
		"tick_duration_us": int(debug.get("tick_duration_us", 0)),
		"current_tick": kernel.current_tick(),
		"ordered_command_count": kernel.execution_log().size(),
		"deterministic_replay_count": REPLAY_TARGET,
		"replay_state_hash_mismatch_count": mismatch_count,
		"float_authority_field_count": int(debug.get("float_authority_field_count", -1)),
		"same_seed_command_log_parity": mismatch_count == 0,
		"same_seed_state_hash_parity": mismatch_count == 0,
		"presentation_owns_authority": false,
		"terminal_state_sha256": kernel.state_fingerprint(),
	}
