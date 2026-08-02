extends SceneTree

const BENCH_SCENE := preload("res://scenes/tools/SaveResumeApplicationFlowBench.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bench := BENCH_SCENE.instantiate()
	bench.auto_run = false
	root.add_child(bench)
	var result: Dictionary = await bench.run_bench()
	bench.queue_free()
	await process_frame
	if bool(result.get("passed", false)):
		print("Save/resume application-flow test passed (%d checks)." % int(result.get("checks", 0)))
		quit(0)
		return
	push_error("Save/resume application-flow test failed:\n- " + "\n- ".join(result.get("failures", [])))
	quit(1)
