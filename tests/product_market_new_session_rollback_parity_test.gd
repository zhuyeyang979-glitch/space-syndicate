extends SceneTree

const FIXTURE := preload("res://tests/product_market_save_v2_test_fixture.gd")

var _checks := 0
var _failures: Array[String] = []


class WorldFixture:
	extends Node

	var completed_cycles: Array[int] = []

	func _on_product_market_cycle_completed(cycle: int) -> void:
		completed_cycles.append(cycle)


func _init() -> void:
	var reference := FIXTURE.make_controller(23.125, 17, 41)
	var restored_target := FIXTURE.make_controller(2.0, 1, 1)
	FIXTURE.seed_non_default_runtime(reference, 3)
	var before_wire := reference.to_save_data()
	var before_runtime := reference.runtime_state_snapshot()
	var before_timer_bits := FIXTURE.timer_bits(before_wire)
	var receipt := restored_target.restore_new_session_checkpoint(before_wire)
	var after_wire := restored_target.to_save_data()
	var after_runtime := restored_target.runtime_state_snapshot()
	_expect(bool(receipt.get("restored", false)), "Save v2 new-session checkpoint restores")
	_expect(after_wire == before_wire, "Product Market Save wire before equals after")
	_expect(after_runtime == before_runtime, "Product Market runtime before equals after")
	_expect(FIXTURE.timer_bits(after_wire) == before_timer_bits, "market timer F64 bits before equal after")
	_expect(restored_target.business_cycle_count == reference.business_cycle_count, "business cycle count has parity")
	_expect(restored_target.futures_position_sequence == reference.futures_position_sequence, "futures sequence has parity")
	var reference_world := WorldFixture.new()
	var restored_world := WorldFixture.new()
	var reference_rng := RunRngService.new()
	var restored_rng := RunRngService.new()
	reference_rng.set_seed(424242)
	restored_rng.set_seed(424242)
	var reference_bridge := ProductMarketRuntimeWorldBridge.new()
	var restored_bridge := ProductMarketRuntimeWorldBridge.new()
	reference_bridge.bind_world(reference_world)
	restored_bridge.bind_world(restored_world)
	reference_bridge.set_rng_service(reference_rng)
	restored_bridge.set_rng_service(restored_rng)
	reference.set_world_bridge(reference_bridge)
	restored_target.set_world_bridge(restored_bridge)
	var tick_delta := reference.market_timer + 0.001
	var reference_tick := reference.tick_market_cycle(tick_delta)
	var restored_tick := restored_target.tick_market_cycle(tick_delta)
	_expect(bool(reference_tick.get("ticked", false)) and reference_tick == restored_tick, "both authorities cross the same next market tick exactly once")
	_expect(reference.to_save_data() == restored_target.to_save_data() \
			and reference.runtime_state_snapshot() == restored_target.runtime_state_snapshot(), "next market tick produces identical price and timer authority")
	_expect(reference_rng.capture_plan_checkpoint() == restored_rng.capture_plan_checkpoint() \
			and reference_world.completed_cycles == restored_world.completed_cycles \
			and reference_world.completed_cycles.size() == 1, "next market tick preserves RNG and completion-callback parity")
	reference.free()
	restored_target.free()
	reference_bridge.free()
	restored_bridge.free()
	reference_rng.free()
	restored_rng.free()
	reference_world.free()
	restored_world.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("PRODUCT_MARKET_NEW_SESSION_ROLLBACK_PARITY_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	if not _failures.is_empty():
		push_error("Product Market new-session rollback parity failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
