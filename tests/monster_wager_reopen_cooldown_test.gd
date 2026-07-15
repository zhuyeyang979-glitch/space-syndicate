extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const SAVE_PATH := "GameSessionRuntimeController/GameSaveRuntimeCoordinator"
const MONSTER_PATH := "MonsterRuntimeController"
const SAVE_OVERRIDE := "user://test_runs/monster_wager_reopen_cooldown/run.save"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	var coordinator := main.get_node_or_null(COORDINATOR_PATH)
	var save_coordinator := coordinator.get_node_or_null(SAVE_PATH) if coordinator != null else null
	_expect(save_coordinator != null and bool(save_coordinator.call("set_qa_default_save_path_override", SAVE_OVERRIDE)), "QA save path is isolated before Main enters the tree")
	main.visible = false
	root.add_child(main)
	await _frames(8)

	main.set("configured_player_count", 4)
	main.set("configured_ai_player_count", 0)
	main.set("configured_role_indices", [0, 1, 2, 3])
	main.set("configured_starter_monster_indices", [0, 1, 2, 3])
	main.call("_new_game")
	main.set("opening_guide_dismissed", true)
	var monsters := coordinator.get_node_or_null(MONSTER_PATH) if coordinator != null else null
	_expect(monsters != null, "real MonsterRuntimeController is available through the Coordinator scene")

	var timing: Dictionary = main.call("_ruleset_timing_rules")
	var cooldown := float(timing.get("monster_wager_reopen_cooldown_seconds", -1.0))
	_expect(is_equal_approx(cooldown, 20.0), "ruleset owns a 20-second wager reopen cooldown")
	var district_index := maxi(0, int(main.get("selected_district")))
	var actor_a := monsters.call("_make_auto_monster", 0, 0, district_index, 0, 1) as Dictionary
	var actor_b := monsters.call("_make_auto_monster", 1, 1, district_index, 1, 1) as Dictionary
	actor_a["slot"] = 0
	actor_b["slot"] = 1
	actor_a["down"] = false
	actor_b["down"] = false
	monsters.set("auto_monsters", [actor_a, actor_b])
	monsters.set("active_monster_wagers", [])
	monsters.set("resolved_monster_wager_history", [])
	main.set("game_time", 100.0)

	var wager_id := int(monsters.call("_open_monster_wager_for_pair", 0, 1, "QA cooldown"))
	_expect(wager_id > 0, "first eligible monster wager opens")
	_expect(bool(monsters.call("_settle_monster_wager", wager_id, "QA cooldown settlement")), "wager settles into the existing owner history")
	var history: Array = monsters.get("resolved_monster_wager_history")
	_expect(history.size() == 1 and is_equal_approx(float((history[0] as Dictionary).get("resolved_at", -1.0)), 100.0), "settlement history records the authoritative reopen anchor")
	_expect(int(monsters.call("_open_monster_wager_for_pair", 0, 1, "QA immediate reopen")) == -1, "immediate serial wager is blocked")

	main.set("game_time", 100.0 + cooldown - 0.001)
	_expect(int(monsters.call("_open_monster_wager_for_pair", 0, 1, "QA boundary before")) == -1, "half-open cooldown remains active immediately before its boundary")
	main.set("game_time", 100.0 + cooldown)
	_expect(int(monsters.call("_open_monster_wager_for_pair", 0, 1, "QA boundary")) > wager_id, "a new wager may open exactly at the cooldown boundary")
	_expect(not (history[0] as Dictionary).has("reopen_cooldown_remaining"), "cooldown is derived from existing history without duplicate mutable state")

	if save_coordinator != null:
		save_coordinator.call("clear_qa_default_save_path_override")
	root.remove_child(main)
	main.free()
	await _frames(3)
	print("MONSTER_WAGER_REOPEN_COOLDOWN_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error(message)


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
