extends SceneTree

const SESSION_SCENE_PATH := "res://scenes/runtime/GameSessionRuntimeController.tscn"
const QA_ROOT := "user://test_runs/c16a_focused/"
const PRIVATE_SENTINEL := "C16A_PRIVATE_SAVE_SENTINEL"
const FORBIDDEN_PUBLIC_KEYS := [
	"sections", "envelope", "exact_cash", "cash_after", "hand", "discard",
	"true_owner", "hidden_owner", "owner_truth", "ai_plan", "ai_score",
]

var _session: Node
var _save: Node
var _handshake: Node
var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_root()
	_test_scene_and_registry()
	if _save == null or _handshake == null:
		_finish()
		return
	_test_strict_envelope_schema()
	_test_codec_and_determinism()
	_test_roundtrip_replay_and_session_lifecycle()
	_test_atomic_failure_matrix()
	_test_legacy_unknown_and_corrupt_paths()
	_cleanup_root()
	_finish()


func _test_scene_and_registry() -> void:
	var packed := load(SESSION_SCENE_PATH) as PackedScene
	_expect(packed != null, "GameSession scene loads")
	if packed == null:
		return
	_session = packed.instantiate()
	root.add_child(_session)
	_save = _session.get_node_or_null("GameSaveRuntimeCoordinator")
	_handshake = _save.get_node_or_null("RulesetSaveHandshakeService") if _save != null else null
	_expect(_save != null and _handshake != null, "one Session composes one Save and one Handshake service")
	_expect(_has_methods(_save, ["validate_envelope", "write_validated_envelope", "read_and_validate", "inspect_legacy"]), "C16b narrow save API is present")
	_expect(_has_methods(_handshake, ["required_section_manifest", "write_authorization", "authorization_matches", "encode_codec_value", "decode_codec_value"]), "strict handshake and codec APIs are present")
	_session.call("configure", {"ruleset_id": "v0.6"})
	var save_snapshot: Dictionary = _save.call("operation_snapshot")
	_expect(bool(save_snapshot.get("configured", false)) and int(save_snapshot.get("save_version", 0)) == 3 and str(save_snapshot.get("ruleset_id", "")) == "v0.6" and int(save_snapshot.get("currency_scale", 0)) == 100, "production envelope identity is v3/v0.6/currency 100")
	_expect(str(save_snapshot.get("default_save_path", "not-empty")).is_empty() and bool(save_snapshot.get("explicit_path_required", false)) and str(save_snapshot.get("qa_save_root", "")) == "user://test_runs/", "save I/O requires an explicit isolated QA path")
	_expect(not bool(save_snapshot.get("captures_business_state", true)) and not bool((_session.call("operation_lifecycle_snapshot") as Dictionary).get("captures_business_state", true)), "Save and Session do not capture business owners")
	var manifest: Dictionary = _handshake.call("required_section_manifest")
	var owners: Dictionary = {}
	for section_variant in manifest.keys():
		var owner_id := str((manifest.get(section_variant, {}) as Dictionary).get("owner_id", ""))
		owners[owner_id] = true
	var bankruptcy_contract: Dictionary = manifest.get("bankruptcy_neutral_estate", {}) if manifest.get("bankruptcy_neutral_estate", {}) is Dictionary else {}
	var history_contract: Dictionary = manifest.get("card_resolution_history", {}) if manifest.get("card_resolution_history", {}) is Dictionary else {}
	_expect(manifest.size() == 19 and owners.size() == manifest.size() and manifest.has("session") and manifest.has("player_organization") and str(bankruptcy_contract.get("owner_id", "")) == "bankruptcy_neutral_estate" and int(bankruptcy_contract.get("state_version", 0)) == 1 and str(history_contract.get("owner_id", "")) == "card_resolution_history" and int(history_contract.get("state_version", 0)) == 1, "registry has 19 unique required owners including card resolution history and bankruptcy neutral estate")


