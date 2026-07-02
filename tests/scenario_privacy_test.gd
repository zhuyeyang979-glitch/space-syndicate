extends SceneTree

const LOG_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/scenario_action_log_snapshot.gd")
const ACTION_LOG_SCENE := preload("res://scenes/ui/ScenarioActionLog.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var raw_log := {
		"title": "隐私测试日志",
		"viewer_index": 0,
		"entries": [
			{"time": "00:01", "phase_id": "public", "public_text": "有人打出一张匿名牌", "private_text": "你打出：轨道融资", "viewer_index": 0, "developer_text": "ai_route_plan=greedy"},
			{"time": "00:02", "phase_id": "rival", "public_text": "对手发生一次公开行动", "private_text": "对手现金 9999 / 手牌 5", "viewer_index": 2, "developer_text": "true_owner=player3"},
		],
	}
	var snapshot: Dictionary = LOG_SNAPSHOT_SCRIPT.new().apply_dictionary(raw_log).to_ui_dictionary()
	var text := var_to_str(snapshot)
	_expect(text.contains("你打出：轨道融资"), "current player private_text is visible to that player")
	for forbidden in ["对手现金", "手牌 5", "ai_route_plan", "true_owner", "developer_text"]:
		_expect(not text.contains(forbidden), "player-facing scenario log hides %s" % forbidden)
	var node := ACTION_LOG_SCENE.instantiate() as Control
	get_root().add_child(node)
	node.call("set_log", snapshot)
	await process_frame
	var ui_text := _node_text(node)
	for forbidden in ["对手现金", "手牌 5", "ai_route_plan", "true_owner", "developer_text"]:
		_expect(not ui_text.contains(forbidden), "ScenarioActionLog UI hides %s" % forbidden)
	node.queue_free()
	if _failures.is_empty():
		print("Scenario privacy test passed.")
	else:
		push_error("Scenario privacy test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())


func _node_text(node: Node) -> String:
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
