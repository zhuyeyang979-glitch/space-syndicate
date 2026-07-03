extends SceneTree

const RIGHT_INSPECTOR_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/right_inspector_snapshot.gd")
const FIRST_RUN_COACH_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/first_run_coach_snapshot.gd")
const SCENARIO_COACH_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/scenario_coach_snapshot.gd")
const MAIN_SCENE_PATH := "res://scenes/main.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_right_inspector_snapshot_density()
	_check_first_run_coach_density()
	_check_scenario_coach_empty_state()
	_check_player_facing_source_guards()
	await _check_first_run_coach_stays_off_planet()
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
	var track_seen_snapshot: Dictionary = FIRST_RUN_COACH_SNAPSHOT_SCRIPT.new().apply_dictionary({
		"visible": true,
		"progress": {
			"selected_district": true,
			"has_monster": true,
			"has_city": true,
			"has_opened_supply": true,
			"has_bought_card": true,
			"has_played_card": true,
			"has_seen_public_track": true,
			"has_checked_economy": false,
			"has_chosen_route": false,
		},
		"auto_fold_after_route_choice": true,
	}).to_ui_dictionary()
	_expect(str(track_seen_snapshot.get("stage", "")) == "check_economy" and not bool(track_seen_snapshot.get("collapsed", false)), "first-run coach does not disappear after public-track inspection; it continues to economy overview")
	var route_done_snapshot: Dictionary = FIRST_RUN_COACH_SNAPSHOT_SCRIPT.new().apply_dictionary({
		"visible": true,
		"progress": {
			"selected_district": true,
			"has_monster": true,
			"has_city": true,
			"has_opened_supply": true,
			"has_bought_card": true,
			"has_played_card": true,
			"has_seen_public_track": true,
			"has_checked_economy": true,
			"has_chosen_route": true,
		},
		"auto_fold_after_route_choice": true,
	}).to_ui_dictionary()
	_expect(bool(route_done_snapshot.get("collapsed", false)) and str(route_done_snapshot.get("body", "")).length() <= 18, "first-run coach folds only after route choice and leaves compact completion copy")


func _check_scenario_coach_empty_state() -> void:
	var empty_snapshot: Dictionary = SCENARIO_COACH_SNAPSHOT_SCRIPT.new().apply_dictionary({}).to_ui_dictionary()
	_expect(not bool(empty_snapshot.get("visible", true)), "scenario coach hides itself when no scenario is active")
	_expect(str(empty_snapshot.get("goal", "")) == "", "empty scenario coach does not show placeholder goal text")
	var active_snapshot: Dictionary = SCENARIO_COACH_SNAPSHOT_SCRIPT.new().apply_dictionary({
		"scenario_id": "first_table",
		"title": "01 首局入门",
		"current_index": 0,
		"total": 6,
		"current_phase": {"id": "select_district", "label": "点区", "goal": "在中央星球选择一个陆地区域。", "primary_action_hint": "点击推荐区域", "focus_target": "planet"},
	}).to_ui_dictionary()
	_expect(bool(active_snapshot.get("visible", false)) and str(active_snapshot.get("goal", "")).contains("选择一个陆地"), "active scenario coach still shows real scenario copy")
	var stuck_snapshot: Dictionary = SCENARIO_COACH_SNAPSHOT_SCRIPT.new().apply_dictionary({
		"scenario_id": "first_table",
		"title": "01 首局入门",
		"current_index": 0,
		"total": 6,
		"failed_attempts": 2,
		"current_phase": {"id": "select_district", "label": "点区", "goal": "在中央星球选择一个陆地区域。", "primary_action_hint": "点击推荐区域", "focus_target": "planet", "stuck_hint": "看中央星球，点击被推荐的陆地区域。"},
	}).to_ui_dictionary()
	_expect(str(stuck_snapshot.get("stuck_state", "")) == "strong" and bool(stuck_snapshot.get("pulse_focus", false)), "repeated stuck scenario enters a pulsing strong-stuck state")
	_expect(str(stuck_snapshot.get("shortest_action_text", "")).length() <= 18 and str(stuck_snapshot.get("shortest_action_text", "")).strip_edges() != "", "strong stuck scenario keeps shortest-action copy compact")


