extends Node

const QA_PATH := "user://test_runs/c16a_mcp/v06_save_envelope_runtime_bench.save"
const PRIVATE_SENTINEL := "C16A_PRIVATE_SENTINEL"
const FORBIDDEN_PUBLIC_KEYS := ["sections", "envelope", "exact_cash", "hand", "discard", "true_owner", "hidden_owner", "owner_truth", "ai_plan"]

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_artifacts()
	var session := get_node_or_null("GameSessionRuntimeController")
	var save := session.get_node_or_null("GameSaveRuntimeCoordinator") if session != null else null
	var handshake := save.get_node_or_null("RulesetSaveHandshakeService") if save != null else null
	_record("scene_tree", session != null and save != null and handshake != null)
	_record("narrow_save_api", _has_methods(save, ["validate_envelope", "write_validated_envelope", "read_and_validate", "inspect_legacy"]))
	_record("session_operation_only", session != null and session.has_method("operation_lifecycle_snapshot"))
	if session == null or save == null or handshake == null:
		_finish({})
		return
	session.call("configure", {"ruleset_id": "v0.6"})
	var save_snapshot: Dictionary = save.call("operation_snapshot")
	var explicit_qa_only := str(save_snapshot.get("qa_save_root", "")) == "user://test_runs/" \
		and str(save_snapshot.get("default_save_path", "not-empty")).is_empty() \
		and bool(save_snapshot.get("explicit_path_required", false))
	_record("explicit_qa_path_only", explicit_qa_only)
	var envelope := _fixture_envelope(handshake, "c16a-bench-envelope", "c16a-bench-write", PRIVATE_SENTINEL)
	var validation: Dictionary = save.call("validate_envelope", envelope)
	_record("strict_v3_handshake", bool(validation.get("valid", false)) and int(envelope.get("save_version", 0)) == 3 and str(envelope.get("ruleset_id", "")) == "v0.6" and int(envelope.get("currency_scale", 0)) == 100)
	var authorization: Dictionary = save.call("write_authorization", QA_PATH, envelope)
	var written: Dictionary = save.call("write_validated_envelope", QA_PATH, envelope, authorization)
	var readback: Dictionary = save.call("read_and_validate", QA_PATH)
	_record("atomic_roundtrip", bool(written.get("ok", false)) and bool(readback.get("ok", false)) and str(readback.get("fingerprint", "")) == str(validation.get("fingerprint", "")))
	var replay_authorization: Dictionary = save.call("write_authorization", QA_PATH, envelope)
	var replay: Dictionary = save.call("write_validated_envelope", QA_PATH, envelope, replay_authorization)
	_record("duplicate_write_idempotent", bool(replay.get("ok", false)) and bool(replay.get("idempotent", false)))
	var next_envelope := _fixture_envelope(handshake, "c16a-bench-envelope-2", "c16a-bench-write-2", "changed-private")
	var failed_authorization: Dictionary = save.call("write_authorization", QA_PATH, next_envelope, {"allow_replace": true, "qa_failure_stage": "after_destination_swap"})
	var failed_replace: Dictionary = save.call("write_validated_envelope", QA_PATH, next_envelope, failed_authorization)
	var preserved: Dictionary = save.call("read_and_validate", QA_PATH)
	_record("replace_failure_preserves_previous", not bool(failed_replace.get("ok", true)) and bool(preserved.get("ok", false)) and str(preserved.get("fingerprint", "")) == str(validation.get("fingerprint", "")))
	var legacy_v1: Dictionary = save.call("inspect_legacy", {"version": 1, "players": []})
	var legacy_v2: Dictionary = save.call("inspect_legacy", {"save_version": 2, "ruleset_id": "v0.5"})
	_record("legacy_inspect_only", bool(legacy_v1.get("recognized", false)) and not bool(legacy_v1.get("can_resume", true)) and bool(legacy_v2.get("recognized", false)) and not bool(legacy_v2.get("can_resume", true)))
	var encoded: Dictionary = handshake.call("encode_codec_value", {"position": Vector2(3.0, 4.0), "color": Color(0.1, 0.2, 0.3, 0.4)})
	var decoded: Dictionary = handshake.call("decode_codec_value", encoded.get("value"))
	_record("explicit_vector_color_codec", bool(encoded.get("ok", false)) and bool(decoded.get("ok", false)) and (decoded.get("value") as Dictionary).get("position") is Vector2 and (decoded.get("value") as Dictionary).get("color") is Color)
	var public_receipt: Dictionary = save.call("public_operation_receipt", written)
	_record("public_receipt_privacy", _privacy_leak_count(public_receipt) == 0 and not JSON.stringify(public_receipt).contains(PRIVATE_SENTINEL))
	var evidence := {
		"save_version": int(envelope.get("save_version", 0)),
		"ruleset_id": str(envelope.get("ruleset_id", "")),
		"currency_scale": int(envelope.get("currency_scale", 0)),
		"section_count": (envelope.get("sections", {}) as Dictionary).size(),
		"atomic_roundtrip": bool(readback.get("ok", false)),
		"idempotent": bool(replay.get("idempotent", false)),
		"legacy_resume": false,
		"business_state_captured_by_save": false,
		"explicit_qa_path_only": explicit_qa_only,
		"qa_root": "user://test_runs/",
		"default_player_path_accessed": false,
		"write_reason": str(written.get("reason_code", "")),
		"read_reason": str(readback.get("reason_code", "")),
		"authorization_reason": str(authorization.get("reason_code", "")),
		"failed_replace_reason": str(failed_replace.get("reason_code", "")),
	}
	_cleanup_artifacts()
	_finish(evidence)


