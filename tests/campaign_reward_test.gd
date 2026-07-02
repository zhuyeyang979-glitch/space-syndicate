extends SceneTree

const CAMPAIGN_SCRIPT := preload("res://scripts/campaign/campaign_definition.gd")
const PROGRESS_SCRIPT := preload("res://scripts/campaign/campaign_progress.gd")
const REWARD_SERVICE_SCRIPT := preload("res://scripts/campaign/campaign_reward_service.gd")
const REWARD_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/campaign_reward_snapshot.gd")
const RECAP_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/match_recap_snapshot.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var campaign: Dictionary = CAMPAIGN_SCRIPT.new().load_by_id("tutorial_campaign")
	var chapters: Array = campaign.get("chapters", []) if campaign.get("chapters", []) is Array else []
	var chapter: Dictionary = chapters[1] if chapters.size() > 1 and chapters[1] is Dictionary else {}
	var progress: Variant = PROGRESS_SCRIPT.new().apply_state(campaign, ["00_tavern_entry"])
	progress.mark_completed(str(chapter.get("id", "")))
	var stats := {"time_text": "03:20", "objectives_completed": 3, "objectives_total": 3, "errors": 1, "hints": 1}
	var service := REWARD_SERVICE_SCRIPT.new()
	var reward: Dictionary = service.build_reward(campaign, chapter, progress.to_dictionary(), stats)
	_expect(str(reward.get("badge", "")) != "", "reward includes badge")
	_expect((reward.get("unlocks", []) as Array).size() >= 1, "reward includes unlocks")
	var reward_snapshot: Dictionary = REWARD_SNAPSHOT_SCRIPT.new().apply_dictionary(reward).to_ui_dictionary()
	await _check_scene("res://scenes/ui/CampaignRewardPanel.tscn", "set_reward", reward_snapshot)
	var recap: Dictionary = service.build_recap(campaign, chapter, [
		{"time": "00:15", "public_text": "选择区域：雾港区。", "private_text": "对手现金9999", "developer_text": "ai_route_plan"},
		{"time": "00:42", "public_text": "首召怪兽。", "developer_text": "true_owner=2"},
	], stats)
	var recap_snapshot: Dictionary = RECAP_SNAPSHOT_SCRIPT.new().apply_dictionary(recap).to_ui_dictionary()
	_expect(str(var_to_str(recap_snapshot)).contains("选择区域"), "recap keeps public key actions")
	await _check_scene("res://scenes/ui/MatchRecapPanel.tscn", "set_recap", recap_snapshot)
	_finish()


func _check_scene(path: String, method: String, snapshot: Dictionary) -> void:
	var packed := load(path) as PackedScene
	_expect(packed != null, "%s loads" % path)
	if packed == null:
		return
	var node := packed.instantiate() as Control
	root.add_child(node)
	await process_frame
	_expect(node.has_method(method), "%s exposes %s" % [path, method])
	if node.has_method(method):
		node.call(method, snapshot)
		await process_frame
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
		print("Campaign reward test passed.")
	else:
		push_error("Campaign reward test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
