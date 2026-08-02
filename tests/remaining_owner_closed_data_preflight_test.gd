extends SceneTree

const INSPECTOR := preload("res://scripts/tools/remaining_owner_closed_data_inspector_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var closed := INSPECTOR.inspect({
		"schema_version": 1,
		"state_version": 1,
		"rows": [{"owner_id": "fixture", "ready": true, "sequence": 3}],
	})
	var raw_float := INSPECTOR.inspect({"state_version": 1, "timer": 1.25})
	_expect(bool(closed.get("closed_data", false)) \
			and int(closed.get("non_closed_leaf_count", -1)) == 0, "strict inspector accepts only closed SemanticWire data")
	_expect(not bool(raw_float.get("closed_data", true)) \
			and int(raw_float.get("non_closed_leaf_count", -1)) == 1 \
			and str(raw_float.get("first_non_closed_type", "")) == "float", "strict inspector rejects one raw float without coercion")
	_expect(str(raw_float.get("first_non_closed_path", "")).contains("<redacted:") \
			and not str(raw_float.get("first_non_closed_path", "")).contains("timer"), "private field names remain redacted")
	var child := FileAccess.get_file_as_string(
		"res://scripts/tools/alpha04c_remaining_index_14_18_owner_closed_data_preflight_v2.gd"
	)
	_expect(child.contains("const NEW_FIRST_OWNER_INDEX := 14") \
			and child.contains("const NEW_LAST_OWNER_INDEX := 18") \
			and child.contains("const NEW_EXPECTED_OWNER_COUNT := 5"), "only final five Registry bindings are selected")
	_expect(child.contains("_preflight_owner(context, registry, binding, owner_index, production_ruleset_id)") \
			and child.contains('"remaining_owner_capture_mutation_count": mutation_count'), "real owner capture and mutation evidence are mandatory")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("REMAINING_OWNER_CLOSED_DATA_PREFLIGHT_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size(),
	])
	if not _failures.is_empty():
		push_error("Remaining Owner closed-data preflight contract failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
