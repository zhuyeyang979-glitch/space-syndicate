extends SceneTree

const BENCH_SCENE := preload("res://scenes/tools/DeveloperBalanceApplicationHostBench.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bench := BENCH_SCENE.instantiate()
	bench.auto_run = false
	root.add_child(bench)
	var result: Dictionary = bench.run_bench()
	var failures: Array = result.get("failures", []) if result.get("failures", []) is Array else []
	var request_text := FileAccess.get_file_as_string("res://docs/integration_requests/P3-DEVELOPER-DIAGNOSTICS-HOST-CUTOVER.json")
	var request: Variant = JSON.parse_string(request_text)
	if not (request is Dictionary):
		failures.append("integration request is valid JSON")
	else:
		var request_data := request as Dictionary
		if str(request_data.get("status", "")) != "FUNCTIONAL_CORE_READY":
			failures.append("integration request records functional core readiness")
		var hot_files: Array = request_data.get("hot_file_changes", []) if request_data.get("hot_file_changes", []) is Array else []
		var hot_json := JSON.stringify(hot_files)
		for required_path in ["scripts/main.gd", "scenes/main.tscn", "docs/migration/main_gd_cutover_ledger.json"]:
			if not hot_json.contains(required_path):
				failures.append("integration request names hot file: %s" % required_path)
	var host_source := FileAccess.get_file_as_string("res://scripts/presentation/developer_balance_application_host.gd")
	for forbidden in ["scripts/" + "main.gd", "/root/" + "Main", "get_tree().current_scene", "build_developer_panel_snapshot", "set_diagnostics_service"]:
		if host_source.contains(forbidden):
			failures.append("Host source excludes forbidden dependency: %s" % forbidden)
	bench.queue_free()
	await process_frame
	var checks := int(result.get("checks", 0)) + 8
	if failures.is_empty():
		print("Developer balance application-host cutover test passed (%d checks)." % checks)
		quit(0)
		return
	push_error("Developer balance application-host cutover test failed:\n- " + "\n- ".join(failures))
	quit(1)
