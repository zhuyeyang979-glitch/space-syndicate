@tool
extends Node

class FakeTransitionSink extends CardResolutionTransitionSink:
	var applied := 0

	func apply_transition_batch(commands: Array) -> Dictionary:
		applied += commands.size()
		return {"handled": true, "reason": "", "command_count": commands.size()}


var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var pipeline := $RuntimeCommandPipeline as RuntimeCommandPipeline
	var sink := FakeTransitionSink.new()
	add_child(sink)
	pipeline.bind_card_transition_sink(sink)
	var commands := [
		_command(11, 0, "show_active"),
		_command(11, 1, "complete_active"),
	]
	var receipt := pipeline.dispatch_card_transition_batch(commands)
	_check(bool(receipt.get("handled", false)), "real scene-owned pipeline accepts a typed command batch")
	_check(int(receipt.get("command_count", -1)) == 2, "batch receipt preserves command count")
	_check(sink.applied == 2, "bound domain sink applies each payload once")
	_check((receipt.get("command_trace", []) as Array).size() == 2, "pipeline emits a two-entry deterministic trace")
	_check(not bool(pipeline.debug_snapshot().get("global_bus", true)), "scene pipeline is local, not a global bus")
	print("CommandPipelineBoundaryHardeningBench: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		push_error("\n- ".join(_failures))
	# Keep the Bench alive briefly so editor/MCP validation can inspect the same
	# runtime output before the deterministic QA scene closes itself.
	await get_tree().create_timer(5.0).timeout
	get_tree().quit(0 if _failures.is_empty() else 1)


func _command(revision: int, order_index: int, transition: String) -> Dictionary:
	return {
		"command_schema_version": 1,
		"command_id": "bench:%d:%d:%s" % [revision, order_index, transition],
		"command_fingerprint": "bench-payload:%d:%d:%s" % [revision, order_index, transition],
		"transition": transition,
		"batch_revision": revision,
		"revision": revision,
		"order_index": order_index,
	}


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
