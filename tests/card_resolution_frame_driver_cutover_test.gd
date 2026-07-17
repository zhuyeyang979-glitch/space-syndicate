extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const DRIVER_SCENE := preload("res://scenes/runtime/CardResolutionFrameDriver.tscn")
const CONTROLLER_SCENE := preload("res://scenes/runtime/CardResolutionRuntimeController.tscn")
const QUEUE_SCENE := preload("res://scenes/runtime/CardResolutionQueueRuntimeService.tscn")
const WORLD_SCENE := preload("res://scenes/runtime/WorldSessionState.tscn")
const ELIGIBILITY_SCENE := preload("res://scenes/runtime/CardPlayEligibilityRuntimeService.tscn")

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
	for node in [driver, controller, queue, world, eligibility]:
		root.add_child(node)
	world.replace_players([
		{"public_name": "local"},
		{"public_name": "out", "eliminated": true},
		{"public_name": "rival"},
	], true)
	driver.configure(controller, queue, world, eligibility)

	_expect(_transitions(driver.advance_world(0.25)) == ["hide_overlay"], "empty queue emits the complete ordered hide command")
	_expect(driver.advance_world(0.25).is_empty(), "unchanged empty queue does not emit duplicate presentation work")
	_expect(driver.facts_snapshot().get("active_player_indices", []) == [0, 2], "facts exclude eliminated seats without exposing player payloads")

	queue.replace_active_entry({
		"resolution_id": 7,
		"skill": {"kind": "player_hand_disrupt", "name": "public interaction"},
	})
	controller.begin_active_display(1.0)
	_expect(_transitions(driver.advance_world(1.0)) == ["show_active", "begin_counter"], "counterable reveal emits the exact ordered transition pair")
	_expect(bool(driver.facts_snapshot().get("active_counterable", false)), "field-driven eligibility marks public player interaction counterable")
	_expect(_transitions(driver.advance_world(controller.counter_seconds)) == ["show_active", "complete_active"], "counter expiry emits show before completion")

	queue.replace_active_entry({
		"resolution_id": 8,
		"skill": {"kind": "phase_counter", "name": "counter card"},
	})
	controller.begin_active_display(0.5)
	_expect(not bool(driver.facts_snapshot().get("active_counterable", true)), "counter cards do not recursively open another counter window")
	_expect(_transitions(driver.advance_world(0.5)) == ["show_active", "complete_active"], "non-counterable reveal completes in one ordered frame")

	queue.replace_active_entry({})
	queue.replace_current_queue([{"resolution_id": 9, "skill": {"kind": "public_facility"}}])
	controller.reset_state()
	controller.begin_group_window(-1.0, 0, 0)
	_expect(_transitions(driver.advance_world(1.0)) == ["show_group_window"], "queued batch advances through the scene-owned frame driver")

	var debug_text := JSON.stringify(driver.debug_snapshot())
	for forbidden in ["players", "cash", "hand", "skill", "owner", "hidden"]:
		_expect(not debug_text.contains(forbidden), "driver debug omits private field %s" % forbidden)
	_expect(int(driver.debug_snapshot().get("tick_count", -1)) == 6, "driver records exactly one controller tick per advance call")

	var main_source := FileAccess.get_file_as_string("res://scripts/%s.gd" % "main")
	var driver_source := FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_frame_driver.gd")
	_expect(not main_source.contains("func _update_card_resolution_queue"), "Main no longer owns card-resolution frame ticking")
	_expect(not main_source.contains("func _card_resolution_controller_facts"), "Main no longer assembles card-resolution frame facts")
	_expect(not driver_source.contains("Main") and not driver_source.contains("current_scene") and not driver_source.contains("Callable"), "driver has no Main callback or scene locator")

	var main := MAIN_SCENE.instantiate()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(main)
	await process_frame
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	_expect(coordinator != null, "production main composes the runtime coordinator")
	if coordinator != null:
		_expect(coordinator.get_node_or_null("CardResolutionFrameDriver") != null, "production coordinator owns the frame driver")
		_expect(coordinator.get_node_or_null("CardResolutionRuntimeController") != null, "production coordinator owns the card timing controller")
	_expect(main.find_children("CardResolutionFrameDriver", "CardResolutionFrameDriver", true, false).size() == 1, "production scene has exactly one card frame driver")
	_expect(main.find_children("CardResolutionRuntimeController", "CardResolutionRuntimeController", true, false).size() == 1, "production scene has exactly one card timing controller")
	main.queue_free()

	for node in [driver, controller, queue, world, eligibility]:
		node.queue_free()
	await process_frame
	_finish()


func _transitions(commands: Array) -> Array[String]:
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
