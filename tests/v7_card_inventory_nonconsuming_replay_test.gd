extends SceneTree

const TOOL_PATH := "res://scripts/tools/alpha04c_v7_card_inventory_nonconsuming_replay.gd"
const WRAPPER_PATH := "res://scripts/tools/run_alpha04c_v7_card_inventory_nonconsuming_replay.ps1"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var tool := FileAccess.get_file_as_string(TOOL_PATH)
	var wrapper := FileAccess.get_file_as_string(WRAPPER_PATH)
	_expect(not tool.is_empty() and not wrapper.is_empty(), "replay tool and parent wrapper exist")
	_expect(tool.contains('preload("res://scenes/main.tscn")') \
			and tool.contains("const FIXED_SEED := 900626424") \
			and tool.contains("const FIXED_CHALLENGE_DEPTH := 1") \
			and tool.contains("const FIXED_LOCAL_PLAYER_COUNT := 1") \
			and tool.contains("const FIXED_AI_PLAYER_COUNT := 3"), "replay pins the V7 production composition and setup")
	_expect(tool.contains("const TARGET_OWNER_INDEX := 7") \
			and tool.contains('const TARGET_SECTION_ID := "card_inventory"') \
			and tool.contains('const TARGET_OWNER_ID := "card_inventory"'), "replay pins only the attested Card Inventory row")
	_expect(tool.contains("SCENARIO_IDENTITY.validation_report") \
			and tool.contains("REGISTRY_VALIDATOR.validate(contract, registry, 19)") \
			and tool.contains('registry.call("registry_binding_contract_v1")'), "scenario identity and canonical Registry binding are attested")
	_expect(tool.contains('owner.call("to_save_data")') \
			and tool.contains('owner.call("capture_runtime_checkpoint")') \
			and tool.contains('owner.call("restore_runtime_checkpoint", checkpoint_a)'), "only the real composite Owner Save and checkpoint APIs are exercised")
	_expect(tool.contains("INSPECTOR.inspect(save_a") \
			and tool.contains("INSPECTOR.inspect(checkpoint_a") \
			and tool.contains("WIRE.is_closed_data(save_a)") \
			and tool.contains("WIRE.is_closed_data(checkpoint_a)"), "both payloads use the production closed-data validator")
	_expect(tool.contains('handshake.call("encode_codec_value", save_a)') \
			and tool.contains("JSON.parse_string(JSON.stringify") \
			and tool.contains('handshake.call("decode_codec_value"'), "persistent Save uses the unchanged production Envelope codec at JSON boundary")
	_expect(not tool.contains("capture_all_sections_detailed") \
			and not tool.contains("capture_resume_envelope") \
			and not tool.contains("preflight_envelope") \
			and not tool.contains("apply_envelope"), "replay cannot execute a full Registry Owner audit or restore")
	_expect(not tool.contains("targeted_owner_capture_diagnostic_v2") \
			and not tool.contains("cold_restore_vertical_slice_orchestrator") \
			and not tool.contains("authorization_id") \
			and not tool.contains("quota_ledger"), "replay cannot create or consume diagnostic authorization")
	_expect(tool.contains('output_path.contains("current_run.save")') \
			and not tool.contains("write_validated_envelope") \
			and not tool.contains("request_save"), "replay has no production Save-file write path")
	_expect(not tool.contains("official_attempt") \
			and not tool.contains("process_a_rehearsal") \
			and not tool.contains("create_v8"), "replay records V8 absence without launching official workflows")
	_expect(tool.contains('"v8_run_id_created": false') \
			and tool.contains('"replay_diagnostic_count_delta": 0') \
			and tool.contains('"replay_quota_claim_count": 0') \
			and tool.contains('"replay_full_owner_audit_count": 0') \
			and tool.contains('"replay_production_fixed_slot_write_count": 0'), "result envelope records every nonconsumption counter")
	_expect(tool.contains('"v7_historical_registry_owner_capture": "7/19"') \
			and not tool.contains('"v7_historical_registry_owner_capture": "19/19"'), "immutable V7 remains 7/19")
	_expect(tool.contains("save_capture_mutation_count") \
			and tool.contains("checkpoint_capture_mutation_count") \
			and tool.contains("capture_rng_draw_delta") \
			and tool.contains("capture_world_time_delta") \
			and tool.contains("capture_public_log_delta"), "capture side effects are explicitly measured")
	_expect(wrapper.contains('$startInfo.Environment["APPDATA"] = $appData') \
			and wrapper.contains('$startInfo.Environment["LOCALAPPDATA"] = $localAppData') \
			and wrapper.contains("CreateNoWindow = $true"), "parent gives the replay isolated hidden-process user data")
	_expect(_occurrences(wrapper, "res://scripts/tools/alpha04c_v7_card_inventory_nonconsuming_replay.gd") == 1, "parent names the replay entry exactly once")
	_expect(wrapper.contains("replay_evidence_already_exists") \
			and wrapper.contains("Get-DirectoryAttestation -Root $v7Root") \
			and wrapper.contains("immutable_v7_evidence_preserved"), "parent enforces a unique run and immutable V7 tree")
	_expect(wrapper.contains("607f1a15d875321a368ab071b35693857d7acf32063b4ed5578fa4f4aea9f826") \
			and wrapper.contains("eba66bdf8edc55071b862a6b1c9d1ab8073d130335408bcf76be9c373538b778") \
			and wrapper.contains("ExpectedV7FileCount = 107") \
			and wrapper.contains("ExpectedV7ByteCount = [int64]271918"), "parent pins the retained V7 ledger, failure phase, and tree size")
	_expect(wrapper.contains("task_owned_process_count_after") \
			and wrapper.contains("replay_full_owner_audit_count = 0") \
			and wrapper.contains("replay_process_a_count = 0"), "parent attests child exit and forbidden workflow counts")
	_expect(not wrapper.contains("current_run.save") \
			and not wrapper.contains("targeted_owner_capture_diagnostic_v2") \
			and not wrapper.contains("process_a_rehearsal"), "parent cannot redirect into fixed Save or official diagnostic workflows")
	_finish()


func _occurrences(source: String, needle: String) -> int:
	if needle.is_empty():
		return 0
	return source.split(needle, false).size() - 1


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("V7_CARD_INVENTORY_NONCONSUMING_REPLAY_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("V7 Card Inventory replay contract failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
