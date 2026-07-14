extends SceneTree

const BENCH_SCENE_PATH := "res://scenes/tools/TomorrowPlayableVerticalSliceBench.tscn"
const EXPECTED_RECORD_IDS := [
	"main_menu_new_run_setup",
	"new_match_one_human_two_ai",
	"human_authoritative_first_summon",
	"public_facility_core_dispatch_exact_once",
	"commodity_flow_realtime_income",
	"ai_progress_without_deadlock",
	"victory_qualification_audit_outcome",
	"settlement_recap_visible",
	"player_facing_privacy",
	"qa_save_isolation",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(BENCH_SCENE_PATH) as PackedScene
	_expect(packed != null, "vertical-slice Bench scene parses")
	if packed == null:
		_finish()
		return
	var bench := packed.instantiate() as TomorrowPlayableVerticalSliceBench
	_expect(bench != null, "vertical-slice Bench instantiates")
	if bench == null:
		_finish()
		return
	bench.auto_run_on_ready = false
	bench.write_evidence = false
	bench.quit_when_complete = false
	var user_args := OS.get_cmdline_user_args()
	if user_args.has("--parse-only"):
		bench.free()
		_finish()
		return
	if user_args.has("--stage3-oracle-self-check"):
		var oracle := bench.stage3_oracle_self_check()
		_expect(bool(oracle.get("passed", false)), "stage 3 oracle accepts authoritative finalized/no-inflight evidence, rejects weakened owner lifecycle evidence, and does not gate ordinary setup_start on campaign signals")
		_expect(int(oracle.get("checks", 0)) == 10 and int(oracle.get("scenario_variants_accepted", 0)) == 2 and int(oracle.get("rejected_mutations", 0)) == 8, "stage 3 oracle self-check executes both scenario-independent controls and all eight lifecycle mutations")
		bench.free()
		_finish()
		return
	if user_args.has("--stage4-oracle-self-check"):
		var oracle := bench.stage4_oracle_self_check()
		_expect(bool(oracle.get("passed", false)), "stage 4 oracle accepts the complete v0.6 lifecycle and rejects weakened cash, asset, revision, finalize, facility, and replay evidence")
		_expect(int(oracle.get("checks", 0)) == 9 and int(oracle.get("rejected_mutations", 0)) == 8, "stage 4 oracle self-check executes all nine contract probes")
		bench.free()
		_finish()
		return
	root.add_child(bench)
	var manifest := await bench.run_acceptance()
	_expect(str(manifest.get("suite", "")) == "tomorrow-playable-vertical-slice-vs06-c", "suite identity is stable")
	var records: Array = manifest.get("records", []) if manifest.get("records", []) is Array else []
	_expect(records.size() == EXPECTED_RECORD_IDS.size(), "all ten production-facing stages emit evidence")
	for record_index in range(EXPECTED_RECORD_IDS.size()):
		var record: Dictionary = records[record_index] if record_index < records.size() and records[record_index] is Dictionary else {}
		_expect(str(record.get("step_id", "")) == EXPECTED_RECORD_IDS[record_index], "stage %s is present in order" % EXPECTED_RECORD_IDS[record_index])
		_expect(bool(record.get("passed", false)), "stage %s passes from real before/after evidence" % EXPECTED_RECORD_IDS[record_index])
	_expect(bool(manifest.get("passed", false)), "all production-facing vertical-slice gates pass")
	_expect(int(manifest.get("privacy_leak_count", -1)) == 0, "public UI and snapshots leak zero private values")
	_expect(str(manifest.get("qa_save_path", "")).begins_with("user://test_runs/"), "run save is isolated below the v0.6 QA test root")
	root.remove_child(bench)
	bench.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("TOMORROW_VERTICAL_SLICE_TEST|status=%s|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(_failures.size())
