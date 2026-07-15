extends SceneTree

const BENCH_SCENE := preload("res://scenes/tools/MonsterCodexPublicSnapshotCutoverBench.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bench := BENCH_SCENE.instantiate()
	bench.set("auto_run", false)
	bench.set("quit_on_complete", false)
	root.add_child(bench)
	await process_frame
	await bench.call("run_cutover_suite")
	var result: Dictionary = bench.call("build_cutover_manifest_preview") as Dictionary
	var manifest_path := "user://space_syndicate_design_qa/monster_codex_public_snapshot_cutover/manifest.json"
	var manifest_text := FileAccess.get_file_as_string(manifest_path)
	var parsed: Dictionary = JSON.parse_string(manifest_text) as Dictionary if manifest_text != "" else {}
	var passed := int(parsed.get("passed_count", -1)) == int(parsed.get("record_count", 0)) and int(parsed.get("record_count", 0)) >= int(result.get("record_count", 0))
	print("MONSTER CODEX PUBLIC SOURCE %s (%d checks)" % ["PASS" if passed else "FAIL", int(parsed.get("record_count", 0))])
	if not passed:
		push_error("Monster Codex public source cutover failed: %s" % manifest_text)
	bench.queue_free()
	await process_frame
	quit(0 if passed else 1)
