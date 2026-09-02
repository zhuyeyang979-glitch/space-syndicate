extends SceneTree
## Focused regression only. Not a natural STEP11 execution or platform probe.
const Kernel := preload("res://scripts/v076/simulation/v076_deterministic_kernel.gd")
const Command := preload("res://scripts/v076/simulation/v076_authority_command_v1.gd")
const KernelTest := preload("res://tests/v076_deterministic_kernel_test.gd")
const Composition := preload("res://scenes/runtime/V075RuntimeComposition.tscn")

var _checks := 0
var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_pending_observation()
	await _test_production_terminal()
	print("V076_TERMINAL_DRAIN_OBSERVER|%s|%d/%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(), _checks])
	quit(0 if _failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(message)
		push_error(message)

func _test_pending_observation() -> void:
	var kernel := Kernel.new()
	if not kernel.has_method("pending_command_observation"):
		_check(false, "Kernel provides a read-only domain-scoped pending observer")
		kernel.free()
		return
	var before := kernel.debug_snapshot()
	var idle := kernel.call("pending_command_observation", "direct") as Dictionary
	_check(not bool(idle.get("valid", true)), "unconfigured observer fails closed")
	_check(kernel.debug_snapshot() == before, "invalid observation does not mutate idle Kernel")
	_check(bool(kernel.configure(917592522).get("accepted", false)), "unit Kernel configures")
	for domain_id in ["direct", "other"]:
		_check(bool(kernel.register_domain(domain_id, {"value": 0}, KernelTest.CounterDomain).get("accepted", false)), "unit domain registers")
	for args in [["d2", "direct", 2], ["d1", "direct", 1], ["o1", "other", 1]]:
		var built := Command.build(args[0], args[1], "add", "actor", args[2], 1, 0, {"amount": 1})
		_check(bool(kernel.submit_command(built.get("command", {})).get("accepted", false)), "unit command accepted")
	kernel.advance_elapsed_us(12345)
	before = kernel.debug_snapshot()
	var observed := kernel.call("pending_command_observation", "direct") as Dictionary
	_check(bool(observed.get("valid", false)), "partial-tick pending observation is valid")
	_check(int(observed.get("pending_command_count", -1)) == 2, "pending count excludes other domain")
	_check(int(observed.get("current_tick", -1)) == 0, "observation retains current authority tick")
	_check(str(observed.get("domain_id", "")) == "direct", "observation binds exact domain")
	_check(not bool(kernel.capture_snapshot().get("accepted", true)), "restorable snapshot still requires tick boundary")
	observed["pending_command_count"] = 99
	_check(int((kernel.call("pending_command_observation", "direct") as Dictionary).get("pending_command_count", -1)) == 2, "returned dictionary cannot mutate queue")
	for invalid_domain in ["", "missing"]:
		_check(not bool((kernel.call("pending_command_observation", invalid_domain) as Dictionary).get("valid", true)), "unknown domain observation fails closed")
	_check(kernel.debug_snapshot() == before, "all observation leaves time sequence RNG and authority unchanged")
	kernel.advance_elapsed_us(50000)
	var after_tick := kernel.call("pending_command_observation", "direct") as Dictionary
	_check(int(after_tick.get("pending_command_count", -1)) == 1 and int(after_tick.get("current_tick", -1)) == 1, "observer follows executed commands at partial tick")
	kernel.advance_elapsed_us(50000)
	_check(int((kernel.call("pending_command_observation", "direct") as Dictionary).get("pending_command_count", -1)) == 0, "drained domain reports zero without advancing time")
	kernel.free()

func _test_production_terminal() -> void:
	var flow := Composition.instantiate()
	root.add_child(flow)
	await process_frame
	flow.process_mode = Node.PROCESS_MODE_DISABLED
	var started := flow.call("_start_new_game", {
		"player_count": 4, "seed": 917592522, "map_seed": 917592522,
		"region_count": 16, "geography_complexity": "STANDARD",
		"land_ocean_profile": "BALANCED"}) as Dictionary
	_check(bool(started.get("accepted", false)), "real production composition initializes")
	var kernel := flow.get_node("V076DeterministicKernel")
	var runtime := flow.get_node("V075RuntimeOwner")
	for remainder in [1, 12345, 49999, 0]:
		var before := kernel.call("debug_snapshot") as Dictionary
		var elapsed: int = (int(remainder) - int(before.get("elapsed_remainder_us", 0)) + 50000) % 50000
		kernel.call("advance_elapsed_us", elapsed)
		before = kernel.call("debug_snapshot") as Dictionary
		var drain := flow.call("terminal_drain_snapshot") as Dictionary
		var snapshot := kernel.call("capture_snapshot") as Dictionary
		_check(bool(drain.get("valid", false)), "production drain valid at remainder %d" % remainder)
		_check(bool(drain.get("drained", false)), "unresolved-free Direct Action domain is drained")
		_check(bool(snapshot.get("accepted", false)) == (remainder == 0), "restorable snapshot contract unchanged")
		_check(kernel.call("debug_snapshot") == before, "production observation never advances or rewrites Kernel")
	kernel.call("advance_elapsed_us", 12345)
	var faults: Array = []
	flow.runtime_fault_presented.connect(func(receipt: Dictionary): faults.append(receipt.duplicate(true)))
	var settled := runtime.call("run_accelerated_until_settled", 8000) as Dictionary
	var debug := runtime.call("debug_snapshot") as Dictionary
	print("V076_TERMINAL_DRAIN_FOCUSED_FAULTS|%s" % JSON.stringify(faults))
	_check(bool(settled.get("accepted", false)) and str(debug.get("phase", "")) == "settled", "production composition completes major round at nonboundary")
	_check(int(debug.get("runtime_error_count", -1)) == 0 and faults.is_empty(), "terminal observer causes no runtime fault")
	_check(int(debug.get("final_settlement_count", -1)) == 1, "FinalSettlement commits exactly once")
	_check(int(debug.get("duplicate_settlement_count", -1)) == 0, "no duplicate FinalSettlement")
	flow.queue_free()
	await process_frame
	await process_frame
