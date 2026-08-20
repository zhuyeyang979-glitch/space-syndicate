extends SceneTree

const AuthorityCommand := preload("res://scripts/v076/simulation/v076_authority_command_v1.gd")
const Kernel := preload("res://scripts/v076/simulation/v076_deterministic_kernel.gd")
const ReplayRunner := preload("res://scripts/v076/simulation/v076_replay_runner.gd")
const StateCodec := preload("res://scripts/v076/simulation/v076_authority_state_codec.gd")

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
		}

	func v076_apply_command(state: Dictionary, command: Dictionary, rng: Variant) -> Dictionary:
		var payload := command.get("payload", {}) as Dictionary
		match str(command.get("command_type", "")):
			"add":
				state["value"] = int(state.get("value", 0)) + int(payload.get("amount", 0))
			"multiply":
				state["value"] = int(state.get("value", 0)) * int(payload.get("amount", 1))
			"draw_add":
				state["value"] = int(state.get("value", 0)) + rng.randi_range(1, int(payload.get("maximum", 1)))
			"draw_then_reject":
				state["value"] = int(state.get("value", 0)) + rng.randi_range(1, int(payload.get("maximum", 1)))
				return {"accepted": false, "reason": "intentional_transaction_rejection", "state": state, "receipt": {}}
			_:
				return {"accepted": false, "reason": "unknown_test_command", "state": state, "receipt": {}}
		return {"accepted": true, "reason": "", "state": state, "receipt": {"value": int(state.get("value", 0))}}


class UnsafeDomain extends CounterDomain:
	func v076_domain_contract(domain_id: String) -> Dictionary:
		var contract := super.v076_domain_contract(domain_id)
		contract["external_side_effects_allowed"] = true
		return contract


class CachedChildFactory extends RefCounted:
	var cached := CounterDomain.new()

	func v076_domain_contract(domain_id: String) -> Dictionary:
		return cached.v076_domain_contract(domain_id)

	func v076_create_handler(_domain_id: String) -> RefCounted:
		return cached


