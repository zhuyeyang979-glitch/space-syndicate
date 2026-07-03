extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_public_track_focus_selects_without_fake_completion()
	await _check_market_focus_opens_real_rack_and_rotates_planet()
	_finish()


func _check_public_track_focus_selects_without_fake_completion() -> void:
	var main := await _instantiate_main()
	if main == null:
		return
	main.call("_start_campaign_chapter", "03_public_track")
	await _wait_frames(10)
	_expect(bool(main.call("_activate_scenario_action", "scenario_focus_target")), "public-track focus action is accepted")
	await _wait_frames(6)
	_expect(int(main.get("selected_card_resolution_id")) >= 0, "public-track focus selects a visible track card for the player")
	var completed: Dictionary = main.get("scenario_completed_signals") as Dictionary
	_expect(not bool(completed.get("track_selected", false)), "public-track focus does not fake-complete the track-selected success signal")
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(1)


func _check_market_focus_opens_real_rack_and_rotates_planet() -> void:
	var main := await _instantiate_main()
	if main == null:
		return
	main.call("_start_campaign_chapter", "02_market_hand")
	await _wait_frames(10)
	main.set("selected_district", -1)
	main.set("district_supply_open_district", -1)
	main.set("district_supply_open_player", -1)
	_expect(bool(main.call("_activate_scenario_action", "scenario_focus_target")), "market focus action is accepted")
	await _wait_frames(8)
	var open_district := int(main.get("district_supply_open_district"))
	var open_player := int(main.get("district_supply_open_player"))
	_expect(open_district >= 0 and open_player == 0, "market focus opens a real local-player district supply rack")
	_expect_runtime_map_centered_on_district(main, open_district, "market focus rotates the central planet to the opened rack")
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(1)


func _instantiate_main() -> Node:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main.tscn loads for scenario focus navigation")
	if packed == null:
		return null
	var main := packed.instantiate()
	root.add_child(main)
	await _wait_frames(8)
	main.set("campaign_completed_chapter_ids", [])
	main.set("selected_campaign_chapter_id", "")
	main.set("active_campaign_chapter_id", "")
	return main


func _expect_runtime_map_centered_on_district(main: Node, district_index: int, message: String) -> void:
	var map_node := _find_node_with_method(main, "get_projection_debug_snapshot")
	_expect(map_node != null, "%s has a runtime MapView debug snapshot" % message)
	if map_node == null or district_index < 0:
		return
	var districts: Array = main.get("districts") as Array
	if district_index >= districts.size() or not (districts[district_index] is Dictionary):
		_expect(false, "%s has a valid target district" % message)
		return
	var snapshot_variant: Variant = map_node.call("get_projection_debug_snapshot")
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	var center: Vector2 = snapshot.get("view_center_m", Vector2(-999999.0, -999999.0))
	var target: Vector2 = (districts[district_index] as Dictionary).get("center", Vector2.ZERO)
	_expect(center.distance_to(target) <= 1.0, message)


func _find_node_with_method(node: Node, method_name: String) -> Node:
	if node == null:
		return null
	if node.has_method(method_name):
		return node
	for child in node.get_children():
		var found := _find_node_with_method(child, method_name)
		if found != null:
			return found
	return null


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
		print("Scenario focus navigation test passed.")
	else:
		push_error("Scenario focus navigation test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
