extends SceneTree

const TOOL_PATH := "res://scripts/tools/alpha04c_remaining_owner_closed_data_preflight.gd"
const WRAPPER_PATH := "res://scripts/tools/run_alpha04c_remaining_owner_closed_data_preflight.ps1"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var tool := FileAccess.get_file_as_string(TOOL_PATH)
	var wrapper := FileAccess.get_file_as_string(WRAPPER_PATH)
	_expect(not tool.is_empty() and not wrapper.is_empty(), "preflight tool and wrapper exist")
	_expect(tool.contains("const FIRST_OWNER_INDEX := 8") \
			and tool.contains("const LAST_OWNER_INDEX := 18") \
			and tool.contains("const EXPECTED_OWNER_COUNT := 11"), "only remaining Owner indexes are selected")
	_expect(tool.contains('preload("res://scenes/main.tscn")') \
			and tool.contains('session.get_node_or_null("V06SaveOwnerRegistry")') \
			and tool.contains('registry.call("registry_binding_contract_v1")'), "real production composition and Registry are used")
	_expect(tool.contains("INSPECTOR.inspect(payload_variant)") \
			and tool.contains("WIRE.is_closed_data(result)"), "strict SemanticWire inspection protects payloads and evidence")
	_expect(tool.contains("break") \
			and tool.contains("first_remaining_owner_failure_index"), "preflight stops at the first real failure")
	_expect(tool.contains("capture_mutation_count") \
			and tool.contains("rng_draw_delta") \
			and tool.contains("world_time_delta") \
			and tool.contains("public_log_delta"), "capture side effects are measured")
	_expect(not tool.contains("capture_all_sections_detailed") \
			and not tool.contains("capture_resume_envelope") \
			and not tool.contains("request_save"), "preflight cannot become a full audit or Save")
	_expect(not tool.contains("_is_owner_codec_data") \
			and not tool.contains("cold_restore_vertical_slice_orchestrator"), "preflight cannot use the wide Registry predicate or launch V8")
	_expect(tool.contains('"preflight_diagnostic_count_delta": 0') \
			and tool.contains('"preflight_quota_claim_count": 0') \
			and tool.contains('"v8_authorization_created": false'), "nonconsumption and V8 absence are explicit")
	_expect(wrapper.contains("remaining_owner_preflight_remote_checkpoint_mismatch") \
			and wrapper.contains("v8_root_exists_before_authorization") \
			and wrapper.contains("v8_authorization_root_absent"), "wrapper freezes code and proves no V8 root")
	_expect(wrapper.contains("WaitForExit(120000)") \
			and wrapper.contains("Kill($true)"), "wrapper bounds and cleans its process tree")
	_expect(not wrapper.contains("targeted_owner_capture_diagnostic_v2") \
			and not wrapper.contains("process_a_rehearsal_completion_v1"), "wrapper cannot launch diagnostics or Process A")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("ALPHA04C_REMAINING_OWNER_PREFLIGHT_CONTRACT_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Remaining Owner preflight contract failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