var _checks := 0
var _failures: Array[String] = []
var _replay_count := 0
var _replay_mismatch_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_closed_authority_codec()
	_test_command_envelope_types()
	_test_twenty_hz_integer_clock()
	_test_domain_handler_purity_contract()
	_test_stable_same_tick_order()
	_test_domain_rng_isolation()
	_test_tick_transaction_rollback()
	_test_snapshot_restore_and_pending_queue()
	_test_duplicate_and_collision_contract()
	_test_replay_tamper_detection()
	_test_two_thousand_replays()
	_test_static_authority_boundaries()
	print("V076_DETERMINISTIC_KERNEL_TEST|%s|%d/%d|V076_DETERMINISTIC_REPLAY_COUNT=%d|V076_STATE_HASH_MISMATCH_COUNT=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
		_replay_count,
		_replay_mismatch_count,
	])
	if not _failures.is_empty():
		push_error("\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _test_closed_authority_codec() -> void:
	_check(bool(StateCodec.validate({"ok": [null, true, 7, "text"]}).get("valid", false)), "closed authority codec accepts only approved scalar/container types")
	_check(not bool(StateCodec.validate({"value": 0.25}).get("valid", true)), "authority codec rejects float values")
	_check(not bool(StateCodec.validate({"value": 9_007_199_254_740_992}).get("valid", true)), "authority codec rejects integers that cannot round-trip through canonical JSON")
	_check(not bool(StateCodec.validate({StringName("key"): 1}).get("valid", true)), "authority codec rejects non-String dictionary keys")
	_check(not bool(StateCodec.validate({"presentation": {"flash": true}}).get("valid", true)), "authority codec rejects presentation fields")
	_check(not bool(StateCodec.validate({"ui_state": {"selected": true}}).get("valid", true)), "authority codec rejects presentation-token compound fields")
	_check(not bool(StateCodec.validate({"cameraPosition": 7}).get("valid", true)), "authority codec rejects camelCase presentation fields")
	_check(bool(StateCodec.validate({"build": 7, "equity": 3}).get("valid", false)), "camelCase guard does not reject ordinary authority words containing ui substrings")
	_check(StateCodec.fingerprint({"b": 2, "a": 1}) == StateCodec.fingerprint({"a": 1, "b": 2}), "authority dictionary insertion order does not change state hash")


func _test_command_envelope_types() -> void:
	var valid := _command("typed", "combat", "add", "actor", 1, 1, 1, {"amount": 1})
	_check(bool(AuthorityCommand.validate(valid).get("valid", false)) and not AuthorityCommand.fingerprint(valid).is_empty(), "well-typed command envelope has a non-empty SHA256 identity")
	var float_schema := valid.duplicate(true)
	float_schema["schema_version"] = 1.0
	_check(not bool(AuthorityCommand.validate(float_schema).get("valid", true)), "float schema_version cannot pass integer command contract")
	var string_name_hash := valid.duplicate(true)
	string_name_hash["payload_sha256"] = StringName(str(valid.get("payload_sha256", "")))
	_check(not bool(AuthorityCommand.validate(string_name_hash).get("valid", true)), "StringName payload hash cannot pass String command contract")
	var unsafe_priority := valid.duplicate(true)
	unsafe_priority["domain_priority"] = 9_007_199_254_740_992
	_check(not bool(AuthorityCommand.validate(unsafe_priority).get("valid", true)), "command integer fields must remain canonical-JSON safe")


func _test_domain_handler_purity_contract() -> void:
	var unsafe_kernel := Kernel.new()
	unsafe_kernel.configure(7)
	_check(not bool(unsafe_kernel.register_domain("combat", {"value": 0}, UnsafeDomain).get("accepted", true)), "domain reducer declaring external side effects is rejected")
	var reusing_kernel := Kernel.new()
	reusing_kernel.configure(7)
	_check(not bool(reusing_kernel.register_domain("combat", {"value": 0}, CachedChildFactory.new()).get("accepted", true)), "cached-child factories cannot enter the Script-only fresh reducer API")
	var unsafe_seed_kernel := Kernel.new()
	_check(not bool(unsafe_seed_kernel.configure(9_007_199_254_740_992).get("accepted", true)), "kernel rejects an unsafe root seed before configuration becomes permanent")
	unsafe_kernel.free(); reusing_kernel.free(); unsafe_seed_kernel.free()


func _test_twenty_hz_integer_clock() -> void:
	var fixture := _new_kernel(17, ["combat"])
	var kernel: Variant = fixture.get("kernel")
	var partial: Dictionary = kernel.advance_elapsed_us(49_999)
	_check(bool(partial.get("accepted", false)) and kernel.current_tick() == 0, "less than 50000us does not advance authority")
	var boundary: Dictionary = kernel.advance_elapsed_us(1)
	_check(bool(boundary.get("accepted", false)) and kernel.current_tick() == 1, "50000us advances exactly one authority tick")
	var rest: Dictionary = kernel.advance_elapsed_us(950_000)
	_check(bool(rest.get("accepted", false)) and kernel.current_tick() == 20, "one integer second advances exactly 20 ticks")
	_check(int(kernel.debug_snapshot().get("float_authority_field_count", -1)) == 0, "kernel authoritative projection contains zero float fields")
	kernel.free()


func _test_stable_same_tick_order() -> void:
	var commands := [
		_command("id-z", "domain.b", "add", "actor.b", 1, 20, 2, {"amount": 1}),
		_command("id-a", "domain.a", "add", "actor.b", 1, 20, 2, {"amount": 1}),
		_command("actor-first", "domain.a", "add", "actor.a", 1, 20, 2, {"amount": 1}),
		_command("producer-first", "domain.a", "add", "actor.a", 1, 20, 1, {"amount": 1}),
		_command("command-b", "domain.a", "add", "actor.a", 1, 20, 0, {"amount": 1}),
		_command("command-a", "domain.a", "add", "actor.a", 1, 20, 0, {"amount": 1}),
		_command("priority-first", "domain.b", "add", "actor.z", 1, 10, 9, {"amount": 1}),
	]
	var reversed := commands.duplicate(true)
	reversed.reverse()
	var left := _run_commands(300, commands, 1, ["domain.a", "domain.b"])
	var right := _run_commands(300, reversed, 1, ["domain.a", "domain.b"])
	_check(left.hash == right.hash and left.log == right.log, "arrival order cannot change stable same-tick command order")
	var ordered_ids: Array[String] = []
	for entry_variant in left.log as Array:
		ordered_ids.append(str(((entry_variant as Dictionary).get("command", {}) as Dictionary).get("command_id", "")))
	_check(ordered_ids == ["priority-first", "command-a", "command-b", "producer-first", "actor-first", "id-a", "id-z"], "stable ordering covers priority, domain, actor, producer sequence, and command ID tie-breaks")
	_check(int((left.log[0] as Dictionary).get("authority_sequence", 0)) == 1 and int((left.log[6] as Dictionary).get("authority_sequence", 0)) == 7, "kernel assigns one monotonic Authority Sequence after stable sorting")
	var log_chain_green := true
	for index in range((left.log as Array).size() - 1):
		if str((left.log[index] as Dictionary).get("after_state_sha256", "")) != str((left.log[index + 1] as Dictionary).get("before_state_sha256", "")):
			log_chain_green = false
	for entry_variant in left.log as Array:
		var entry := entry_variant as Dictionary
		if str(entry.get("command_sha256", "")) != StateCodec.fingerprint(entry.get("command", {})):
			log_chain_green = false
	_check(log_chain_green, "per-command hashes bind the sequenced command and form one before/after chain")
	_check(str(left.recipe_sha) == str(right.recipe_sha), "arrival order cannot change canonical replay recipe identity")


func _test_domain_rng_isolation() -> void:
	var base_commands := [
		_command("b-draw", "domain.b", "draw_add", "actor", 2, 10, 1, {"maximum": 1000}),
	]
	var extra_commands := [
		_command("a-extra", "domain.a", "draw_add", "actor", 1, 10, 1, {"maximum": 1000}),
		base_commands[0],
	]
	var left := _run_commands(444, base_commands, 2, ["domain.a", "domain.b"])
	var right := _run_commands(444, extra_commands, 2, ["domain.a", "domain.b"])
	_check((left.states as Dictionary)["domain.b"] == (right.states as Dictionary)["domain.b"], "extra Domain A RNG draw cannot perturb Domain B")


func _test_tick_transaction_rollback() -> void:
	var fixture := _new_kernel(515, ["combat"])
	var kernel: Variant = fixture.get("kernel")
	var command := _command("reject-after-draw", "combat", "draw_then_reject", "actor", 1, 1, 1, {"maximum": 99})
	_check(bool(kernel.submit_command(command).get("accepted", false)), "transaction rollback fixture command is accepted into the pending queue")
	var before_hash: String = kernel.state_fingerprint()
	var before_state: Dictionary = kernel.domain_state("combat")
	var failed: Dictionary = kernel.advance_elapsed_us(50_000)
	var debug: Dictionary = kernel.debug_snapshot()
	_check(not bool(failed.get("accepted", true)) and str(failed.get("reason", "")) == "intentional_transaction_rejection", "domain rejection is surfaced without a partial tick")
	_check(kernel.current_tick() == 0 and int(debug.get("next_authority_sequence", 0)) == 1 and int(debug.get("pending_command_count", 0)) == 1, "failed tick preserves tick, Authority Sequence, and pending command")
	_check(kernel.state_fingerprint() == before_hash and kernel.domain_state("combat") == before_state and kernel.execution_log().is_empty(), "failed tick rolls back staged state, Domain RNG, and execution log")
	kernel.free()


func _test_snapshot_restore_and_pending_queue() -> void:
	var fixture := _new_kernel(808, ["combat"])
	var kernel: Variant = fixture.get("kernel")
	kernel.submit_command(_command("early", "combat", "draw_add", "actor", 1, 1, 1, {"maximum": 7}))
	kernel.submit_command(_command("pending", "combat", "draw_add", "actor", 4, 1, 2, {"maximum": 7}))
	kernel.advance_ticks(2)
	var envelope: Dictionary = kernel.capture_snapshot()
	_check(bool(envelope.get("accepted", false)), "snapshot is accepted at an authority tick boundary")
	var snapshot_rng := (((envelope.get("snapshot", {}) as Dictionary).get("domain_rng", {}) as Dictionary).get("combat", {}) as Dictionary)
	_check(int(snapshot_rng.get("draw_count", 0)) > 0, "snapshot binds a non-zero Domain RNG state and draw cursor")
	var partial: Variant = _new_kernel(808, ["combat"]).get("kernel")
	partial.advance_elapsed_us(1)
	_check(not bool(partial.capture_snapshot().get("accepted", true)), "snapshot is rejected between authority tick boundaries")
	partial.free()
	var restored: Variant = _new_kernel(808, ["combat"]).get("kernel")
	var restored_receipt: Dictionary = restored.restore_snapshot(envelope.get("snapshot", {}) as Dictionary, str(envelope.get("snapshot_sha256", "")))
	_check(bool(restored_receipt.get("accepted", false)), "snapshot restore validates and restores exact state")
	var snapshot_serialized := StateCodec.serialize(envelope.get("snapshot", {}))
	var snapshot_roundtrip := StateCodec.deserialize(str(snapshot_serialized.get("serialized", "")), str(envelope.get("snapshot_sha256", "")))
	var byte_restored: Variant = _new_kernel(808, ["combat"]).get("kernel")
	_check(bool(snapshot_roundtrip.get("valid", false)) and bool(byte_restored.restore_snapshot(snapshot_roundtrip.get("value", {}) as Dictionary, str(envelope.get("snapshot_sha256", ""))).get("accepted", false)), "snapshot survives canonical byte serialization with strict integer restoration")
	kernel.advance_ticks(3)
	restored.advance_ticks(3)
	_check(kernel.state_fingerprint() == restored.state_fingerprint() and kernel.execution_log() == restored.execution_log(), "snapshot restore preserves pending command, RNG cursor, log, and continuation hash")
	var tampered := (envelope.get("snapshot", {}) as Dictionary).duplicate(true)
	tampered["current_tick"] = int(tampered.get("current_tick", 0)) + 1
	var rejected: Variant = _new_kernel(808, ["combat"]).get("kernel")
	_check(not bool(rejected.restore_snapshot(tampered, str(envelope.get("snapshot_sha256", ""))).get("accepted", true)), "single-byte-equivalent snapshot mutation is rejected by SHA256")
	var wrong_shape := (envelope.get("snapshot", {}) as Dictionary).duplicate(true)
	wrong_shape["domain_states"] = []
	_check(not bool(rejected.restore_snapshot(wrong_shape, StateCodec.fingerprint(wrong_shape)).get("accepted", true)), "hash-valid wrong-shape snapshot fails closed without a cast error")
	var forged_log_snapshot := (envelope.get("snapshot", {}) as Dictionary).duplicate(true)
	var forged_snapshot_log := (forged_log_snapshot.get("execution_log", []) as Array).duplicate(true)
	var forged_snapshot_entry := (forged_snapshot_log[0] as Dictionary).duplicate(true)
	forged_snapshot_entry["after_state_sha256"] = "0".repeat(64)
	forged_snapshot_log[0] = forged_snapshot_entry
	forged_log_snapshot["execution_log"] = forged_snapshot_log
	forged_log_snapshot["execution_log_sha256"] = StateCodec.fingerprint(forged_snapshot_log)
	_check(not bool(rejected.restore_snapshot(forged_log_snapshot, StateCodec.fingerprint(forged_log_snapshot)).get("accepted", true)), "re-signed snapshot execution-log tamper fails semantic replay")
	var forged_tick_snapshot := (envelope.get("snapshot", {}) as Dictionary).duplicate(true)
	var forged_tick_hashes := (forged_tick_snapshot.get("tick_hashes", []) as Array).duplicate(true)
	var forged_tick_entry := (forged_tick_hashes[0] as Dictionary).duplicate(true)
	forged_tick_entry["state_sha256"] = "0".repeat(64)
	forged_tick_hashes[0] = forged_tick_entry
	forged_tick_snapshot["tick_hashes"] = forged_tick_hashes
	_check(not bool(rejected.restore_snapshot(forged_tick_snapshot, StateCodec.fingerprint(forged_tick_snapshot)).get("accepted", true)), "re-signed snapshot tick-hash tamper fails semantic replay")
	var multi_fixture := _new_kernel(808, ["domain.a", "domain.b"])
	var multi: Variant = multi_fixture.get("kernel")
	multi.submit_command(_command("draw-a", "domain.a", "draw_add", "actor", 1, 1, 1, {"maximum": 9}))
	multi.submit_command(_command("draw-b", "domain.b", "draw_add", "actor", 1, 1, 2, {"maximum": 9}))
	multi.advance_ticks(1)
	var multi_envelope: Dictionary = multi.capture_snapshot()
	var semantic_tamper := (multi_envelope.get("snapshot", {}) as Dictionary).duplicate(true)
	var semantic_rng := (semantic_tamper.get("domain_rng", {}) as Dictionary).duplicate(true)
	var bad_b := (semantic_rng.get("domain.b", {}) as Dictionary).duplicate(true)
	bad_b["state"] = 0
	semantic_rng["domain.b"] = bad_b
	semantic_tamper["domain_rng"] = semantic_rng
	var atomic_target: Variant = _new_kernel(808, ["domain.a", "domain.b"]).get("kernel")
	var atomic_before: String = atomic_target.state_fingerprint()
	var semantic_sha := StateCodec.fingerprint(semantic_tamper)
	_check(not bool(atomic_target.restore_snapshot(semantic_tamper, semantic_sha).get("accepted", true)) and atomic_target.state_fingerprint() == atomic_before, "semantic restore failure leaves all live domain states and RNGs unchanged")
	kernel.free(); restored.free(); byte_restored.free(); rejected.free(); multi.free(); atomic_target.free()


func _test_duplicate_and_collision_contract() -> void:
	var fixture := _new_kernel(99, ["combat"])
	var kernel: Variant = fixture.get("kernel")
	var command := _command("exact-once", "combat", "add", "actor", 1, 1, 1, {"amount": 6})
	var first: Dictionary = kernel.submit_command(command)
	var duplicate: Dictionary = kernel.submit_command(command)
	_check(bool(first.get("accepted", false)) and bool(duplicate.get("accepted", false)) and bool(duplicate.get("duplicate", false)), "exact duplicate command is acknowledged without second enqueue")
	var collision := command.duplicate(true)
	collision["payload"] = {"amount": 9}
	collision["payload_sha256"] = StateCodec.fingerprint(collision["payload"])
	_check(not bool(kernel.submit_command(collision).get("accepted", true)), "same command ID with different payload fails closed")
	kernel.advance_ticks(1)
	_check(kernel.execution_log().size() == 1 and int(kernel.domain_state("combat").get("value", 0)) == 6, "duplicate command creates exactly one authority effect")
	kernel.free()


func _test_replay_tamper_detection() -> void:
	var run := _run_commands(771, [_command("one", "combat", "add", "actor", 1, 1, 1, {"amount": 3})], 1)
	var recipe := (run.recipe as Dictionary).duplicate(true)
	recipe["final_tick"] = 2
	var runner := ReplayRunner.new()
	var replay := runner.verify(recipe, str(run.recipe_sha), {"combat": CounterDomain})
	_check(str(replay.get("status", "")) == "FAIL" and str(replay.get("reason", "")) == "replay_recipe_hash_mismatch", "tampered replay recipe fails before execution")
	var forged := (run.recipe as Dictionary).duplicate(true)
	var forged_log := (forged.get("expected_execution_log", []) as Array).duplicate(true)
	var forged_entry := (forged_log[0] as Dictionary).duplicate(true)
	forged_entry["after_state_sha256"] = "0".repeat(64)
	forged_log[0] = forged_entry
	forged["expected_execution_log"] = forged_log
	forged["expected_execution_log_sha256"] = StateCodec.fingerprint(forged_log)
	var forged_replay := runner.verify(forged, StateCodec.fingerprint(forged), {"combat": CounterDomain})
	_check(str(forged_replay.get("status", "")) == "FAIL" and int(forged_replay.get("replay_state_hash_mismatch_count", 0)) > 0, "re-signed command-log tamper still fails replay semantics")
	var wrong_schema := (run.recipe as Dictionary).duplicate(true)
	wrong_schema["schema_version"] = 999
	var schema_replay := runner.verify(wrong_schema, StateCodec.fingerprint(wrong_schema), {"combat": CounterDomain})
	_check(str(schema_replay.get("status", "")) == "FAIL" and str(schema_replay.get("reason", "")) == "replay_recipe_schema_mismatch", "re-signed unknown replay schema fails before kernel execution")
	var wrong_recipe_shape := (run.recipe as Dictionary).duplicate(true)
	wrong_recipe_shape["commands"] = {}
	var shape_replay := runner.verify(wrong_recipe_shape, StateCodec.fingerprint(wrong_recipe_shape), {"combat": CounterDomain})
	_check(str(shape_replay.get("status", "")) == "FAIL" and str(shape_replay.get("reason", "")).begins_with("replay_recipe_field_type_mismatch"), "hash-valid wrong-shape replay recipe fails closed")
	var pending_kernel: Variant = _new_kernel(771, ["combat"]).get("kernel")
	pending_kernel.submit_command(_command("future", "combat", "add", "actor", 5, 1, 1, {"amount": 1}))
	var empty_kernel: Variant = _new_kernel(771, ["combat"]).get("kernel")
	_check(pending_kernel.state_fingerprint() != empty_kernel.state_fingerprint(), "pending future commands participate in authority state identity")
	pending_kernel.free(); empty_kernel.free()


func _test_two_thousand_replays() -> void:
	var commands := [
		_command("one", "combat", "add", "actor.a", 1, 2, 1, {"amount": 2}),
		_command("two", "combat", "multiply", "actor.b", 1, 2, 2, {"amount": 4}),
		_command("three", "combat", "draw_add", "actor.a", 3, 2, 3, {"maximum": 11}),
	]
	var run := _run_commands(76076, commands, 5)
	_check(str(run.get("status", "")) == "PASS" and (run.log as Array).size() == 3, "replay source run completed all expected commands before acceptance")
	var serialized_envelope := StateCodec.serialize(run.recipe)
	var roundtrip := StateCodec.deserialize(str(serialized_envelope.get("serialized", "")), str(run.recipe_sha))
	var roundtrip_recipe: Variant = roundtrip.get("value", {})
	_check(bool(roundtrip.get("valid", false)) and roundtrip_recipe is Dictionary and StateCodec.fingerprint(roundtrip_recipe) == str(run.recipe_sha), "replay recipe survives a canonical JSON byte round-trip with integers restored explicitly")
	var runner := ReplayRunner.new()
	for _index in range(REPLAY_TARGET):
		var replay := runner.verify(roundtrip_recipe as Dictionary, str(run.recipe_sha), {"combat": CounterDomain})
		_replay_count += 1
		if str(replay.get("status", "")) != "PASS" or int(replay.get("command_count", -1)) != 3 or int(replay.get("pending_command_count", -1)) != 0:
			_replay_mismatch_count += 1
		else:
			_replay_mismatch_count += int(replay.get("replay_state_hash_mismatch_count", 1))
	_check(_replay_count == REPLAY_TARGET, "deterministic replay acceptance executes at least 2000 independent replays")
	_check(_replay_mismatch_count == 0, "all deterministic replays preserve command log and state hashes")


func _test_static_authority_boundaries() -> void:
	var kernel_source := FileAccess.get_file_as_string("res://scripts/v076/simulation/v076_deterministic_kernel.gd")
	var rng_source := FileAccess.get_file_as_string("res://scripts/v076/simulation/v076_domain_rng.gd")
	var combined := kernel_source + "\n" + rng_source
	_check(not kernel_source.contains("func _process(") and not kernel_source.contains("func _physics_process("), "authority kernel owns no frame callback")
	_check(not combined.contains("Time.") and not combined.contains("OS.") and not combined.contains("Engine."), "authority kernel does not read wall, OS, or engine time")
	_check(not combined.contains("randf(") and not combined.contains("randomize(") and not combined.contains("RandomNumberGenerator"), "Domain RNG exposes integer-only deterministic draws")
	_check(not kernel_source.contains("CanvasItem") and not kernel_source.contains("Control") and not kernel_source.contains("GameScreen"), "presentation nodes cannot own or mutate authority")


func _new_kernel(seed: int, domains: Array[String]) -> Dictionary:
	var kernel := Kernel.new()
	var configured := kernel.configure(seed)
	if not bool(configured.get("accepted", false)):
		return {"kernel": kernel, "domains": {}}
	var handlers := {}
	for domain_id in domains:
		var handler: Variant = CounterDomain
		handlers[domain_id] = handler
		kernel.register_domain(domain_id, {"value": 0}, handler)
	return {"kernel": kernel, "domains": handlers}


func _run_commands(seed: int, commands: Array, tick_count: int, domains: Array[String] = ["combat"]) -> Dictionary:
	var fixture := _new_kernel(seed, domains)
	var kernel: Variant = fixture.get("kernel")
	for command_variant in commands:
		var submitted: Dictionary = kernel.submit_command(command_variant as Dictionary)
		if not bool(submitted.get("accepted", false)):
			kernel.free()
			return {"status": "FAIL", "reason": str(submitted.get("reason", "submit_failed")), "hash": "", "state": {}, "states": {}, "log": [], "recipe": {}, "recipe_sha": ""}
	var advanced: Dictionary = kernel.advance_ticks(tick_count)
	if not bool(advanced.get("accepted", false)):
		kernel.free()
		return {"status": "FAIL", "reason": str(advanced.get("reason", "advance_failed")), "hash": "", "state": {}, "states": {}, "log": [], "recipe": {}, "recipe_sha": ""}
	var recipe_envelope: Dictionary = kernel.build_replay_recipe()
	if not bool(recipe_envelope.get("accepted", false)):
		kernel.free()
		return {"status": "FAIL", "reason": str(recipe_envelope.get("reason", "recipe_failed")), "hash": "", "state": {}, "states": {}, "log": [], "recipe": {}, "recipe_sha": ""}
	var states := {}
	for domain_id in domains:
		states[domain_id] = kernel.domain_state(domain_id)
	var result := {
		"status": "PASS",
		"reason": "",
		"hash": kernel.state_fingerprint(),
		"state": kernel.domain_state(domains[0]),
		"states": states,
		"log": kernel.execution_log(),
		"recipe": recipe_envelope.get("recipe", {}),
		"recipe_sha": recipe_envelope.get("recipe_sha256", ""),
	}
	kernel.free()
	return result


func _command(command_id: String, domain_id: String, command_type: String, actor_id: String, tick: int, priority: int, producer_sequence: int, payload: Dictionary) -> Dictionary:
	var built := AuthorityCommand.build(command_id, domain_id, command_type, actor_id, tick, priority, producer_sequence, payload)
	if not bool(built.get("accepted", false)):
		return {}
	return built.get("command", {}) as Dictionary


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
