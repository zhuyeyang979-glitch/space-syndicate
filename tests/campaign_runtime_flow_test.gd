extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const CAMPAIGN_SCRIPT := preload("res://scripts/campaign/campaign_definition.gd")
const PROGRESS_SCRIPT := preload("res://scripts/campaign/campaign_progress.gd")
const SAVE_SCRIPT := preload("res://scripts/campaign/campaign_save.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var campaign: Dictionary = CAMPAIGN_SCRIPT.new().load_by_id("tutorial_campaign")
	var chapters: Array = campaign.get("chapters", []) if campaign.get("chapters", []) is Array else []
	_expect(chapters.size() >= 10, "runtime campaign contract has 10 chapters")
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.set("campaign_completed_chapter_ids", [])
	main.set("selected_campaign_chapter_id", "")
	main.set("active_campaign_chapter_id", "")
	main.call("_open_main_menu")
	await process_frame
	var menu_overlay := main.get("menu_overlay") as Control
	_expect(menu_overlay != null and _node_text(menu_overlay).contains("新手战役"), "main menu exposes campaign entry")
	_expect(menu_overlay != null and _node_text(menu_overlay).contains("快速开局"), "main menu exposes quick-start entry")
	main.call("_open_campaign_menu")
	await process_frame
	_expect(_has_named_node(menu_overlay, "CampaignMenu"), "campaign menu opens from main")
	_expect(_node_text(menu_overlay).contains("继续新手战役"), "campaign menu exposes continue CTA")
	await _check_every_chapter_briefing(main, campaign, chapters)
	await _check_first_chapter_reward_and_recap(main, chapters)
	root.remove_child(main)
	main.queue_free()
	await process_frame
	_finish()


func _check_every_chapter_briefing(main: Node, campaign: Dictionary, chapters: Array) -> void:
	var completed: Array = []
	for i in range(chapters.size()):
		var chapter: Dictionary = chapters[i] if chapters[i] is Dictionary else {}
		var chapter_id := str(chapter.get("id", ""))
		var progress: Dictionary = PROGRESS_SCRIPT.new().apply_state(campaign, completed, chapter_id).to_dictionary()
		_expect((progress.get("unlocked_chapter_ids", []) as Array).has(chapter_id), "chapter %s can be unlocked by previous completions" % chapter_id)
		main.set("campaign_completed_chapter_ids", completed.duplicate(true))
		main.set("selected_campaign_chapter_id", chapter_id)
		main.call("_open_campaign_briefing_menu", chapter_id)
		await process_frame
		var menu_overlay := main.get("menu_overlay") as Control
		_expect(_has_named_node(menu_overlay, "CampaignBriefing"), "chapter %s opens briefing panel" % chapter_id)
		_expect(_node_text(menu_overlay).contains(str(chapter.get("title", ""))), "chapter %s briefing shows title" % chapter_id)
		_expect(_node_text(menu_overlay).contains("开始本关"), "chapter %s briefing exposes start button" % chapter_id)
		if not completed.has(chapter_id):
			completed.append(chapter_id)


func _check_first_chapter_reward_and_recap(main: Node, chapters: Array) -> void:
	var chapter: Dictionary = chapters[0] if chapters.size() > 0 and chapters[0] is Dictionary else {}
	var chapter_id := str(chapter.get("id", ""))
	var save := SAVE_SCRIPT.new()
	var save_path := "user://campaign_runtime_flow_test.save"
	save.reset(save_path)
	main.set("campaign_completed_chapter_ids", [])
	main.set("selected_campaign_chapter_id", chapter_id)
	main.set("active_campaign_chapter_id", "")
	main.call("_start_campaign_chapter", chapter_id)
	await process_frame
	await process_frame
	_expect(str(main.get("active_campaign_chapter_id")) == chapter_id, "starting a campaign chapter stores active chapter id")
	var completed: Variant = main.call("_complete_scenario_signal", "district_selected", "选择区域：验收区。", "after_select", "scenario_coach")
	await process_frame
	await process_frame
	_expect(bool(completed), "real scenario signal completes the prologue objective")
	_expect((main.get("campaign_completed_chapter_ids") as Array).has(chapter_id), "completed campaign chapter is recorded on runtime state")
	var reward: Dictionary = main.get("campaign_last_reward") as Dictionary
	var recap: Dictionary = main.get("campaign_last_recap") as Dictionary
	_expect(not reward.is_empty(), "campaign runtime creates reward packet")
	_expect(not recap.is_empty(), "campaign runtime creates recap packet")
	var menu_overlay := main.get("menu_overlay") as Control
	_expect(_has_named_node(menu_overlay, "CampaignRewardPanel"), "campaign completion opens reward panel")
	main.call("_open_campaign_recap_menu")
	await process_frame
	_expect(_has_named_node(menu_overlay, "MatchRecapPanel"), "campaign recap opens from reward flow")
	save.save_progress({
		"campaign_id": str(main.get("active_campaign_id")),
		"completed_chapter_ids": (main.get("campaign_completed_chapter_ids") as Array).duplicate(true),
		"selected_chapter_id": str(main.get("selected_campaign_chapter_id")),
	}, save_path)
	var saved: Dictionary = save.load_progress(save_path)
	_expect((saved.get("completed_chapter_ids", []) as Array).has(chapter_id), "campaign progress save contains completed runtime chapter")
	save.reset(save_path)


func _has_named_node(node: Node, node_name: String) -> bool:
	if node == null:
		return false
	if node.name == node_name:
		return true
	if node.find_child(node_name, true, false) != null:
		return true
	return false


func _node_text(node: Node) -> String:
	if node == null:
		return ""
	var parts: Array[String] = []
	if node is Label:
		parts.append((node as Label).text)
	if node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		parts.append(_node_text(child))
	return "\n".join(parts)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Campaign runtime flow test passed.")
	else:
		push_error("Campaign runtime flow test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
