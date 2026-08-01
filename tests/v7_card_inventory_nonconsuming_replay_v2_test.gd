extends SceneTree

const TOOL_PATH := "res://scripts/tools/alpha04c_v7_card_inventory_nonconsuming_replay.gd"
const WRAPPER_PATH := "res://scripts/tools/run_alpha04c_v7_card_inventory_nonconsuming_replay_v2.ps1"
const AUTHORIZATION_PATH := "res://scripts/tools/card_inventory_owner_replay_authorization_v1.json"
const IDENTITY_PATH := "res://scripts/tools/card_inventory_owner_replay_scenario_identity_v1.gd"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var tool := FileAccess.get_file_as_string(TOOL_PATH)
	var wrapper := FileAccess.get_file_as_string(WRAPPER_PATH)
	var identity := FileAccess.get_file_as_string(IDENTITY_PATH)
	var authorization_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string(AUTHORIZATION_PATH))
	var authorization: Dictionary = authorization_variant if authorization_variant is Dictionary else {}
	_expect(not tool.is_empty() and not wrapper.is_empty() and not identity.is_empty() and not authorization.is_empty(), "Replay v2 sources exist")
	_expect(str(authorization.get("authorization_id", "")) == "alpha04c-v7-card-inventory-save-v4-checkpoint-v2-replay-v2-scenario-identity", "authorization id is exact")
	_expect(str(authorization.get("run_id", "")).begins_with("alpha04c-v7-card-inventory-replay-v2-scenario-identity-"), "run id uses the authorized prefix")
	_expect(int(authorization.get("replay_attempt_count_before", -1)) == 1 \
			and int(authorization.get("replay_attempt_count_after", -1)) == 2, "attempt transition is 1 to 2")
	_expect(tool.contains('session.get_node_or_null("RulesetSaveAttestationOwner")') \
			and not tool.contains('session.get_node_or_null("../RulesetSaveAttestationOwner")'), "ruleset owner path is the production Session child")
	_expect(tool.contains("REPLAY_SCENARIO_IDENTITY.build") \
			and tool.contains("REPLAY_SCENARIO_IDENTITY.validation_report"), "tool builds and validates the dedicated replay identity")
	_expect(not tool.contains("diagnostic_scenario_identity_v1.gd") \
			and not tool.contains("targeted_owner_diagnostic"), "replay identity is not mislabeled as a targeted diagnostic")
	_expect(identity.contains('const PRODUCTION_RUNTIME_RULESET_ID := "v0.6"') \
			and identity.contains('const HIGHEST_TARGET_RULESET_ID := "v0.7.3"') \
			and identity.contains('const SCENARIO_IDENTITY_AUTHORITY := "production_runtime_ruleset_id"'), "runtime and highest target identities are separated")
	_expect(tool.contains('ruleset_owner.call("to_save_data")') \
			and tool.contains('registry.call("registry_snapshot")') \
			and tool.contains("get_script_constant_map"), "identity values come from real production owners and Registry")
	_expect(tool.contains('owner.call("to_save_data")') \
			and tool.contains('owner.call("capture_runtime_checkpoint")') \
			and tool.contains('owner.call("restore_runtime_checkpoint", checkpoint_a)'), "real Card Inventory APIs remain the only replay target")
	_expect(not tool.contains("capture_all_sections_detailed") \
			and not tool.contains("capture_resume_envelope"), "replay cannot become a full Owner audit")
	_expect(not tool.contains("request_save") and not tool.contains("write_validated_envelope"), "replay cannot write a production Save")
	_expect(wrapper.contains("prior_replay_attempt_attestation_invalid") \
			and wrapper.contains("replay_v2_evidence_already_exists"), "wrapper binds attempt two and rejects retries")
	_expect(wrapper.contains("[IO.FileMode]::CreateNew") \
			and wrapper.contains("replay_attempt_claim.json") \
			and wrapper.contains("replay_child_admission.json"), "wrapper atomically claims attempt two and creates one child admission")
	_expect(tool.contains("_consume_replay_admission") \
			and tool.contains("DirAccess.rename_absolute(admission_path, consumed_path)"), "child atomically consumes its one admission")
	_expect(not wrapper.contains("[string]$EvidenceOutput") \
			and not wrapper.contains("[string]$ParentOutput") \
			and tool.contains("replay_v2_evidence_path_not_canonical"), "evidence paths cannot be redirected to bypass attempt two")
	_expect(wrapper.contains("status --porcelain") \
			and wrapper.contains("replay_v2_remote_checkpoint_mismatch") \
			and wrapper.contains("card_inventory_repair_head_not_ancestor"), "wrapper requires a clean pushed descendant of the repair result")
	_expect(wrapper.contains("WaitForExit(120000)") \
			and wrapper.contains("Kill($true)") \
			and wrapper.contains("if (-not $process.HasExited)"), "wrapper bounds runtime and terminates only its process tree")
	_expect(wrapper.contains("Resolve-GodotConsolePath") \
			and not wrapper.contains("C:\\Users\\"), "wrapper resolves Godot without a committed local user path")
	_expect(wrapper.contains("Test-ExactJsonInt64") \
			and wrapper.contains("Test-ExactPropertySet"), "wrapper rejects coercive or extra authorization fields")
	_expect(wrapper.contains('$startInfo.Environment["APPDATA"] = $appData') \
			and wrapper.contains('$startInfo.Environment["LOCALAPPDATA"] = $localAppData'), "wrapper isolates user data")
	_expect(wrapper.contains("immutable_v7_evidence_preserved") \
			and wrapper.contains("replay_quota_claim_count = 0") \
			and wrapper.contains("replay_full_owner_audit_count = 0"), "wrapper attests V7 immutability and nonconsumption")
	_expect(tool.contains('result["v7_card_inventory_payload_closed"]') \
			and tool.contains('result["v7_card_inventory_capture_mutation_count"]') \
			and wrapper.contains("v7_card_inventory_capture_mutation_count -eq 0"), "child and parent explicitly attest closed payloads and zero capture mutation")
	_expect(not wrapper.contains("cold_restore_vertical_slice_orchestrator.ps1") \
			and not wrapper.contains("process_a_rehearsal"), "wrapper cannot launch V8 or Process A")
	_expect(_occurrences(identity, "class_name CardInventoryOwnerReplayScenarioIdentityV1") == 1, "Scenario Identity contract has one implementation source")
	_expect(not tool.contains('"v0.7.3"') and not tool.contains('"v0.6"') \
			and not wrapper.contains('"v0.7.3"') and not wrapper.contains('"v0.6"'), "runtime sources do not duplicate ruleset identity literals")
	_finish()


func _occurrences(source: String, needle: String) -> int:
	return source.split(needle, false).size() - 1 if not needle.is_empty() else 0


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("V7_CARD_INVENTORY_NONCONSUMING_REPLAY_V2_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Replay v2 contract failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
