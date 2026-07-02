extends SceneTree

const RIGHT_INSPECTOR_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/right_inspector_snapshot.gd")
const FIRST_RUN_COACH_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/first_run_coach_snapshot.gd")
const MAIN_SCENE_PATH := "res://scenes/main.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_right_inspector_snapshot_density()
	_check_first_run_coach_density()
	_check_player_facing_source_guards()
	await _check_default_scenario_coach_stays_off_planet()
	_finish()


func _check_right_inspector_snapshot_density() -> void:
	var long_text := "这是一个故意写得很长的说明，用来模拟开发过程中把完整规则、推理理由、区域说明和操作解释全部塞进右侧主桌的坏情况。"
	var snapshot: Dictionary = RIGHT_INSPECTOR_SNAPSHOT_SCRIPT.new().apply_dictionary({
		"why": long_text,
		"district": {
			"title": "雾港区",
			"detail": long_text,
		},
		"requirements": [{"text": "怪兽邻近"}, {"text": "现金足够"}],
	}).to_ui_dictionary()
	_expect(str(snapshot.get("why", "")).length() <= 49, "right inspector why line stays one-glance")
	var district: Dictionary = snapshot.get("district", {}) if snapshot.get("district", {}) is Dictionary else {}
	_expect(str(district.get("summary", "")).length() <= 45, "right inspector district summary stays one-glance")
	_expect(str(district.get("full_detail", "")).length() > str(district.get("summary", "")).length(), "right inspector preserves full detail outside the table summary")


func _check_first_run_coach_density() -> void:
	for stage in [
		"select_district",
		"first_summon",
		"build_city",
		"open_rack",
		"buy_card",
		"play_card",
		"inspect_track",
		"inspect_clues",
	]:
		var snapshot: Dictionary = FIRST_RUN_COACH_SNAPSHOT_SCRIPT.new().apply_dictionary({
			"visible": true,
			"stage": stage,
			"progress": {},
		}).to_ui_dictionary()
		_expect(str(snapshot.get("body", "")).length() <= 18, "first-run coach stage %s uses a short action sentence" % stage)
		_expect(str(snapshot.get("title", "")).length() <= 14, "first-run coach stage %s title is compact" % stage)


func _check_player_facing_source_guards() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var game_screen_source := FileAccess.get_file_as_string("res://scripts/ui/game_screen.gd")
	var inspector_source := FileAccess.get_file_as_string("res://scripts/ui/right_inspector.gd")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/overlay_layer.gd")
	var tutorial_source := FileAccess.get_file_as_string("res://scripts/ui/tutorial_quick_start_board.gd")
	var rules_source := FileAccess.get_file_as_string("res://scripts/ui/rules_quick_reference_board.gd")
	var snapshot_source := FileAccess.get_file_as_string("res://scripts/viewmodels/right_inspector_snapshot.gd")
	var bid_board_scene := FileAccess.get_file_as_string("res://scenes/ui/BidBoard.tscn")
	_expect(snapshot_source.contains("WHY_TEXT_CHAR_LIMIT := 48") and snapshot_source.contains("DETAIL_SUMMARY_CHAR_LIMIT := 44"), "right inspector snapshot has strict scan-first limits")
	_expect(inspector_source.contains("WHY_TEXT_CHAR_LIMIT := 48") and inspector_source.contains("SUMMARY_TEXT_CHAR_LIMIT := 44"), "right inspector UI has strict scan-first limits")
	_expect(overlay_source.contains("TEMP_DECISION_BODY_LIMIT := 72") and overlay_source.contains("SIDE_DRAWER_SECTION_BODY_LIMIT := 132"), "overlay modals/drawers cap visible prose")
	_expect(overlay_source.contains("TEMP_DECISION_SIDE_ANCHOR_LEFT := 0.70") and overlay_source.contains("_dock_confirm_to_planet_side_lane"), "temporary decision overlays dock to a planet side lane instead of the table center")
	_expect(tutorial_source.contains("_short_text(body_text, 34)") and tutorial_source.contains("_short_text(meta_text, 28)"), "tutorial cards use short visible copy")
	_expect(rules_source.contains("_short_text(body_text, 34)") and rules_source.contains("_short_text(meta_text, 28)"), "rules quick-reference cards use short visible copy")
	_expect(not main_source.contains("当前位置：主菜单"), "menu breadcrumb prose is not shown as player-facing navigation copy")
	_expect(not main_source.contains("所有牌都会公开展示，出牌者匿名"), "rules menu no longer repeats long prose in the page body")
	_expect(main_source.contains("第一局只做四件事：首召、建城、买牌、出牌。"), "tutorial menu opens with one-line first-game guidance")
	_expect(game_screen_source.contains("0.635, 0.145, 0.790, 0.285"), "default scenario coach uses the planet side lane instead of the table center")
	_expect(not bid_board_scene.contains("下一张匿名牌可预设公开报价"), "bid board does not over-explain anonymity in the always-visible table text")
	_expect(not main_source.contains("预设匿名报价"), "bid tooltips use compact public-bid wording")


