extends SceneTree

const SESSION_SCENE_PATH := "res://scenes/runtime/GameSessionRuntimeController.tscn"
const QA_ROOT := "user://test_runs/alpha04c_save_file_fault_matrix/"
const STALE_SWAP_PATH := QA_ROOT + "stale_swap.save"
const BACKUP_FAILURE_PATH := QA_ROOT + "backup_failure.save"
const DIRECTORY_FAILURE_PATH := QA_ROOT + "missing/nested/directory_failure.save"

var _session: Node
var _save: Node
var _handshake: Node
var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_fixture_files()
	var packed := load(SESSION_SCENE_PATH) as PackedScene
	_expect(packed != null, "GameSession runtime scene loads")
	if packed == null:
		_finish()
		return
	_session = packed.instantiate()
	root.add_child(_session)
	_save = _session.get_node_or_null("GameSaveRuntimeCoordinator")
	_handshake = _save.get_node_or_null("RulesetSaveHandshakeService") if _save != null else null
	_expect(_save != null and _handshake != null, "save coordinator and strict handshake are composed")
	if _save == null or _handshake == null:
		_cleanup_fixture_files()
		_finish()
		return
	_session.call("configure", {"ruleset_id": "v0.6"})
	_test_stale_swap_fails_closed()
	_test_backup_failure_preserves_legacy_source()
	_test_directory_failure_has_zero_filesystem_effect()
	_cleanup_fixture_files()
	_finish()


func _test_stale_swap_fails_closed() -> void:
	var base := _fixture_envelope("fault-stale-base", "fault-stale-base-write", "stale-base")
	var base_write := _authorized_write(STALE_SWAP_PATH, base)
	var base_read: Dictionary = _save.call("read_and_validate", STALE_SWAP_PATH)
	var base_bytes := FileAccess.get_file_as_bytes(STALE_SWAP_PATH)
	_expect(bool(base_write.get("ok", false)) and bool(base_read.get("ok", false)), "stale-swap fixture starts from one valid committed destination")

	var replacement := _fixture_envelope("fault-stale-next", "fault-stale-next-write", "stale-next")
	var authorization: Dictionary = _save.call("write_authorization", STALE_SWAP_PATH, replacement, {"allow_replace": true})
	var swap_path := "%s.swap-%s" % [STALE_SWAP_PATH, str(replacement.get("write_id", ""))]
	var swap_sentinel := "STALE_SWAP_RECOVERY_SENTINEL"
	_expect(bool(authorization.get("allowed", false)) and _write_text(swap_path, swap_sentinel), "stale-swap fixture has valid replacement authority plus one parked swap")

	var failure: Dictionary = _save.call("write_validated_envelope", STALE_SWAP_PATH, replacement, authorization)
	var after: Dictionary = _save.call("read_and_validate", STALE_SWAP_PATH)
	_expect(
		not bool(failure.get("ok", true))
			and str(failure.get("reason_code", "")) == "stale_atomic_swap_present"
			and int(failure.get("error_code", OK)) == ERR_ALREADY_EXISTS,
		"stale swap rejects before a new atomic replace"
	)
	_expect(
		FileAccess.get_file_as_bytes(STALE_SWAP_PATH) == base_bytes
			and bool(after.get("ok", false))
			and str(after.get("fingerprint", "")) == str(base_read.get("fingerprint", "")),
		"stale swap preserves the previously committed destination byte-for-byte"
	)
	_expect(
		FileAccess.get_file_as_string(swap_path) == swap_sentinel
			and not FileAccess.file_exists("%s.tmp-%s" % [STALE_SWAP_PATH, str(replacement.get("write_id", ""))]),
		"stale swap remains available for recovery inspection and no temp file survives"
	)


func _test_backup_failure_preserves_legacy_source() -> void:
	var legacy_text := JSON.stringify({
		"save_version": 2,
		"ruleset_id": "v0.5",
		"session": {"fixture": "legacy-source"},
		"domains": {},
	})
	_expect(_write_text(BACKUP_FAILURE_PATH, legacy_text), "backup-failure fixture writes one legacy source")
	var source_bytes := FileAccess.get_file_as_bytes(BACKUP_FAILURE_PATH)
	var replacement := _fixture_envelope("fault-backup-next", "fault-backup-next-write", "backup-next")
	var authorization: Dictionary = _save.call("write_authorization", BACKUP_FAILURE_PATH, replacement, {
		"allow_replace": true,
		"allow_backup": true,
		"qa_failure_stage": "backup_failure",
	})
	_expect(
		bool(authorization.get("allowed", false))
			and bool(authorization.get("requires_backup", false))
			and str(authorization.get("qa_failure_stage", "")) == "backup_failure",
		"backup failure is injected only after explicit legacy-backup authorization"
	)

	var failure: Dictionary = _save.call("write_validated_envelope", BACKUP_FAILURE_PATH, replacement, authorization)
	var after: Dictionary = _save.call("read_and_validate", BACKUP_FAILURE_PATH)
	_expect(
		not bool(failure.get("ok", true))
			and str(failure.get("reason_code", "")) == "qa_injected_backup_failure"
			and int(failure.get("error_code", OK)) == ERR_CANT_CREATE,
		"backup creation failure rejects the replacement"
	)
	_expect(
		FileAccess.get_file_as_bytes(BACKUP_FAILURE_PATH) == source_bytes
			and not bool(after.get("ok", true))
			and str(after.get("classification", "")) == "legacy_v2",
		"backup failure preserves the legacy source byte-for-byte and inspect-only"
	)
	_expect(
		not _directory_has_prefix(BACKUP_FAILURE_PATH.get_file() + ".backup-")
			and not _directory_has_prefix(BACKUP_FAILURE_PATH.get_file() + ".tmp-")
			and not _directory_has_prefix(BACKUP_FAILURE_PATH.get_file() + ".swap-"),
		"backup failure leaves no backup, temp, or swap artifact"
	)


