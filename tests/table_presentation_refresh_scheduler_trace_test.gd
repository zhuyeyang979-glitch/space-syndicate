extends SceneTree

var failures: Array[String] = []
var checks := 0


func _init() -> void:
	var scheduler := TablePresentationRefreshScheduler.new()
	scheduler.live_interval_seconds = 1.0
	scheduler.map_interval_seconds = 2.0
	scheduler.full_interval_seconds = 3.0
	scheduler.developer_interval_seconds = 4.0
	var initial := scheduler.advance_typed(0.0, false)
	_check(_kinds(initial) == [&"live", &"map", &"full"], "initial due order is live, map, full")
	scheduler.reset_table_cadence()
	_check(scheduler.advance_typed(0.5, false).is_empty(), "empty frame stays empty")
	_check(_kinds(scheduler.advance_typed(0.5, false)) == [&"live"], "single due receipt is deterministic")
	var large := scheduler.advance_typed(10.0, true)
	_check(_kinds(large) == [&"live", &"map", &"full", &"developer"], "large delta emits each due kind once in stable order")
	var sequences: Array[int] = []
	for receipt in initial + large:
		sequences.append(receipt.sequence)
	_check(_strictly_increasing(sequences), "receipt sequence is strictly increasing")
	scheduler.reset_table_cadence()
	var hidden_developer := scheduler.advance_typed(10.0, false)
	_check(not _kinds(hidden_developer).has(&"developer"), "developer-disabled cadence emits no developer receipt")
	_check(scheduler.immediate_typed(&"live").kind == &"live", "typed immediate request emits only requested kind")
	_check(scheduler.immediate_typed(&"unknown") == null, "unknown immediate kind fails closed")
	scheduler.free()
	print("table_presentation_refresh_scheduler_trace_test: %s %d/%d" % ["PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	if not failures.is_empty():
		push_error("\n- ".join(failures))
	quit(0 if failures.is_empty() else 1)


func _kinds(receipts: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for receipt in receipts:
		result.append(receipt.kind)
	return result


func _strictly_increasing(values: Array[int]) -> bool:
	for index in range(1, values.size()):
		if values[index] <= values[index - 1]:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
