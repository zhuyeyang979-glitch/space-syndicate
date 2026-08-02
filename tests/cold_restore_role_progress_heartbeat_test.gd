extends SceneTree

const HEARTBEAT := preload("res://scripts/tools/cold_restore_role_progress_heartbeat.gd")

const HEAD := "0123456789abcdef0123456789abcdef01234567"
const POLICY := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

var _checks := 0
var _failures: Array[String] = []
var _run_id := ""


func _init() -> void:
	_run_id = "heartbeat-contract-%d" % OS.get_process_id()
	var heartbeat := HEARTBEAT.new()
	_expect(bool(heartbeat.initialize(_run_id, "process_a", HEAD, POLICY).get("valid", false)), "heartbeat identity initializes")
	var first := heartbeat.emit(_progress("session_started", 0, -1, 0, "setup"))
	var duplicate := heartbeat.emit(_progress("session_started", 0, -1, 0, "setup"))
	var advanced := heartbeat.emit(_progress("owner_capture_started", 0, 0, 1, "capture"))
	_expect(bool(first.get("valid", false)) and bool(first.get("semantic_progressed", false)), "first heartbeat is semantic progress")
	_expect(bool(duplicate.get("valid", false)) and not bool(duplicate.get("semantic_progressed", true)), "sequence-only heartbeat does not count as progress")
	_expect(bool(advanced.get("valid", false)) and bool(advanced.get("semantic_progressed", false)), "authoritative field change counts as progress")
	var value := (advanced.get("heartbeat", {}) as Dictionary).duplicate(true)
	_expect(bool(HEARTBEAT.validation_report(value, _run_id, "process_a", HEAD, POLICY).get("valid", false)), "heartbeat validates against bound identity")
	value["run_id"] = "other-run"
	_expect(not bool(HEARTBEAT.validation_report(value, _run_id, "process_a", HEAD, POLICY).get("valid", true)), "wrong run identity rejects")
	var policy_text := FileAccess.get_file_as_string("res://scripts/tools/cold_restore_role_timeout_policy_v1.json")
	var policy_value: Variant = JSON.parse_string(policy_text)
	_expect(policy_value is Dictionary \
			and str((policy_value as Dictionary).get("policy_id", "")) == "ColdRestoreRoleTimeoutPolicyV1" \
			and ((policy_value as Dictionary).get("roles", {}) as Dictionary).size() == 4, "four-role timeout policy is machine-readable")
	print("COLD_RESTORE_ROLE_PROGRESS_HEARTBEAT_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _progress(phase: String, world_time: int, owner_index: int, queue_revision: int, save_phase: String) -> Dictionary:
	return {
		"phase": phase,
		"world_time": world_time,
		"owner_index": owner_index,
		"queue_revision": queue_revision,
		"save_phase": save_phase,
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)
