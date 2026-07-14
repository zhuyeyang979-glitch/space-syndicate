extends SceneTree

const BENCH_SCENE := preload("res://scenes/tools/DistrictPurchaseRuntimeCutoverBench.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bench := BENCH_SCENE.instantiate()
	bench.set("auto_run", false)
	root.add_child(bench)
	await process_frame
	var result: Dictionary = await bench.call("run_suite")
	print("CARD_MARKET_POLICY_RUNTIME_TEST|%s" % JSON.stringify(result))
	bench.queue_free()
	await process_frame
	quit(0 if str(result.get("status", "FAIL")) == "PASS" else 1)
