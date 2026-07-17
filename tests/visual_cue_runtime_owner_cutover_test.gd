extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const OWNER_SCENE := preload("res://scenes/runtime/VisualCueRuntimeOwner.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := OWNER_SCENE.instantiate() as VisualCueRuntimeOwner
	root.add_child(owner)
	owner.configure_world_bounds(100.0, 80.0)
	owner.add_visual_trail(Vector2(95, 75), Vector2(105, 85), Color.WHITE, "move", 2.0)
	owner.add_action_callout("actor", "攻击", "公开伤害", Color.RED, Vector2(105, 85), 3.0)
	owner.add_map_event_effect("impact", Vector2(-5, -5), Color.ORANGE, "abcdefghijk", 4.0, 60.0)
	owner.add_monster_attack_effect(Vector2(10, 10), Vector2(20, 20), "激光", 300.0, Color.CYAN, false)
	owner.pulse_district(0, Color.YELLOW, 2.0)
	var snapshot := owner.public_snapshot()
	_expect((snapshot.get("movement_trails", []) as Array).size() == 1, "owner stores one movement trail")
	_expect((snapshot.get("action_callouts", []) as Array).size() == 1, "owner stores one action callout")
	_expect((snapshot.get("map_event_effects", []) as Array).size() == 2, "owner stores map and attack effects")
	var trail := (snapshot.get("movement_trails", []) as Array)[0] as Dictionary
	_expect(trail.get("to", Vector2.ZERO) == Vector2(5, 5), "visual positions use configured spherical wrap bounds")
	var attack := (snapshot.get("map_event_effects", []) as Array)[1] as Dictionary
	_expect(str(attack.get("kind", "")) == "laser", "ranged monster source selects the differentiated laser effect")

	var authoritative_districts := [{"region_id": "region.000", "name": "A", "hp": 10}]
	var presented := owner.districts_with_pulses(authoritative_districts)
	_expect(not (authoritative_districts[0] as Dictionary).has("pulse"), "authoritative district data does not contain transient pulse state")
	_expect(float((presented[0] as Dictionary).get("pulse", 0.0)) > 0.0, "presentation copy overlays the district pulse")
	owner.advance(2.5)
	var aged := owner.public_snapshot()
	_expect((aged.get("movement_trails", []) as Array).is_empty(), "expired trails are removed")
	_expect((aged.get("district_pulses", {}) as Dictionary).is_empty(), "expired district pulses are removed")
	_expect((aged.get("action_callouts", []) as Array).size() == 1, "longer callout remains after shorter cue expiry")

	var legacy_districts := [{"pulse": 1.5, "pulse_color": Color.GREEN, "city": {}}]
	var legacy_receipt := owner.import_legacy_state({
		"movement_trails": [{"life": 1.0}],
		"action_callouts": [{"life": 1.0}],
		"map_event_effects": [{"life": 1.0}],
	}, legacy_districts)
	_expect(bool(legacy_receipt.get("imported", false)), "legacy transient presentation state has an explicit one-way import")
	_expect(not (legacy_districts[0] as Dictionary).has("pulse") and not (legacy_districts[0] as Dictionary).has("pulse_color"), "legacy pulse fields are removed from authoritative districts during migration")
	_expect((owner.public_snapshot().get("district_pulses", {}) as Dictionary).size() == 1, "legacy pulse continues only in the transient owner")
	owner.reset_state()
	_expect((owner.public_snapshot().get("action_callouts", []) as Array).is_empty(), "new-session reset clears all transient cues")

	var debug_text := JSON.stringify(owner.debug_snapshot())
	for forbidden in ["actor", "detail", "cash", "hand", "owner_player", "hidden"]:
		_expect(not debug_text.contains(forbidden), "visual debug omits payload field %s" % forbidden)
	var main_source := FileAccess.get_file_as_string("res://scripts/%s.gd" % "main")
	_expect(not main_source.contains("var movement_trails") and not main_source.contains("var action_callouts") and not main_source.contains("var map_event_effects"), "Main no longer stores transient visual arrays")
	_expect(not main_source.contains("func _update_visual_cues") and not main_source.contains("func _pulse_district"), "Main no longer owns visual ageing or district pulses")
	for controller_path in [
		"res://scripts/runtime/monster_runtime_controller.gd",
		"res://scripts/runtime/military_runtime_controller.gd",
		"res://scripts/runtime/weather_runtime_controller.gd",
		"res://scripts/runtime/ai_runtime_controller.gd",
	]:
		var source := FileAccess.get_file_as_string(controller_path)
		_expect(not source.contains("_world_call(&\"_add_action_callout\"") and not source.contains("_world_call(&\"_add_visual_trail\"") and not source.contains("_world_call(&\"_add_monster_attack_effect\""), "%s has no visual callback to Main" % controller_path.get_file())

	var main := MAIN_SCENE.instantiate()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(main)
	await process_frame
	_expect(main.find_children("VisualCueRuntimeOwner", "VisualCueRuntimeOwner", true, false).size() == 1, "production scene has exactly one visual cue owner")
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
	if coordinator != null:
		coordinator.add_visual_action_callout("test", "卡牌", "public", Color.WHITE, Vector2.ZERO)
		_expect((coordinator.visual_cue_public_snapshot().get("action_callouts", []) as Array).size() == 1, "production coordinator routes visual producers to the owner")
	main.queue_free()
	owner.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Visual cue runtime owner cutover passed (%d checks)." % _checks)
		quit(0)
		return
	push_error("Visual cue runtime owner cutover failed:\n- " + "\n- ".join(_failures))
	quit(1)
