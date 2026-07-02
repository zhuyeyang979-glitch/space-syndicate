extends SceneTree

const CAMPAIGN_SCRIPT := preload("res://scripts/campaign/campaign_definition.gd")
const PROGRESS_SCRIPT := preload("res://scripts/campaign/campaign_progress.gd")
const RECOMMEND_SCRIPT := preload("res://scripts/recommendations/recommended_start_service.gd")
const REWARD_SERVICE_SCRIPT := preload("res://scripts/campaign/campaign_reward_service.gd")
const MENU_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/campaign_menu_snapshot.gd")
const BRIEFING_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/campaign_briefing_snapshot.gd")
const PROGRESS_MAP_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/campaign_progress_map_snapshot.gd")
const REWARD_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/campaign_reward_snapshot.gd")
const RECAP_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/match_recap_snapshot.gd")
const SCENARIO_COACH_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/scenario_coach_snapshot.gd")

const OUTPUT_DIR := "user://campaign_snapshots"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var campaign: Dictionary = CAMPAIGN_SCRIPT.new().load_by_id("tutorial_campaign")
	var progress_empty: Dictionary = PROGRESS_SCRIPT.new().apply_state(campaign, []).to_dictionary()
	var progress_mid: Dictionary = PROGRESS_SCRIPT.new().apply_state(campaign, ["00_tavern_entry", "01_first_table", "02_market_hand"]).to_dictionary()
	var recommendations: Dictionary = RECOMMEND_SCRIPT.new().load_recommendations()
	var chapters: Array = campaign.get("chapters", []) if campaign.get("chapters", []) is Array else []
	var chapter_01: Dictionary = chapters[1] if chapters.size() > 1 and chapters[1] is Dictionary else {}
	var chapter_final: Dictionary = chapters.back() if not chapters.is_empty() and chapters.back() is Dictionary else {}
	var reward: Dictionary = REWARD_SERVICE_SCRIPT.new().build_reward(campaign, chapter_01, progress_mid, {"time_text": "05:10", "objectives_completed": 3, "objectives_total": 3, "errors": 0, "hints": 1})
	var recap: Dictionary = REWARD_SERVICE_SCRIPT.new().build_recap(campaign, chapter_01, [
		{"time": "00:15", "public_text": "选择区域：雾港区。"},
		{"time": "00:42", "public_text": "首召怪兽。"},
		{"time": "01:20", "public_text": "完成城市化。"},
	], {})
	await _capture_scene("res://scenes/ui/CampaignMenu.tscn", "set_campaign_menu", MENU_SNAPSHOT_SCRIPT.new().apply_dictionary({"campaign": campaign, "progress": progress_empty, "recommendations": recommendations}).to_ui_dictionary(), Vector2i(1280, 720), "campaign_main_menu_1280x720.png")
	await _capture_scene("res://scenes/ui/CampaignMenu.tscn", "set_campaign_menu", MENU_SNAPSHOT_SCRIPT.new().apply_dictionary({"campaign": campaign, "progress": progress_empty, "recommendations": recommendations}).to_ui_dictionary(), Vector2i(1600, 960), "campaign_main_menu_1600x960.png")
	await _capture_scene("res://scenes/ui/CampaignProgressMap.tscn", "set_progress_map", PROGRESS_MAP_SNAPSHOT_SCRIPT.new().apply_dictionary({"progress": progress_mid}).to_ui_dictionary(), Vector2i(1600, 960), "campaign_map_1600x960.png")
	await _capture_scene("res://scenes/ui/CampaignBriefing.tscn", "set_briefing", BRIEFING_SNAPSHOT_SCRIPT.new().apply_dictionary({"campaign": campaign, "chapter": chapter_01}).to_ui_dictionary(), Vector2i(1600, 960), "campaign_briefing_01_1600x960.png")
	await _capture_scene("res://scenes/ui/ScenarioCoach.tscn", "set_coach", _coach_snapshot("新手战役｜第一桌：星球赌桌", "点区", "先点一个区域", "1/3"), Vector2i(1600, 960), "campaign_coach_step_01_1600x960.png")
	await _capture_scene("res://scenes/ui/ScenarioCoach.tscn", "set_coach", _coach_snapshot("新手战役｜第一桌：星球赌桌", "卡住", "如果不知道点哪里，点中央星球上的陆地区域。", "1/3"), Vector2i(1600, 960), "campaign_coach_blocked_1600x960.png")
	await _capture_scene("res://scenes/ui/CampaignRewardPanel.tscn", "set_reward", REWARD_SNAPSHOT_SCRIPT.new().apply_dictionary(reward).to_ui_dictionary(), Vector2i(1600, 960), "campaign_reward_1600x960.png")
	await _capture_scene("res://scenes/ui/MatchRecapPanel.tscn", "set_recap", RECAP_SNAPSHOT_SCRIPT.new().apply_dictionary(recap).to_ui_dictionary(), Vector2i(1600, 960), "campaign_recap_1600x960.png")
	await _capture_control(_settings_panel(), Vector2i(1600, 960), "campaign_settings_1600x960.png")
	await _capture_scene("res://scenes/ui/CampaignMenu.tscn", "set_campaign_menu", MENU_SNAPSHOT_SCRIPT.new().apply_dictionary({"campaign": campaign, "progress": progress_mid, "recommendations": recommendations}).to_ui_dictionary(), Vector2i(1600, 960), "campaign_progress_continue_1600x960.png")
	await _capture_scene("res://scenes/ui/CampaignBriefing.tscn", "set_briefing", BRIEFING_SNAPSHOT_SCRIPT.new().apply_dictionary({"campaign": campaign, "chapter": chapter_final}).to_ui_dictionary(), Vector2i(1600, 960), "graduation_match_start_1600x960.png")
	await _capture_scene("res://scenes/ui/CampaignRewardPanel.tscn", "set_reward", REWARD_SNAPSHOT_SCRIPT.new().apply_dictionary(REWARD_SERVICE_SCRIPT.new().build_reward(campaign, chapter_final, progress_mid, {"time_text": "11:40", "objectives_completed": 4, "objectives_total": 4, "errors": 2, "hints": 1})).to_ui_dictionary(), Vector2i(1600, 960), "graduation_match_result_1600x960.png")
	if _failures.is_empty():
		print("Campaign snapshots written to %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	else:
		push_error("Campaign snapshot capture failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())


func _capture_scene(path: String, method: String, data: Dictionary, size: Vector2i, filename: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		_failures.append("%s loads" % path)
		return
	var node := packed.instantiate() as Control
	await _capture_control(node, size, filename, method, data)


func _capture_control(node: Control, size: Vector2i, filename: String, method: String = "", data: Dictionary = {}) -> void:
	root.size = size
	var host := CenterContainer.new()
	host.name = "CampaignSnapshotHost"
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_theme_constant_override("margin_left", 24)
	host.add_theme_constant_override("margin_top", 24)
	host.add_theme_constant_override("margin_right", 24)
	host.add_theme_constant_override("margin_bottom", 24)
	root.add_child(host)
	host.add_child(node)
	await process_frame
	if method != "" and node.has_method(method):
		node.call(method, data)
		await process_frame
	await process_frame
	var image: Image = null
	var display_name := DisplayServer.get_name()
	if display_name == "headless":
		image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
		image.fill(Color("#020617"))
	else:
		var viewport_texture := root.get_texture()
		if viewport_texture != null:
			image = viewport_texture.get_image()
	if image == null:
		image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
		image.fill(Color("#020617"))
	var path := "%s/%s" % [OUTPUT_DIR, filename]
	var err := image.save_png(path)
	if err != OK:
		_failures.append("save %s: %s" % [filename, error_string(err)])
	root.remove_child(host)
	host.queue_free()
	await process_frame


func _coach_snapshot(title: String, phase_label: String, goal: String, progress_text: String) -> Dictionary:
	return {
		"visible": true,
		"collapsed": false,
		"title": title,
		"phase_label": phase_label,
		"progress_text": progress_text,
		"goal": goal,
		"detail": goal,
		"primary_action": {"id": "scenario_step_demo", "label": "定位目标", "tooltip": goal},
		"secondary_actions": [{"id": "scenario_hint", "label": "提示"}, {"id": "scenario_restart", "label": "重开"}],
		"font_scale_percent": 100,
	}


func _settings_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 360)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(Color("#a78bfa"), 0.10)
	style.border_color = Color("#a78bfa")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	for text in ["设置", "教学提示：开", "自动暂停教学弹窗：开", "动画强度：完整", "字体缩放：中", "色盲辅助：关", "UI 音效：80", "背景音乐：60", "重置教程进度"]:
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", 18 if text == "设置" else 13)
		label.add_theme_color_override("font_color", Color("#f8fafc") if text == "设置" else Color("#e9d5ff"))
		box.add_child(label)
	return panel
