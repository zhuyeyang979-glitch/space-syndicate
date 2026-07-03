extends SceneTree

const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var screen := GAME_SCREEN_SCENE.instantiate() as Control
	_expect(screen != null, "GameScreen scene instantiates for focus-guide gate")
	if screen == null:
		_finish()
		return
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.position = Vector2.ZERO
	screen.size = Vector2(1280, 720)
	get_root().add_child(screen)
	await process_frame
	await process_frame

	await _apply_and_expect_focus(screen, "player_hand", "手牌", "first_summon")
	await _apply_and_expect_focus(screen, "public_track", "牌轨", "select_track_card")
	await _apply_and_expect_focus(screen, "right_inspector", "右侧详情", "read_inspector")
	await _apply_and_expect_focus(screen, "bid_board", "竞价", "read_bid_board")
	screen.call("apply_state", _table_state(""))
	await process_frame
	await process_frame
	var layer := screen.find_child("FocusGuideLayer", true, false) as Control
	_expect(layer != null and not layer.visible, "focus guide hides when no scenario target is active")

	screen.queue_free()
	_finish()


func _apply_and_expect_focus(screen: Control, focus_target: String, expected_label: String, phase_id: String) -> void:
	screen.call("apply_state", _table_state(focus_target, phase_id))
	await process_frame
	await process_frame
	var layer := screen.find_child("FocusGuideLayer", true, false) as Control
	var panel := screen.find_child("FocusGuidePanel", true, false) as Control
	var chip := screen.find_child("FocusGuideChip", true, false) as Control
	var label := screen.find_child("FocusGuideLabel", true, false) as Label
	_expect(layer != null and layer.visible, "focus guide layer is visible for target %s" % focus_target)
	_expect(panel != null and panel.visible, "focus guide panel is visible for target %s" % focus_target)
	_expect(chip != null and chip.visible, "focus guide chip is visible for target %s" % focus_target)
	_expect(label != null and label.text.contains(expected_label), "focus guide label for %s points players to %s" % [focus_target, expected_label])
	_expect(panel != null and panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "focus guide panel does not intercept mouse input for %s" % focus_target)
	_expect(chip != null and chip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "focus guide chip does not intercept mouse input for %s" % focus_target)
	var target := _target_control(screen, focus_target)
	if panel != null and target != null:
		_expect(panel.get_global_rect().intersects(target.get_global_rect()), "focus guide panel overlaps the intended target control for %s" % focus_target)


func _target_control(screen: Control, focus_target: String) -> Control:
	match focus_target:
		"player_hand":
			return screen.find_child("HandRack", true, false) as Control
		"public_track":
			return screen.find_child("PublicTrack", true, false) as Control
		"right_inspector":
			return screen.find_child("RightInspector", true, false) as Control
		"bid_board":
			return screen.find_child("PlayerBidBoard", true, false) as Control
		_:
			return null


func _table_state(focus_target: String, phase_id: String = "first_summon") -> Dictionary:
	var scenario := {}
	if focus_target != "":
		scenario = {
			"scenario_id": "focus_guide_test",
			"title": "01 首局入门",
			"current_index": 1,
			"total": 6,
			"campaign_focus_mode": true,
			"current_phase": {
				"id": phase_id,
				"label": _phase_label(phase_id),
				"goal": "完成当前桌边动作。",
				"detail": "测试焦点高亮是否落在正确桌面区域。",
				"primary_action_hint": _primary_action_label(phase_id),
				"focus_target": focus_target,
			},
		}
	return {
		"top_bar": {
			"identity": "本席 玩家1",
			"cash_text": "现金 ¥2080",
			"gdp_text": "GDP 0/min",
			"goal_text": "目标 2080/4740",
			"selected_district": "选区 能源塔",
			"primary_action": "下一步",
		},
		"card_track": [
			{"id": "track_focus_sample", "label": "#事 本局卡池", "state": "只读", "slot": "1", "select_action": "track_select_1", "open_action": "track_open_1"},
		],
		"planet": {
			"title": "星球牌桌",
			"hint": "公开星球状态。",
			"campaign_focus_mode": true,
			"weather": {"active": "现在：无天气", "forecast": "预报：平稳", "impact": "影响：产/交/消"},
		},
		"right_inspector": {
			"title": "右侧详情",
			"why": "现在可做：建城、牌架、首召。",
			"district": {"title": "能源塔", "summary": "可城市化", "chips": ["陆地", "可建"]},
			"actions": [{"id": "build_city", "label": "城市化"}],
			"logs": [],
		},
		"player_board": {
			"title": "本席 玩家1",
			"identity": "玩家1",
			"cash_text": "¥2080",
			"gdp_text": "0/min",
			"goal_text": "2080/4740",
			"selected_district_summary": "能源塔",
			"primary_action": "在选区首召",
			"hand_limit": 5,
			"hand_cards": [
				{"id": "starter_monster", "name": "怪兽·孢雾海皇", "type": "怪兽", "rank": "I", "cost": "¥450", "effect": "召唤怪兽，开放附近买牌。", "actionable": true, "actions": [{"id": "play_starter", "label": "打出"}]},
			],
			"quick_actions": [
				{"id": "build_city", "label": "城市化", "active": true},
				{"id": "open_rack", "label": "牌架", "active": true},
			],
			"bid_board": {"title": "牌桌竞价", "my_bid": "¥0", "highest_bid": "¥0", "actions": [{"id": "bid_plus_10", "label": "+10"}]},
		},
		"scenario_coach": scenario,
		"campaign_focus_mode": true,
	}


func _phase_label(phase_id: String) -> String:
	match phase_id:
		"first_summon":
			return "首召"
		"select_track_card":
			return "看牌轨"
		"read_inspector":
			return "读详情"
		"read_bid_board":
			return "读竞价"
		_:
			return "下一步"


func _primary_action_label(phase_id: String) -> String:
	match phase_id:
		"first_summon":
			return "在选区首召"
		"select_track_card":
			return "点选牌轨"
		"read_inspector":
			return "查看右侧详情"
		"read_bid_board":
			return "查看竞价板"
		_:
			return "定位下一步"


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("Focus guide gate failure: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Focus guide gate passed.")
	else:
		print("Focus guide gate failed: %s" % " / ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
