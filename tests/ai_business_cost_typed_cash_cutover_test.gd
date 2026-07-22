extends SceneTree

const BENCH_SCENE := preload("res://scenes/tools/AiBusinessCostTypedCashCutoverBench.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bench: Node = BENCH_SCENE.instantiate()
	bench.set("auto_run", false)
	root.add_child(bench)
	await process_frame
	var report: Dictionary = bench.call("run_suite") as Dictionary
	var passed := str(report.get("status", "FAIL")) == "PASS" and int(report.get("failure_count", -1)) == 0
	print("AI_BUSINESS_COST_TYPED_CASH_CUTOVER_TEST|status=%s|checks=%d|failures=%d|details=%s" % [
		"PASS" if passed else "FAIL",
		int(report.get("check_count", 0)),
		int(report.get("failure_count", -1)),
		JSON.stringify(report.get("failures", [])),
	])
	quit(0 if passed else 1)
