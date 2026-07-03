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
	var stats := {
		"time_text": "03:20",
		"objectives_completed": 3,
		"objectives_total": 3,
		"errors": 1,
		"hints": 1,
		"economy": {
			"starting_cash": 1000,
			"final_cash": 1240,
			"cash_delta": 240,
			"city_count": 2,
			"gdp_per_min": 86,
			"total_income": 420,
			"total_spend": 180,
			"pressure": 7,
			"top_city": "雾港区｜GDP/min 56",
		},
	}
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
	var recap_summary_cards: Array = recap_snapshot.get("summary_cards", []) as Array
	_expect(recap_summary_cards.size() == 4, "recap snapshot exposes four board-game recap summary cards")
	if recap_summary_cards.size() >= 4:
		var recap_summary_text := var_to_str(recap_summary_cards)
		_expect(recap_summary_text.contains("关键行动") and recap_summary_text.contains("学到") and recap_summary_text.contains("下次建议") and recap_summary_text.contains("回看"), "recap summary cards separate action, learning, next step, and replay")
	var economy_cards: Array = recap_snapshot.get("economy_cards", []) as Array
	_expect(economy_cards.size() == 4, "recap snapshot exposes four compact economy explanation cards")
	var economy_text := var_to_str(economy_cards)
	_expect(economy_text.contains("现金") and economy_text.contains("城市/GDP") and economy_text.contains("投入") and economy_text.contains("下局抓手"), "recap economy cards explain cash, city GDP, spend, and next economic handle")
	_expect(not economy_text.contains("对手现金") and not economy_text.contains("true_owner") and not economy_text.contains("ai_route_plan"), "recap economy cards stay player-facing without hidden/developer fields")
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
	if path.ends_with("MatchRecapPanel.tscn"):
		var recap_summary_row := node.find_child("MatchRecapSummaryCardRow", true, false)
		_expect(recap_summary_row != null and recap_summary_row.visible and recap_summary_row.get_child_count() == 4, "MatchRecapPanel renders four recap summary cards")
		var recap_summary_text := _node_text(recap_summary_row)
		_expect(recap_summary_text.contains("关键行动") and recap_summary_text.contains("学到") and recap_summary_text.contains("下次建议") and recap_summary_text.contains("回看"), "MatchRecapPanel cards keep a board-game recap read order")
		var recap_economy_row := node.find_child("MatchRecapEconomyCardRow", true, false)
		_expect(recap_economy_row != null and recap_economy_row.visible and recap_economy_row.get_child_count() == 4, "MatchRecapPanel renders four compact economy explanation cards")
		var recap_economy_text := _node_text(recap_economy_row)
		_expect(recap_economy_text.contains("现金") and recap_economy_text.contains("城市/GDP") and recap_economy_text.contains("投入") and recap_economy_text.contains("下局抓手"), "MatchRecapPanel economy cards keep a scan-first money read order")
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
