extends SceneTree

const SCENE_PATHS := [
	"res://scenes/GameScreen.tscn",
	"res://scenes/CardUI.tscn",
	"res://scenes/LayoutDemo.tscn",
]

const SPLIT_UI_SCENE_PATHS := [
	"res://scenes/ui/GameScreen.tscn",
	"res://scenes/ui/TopBar.tscn",
	"res://scenes/ui/PlanetBoard.tscn",
	"res://scenes/ui/PlayerBoard.tscn",
	"res://scenes/ui/HandRack.tscn",
	"res://scenes/ui/CardFace.tscn",
	"res://scenes/ui/RightInspector.tscn",
	"res://scenes/ui/ActionDock.tscn",
	"res://scenes/ui/DistrictInfoPanel.tscn",
	"res://scenes/ui/CardTrack.tscn",
	"res://scenes/ui/OverlayLayer.tscn",
]

const SPLIT_UI_SCRIPT_PATHS := [
	"res://scripts/ui/game_screen.gd",
	"res://scripts/ui/top_bar.gd",
	"res://scripts/ui/player_board.gd",
	"res://scripts/ui/hand_rack.gd",
	"res://scripts/ui/card_face.gd",
	"res://scripts/ui/right_inspector.gd",
	"res://scripts/ui/action_dock.gd",
	"res://scripts/ui/district_info_panel.gd",
	"res://scripts/ui/card_track.gd",
]

const VIEWMODEL_SCRIPT_PATHS := [
	"res://scripts/viewmodels/table_snapshot.gd",
	"res://scripts/viewmodels/player_board_snapshot.gd",
	"res://scripts/viewmodels/card_view_snapshot.gd",
	"res://scripts/viewmodels/district_view_snapshot.gd",
]

const VIEWPORT_SIZES := [
	Vector2(1280, 720),
	Vector2(1366, 768),
	Vector2(1600, 960),
	Vector2(1920, 1080),
	Vector2(2560, 1440),
]

var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists("res://themes/GameTheme.tres"), "GameTheme exists")
	_expect(ResourceLoader.exists("res://scripts/HandLayout.gd"), "HandLayout script exists")
	_expect(ResourceLoader.exists("res://scripts/CardUI.gd"), "CardUI script exists")
	for script_path in SPLIT_UI_SCRIPT_PATHS:
		_expect(ResourceLoader.exists(script_path), "%s exists" % script_path)
	for script_path in VIEWMODEL_SCRIPT_PATHS:
		_expect(ResourceLoader.exists(script_path), "%s exists" % script_path)
	for path in SCENE_PATHS:
		await _check_scene_loads(path)
	for path in SPLIT_UI_SCENE_PATHS:
		await _check_scene_loads(path, path.ends_with("OverlayLayer.tscn"))
	_check_main_player_panel_refresh_contract()
	await _check_game_screen_structure()
	await _check_split_game_screen_structure()
	await _check_split_game_screen_data_binding()
	await _check_core_layout_no_overlap()
	_check_viewmodel_contracts()
	await _check_hand_layout_counts()
	await _check_empty_player_board_affordance()
	_finish()


func _check_scene_loads(path: String, allow_canvas_layer: bool = false) -> void:
	var packed := load(path) as PackedScene
	_expect(packed != null, "%s loads" % path)
	if packed == null:
		return
	for viewport_size in VIEWPORT_SIZES:
		var instance: Node = packed.instantiate()
		_expect(instance is Control or (allow_canvas_layer and instance is CanvasLayer), "%s root is Control%s" % [path, " or CanvasLayer" if allow_canvas_layer else ""])
		if instance is Control:
			var viewport := SubViewport.new()
			viewport.size = Vector2i(int(viewport_size.x), int(viewport_size.y))
			root.add_child(viewport)
			var control := instance as Control
			viewport.add_child(control)
			await process_frame
			_expect(not _has_forbidden_2d_ui(control), "%s has no Node2D/Sprite2D UI nodes" % path)
			_expect(control.get_combined_minimum_size().x <= viewport_size.x and control.get_combined_minimum_size().y <= viewport_size.y, "%s minimum layout fits %.0fx%.0f" % [path, viewport_size.x, viewport_size.y])
			viewport.remove_child(control)
			root.remove_child(viewport)
			viewport.queue_free()
		elif allow_canvas_layer and instance is CanvasLayer:
			root.add_child(instance)
			await process_frame
			_expect(not _has_forbidden_2d_ui(instance), "%s has no Node2D/Sprite2D UI nodes" % path)
			root.remove_child(instance)
		instance.queue_free()


