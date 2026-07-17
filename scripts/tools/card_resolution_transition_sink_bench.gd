extends Node

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	var coordinator := get_node_or_null("GameRuntimeCoordinator") as GameRuntimeCoordinator
	_expect(coordinator != null, "production GameRuntimeCoordinator loads")
	if coordinator != null:
		var sink := coordinator.get_node_or_null("CardResolutionTransitionSink")
		var driver := coordinator.get_node_or_null("CardResolutionFrameDriver")
		_expect(sink != null and driver != null, "production frame driver and transition sink are composed")
		_expect(coordinator.find_children("CardResolutionTransitionSink", "", true, false).size() == 1, "production composition has one transition sink")
		var first := coordinator.advance_card_resolution_frame(0.1)
		_expect(bool(first.get("handled", false)) and int(first.get("command_count", -1)) == 1, "production driver sends the initial hide command directly to the sink")
		var sink_debug: Dictionary = sink.debug_snapshot() if sink != null else {}
		_expect(bool(sink_debug.get("sole_frame_command_consumer", false)), "sink reports sole frame-command consumption")
		_expect(not bool(sink_debug.get("holds_main_reference", true)) and int(sink_debug.get("dynamic_main_access_count", -1)) == 0, "sink has no Main reference or dynamic Main access")
		var second := coordinator.advance_card_resolution_frame(0.1)
		_expect(bool(second.get("handled", false)) and int(second.get("command_count", -1)) == 0, "unchanged empty frame produces no duplicate hide command")
	var passed := _failures.is_empty()
	print("CARD_RESOLUTION_TRANSITION_SINK_BENCH %s %d/%d" % ["PASS" if passed else "FAIL", _checks - _failures.size(), _checks])
	for failure in _failures:
		push_error(failure)
	get_tree().quit(0 if passed else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
