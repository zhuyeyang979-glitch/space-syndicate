extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main.tscn loads for first-five campaign runtime")
	if packed == null:
		_finish()
		return
	root.size = Vector2i(1600, 960)
	var main := packed.instantiate()
	root.add_child(main)
	await _wait_frames(6)
	main.set("campaign_completed_chapter_ids", [])
	main.set("selected_campaign_chapter_id", "")
	main.set("active_campaign_chapter_id", "")
	await _complete_chapter_00(main)
	await _open_next_briefing(main, "01_first_table")
	await _complete_chapter_01(main)
	await _open_next_briefing(main, "02_market_hand")
	await _complete_chapter_02(main)
	await _open_next_briefing(main, "03_public_track")
	await _complete_chapter_03(main)
	await _open_next_briefing(main, "04_bid_practice")
	await _complete_chapter_04(main)
	var completed: Array = main.get("campaign_completed_chapter_ids") as Array
	for chapter_id in ["00_tavern_entry", "01_first_table", "02_market_hand", "03_public_track", "04_bid_practice"]:
		_expect(completed.has(chapter_id), "campaign runtime completes %s through real table actions" % chapter_id)
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(1)
	_finish()


func _complete_chapter_00(main: Node) -> void:
	main.call("_start_campaign_chapter", "00_tavern_entry")
	await _wait_frames(8)
	_expect(_runtime_ready(main, "00_tavern_entry", "first_table"), "chapter 00 enters real runtime table")
	_select_recommended_district(main)
	await _wait_for_reward(main, "00_tavern_entry")


func _complete_chapter_01(main: Node) -> void:
	main.call("_start_campaign_chapter", "01_first_table")
	await _wait_frames(8)
	_select_recommended_district(main)
	await _wait_frames(4)
	main.call("_activate_first_run_coach_action", "coach_first_summon")
	await _wait_frames(16)
	main.call("_activate_first_run_coach_action", "coach_build_city")
	await _wait_for_reward(main, "01_first_table")


func _complete_chapter_02(main: Node) -> void:
	main.call("_start_campaign_chapter", "02_market_hand")
	await _wait_frames(8)
	_select_recommended_district(main)
	await _wait_frames(4)
	main.call("_activate_first_run_coach_action", "coach_first_summon")
	await _wait_frames(12)
	main.call("_activate_first_run_coach_action", "coach_open_rack")
	await _wait_frames(6)
	main.call("_activate_scenario_action", "scenario_step_compare_cards")
	await _wait_frames(6)
	main.call("_activate_first_run_coach_action", "coach_buy_card")
	await _wait_for_reward(main, "02_market_hand")


func _complete_chapter_03(main: Node) -> void:
	main.call("_start_campaign_chapter", "03_public_track")
	await _wait_frames(8)
	main.call("_activate_scenario_action", "scenario_step_select_track_card")
	await _wait_frames(4)
	main.call("_activate_scenario_action", "scenario_step_read_inspector")
	await _wait_frames(4)
	main.call("_activate_scenario_action", "scenario_step_open_card_detail")
	await _wait_for_reward(main, "03_public_track")


func _complete_chapter_04(main: Node) -> void:
	main.call("_start_campaign_chapter", "04_bid_practice")
	await _wait_frames(8)
	main.call("_activate_scenario_action", "scenario_step_read_bid_board")
	await _wait_frames(4)
	main.call("_activate_scenario_action", "scenario_step_raise_bid")
	await _wait_frames(4)
	main.call("_activate_scenario_action", "scenario_step_reset_bid")
	await _wait_for_reward(main, "04_bid_practice")


func _open_next_briefing(main: Node, chapter_id: String) -> void:
	main.call("_on_campaign_action_requested", "campaign_next_%s" % chapter_id)
	await _wait_frames(4)
	_expect(_has_named_node(main, "CampaignBriefing"), "reward flow can open next briefing %s" % chapter_id)


func _select_recommended_district(main: Node) -> void:
	var district_index := int(main.call("_first_run_recommended_start_district", 0))
	_expect(district_index >= 0, "runtime finds a recommended playable district")
	if district_index >= 0:
		main.call("_select_district", district_index)


func _wait_for_reward(main: Node, chapter_id: String) -> void:
	await create_timer(1.20).timeout
	await _wait_frames(4)
	var completed: Array = main.get("campaign_completed_chapter_ids") as Array
	_expect(completed.has(chapter_id), "%s records completion after success feedback" % chapter_id)
	_expect(_has_named_node(main, "CampaignRewardPanel"), "%s opens reward panel after success feedback" % chapter_id)
	_expect(not (main.get("campaign_last_reward") as Dictionary).is_empty(), "%s creates non-empty reward data" % chapter_id)
	_expect(not (main.get("campaign_last_recap") as Dictionary).is_empty(), "%s creates non-empty recap data" % chapter_id)


func _runtime_ready(main: Node, chapter_id: String, scenario_id: String) -> bool:
	var screen := main.find_child("RuntimeGameScreen", true, false) as Control
	return screen != null and screen.visible and str(main.get("active_campaign_chapter_id")) == chapter_id and str(main.get("active_scenario_id")) == scenario_id


func _has_named_node(node: Node, node_name: String) -> bool:
	return node != null and (node.name == node_name or node.find_child(node_name, true, false) != null)


func _wait_frames(count: int) -> void:
	for _i in range(maxi(1, count)):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Campaign first-five runtime test passed.")
	else:
		push_error("Campaign first-five runtime test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
