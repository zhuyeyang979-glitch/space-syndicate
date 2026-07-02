extends SceneTree

const CAMPAIGN_SCRIPT := preload("res://scripts/campaign/campaign_definition.gd")
const PROGRESS_SCRIPT := preload("res://scripts/campaign/campaign_progress.gd")
const RECOMMEND_SCRIPT := preload("res://scripts/recommendations/recommended_start_service.gd")
const MENU_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/campaign_menu_snapshot.gd")
const BRIEFING_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/campaign_briefing_snapshot.gd")
const PROGRESS_MAP_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/campaign_progress_map_snapshot.gd")
const REWARD_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/campaign_reward_snapshot.gd")
const RECAP_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/match_recap_snapshot.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var campaign: Dictionary = CAMPAIGN_SCRIPT.new().load_by_id("tutorial_campaign")
	_expect(not campaign.is_empty(), "tutorial campaign loads for focus navigation")
	if campaign.is_empty():
		_finish()
		return
	var chapters: Array = campaign.get("chapters", []) if campaign.get("chapters", []) is Array else []
	var first_chapter: Dictionary = chapters[0] if not chapters.is_empty() and chapters[0] is Dictionary else {}
	var progress: Dictionary = PROGRESS_SCRIPT.new().apply_state(campaign, []).to_dictionary()
	var recommendations: Dictionary = RECOMMEND_SCRIPT.new().load_recommendations()
	var menu_snapshot: Dictionary = MENU_SNAPSHOT_SCRIPT.new().apply_dictionary({
		"campaign": campaign,
		"progress": progress,
		"recommendations": recommendations,
	}).to_ui_dictionary()
	var briefing_snapshot: Dictionary = BRIEFING_SNAPSHOT_SCRIPT.new().apply_dictionary({
		"campaign": campaign,
		"chapter": first_chapter,
	}).to_ui_dictionary()
	var progress_map_snapshot: Dictionary = PROGRESS_MAP_SNAPSHOT_SCRIPT.new().apply_dictionary({
		"progress": progress,
	}).to_ui_dictionary()
	var reward_snapshot: Dictionary = REWARD_SNAPSHOT_SCRIPT.new().apply_dictionary({
		"title": "第一桌完成",
		"badge": "星球赌桌入门",
		"score": 4,
		"time_text": "02:10",
		"objectives_completed": 3,
		"objectives_total": 3,
		"next_chapter_id": "02_market_hand",
		"next_label": "下一关",
		"unlocks": ["牌架练习"],
	}).to_ui_dictionary()
	var recap_snapshot: Dictionary = RECAP_SNAPSHOT_SCRIPT.new().apply_dictionary({
		"title": "第一桌复盘",
		"learned": ["先看星球，再看手牌。"],
		"key_actions": ["选择区域", "首召怪兽", "建城"],
		"suggestions": ["下一关练习买牌。"],
		"checkpoint_actions": [
			{"id": "campaign_next_02_market_hand", "label": "继续下一关"},
		],
	}).to_ui_dictionary()

	await _check_scene_default_focus("res://scenes/ui/CampaignMenu.tscn", "set_campaign_menu", menu_snapshot, "CampaignMenuPrimaryButton", "CampaignChapterButton", "Campaign menu")
	await _check_scene_default_focus("res://scenes/ui/CampaignBriefing.tscn", "set_briefing", briefing_snapshot, "CampaignBriefingPrimaryButton", "CampaignBriefingSecondaryButton", "Campaign briefing")
	await _check_scene_default_focus("res://scenes/ui/CampaignRewardPanel.tscn", "set_reward", reward_snapshot, "CampaignRewardPrimaryButton", "CampaignRewardSecondaryButton", "Campaign reward")
	await _check_scene_default_focus("res://scenes/ui/MatchRecapPanel.tscn", "set_recap", recap_snapshot, "MatchRecapActionButton_campaign_next_02_market_hand", "MatchRecapActionButton", "Match recap")
	await _check_scene_default_focus("res://scenes/ui/CampaignProgressMap.tscn", "set_progress_map", progress_map_snapshot, "CampaignProgressChapterButton_campaign_chapter_00_tavern_entry", "CampaignProgressChapterButton", "Campaign progress map")
	_finish()


func _check_scene_default_focus(path: String, method: String, snapshot: Dictionary, expected_focus_name: String, dynamic_prefix: String, label: String) -> void:
	root.gui_release_focus()
	var packed := load(path) as PackedScene
	_expect(packed != null, "%s scene loads" % label)
	if packed == null:
		return
	var panel := packed.instantiate() as Control
	_expect(panel != null, "%s root is Control" % label)
	if panel == null:
		return
	root.add_child(panel)
	await process_frame
	_expect(panel.has_method(method), "%s exposes %s" % [label, method])
	if panel.has_method(method):
		panel.call(method, snapshot)
	await _wait_frames(4)
	var focus_owner := root.gui_get_focus_owner()
	_expect(focus_owner is Button, "%s gives keyboard/gamepad focus to a button by default" % label)
	if focus_owner is Button:
		var focused_button := focus_owner as Button
		_expect(focused_button.name == expected_focus_name, "%s default focus lands on %s" % [label, expected_focus_name])
		_expect(not focused_button.disabled, "%s default focus is never disabled" % label)
	var focusable_buttons := _focusable_buttons(panel)
	_expect(not focusable_buttons.is_empty(), "%s exposes at least one focusable button" % label)
	var dynamic_count := 0
	for button in focusable_buttons:
		_expect(button.focus_mode == Control.FOCUS_ALL, "%s button %s is reachable by keyboard/gamepad focus" % [label, button.name])
		if button.name.begins_with(dynamic_prefix):
			dynamic_count += 1
	_expect(dynamic_count > 0, "%s gives dynamic action buttons stable focus node names" % label)
	root.remove_child(panel)
	panel.queue_free()
	await process_frame


func _focusable_buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button:
		var button := node as Button
		if not button.disabled and button.visible:
			result.append(button)
	for child in node.get_children():
		result.append_array(_focusable_buttons(child))
	return result


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
		print("Campaign focus navigation test passed.")
	else:
		push_error("Campaign focus navigation test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
