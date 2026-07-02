extends SceneTree

const CAMPAIGN_SCRIPT := preload("res://scripts/campaign/campaign_definition.gd")
const PROGRESS_SCRIPT := preload("res://scripts/campaign/campaign_progress.gd")
const RECOMMEND_SCRIPT := preload("res://scripts/recommendations/recommended_start_service.gd")
const MENU_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/campaign_menu_snapshot.gd")
const REWARD_SERVICE_SCRIPT := preload("res://scripts/campaign/campaign_reward_service.gd")
const RECAP_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/match_recap_snapshot.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var campaign: Dictionary = CAMPAIGN_SCRIPT.new().load_by_id("tutorial_campaign")
	var progress: Dictionary = PROGRESS_SCRIPT.new().apply_state(campaign, []).to_dictionary()
	var menu_snapshot: Dictionary = MENU_SNAPSHOT_SCRIPT.new().apply_dictionary({
		"campaign": campaign,
		"progress": progress,
		"recommendations": RECOMMEND_SCRIPT.new().load_recommendations(),
		"opponent_cash": 999999,
		"opponent_hand": ["秘密手牌"],
		"ai_private_plan": "hidden",
		"ai_route_plan": "hidden",
		"true_owner": 2,
		"hidden_owner": 3,
		"owner_truth": "rival",
	}).to_ui_dictionary()
	_assert_no_forbidden(var_to_str(menu_snapshot), "campaign menu snapshot")
	var chapter: Dictionary = (campaign.get("chapters", []) as Array)[0] if (campaign.get("chapters", []) as Array).size() > 0 else {}
	var recap: Dictionary = REWARD_SERVICE_SCRIPT.new().build_recap(campaign, chapter, [
		{"time": "00:01", "public_text": "有人完成公开行动。", "private_text": "opponent hand rival exact hand hidden_owner=2", "developer_text": "true_owner=3 owner_truth=3 ai_private_plan=attack ai_utility_score=999"},
	], {})
	var recap_snapshot: Dictionary = RECAP_SNAPSHOT_SCRIPT.new().apply_dictionary(recap).to_ui_dictionary()
	_assert_no_forbidden(var_to_str(recap_snapshot), "campaign recap snapshot")
	_finish()


func _assert_no_forbidden(text: String, label: String) -> void:
	var lower_text := text.to_lower()
	for forbidden in ["opponent_cash", "opponent cash", "opponent_hand", "opponent hand", "rival exact hand", "ai_private_plan", "ai private plan", "ai_route_plan", "true_owner", "hidden_owner", "owner_truth", "developer_text", "ai_utility_score", "pressure bucket", "decision_samples", "learning_bonus"]:
		_expect(not lower_text.contains(forbidden), "%s hides %s" % [label, forbidden])


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Campaign privacy test passed.")
	else:
		push_error("Campaign privacy test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