func _test_strict_envelope_schema() -> void:
	var envelope := _fixture_envelope("schema-envelope", "schema-write", PRIVATE_SENTINEL)
	var validation: Dictionary = _save.call("validate_envelope", envelope)
	_expect(bool(validation.get("valid", false)), "complete v3 envelope validates")
	for key_variant in envelope.keys():
		var damaged := envelope.duplicate(true)
		damaged.erase(key_variant)
		_expect(not bool((_save.call("validate_envelope", damaged) as Dictionary).get("valid", true)), "missing top-level field rejects: %s" % str(key_variant))
	var unknown_header := envelope.duplicate(true)
	unknown_header["future_header"] = true
	_expect(not bool((_save.call("validate_envelope", unknown_header) as Dictionary).get("valid", true)), "unknown top-level header rejects")
	var unknown_section := envelope.duplicate(true)
	(unknown_section["sections"] as Dictionary)["unknown_owner_section"] = {"schema_version": 1}
	_expect(not bool((_save.call("validate_envelope", unknown_section) as Dictionary).get("valid", true)), "unknown section rejects")
	var missing_section := envelope.duplicate(true)
	var first_section := str((missing_section["sections"] as Dictionary).keys()[0])
	(missing_section["sections"] as Dictionary).erase(first_section)
	_expect(not bool((_save.call("validate_envelope", missing_section) as Dictionary).get("valid", true)), "missing required section rejects")
	var wrong_section_version := envelope.duplicate(true)
	((wrong_section_version["sections"] as Dictionary)[first_section] as Dictionary)["schema_version"] = 99
	_expect(not bool((_save.call("validate_envelope", wrong_section_version) as Dictionary).get("valid", true)), "section registry version mismatch rejects")
	var raw_variant := envelope.duplicate(true)
	((raw_variant["sections"] as Dictionary)[first_section] as Dictionary)["raw_vector"] = Vector2.ONE
	_expect(not bool((_save.call("validate_envelope", raw_variant) as Dictionary).get("valid", true)), "raw Variant values fail closed")
	_expect(not bool((_save.call("validate_envelope", {"version": 1, "players": []}) as Dictionary).get("valid", true)), "v1 cannot validate as resumable v3")
	_expect(not bool((_save.call("validate_envelope", {"save_version": 2, "ruleset_id": "v0.5"}) as Dictionary).get("valid", true)), "v2 cannot validate as resumable v3")


func _test_codec_and_determinism() -> void:
	var source := {
		"position": Vector2(12.5, -3.0),
		"color": Color(0.1, 0.2, 0.3, 0.4),
		"nested": [{"value": 4}],
	}
	var encoded: Dictionary = _handshake.call("encode_codec_value", source)
	var decoded: Dictionary = _handshake.call("decode_codec_value", encoded.get("value"))
	var decoded_value: Dictionary = decoded.get("value", {}) if decoded.get("value", {}) is Dictionary else {}
	_expect(bool(encoded.get("ok", false)) and bool(decoded.get("ok", false)) and decoded_value.get("position") == source.position and decoded_value.get("color") == source.color, "Vector2 and Color use the explicit tagged codec")
	var forbidden_node := Node.new()
	_expect(not bool((_handshake.call("encode_codec_value", forbidden_node) as Dictionary).get("ok", true)), "arbitrary Object codec input rejects")
	forbidden_node.free()
	_expect(not bool((_handshake.call("decode_codec_value", {"$codec": "Object", "id": 1}) as Dictionary).get("ok", true)), "unknown codec tag rejects")
	var envelope_a := _fixture_envelope("deterministic-envelope", "deterministic-write", "same")
	var sections_a: Dictionary = envelope_a.get("sections", {})
	var reverse_keys: Array = sections_a.keys()
	reverse_keys.reverse()
	var reversed_domains: Dictionary = {}
	var reversed_session: Dictionary = {}
	for key_variant in reverse_keys:
		if str(key_variant) == "session":
			reversed_session = (sections_a[key_variant] as Dictionary).duplicate(true)
		else:
			reversed_domains[str(key_variant)] = (sections_a[key_variant] as Dictionary).duplicate(true)
	var envelope_b: Dictionary = _handshake.call("compose_v06_envelope", reversed_session, reversed_domains, {"envelope_id": "deterministic-envelope", "write_id": "deterministic-write"})
	_expect(str((_save.call("validate_envelope", envelope_a) as Dictionary).get("fingerprint", "")) == str((_save.call("validate_envelope", envelope_b) as Dictionary).get("fingerprint", "")), "dictionary insertion order does not change fingerprint")


