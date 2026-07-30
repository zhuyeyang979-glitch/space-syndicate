extends SceneTree

const SESSION_START_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const QA_SAVE_PATH := "user://test_runs/alpha04c_production_save_capture_readback/production_capture.save"
const REQUEST_ID := "alpha04c-production-save-capture-readback"
const EXPECTED_SECTION_COUNT := 19
const NONTRIVIAL_WORLD_DELTA_SECONDS := 0.25
const NONTRIVIAL_WORLD_DELTA_US := 250_000

var _checks := 0
var _failures: Array[String] = []
var _capture_failure_section := ""
var _capture_failure_reason := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_test_artifacts()
	var start_result: Dictionary = await SESSION_START_DRIVER.start_default_session(
		self,
		QA_SAVE_PATH,
		REQUEST_ID
	)
	var main := start_result.get("main_root") as Node
	var coordinator := start_result.get("coordinator") as GameRuntimeCoordinator
	var session := start_result.get("game_session") as GameSessionRuntimeController
	var save := start_result.get("save_coordinator") as GameSaveRuntimeCoordinator

	_expect(
		bool(start_result.get("started", false)),
		"real main session starts through the production setup transaction|reason=%s"
			% str(start_result.get("reason_code", ""))
	)
	_expect(
		bool(start_result.get("qa_save_override_ready", false)),
		"production Save coordinator accepts the isolated QA save path before tree entry"
	)
	_expect(main != null and coordinator != null and session != null and save != null, "real main composes GameRuntimeCoordinator, GameSession, and GameSave")
	if main == null or coordinator == null or session == null or save == null \
			or not bool(start_result.get("started", false)):
		await _release_main(main)
		_cleanup_test_artifacts()
		_finish()
		return

	main.process_mode = Node.PROCESS_MODE_DISABLED
	var registry := session.get_node_or_null("V06SaveOwnerRegistry") as V06SaveOwnerRegistry
	var handshake := save.get_node_or_null("RulesetSaveHandshakeService")
	_expect(registry != null and handshake != null, "production GameSession composes one Registry and one v3 handshake")
	if registry == null or handshake == null:
		await _release_main(main)
		_cleanup_test_artifacts()
		_finish()
		return

	var registry_snapshot: Dictionary = registry.registry_snapshot()
	var manifest: Dictionary = handshake.call("required_section_manifest")
	var fixed_order: Array = registry.fixed_section_order()
	_expect(
		bool(registry_snapshot.get("valid", false))
				and bool(registry_snapshot.get("resume_ready", false))
				and int(registry_snapshot.get("transactional_section_count", 0)) == EXPECTED_SECTION_COUNT
				and int(registry_snapshot.get("unsupported_section_count", -1)) == 0,
		"production Registry is resume-ready with 19 transactional Owners"
	)
	_expect(
		manifest.size() == EXPECTED_SECTION_COUNT and fixed_order.size() == EXPECTED_SECTION_COUNT,
		"handshake manifest and Registry capture order both contain exactly 19 sections"
	)

	var clock_before: Dictionary = coordinator.world_effective_clock_snapshot()
	var advanced: Dictionary = coordinator.advance_runtime_world_time(NONTRIVIAL_WORLD_DELTA_SECONDS)
	var clock_after_advance: Dictionary = coordinator.world_effective_clock_snapshot()
	_expect(
		int(advanced.get("world_effective_us", -1))
				== int(clock_before.get("world_effective_us", -1)) + NONTRIVIAL_WORLD_DELTA_US
				and clock_after_advance == advanced,
		"production lifecycle port creates a deterministic non-default world state before capture"
	)

	var capture: Dictionary = registry.capture_resume_envelope({
		"envelope_id": "alpha04c-production-capture-readback-envelope",
		"write_id": "alpha04c-production-capture-readback-write",
	})
	var envelope: Dictionary = capture.get("envelope", {}) if capture.get("envelope", {}) is Dictionary else {}
	if not bool(capture.get("ok", false)):
		var capture_debug: Dictionary = registry.debug_snapshot()
		_capture_failure_section = str(capture.get(
			"failing_section_id",
			capture_debug.get("last_internal_capture_failure_section", "")
		))
		_capture_failure_reason = str(capture.get(
			"internal_reason_code",
			capture_debug.get("last_internal_capture_failure_reason", "")
		))
	_expect(
		bool(capture.get("ok", false)) and not envelope.is_empty(),
		"production Registry captures the live session|section=%s|reason=%s"
			% [_capture_failure_section, _capture_failure_reason]
	)
	if envelope.is_empty():
		await _release_main(main)
		_cleanup_test_artifacts()
		_finish()
		return

	var sections: Dictionary = envelope.get("sections", {}) if envelope.get("sections", {}) is Dictionary else {}
	_expect(
		sections.size() == EXPECTED_SECTION_COUNT and _has_exact_manifest_sections(sections, manifest),
		"captured v3 envelope contains every required Owner section exactly once"
	)
	_expect(
		int(envelope.get("save_version", 0)) == 3 and str(envelope.get("ruleset_id", "")) == "v0.6",
		"captured envelope retains the production v3/v0.6 identity"
	)

	var validation: Dictionary = save.validate_envelope(envelope)
	var expected_fingerprint := str(validation.get("fingerprint", ""))
	_expect(
		bool(validation.get("valid", false)) and expected_fingerprint.length() == 64,
		"GameSave validates the captured 19-Owner envelope and produces a SHA-256 fingerprint"
	)
	var private_cursor_probe := 900626424
	var scalar_diagnostic := str(save.call("_safe_scalar_diagnostic", private_cursor_probe))
	var mismatch_diagnostic: Dictionary = save.call(
		"_first_canonical_mismatch",
		{"next_quote_sequence": private_cursor_probe},
		{"next_quote_sequence": private_cursor_probe + 1},
		handshake
	)
	var mismatch_serialized := JSON.stringify(mismatch_diagnostic)
	_expect(
		scalar_diagnostic.begins_with("int:")
				and not scalar_diagnostic.contains(str(private_cursor_probe))
				and not mismatch_serialized.contains(str(private_cursor_probe))
				and not mismatch_serialized.contains(str(private_cursor_probe + 1)),
		"readback diagnostics fingerprint numeric allocator values instead of exposing raw scalars"
	)

	var authorization: Dictionary = save.write_authorization(QA_SAVE_PATH, envelope)
	_expect(bool(authorization.get("allowed", false)), "production handshake authorizes the isolated QA write")
	var write_result: Dictionary = session.request_save(QA_SAVE_PATH, envelope, authorization)
	var session_after_write := session.operation_lifecycle_snapshot()
	_expect(
		bool(write_result.get("ok", false))
				and str(write_result.get("reason_code", "")) == "written"
				and str(write_result.get("fingerprint", "")) == expected_fingerprint
				and (session_after_write.get("active", {}) as Dictionary).is_empty()
				and str((session_after_write.get("last", {}) as Dictionary).get("kind", "")) == "write",
		"GameSession completes one atomic QA write and closes its operation lifecycle"
	)
	_expect(
		FileAccess.file_exists(QA_SAVE_PATH)
				and FileAccess.get_file_as_bytes(QA_SAVE_PATH).size() > 0
				and _atomic_fragment_count() == 0,
		"atomic write leaves one nonempty destination and no temp or swap fragments"
	)

	var readback: Dictionary = save.read_and_validate(QA_SAVE_PATH)
	var readback_envelope: Dictionary = readback.get("envelope", {}) \
			if readback.get("envelope", {}) is Dictionary else {}
	_expect(
		bool(readback.get("ok", false))
				and str(readback.get("reason_code", "")) == "read_validated"
				and str(readback.get("fingerprint", "")) == expected_fingerprint
				and not readback_envelope.is_empty(),
		"GameSave reads back and validates the atomically installed v3 document"
	)

	var preflight: Dictionary = registry.preflight_envelope(readback_envelope)
	var preflight_debug: Dictionary = registry.debug_snapshot()
	_expect(
		bool(preflight.get("ok", false))
				and bool(preflight.get("preflight_complete", false))
				and int(preflight.get("preflight_count", 0)) == EXPECTED_SECTION_COUNT,
		"Registry strictly preflights all 19 readback sections|section=%s|reason=%s"
			% [
				str(preflight_debug.get("last_internal_preflight_failure_section", "")),
				str(preflight_debug.get("last_internal_preflight_failure_reason", "")),
			]
	)

	var captured_sections_fingerprint := str(handshake.call("canonical_json", sections)).sha256_text()
	var readback_sections: Dictionary = readback_envelope.get("sections", {}) \
			if readback_envelope.get("sections", {}) is Dictionary else {}
	var readback_sections_fingerprint := str(handshake.call("canonical_json", readback_sections)).sha256_text()
	_expect(
		expected_fingerprint == str(capture.get("fingerprint", ""))
				and expected_fingerprint == str(write_result.get("fingerprint", ""))
				and expected_fingerprint == str(readback.get("fingerprint", ""))
				and captured_sections_fingerprint == readback_sections_fingerprint,
		"capture, validation, atomic write, readback, and section fingerprints remain exact"
	)
	_expect(
		coordinator.world_effective_clock_snapshot() == clock_after_advance,
		"capture, write, readback, and Registry preflight do not advance world time"
	)

	await _release_main(main)
	var remaining_artifacts := _cleanup_test_artifacts()
	_expect(remaining_artifacts == 0 and not FileAccess.file_exists(QA_SAVE_PATH) \
			and _atomic_fragment_count() == 0, "task-owned Save, temp, swap, and backup artifacts are removed after verification")
	_finish()


