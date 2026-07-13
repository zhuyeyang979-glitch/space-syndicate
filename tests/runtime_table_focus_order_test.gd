extends SceneTree

const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")
const DISTRICT_SUPPLY_DRAWER_SCENE := preload("res://scenes/ui/DistrictSupplyDrawer.tscn")
const DISTRICT_SUPPLY_MARKET_CARD_SCENE := preload("res://scenes/ui/DistrictSupplyMarketCard.tscn")
const GlobalNavigationRegistryScript := preload("res://scripts/tools/global_ui_navigation_characterization_registry.gd")

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
		var meta_label := public_track_slot.find_child("PublicTrackSlotMeta", true, false) as Label
		_expect(meta_label != null and meta_label.text.contains("未知") and not meta_label.text.contains("匿名"), "runtime public track summarizes hidden source as 未知 instead of repeatedly saying 匿名")
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

	var selected_cards: Array = []
	var action_ids: Array[String] = []
	if screen.has_signal("card_selected"):
		screen.connect("card_selected", func(card_data: Dictionary) -> void:
			selected_cards.append(card_data)
		)
	if screen.has_signal("action_requested"):
		screen.connect("action_requested", func(action_id: String) -> void:
			action_ids.append(action_id)
		)
	var hand_card := screen.find_child("MiniHandCardFace0", true, false) as Control
	_expect(hand_card != null, "runtime hand renders a focusable hand card")
	if hand_card != null:
		_expect(hand_card.focus_mode == Control.FOCUS_ALL, "runtime hand card is reachable by keyboard/gamepad focus")
		_expect(str(hand_card.get_meta("runtime_focus_kind", "")) == "hand_card", "runtime hand card carries a table-focus marker")
		_expect(str(hand_card.focus_next) != "" and str(hand_card.focus_previous) != "", "runtime hand card links to neighboring hand cards when available")
		hand_card.emit_signal("mouse_entered")
		await _wait_frames(2)
		_check_hand_hover_readable_preview(screen, "starter_monster")
		var hand_accept := InputEventAction.new()
		hand_accept.action = "ui_accept"
		hand_accept.pressed = true
		hand_card.emit_signal("gui_input", hand_accept)
		await _wait_frames(1)
		hand_card.emit_signal("gui_input", hand_accept)
		await _wait_frames(1)
		hand_card.emit_signal("mouse_exited")
		await _wait_frames(1)
	_expect(selected_cards.size() >= 1 and str((selected_cards[0] as Dictionary).get("id", "")) == "starter_monster", "runtime hand card first confirm selects the card")
	_expect(action_ids.has("play_starter"), "runtime hand card second confirm requests the card play action")

	await _check_district_supply_market_card_component()
	await _check_district_supply_drawer_focus_chain()
	_check_global_navigation_focus_characterization()

	root.remove_child(screen)
	screen.queue_free()
	_finish()


func _check_global_navigation_focus_characterization() -> void:
	var records: Array = GlobalNavigationRegistryScript.characterization_cases()
	var surfaces: Array = GlobalNavigationRegistryScript.surface_registry()
	var focus_record: Dictionary = {}
	var fallback_record: Dictionary = {}
	var input_record: Dictionary = {}
	for record_variant: Variant in records:
		var record := record_variant as Dictionary
		match str(record.get("case_id", "")):
			"focus_restores_to_opener": focus_record = record
			"freed_focus_uses_safe_fallback": fallback_record = record
			"keyboard_controller_pointer_parity": input_record = record
	_expect(records.size() == 32 and surfaces.size() >= 15, "Sprint 67 registers the complete global Back/focus characterization matrix")
	_expect(bool(focus_record.get("focus_restore_checked", false)) and str(focus_record.get("resolved_action", "")) == "focus_untracked" and not bool(focus_record.get("contract_aligned", true)), "Sprint 67 explicitly records missing exact-opener focus restoration")
	_expect(bool(fallback_record.get("focus_restore_checked", false)) and str(fallback_record.get("resolved_action", "")) == "no_global_focus_fallback" and not bool(fallback_record.get("contract_aligned", true)), "Sprint 67 explicitly records the missing freed-opener fallback")
	_expect(str(input_record.get("resolved_action", "")) == "key_escape_only" and not bool(input_record.get("contract_aligned", true)), "Sprint 67 keeps keyboard/controller/pointer parity as an open hard-cutover gate")


func _check_district_supply_market_card_component() -> void:
	var card := DISTRICT_SUPPLY_MARKET_CARD_SCENE.instantiate() as Control
	_expect(card != null, "district supply market card scene instantiates")
	if card == null:
		return
	root.add_child(card)
	await _wait_frames(2)
	if card.has_method("set_card"):
		card.call("set_card", {
			"card_name": "城市融资1",
			"title": "城市融资",
			"display_name": "城市融资",
			"kind": "city",
			"rank": "I",
			"rank_number": 1,
			"route": "城市成长",
			"facts": "GDP+70｜无门槛",
			"state_text": "可购买",
			"actionable": true,
			"accent": Color("#22c55e"),
			"theme_color": Color("#38bdf8"),
			"chips": [{"text": "经济", "accent": Color("#38bdf8")}],
			"micro_chips": [{"text": "¥120", "accent": Color("#fde68a")}],
		})
	var previewed: Array[String] = []
	var activated: Array[String] = []
	if card.has_signal("card_preview_requested"):
		card.connect("card_preview_requested", func(card_name: String) -> void:
			previewed.append(card_name)
		)
	if card.has_signal("card_activated"):
		card.connect("card_activated", func(card_name: String) -> void:
			activated.append(card_name)
		)
	_expect(card.focus_mode == Control.FOCUS_ALL, "district supply market card is keyboard/gamepad focusable")
	_expect(str(card.get_meta("runtime_focus_kind", "")) == "district_supply_market_card", "district supply market card carries a table-focus marker")
	var accept_event := InputEventAction.new()
	accept_event.action = "ui_accept"
	accept_event.pressed = true
	card.call("_gui_input", accept_event)
	await _wait_frames(1)
	_expect(previewed == ["城市融资1"], "district supply market card confirm first previews the card")
	_expect(activated == ["城市融资1"], "district supply market card confirm activates the purchase/open action")
	root.remove_child(card)
	card.queue_free()


