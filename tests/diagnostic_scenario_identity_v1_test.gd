extends SceneTree

const IDENTITY := preload("res://scripts/tools/diagnostic_scenario_identity_v1.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

const RUN_ID := "alpha04c-owner-capture-diagnostic-0123456789ab"
const HEAD := "0123456789abcdef0123456789abcdef01234567"
const SHA := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var identity := _valid_identity()
	_expect(bool(IDENTITY.validation_report(identity, RUN_ID, HEAD, SHA).get("valid", false)), "complete scenario identity validates")
	var wrong_depth := identity.duplicate(true)
	wrong_depth["challenge_depth"] = 2
	wrong_depth["identity_fingerprint"] = _fingerprint(wrong_depth)
	var depth_report := IDENTITY.validation_report(wrong_depth, RUN_ID, HEAD, SHA)
	_expect(not bool(depth_report.get("valid", true)) and str((depth_report.get("failure", {}) as Dictionary).get("failure_field", "")) == "challenge_depth", "challenge mismatch is field-attested")
	var wrong_head := identity.duplicate(true)
	wrong_head["repository_head"] = "b".repeat(40)
	wrong_head["identity_fingerprint"] = _fingerprint(wrong_head)
	_expect(not bool(IDENTITY.validation_report(wrong_head, RUN_ID, HEAD, SHA).get("valid", true)), "repository mismatch fails closed")
	var raw_seed := identity.duplicate(true)
	raw_seed["run_seed_tagged_int64"] = 900626424
	raw_seed["identity_fingerprint"] = _fingerprint(raw_seed)
	_expect(not bool(IDENTITY.validation_report(raw_seed, RUN_ID, HEAD, SHA).get("valid", true)), "raw untagged seed is rejected")
	var exposed := identity.duplicate(true)
	exposed["roster"] = ["private"]
	_expect(not bool(IDENTITY.validation_report(exposed, RUN_ID, HEAD, SHA).get("valid", true)), "extra roster payload is rejected")
	print("DIAGNOSTIC_SCENARIO_IDENTITY_V1_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _valid_identity() -> Dictionary:
	return IDENTITY.build({
		"run_id": RUN_ID,
		"repository_head": HEAD,
		"ruleset_id": "v0.6",
		"ruleset_fingerprint": SHA,
		"challenge_depth": 1,
		"run_seed": 900626424,
		"session_seed": 9223372036854770000,
		"scenario_fingerprint": SHA,
		"local_player_count": 1,
		"ai_player_count": 3,
		"roster_fingerprint": SHA,
		"session_id": "cold-restore-session",
		"session_generation": 1,
		"session_plan_fingerprint": SHA,
		"world_revision": 1,
		"runtime_composition_fingerprint": SHA,
		"save_registry_fingerprint": SHA,
		"user_data_path_fingerprint": SHA,
	})


func _fingerprint(value: Dictionary) -> String:
	return WIRE.fingerprint(value, "identity_fingerprint")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)
