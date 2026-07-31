extends SceneTree

const AUTHORIZATION_CONTRACT := preload("res://scripts/tools/cold_restore_authorization_contract_v1.gd")
const CHILD_ATTESTATION := preload("res://scripts/tools/cold_restore_child_completion_attestation.gd")
const PHASE_TIMELINE := preload("res://scripts/tools/cold_restore_process_a_phase_timeline.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var authorization := AUTHORIZATION_CONTRACT.entry(
		"targeted_owner_capture_diagnostic_v4_importchain"
	)
	var head := "a".repeat(40)
	var run_id := AUTHORIZATION_CONTRACT.run_id(
		"targeted_owner_capture_diagnostic_v4_importchain", head
	)
	var expected_root := AUTHORIZATION_CONTRACT.targeted_evidence_root()
	_expect(not authorization.is_empty(), "targeted authorization contract is readable")
	_expect(
		run_id == "%s-%s" % [str(authorization.get("run_id_prefix", "")), head.left(12)],
		"targeted run ID is derived from the single contract prefix"
	)
	_expect(not expected_root.is_empty(), "targeted evidence root resolves below git common")
	var existed_before := DirAccess.dir_exists_absolute(expected_root)

	OS.unset_environment("SPACE_SYNDICATE_COLD_RESTORE_EVIDENCE_ROOT")
	_expect(
		AUTHORIZATION_CONTRACT.evidence_run_root(run_id).is_empty(),
		"targeted evidence root is unavailable without an exact parent binding"
	)
	OS.set_environment(
		"SPACE_SYNDICATE_COLD_RESTORE_EVIDENCE_ROOT", "%s-wrong" % expected_root
	)
	_expect(
		AUTHORIZATION_CONTRACT.evidence_run_root(run_id).is_empty(),
		"a neighboring evidence root is rejected"
	)
	OS.set_environment("SPACE_SYNDICATE_COLD_RESTORE_EVIDENCE_ROOT", expected_root)
	_expect(
		AUTHORIZATION_CONTRACT.evidence_run_root(run_id) == expected_root,
		"the exact contract evidence root is accepted"
	)
	_expect(
		CHILD_ATTESTATION.completion_path(run_id, "producer") \
				== "%s/child/producer.completion.json" % expected_root,
		"Child Completion uses the contract evidence root"
	)
	_expect(
		PHASE_TIMELINE.stable_path(run_id) \
				== "%s/diagnostics/producer.phase_timeline.json" % expected_root,
		"phase timeline uses the contract evidence root"
	)
	_expect(
		PHASE_TIMELINE.event_root(run_id) \
				== "%s/diagnostics/producer.phase_timeline.events" % expected_root,
		"phase events use the contract evidence root"
	)
	var heartbeat_source := FileAccess.get_file_as_string(
		"res://scripts/tools/cold_restore_role_progress_heartbeat.gd"
	)
	var driver_source := FileAccess.get_file_as_string(
		"res://scripts/tools/cold_restore_vertical_slice_driver.gd"
	)
	_expect(
		heartbeat_source.contains("AUTHORIZATION_CONTRACT.evidence_run_root(_run_id)"),
		"heartbeat uses the shared evidence-root resolver"
	)
	_expect(
		driver_source.contains("SPACE_SYNDICATE_COLD_RESTORE_EVIDENCE_ROOT") \
				and driver_source.contains("_resolve_targeted_diagnostic_evidence_root"),
		"Driver launch binding uses the same exact evidence root"
	)
	_expect(
		DirAccess.dir_exists_absolute(expected_root) == existed_before,
		"path validation creates no production evidence directory"
	)
	OS.unset_environment("SPACE_SYNDICATE_COLD_RESTORE_EVIDENCE_ROOT")

	var passed := _failures.is_empty()
	print("COLD_RESTORE_TARGETED_EVIDENCE_ROOT_CONTRACT|status=%s|checks=%d|failures=%d|writes=0" % [
		"PASS" if passed else "FAIL", _checks, _failures.size(),
	])
	for failure in _failures:
		push_error(failure)
	quit(0 if passed else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
