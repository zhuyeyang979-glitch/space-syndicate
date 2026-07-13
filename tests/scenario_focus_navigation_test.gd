extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const COACH_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/scenario_coach_snapshot.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_public_track_focus_selects_without_fake_completion()
	await _check_stuck_primary_cta_uses_focus_navigation()
	await _check_market_focus_opens_real_rack_and_rotates_planet()
	await _check_track_card_selection_rotates_to_public_target_region()
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
	var completed: Dictionary = _runtime_scenario_state(main).get("completed_signals", {})
	_expect(not bool(completed.get("track_selected", false)), "public-track focus does not fake-complete the track-selected success signal")
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(1)


func _check_stuck_primary_cta_uses_focus_navigation() -> void:
	var main := await _instantiate_main()
	if main == null:
		return
	main.call("_start_campaign_chapter", "03_public_track")
	await _wait_frames(10)
	_expect(bool(main.call("_activate_scenario_action", "scenario_hint")), "scenario hint records a stuck/help request")
	await _wait_frames(4)
	var source: Dictionary = main.call("_runtime_scenario_coach_snapshot_source", 0) as Dictionary
	var ui: Dictionary = COACH_SNAPSHOT_SCRIPT.new().apply_dictionary(source).to_ui_dictionary()
	var primary: Dictionary = ui.get("primary_action", {}) if ui.get("primary_action", {}) is Dictionary else {}
	_expect(bool(ui.get("help_visible", false)), "stuck scenario coach shows help after a hint request")
	_expect(str(primary.get("id", "")) == "scenario_focus_target" and str(primary.get("label", "")) == "定位下一步", "stuck scenario primary CTA is the real focus action")
	_expect(bool(main.call("_activate_scenario_action", "scenario_hint")), "a repeated scenario hint records a stronger stuck request")
	await _wait_frames(4)
	source = main.call("_runtime_scenario_coach_snapshot_source", 0) as Dictionary
	ui = COACH_SNAPSHOT_SCRIPT.new().apply_dictionary(source).to_ui_dictionary()
	primary = ui.get("primary_action", {}) if ui.get("primary_action", {}) is Dictionary else {}
	_expect(str(ui.get("stuck_state", "")) == "strong", "repeated stuck scenario enters strong stuck state")
	_expect(bool(ui.get("pulse_focus", false)), "strong stuck scenario requests a pulsing focus guide")
	_expect(str(ui.get("shortest_action_text", "")).strip_edges() != "", "strong stuck scenario exposes a shortest next action")
	var focus_guide := _find_node_with_method(main, "get_focus_debug_snapshot")
	if focus_guide != null:
		var focus_snapshot: Dictionary = focus_guide.call("get_focus_debug_snapshot") as Dictionary
		_expect(bool(focus_snapshot.get("pulse_focus", false)), "strong stuck focus guide pulses the target region")
		_expect(str(focus_snapshot.get("label", "")).contains("最短"), "strong stuck focus guide label uses shortest-action wording")
	else:
		_expect(false, "strong stuck focus guide exposes a debug snapshot")
	_expect(str(primary.get("id", "")) == "scenario_focus_target" and str(primary.get("label", "")) == "定位下一步", "strong stuck scenario primary CTA remains the real focus action")
	_expect(bool(main.call("_activate_scenario_action", str(primary.get("id", "")))), "stuck primary focus action is accepted")
	await _wait_frames(6)
	_expect(int(main.get("selected_card_resolution_id")) >= 0, "stuck primary focus action selects a visible track card")
	var completed: Dictionary = _runtime_scenario_state(main).get("completed_signals", {})
	_expect(not bool(completed.get("track_selected", false)), "stuck primary focus action does not fake-complete the success signal")
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
	await _expect_runtime_map_centered_on_district(main, open_district, "market focus rotates the central planet to the opened rack")
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(1)


