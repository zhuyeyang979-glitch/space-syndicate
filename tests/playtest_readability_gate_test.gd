extends SceneTree

const RIGHT_INSPECTOR_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/right_inspector_snapshot.gd")
const FIRST_RUN_COACH_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/first_run_coach_snapshot.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_right_inspector_snapshot_density()
	_check_first_run_coach_density()
	_check_player_facing_source_guards()
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
	var inspector_source := FileAccess.get_file_as_string("res://scripts/ui/right_inspector.gd")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/overlay_layer.gd")
	var tutorial_source := FileAccess.get_file_as_string("res://scripts/ui/tutorial_quick_start_board.gd")
	var rules_source := FileAccess.get_file_as_string("res://scripts/ui/rules_quick_reference_board.gd")
	var snapshot_source := FileAccess.get_file_as_string("res://scripts/viewmodels/right_inspector_snapshot.gd")
	_expect(snapshot_source.contains("WHY_TEXT_CHAR_LIMIT := 48") and snapshot_source.contains("DETAIL_SUMMARY_CHAR_LIMIT := 44"), "right inspector snapshot has strict scan-first limits")
	_expect(inspector_source.contains("WHY_TEXT_CHAR_LIMIT := 48") and inspector_source.contains("SUMMARY_TEXT_CHAR_LIMIT := 44"), "right inspector UI has strict scan-first limits")
	_expect(overlay_source.contains("TEMP_DECISION_BODY_LIMIT := 72") and overlay_source.contains("SIDE_DRAWER_SECTION_BODY_LIMIT := 132"), "overlay modals/drawers cap visible prose")
	_expect(tutorial_source.contains("_short_text(body_text, 34)") and tutorial_source.contains("_short_text(meta_text, 28)"), "tutorial cards use short visible copy")
	_expect(rules_source.contains("_short_text(body_text, 34)") and rules_source.contains("_short_text(meta_text, 28)"), "rules quick-reference cards use short visible copy")
	_expect(not main_source.contains("当前位置：主菜单"), "menu breadcrumb prose is not shown as player-facing navigation copy")
	_expect(not main_source.contains("所有牌都会公开展示，出牌者匿名"), "rules menu no longer repeats long prose in the page body")
	_expect(main_source.contains("第一局只做四件事：首召、建城、买牌、出牌。"), "tutorial menu opens with one-line first-game guidance")


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