func _check_player_facing_source_guards() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var game_screen_source := FileAccess.get_file_as_string("res://scripts/ui/game_screen.gd")
	var game_screen_scene := FileAccess.get_file_as_string("res://scenes/ui/GameScreen.tscn")
	var inspector_source := FileAccess.get_file_as_string("res://scripts/ui/right_inspector.gd")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/overlay_layer.gd")
	var first_run_coach_scene := FileAccess.get_file_as_string("res://scenes/ui/FirstRunCoach.tscn")
	var first_run_coach_script := FileAccess.get_file_as_string("res://scripts/ui/first_run_coach.gd")
	var resolution_banner_source := FileAccess.get_file_as_string("res://scenes/ui/CardResolutionBanner.tscn")
	var tutorial_source := FileAccess.get_file_as_string("res://scripts/ui/tutorial_quick_start_board.gd")
	var rules_source := FileAccess.get_file_as_string("res://scripts/ui/rules_quick_reference_board.gd")
	var snapshot_source := FileAccess.get_file_as_string("res://scripts/viewmodels/right_inspector_snapshot.gd")
	var scenario_snapshot_source := FileAccess.get_file_as_string("res://scripts/viewmodels/scenario_coach_snapshot.gd")
	var scenario_coach_scene := FileAccess.get_file_as_string("res://scenes/ui/ScenarioCoach.tscn")
	var scenario_coach_script := FileAccess.get_file_as_string("res://scripts/ui/scenario_coach.gd")
	var bid_board_scene := FileAccess.get_file_as_string("res://scenes/ui/BidBoard.tscn")
	var district_supply_preview_scene := FileAccess.get_file_as_string("res://scenes/ui/DistrictSupplyPreviewCard.tscn")
	var district_supply_preview_script := FileAccess.get_file_as_string("res://scripts/ui/district_supply_preview_card.gd")
	_expect(snapshot_source.contains("WHY_TEXT_CHAR_LIMIT := 48") and snapshot_source.contains("DETAIL_SUMMARY_CHAR_LIMIT := 44"), "right inspector snapshot has strict scan-first limits")
	_expect(inspector_source.contains("WHY_TEXT_CHAR_LIMIT := 48") and inspector_source.contains("SUMMARY_TEXT_CHAR_LIMIT := 44"), "right inspector UI has strict scan-first limits")
	_expect(overlay_source.contains("TEMP_DECISION_BODY_LIMIT := 72") and overlay_source.contains("SIDE_DRAWER_SECTION_BODY_LIMIT := 132"), "overlay modals/drawers cap visible prose")
	_expect(overlay_source.contains("TEMP_DECISION_SIDE_ANCHOR_LEFT := 0.70") and overlay_source.contains("_dock_confirm_to_planet_side_lane"), "temporary decision overlays dock to a planet side lane instead of the table center")
	_expect(resolution_banner_source.contains("anchor_left = 0.625") and resolution_banner_source.contains("anchor_top = 0.302") and resolution_banner_source.contains("anchor_right = 0.795") and resolution_banner_source.contains("anchor_bottom = 0.448") and resolution_banner_source.contains("custom_minimum_size = Vector2(292, 128)"), "card resolution and auction banner docks to a narrow middle planet side lane")
	_expect(not resolution_banner_source.contains("Anonymous card resolution") and resolution_banner_source.contains("避免遮挡中央星球"), "card resolution banner uses player-facing side-card copy")
	_expect(tutorial_source.contains("_short_text(body_text, 34)") and tutorial_source.contains("_short_text(meta_text, 28)"), "tutorial cards use short visible copy")
	_expect(rules_source.contains("_short_text(body_text, 34)") and rules_source.contains("_short_text(meta_text, 28)"), "rules quick-reference cards use short visible copy")
	_expect(not main_source.contains("当前位置：主菜单"), "menu breadcrumb prose is not shown as player-facing navigation copy")
	_expect(not main_source.contains("所有牌都会公开展示，出牌者匿名"), "rules menu no longer repeats long prose in the page body")
	_expect(main_source.contains("第一局只做四件事：首召、建城、买牌、出牌。"), "tutorial menu opens with one-line first-game guidance")
	_expect(game_screen_source.contains("PLANET_LEFT_SIDE_LANE_LEFT") and game_screen_source.contains("PLANET_LEFT_SIDE_LANE_BOTTOM") and game_screen_source.contains("_set_overlay_anchor_rect(first_run_coach_host"), "default first-run coach uses named planet left side-lane skeleton constants instead of a loose top banner")
	_expect(first_run_coach_scene.contains("custom_minimum_size = Vector2(220, 98)") and first_run_coach_scene.contains("CoachBodyRow\" type=\"VBoxContainer") and first_run_coach_script.contains("custom_minimum_size = Vector2(220, 32 if collapsed else 98)") and first_run_coach_script.contains("_short_text(str(data.get(\"body\", \"\")), 24)"), "FirstRunCoach is a narrow side-card layout with stacked body/CTA and short body copy")
	_expect(game_screen_source.contains("PLANET_RIGHT_SIDE_LANE_LEFT") and game_screen_source.contains("PLANET_RIGHT_SIDE_LANE_BOTTOM"), "default scenario coach uses named planet side-lane skeleton constants instead of loose center anchors")
	_expect(game_screen_scene.contains("HandHoverPreviewHost") and game_screen_scene.contains("HandHoverPreviewCard") and game_screen_source.contains("HAND_HOVER_PREVIEW_LEFT") and game_screen_source.contains("get_hand_hover_preview_snapshot") and game_screen_source.contains("left-side-readable-card") and game_screen_source.contains("hover_readable_preview"), "hand hover opens a readable left-side CardFace preview instead of forcing tiny hand text or covering the planet center")
	_expect(FileAccess.get_file_as_string("res://scripts/ui/planet_board.gd").contains("PLANET_TABLE_SAFE_CORE_RATIO") and FileAccess.get_file_as_string("res://scripts/ui/planet_board.gd").contains("SIDE_RAIL_MIN_STAGGER_PIXELS"), "planet side rails use explicit safe-core and stagger metrics")
	_expect(bid_board_scene.contains("牌桌竞价") and bid_board_scene.contains("下一张牌可报价。") and not bid_board_scene.contains("公开竞价") and not bid_board_scene.contains("下一张匿名牌可预设公开报价"), "bid board reads as a compact table-bid control instead of an anonymity rules explainer")
	_expect(not main_source.contains("预设匿名报价"), "bid tooltips use compact public-bid wording")
	_expect(district_supply_preview_scene.contains("DistrictSupplyPreviewScanGrid") and district_supply_preview_script.contains("SCAN_SECTION_BODY_LIMIT := 34") and district_supply_preview_script.contains("_render_scan_sections") and district_supply_preview_script.contains("body_label.visible = body_label.text != \"\" and not has_scan_sections") and district_supply_preview_script.contains("facts_label.visible = facts_label.text != \"\" and not has_scan_sections") and district_supply_preview_script.contains("status_label.visible = status_label.text != \"\" and not has_scan_sections") and main_source.contains("_district_supply_preview_scan_sections") and main_source.contains("\"title\": \"用途\"") and main_source.contains("\"title\": \"买入\"") and main_source.contains("\"title\": \"打出\"") and main_source.contains("\"title\": \"目标\""), "district supply preview uses four compact scan sections instead of always-visible dense prose")
	_expect(scenario_snapshot_source.contains("has_scenario") and scenario_snapshot_source.contains("\"visible\": false") and scenario_snapshot_source.contains("按桌边提示完成下一步。") and scenario_snapshot_source.contains("pulse_focus") and scenario_snapshot_source.contains("_shortest_action_text") and scenario_coach_script.contains("_stuck_help_text") and not _contains_any("\n".join([scenario_snapshot_source, scenario_coach_scene, scenario_coach_script]), ["完成当前目标。", "看高亮区域，完成当前目标。"]), "scenario coach hides empty/default state, supports strong-stuck shortest-action guidance, and avoids placeholder objective copy")


