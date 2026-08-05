extends SceneTree

const SAMPLE_COUNT := 2000


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := V074MapGenesisAudit.run_sample_suite(SAMPLE_COUNT)
	var passed := (
		bool(result.get("success", false))
		and int(result.get("map_generation_sample_count", 0))
		== SAMPLE_COUNT
	)
	print(
		"V074_MAP_GENESIS_2000_SAMPLE_TEST|status=%s|result=%s"
		% [
			"PASS" if passed else "FAIL",
			JSON.stringify(result),
		]
	)
	quit(0 if passed else 1)
