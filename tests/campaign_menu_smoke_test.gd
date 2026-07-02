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
	_expect((menu_snapshot.get("chapters", []) as Array).size() >= 10, "campaign menu snapshot exposes 10 chapter cards")
	await _check_scene("res://scenes/ui/CampaignMenu.tscn", "set_campaign_menu", menu_snapshot)
	var first_chapter: Dictionary = chapters[0] if chapters[0] is Dictionary else {}
	var briefing_snapshot: Dictionary = BRIEFING_SNAPSHOT_SCRIPT.new().apply_dictionary({"campaign": campaign, "chapter": first_chapter}).to_ui_dictionary()
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
	_expect(node.get_combined_minimum_size().x <= 1280 and node.get_combined_minimum_size().y <= 720, "%s fits 1280x720 minimum" % path)
	root.remove_child(node)
	node.queue_free()


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