func _check_first_run_coach_stays_off_planet() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main scene loads for first-run coach readability check")
	if packed == null:
		return
	root.size = Vector2i(1600, 960)
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	if main.has_method("_new_game"):
		main.call("_new_game")
	await process_frame
	await process_frame
	await process_frame
	var map_host := main.find_child("MapHost", true, false) as Control
	var coach_host := main.find_child("FirstRunCoachHost", true, false) as Control
	var coach := main.find_child("FirstRunCoach", true, false) as Control
	var right_inspector := main.find_child("RightInspector", true, false) as Control
	_expect(map_host != null and coach_host != null and coach != null, "first-run coach and map host exist in runtime")
	if map_host != null and coach_host != null and coach != null:
		var map_rect := map_host.get_global_rect()
		var coach_rect := coach_host.get_global_rect()
		var planet_core_rect := Rect2(
			map_rect.position + Vector2(map_rect.size.x * 0.24, map_rect.size.y * 0.08),
			Vector2(map_rect.size.x * 0.52, map_rect.size.y * 0.84)
		)
		_expect(coach.visible, "first-run coach is visible during a normal first table")
		_expect(coach_rect.size.x <= 340.0, "first-run coach is a narrow side card instead of a wide top banner")
		_expect(coach_rect.end.x <= planet_core_rect.position.x + 2.0, "first-run coach sits in the left side lane before the planet core")
		_expect(not coach_rect.intersects(planet_core_rect), "first-run coach does not cover the central planet body")
		if right_inspector != null:
			_expect(not coach_rect.intersects(right_inspector.get_global_rect()), "first-run coach does not cover the right inspector")
	root.remove_child(main)
	main.queue_free()
	await process_frame


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


func _contains_any(haystack: String, needles: Array) -> bool:
	for needle_variant in needles:
		if haystack.contains(str(needle_variant)):
			return true
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("Playtest readability gate passed.")
		quit(0)
	else:
		print("Playtest readability gate failed: %s" % " / ".join(_failures))
		quit(1)
