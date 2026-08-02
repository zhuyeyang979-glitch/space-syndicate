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
var _capture_operation_delta := -1
var _captured_section_count := -1
var _preflight_count := -1
var _tagged_int64_count := -1
var _world_time_delta_us := -1
var _rng_draw_delta := -1
var _public_log_entry_delta := -1
var _public_log_revision_delta := -1
var _remaining_artifact_count := -1


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

	var registry_before_capture: Dictionary = registry.debug_snapshot()
	var capture_operation_before := int(registry_before_capture.get("operation_sequence", -1))
	var safety_before_save_chain: Dictionary = coordinator.save_restore_safety_observation()
	var capture: Dictionary = registry.capture_resume_envelope({
		"envelope_id": "alpha04c-production-capture-readback-envelope",
		"write_id": "alpha04c-production-capture-readback-write",
	})
	var registry_after_capture: Dictionary = registry.debug_snapshot()
	var capture_operation_after := int(registry_after_capture.get("operation_sequence", -1))
	_capture_operation_delta = capture_operation_after - capture_operation_before
	_captured_section_count = int(registry_after_capture.get("last_capture_section_count", -1))
	var envelope: Dictionary = capture.get("envelope", {}) if capture.get("envelope", {}) is Dictionary else {}
	if not bool(capture.get("ok", false)):
		_capture_failure_section = str(capture.get(
			"failing_section_id",
			registry_after_capture.get("last_internal_capture_failure_section", "")
		))
		_capture_failure_reason = str(capture.get(
			"internal_reason_code",
			registry_after_capture.get("last_internal_capture_failure_reason", "")
		))
	_expect(
		bool(capture.get("ok", false)) and not envelope.is_empty(),
		"production Registry captures the live session|section=%s|reason=%s"
			% [_capture_failure_section, _capture_failure_reason]
	)
	_expect(
		_capture_operation_delta == 1
				and int(capture.get("operation_sequence", -1)) == capture_operation_after
				and int(registry_after_capture.get("last_capture_operation_sequence", -1)) == capture_operation_after
				and str(registry_after_capture.get("last_capture_write_id", ""))
						== "alpha04c-production-capture-readback-write",
		"production Save performs exactly one new Registry capture operation with the requested write identity"
	)
	if envelope.is_empty():
		await _release_main(main)
		_cleanup_test_artifacts()
		_finish()
		return

	var sections: Dictionary = envelope.get("sections", {}) if envelope.get("sections", {}) is Dictionary else {}
	_expect(
		_captured_section_count == EXPECTED_SECTION_COUNT
				and sections.size() == EXPECTED_SECTION_COUNT
				and _has_exact_manifest_sections(sections, manifest),
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
	_preflight_count = int(preflight.get("preflight_count", -1))
	_expect(
		bool(preflight.get("ok", false))
				and bool(preflight.get("preflight_complete", false))
				and _preflight_count == EXPECTED_SECTION_COUNT,
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
		str(registry_after_capture.get("last_capture_envelope_fingerprint", ""))
				== str(readback.get("fingerprint", ""))
				and str(registry_after_capture.get("last_capture_sections_fingerprint", ""))
						== readback_sections_fingerprint,
		"Registry capture envelope and section fingerprints bind exactly to disk readback"
	)

	var captured_int64_audit := _tagged_int64_audit(sections, handshake)
	var readback_int64_audit := _tagged_int64_audit(readback_sections, handshake)
	var captured_int64_entries: Dictionary = captured_int64_audit.get("entries", {}) \
			if captured_int64_audit.get("entries", {}) is Dictionary else {}
	var readback_int64_entries: Dictionary = readback_int64_audit.get("entries", {}) \
			if readback_int64_audit.get("entries", {}) is Dictionary else {}
	_tagged_int64_count = captured_int64_entries.size()
	_expect(
		bool(captured_int64_audit.get("valid", false))
				and bool(readback_int64_audit.get("valid", false))
				and _tagged_int64_count > 0
				and captured_int64_entries == readback_int64_entries,
		"every captured tagged Int64 remains structurally valid and exact after disk readback"
	)

	var safety_after_save_chain: Dictionary = coordinator.save_restore_safety_observation()
	var clock_after_save_chain: Dictionary = coordinator.world_effective_clock_snapshot()
	_world_time_delta_us = int(clock_after_save_chain.get("world_effective_us", -1)) \
			- int(clock_after_advance.get("world_effective_us", -1))
	_rng_draw_delta = int(safety_after_save_chain.get("rng_draw_invocation_count", -1)) \
			- int(safety_before_save_chain.get("rng_draw_invocation_count", -1))
	_public_log_entry_delta = int(safety_after_save_chain.get("public_log_entry_count", -1)) \
			- int(safety_before_save_chain.get("public_log_entry_count", -1))
	_public_log_revision_delta = int(safety_after_save_chain.get("public_log_revision", -1)) \
			- int(safety_before_save_chain.get("public_log_revision", -1))
	_expect(
		_world_time_delta_us == 0
				and int(safety_after_save_chain.get("world_clock_advance_count", -1))
						== int(safety_before_save_chain.get("world_clock_advance_count", -2))
				and clock_after_save_chain == clock_after_advance,
		"capture, write, readback, and Registry preflight have zero world-time delta"
	)
	_expect(
		_rng_draw_delta == 0,
		"capture, write, readback, and Registry preflight have zero RNG-draw delta"
	)
	_expect(
		_public_log_entry_delta == 0 and _public_log_revision_delta == 0,
		"capture, write, readback, and Registry preflight have zero public-log delta"
	)

	await _release_main(main)
	_remaining_artifact_count = _cleanup_test_artifacts()
	_expect(
		not is_instance_valid(main)
				and _remaining_artifact_count == 0
				and not FileAccess.file_exists(QA_SAVE_PATH)
				and _atomic_fragment_count() == 0,
		"production main and task-owned Save, temp, swap, and backup artifacts are removed after verification"
	)
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


func _tagged_int64_audit(value: Variant, handshake: Node) -> Dictionary:
	var entries: Dictionary = {}
	return {
		"valid": _collect_tagged_int64_entries(value, "$", handshake, entries),
		"entries": entries,
	}


func _collect_tagged_int64_entries(
	value: Variant,
	path: String,
	handshake: Node,
	entries: Dictionary
) -> bool:
	if value is Array:
		var values := value as Array
		for index in range(values.size()):
			if not _collect_tagged_int64_entries(values[index], "%s/%d" % [path, index], handshake, entries):
				return false
		return true
	if not (value is Dictionary):
		return true
	var dictionary := value as Dictionary
	if dictionary.has("$codec"):
		if str(dictionary.get("$codec", "")) != "Int64":
			return true
		var encoded_value: Variant = dictionary.get("value")
		if dictionary.size() != 2 or not (encoded_value is String) \
				or not str(encoded_value).is_valid_int():
			return false
		var decoded_variant: Variant = handshake.call("decode_codec_value", dictionary)
		if not (decoded_variant is Dictionary):
			return false
		var decoded := decoded_variant as Dictionary
		if not bool(decoded.get("ok", false)) or not (decoded.get("value") is int):
			return false
		var reencoded_variant: Variant = handshake.call("encode_codec_value", decoded.get("value"))
		if not (reencoded_variant is Dictionary):
			return false
		var reencoded := reencoded_variant as Dictionary
		if not bool(reencoded.get("ok", false)) \
				or str(handshake.call("canonical_json", reencoded.get("value"))) \
						!= str(handshake.call("canonical_json", dictionary)):
			return false
		entries[path] = str(encoded_value)
		return true
	for key_variant in dictionary.keys():
		var key := str(key_variant)
		if not _collect_tagged_int64_entries(dictionary[key_variant], "%s/%s" % [path, key], handshake, entries):
			return false
	return true


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
	print("ALPHA04C_PRODUCTION_SAVE_CAPTURE_READBACK_TEST|status=%s|checks=%d|failures=%d|capture_operation_delta=%d|captured_sections=%d|strict_preflights=%d|tagged_int64_count=%d|world_time_delta_us=%d|rng_draw_delta=%d|public_log_entry_delta=%d|public_log_revision_delta=%d|remaining_artifacts=%d|capture_failure_section=%s|capture_failure_reason=%s" % [
		status,
		_checks,
		_failures.size(),
		_capture_operation_delta,
		_captured_section_count,
		_preflight_count,
		_tagged_int64_count,
		_world_time_delta_us,
		_rng_draw_delta,
		_public_log_entry_delta,
		_public_log_revision_delta,
		_remaining_artifact_count,
		_capture_failure_section,
		_capture_failure_reason,
	])
	quit(0 if _failures.is_empty() else 1)
