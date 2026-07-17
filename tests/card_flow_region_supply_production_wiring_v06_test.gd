extends SceneTree

const BENCH_SCENE := preload(
	"res://scenes/tools/CardFlowRegionSupplyProductionWiringV06Bench.tscn"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bench := BENCH_SCENE.instantiate()
	bench.set("auto_run", false)
	bench.set("quit_on_finish", false)
	root.add_child(bench)
	await process_frame
	var result_variant: Variant = await bench.call("run_checks")
	var result: Dictionary = (
		(result_variant as Dictionary).duplicate(true)
		if result_variant is Dictionary
		else {
			"passed": false,
			"checks": 0,
			"failures": ["bench_result_invalid"],
		}
	)
	if bool(result.get("passed", false)):
		print("CARD_FLOW_REGION_SUPPLY_PRODUCTION_WIRING_V06_TEST|status=PASS|checks=%d|failures=0" % int(result.get("checks", 0)))
		quit(0)
		return
	push_error("CARD_FLOW_REGION_SUPPLY_PRODUCTION_WIRING_V06_TEST_FAIL|%s" % JSON.stringify(result))
	print("CARD_FLOW_REGION_SUPPLY_PRODUCTION_WIRING_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [
		int(result.get("checks", 0)),
		(result.get("failures", []) as Array).size(),
		JSON.stringify(result.get("failures", [])),
	])
	quit(1)