func _check_game_screen_structure() -> void:
	var packed := load("res://scenes/GameScreen.tscn")
	if packed == null:
		return
	var screen: Node = packed.instantiate()
	root.add_child(screen)
	await process_frame
	for node_name in ["TopBar", "TableRow", "LeftInfoPanel", "CenterTablePanel", "RightInfoPanel", "PlayerPanel", "OverlayLayer", "HandArea"]:
		_expect(screen.find_child(node_name, true, false) != null, "GameScreen contains %s" % node_name)
	root.remove_child(screen)
	screen.queue_free()


func _check_split_game_screen_structure() -> void:
	var packed := load("res://scenes/ui/GameScreen.tscn") as PackedScene
	if packed == null:
		return
	var screen: Node = packed.instantiate()
	root.add_child(screen)
	await process_frame
	for node_name in ["TopBar", "CardTrack", "PlanetBoard", "RightInspector", "DistrictInfoPanel", "CurrentActionPanel", "EventLogLabel", "PlayerBoard", "OverlayLayer"]:
		_expect(screen.find_child(node_name, true, false) != null, "split GameScreen contains %s" % node_name)
	root.remove_child(screen)
	screen.queue_free()


func _check_split_game_screen_data_binding() -> void:
	var packed := load("res://scenes/ui/GameScreen.tscn") as PackedScene
	if packed == null:
		return
	var screen: Control = packed.instantiate() as Control
	root.add_child(screen)
	await process_frame
	_expect(screen.has_method("apply_state"), "split GameScreen exposes apply_state")
	screen.call("apply_state", {
		"top_bar": {"phase": "阶段｜竞价", "turn": "席位｜2/4", "resources": "¥ 1300   GDP +22/s   目标 5000   手牌 5/5"},
		"card_track": [{"label": "匿名牌"}, {"label": "公共事件"}],
		"planet": {"title": "星球赌桌", "hint": "中央地图保留最大视觉中心"},
		"district": {"title": "雾港区", "detail": "生产海雾果，需求轨迹墨水。", "chips": [{"text": "可看牌架"}]},
		"actions": [{"id": "build", "label": "建城"}, {"id": "market", "label": "牌架"}],
		"player_board": {
			"title": "玩家板｜测试手牌",
			"hint": "选中卡牌后在右侧详情执行。",
			"hand_cards": [
				{"name": "轨道融资", "cost": "2", "type": "经济", "rank": "I", "effect": "现金流上升。"},
				{"name": "相位否决", "cost": "1", "type": "互动", "rank": "I", "effect": "反制直接互动牌。"},
			],
		},
		"logs": ["有人打出匿名牌", "怪兽靠近雾港"],
	})
	await process_frame
	var top_bar := screen.find_child("TopBar", true, false)
	var right_inspector := screen.find_child("RightInspector", true, false)
	var player_board := screen.find_child("PlayerBoard", true, false)
	var hand_rack := screen.find_child("HandRack", true, false)
	_expect(top_bar != null, "split GameScreen top bar survives data binding")
	_expect(right_inspector != null and right_inspector.has_method("set_context"), "split GameScreen routes context through RightInspector")
	_expect(player_board != null, "split GameScreen player board survives data binding")
	_expect(hand_rack != null and hand_rack.get_child_count() == 2, "split HandRack receives card data")
	root.remove_child(screen)
	screen.queue_free()