func _test_roundtrip_replay_and_session_lifecycle() -> void:
	var path := QA_ROOT + "roundtrip.save"
	var envelope := _fixture_envelope("roundtrip-envelope", "roundtrip-write", PRIVATE_SENTINEL)
	var validation: Dictionary = _save.call("validate_envelope", envelope)
	var authorization: Dictionary = _save.call("write_authorization", path, envelope)
	var written: Dictionary = _save.call("write_validated_envelope", path, envelope, authorization)
	var readback: Dictionary = _save.call("read_and_validate", path)
	_expect(bool(written.get("ok", false)) and bool(readback.get("ok", false)) and str(readback.get("fingerprint", "")) == str(validation.get("fingerprint", "")), "valid v3 atomic roundtrip succeeds")
	var replay_auth: Dictionary = _save.call("write_authorization", path, envelope)
	var replay: Dictionary = _save.call("write_validated_envelope", path, envelope, replay_auth)
	_expect(bool(replay.get("ok", false)) and bool(replay.get("idempotent", false)), "duplicate write is idempotent")
	var collision := _fixture_envelope("collision-envelope", "roundtrip-write", "different")
	var collision_auth: Dictionary = _save.call("write_authorization", path, collision, {"allow_replace": true})
	_expect(not bool(collision_auth.get("allowed", true)) and str(collision_auth.get("reason_code", "")) == "write_id_collision", "same write id with different envelope rejects")
	var public_receipt: Dictionary = _save.call("public_operation_receipt", written)
	_expect(_privacy_leak_count(public_receipt) == 0 and not JSON.stringify(public_receipt).contains(PRIVATE_SENTINEL), "public write receipt has zero nested privacy leaks")
	var unauthorized := _save.call("write_validated_envelope", QA_ROOT + "unauthorized.save", envelope, {}) as Dictionary
	_expect(not bool(unauthorized.get("ok", true)) and str(unauthorized.get("reason_code", "")) == "write_authorization_invalid", "write without handshake authorization rejects")
	var outside := _save.call("write_authorization", "user://not_test_runs/c16a.save", envelope) as Dictionary
	_expect(not bool(outside.get("allowed", true)), "default player save path is never accessed by C16a")
	var session_path := QA_ROOT + "session_lifecycle.save"
	var session_envelope := _fixture_envelope("session-envelope", "session-write", "session-private")
	var session_auth: Dictionary = _save.call("write_authorization", session_path, session_envelope)
	var session_write: Dictionary = _session.call("request_save", session_path, session_envelope, session_auth)
	var lifecycle: Dictionary = _session.call("operation_lifecycle_snapshot")
	_expect(bool(session_write.get("ok", false)) and (lifecycle.get("active", {}) as Dictionary).is_empty() and str((lifecycle.get("last", {}) as Dictionary).get("state", "")) == "complete", "GameSession owns only write operation lifecycle")
	var session_read: Dictionary = _session.call("request_load", session_path)
	lifecycle = _session.call("operation_lifecycle_snapshot")
	_expect(bool(session_read.get("ok", false)) and (lifecycle.get("active", {}) as Dictionary).is_empty() and str((lifecycle.get("last", {}) as Dictionary).get("kind", "")) == "read", "GameSession owns only read operation lifecycle")


func _test_atomic_failure_matrix() -> void:
	for stage in ["before_temp_write", "after_temp_write", "after_readback", "before_replace", "after_destination_swap"]:
		var path := QA_ROOT + "failure_%s.save" % stage
		var base := _fixture_envelope("base-%s" % stage, "base-write-%s" % stage, "base")
		var base_auth: Dictionary = _save.call("write_authorization", path, base)
		var base_write: Dictionary = _save.call("write_validated_envelope", path, base, base_auth)
		var base_read: Dictionary = _save.call("read_and_validate", path)
		var replacement := _fixture_envelope("next-%s" % stage, "next-write-%s" % stage, "next")
		var failure_auth: Dictionary = _save.call("write_authorization", path, replacement, {"allow_replace": true, "qa_failure_stage": stage})
		var failure: Dictionary = _save.call("write_validated_envelope", path, replacement, failure_auth)
		var after: Dictionary = _save.call("read_and_validate", path)
		_expect(bool(base_write.get("ok", false)) and bool(base_read.get("ok", false)) and not bool(failure.get("ok", true)) and bool(after.get("ok", false)) and str(after.get("fingerprint", "")) == str(base_read.get("fingerprint", "")), "atomic failure preserves previous file: %s" % stage)
		_expect(not _directory_has_fragment(path.get_file() + ".tmp-") and not _directory_has_fragment(path.get_file() + ".swap-"), "atomic failure leaves no temporary half-file: %s" % stage)


