extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const DRIVER_SCENE := preload("res://scenes/runtime/CardResolutionFrameDriver.tscn")
const CONTROLLER_SCENE := preload("res://scenes/runtime/CardResolutionRuntimeController.tscn")
const QUEUE_SCENE := preload("res://scenes/runtime/CardResolutionQueueRuntimeService.tscn")
const WORLD_SCENE := preload("res://scenes/runtime/WorldSessionState.tscn")
const ELIGIBILITY_SCENE := preload("res://scenes/runtime/CardPlayEligibilityRuntimeService.tscn")

const EXPECTED_TRANSITIONS := [
	"show_active",
	"begin_counter",
	"complete_active",
	"start_next",
	"show_group_window",
	"enter_public_bid",
	"enter_lock",
	"all_ready_public_bid",
	"all_ready_lock",
	"all_ready_lock_batch",
	"lock_batch",
	"hide_overlay",
]


class FakeTransitionSink extends CardResolutionTransitionSink:
	var batches: Array = []
	var observed_transitions: Dictionary = {}

	func apply_transition_batch(commands: Array) -> Dictionary:
		var copied_commands := commands.duplicate(true)
		batches.append(copied_commands)
		var trace: Array[String] = []
		var receipts: Array = []
		for command_variant in copied_commands:
			if not (command_variant is Dictionary):
				continue
			var command := command_variant as Dictionary
			var transition := str(command.get("transition", ""))
			trace.append(transition)
			observed_transitions[transition] = true
			receipts.append({
				"handled": true,
				"command_id": str(command.get("command_id", "")),
				"transition": transition,
			})
		return {
			"handled": true,
			"reason": "",
			"command_count": copied_commands.size(),
			"receipts": receipts,
			"trace": trace,
		}


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var driver := DRIVER_SCENE.instantiate() as CardResolutionFrameDriver
	var controller := CONTROLLER_SCENE.instantiate() as CardResolutionRuntimeController
	var queue := QUEUE_SCENE.instantiate() as CardResolutionQueueRuntimeService
	var world := WORLD_SCENE.instantiate() as WorldSessionState
	var eligibility := ELIGIBILITY_SCENE.instantiate() as CardPlayEligibilityRuntimeService
	var sink := FakeTransitionSink.new()
	for node in [driver, controller, queue, world, eligibility, sink]:
		root.add_child(node)
	world.replace_players([
		{"public_name": "local"},
		{"public_name": "out", "eliminated": true},
		{"public_name": "rival"},
	], true)
	var command_pipeline := RuntimeCommandPipeline.new()
	root.add_child(command_pipeline)
	command_pipeline.bind_card_transition_sink(sink)
	driver.configure(controller, queue, world, eligibility, command_pipeline)

	_expect_advance(driver, sink, 0.25, ["hide_overlay"], "empty queue")
	_expect_advance(driver, sink, 0.25, [], "unchanged empty queue")
	_expect(driver.facts_snapshot().get("active_player_indices", []) == [0, 2], "facts exclude eliminated seats without exposing player payloads")

	queue.replace_active_entry({
		"resolution_id": 7,
		"skill": {"kind": "player_hand_disrupt", "name": "public interaction"},
	})
	controller.begin_active_display(1.0)
	_expect_advance(driver, sink, 1.0, ["show_active", "begin_counter"], "counterable reveal")
	_expect(bool(driver.facts_snapshot().get("active_counterable", false)), "field-driven eligibility marks public player interaction counterable")
	_expect_advance(driver, sink, controller.counter_seconds, ["show_active", "complete_active"], "counter expiry")

	queue.replace_active_entry({})
	queue.replace_current_queue([{"resolution_id": 9, "skill": {"kind": "public_facility"}}])
	controller.reset_state()
	controller.batch_locked = true
	_expect_advance(driver, sink, 0.0, ["start_next"], "locked batch")

	controller.reset_state()
	controller.begin_group_window(-1.0, 0, 3)
	_expect_advance(driver, sink, 0.0, ["show_group_window"], "planning window")

	controller.reset_state()
	controller.begin_group_window(-1.0, 0, 3)
	_expect_advance(driver, sink, 60.0, ["enter_public_bid", "enter_lock", "show_group_window", "lock_batch"], "large delta window close")

	controller.reset_state()
	controller.begin_group_window(-1.0, 0, 3)
	_set_all_ready(controller, [0, 2])
	_expect_advance(driver, sink, 0.0, ["all_ready_public_bid", "enter_public_bid", "show_group_window"], "all ready planning")
	_set_all_ready(controller, [0, 2])
	_expect_advance(driver, sink, 0.0, ["all_ready_lock", "enter_lock", "show_group_window"], "all ready public bid")
	_set_all_ready(controller, [0, 2])
	_expect_advance(driver, sink, 0.0, ["all_ready_lock_batch", "lock_batch"], "all ready lock")

	for transition in EXPECTED_TRANSITIONS:
		_expect(sink.observed_transitions.has(transition), "transition %s is consumed inside the sink" % transition)
	_expect(sink.observed_transitions.size() == EXPECTED_TRANSITIONS.size(), "sink consumes exactly the twelve frame-command kinds")

	var debug_snapshot := driver.debug_snapshot()
	var debug_text := JSON.stringify(debug_snapshot)
	for forbidden in ["players", "cash", "hand", "skill", "owner", "hidden"]:
		_expect(not debug_text.contains(forbidden), "driver debug omits private field %s" % forbidden)
	_expect(bool(debug_snapshot.get("command_pipeline_ready", false)), "driver configuration requires the explicit command pipeline")
	_expect(not bool(debug_snapshot.get("returns_commands_to_main", true)), "driver reports that commands never leave through a legacy consumer")
	_expect(int(debug_snapshot.get("tick_count", -1)) == 10, "driver records exactly one controller tick per advance call")

	var driver_source := FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_frame_driver.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	_expect(driver_source.contains("command_pipeline: RuntimeCommandPipeline"), "FrameDriver.configure explicitly requires the typed command pipeline")
	_expect(driver_source.contains("func advance_world(delta: float) -> Dictionary"), "FrameDriver returns a high-level Dictionary receipt")
	_expect(not driver_source.contains("func advance_world(delta: float) -> Array"), "FrameDriver no longer returns a raw command Array")
	_expect(coordinator_source.contains("func advance_card_resolution_frame(delta: float) -> Dictionary"), "coordinator forwards the high-level frame receipt")
	_expect(not driver_source.contains("current_scene") and not driver_source.contains("Callable"), "driver has no scene-locator or callback fallback")

	var coordinator := COORDINATOR_SCENE.instantiate()
	root.add_child(coordinator)
	_expect(coordinator.get_node_or_null("CardResolutionFrameDriver") != null, "production coordinator owns the frame driver")
	_expect(coordinator.get_node_or_null("CardResolutionTransitionSink") != null, "production coordinator owns the transition sink")
	_expect(coordinator.get_node_or_null("RuntimeCommandPipeline") != null, "production coordinator owns the command pipeline")
	_expect(coordinator.find_children("CardResolutionFrameDriver", "CardResolutionFrameDriver", true, false).size() == 1, "production coordinator has exactly one card frame driver")
	_expect(coordinator.find_children("CardResolutionTransitionSink", "CardResolutionTransitionSink", true, false).size() == 1, "production coordinator has exactly one transition sink")
	coordinator.queue_free()

	for node in [driver, controller, queue, world, eligibility, sink, command_pipeline]:
		node.queue_free()
	await process_frame
	_finish()


