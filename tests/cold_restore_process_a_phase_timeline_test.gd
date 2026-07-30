extends SceneTree

const TIMELINE := preload("res://scripts/tools/cold_restore_process_a_phase_timeline.gd")
const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var run_id := "process-a-timeline-%d" % Time.get_ticks_msec()
	var repository_head := "d".repeat(40)
	var scenario_fingerprint := "a".repeat(64)
	var timeline := TIMELINE.new()
	var initialized: Dictionary = timeline.initialize(
		run_id,
		repository_head,
		scenario_fingerprint,
		false,
		Time.get_ticks_msec()
	)
	_expect(bool(initialized.get("valid", false)), "timeline initializes with an atomic child_bootstrap snapshot: %s" % JSON.stringify(initialized))
	var first := timeline.snapshot()
	_expect(bool(TIMELINE.validation_report(first, run_id, repository_head).get("valid", false)), "initial snapshot is closed and valid")
	var duplicate: Dictionary = timeline.enter_phase("child_bootstrap")
	_expect(bool(duplicate.get("valid", false)) and str(duplicate.get("reason_code", "")) == "idempotent", "duplicate phase entry is idempotent")
	_expect(int(timeline.snapshot().get("snapshot_sequence", 0)) == int(first.get("snapshot_sequence", -1)), "idempotent entry writes no duplicate snapshot")

	_expect(bool(timeline.complete_phase("child_bootstrap", true, "ok", {"fixture": 1}).get("valid", false)), "first phase completes")
	var second := timeline.snapshot()
	_expect(bool(TIMELINE.transition_report(first, second).get("valid", false)), "valid completion is a monotonic transition")
	_expect(bool(timeline.enter_phase("scene_loaded").get("valid", false)), "second phase enters in order")
	var third := timeline.snapshot()
	_expect(bool(TIMELINE.transition_report(second, third).get("valid", false)), "valid phase advance is monotonic")

	var wrong_run := _reseal(third, {"run_id": "%s-wrong" % run_id})
	_expect(str(TIMELINE.validation_report(wrong_run, run_id, repository_head).get("reason_code", "")) == "phase_timeline_run_id_mismatch", "stale or wrong run ID is rejected")
	var wrong_head := _reseal(third, {"repository_head": "c".repeat(40)})
	_expect(str(TIMELINE.validation_report(wrong_head, run_id, repository_head).get("reason_code", "")) == "phase_timeline_repository_head_mismatch", "wrong repository HEAD is rejected")
	var truncated := third.duplicate(true)
	(truncated.get("phase_rows", []) as Array).remove_at(1)
	truncated["snapshot_sequence"] = int(third.get("snapshot_sequence", 0)) + 1
	truncated["current_phase"] = ""
	truncated["last_completed_phase"] = "child_bootstrap"
	truncated.erase("timeline_fingerprint")
	truncated = SEMANTIC_WIRE.sealed_copy(truncated, "timeline_fingerprint")
	_expect(str(TIMELINE.transition_report(third, truncated).get("reason_code", "")) == "phase_timeline_truncated", "truncated timeline transition is rejected")

	_expect(bool(timeline.complete_phase("scene_loaded").get("valid", false)), "second phase completes")
	var save_path := "user://test_runs/alpha04c/%s/non_official/timeline-fixture.save" % run_id
	for index in range(2, TIMELINE.PHASE_IDS.size()):
		var phase_id := str(TIMELINE.PHASE_IDS[index])
		_expect(bool(timeline.enter_phase(phase_id).get("valid", false)), "%s enters" % phase_id)
		if phase_id == "atomic_write_complete":
			_expect(_write_text(save_path, "timeline fixture save"), "fixture save is writable")
			_expect(bool(timeline.update_save_file(save_path).get("valid", false)), "save bytes and SHA-256 are captured")
		elif phase_id == "allowlisted_manifest_complete":
			_expect(bool(timeline.mark_allowlisted_manifest_written().get("valid", false)), "manifest completion flag is monotonic")
		elif phase_id == "child_completion_attestation_complete":
			_expect(bool(timeline.mark_child_completion_written().get("valid", false)), "child completion flag is monotonic")
		elif phase_id == "quit_requested":
			_expect(bool(timeline.mark_quit_requested().get("valid", false)), "quit request flag is monotonic")
		_expect(bool(timeline.complete_phase(phase_id, true, "ok", {"phase_index": index}).get("valid", false)), "%s completes" % phase_id)

	var final_snapshot := timeline.snapshot()
	var final_validation := TIMELINE.validation_report(final_snapshot, run_id, repository_head)
	_expect(bool(final_validation.get("valid", false)), "complete ProcessAPhaseTimelineV1 validates")
	_expect((final_snapshot.get("phase_rows", []) as Array).size() == 19 and str(final_snapshot.get("last_completed_phase", "")) == "quit_requested", "all nineteen required phases are present")
	_expect(bool(final_snapshot.get("save_file_exists", false)) and int(final_snapshot.get("save_file_bytes", 0)) > 0 and str(final_snapshot.get("save_file_sha256", "")).length() == 64, "final timeline binds the Save file")
	_expect(bool(final_snapshot.get("allowlisted_manifest_written", false)) and bool(final_snapshot.get("child_completion_written", false)) and bool(final_snapshot.get("quit_requested", false)), "finalization flags remain true")
	var event_files := _event_files(run_id)
	_expect(event_files.size() > 19, "timeline updates are emitted as immutable atomic snapshots")
	for event_path in event_files:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(event_path))
		_expect(parsed is Dictionary and bool(TIMELINE.validation_report(parsed, run_id, repository_head).get("valid", false)), "atomic event readback is valid: %s" % event_path.get_file())

	_cleanup(run_id, save_path)
	if _failures.is_empty():
		print("PROCESS A PHASE TIMELINE PASS %d checks" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error("PROCESS A PHASE TIMELINE FAILURE: %s" % failure)
		quit(1)


func _reseal(source: Dictionary, changes: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	result.merge(changes, true)
	result.erase("timeline_fingerprint")
	return SEMANTIC_WIRE.sealed_copy(result, "timeline_fingerprint")


func _write_text(path: String, content: String) -> bool:
	var absolute_path := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir()) != OK:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.flush()
	file.close()
	return true


func _event_files(run_id: String) -> Array[String]:
	var result: Array[String] = []
	var absolute_root := ProjectSettings.globalize_path(TIMELINE.event_root(run_id))
	var directory := DirAccess.open(absolute_root)
	if directory == null:
		return result
	for file_name in directory.get_files():
		if str(file_name).ends_with(".snapshot.json"):
			result.append(absolute_root.path_join(str(file_name)))
	result.sort()
	return result


func _cleanup(run_id: String, save_path: String) -> void:
	var absolute_save := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(absolute_save):
		DirAccess.remove_absolute(absolute_save)
	_remove_tree(ProjectSettings.globalize_path("res://.godot/cold_restore_attestation_v1/%s" % run_id))


func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file_name in directory.get_files():
		DirAccess.remove_absolute(path.path_join(str(file_name)))
	for directory_name in directory.get_directories():
		var child := path.path_join(str(directory_name))
		_remove_tree(child)
		DirAccess.remove_absolute(child)
	DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