func _test_legacy_unknown_and_corrupt_paths() -> void:
	var legacy_cases := [
		{"name": "v1", "document": {"version": 1, "players": []}, "classification": "legacy_v1"},
		{"name": "v2", "document": {"save_version": 2, "ruleset_id": "v0.5", "session": {}, "domains": {}}, "classification": "legacy_v2"},
	]
	for case_variant in legacy_cases:
		var case := case_variant as Dictionary
		var path := QA_ROOT + "legacy_%s.save" % str(case.name)
		_write_fixture(path, JSON.stringify(case.document))
		var read_result: Dictionary = _save.call("read_and_validate", path)
		var inspection: Dictionary = _save.call("inspect_legacy", case.document)
		_expect(not bool(read_result.get("ok", true)) and str(read_result.get("classification", "")) == str(case.classification) and not bool(inspection.get("can_resume", true)) and bool(inspection.get("requires_backup", false)), "%s is inspect-only and cannot resume" % str(case.name))
		var replacement := _fixture_envelope("legacy-replacement-%s" % str(case.name), "legacy-write-%s" % str(case.name), "replacement")
		var denied_auth: Dictionary = _save.call("write_authorization", path, replacement, {"allow_replace": true})
		_expect(not bool(denied_auth.get("allowed", true)) and str(denied_auth.get("reason_code", "")) == "backup_authorization_required", "%s overwrite requires explicit backup authorization" % str(case.name))
		var allowed_auth: Dictionary = _save.call("write_authorization", path, replacement, {"allow_replace": true, "allow_backup": true})
		var replaced: Dictionary = _save.call("write_validated_envelope", path, replacement, allowed_auth)
		_expect(bool(replaced.get("ok", false)) and bool(replaced.get("backup_created", false)) and FileAccess.file_exists(str(replaced.get("backup_path", ""))) and bool((_save.call("read_and_validate", path) as Dictionary).get("ok", false)), "%s backup precedes authorized v3 replacement" % str(case.name))
	var malformed_cases := [
		{"name": "truncated", "text": "{\"save_version\":3,"},
		{"name": "corrupt", "text": "not-json"},
		{"name": "unknown", "text": JSON.stringify({"save_version": 99, "ruleset_id": "future"})},
	]
	for case_variant in malformed_cases:
		var case := case_variant as Dictionary
		var path := QA_ROOT + "%s.save" % str(case.name)
		_write_fixture(path, str(case.text))
		var before := FileAccess.get_file_as_bytes(path)
		var rejected: Dictionary = _save.call("read_and_validate", path)
		var replacement := _fixture_envelope("malformed-%s" % str(case.name), "malformed-write-%s" % str(case.name), "safe")
		var denied_auth: Dictionary = _save.call("write_authorization", path, replacement, {"allow_replace": true})
		_expect(not bool(rejected.get("ok", true)) and not bool(denied_auth.get("allowed", true)) and FileAccess.get_file_as_bytes(path) == before, "%s input rejects with zero overwrite" % str(case.name))


func _fixture_envelope(envelope_id: String, write_id: String, private_value: String) -> Dictionary:
	var manifest: Dictionary = _handshake.call("required_section_manifest")
	var session_payload: Dictionary = {}
	var domains: Dictionary = {}
	for section_variant in manifest.keys():
		var section_id := str(section_variant)
		var state_version := int((manifest.get(section_id, {}) as Dictionary).get("state_version", 0))
		var payload := {"schema_version": state_version, "revision": 0, "fixture_id": "c16a-focused"}
		if section_id == "session":
			payload["private_fixture"] = private_value
			session_payload = payload
		else:
			domains[section_id] = payload
	return _handshake.call("compose_v06_envelope", session_payload, domains, {"envelope_id": envelope_id, "write_id": write_id}) as Dictionary


func _write_fixture(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.flush()
		file.close()


func _directory_has_fragment(fragment: String) -> bool:
	var directory := DirAccess.open(QA_ROOT)
	if directory == null:
		return false
	for filename in directory.get_files():
		if filename.contains(fragment):
			return true
	return false


func _cleanup_root() -> void:
	var absolute := ProjectSettings.globalize_path(QA_ROOT)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory := DirAccess.open(QA_ROOT)
	if directory == null:
		return
	for filename in directory.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_ROOT.path_join(filename)))


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


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("V06_SAVE_ENVELOPE_RUNTIME_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("V06_SAVE_ENVELOPE_RUNTIME_TEST|status=FAIL|checks=%d|failures=%d|first=%s" % [_checks, _failures.size(), _failures[0]])
	for failure in _failures:
		push_error(failure)
	quit(1)
