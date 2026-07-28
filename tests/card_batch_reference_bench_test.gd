extends SceneTree

const BENCH_PATH := "res://scenes/tools/CardBatchReferenceBench.tscn"

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(BENCH_PATH) as PackedScene
	_expect(packed != null, "real CardBatch reference Bench scene loads")
	if packed == null:
		_finish()
		return
	var bench := packed.instantiate() as CardBatchReferenceBench
	root.add_child(bench)
	await process_frame
	var result := bench.last_result
	_expect(bool(result.get("passed", false)), "Bench runs proactive defense, commodity, bound action, and attack in one uninterrupted batch")
	_expect(int(result.get("card_receipt_count", -1)) == 4, "Bench commits all four locked cards exactly once")
	_expect(int(result.get("mid_resolution_gameplay_wait_count", -1)) == 0, "Bench records zero mid-resolution gameplay waits")
	_expect(int(result.get("counter_window_wait_seconds", -1)) == 0 and int(result.get("counter_stack_depth", -1)) == 0, "Bench has no retired counter timing")
	_expect(str(result.get("next_window_id", "")) == "card-window:000002" and bool(result.get("world_effective_time_running", false)), "batch-complete receipt opens the next window and resumes world time")
	var runtime := bench.get_node("CardBatchRuntime") as CardBatchReferenceRuntime
	var debug := runtime.debug_snapshot()
	_expect(not bool(debug.get("production_wired", true)) and not bool(debug.get("production_cutover", true)), "Bench remains a passive V0.7 reference and never claims production cutover")
	root.remove_child(bench)
	bench.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CARD_BATCH_REFERENCE_BENCH_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	push_error("CARD_BATCH_REFERENCE_BENCH_TEST|status=FAIL|checks=%d|failures=%d\n- %s" % [_checks, _failures.size(), "\n- ".join(_failures)])
	quit(1)
