extends SceneTree

const BENCH_SCENE := preload("res://scenes/tools/RegionCodexPublicSourceBench.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bench := BENCH_SCENE.instantiate()
	bench.set("auto_run", false)
	root.add_child(bench)
	await process_frame
	bench.call("run_suite")
	await process_frame
	var result := bench.call("debug_snapshot") as Dictionary
	var passed := bool(result.get("bench_complete", false)) and str(result.get("status", "")) == "PASS" and int(result.get("failure_count", -1)) == 0
	print("REGION CODEX PUBLIC SOURCE %s (%d checks)" % ["PASS" if passed else "FAIL", int(result.get("check_count", 0))])
	if not passed:
		push_error("Region Codex public source failures: %s" % str(result.get("failed_cases", "unknown")))
	bench.queue_free()
	await process_frame
	quit(0 if passed else 1)
