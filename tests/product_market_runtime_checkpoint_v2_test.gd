extends SceneTree

const FIXTURE := preload("res://tests/product_market_save_v2_test_fixture.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var source := FIXTURE.make_controller(21.625, 9, 31)
	source.set("_futures_open_count", 3)
	source.set("_futures_settlement_count", 2)
	var checkpoint_a := source.capture_runtime_checkpoint()
	_expect(int(checkpoint_a.get("schema_version", 0)) == 2, "runtime checkpoint schema stays v2")
	_expect(FIXTURE.timer_is_f64_tag(checkpoint_a), "runtime checkpoint timer uses the shared closed F64 tag")
	source.market_timer = 3.0
	source.business_cycle_count = 0
	source.futures_position_sequence = 0
	source.set("_futures_open_count", 0)
	source.set("_futures_settlement_count", 0)
	var restored := source.restore_runtime_checkpoint(checkpoint_a)
	_expect(bool(restored.get("restored", false)) and source.capture_runtime_checkpoint() == checkpoint_a, "runtime checkpoint restores all v2 fields exactly")
	var before_invalid := source.capture_runtime_checkpoint()
	var invalid := checkpoint_a.duplicate(true)
	invalid["market_timer"] = {"codec": "f64_bits_hex_v1", "bits": "00"}
	var rejected := source.restore_runtime_checkpoint(invalid)
	_expect(not bool(rejected.get("restored", true)) and source.capture_runtime_checkpoint() == before_invalid, "invalid runtime checkpoint causes zero mutation")
	source.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("PRODUCT_MARKET_RUNTIME_CHECKPOINT_V2_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	if not _failures.is_empty():
		push_error("Product Market runtime checkpoint v2 failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
