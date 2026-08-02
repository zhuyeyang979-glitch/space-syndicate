extends SceneTree

const FIXTURE := preload("res://tests/fixtures/card_resolution_execution_save_full_state_fixture.gd")
const SAVE_CODEC := preload("res://scripts/runtime/card_resolution_execution_save_wire_codec_v4.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := FIXTURE.create(self)
	var owner := fixture.get("execution") as CardResolutionExecutionRuntimeService
	var save := owner.to_save_data()
	var decoded := SAVE_CODEC.decode_save_state(save)
	var runtime := decoded.get("value", {}) as Dictionary
	_expect(bool(decoded.get("ok", false)) and int(runtime.get("schema_version", -1)) == 4, "Execution persistent Save schema is v4")
	_expect(int(runtime.get("execution_wire_version", -1)) == 1 and str(runtime.get("ruleset_id", "")) == "v0.6", "Execution wire and production ruleset identities are explicit")
	_expect(int(((runtime.get("transition_controller", {}) as Dictionary).get("transition_state_wire_version", -1))) == 2, "nested Transition state wire is v2")
	_expect(owner.preflight_save_data(save).get("normalized_state") == save, "strict preflight returns the canonical v4 wire without field loss")
	_expect(not str(save.get("execution_wire_fingerprint", "")).is_empty(), "Execution wire owns a canonical fingerprint")

	var registry_source := FileAccess.get_file_as_string("res://scenes/runtime/V06SaveOwnerRegistry.tscn")
	var binding_block := _block(registry_source, "[sub_resource type=\"Resource\" id=\"BindingCardExecution\"]")
	_expect(registry_source.count('section_id = "') == 19 \
			and registry_source.count('owner_id = "card_resolution_execution"') == 1, "Registry keeps 19 sections and one Execution owner")
	_expect(binding_block.contains("state_version = 2") \
			and binding_block.contains('capture_method = "to_save_data"') \
			and binding_block.contains('preflight_method = "preflight_save_data"') \
			and binding_block.contains('apply_method = "apply_save_data"') \
			and binding_block.contains('rollback_method = "apply_save_data"') \
			and not binding_block.contains("checkpoint_method ="), "Execution binding is state v2 with registry-managed checkpoint semantics")
	var version_source := FileAccess.get_file_as_string("res://resources/rules/controller_state_version_registry_v06.tres")
	var version_block := _block(version_source, "controller_id = \"card_resolution_execution\"")
	_expect(version_block.contains("state_version = 2"), "controller state-version registry also declares Execution state v2")
	_expect(not owner.has_method("capture_runtime_checkpoint") and not owner.has_method("restore_runtime_checkpoint"), "Execution does not add a second checkpoint representation")

	var malformed := save.duplicate(true)
	malformed["unknown_execution_field"] = true
	_expect(not bool(owner.preflight_save_data(malformed).get("accepted", true)), "unknown top-level Save fields fail closed")
	var before := owner.to_save_data()
	_expect(not bool(owner.apply_save_data(malformed).get("applied", true)) and owner.to_save_data() == before, "shape failure mutates neither Execution nor Transition state")

	FIXTURE.cleanup(fixture)
	await process_frame
	print("CARD_RESOLUTION_EXECUTION_SAVE_V4_TEST|status=%s|checks=%d|failures=%d|sections=19|owners=1" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()
	])
	if not _failures.is_empty():
		push_error("Execution Save v4 contract failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _block(source: String, marker: String) -> String:
	var start := source.find(marker)
	if start < 0:
		return ""
	var next := source.find("\n[", start + marker.length())
	return source.substr(start) if next < 0 else source.substr(start, next - start)