func _check_track_card_selection_rotates_to_public_target_region() -> void:
	var main := await _instantiate_main()
	if main == null:
		return
	main.call("_start_campaign_chapter", "02_market_hand")
	await _wait_frames(10)
	var districts: Array = main.get("districts") as Array
	if districts.size() < 2:
		_expect(false, "card-track target rotation needs at least two districts")
		root.remove_child(main)
		main.queue_free()
		await _wait_frames(1)
		return
	var map_node := _find_node_with_method(main, "get_projection_debug_snapshot")
	_expect(map_node != null, "card-track target rotation has a runtime MapView")
	if map_node == null:
		root.remove_child(main)
		main.queue_free()
		await _wait_frames(1)
		return
	var origin := 0
	var target := _farthest_district_from(main, origin, map_node)
	if target < 0:
		_expect(false, "card-track target rotation found a different target district")
		root.remove_child(main)
		main.queue_free()
		await _wait_frames(1)
		return
	var origin_center: Vector2 = (districts[origin] as Dictionary).get("center", Vector2.ZERO)
	map_node.call("reset_to_planet_overview")
	map_node.set("_view_center_m", origin_center)
	map_node.set("_view_zoom", 0.34)
	map_node.set("_target_view_zoom", 0.34)
	main.set("selected_district", origin)
	main.set("selected_card_resolution_id", -1)
	var skill_variant: Variant = main.call("_make_skill", "生产扩张1")
	var skill: Dictionary = skill_variant if skill_variant is Dictionary else {"name": "生产扩张1", "kind": "region_economy_shift"}
	var resolution_id := 987321
	var entry := {
		"resolution_id": resolution_id,
		"queued_order": resolution_id,
		"player_index": 1,
		"selected_district": target,
		"selected_trade_product": "",
		"tip": 30,
		"winning_bid": 30,
		"public_owner_revealed": false,
		"skill": skill,
	}
	main.set("resolved_card_history", [entry])
	main.call("_select_card_resolution_track_entry", resolution_id)
	await _wait_frames(2)
	_expect(int(main.get("selected_card_resolution_id")) == resolution_id, "card-track target rotation keeps the public card selected")
	await _expect_runtime_map_centered_on_district(main, target, "selecting a public card rotates the central planet to its target region")
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


func _runtime_scenario_state(main: Node) -> Dictionary:
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if main != null else null
	var value: Variant = coordinator.call("runtime_scenario_state", float(main.get("game_time"))) if coordinator != null else {}
	return value as Dictionary if value is Dictionary else {}


func _farthest_district_from(main: Node, origin: int, map_node: Node) -> int:
	var districts: Array = main.get("districts") as Array
	if origin < 0 or origin >= districts.size():
		return -1
	var origin_center: Vector2 = (districts[origin] as Dictionary).get("center", Vector2.ZERO)
	var best_index := -1
	var best_distance := -1.0
	for i in range(districts.size()):
		if i == origin or not (districts[i] is Dictionary):
			continue
		var center: Vector2 = (districts[i] as Dictionary).get("center", origin_center)
		var distance := float(map_node.call("_surface_distance", origin_center, center))
		if distance > best_distance:
			best_distance = distance
			best_index = i
	return best_index


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
	var focus_target: Vector2 = snapshot.get("focus_target_center_m", Vector2(-999999.0, -999999.0))
	_expect(int(snapshot.get("focus_target_district", -1)) == district_index, "%s records the target district for a visible planet rotation" % message)
	_expect(focus_target.distance_to(target) <= 1.0, "%s records the target region center before the rotation finishes" % message)
	if center.distance_to(target) > 1.0:
		_expect(bool(snapshot.get("focus_rotation_active", false)), "%s starts an animated planet rotation instead of silently jumping" % message)
	for _frame in range(180):
		await process_frame
		snapshot_variant = map_node.call("get_projection_debug_snapshot")
		snapshot = snapshot_variant if snapshot_variant is Dictionary else {}
		center = snapshot.get("view_center_m", Vector2(-999999.0, -999999.0))
		if center.distance_to(target) <= 1.0 and not bool(snapshot.get("focus_rotation_active", false)):
			break
	snapshot_variant = map_node.call("get_projection_debug_snapshot")
	snapshot = snapshot_variant if snapshot_variant is Dictionary else {}
	center = snapshot.get("view_center_m", Vector2(-999999.0, -999999.0))
	_expect(center.distance_to(target) <= 1.0, message)
	_expect(not bool(snapshot.get("focus_rotation_active", false)), "%s finishes the region rotation" % message)


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