func _check_district_supply_drawer_focus_chain() -> void:
	var drawer := DISTRICT_SUPPLY_DRAWER_SCENE.instantiate() as Control
	_expect(drawer != null, "district supply drawer scene instantiates for focus ownership")
	if drawer == null:
		return
	root.add_child(drawer)
	await _wait_frames(2)
	drawer.call("set_supply", {
		"cards": [
			{"card_name": "城市融资1", "title": "城市融资", "rank": "I", "state_text": "可购买", "accent": "#34d399ff", "theme_color": "#38bdf8ff", "actionable": true},
			{"card_name": "轨道融资1", "title": "轨道融资", "rank": "I", "state_text": "可购买", "accent": "#fbbf24ff", "theme_color": "#fb923cff", "actionable": true},
		],
		"preview": {},
	})
	await _wait_frames(2)
	var market_grid := drawer.find_child("DistrictSupplyMarketGrid", true, false) as Container
	var first_card := market_grid.get_child(0) as Control if market_grid != null and market_grid.get_child_count() > 0 else null
	var second_card := market_grid.get_child(1) as Control if market_grid != null and market_grid.get_child_count() > 1 else null
	_expect(first_card != null and second_card != null, "district supply drawer renders multiple focusable market cards")
	_expect(first_card != null and second_card != null and first_card.get_node_or_null(first_card.focus_next) == second_card and second_card.get_node_or_null(second_card.focus_next) == first_card, "district supply drawer owns a wraparound next-focus chain")
	_expect(first_card != null and second_card != null and first_card.get_node_or_null(first_card.focus_previous) == second_card and second_card.get_node_or_null(second_card.focus_previous) == first_card, "district supply drawer owns a wraparound previous-focus chain")
	var action_ids: Array[String] = []
	if drawer.has_signal("supply_action_requested"):
		drawer.connect("supply_action_requested", func(action_id: String, _payload: Dictionary) -> void:
			action_ids.append(action_id)
		)
	if first_card != null:
		var accept_event := InputEventAction.new()
		accept_event.action = "ui_accept"
		accept_event.pressed = true
		first_card.call("_gui_input", accept_event)
	await _wait_frames(1)
	_expect(action_ids == ["district_supply_preview_card", "district_supply_purchase_card"], "district supply drawer aggregates focused card preview and purchase intents")
	root.remove_child(drawer)
	drawer.queue_free()


func _check_hand_hover_readable_preview(screen: Control, expected_card_id: String) -> void:
	_expect(screen.has_method("get_hand_hover_preview_snapshot"), "runtime screen exposes a hand-hover readable-preview snapshot")
	if not screen.has_method("get_hand_hover_preview_snapshot"):
		return
	var snapshot: Dictionary = screen.call("get_hand_hover_preview_snapshot")
	_expect(bool(snapshot.get("visible", false)), "hand hover opens a large readable side-card preview")
	_expect(str(snapshot.get("policy", "")) == "left-side-readable-card", "hand hover preview uses the left-side table lane instead of the planet center")
	_expect(str(snapshot.get("card_name", "")).contains("孢雾海皇"), "hand hover preview shows the hovered card name")
	var preview_rect: Rect2 = snapshot.get("rect", Rect2())
	var planet_board := screen.find_child("PlanetBoard", true, false) as Control
	_expect(planet_board != null, "hand hover preview can compare against the planet board")
	if planet_board != null:
		var planet_rect := planet_board.get_global_rect()
		var planet_core_rect := Rect2(
			planet_rect.position + Vector2(planet_rect.size.x * 0.26, planet_rect.size.y * 0.10),
			Vector2(planet_rect.size.x * 0.48, planet_rect.size.y * 0.80)
		)
		_expect(not preview_rect.intersects(planet_core_rect), "hand hover preview stays out of the central planet body")
	var hover_card := screen.find_child("HandHoverPreviewCard", true, false) as Control
	_expect(hover_card != null, "hand hover preview renders a real CardFace")
	if hover_card != null:
		_expect(str(hover_card.get_meta("card_presentation_spec", "")) == "inspector_full", "hand hover preview uses the readable inspector_full card presentation")
		_expect(bool(hover_card.get_meta("hand_hover_readable_preview", false)), "hand hover preview card carries a readable-preview contract marker")
		var card_data: Dictionary = hover_card.call("get_card_data") if hover_card.has_method("get_card_data") else {}
		_expect(str(card_data.get("id", "")) == expected_card_id, "hand hover preview keeps the hovered hand-card data")


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
				"owner_hint": "匿名",
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
				{
					"id": "starter_route",
					"name": "城市融资",
					"type": "经济",
					"rank": "I",
					"cost": "¥120",
					"effect": "提升城市现金流。",
					"actionable": true,
					"actions": [{"id": "play_route", "label": "打出"}],
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
