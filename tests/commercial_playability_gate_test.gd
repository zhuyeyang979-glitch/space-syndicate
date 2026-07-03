extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const VIEWPORT_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1600, 960),
	Vector2i(1920, 1080),
]

const FORBIDDEN_PLAYER_FACING_TOKENS := [
	"ai_reason",
	"ai_utility_score",
	"route_plan_score",
	"pressure bucket",
	"decision_samples",
	"learning_bonus",
	"true_owner",
	"hidden_owner",
	"owner_truth",
	"opponent cash",
	"opponent hand",
	"rival exact hand",
	"private route plan",
	"ai private plan",
	"ai 私有计划",
	"对手现金",
	"对手手牌",
	"开发原则",
	"测试阶段优先",
	"prototype",
	"debug",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_gate_documentation()
	for viewport_size in VIEWPORT_SIZES:
		await _check_first_table_runtime_layout(viewport_size)
	await _check_first_run_cta_forgives_missing_region()
	await _check_first_ten_minute_action_chain()
	_finish()


func _check_gate_documentation() -> void:
	_expect(FileAccess.file_exists("res://docs/commercial_playability_gate.md"), "commercial playability gate document exists")
	var source := FileAccess.get_file_as_string("res://docs/commercial_playability_gate.md")
	for marker in ["真人首局", "真实 RuntimeGameScreen", "单主 CTA", "隐藏信息", "1280×720"]:
		_expect(source.contains(marker), "commercial gate document explains %s" % marker)


func _check_first_table_runtime_layout(viewport_size: Vector2i) -> void:
	root.size = viewport_size
	var main := await _instantiate_main()
	if main == null:
		return
	main.call("_start_campaign_chapter", "01_first_table")
	await _wait_frames(16)
	_select_recommended_district(main)
	await _wait_frames(8)
	var runtime := main.find_child("RuntimeGameScreen", true, false) as Control
	_expect(runtime != null and runtime.visible, "%s first-table chapter enters real RuntimeGameScreen" % _size_label(viewport_size))
	if runtime != null:
		_check_core_table_regions(main, runtime, viewport_size)
		_check_runtime_focus_order(runtime, ["顶部状态", "牌轨", "星球地图", "右侧详情", "手牌", "当前行动", "竞价"], "%s closed-rack table" % _size_label(viewport_size))
		_check_single_primary_campaign_cta(main, viewport_size)
		_check_player_facing_privacy(runtime, viewport_size)
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(1)


func _check_first_ten_minute_action_chain() -> void:
	root.size = Vector2i(1600, 960)
	var main := await _instantiate_main()
	if main == null:
		return
	main.call("_start_campaign_chapter", "02_market_hand")
	await _wait_frames(16)
	_select_recommended_district(main)
	await _wait_frames(4)
	_expect(bool(main.call("_activate_first_run_coach_action", "coach_first_summon")), "first ten-minute path can perform first summon from coach")
	await _wait_frames(12)
	_expect(bool(main.call("_activate_first_run_coach_action", "coach_open_rack")), "first ten-minute path can open district card rack from coach")
	await _wait_frames(8)
	var runtime := main.find_child("RuntimeGameScreen", true, false) as Control
	var ui_text := _node_text(runtime)
	_expect(ui_text.contains("牌架") and ui_text.contains("手牌"), "first ten-minute path keeps card rack and hand concepts visible together")
	_check_runtime_focus_order(runtime, ["顶部状态", "牌轨", "星球地图", "右侧详情", "区域牌架", "手牌", "当前行动", "竞价"], "first ten-minute opened-rack table")
	_check_player_facing_privacy(runtime, Vector2i(1600, 960))
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(1)


func _check_first_run_cta_forgives_missing_region() -> void:
	root.size = Vector2i(1600, 960)
	var main := await _instantiate_main()
	if main == null:
		return
	main.call("_new_game")
	await _wait_frames(12)
	main.set("selected_district", -1)
	main.set("district_supply_open_district", -1)
	main.set("district_supply_open_player", -1)
	_expect(bool(main.call("_activate_first_run_coach_action", "coach_open_rack")), "first-run CTA can auto-select a recommended region before opening the rack")
	await _wait_frames(8)
	var selected := int(main.get("selected_district"))
	var open_district := int(main.get("district_supply_open_district"))
	var open_player := int(main.get("district_supply_open_player"))
	_expect(selected >= 0 and open_district == selected and open_player == 0, "first-run rack CTA lands on the selected recommended region for the local player selected=%d open=%d player=%d" % [selected, open_district, open_player])
	_expect_first_run_focus_pulse(main, "district_supply", "牌架", "first-run rack CTA enters a strong focus state on the opened card rack")
	var snapshot_variant: Variant = main.call("_runtime_table_snapshot") if main.has_method("_runtime_table_snapshot") else {}
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	var coach: Dictionary = snapshot.get("first_run_coach", {}) if snapshot.get("first_run_coach", {}) is Dictionary else {}
	_expect(str(coach.get("focus_target", "")).strip_edges() != "", "first-run coach keeps a focus target after auto-positioning")
	_expect(str(coach.get("stuck_state", "")).strip_edges() == "strong" and bool(coach.get("pulse_focus", false)), "first-run coach data exposes a temporary strong focus state after CTA auto-positioning")
	await _expect_runtime_map_centered_on_district(main, open_district, "first-run rack CTA rotates the central planet to the opened region")
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(1)

	var buy_main := await _instantiate_main()
	if buy_main == null:
		return
	buy_main.call("_new_game")
	await _wait_frames(12)
	_expect(bool(buy_main.call("_activate_first_run_coach_action", "coach_first_summon")), "first-run buy recovery setup can summon the starter monster")
	await _wait_frames(12)
	_expect_first_run_focus_pulse(buy_main, "action_dock", "行动", "first-run first-summon CTA pulses the next city/action area")
	var wrong_district := _first_non_buyable_district(buy_main)
	if wrong_district >= 0:
		buy_main.set("selected_district", wrong_district)
		buy_main.set("district_supply_open_district", -1)
		buy_main.set("district_supply_open_player", -1)
		var hand_before := _local_hand_size(buy_main)
		_expect(bool(buy_main.call("_activate_first_run_coach_action", "coach_buy_card")), "first-run Buy CTA can recover from a non-buyable selected region")
		await _wait_frames(12)
		var recovered_district := int(buy_main.get("district_supply_open_district"))
		_expect(recovered_district >= 0 and bool(buy_main.call("_can_buy_card_from_district", recovered_district, 0)), "first-run Buy CTA reopens a legal monster-accessible card rack")
		await _expect_runtime_map_centered_on_district(buy_main, recovered_district, "first-run Buy CTA rotates the central planet to the recovered legal rack")
		_expect_first_run_focus_pulse(buy_main, "district_supply", "牌架", "first-run Buy CTA pulses the recovered legal card rack")
		_expect(_local_hand_size(buy_main) >= hand_before, "first-run Buy CTA does not lose local hand cards while recovering from the wrong region")
	root.remove_child(buy_main)
	buy_main.queue_free()
	await _wait_frames(1)


func _expect_first_run_focus_pulse(main: Node, expected_target: String, label_hint: String, message: String) -> void:
	var focus_layer := _find_node_with_method(main, "get_focus_debug_snapshot")
	_expect(focus_layer != null, "%s has a FocusGuideLayer debug snapshot" % message)
	if focus_layer == null:
		return
	var snapshot_variant: Variant = focus_layer.call("get_focus_debug_snapshot")
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	var label := str(snapshot.get("label", ""))
	_expect(bool(snapshot.get("visible", false)), "%s is visible" % message)
	_expect(bool(snapshot.get("pulse_focus", false)), "%s pulses the target frame" % message)
	_expect(str(snapshot.get("focus_target", "")) == expected_target, "%s targets %s" % [message, expected_target])
	_expect(label.contains("最短") and label.contains(label_hint), "%s uses shortest-action copy instead of long help text" % message)


func _instantiate_main() -> Node:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main.tscn loads for commercial playability gate")
	if packed == null:
		return null
	var main := packed.instantiate()
	root.add_child(main)
	await _wait_frames(8)
	main.set("campaign_completed_chapter_ids", [])
	main.set("selected_campaign_chapter_id", "")
	main.set("active_campaign_chapter_id", "")
	return main


func _first_non_buyable_district(main: Node) -> int:
	var districts: Array = main.get("districts") as Array
	for i in range(districts.size()):
		if bool((districts[i] as Dictionary).get("destroyed", false)):
			continue
		if not bool(main.call("_can_buy_card_from_district", i, 0)):
			return i
	return -1


func _local_hand_size(main: Node) -> int:
	var players: Array = main.get("players") as Array
	if players.is_empty() or not (players[0] is Dictionary):
		return 0
	return ((players[0] as Dictionary).get("slots", []) as Array).size()


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


func _check_core_table_regions(main: Node, runtime: Control, viewport_size: Vector2i) -> void:
	var label := _size_label(viewport_size)
	var top_bar := _control(main, "TopBar")
	var public_track := _control(main, "PublicTrack")
	var planet_board := _control(main, "PlanetBoard")
	var stage := _control(main, "PlanetStageViewport")
	var map_host := _control(main, "MapHost")
	var inspector := _control(main, "RightInspector")
	var player_board := _control(main, "PlayerBoard")
	var hand_rack := _control(main, "HandRack")
	var action_dock := _control(main, "PlayerMainActionDock")
	for pair in [
		["TopBar", top_bar],
		["PublicTrack", public_track],
		["PlanetBoard", planet_board],
		["PlanetStageViewport", stage],
		["MapHost", map_host],
		["RightInspector", inspector],
		["PlayerBoard", player_board],
		["HandRack", hand_rack],
		["PlayerMainActionDock", action_dock],
	]:
		_expect(pair[1] != null and (pair[1] as Control).is_visible_in_tree(), "%s %s is visible on the live table" % [label, pair[0]])
	if planet_board == null or public_track == null or player_board == null or stage == null or map_host == null:
		return
	var runtime_rect := runtime.get_global_rect()
	var track_rect := public_track.get_global_rect()
	var planet_rect := planet_board.get_global_rect()
	var stage_rect := stage.get_global_rect()
	var map_rect := map_host.get_global_rect()
	var player_rect := player_board.get_global_rect()
	_expect(_rect_inside(public_track, runtime_rect), "%s public track stays inside the table safe area" % label)
	_expect(_rect_inside(planet_board, runtime_rect), "%s planet board stays inside the table safe area" % label)
	_expect(_rect_inside(player_board, runtime_rect), "%s player board stays inside the table safe area" % label)
	_expect(track_rect.size.y <= float(viewport_size.y) * 0.085, "%s card/event timeline remains a thin table rail" % label)
	_expect(player_rect.size.y >= 168.0 and player_rect.size.y <= float(viewport_size.y) * 0.34, "%s hand/action board is visible but does not consume the table" % label)
	_expect(planet_rect.size.y >= float(viewport_size.y) * 0.38, "%s planet board keeps the main visual weight" % label)
	_expect(stage_rect.size.y >= float(viewport_size.y) * 0.30, "%s planet stage has playable vertical space" % label)
	_expect(map_rect.size.x >= minf(stage_rect.size.x, stage_rect.size.y) * 0.62 and map_rect.size.y >= minf(stage_rect.size.x, stage_rect.size.y) * 0.62, "%s globe/map remains prominent inside the planet stage" % label)
	_expect(not track_rect.intersects(player_rect), "%s timeline does not overlap the hand board" % label)
	_expect(not planet_rect.intersects(player_rect), "%s planet board does not overlap the hand board" % label)
	if inspector != null:
		_expect(inspector.get_global_rect().size.x <= 330.0, "%s campaign focus keeps the right detail drawer compact" % label)


func _check_runtime_focus_order(runtime: Control, expected_labels: Array[String], message: String) -> void:
	_expect(runtime != null and runtime.has_method("runtime_focus_order_snapshot"), "%s exposes runtime focus-order snapshot" % message)
	if runtime == null or not runtime.has_method("runtime_focus_order_snapshot"):
		return
	var snapshot: Array = runtime.call("runtime_focus_order_snapshot")
	_expect(snapshot.size() == expected_labels.size(), "%s has exactly the expected table focus regions" % message)
	var seen := {}
	for index in range(expected_labels.size()):
		var item: Dictionary = snapshot[index] if index < snapshot.size() and snapshot[index] is Dictionary else {}
		var label := str(item.get("label", ""))
		_expect(label == expected_labels[index], "%s focus slot %d is %s" % [message, index + 1, expected_labels[index]])
		_expect(not seen.has(label), "%s focus slot %d is not duplicated" % [message, index + 1])
		seen[label] = true
		_expect(int(item.get("index", -1)) == index, "%s focus slot %d keeps a stable index" % [message, index + 1])
		_expect(int(item.get("focus_mode", Control.FOCUS_NONE)) == Control.FOCUS_ALL, "%s focus slot %d is keyboard/gamepad reachable" % [message, index + 1])
		_expect(str(item.get("focus_next", "")) != "" and str(item.get("focus_previous", "")) != "", "%s focus slot %d links next/previous focus" % [message, index + 1])
		_expect(bool(item.get("visible", false)), "%s focus slot %d is visible" % [message, index + 1])


func _check_single_primary_campaign_cta(main: Node, viewport_size: Vector2i) -> void:
	var label := _size_label(viewport_size)
	var coach := _control(main, "ScenarioCoach")
	_expect(coach != null and coach.visible, "%s scenario coach is visible" % label)
	if coach == null:
		return
	var visible_buttons := _visible_buttons(coach)
	_expect(visible_buttons.size() == 1, "%s scenario coach exposes one primary CTA, not a button wall" % label)
	var goal_label := coach.find_child("ScenarioCoachGoal", true, false) as Label
	var primary_button := coach.find_child("ScenarioCoachPrimaryButton", true, false) as Button
	_expect(goal_label != null and goal_label.text.length() > 0 and goal_label.text.length() <= 42, "%s current objective is short enough to read at a glance" % label)
	_expect(primary_button != null and primary_button.text.length() > 0 and primary_button.text.length() <= 10, "%s primary CTA label is short" % label)


func _check_player_facing_privacy(runtime: Control, viewport_size: Vector2i) -> void:
	if runtime == null:
		return
	var label := _size_label(viewport_size)
	var ui_text := _node_text(runtime).to_lower()
	for forbidden in FORBIDDEN_PLAYER_FACING_TOKENS:
		_expect(not ui_text.contains(forbidden.to_lower()), "%s player-facing runtime hides %s" % [label, forbidden])


func _select_recommended_district(main: Node) -> void:
	var district_index := int(main.call("_first_run_recommended_start_district", 0))
	_expect(district_index >= 0, "commercial gate finds a recommended playable district")
	if district_index >= 0:
		main.call("_select_district", district_index)


func _control(root_node: Node, node_name: String) -> Control:
	return root_node.find_child(node_name, true, false) as Control


func _rect_inside(control: Control, parent_rect: Rect2) -> bool:
	if control == null:
		return false
	var rect := control.get_global_rect()
	return rect.position.x >= parent_rect.position.x - 1.0 \
		and rect.position.y >= parent_rect.position.y - 1.0 \
		and rect.end.x <= parent_rect.end.x + 1.0 \
		and rect.end.y <= parent_rect.end.y + 1.0


func _visible_buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button and (node as Button).is_visible_in_tree():
		result.append(node as Button)
	for child in node.get_children():
		result.append_array(_visible_buttons(child))
	return result


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


func _size_label(viewport_size: Vector2i) -> String:
	return "%dx%d" % [viewport_size.x, viewport_size.y]


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
		print("Commercial playability gate passed.")
	else:
		push_error("Commercial playability gate failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
