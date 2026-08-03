extends SceneTree

const FIXTURE := preload("res://tests/product_market_save_v2_test_fixture.gd")

var _checks := 0
var _failures: Array[String] = []


class WorldFixture:
	extends Node

	var game_time := 123.5
	var mutation_count := 0

	func _on_product_market_cycle_completed(_cycle: int) -> void:
		mutation_count += 1


func _init() -> void:
	var source := FIXTURE.make_controller(26.75, 11, 34)
	var target := FIXTURE.make_controller(18.5, 5, 21)
	var world := WorldFixture.new()
	var rng := RunRngService.new()
	rng.set_seed(987654)
	var bridge := ProductMarketRuntimeWorldBridge.new()
	bridge.bind_world(world)
	bridge.set_rng_service(rng)
	target.set_world_bridge(bridge)
	var public_log_owner := PublicLogPresentationOwner.new()
	var public_log_port := PublicLogProducerPort.new()
	public_log_port.configure(public_log_owner)
	target.set_table_presentation_log_port(public_log_port, null)
	var valid_wire := source.to_save_data()
	var mutation_count := 0
	var world_mutation_count := 0
	var rng_draw_delta := 0
	var world_time_delta := 0.0
	var public_log_delta := 0
	var private_feedback_delta := 0
	var cases := FIXTURE.invalid_save_v2_cases(valid_wire)
	for case in cases:
		var before := target.capture_runtime_checkpoint()
		var rng_before := rng.capture_plan_checkpoint()
		var world_mutation_before := world.mutation_count
		var world_time_before := world.game_time
		var public_log_before := int(public_log_port.capture_session_checkpoint().get("sequence", 0))
		var receipt := target.restore_new_session_checkpoint(case.get("wire", {}) as Dictionary)
		var unchanged := target.capture_runtime_checkpoint() == before
		if not unchanged:
			mutation_count += 1
		_expect(not bool(receipt.get("restored", true)) and not bool(receipt.get("applied", true)), "%s fails closed" % str(case.get("id", "unknown")))
		_expect(unchanged, "%s causes zero Product Market mutation" % str(case.get("id", "unknown")))
		world_mutation_count += world.mutation_count - world_mutation_before
		rng_draw_delta += int(rng.capture_plan_checkpoint().get("draw_count", 0)) - int(rng_before.get("draw_count", 0))
		world_time_delta += world.game_time - world_time_before
		public_log_delta += int(public_log_port.capture_session_checkpoint().get("sequence", 0)) - public_log_before
	_expect(cases.size() == 10 and mutation_count == 0, "all ten invalid checkpoint classes are covered with zero mutation")
	_expect(world_mutation_count == 0 and rng_draw_delta == 0 and is_zero_approx(world_time_delta) and public_log_delta == 0, "invalid checkpoints mutate no World, RNG, clock, or public-log dependency")
	_expect(not FileAccess.get_file_as_string("res://scripts/runtime/product_market_runtime_controller.gd").contains("private_feedback"), "Product Market has no private-feedback dependency to mutate during restore")
	target.set("_ai_business_market_pressure_recovery_required", true)
	var ai_blocked_before := target.capture_runtime_checkpoint()
	var ai_blocked := target.restore_new_session_checkpoint(valid_wire)
	_expect(not bool(ai_blocked.get("restored", true)) and str(ai_blocked.get("reason_code", "")) == "ai_business_market_pressure_recovery_required", "AI market-pressure recovery gate remains fail closed")
	_expect(target.capture_runtime_checkpoint() == ai_blocked_before, "AI market-pressure recovery rejection causes zero mutation")
	target.set("_ai_business_market_pressure_recovery_required", false)
	source.free()
	target.free()
	bridge.free()
	rng.free()
	world.free()
	public_log_port.free()
	public_log_owner.free()
	print("PRODUCT_MARKET_INVALID_CHECKPOINT_ZERO_MUTATION_METRICS|cases=%d|mutation_count=%d|world_mutation_count=%d|rng_draw_delta=%d|world_time_delta=%.1f|public_log_delta=%d|private_feedback_delta=%d" % [cases.size(), mutation_count, world_mutation_count, rng_draw_delta, world_time_delta, public_log_delta, private_feedback_delta])
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("PRODUCT_MARKET_INVALID_CHECKPOINT_ZERO_MUTATION_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	if not _failures.is_empty():
		push_error("Product Market invalid checkpoint zero-mutation failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
