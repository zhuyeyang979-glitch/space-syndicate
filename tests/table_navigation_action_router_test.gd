extends SceneTree

const BENCH_SCENE := preload("res://scenes/tools/TableNavigationActionRouterBench.tscn")


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
		print("Table navigation action router test passed (%d checks)." % int(result.get("checks", 0)))
		quit(0)
		return
	push_error("Table navigation action router test failed:\n- " + "\n- ".join(result.get("failures", [])))
	quit(1)