func _check_core_layout_no_overlap() -> void:
	await _check_core_layout_for_scene("res://scenes/GameScreen.tscn", {
		"vertical": ["TopBar", "TableRow", "PlayerPanel"],
		"horizontal": ["LeftInfoPanel", "CenterTablePanel", "RightInfoPanel"],
	})
	await _check_core_layout_for_scene("res://scenes/ui/GameScreen.tscn", {
		"vertical": ["TopBar", "CardTrack", "TableArea", "PlayerBoard"],
		"horizontal": ["PlanetBoard", "RightInspector"],
	})


func _check_core_layout_for_scene(path: String, groups: Dictionary) -> void:
	var packed := load(path) as PackedScene
	_expect(packed != null, "%s loads for overlap checks" % path)
	if packed == null:
		return
	for viewport_size in VIEWPORT_SIZES:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(int(viewport_size.x), int(viewport_size.y))
		root.add_child(viewport)
		var screen := packed.instantiate() as Control
		_expect(screen != null, "%s root is Control for %.0fx%.0f overlap check" % [path, viewport_size.x, viewport_size.y])
		if screen == null:
			root.remove_child(viewport)
			viewport.queue_free()
			continue
		viewport.add_child(screen)
		await process_frame
		await process_frame
		var vertical_names: Array = groups.get("vertical", [])
		_check_named_controls_do_not_overlap(screen, vertical_names, path, viewport_size)
		var horizontal_names: Array = groups.get("horizontal", [])
		_check_named_controls_do_not_overlap(screen, horizontal_names, path, viewport_size)
		viewport.remove_child(screen)
		screen.queue_free()
		root.remove_child(viewport)
		viewport.queue_free()


func _check_named_controls_do_not_overlap(screen: Control, names: Array, path: String, viewport_size: Vector2) -> void:
	for i in range(names.size()):
		var first := screen.find_child(str(names[i]), true, false) as Control
		_expect(first != null, "%s contains %s for %.0fx%.0f overlap check" % [path, str(names[i]), viewport_size.x, viewport_size.y])
		if first == null:
			continue
		for j in range(i + 1, names.size()):
			var second := screen.find_child(str(names[j]), true, false) as Control
			_expect(second != null, "%s contains %s for %.0fx%.0f overlap check" % [path, str(names[j]), viewport_size.x, viewport_size.y])
			if second == null:
				continue
			_expect(not _controls_visibly_overlap(first, second), "%s keeps %s and %s non-overlapping at %.0fx%.0f" % [path, first.name, second.name, viewport_size.x, viewport_size.y])


func _controls_visibly_overlap(first: Control, second: Control) -> bool:
	if not first.visible or not second.visible:
		return false
	var a := first.get_global_rect()
	var b := second.get_global_rect()
	return a.position.x < b.end.x - 1.0 and a.end.x > b.position.x + 1.0 and a.position.y < b.end.y - 1.0 and a.end.y > b.position.y + 1.0


