extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const COOLDOWN_SCENE := preload("res://scenes/runtime/CardCooldownRuntimeController.tscn")
const WORLD_SCENE := preload("res://scenes/runtime/WorldSessionState.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var controller := COOLDOWN_SCENE.instantiate() as CardCooldownRuntimeController
	var world := WORLD_SCENE.instantiate() as WorldSessionState
	root.add_child(controller)
	root.add_child(world)
	world.replace_players(_fixture_players(), true)
	controller.configure(world)

	var receipt := controller.advance_world(2.0)
	var first := world.players[0] as Dictionary
	var first_slot := (first.get("slots", []) as Array)[0] as Dictionary
	var eliminated := world.players[1] as Dictionary
	_expect(bool(receipt.get("advanced", false)), "world delta advances through the cooldown owner")
	_expect(is_equal_approx(float(first.get("action_cooldown", -1.0)), 3.0), "player action cooldown decays by world delta")
	_expect(is_equal_approx(float(first_slot.get("cooldown_left", -1.0)), 4.0) and is_equal_approx(float(first_slot.get("lock_left", -1.0)), 2.0), "persistent card cooldown and lock decay together")
	_expect(is_equal_approx(float(eliminated.get("action_cooldown", -1.0)), 1.0), "eliminated seats retain deterministic cooldown state progression")
	_expect((first.get("slots", []) as Array)[1] == null, "null hand slots remain untouched")

	var fragmented_controller := COOLDOWN_SCENE.instantiate() as CardCooldownRuntimeController
	var fragmented_world := WORLD_SCENE.instantiate() as WorldSessionState
	root.add_child(fragmented_controller)
	root.add_child(fragmented_world)
	fragmented_world.replace_players(_fixture_players(), true)
	fragmented_controller.configure(fragmented_world)
	fragmented_controller.advance_world(0.75)
	fragmented_controller.advance_world(1.25)
	_expect(fragmented_world.internal_snapshot() == world.internal_snapshot(), "fragmented and large world deltas produce the same state")

	var arm_low := controller.arm_player_action(0, 1.0)
	var arm_high := controller.arm_player_action(0, 8.0)
	_expect(bool(arm_low.get("armed", false)) and not bool(arm_low.get("changed", true)), "arming never shortens an existing action cooldown")
	_expect(bool(arm_high.get("changed", false)) and is_equal_approx(float((world.players[0] as Dictionary).get("action_cooldown", 0.0)), 8.0), "arming extends action cooldown through the owner")
	var mismatch := controller.arm_persistent_card(0, 0, "wrong-instance", 20.0)
	_expect(not bool(mismatch.get("armed", true)) and str(mismatch.get("reason", "")) == "runtime_instance_mismatch", "persistent cooldown rejects stale card identity")
	var matching := controller.arm_persistent_card(0, 0, "card-a", 20.0)
	_expect(bool(matching.get("armed", false)) and is_equal_approx(float(((world.players[0] as Dictionary).get("slots", []) as Array)[0].get("cooldown_left", 0.0)), 20.0), "persistent cooldown binds to the authoritative runtime card instance")

	controller.advance_world(10000.0)
	_expect(is_equal_approx(float((world.players[0] as Dictionary).get("action_cooldown", -1.0)), 0.0), "cooldowns clamp at zero")
	_expect(is_equal_approx(float(((world.players[0] as Dictionary).get("slots", []) as Array)[2].get("lock_left", -1.0)), 0.0), "long lock values use the same linear clock and clamp")

	var saved := world.to_save_data()
	var restored := WORLD_SCENE.instantiate() as WorldSessionState
	root.add_child(restored)
	_expect(bool(restored.apply_save_data(saved).get("applied", false)), "existing WorldSessionState remains the only save owner")
	_expect(restored.internal_snapshot() == world.internal_snapshot(), "cooldown state roundtrips without a second save schema")

	var debug_text := JSON.stringify(controller.debug_snapshot())
	for forbidden in ["players", "slots", "cash", "hand", "runtime_instance_id"]:
		_expect(not debug_text.contains(forbidden), "cooldown debug omits private field %s" % forbidden)
	var main_source := FileAccess.get_file_as_string("res://scripts/%s.gd" % "main")
	var source := FileAccess.get_file_as_string("res://scripts/runtime/card_cooldown_runtime_controller.gd")
	_expect(not main_source.contains("func _update_realtime_cooldowns"), "Main no longer owns realtime card cooldown decay")
	_expect(not main_source.contains("[\"action_cooldown\"] = max"), "Main no longer arms action cooldown by direct mutation")
	_expect(not source.contains("Main") and not source.contains("current_scene") and not source.contains("Callable"), "cooldown owner has no Main callback or scene locator")

	var main := MAIN_SCENE.instantiate()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(main)
	await process_frame
	_expect(main.find_children("CardCooldownRuntimeController", "CardCooldownRuntimeController", true, false).size() == 1, "production scene has exactly one card cooldown owner")
	main.queue_free()
	for node in [controller, world, fragmented_controller, fragmented_world, restored]:
		node.queue_free()
	await process_frame
	_finish()


func _fixture_players() -> Array:
	return [
		{
			"action_cooldown": 5.0,
			"slots": [
				{"runtime_instance_id": "card-a", "cooldown_left": 6.0, "lock_left": 4.0},
				null,
				{"runtime_instance_id": "card-b", "cooldown_left": 0.0, "lock_left": 9999.0},
			],
		},
		{"eliminated": true, "action_cooldown": 3.0, "slots": []},
	]


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Card cooldown owner cutover passed (%d checks)." % _checks)
		quit(0)
		return
	push_error("Card cooldown owner cutover failed:\n- " + "\n- ".join(_failures))
	quit(1)
