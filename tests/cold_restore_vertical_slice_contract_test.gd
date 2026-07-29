extends SceneTree

const ORCHESTRATOR_PATH := "res://scripts/tools/cold_restore_vertical_slice_orchestrator.ps1"
const SAFE_RESULT_FIELDS := [
	"schema_version",
	"driver_id",
	"formal_full_run",
	"execution_ready",
	"executed",
	"contract_fixture",
	"run_id",
	"process_sequence",
	"comparison_scope",
	"process_ids_distinct",
	"head_sha_match",
	"generation1_digest_match",
	"generation2_digest_match",
	"write_chain_match",
	"section_counts_exact",
	"save_capture_deltas_zero",
	"restore_deltas_zero",
	"action_counts_positive",
	"generation2_counts_exact",
	"final_settlement_exact_once",
	"terminal_quiescent_frames",
	"terminal_quiet",
	"success",
	"failure_code",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FileAccess.get_file_as_string(ORCHESTRATOR_PATH)
	_expect(source.contains("$ORCHESTRATOR_SCHEMA_VERSION = 2") and source.contains("$FORMAL_FULL_RUN = $false") and source.contains("$DriverExecutionReady = $true"), "orchestrator declares executable non-Formal v2 contract")
	_expect(source.contains('[ValidateSet("producer", "consumer", "validator")]') and source.contains('$RoleSequence = @("producer", "consumer", "validator")'), "v2 contract has three closed process roles")
	_expect(source.contains("-PassThru -Wait -WindowStyle Hidden") and source.contains("-RedirectStandardOutput") and source.contains("-RedirectStandardError"), "every Godot role redirects stdout/stderr and waits for process exit")
	var producer_index := source.find('Invoke-ColdRestoreRole "producer"')
	var consumer_index := source.find('Invoke-ColdRestoreRole "consumer"')
	var validator_index := source.find('Invoke-ColdRestoreRole "validator"')
	_expect(producer_index >= 0 and producer_index < consumer_index and consumer_index < validator_index, "producer, consumer, and validator launch sequentially")
	_expect(source.contains("rev-parse HEAD") and source.contains("--cold-restore-head-sha=$HeadSha"), "one repository HEAD attestation is passed to all three roles")
	_expect(source.contains('$ManifestPrefix = "COLD_RESTORE_MANIFEST|"') and source.contains("manifest_marker_count_invalid") and source.contains("manifest_field_set_invalid"), "stdout parser accepts exactly one closed manifest marker")
	_expect(source.contains("$generation1Digest -eq [string]$Consumer.source_sections_digest") and source.contains("$generation1Digest -eq [string]$Consumer.restored_sections_digest"), "generation one compares A saved against B source and restored digests")
	_expect(source.contains("$generation2Digest -eq [string]$Validator.source_sections_digest") and source.contains("$generation2Digest -eq [string]$Validator.restored_sections_digest"), "generation two compares B saved against C source and restored digests")
	_expect(source.contains("write_id_rotation_invalid") and source.contains("write_fingerprint_rotation_invalid") and source.contains("write_chain_mismatch"), "v2 comparison rotates writes while preserving both source chains")
	for required_field in [
		"restore_rng_draw_delta",
		"restore_world_time_delta",
		"restore_public_log_delta",
		"restore_sale_receipt_delta",
		"restore_economic_reward_delta",
		"restore_ai_action_delta",
		"restore_player_action_delta",
		"restore_notification_delta",
		"human_action_count",
		"commodity_action_count",
		"ai_action_count",
		"sale_receipt_count",
		"terminal_quiescent_frames",
	]:
		_expect(source.contains('"%s"' % required_field), "v2 manifest includes %s" % required_field)
	_expect(source.contains("final_settlement_exact_once_invalid") and source.contains("terminal_quiescent_frames -eq 8") and source.contains("terminal_quiet_delta_nonzero"), "settlement is exact-once and followed by eight zero-delta quiet frames")

	var fixture := _valid_fixture()
	var fixture_path := ProjectSettings.globalize_path("user://cold_restore_orchestrator_v2_contract.json")
	_expect(_write_fixture(fixture_path, fixture), "synthetic safe manifest fixture is writable")
	var accepted := _invoke_orchestrator(fixture_path)
	var accepted_result: Dictionary = accepted.get("result", {}) if accepted.get("result", {}) is Dictionary else {}
	_expect(int(accepted.get("exit_code", -1)) == 0 and bool(accepted_result.get("success", false)), "synthetic three-process manifest chain passes the real PowerShell comparator")
	_expect(_has_exact_fields(accepted_result, SAFE_RESULT_FIELDS) and bool(accepted_result.get("process_ids_distinct", false)) and bool(accepted_result.get("head_sha_match", false)), "successful output uses one closed safe result allowlist")
	_expect(bool(accepted_result.get("generation1_digest_match", false)) and bool(accepted_result.get("generation2_digest_match", false)) and bool(accepted_result.get("write_chain_match", false)), "synthetic comparator proves both digest generations and write lineage")
	_expect(bool(accepted_result.get("save_capture_deltas_zero", false)) and bool(accepted_result.get("restore_deltas_zero", false)) and bool(accepted_result.get("action_counts_positive", false)), "synthetic comparator proves save/restore silence and continued actions")
	_expect(bool(accepted_result.get("final_settlement_exact_once", false)) and int(accepted_result.get("terminal_quiescent_frames", 0)) == 8 and bool(accepted_result.get("terminal_quiet", false)), "synthetic comparator proves one settlement and eight quiet frames")
	var accepted_serialized := JSON.stringify(accepted_result)
	for private_value in [
		str((fixture.get("producer", {}) as Dictionary).get("saved_sections_digest", "")),
		str((fixture.get("producer", {}) as Dictionary).get("write_id", "")),
		str((fixture.get("producer", {}) as Dictionary).get("write_fingerprint", "")),
		str((fixture.get("producer", {}) as Dictionary).get("head_sha", "")),
	]:
		_expect(not accepted_serialized.contains(private_value), "safe result omits manifest evidence value %s" % private_value.left(12))

	var digest_tamper := fixture.duplicate(true)
	(digest_tamper.get("validator", {}) as Dictionary)["restored_sections_digest"] = "tampered-generation-2".sha256_text()
	_expect(_write_fixture(fixture_path, digest_tamper), "digest-tamper fixture is writable")
	var rejected_digest := _invoke_orchestrator(fixture_path)
	var rejected_digest_result: Dictionary = rejected_digest.get("result", {}) if rejected_digest.get("result", {}) is Dictionary else {}
	_expect(int(rejected_digest.get("exit_code", 0)) != 0 and str(rejected_digest_result.get("failure_code", "")) == "generation2_digest_mismatch", "generation-two digest tamper fails closed")
	_expect(_has_exact_fields(rejected_digest_result, SAFE_RESULT_FIELDS) and not bool(rejected_digest_result.get("success", true)), "digest rejection still emits only allowlisted safe JSON")

	var private_injection := fixture.duplicate(true)
	(private_injection.get("producer", {}) as Dictionary)["envelope"] = {"sections": {"ai": {"private": true}}}
	_expect(_write_fixture(fixture_path, private_injection), "private-injection fixture is writable")
	var rejected_private := _invoke_orchestrator(fixture_path)
	var rejected_private_result: Dictionary = rejected_private.get("result", {}) if rejected_private.get("result", {}) is Dictionary else {}
	_expect(int(rejected_private.get("exit_code", 0)) != 0 and str(rejected_private_result.get("failure_code", "")) == "manifest_field_set_invalid", "unknown private manifest fields fail closed")
	_expect(_has_exact_fields(rejected_private_result, SAFE_RESULT_FIELDS) and not JSON.stringify(rejected_private_result).contains("private"), "private-field rejection emits no private payload or raw evidence")

	DirAccess.remove_absolute(fixture_path)
	if _failures.is_empty():
		print("COLD_RESTORE_VERTICAL_SLICE_CONTRACT_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	push_error("Cold restore vertical-slice contract test failed:\n- " + "\n- ".join(_failures))
	quit(1)


func _valid_fixture() -> Dictionary:
	var head_sha := "cold-restore-v2-head".sha256_text()
	var generation1_digest := "cold-restore-generation-1".sha256_text()
	var generation2_digest := "cold-restore-generation-2".sha256_text()
	var generation1_fingerprint := "cold-restore-write-1".sha256_text()
	var generation2_fingerprint := "cold-restore-write-2".sha256_text()
	var producer := _base_manifest("producer", 101, head_sha)
	producer["saved_sections_digest"] = generation1_digest
	producer["write_id"] = "cold-restore-write-a"
	producer["write_fingerprint"] = generation1_fingerprint
	producer["preflight_count"] = 19
	producer["generation"] = 1
	producer["slot_state"] = "ready"
	producer["production_surface_ready"] = true
	producer["victory_unresolved_before_save"] = true

	var consumer := _base_manifest("consumer", 202, head_sha)
	consumer["source_sections_digest"] = generation1_digest
	consumer["restored_sections_digest"] = generation1_digest
	consumer["saved_sections_digest"] = generation2_digest
	consumer["source_write_id"] = "cold-restore-write-a"
	consumer["write_id"] = "cold-restore-write-b"
	consumer["source_write_fingerprint"] = generation1_fingerprint
	consumer["write_fingerprint"] = generation2_fingerprint
	consumer["preflight_count"] = 19
	consumer["owner_apply_count"] = 19
	consumer["registry_apply_count"] = 1
	consumer["rng_draw_count_before"] = 41
	consumer["rng_draw_count_after"] = 41
	consumer["human_action_count"] = 2
	consumer["commodity_action_count"] = 1
	consumer["ai_action_count"] = 3
	consumer["sale_receipt_count"] = 1
	consumer["normal_card_count"] = 2
	consumer["commodity_card_count"] = 2
	consumer["commodity_claim_count"] = 1
	consumer["facility_count"] = 2
	consumer["route_count"] = 1
	consumer["military_unit_count"] = 1
	consumer["queue_entry_count"] = 1
	consumer["weather_region_count"] = 1
	consumer["ai_nondefault_state_count"] = 1
	consumer["victory_unresolved_before_save"] = true
	consumer["production_surface_ready"] = true
	consumer["victory_state_sequence"] = ["restored_running", "last_survivor", "resolved", "final_settlement", "quiescent"]
	consumer["final_settlement_count"] = 1
	consumer["final_settlement_presentation_count"] = 1
	consumer["final_settlement_public_log_count"] = 1
	consumer["terminal_quiescent_frames"] = 8
	consumer["generation"] = 2
	consumer["backup_created"] = true
	consumer["slot_state"] = "restored"

	var validator := _base_manifest("validator", 303, head_sha)
	validator["source_sections_digest"] = generation2_digest
	validator["restored_sections_digest"] = generation2_digest
	validator["source_write_id"] = "cold-restore-write-b"
	validator["source_write_fingerprint"] = generation2_fingerprint
	validator["preflight_count"] = 19
	validator["owner_apply_count"] = 19
	validator["registry_apply_count"] = 1
	validator["rng_draw_count_before"] = 52
	validator["rng_draw_count_after"] = 52
	validator["human_action_count"] = 2
	validator["commodity_action_count"] = 1
	validator["ai_action_count"] = 3
	validator["sale_receipt_count"] = 1
	validator["normal_card_count"] = 2
	validator["commodity_card_count"] = 2
	validator["commodity_claim_count"] = 1
	validator["facility_count"] = 2
	validator["route_count"] = 1
	validator["military_unit_count"] = 1
	validator["queue_entry_count"] = 1
	validator["weather_region_count"] = 1
	validator["ai_nondefault_state_count"] = 1
	validator["production_surface_ready"] = true
	validator["victory_state_sequence"] = ["restored_running", "last_survivor", "resolved", "final_settlement", "quiescent"]
	validator["final_settlement_count"] = 1
	validator["final_settlement_presentation_count"] = 1
	validator["final_settlement_public_log_count"] = 1
	validator["terminal_quiescent_frames"] = 8
	validator["generation"] = 2
	validator["slot_state"] = "validated"
	return {"producer": producer, "consumer": consumer, "validator": validator}


func _base_manifest(role: String, process_id: int, head_sha: String) -> Dictionary:
	return {
		"schema_version": 2,
		"visibility_scope": "qa_allowlisted",
		"run_id": "run-42",
		"process_role": role,
		"process_id": process_id,
		"head_sha": head_sha,
		"slot_id": "current_run",
		"slot_state": "failed",
		"source_sections_digest": "",
		"restored_sections_digest": "",
		"saved_sections_digest": "",
		"source_write_id": "",
		"write_id": "",
		"source_write_fingerprint": "",
		"write_fingerprint": "",
		"section_count": 19,
		"preflight_count": 0,
		"owner_apply_count": 0,
		"registry_apply_count": 0,
		"save_capture_world_delta": 0,
		"save_capture_rng_delta": 0,
		"save_capture_log_delta": 0,
		"rng_draw_count_before": 0,
		"rng_draw_count_after": 0,
		"restore_rng_draw_delta": 0,
		"restore_world_time_delta": 0,
		"restore_public_log_delta": 0,
		"restore_sale_receipt_delta": 0,
		"restore_economic_reward_delta": 0,
		"restore_ai_action_delta": 0,
		"restore_player_action_delta": 0,
		"restore_notification_delta": 0,
		"human_action_count": 0,
		"commodity_action_count": 0,
		"ai_action_count": 0,
		"sale_receipt_count": 0,
		"normal_card_count": 0,
		"commodity_card_count": 0,
		"commodity_claim_count": 0,
		"facility_count": 0,
		"route_count": 0,
		"military_unit_count": 0,
		"queue_entry_count": 0,
		"weather_region_count": 0,
		"ai_nondefault_state_count": 0,
		"victory_unresolved_before_save": false,
		"production_surface_ready": false,
		"victory_state_sequence": [],
		"final_settlement_count": 0,
		"final_settlement_presentation_count": 0,
		"final_settlement_public_log_count": 0,
		"terminal_quiescent_frames": 0,
		"terminal_world_delta": 0,
		"terminal_rng_draw_delta": 0,
		"generation": 0,
		"backup_created": false,
		"elapsed_ms": 10,
		"success": true,
		"failure_code": "",
	}


func _write_fixture(path: String, fixture: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(fixture))
	file.close()
	return true


func _invoke_orchestrator(fixture_path: String) -> Dictionary:
	var output: Array = []
	var project_path := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	var script_path := ProjectSettings.globalize_path(ORCHESTRATOR_PATH)
	var exit_code := OS.execute("pwsh", PackedStringArray([
		"-NoProfile",
		"-File",
		script_path,
		"-ProjectPath",
		project_path,
		"-RunId",
		"run-42",
		"-ContractManifestPath",
		fixture_path,
	]), output, true)
	var parsed: Dictionary = {}
	for chunk_variant: Variant in output:
		for line in str(chunk_variant).split("\n", false):
			var candidate := line.strip_edges()
			if not candidate.begins_with("{"):
				continue
			var value: Variant = JSON.parse_string(candidate)
			if value is Dictionary:
				parsed = value as Dictionary
	return {"exit_code": exit_code, "result": parsed, "raw_output": output}


func _has_exact_fields(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant: Variant in value.keys():
		if not expected.has(str(key_variant)):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