func _check_viewmodel_contracts() -> void:
	var card_script := load("res://scripts/viewmodels/card_view_snapshot.gd")
	var district_script := load("res://scripts/viewmodels/district_view_snapshot.gd")
	var player_script := load("res://scripts/viewmodels/player_board_snapshot.gd")
	var table_script := load("res://scripts/viewmodels/table_snapshot.gd")
	_expect(card_script != null, "CardViewSnapshot script loads")
	_expect(district_script != null, "DistrictViewSnapshot script loads")
	_expect(player_script != null, "PlayerBoardSnapshot script loads")
	_expect(table_script != null, "TableSnapshot script loads")
	if card_script == null or district_script == null or player_script == null or table_script == null:
		return
	var card: Variant = card_script.new().apply_dictionary({"name": "相位否决", "rank": "I", "type": "互动", "effect": "反制一次直接互动。"})
	var district: Variant = district_script.new().apply_dictionary({"name": "雾港区", "summary": "海陆商路交界。"})
	var player: Variant = player_script.new().apply_dictionary({"title": "玩家板", "hand_cards": [card.to_ui_dictionary()]})
	var table: Variant = table_script.new().apply_dictionary({"district": district.to_ui_dictionary(), "player_board": player.to_ui_dictionary()})
	_expect(card.to_ui_dictionary().get("name") == "相位否决", "CardViewSnapshot emits card UI dictionaries")
	_expect(district.to_ui_dictionary().get("title") == "雾港区", "DistrictViewSnapshot emits district UI dictionaries")
	_expect(player.to_ui_dictionary().get("hand_cards", []).size() == 1, "PlayerBoardSnapshot keeps hand cards")
	_expect(table.to_ui_dictionary().has("right_inspector"), "TableSnapshot creates right-inspector UI context")


func _check_empty_player_board_affordance() -> void:
	var packed := load("res://scenes/ui/PlayerBoard.tscn") as PackedScene
	_expect(packed != null, "PlayerBoard scene loads for empty-hand affordance")
	if packed == null:
		return
	var board := packed.instantiate()
	root.add_child(board)
	await process_frame
	_expect(board.has_method("set_player_state"), "PlayerBoard accepts player-state snapshots")
	board.call("set_player_state", {"title": "玩家板｜空手牌", "hand_cards": []})
	await process_frame
	var hand_rack := board.find_child("HandRack", true, false)
	_expect(hand_rack != null, "PlayerBoard keeps a HandRack node for empty hands")
	_expect(hand_rack != null and hand_rack.get_child_count() == 1 and hand_rack.get_child(0) is Label, "PlayerBoard renders an empty-hand affordance instead of collapsing the rack")
	root.remove_child(board)
	board.queue_free()


func _check_main_player_panel_refresh_contract() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(main_source.contains("var player_panel_signature"), "main UI tracks a player panel structure signature")
	_expect(main_source.contains("_refresh_player_panel(false)"), "periodic full refresh does not force PlayerBoard rebuild")
	_expect(main_source.contains("func _player_panel_structure_signature"), "main UI can decide when PlayerBoard structure changed")
	_expect(main_source.contains("func _refresh_player_panel_live_values"), "main UI updates live resource values without destroy/recreate")


func _check_hand_layout_counts() -> void:
	var card_scene := load("res://scenes/CardUI.tscn")
	var hand_script := load("res://scripts/HandLayout.gd")
	_expect(card_scene != null, "CardUI scene loads for hand layout")
	_expect(hand_script != null, "HandLayout script loads for direct layout checks")
	if card_scene == null or hand_script == null:
		return
	for count in [0, 1, 5, 10, 15]:
		var hand := hand_script.new() as Control
		hand.size = Vector2(1000, 250)
		root.add_child(hand)
		for i in range(count):
			var card := card_scene.instantiate() as Control
			hand.add_child(card)
		hand.relayout()
		await process_frame
		_expect(hand.get_child_count() == count, "HandLayout keeps %d cards" % count)
		for child in hand.get_children():
			if child is Control:
				var card := child as Control
				_expect(card.position.x >= -1.0, "hand card stays within left bound for %d cards" % count)
				_expect(card.position.x + card.size.x <= hand.size.x + 1.0, "hand card stays within right bound for %d cards" % count)
		root.remove_child(hand)
		hand.queue_free()


func _has_forbidden_2d_ui(node: Node) -> bool:
	if node is Node2D or node is Sprite2D:
		return true
	for child in node.get_children():
		if _has_forbidden_2d_ui(child):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		push_error(message)
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Layout scene smoke test passed.")
		quit(0)
	else:
		printerr("Layout scene smoke test failed:")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