func _check_default_scenario_coach_stays_off_planet() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main scene loads for scenario coach readability check")
	if packed == null:
		return
	root.size = Vector2i(1600, 960)
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	if main.has_method("_start_scenario_from_menu"):
		main.call("_start_scenario_from_menu", "first_table")
	await process_frame
	await process_frame
	await process_frame
	var map_host := main.find_child("MapHost", true, false) as Control
	var coach_host := main.find_child("ScenarioCoachHost", true, false) as Control
	var first_run_coach := main.find_child("FirstRunCoach", true, false) as Control
	var right_inspector := main.find_child("RightInspector", true, false) as Control
	var overlay := main.find_child("OverlayLayer", true, false)
	_expect(map_host != null and coach_host != null, "scenario coach and map host exist in runtime")
	if map_host != null and coach_host != null:
		var map_rect := map_host.get_global_rect()
		var coach_rect := coach_host.get_global_rect()
		var planet_core_rect := Rect2(
			map_rect.position + Vector2(map_rect.size.x * 0.24, map_rect.size.y * 0.08),
			Vector2(map_rect.size.x * 0.52, map_rect.size.y * 0.84)
		)
		var coach_center_x := coach_rect.position.x + coach_rect.size.x * 0.5
		var map_center_x := map_rect.position.x + map_rect.size.x * 0.5
		_expect(coach_rect.size.x <= 270.0, "default scenario coach remains a compact side card")
		_expect(absf(coach_center_x - map_center_x) >= map_rect.size.x * 0.22, "default scenario coach sits in a left/right planet side lane")
		_expect(not coach_rect.intersects(planet_core_rect), "default scenario coach does not cover the central planet body")
		if right_inspector != null:
			_expect(not coach_rect.intersects(right_inspector.get_global_rect()), "default scenario coach does not cover the right inspector")
		if overlay != null and overlay.has_method("show_temporary_decision"):
			overlay.call("show_temporary_decision", {
				"title": "签约选择",
				"body": "这类临时选择要在桌边处理，不遮挡星球主体。",
				"actions": [{"id": "accept", "label": "签"}, {"id": "decline", "label": "拒"}],
			})
			await process_frame
			var decision_panel := main.find_child("TemporaryDecisionModal", true, false) as Control
			_expect(decision_panel != null, "temporary decision modal can be shown in runtime")
			if decision_panel != null:
				var decision_rect := decision_panel.get_global_rect()
				_expect(decision_rect.get_center().x > map_center_x, "temporary decision modal uses the right side of the table")
				_expect(not decision_rect.intersects(planet_core_rect), "temporary decision modal does not cover the central planet body")
	_expect(first_run_coach != null and not first_run_coach.visible, "scenario runtime hides the generic first-run coach so only one CTA card is on the table")
	root.remove_child(main)
	main.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("Playtest readability gate failure: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Playtest readability gate passed.")
		quit(0)
	else:
		print("Playtest readability gate failed: %s" % " / ".join(_failures))
		quit(1)