func _fixture_envelope(handshake: Node, envelope_id: String, write_id: String, private_value: String) -> Dictionary:
	var manifest: Dictionary = handshake.call("required_section_manifest")
	var session_payload: Dictionary = {}
	var domains: Dictionary = {}
	for section_variant in manifest.keys():
		var section_id := str(section_variant)
		var state_version := int((manifest.get(section_id, {}) as Dictionary).get("state_version", 0))
		var payload := {"schema_version": state_version, "revision": 0, "fixture": "c16a"}
		if section_id == "session":
			payload["private_fixture"] = private_value
			session_payload = payload
		else:
			domains[section_id] = payload
	return handshake.call("compose_v06_envelope", session_payload, domains, {"envelope_id": envelope_id, "write_id": write_id}) as Dictionary


func _has_methods(target: Object, methods: Array[String]) -> bool:
	if target == null:
		return false
	for method_name in methods:
		if not target.has_method(method_name):
			return false
	return true


func _privacy_leak_count(value: Variant) -> int:
	var leaks := 0
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			if FORBIDDEN_PUBLIC_KEYS.has(key):
				leaks += 1
			leaks += _privacy_leak_count((value as Dictionary)[key_variant])
	elif value is Array:
		for item in value:
			leaks += _privacy_leak_count(item)
	elif value is String and str(value).contains(PRIVATE_SENTINEL):
		leaks += 1
	return leaks


func _cleanup_artifacts() -> void:
	var directory_path := ProjectSettings.globalize_path(QA_PATH.get_base_dir())
	if not DirAccess.dir_exists_absolute(directory_path):
		return
	var directory := DirAccess.open(QA_PATH.get_base_dir())
	if directory == null:
		return
	for filename in directory.get_files():
		if filename.begins_with(QA_PATH.get_file()):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_PATH.get_base_dir().path_join(filename)))


func _record(label: String, passed: bool) -> void:
	_checks += 1
	if not passed:
		_failures.append(label)


func _finish(evidence: Dictionary) -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V06_SAVE_ENVELOPE_RUNTIME_BENCH|status=%s|checks=%d|failures=%d|details=%s|evidence=%s" % [status, _checks, _failures.size(), JSON.stringify(_failures), JSON.stringify(evidence)])
	if not _failures.is_empty():
		push_error("V06 save envelope runtime Bench failed: %s" % JSON.stringify(_failures))
