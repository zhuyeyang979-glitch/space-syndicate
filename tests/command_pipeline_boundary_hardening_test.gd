extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")


class FakeTransitionSink extends CardResolutionTransitionSink:
	var applied_batches: Array = []
	var mutation_count := 0

	func apply_transition_batch(commands: Array) -> Dictionary:
		applied_batches.append(commands.duplicate(true))
		mutation_count += commands.size()
		return {
			"handled": true,
			"reason": "",
			"command_count": commands.size(),
			"trace": _transition_names(commands),
		}

	func _transition_names(commands: Array) -> Array[String]:
		var result: Array[String] = []
		for value in commands:
			result.append(str((value as Dictionary).get("transition", "")))
		return result


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_architecture_gate()
	_test_ordered_deterministic_trace()
	_test_mutation_ownership()
	_test_replay_readiness()
	await _test_production_composition()
	print("command_pipeline_boundary_hardening_test: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		push_error("\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _test_architecture_gate() -> void:
	var loop_source := FileAccess.get_file_as_string("res://scripts/runtime/runtime_loop.gd")
	var phase_source := FileAccess.get_file_as_string("res://scripts/runtime/runtime_command_phase_coordinator.gd")
	var driver_source := FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_frame_driver.gd")
	var pipeline_source := FileAccess.get_file_as_string("res://scripts/runtime/runtime_command_pipeline.gd")
	var envelope_source := FileAccess.get_file_as_string("res://scripts/runtime/runtime_command_envelope.gd")
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	_check(not loop_source.contains("RuntimeCommandEnvelope") and not loop_source.contains("dispatch_card_transition_batch"), "RuntimeLoop creates and dispatches no gameplay command")
	_check(phase_source.contains("_card.advance_card_resolution_frame") and not phase_source.contains("cash") and not phase_source.contains("damage"), "command phase invokes the typed card port without gameplay rules")
	_check(driver_source.contains("_command_pipeline.dispatch_card_transition_batch(commands)"), "card frame commands enter the explicit command pipeline inside the command phase")
	_check(not driver_source.contains("apply_transition_batch"), "frame driver no longer bypasses the command boundary")
	_check(pipeline_source.contains("CardResolutionTransitionSink") and not pipeline_source.contains("current_scene") and not pipeline_source.contains("/root/"), "pipeline has one explicit typed sink and no service locator")
	_check(not pipeline_source.contains("func _process") and not pipeline_source.contains("func _physics_process"), "pipeline is not a second frame owner")
	_check(not pipeline_source.contains("cash") and not pipeline_source.contains("price_delta") and not pipeline_source.contains("auto_monsters"), "pipeline contains no gameplay formula or direct world field; typed command names remain data-only")
	_check(envelope_source.contains("command_contains_runtime_object") and not envelope_source.contains("Control") and not envelope_source.contains("CanvasItem"), "command envelope rejects runtime objects and owns no presentation type")
	_check(not project_source.contains("RuntimeCommandPipeline"), "command pipeline is not an autoload")
	for presentation_path in [
		"res://scripts/presentation/table_presentation_source_owner.gd",
		"res://scripts/presentation/table_presentation_refresh_port.gd",
	]:
		var source := FileAccess.get_file_as_string(presentation_path)
		_check(not source.contains("RuntimeCommandEnvelope") and not source.contains("RuntimeCommandPipeline"), "%s cannot create gameplay commands" % presentation_path.get_file())


func _test_ordered_deterministic_trace() -> void:
	var left := _harness()
	var right := _harness()
	var commands := _commands()
	var left_receipt := (left.pipeline as RuntimeCommandPipeline).dispatch_card_transition_batch(commands)
	var right_receipt := (right.pipeline as RuntimeCommandPipeline).dispatch_card_transition_batch(commands)
	_check(bool(left_receipt.get("handled", false)) and bool(right_receipt.get("handled", false)), "two independent command pipelines accept the same pure-data batch")
	_check(left_receipt.get("command_trace", []) == right_receipt.get("command_trace", []), "same command sequence produces the same deterministic trace")
	_check((left.sink as FakeTransitionSink).applied_batches[0] == commands, "sink receives payloads in authored order")
	_check(_trace_orders(left_receipt) == [0, 1, 2], "trace preserves contiguous command order")
	_check(not JSON.stringify(left_receipt.get("command_trace", [])).contains("delta"), "command dispatch is delta independent")
	_free_harness(left)
	_free_harness(right)


func _test_mutation_ownership() -> void:
	var harness := _harness()
	var pipeline := harness.pipeline as RuntimeCommandPipeline
	var sink := harness.sink as FakeTransitionSink
	_check(sink.mutation_count == 0, "domain sink starts with no mutation")
	var receipt := pipeline.dispatch_card_transition_batch(_commands())
	_check(bool(receipt.get("handled", false)) and sink.mutation_count == 3, "only the bound domain sink performs the requested mutation")
	var debug := pipeline.debug_snapshot()
	_check(not bool(debug.get("owns_world_state", true)) and not bool(debug.get("owns_gameplay_rules", true)), "command pipeline declares no world or rule ownership")
	_check(int(debug.get("pending_command_count", -1)) == 0 and not bool(debug.get("global_bus", true)), "pipeline is synchronous, local and not a global bus")
	var invalid := _commands()
	(invalid[0] as Dictionary)["runtime_object"] = Node.new()
	var rejected := pipeline.dispatch_card_transition_batch(invalid)
	_check(not bool(rejected.get("handled", true)) and sink.mutation_count == 3, "commands containing scene objects fail before domain mutation")
	(invalid[0] as Dictionary)["runtime_object"].free()
	_free_harness(harness)


func _test_replay_readiness() -> void:
	var commands := _commands()
	var envelopes: Array = []
	for command in commands:
		envelopes.append(RuntimeCommandEnvelope.from_card_transition(command))
	for envelope in envelopes:
		_check(bool(RuntimeCommandEnvelope.validate(envelope).get("valid", false)), "command envelope has a valid stable identity and type")
	var encoded := JSON.stringify(envelopes)
	var decoded: Variant = JSON.parse_string(encoded)
	_check(decoded is Array and (decoded as Array).size() == envelopes.size(), "command sequence is JSON serializable in principle")
	var decoded_identity_matches := decoded is Array and (decoded as Array).size() == envelopes.size()
	if decoded_identity_matches:
		for index in range(envelopes.size()):
			var expected: Dictionary = envelopes[index]
			var restored: Dictionary = (decoded as Array)[index]
			decoded_identity_matches = decoded_identity_matches \
				and str(restored.get("command_id", "")) == str(expected.get("command_id", "")) \
				and str(restored.get("command_type", "")) == str(expected.get("command_type", "")) \
				and int(restored.get("producer_revision", -1)) == int(expected.get("producer_revision", -1)) \
				and int(restored.get("order_index", -1)) == int(expected.get("order_index", -1))
	_check(decoded_identity_matches, "serialized command sequence restores stable identity, type and order")
	var rebuilt: Array = []
	for command in commands:
		rebuilt.append(RuntimeCommandEnvelope.from_card_transition(command))
	_check(rebuilt == envelopes, "rebuilding the same command sequence produces identical ids, types, order and fingerprints")
	var tampered := (envelopes[0] as Dictionary).duplicate(true)
	tampered["order_index"] = 8
	_check(str(RuntimeCommandEnvelope.validate(tampered).get("reason", "")) == "command_payload_binding_mismatch", "tampered ordering fails the stable payload binding")


func _test_production_composition() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate()
	root.add_child(coordinator)
	await process_frame
	var pipelines := coordinator.find_children("RuntimeCommandPipeline", "RuntimeCommandPipeline", true, false)
	_check(pipelines.size() == 1, "production coordinator composes exactly one RuntimeCommandPipeline")
	var pipeline := pipelines[0] as RuntimeCommandPipeline if pipelines.size() == 1 else null
	_check(pipeline != null and pipeline.is_ready(), "production command pipeline binds the real transition sink")
	_check(coordinator.find_children("RuntimeLoop", "RuntimeLoop", true, false).size() == 1, "RuntimeLoop remains the unique production frame owner")
	coordinator.queue_free()
	await process_frame


func _commands() -> Array:
	return [
		_command(3, 0, "show_active"),
		_command(3, 1, "begin_counter"),
		_command(3, 2, "complete_active"),
	]


func _command(revision: int, order_index: int, transition: String) -> Dictionary:
	var payload := {
		"command_schema_version": 1,
		"transition": transition,
		"batch_revision": revision,
		"revision": revision,
		"order_index": order_index,
		"phase": "reveal",
		"command_fingerprint": "payload-%d-%d-%s" % [revision, order_index, transition],
	}
	payload["command_id"] = "transition:%d:%d:%s" % [revision, order_index, transition]
	return payload


func _trace_orders(receipt: Dictionary) -> Array:
	var result: Array = []
	for value in receipt.get("command_trace", []):
		result.append(int((value as Dictionary).get("order_index", -1)))
	return result


func _harness() -> Dictionary:
	var sink := FakeTransitionSink.new()
	var pipeline := RuntimeCommandPipeline.new()
	root.add_child(sink)
	root.add_child(pipeline)
	pipeline.bind_card_transition_sink(sink)
	return {"sink": sink, "pipeline": pipeline}


func _free_harness(harness: Dictionary) -> void:
	(harness.pipeline as RuntimeCommandPipeline).free()
	(harness.sink as FakeTransitionSink).free()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
