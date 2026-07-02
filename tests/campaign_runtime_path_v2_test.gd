extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const CAMPAIGN_SCRIPT := preload("res://scripts/campaign/campaign_definition.gd")
const PROGRESS_SCRIPT := preload("res://scripts/campaign/campaign_progress.gd")
const SAVE_SCRIPT := preload("res://scripts/campaign/campaign_save.gd")
const SCENARIO_LOADER_SCRIPT := preload("res://scripts/scenarios/scenario_loader.gd")
const FIXTURE_FACTORY_SCRIPT := preload("res://scripts/scenarios/scenario_fixture_factory.gd")
const SCENARIO_COACH_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/scenario_coach_snapshot.gd")
const SHOWCASE_ADAPTER_SCRIPT := preload("res://scripts/ui/scenario_lab_showcase_adapter.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var campaign: Dictionary = CAMPAIGN_SCRIPT.new().load_by_id("tutorial_campaign")
	_check_chapter_fixture_contract(campaign)
	_check_visual_event_contract()
	_check_campaign_save_unlocked(campaign)
	await _check_briefing_runtime_reward_recap(campaign)
	_finish()


func _check_chapter_fixture_contract(campaign: Dictionary) -> void:
	var chapters: Array = campaign.get("chapters", []) if campaign.get("chapters", []) is Array else []
	_expect(chapters.size() == 10, "tutorial campaign keeps exactly 10 runtime chapters")
	var loader: Variant = SCENARIO_LOADER_SCRIPT.new()
	var factory: Variant = FIXTURE_FACTORY_SCRIPT.new()
	for chapter_variant in chapters:
		if not (chapter_variant is Dictionary):
			_expect(false, "chapter entry is a dictionary")
			continue
		var chapter: Dictionary = chapter_variant
		var chapter_id := str(chapter.get("id", "")).strip_edges()
		var scenario_id := str(chapter.get("scenario_id", "")).strip_edges()
		var scenario: Dictionary = loader.load_by_id(scenario_id)
		var fixture: Dictionary = factory.make_fixture(scenario_id, "start")
		_expect(scenario_id != "" and not scenario.is_empty(), "chapter %s loads scenario %s" % [chapter_id, scenario_id])
		_expect(not fixture.is_empty(), "chapter %s loads runtime fixture for %s" % [chapter_id, scenario_id])
		_expect(fixture.get("scenario", {}) is Dictionary and not (fixture.get("scenario", {}) as Dictionary).is_empty(), "chapter %s fixture carries scenario data" % chapter_id)
		_expect(fixture.get("coach", {}) is Dictionary and not (fixture.get("coach", {}) as Dictionary).is_empty(), "chapter %s fixture carries coach data" % chapter_id)
		_expect(fixture.get("table_state", {}) is Dictionary and not (fixture.get("table_state", {}) as Dictionary).is_empty(), "chapter %s fixture carries table state" % chapter_id)
		_expect(fixture.get("replay", {}) is Dictionary and not (fixture.get("replay", {}) as Dictionary).is_empty(), "chapter %s fixture carries replay data" % chapter_id)


func _check_visual_event_contract() -> void:
	var expected_classes := {
		"first_table": ["card_play", "card_reveal", "cash_gain", "gdp_delta"],
		"monster_pressure": ["monster_attack", "city_damage", "cash_gain", "gdp_delta"],
		"public_track_intro": ["card_reveal", "route_damage"],
		"bid_practice": ["target_arrow", "card_reveal"],
	}
	var factory: Variant = FIXTURE_FACTORY_SCRIPT.new()
	var adapter: Variant = SHOWCASE_ADAPTER_SCRIPT.new()
	for scenario_id in expected_classes.keys():
		var payload: Dictionary = factory.make_fixture(str(scenario_id), "start")
		var visual_events: Array = payload.get("visual_events", []) if payload.get("visual_events", []) is Array else []
		_expect(not visual_events.is_empty(), "%s fixture exports visual_events" % scenario_id)
		var snapshot: Dictionary = adapter.normalize_payload(payload)
		_expect(str(snapshot.get("source", "")) == "scenario_lab_visual_events", "%s payload is normalized for ScenarioLabShowcaseAdapter" % scenario_id)
		_expect(bool(snapshot.get("hidden_info_safe", false)), "%s visual payload is hidden-info safe" % scenario_id)
		var classes: Array = snapshot.get("event_classes", []) if snapshot.get("event_classes", []) is Array else []
		for required_class in expected_classes.get(scenario_id, []):
			_expect(classes.has(required_class), "%s visual_events include %s" % [scenario_id, required_class])


func _check_campaign_save_unlocked(campaign: Dictionary) -> void:
	var progress: Dictionary = PROGRESS_SCRIPT.new().apply_state(campaign, ["00_tavern_entry"], "01_first_table").to_dictionary()
	var save := SAVE_SCRIPT.new()
	var save_path := "user://campaign_runtime_path_v2.save"
	save.reset(save_path)
	_expect(save.save_progress(progress, save_path), "campaign progress save succeeds")
	var saved: Dictionary = save.load_progress(save_path)
	var unlocked: Array = saved.get("unlocked_chapter_ids", []) if saved.get("unlocked_chapter_ids", []) is Array else []
	_expect(unlocked.has("00_tavern_entry") and unlocked.has("01_first_table"), "campaign_progress.save persists unlocked chapters")
	save.reset(save_path)


func _check_briefing_runtime_reward_recap(campaign: Dictionary) -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main.tscn loads for campaign runtime path")
	if packed == null:
		return
	root.size = Vector2i(1600, 960)
	var main := packed.instantiate()
	root.add_child(main)
	await _wait_frames(4)
	main.set("campaign_completed_chapter_ids", [])
	main.set("selected_campaign_chapter_id", "")
	main.set("active_campaign_chapter_id", "")
	main.call("_open_campaign_briefing_menu", "00_tavern_entry")
	await _wait_frames(2)
	var briefing := main.find_child("CampaignBriefing", true, false) as Control
	var start_button := main.find_child("CampaignBriefingPrimaryButton", true, false) as Button
	_expect(briefing != null and briefing.visible and start_button != null, "CampaignBriefing exposes a real start button")
	if start_button != null:
		start_button.emit_signal("pressed")
	await _wait_frames(8)
	var runtime_screen := main.find_child("RuntimeGameScreen", true, false) as Control
	var menu_overlay := main.get("menu_overlay") as Control
	_expect(runtime_screen != null and runtime_screen.visible, "CampaignBriefing start enters real RuntimeGameScreen")
	_expect(menu_overlay == null or not menu_overlay.visible, "campaign start leaves briefing/menu overlay")
	_expect(str(main.get("active_campaign_chapter_id")) == "00_tavern_entry", "runtime stores active campaign chapter")
	_expect(str(main.get("active_scenario_id")) == "first_table", "runtime starts chapter scenario_id")
	var scenario_coach := main.find_child("ScenarioCoach", true, false) as Control
	_expect(scenario_coach != null and scenario_coach.visible, "CampaignCoach/ScenarioCoach is mounted on the main table")
	var coach_source: Dictionary = main.call("_runtime_scenario_coach_snapshot_source", 0) as Dictionary
	var coach_ui: Dictionary = SCENARIO_COACH_SNAPSHOT_SCRIPT.new().apply_dictionary(coach_source).to_ui_dictionary()
	var primary: Dictionary = coach_ui.get("primary_action", {}) if coach_ui.get("primary_action", {}) is Dictionary else {}
	_expect(str(coach_ui.get("goal", "")).strip_edges() != "", "CampaignCoach shows current objective")
	_expect(str(primary.get("id", "")).strip_edges() != "" and not bool(primary.get("disabled", false)), "CampaignCoach exposes one enabled primary CTA")
	_expect(_named_node_count(scenario_coach, "ScenarioCoachPrimaryButton") == 1, "CampaignCoach has only one primary CTA node")
	var fake_completed: Variant = main.call("_activate_scenario_action", "scenario_step_select_district")
	await _wait_frames(2)
	_expect(bool(fake_completed), "scenario primary CTA can focus the objective")
	_expect(not bool((main.get("scenario_completed_signals") as Dictionary).get("district_selected", false)), "scenario CTA does not fake-complete success conditions")
	var completed: Variant = main.call("_complete_scenario_signal", "district_selected", "选择区域：运行路径验收。", "after_select", "planet")
	await _wait_frames(4)
	_expect(bool(completed), "real success condition completes the campaign chapter")
	await create_timer(1.15).timeout
	await _wait_frames(2)
	_expect((main.get("campaign_completed_chapter_ids") as Array).has("00_tavern_entry"), "completed campaign chapter is recorded")
	_expect(_has_named_node(main, "CampaignRewardPanel"), "success_conditions completion enters CampaignRewardPanel")
	main.call("_open_campaign_recap_menu")
	await _wait_frames(2)
	_expect(_has_named_node(main, "MatchRecapPanel"), "RewardPanel can continue into MatchRecapPanel")
	var recap: Dictionary = main.get("campaign_last_recap") as Dictionary
	_expect(not (recap.get("key_actions", []) as Array).is_empty(), "MatchRecapPanel data includes key actions")
	_expect(not (recap.get("learned", []) as Array).is_empty(), "MatchRecapPanel data includes learned content")
	_expect(not (recap.get("suggestions", []) as Array).is_empty(), "MatchRecapPanel data includes next suggestions")
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(1)


func _wait_frames(count: int) -> void:
	for _i in range(maxi(1, count)):
		await process_frame


func _has_named_node(node: Node, node_name: String) -> bool:
	return node != null and (node.name == node_name or node.find_child(node_name, true, false) != null)


func _named_node_count(node: Node, node_name: String) -> int:
	if node == null:
		return 0
	var count := 1 if node.name == node_name else 0
	for child in node.get_children():
		count += _named_node_count(child, node_name)
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Campaign Runtime Path v2 test passed.")
	else:
		push_error("Campaign Runtime Path v2 test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
