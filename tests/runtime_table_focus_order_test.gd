extends SceneTree

const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var screen := GAME_SCREEN_SCENE.instantiate() as Control
	_expect(screen != null, "GameScreen scene instantiates for runtime focus order")
	if screen == null:
		_finish()
		return
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.position = Vector2.ZERO
	screen.size = Vector2(1280, 720)
	root.add_child(screen)
	await _wait_frames(2)
	screen.call("apply_state", _table_state())
	await _wait_frames(4)

	var snapshot: Array = screen.call("runtime_focus_order_snapshot") if screen.has_method("runtime_focus_order_snapshot") else []
	var expected_labels := ["顶部状态", "牌轨", "星球地图", "右侧详情", "手牌", "当前行动", "竞价"]
	_expect(snapshot.size() >= expected_labels.size(), "runtime table exposes the core focus regions")
	for index in range(expected_labels.size()):
		var item: Dictionary = snapshot[index] if index < snapshot.size() and snapshot[index] is Dictionary else {}
		_expect(str(item.get("label", "")) == expected_labels[index], "runtime focus order slot %d is %s" % [index + 1, expected_labels[index]])
		_expect(int(item.get("index", -1)) == index, "runtime focus order slot %d has a stable index" % [index + 1])
		_expect(int(item.get("focus_mode", Control.FOCUS_NONE)) == Control.FOCUS_ALL, "runtime focus order slot %d is keyboard/gamepad reachable" % [index + 1])
		_expect(str(item.get("focus_next", "")) != "" and str(item.get("focus_previous", "")) != "", "runtime focus order slot %d links next/previous focus" % [index + 1])
		_expect(bool(item.get("visible", false)), "runtime focus order slot %d is visible" % [index + 1])

	var public_track := screen.find_child("PublicTrack", true, false)
	var public_track_slot := screen.find_child("PublicTrackSlot", true, false) as Control
	_expect(public_track_slot != null, "runtime public track renders a focusable first slot")
	if public_track_slot != null:
		_expect(public_track_slot.focus_mode == Control.FOCUS_ALL, "runtime public track slot is reachable by keyboard/gamepad focus")
		_expect(str(public_track_slot.get_meta("runtime_focus_kind", "")) == "public_track_slot", "runtime public track slot carries a table-focus marker")
	var selected_entries: Array = []
	if public_track != null and public_track.has_signal("track_entry_selected"):
		public_track.connect("track_entry_selected", func(entry: Dictionary) -> void:
			selected_entries.append(entry)
		)
	if public_track_slot != null:
		var accept_event := InputEventAction.new()
		accept_event.action = "ui_accept"
		accept_event.pressed = true
		public_track_slot.emit_signal("gui_input", accept_event)
		await _wait_frames(1)
	_expect(selected_entries.size() == 1 and str((selected_entries[0] as Dictionary).get("id", "")) == "track_focus_sample", "runtime public track accepts keyboard/gamepad selection")

	root.remove_child(screen)
	screen.queue_free()
	_finish()


func _table_state() -> Dictionary:
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
			{
				"id": "track_focus_sample",
				"label": "首张公开牌",
				"state": "竞价",
				"slot": "1",
				"cost": "¥20",
				"select_action": "track_select_focus_sample",
				"open_action": "track_open_focus_sample",
				"tooltip": "测试牌轨槽位可用键盘选择。",
				"active": true,
			},
		],
		"planet": {
			"title": "星球牌桌",
			"hint": "公开星球状态。",
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
				{
					"id": "starter_monster",
					"name": "怪兽·孢雾海皇",
					"type": "怪兽",
					"rank": "I",
					"cost": "¥450",
					"effect": "召唤怪兽，开放附近买牌。",
					"actionable": true,
					"actions": [{"id": "play_starter", "label": "打出"}],
				},
			],
			"quick_actions": [
				{"id": "build_city", "label": "城市化", "active": true},
				{"id": "open_rack", "label": "牌架", "active": true},
			],
			"bid_board": {
				"title": "牌桌竞价",
				"my_bid": "¥0",
				"highest_bid": "¥0",
				"actions": [{"id": "bid_plus_10", "label": "+10"}],
			},
		},
	}


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Runtime table focus order test passed.")
	else:
		push_error("Runtime table focus order test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
