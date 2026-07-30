extends SceneTree

const COMPLETION := preload("res://scripts/tools/process_a_rehearsal_completion_v1.gd")

const HEAD := "12691a8bc7ad2c5a9f4c175c95a8c214ea346a74"
const SCENARIO := "0bccef8426345e2ea1fd8ae7d6187d282d52d44bc73d6fb3d1ed3375dc20b7bf"
const AUTHORIZATION := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const TIMEOUT_POLICY := "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
const SAVE_FINGERPRINT := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
const SAVE_SHA256 := "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"

var _checks := 0
var _failures: Array[String] = []
var _run_id := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_id = "process-a-rehearsal-completion-%d" % OS.get_process_id()
	var completion := _valid_completion()
	_expect(bool(COMPLETION.validation_report(
		completion, _run_id, HEAD, SCENARIO, AUTHORIZATION, TIMEOUT_POLICY
	).get("valid", false)), "green rehearsal completion validates")
	for flag in [
		"restore_barrier_entered", "restore_barrier_quiet", "restore_barrier_released",
		"envelope_encode_green", "atomic_write_green", "save_readback_green",
		"save_fingerprint_parity",
	]:
		var tampered := completion.duplicate(true)
		tampered[flag] = false
		_expect(not bool(COMPLETION.validation_report(tampered).get("valid", true)), "%s fails closed" % flag)
	for field in ["save_owner_capture_count", "save_section_count", "save_preflight_count"]:
		var wrong_count := completion.duplicate(true)
		wrong_count[field] = 18
		_expect(not bool(COMPLETION.validation_report(wrong_count).get("valid", true)), "%s requires 19" % field)
	var official := completion.duplicate(true)
	official["official"] = true
	_expect(not bool(COMPLETION.validation_report(official).get("valid", true)), "official rehearsal evidence rejects")
	var claim_created := completion.duplicate(true)
	claim_created["official_attempt_claim_created"] = true
	_expect(not bool(COMPLETION.validation_report(claim_created).get("valid", true)), "official claim creation rejects")
	var mismatched_readback := completion.duplicate(true)
	mismatched_readback["save_readback_fingerprint"] = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
	_expect(not bool(COMPLETION.validation_report(mismatched_readback).get("valid", true)), "readback mismatch rejects")
	for delta_field in ["save_capture_world_delta", "save_capture_rng_delta", "save_capture_public_log_delta"]:
		var nonzero_delta := completion.duplicate(true)
		nonzero_delta[delta_field] = 1
		_expect(not bool(COMPLETION.validation_report(nonzero_delta).get("valid", true)), "%s must remain zero" % delta_field)
	var write := COMPLETION.write_atomic(_run_id, completion)
	_expect(bool(write.get("valid", false)) and FileAccess.file_exists(str(write.get("path", ""))), "completion writes atomically")
	var duplicate := COMPLETION.write_atomic(_run_id, completion)
	_expect(not bool(duplicate.get("valid", true)) and str(duplicate.get("reason_code", "")).contains("collision"), "duplicate evidence write rejects")
	_cleanup()
	if _failures.is_empty():
		print("PROCESS_A_REHEARSAL_COMPLETION_TEST|%d/%d" % [_checks, _checks])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _valid_completion() -> Dictionary:
	return COMPLETION.build({
		"run_id": _run_id,
		"repository_head": HEAD,
		"scenario_fingerprint": SCENARIO,
		"authorization_fingerprint": AUTHORIZATION,
		"timeout_policy_fingerprint": TIMEOUT_POLICY,
		"restore_barrier_entered": true,
		"restore_barrier_quiet": true,
		"restore_barrier_released": true,
		"save_owner_capture_count": 19,
		"save_section_count": 19,
		"save_preflight_count": 19,
		"capture_operation_sequence": 7,
		"captured_sections_fingerprint": SAVE_FINGERPRINT,
		"readback_sections_fingerprint": SAVE_FINGERPRINT,
		"save_capture_world_delta": 0,
		"save_capture_rng_delta": 0,
		"save_capture_public_log_delta": 0,
		"envelope_encode_green": true,
		"atomic_write_green": true,
		"save_readback_green": true,
		"save_capture_fingerprint": SAVE_FINGERPRINT,
		"save_readback_fingerprint": SAVE_FINGERPRINT,
		"save_fingerprint_parity": true,
		"save_file_bytes": 624083,
		"save_file_sha256": SAVE_SHA256,
		"queue_entry_count": 1,
	})


func _cleanup() -> void:
	var path := COMPLETION.stable_path(_run_id)
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