func _test_directory_failure_has_zero_filesystem_effect() -> void:
	var directory_path := DIRECTORY_FAILURE_PATH.get_base_dir()
	_expect(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory_path)), "directory-failure fixture starts with no target directory")
	var envelope := _fixture_envelope("fault-directory", "fault-directory-write", "directory-next")
	var authorization: Dictionary = _save.call("write_authorization", DIRECTORY_FAILURE_PATH, envelope, {
		"qa_failure_stage": "directory_failure",
	})
	_expect(
		bool(authorization.get("allowed", false))
			and str(authorization.get("qa_failure_stage", "")) == "directory_failure",
		"directory failure uses a valid QA-only write authorization"
	)

	var failure: Dictionary = _save.call("write_validated_envelope", DIRECTORY_FAILURE_PATH, envelope, authorization)
	var operation: Dictionary = _save.call("operation_snapshot")
	_expect(
		not bool(failure.get("ok", true))
			and str(failure.get("reason_code", "")) == "qa_injected_directory_failure"
			and int(failure.get("error_code", OK)) == ERR_CANT_CREATE,
		"directory failure rejects before directory creation"
	)
	_expect(
		not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory_path))
			and not FileAccess.file_exists(DIRECTORY_FAILURE_PATH)
			and str(operation.get("operation_state", "")) == "failed"
			and str(operation.get("last_reason_code", "")) == "qa_injected_directory_failure",
		"directory failure creates no directory or file and records one failed operation"
	)


func _authorized_write(path: String, envelope: Dictionary) -> Dictionary:
	var authorization: Dictionary = _save.call("write_authorization", path, envelope)
	if not bool(authorization.get("allowed", false)):
		return {"ok": false, "reason_code": str(authorization.get("reason_code", "authorization_failed"))}
	return _save.call("write_validated_envelope", path, envelope, authorization) as Dictionary


func _fixture_envelope(envelope_id: String, write_id: String, private_value: String) -> Dictionary:
	var manifest: Dictionary = _handshake.call("required_section_manifest")
	var session_payload: Dictionary = {}
	var domains: Dictionary = {}
	for section_variant in manifest.keys():
		var section_id := str(section_variant)
		var state_version := int((manifest.get(section_id, {}) as Dictionary).get("state_version", 0))
		var payload := {"schema_version": state_version, "revision": 0, "fixture_id": "save-file-fault-matrix"}
		if section_id == "session":
			payload["private_fixture"] = private_value
			session_payload = payload
		else:
			domains[section_id] = payload
	return _handshake.call("compose_v06_envelope", session_payload, domains, {
		"envelope_id": envelope_id,
		"write_id": write_id,
	}) as Dictionary


func _write_text(path: String, text: String) -> bool:
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if directory_error != OK:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	file.close()
	return true


func _directory_has_prefix(prefix: String) -> bool:
	var directory := DirAccess.open(QA_ROOT)
	if directory == null:
		return false
	for filename in directory.get_files():
		if str(filename).begins_with(prefix):
			return true
	return false


func _cleanup_fixture_files() -> void:
	var directory := DirAccess.open(QA_ROOT)
	if directory != null:
		for filename in directory.get_files():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_ROOT.path_join(str(filename))))
	var nested_path := DIRECTORY_FAILURE_PATH.get_base_dir()
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(nested_path)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(nested_path))
	var missing_path := nested_path.get_base_dir()
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(missing_path)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(missing_path))


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("V06_SAVE_FILE_FAULT_MATRIX_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("V06_SAVE_FILE_FAULT_MATRIX_TEST|status=FAIL|checks=%d|failures=%d|first=%s" % [_checks, _failures.size(), _failures[0]])
	for failure in _failures:
		push_error(failure)
	quit(1)
