extends SceneTree

const CAMPAIGN_SCRIPT := preload("res://scripts/campaign/campaign_definition.gd")
const PROGRESS_SCRIPT := preload("res://scripts/campaign/campaign_progress.gd")
const RECOMMEND_SCRIPT := preload("res://scripts/recommendations/recommended_start_service.gd")
const MENU_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/campaign_menu_snapshot.gd")
const BRIEFING_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/campaign_briefing_snapshot.gd")
const PROGRESS_MAP_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/campaign_progress_map_snapshot.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var campaign: Dictionary = CAMPAIGN_SCRIPT.new().load_by_id("tutorial_campaign")
	_expect(not campaign.is_empty(), "tutorial campaign loads")
	var chapters: Array = campaign.get("chapters", []) if campaign.get("chapters", []) is Array else []
	_expect(chapters.size() >= 10, "tutorial campaign has at least 10 chapters")
	for chapter_variant in chapters:
		var chapter: Dictionary = chapter_variant if chapter_variant is Dictionary else {}
		for key in ["id", "title", "scenario_id", "briefing", "objectives", "allowed_actions", "success_conditions", "failure_hints", "reward"]:
			_expect(chapter.has(key), "chapter %s has %s" % [str(chapter.get("id", "?")), key])
	var progress: Dictionary = PROGRESS_SCRIPT.new().apply_state(campaign, []).to_dictionary()
	var recommendations: Dictionary = RECOMMEND_SCRIPT.new().load_recommendations()
	_expect((recommendations.get("presets", []) as Array).size() >= 3, "recommended start exposes 3 presets")
	var menu_snapshot: Dictionary = MENU_SNAPSHOT_SCRIPT.new().apply_dictionary({"campaign": campaign, "progress": progress, "recommendations": recommendations}).to_ui_dictionary()
	_expect(str(menu_snapshot.get("title", "")).contains("新手战役"), "campaign menu snapshot is player-facing")
	var path_steps: Array = menu_snapshot.get("path_steps", []) as Array
	_expect(path_steps.size() == 3, "campaign menu snapshot exposes a three-step visual play path")
	if path_steps.size() >= 3:
		_expect(str((path_steps[0] as Dictionary).get("label", "")).length() <= 8 and str((path_steps[1] as Dictionary).get("label", "")).length() <= 8 and str((path_steps[2] as Dictionary).get("label", "")).length() <= 8, "campaign play-path chips stay short instead of becoming rules prose")
	var visible_chapters: Array = menu_snapshot.get("chapters", []) as Array
	_expect(visible_chapters.size() <= 4 and visible_chapters.size() >= 1, "campaign menu snapshot keeps the first screen to four or fewer chapter cards")
	_expect(str((visible_chapters[0] as Dictionary).get("title", "")).length() <= 18, "campaign menu chapter title stays short")
	await _check_scene("res://scenes/ui/CampaignMenu.tscn", "set_campaign_menu", menu_snapshot)
	var first_chapter: Dictionary = chapters[0] if chapters[0] is Dictionary else {}
	var briefing_snapshot: Dictionary = BRIEFING_SNAPSHOT_SCRIPT.new().apply_dictionary({"campaign": campaign, "chapter": first_chapter}).to_ui_dictionary()
	var quick_cards: Array = briefing_snapshot.get("quick_cards", []) as Array
	_expect(quick_cards.size() == 3, "campaign briefing snapshot exposes three first-glance summary cards")
	if quick_cards.size() >= 3:
		_expect(str((quick_cards[0] as Dictionary).get("kicker", "")).contains("目标") and str((quick_cards[1] as Dictionary).get("kicker", "")).contains("能做") and str((quick_cards[2] as Dictionary).get("kicker", "")).contains("收获"), "campaign briefing summary cards separate goal, action, and reward")
		_expect(str((quick_cards[0] as Dictionary).get("title", "")).length() <= 18 and str((quick_cards[1] as Dictionary).get("title", "")).length() <= 18 and str((quick_cards[2] as Dictionary).get("title", "")).length() <= 18, "campaign briefing summary card titles stay scan-first")
	await _check_scene("res://scenes/ui/CampaignBriefing.tscn", "set_briefing", briefing_snapshot)
	var progress_map_snapshot: Dictionary = PROGRESS_MAP_SNAPSHOT_SCRIPT.new().apply_dictionary({"progress": progress}).to_ui_dictionary()
	await _check_scene("res://scenes/ui/CampaignProgressMap.tscn", "set_progress_map", progress_map_snapshot)
	_finish()


func _check_scene(path: String, method: String, snapshot: Dictionary) -> void:
	var packed := load(path) as PackedScene
	_expect(packed != null, "%s loads" % path)
	if packed == null:
		return
	var node := packed.instantiate() as Control
	_expect(node != null, "%s root is Control" % path)
	root.add_child(node)
	await process_frame
	_expect(node.has_method(method), "%s exposes %s" % [path, method])
	if node.has_method(method):
		node.call(method, snapshot)
		await process_frame
	if path.ends_with("CampaignMenu.tscn"):
		var path_rail := node.find_child("CampaignMenuPathRail", true, false)
		_expect(path_rail != null and path_rail.visible and path_rail.get_child_count() == 3, "CampaignMenu renders the three-step visual play path")
		var path_text := _node_text(path_rail)
		_expect(path_text.contains("开桌") and path_text.contains("练流程") and path_text.contains("完整局"), "CampaignMenu play path uses compact board-game route chips")
	if path.ends_with("CampaignBriefing.tscn"):
		var quick_card_row := node.find_child("CampaignBriefingQuickCardRow", true, false)
		_expect(quick_card_row != null and quick_card_row.visible and quick_card_row.get_child_count() == 3, "CampaignBriefing renders three first-glance summary cards")
		var quick_card_text := _node_text(quick_card_row)
		_expect(quick_card_text.contains("目标") and quick_card_text.contains("能做") and quick_card_text.contains("收获"), "CampaignBriefing summary cards keep a board-game read order")
	_expect(node.get_combined_minimum_size().x <= 1280 and node.get_combined_minimum_size().y <= 720, "%s fits 1280x720 minimum" % path)
	root.remove_child(node)
	node.queue_free()


func _node_text(node: Node) -> String:
	if node == null:
		return ""
	var pieces: Array[String] = []
	if node is Label:
		pieces.append((node as Label).text)
	elif node is Button:
		pieces.append((node as Button).text)
	for child in node.get_children():
		pieces.append(_node_text(child))
	return " ".join(pieces)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Campaign menu smoke test passed.")
	else:
		push_error("Campaign menu smoke test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
