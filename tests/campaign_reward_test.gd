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
	var summary_cards: Array = reward_snapshot.get("summary_cards", []) as Array
	_expect(summary_cards.size() == 4, "reward snapshot exposes four board-game settlement summary cards")
	if summary_cards.size() >= 4:
		var summary_text := var_to_str(summary_cards)
		_expect(summary_text.contains("表现") and summary_text.contains("目标") and summary_text.contains("解锁") and summary_text.contains("下一步"), "reward summary cards separate performance, objective, unlock, and next step")
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
	if path.ends_with("CampaignRewardPanel.tscn"):
		var summary_row := node.find_child("CampaignRewardSummaryCardRow", true, false)
		_expect(summary_row != null and summary_row.visible and summary_row.get_child_count() == 4, "CampaignRewardPanel renders four settlement summary cards")
		var summary_text := _node_text(summary_row)
		_expect(summary_text.contains("表现") and summary_text.contains("目标") and summary_text.contains("解锁") and summary_text.contains("下一步"), "CampaignRewardPanel settlement cards keep a board-game read order")
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
		print("Campaign reward test passed.")
	else:
		push_error("Campaign reward test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
