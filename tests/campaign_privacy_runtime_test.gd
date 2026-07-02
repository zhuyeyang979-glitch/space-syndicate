extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main.tscn loads for runtime privacy test")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	root.add_child(main)
	await _wait_frames(6)
	main.call("_start_campaign_chapter", "03_public_track")
	await _wait_frames(8)
	main.call("_activate_scenario_action", "scenario_step_select_track_card")
	await _wait_frames(4)
	var screen := main.find_child("RuntimeGameScreen", true, false)
	var ui_text := _node_text(screen).to_lower()
	for forbidden in ["opponent cash", "对手现金", "opponent hand", "对手手牌", "ai 私有计划", "ai private plan", "true_owner", "hidden_owner", "owner_truth", "ai_score", "ai_reason"]:
		_expect(not ui_text.contains(forbidden), "runtime campaign UI hides %s" % forbidden)
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(1)
	_finish()


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
		print("Campaign runtime privacy test passed.")
	else:
		push_error("Campaign runtime privacy test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