func _has_exact_manifest_sections(sections: Dictionary, manifest: Dictionary) -> bool:
	if sections.size() != manifest.size():
		return false
	for section_variant in manifest.keys():
		if not sections.has(str(section_variant)):
			return false
	return true


func _atomic_fragment_count() -> int:
	var directory := DirAccess.open(QA_SAVE_PATH.get_base_dir())
	if directory == null:
		return 0
	var file_name := QA_SAVE_PATH.get_file()
	var count := 0
	for candidate_variant in directory.get_files():
		var candidate := str(candidate_variant)
		if candidate.begins_with(file_name + ".tmp-") or candidate.begins_with(file_name + ".swap-"):
			count += 1
	return count


func _cleanup_test_artifacts() -> int:
	var directory_path := QA_SAVE_PATH.get_base_dir()
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return 0
	var file_name := QA_SAVE_PATH.get_file()
	for candidate_variant in directory.get_files():
		var candidate := str(candidate_variant)
		if candidate == file_name \
				or candidate.begins_with(file_name + ".tmp-") \
				or candidate.begins_with(file_name + ".swap-") \
				or candidate.begins_with(file_name + ".backup-"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(directory_path.path_join(candidate)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory_path))
	directory = DirAccess.open(directory_path)
	if directory == null:
		return 0
	var remaining := 0
	for candidate_variant in directory.get_files():
		var candidate := str(candidate_variant)
		if candidate == file_name \
				or candidate.begins_with(file_name + ".tmp-") \
				or candidate.begins_with(file_name + ".swap-") \
				or candidate.begins_with(file_name + ".backup-"):
			remaining += 1
	return remaining


func _release_main(main: Node) -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
		for _frame in range(3):
			await process_frame


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("ALPHA04C PRODUCTION SAVE CAPTURE READBACK: %s" % label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("ALPHA04C_PRODUCTION_SAVE_CAPTURE_READBACK_TEST|status=%s|checks=%d|failures=%d|capture_failure_section=%s|capture_failure_reason=%s" % [
		status,
		_checks,
		_failures.size(),
		_capture_failure_section,
		_capture_failure_reason,
	])
	quit(0 if _failures.is_empty() else 1)
