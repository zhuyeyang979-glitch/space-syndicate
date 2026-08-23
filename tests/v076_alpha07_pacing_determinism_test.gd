extends SceneTree

const AuthorityCommand := preload(
	"res://scripts/v076/simulation/v076_authority_command_v1.gd"
)
const Kernel := preload(
	"res://scripts/v076/simulation/v076_deterministic_kernel.gd"
)

const ROOT_SEED := 7607
const DOMAIN_ID := "pacing.proof"
const LOGICAL_DURATION_US := 2_000_000


class PacingProofDomain extends RefCounted:
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

	func v076_apply_command(
		state: Dictionary,
		command: Dictionary,
		rng: Variant
	) -> Dictionary:
		var payload := command.get("payload", {}) as Dictionary
		match str(command.get("command_type", "")):
			"add":
				state["value"] = int(state.get("value", 0)) + int(
					payload.get("amount", 0)
				)
			"draw_add":
				state["value"] = int(state.get("value", 0)) + rng.randi_range(
					1,
					int(payload.get("maximum", 1))
				)
			_:
				return {
					"accepted": false,
					"reason": "unknown_pacing_proof_command",
					"outcome": "REJECT",
					"state": state,
					"receipt": {},
					"derived_commands": [],
				}
		return {
			"accepted": true,
			"reason": "",
			"outcome": "COMMIT",
			"state": state,
			"receipt": {"value": int(state.get("value", 0))},
			"derived_commands": [],
		}


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var one_x := _run_pace_case("1x", 40, 50_000)
	var two_x := _run_pace_case("2x", 20, 100_000)
	var four_x := _run_pace_case("4x", 10, 200_000)
	var zero_elapsed := _run_zero_elapsed_case()
	_check(bool(one_x.get("accepted", false)), "1x pacing fixture completes")
	_check(bool(two_x.get("accepted", false)), "2x pacing fixture completes")
	_check(bool(four_x.get("accepted", false)), "4x pacing fixture completes")
	_check(
		bool(zero_elapsed.get("accepted", false)),
		"zero-elapsed pacing sentinel completes"
	)
	_check(
		int(one_x.get("current_tick", -1)) == 40
		and int(two_x.get("current_tick", -1)) == 40
		and int(four_x.get("current_tick", -1)) == 40,
		"1x 2x and 4x advance the same 40 logical ticks"
	)
	_check(
		str(one_x.get("state_fingerprint", ""))
		== str(two_x.get("state_fingerprint", ""))
		and str(two_x.get("state_fingerprint", ""))
		== str(four_x.get("state_fingerprint", "")),
		"pace multiplier preserves the authority state fingerprint"
	)
	_check(
		one_x.get("execution_log", []) == two_x.get("execution_log", [])
		and two_x.get("execution_log", []) == four_x.get("execution_log", []),
		"pace multiplier preserves the execution log"
	)
	_check(
		one_x.get("domain_rng", {}) == two_x.get("domain_rng", {})
		and two_x.get("domain_rng", {}) == four_x.get("domain_rng", {}),
		"pace multiplier preserves Domain RNG state and draw count"
	)
	_check(
		int(one_x.get("next_authority_sequence", -1))
		== int(two_x.get("next_authority_sequence", -2))
		and int(two_x.get("next_authority_sequence", -1))
		== int(four_x.get("next_authority_sequence", -2)),
		"pace multiplier preserves Authority Sequence"
	)
	_check(
		one_x.get("command_order", []) == two_x.get("command_order", [])
		and two_x.get("command_order", []) == four_x.get("command_order", []),
		"pace multiplier preserves command order"
	)
	_check(
		int(zero_elapsed.get("current_tick", -1)) == 0
		and int(zero_elapsed.get("next_authority_sequence", -1)) == 1
		and (zero_elapsed.get("execution_log", []) as Array).is_empty(),
		"zero elapsed advances no Tick, Authority Sequence, or command execution"
	)
	var summary_format := (
		"V076_ALPHA07_PACING_DETERMINISM"
		+ "|status=%s|passed=%d|total=%d"
		+ "|logical_tick_count=%d"
		+ "|pace_multiplier_replay_state_hash_parity=%s"
		+ "|pace_multiplier_rng_delta=%d"
		+ "|pace_multiplier_command_order_delta=%d"
		+ "|zero_elapsed_tick_delta=%d"
	)
	print(
		summary_format % [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			int(one_x.get("current_tick", -1)),
			str(
				str(one_x.get("state_fingerprint", ""))
				== str(two_x.get("state_fingerprint", ""))
				and str(two_x.get("state_fingerprint", ""))
				== str(four_x.get("state_fingerprint", ""))
			).to_lower(),
			_rng_draw_delta(one_x, two_x, four_x),
			_command_order_delta(one_x, two_x, four_x),
			int(zero_elapsed.get("current_tick", -1)),
		]
	)
	if not _failures.is_empty():
		push_error("\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _run_pace_case(label: String, step_count: int, elapsed_us: int) -> Dictionary:
	var fixture := _new_kernel()
	if not bool(fixture.get("accepted", false)):
		return fixture
	var kernel: Variant = fixture.get("kernel")
	for index in range(step_count):
		var advanced := kernel.advance_elapsed_us(elapsed_us) as Dictionary
		if not bool(advanced.get("accepted", false)):
			kernel.free()
			return {
				"accepted": false,
				"reason": "%s_step_%d:%s" % [
					label,
					index,
					str(advanced.get("reason", "advance_rejected")),
				],
			}
	var result := _kernel_result(kernel)
	result["accepted"] = true
	kernel.free()
	return result


func _run_zero_elapsed_case() -> Dictionary:
	var fixture := _new_kernel()
	if not bool(fixture.get("accepted", false)):
		return fixture
	var kernel: Variant = fixture.get("kernel")
	for _index in range(40):
		var advanced := kernel.advance_elapsed_us(0) as Dictionary
		if not bool(advanced.get("accepted", false)):
			kernel.free()
			return advanced
	var result := _kernel_result(kernel)
	result["accepted"] = true
	kernel.free()
	return result


func _new_kernel() -> Dictionary:
	var kernel := Kernel.new()
	var configured := kernel.configure(ROOT_SEED) as Dictionary
	if not bool(configured.get("accepted", false)):
		kernel.free()
		return configured
	var registered := kernel.register_domain(
		DOMAIN_ID,
		{"value": 0},
		PacingProofDomain
	) as Dictionary
	if not bool(registered.get("accepted", false)):
		kernel.free()
		return registered
	for command in _commands():
		var submitted := kernel.submit_command(command) as Dictionary
		if not bool(submitted.get("accepted", false)):
			kernel.free()
			return submitted
	return {"accepted": true, "kernel": kernel}


func _commands() -> Array[Dictionary]:
	return [
		_command("pace-add-a", "add", 1, 20, 2, {"amount": 7}),
		_command("pace-draw", "draw_add", 10, 10, 1, {"maximum": 97}),
		_command("pace-add-b", "add", 10, 10, 0, {"amount": 11}),
		_command("pace-add-c", "add", 25, 20, 3, {"amount": 13}),
	]


func _command(
	command_id: String,
	command_type: String,
	scheduled_tick: int,
	domain_priority: int,
	producer_sequence: int,
	payload: Dictionary
) -> Dictionary:
	var built := AuthorityCommand.build(
		command_id,
		DOMAIN_ID,
		command_type,
		"player.local",
		scheduled_tick,
		domain_priority,
		producer_sequence,
		payload
	) as Dictionary
	return built.get("command", {}) as Dictionary


func _kernel_result(kernel: Variant) -> Dictionary:
	var captured := kernel.capture_snapshot() as Dictionary
	var snapshot := captured.get("snapshot", {}) as Dictionary
	var command_order: Array[String] = []
	for entry_variant in kernel.execution_log() as Array:
		var entry := entry_variant as Dictionary
		var command := entry.get("command", {}) as Dictionary
		command_order.append(str(command.get("command_id", "")))
	return {
		"state_fingerprint": kernel.state_fingerprint(),
		"current_tick": kernel.current_tick(),
		"execution_log": kernel.execution_log(),
		"domain_rng": snapshot.get("domain_rng", {}),
		"next_authority_sequence": snapshot.get("next_authority_sequence", -1),
		"command_order": command_order,
	}


func _rng_draw_delta(
	one_x: Dictionary,
	two_x: Dictionary,
	four_x: Dictionary
) -> int:
	var one_draws := _draw_count(one_x)
	return maxi(
		absi(one_draws - _draw_count(two_x)),
		absi(one_draws - _draw_count(four_x))
	)


func _draw_count(result: Dictionary) -> int:
	var rng_by_domain := result.get("domain_rng", {}) as Dictionary
	var snapshot := rng_by_domain.get(DOMAIN_ID, {}) as Dictionary
	return int(snapshot.get("draw_count", -1))


func _command_order_delta(
	one_x: Dictionary,
	two_x: Dictionary,
	four_x: Dictionary
) -> int:
	return 0 if (
		one_x.get("command_order", []) == two_x.get("command_order", [])
		and two_x.get("command_order", []) == four_x.get("command_order", [])
	) else 1


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)