func _expect_advance(
	driver: CardResolutionFrameDriver,
	sink: FakeTransitionSink,
	delta: float,
	expected_transitions: Array,
	label: String
) -> void:
	var batch_count_before := sink.batches.size()
	var receipt_variant: Variant = driver.advance_world(delta)
	_expect(receipt_variant is Dictionary, "%s returns a high-level Dictionary receipt" % label)
	if not (receipt_variant is Dictionary):
		return
	var receipt := receipt_variant as Dictionary
	_expect(bool(receipt.get("handled", false)), "%s receipt is handled by the sink" % label)
	_expect(not receipt.has("commands"), "%s receipt does not expose the raw command Array" % label)
	_expect(int(receipt.get("command_count", -1)) == expected_transitions.size(), "%s reports the consumed command count" % label)
	_expect(receipt.get("sink_receipt", {}) is Dictionary, "%s contains a typed sink receipt" % label)
	_expect(sink.batches.size() == batch_count_before + 1, "%s reaches the sink exactly once" % label)
	if sink.batches.size() == batch_count_before + 1:
		_expect(_transition_names(sink.batches[-1]) == expected_transitions, "%s commands are consumed by the sink in producer order" % label)


func _set_all_ready(controller: CardResolutionRuntimeController, player_indices: Array) -> void:
	for player_index_variant in player_indices:
		controller.set_player_ready(int(player_index_variant), true, player_indices)


func _transition_names(commands: Array) -> Array[String]:
	var result: Array[String] = []
	for command_variant in commands:
		if command_variant is Dictionary:
			result.append(str((command_variant as Dictionary).get("transition", "")))
	return result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Card resolution frame-driver cutover passed (%d checks)." % _checks)
		quit(0)
		return
	push_error("Card resolution frame-driver cutover failed:\n- " + "\n- ".join(_failures))
	quit(1)
