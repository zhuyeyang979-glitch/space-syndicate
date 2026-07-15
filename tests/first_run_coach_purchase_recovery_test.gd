extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const RUN_SEED := 900626424
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const SAVE_PATH := "GameSessionRuntimeController/GameSaveRuntimeCoordinator"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	var coordinator := main.get_node_or_null(COORDINATOR_PATH)
	var save_coordinator := coordinator.get_node_or_null(SAVE_PATH) if coordinator != null else null
	_expect(save_coordinator != null and bool(save_coordinator.call(
		"set_qa_default_save_path_override",
		"user://test_runs/first_run_coach_purchase_recovery/run.save"
	)), "QA save path is isolated before Main enters the tree")
	main.visible = false
	root.add_child(main)
	await _frames(8)

	var setup: Dictionary = main.call("_first_run_recommended_setup")
	main.set("configured_player_count", 4)
	main.set("configured_ai_player_count", 3)
	main.set("configured_role_indices", (setup.get("role_indices", []) as Array).duplicate(true))
	main.set("configured_starter_monster_indices", (setup.get("starter_monster_indices", []) as Array).duplicate(true))
	(main.get("rng") as RandomNumberGenerator).seed = RUN_SEED
	main.call("_confirm_start_new_run_from_setup")
	await _frames(10)

	_expect(bool(main.call("_activate_first_run_coach_action", "coach_select_district")), "coach selects the recommended district")
	await _frames(6)
	_expect(bool(main.call("_activate_first_run_coach_action", "coach_open_rack")), "coach opens the initially selected district rack")
	await _frames(6)

	var player_index := int(main.call("_first_run_coach_player_index"))
	var accessible_district := int(main.call("_first_card_accessible_district_for_player", player_index))
	var selected_before := int(main.get("selected_district"))
	var players_before: Array = main.get("players")
	var player_before: Dictionary = (players_before[player_index] as Dictionary).duplicate(true)
	_expect(accessible_district >= 0 and accessible_district != selected_before, "fixture requires recovery from an unavailable selected rack")

	_expect(bool(main.call("_activate_first_run_coach_action", "coach_buy_card")), "one Buy CTA recovers the rack and completes the purchase")
	await _frames(8)
	var players_after: Array = main.get("players")
	var player_after: Dictionary = players_after[player_index]
	var progress: Dictionary = main.call("_first_run_coach_progress", player_index)
	_expect(bool(progress.get("has_bought_card", false)), "purchase advances first-run progress")
	_expect(int(main.get("selected_district")) == accessible_district, "purchase focuses the accessible source district")
	_expect(int(player_after.get("cash", 0)) < int(player_before.get("cash", 0)), "purchase settles its locked market price")
	_expect((player_after.get("slots", []) as Array).size() == (player_before.get("slots", []) as Array).size() + 1, "purchased teaching card enters the hand")

	if save_coordinator != null:
		save_coordinator.call("clear_qa_default_save_path_override")
	root.remove_child(main)
	main.free()
	await _frames(3)
	print("FIRST_RUN_COACH_PURCHASE_RECOVERY_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
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
