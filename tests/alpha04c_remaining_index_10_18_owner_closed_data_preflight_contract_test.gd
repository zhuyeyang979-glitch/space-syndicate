extends SceneTree

const TOOL_PATH := "res://scripts/tools/alpha04c_remaining_index_10_18_owner_closed_data_preflight.gd"
const WRAPPER_PATH := "res://scripts/tools/run_alpha04c_remaining_index_10_18_owner_closed_data_preflight.ps1"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var tool := FileAccess.get_file_as_string(TOOL_PATH)
	var wrapper := FileAccess.get_file_as_string(WRAPPER_PATH)
	_expect(not tool.is_empty() and not wrapper.is_empty(), "index 10-18 preflight tool and wrapper exist")
	_expect(tool.contains('extends "res://scripts/tools/alpha04c_remaining_owner_closed_data_preflight.gd"'), "the proven production preflight implementation is reused")
	_expect(tool.contains("const NEW_FIRST_OWNER_INDEX := 10") \
			and tool.contains("const NEW_LAST_OWNER_INDEX := 18") \
			and tool.contains("const NEW_EXPECTED_OWNER_COUNT := 9"), "only Owner indexes 10 through 18 are selected")
	_expect(tool.contains("_preflight_owner(context, registry, binding, owner_index, production_ruleset_id)") \
			and tool.contains("break"), "real bindings are inspected and execution stops at the first failure")
	_expect(tool.contains('"total_remaining_owner_preflight_count": QUALIFIED_PRIOR_OWNER_COUNT + owner_results.size()') \
			and tool.contains('"total_remaining_owner_preflight_green_count": QUALIFIED_PRIOR_OWNER_COUNT + green_count'), "prior qualified Owners and new results are counted explicitly")
	_expect(tool.contains('"preflight_diagnostic_count_delta": 0') \
			and tool.contains('"preflight_quota_claim_count": 0') \
			and tool.contains('"v8_authorization_created": false'), "preflight remains nonconsuming and cannot pre-authorize V8")
	_expect(not tool.contains("capture_all_sections_detailed") \
			and not tool.contains("capture_resume_envelope") \
			and not tool.contains("request_save"), "preflight cannot become an all-Owner audit or Save")
	_expect(wrapper.contains("player_organization_preflight_not_green") \
			and wrapper.contains("monster_runtime_replay_v1_not_green") \
			and wrapper.contains("pr77_missing_monster_runtime_replay_result"), "prior Owner and PR #77 gates are verified")
	_expect(wrapper.contains("immutable_v7_evidence_precondition_mismatch") \
			and wrapper.contains("immutable_monster_replay_evidence_precondition_mismatch") \
			and wrapper.contains("v8_root_exists_before_authorization"), "immutable evidence and V8 absence are hard gates")
	_expect(wrapper.contains("replay_child_admission_consumed.json") \
			and wrapper.contains("monster_replay_unconsumed_admission_exists"), "the one Monster replay admission is proven consumed")
	_expect(wrapper.contains("remaining_index_10_18_preflight_remote_checkpoint_mismatch") \
			and wrapper.contains("WaitForExit(120000)") \
			and wrapper.contains("Kill($true)"), "the wrapper freezes pushed code and bounds its child process")
	_expect(wrapper.contains('[IO.FileMode]::CreateNew') \
			and wrapper.contains('$startInfo.Environment["APPDATA"] = $appData') \
			and wrapper.contains('$startInfo.Environment["LOCALAPPDATA"] = $localAppData'), "parent evidence is immutable and user data is isolated")
	_expect(not wrapper.contains("targeted_owner_capture_diagnostic_v2.gd") \
			and not wrapper.contains("process_a_rehearsal_completion_v1.gd") \
			and not wrapper.contains("run_alpha04c_monster_runtime_nonconsuming_replay.ps1"), "the wrapper cannot launch V8, Process A, or a second Monster replay")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("ALPHA04C_REMAINING_INDEX_10_18_OWNER_PREFLIGHT_CONTRACT_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Index 10-18 preflight contract failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
