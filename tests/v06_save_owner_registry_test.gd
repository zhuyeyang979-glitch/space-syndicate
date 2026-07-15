extends SceneTree

const BenchScript := preload("res://scripts/tools/v06_save_owner_registry_bench.gd")
const BENCH_SCENE_PATH := "res://scenes/tools/V06SaveOwnerRegistryBench.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(BENCH_SCENE_PATH) as PackedScene
	_expect(packed != null, "save owner registry Bench scene loads")
	if packed == null:
		_finish()
		return
	var bench := packed.instantiate()
	_expect(bench != null, "save owner registry Bench instantiates")
	if bench == null:
		_finish()
		return
	bench.auto_run_on_ready = false
	root.add_child(bench)
	await process_frame
	var result: Dictionary = bench.run_bench()
	_expect(bool(result.get("passed", false)), "save owner registry transaction and privacy checks pass: %s" % JSON.stringify(result.get("failures", [])))
	_expect(int(result.get("checks", 0)) >= 20, "save owner registry Bench executes the complete contract matrix")
	var evidence: Dictionary = result.get("evidence", {}) if result.get("evidence", {}) is Dictionary else {}
	_expect(int(evidence.get("production_required_sections", 0)) == 18 and int(evidence.get("production_transactional_sections", 0)) == 8 and int(evidence.get("production_unsupported_sections", 0)) == 10, "production registry exposes the audited 8/10 capability boundary")
	_expect(bool(evidence.get("bankruptcy_section_registered", false)) and bool(evidence.get("bankruptcy_section_transactional", false)) and str(evidence.get("bankruptcy_unsupported_reason", "")) == "", "bankruptcy neutral estate is bound to its unique transactional owner")
	_expect(bool(evidence.get("weather_section_transactional", false)) and str(evidence.get("weather_unsupported_reason", "")) == "", "weather is bound to its unique transactional owner")
	_expect(not bool(evidence.get("production_resume_ready", true)) and not bool(evidence.get("full_production_restore_claimed", true)), "production resume stays fail-closed and makes no full-restore claim")
	_expect(bool(evidence.get("global_preflight", false)) and bool(evidence.get("rollback_complete", false)) and bool(evidence.get("public_receipt_private", false)), "global preflight, rollback, and public receipt privacy are proven")
	bench.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("V06_SAVE_OWNER_REGISTRY_TEST|status=%s|checks=8|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(0 if _failures.is_empty() else 1)
