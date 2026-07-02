extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main.tscn loads for campaign visual bridge")
	if packed == null:
		_finish()
		return
	root.size = Vector2i(1600, 960)
	var main := packed.instantiate()
	root.add_child(main)
	await _wait_frames(6)
	main.call("_start_campaign_chapter", "01_first_table")
	await _wait_frames(8)
	var district_index := int(main.call("_first_run_recommended_start_district", 0))
	main.call("_select_district", district_index)
	await _wait_frames(4)
	var screen := main.find_child("RuntimeGameScreen", true, false)
	_expect(screen != null, "RuntimeGameScreen exists after campaign start")
	var visual_layer := main.find_child("RuntimeVisualEventLayer", true, false)
	_expect(visual_layer != null, "real GameScreen mounts RuntimeVisualEventLayer")
	var snapshot: Dictionary = {}
	if screen != null and screen.has_method("get_visual_event_snapshot"):
		snapshot = screen.call("get_visual_event_snapshot") as Dictionary
	var events: Array = snapshot.get("events", []) if snapshot.get("events", []) is Array else []
	var classes: Array = snapshot.get("event_classes", []) if snapshot.get("event_classes", []) is Array else []
	_expect(not events.is_empty(), "scenario visual_events reach the real runtime VisualEventLayer")
	_expect(classes.has("card_play") or classes.has("card_reveal") or classes.has("monster_spawn") or classes.has("gdp_delta"), "runtime visual events expose recognizable commercial event classes")
	_expect(_events_are_hidden_info_safe(events), "runtime visual_events do not carry hidden/private ownership payload")
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(1)
	_finish()


func _events_are_hidden_info_safe(events: Array) -> bool:
	var forbidden := ["true_owner", "hidden_owner", "owner_truth", "private_cash", "opponent_hand", "ai_score"]
	for event_variant in events:
		if not (event_variant is Dictionary):
			continue
		var text := var_to_str(event_variant).to_lower()
		for token in forbidden:
			if text.contains(token):
				return false
	return true


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
		print("Campaign visual event bridge test passed.")
	else:
		push_error("Campaign visual event bridge test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
