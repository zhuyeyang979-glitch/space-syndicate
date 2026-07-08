extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const RULES_BOARD_SCENE_PATH := "res://scenes/ui/RulesQuickReferenceBoard.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_rules_are_game_ui_data()
	await _check_rules_board_renders_player_questions()
	_finish()


func _check_rules_are_game_ui_data() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main scene loads for in-game rules coverage")
	if packed == null:
		return
	var main := packed.instantiate()
	_expect(main != null, "main scene instantiates for in-game rules coverage")
	if main == null:
		return
	var snapshot: Dictionary = main.call("_rules_quick_reference_snapshot") as Dictionary
	var snapshot_text := var_to_str(snapshot)
	for term in [
		"我怎么赢",
		"开局先做",
		"为什么建城",
		"怎么买/出牌",
		"怪兽为何重要",
		"怎么读线索",
		"GDP怎么变",
		"何时结束",
	]:
		_expect(snapshot_text.contains(term), "game rules UI answers player question: %s" % term)
	for module_term in [
		"城市化",
		"区域牌架",
		"公开牌轨",
		"怪兽赌局",
		"军队",
		"天气",
		"金融",
		"情报",
		"商品/商路",
	]:
		_expect(snapshot_text.contains(module_term), "game rules UI exposes table module: %s" % module_term)
	_expect(snapshot_text.contains("按现金比例押"), "monster wager rule is exposed as percentage-based betting in the game UI")
	_expect(not snapshot_text.contains("守护者") and not snapshot_text.contains("D6") and not snapshot_text.contains("旧"), "game rules UI does not expose obsolete/development-history rules")
	main.queue_free()


func _check_rules_board_renders_player_questions() -> void:
	var main_scene := load(MAIN_SCENE_PATH) as PackedScene
	var board_scene := load(RULES_BOARD_SCENE_PATH) as PackedScene
	_expect(main_scene != null and board_scene != null, "main and rules board scenes load")
	if main_scene == null or board_scene == null:
		return
	var main := main_scene.instantiate()
	var board := board_scene.instantiate() as Control
	_expect(main != null and board != null and board.has_method("set_board"), "rules board instantiates and accepts game data")
	if main == null or board == null or not board.has_method("set_board"):
		return
	root.add_child(board)
	await process_frame
	board.call("set_board", main.call("_rules_quick_reference_snapshot"))
	await process_frame
	var rendered_text := _node_text(board)
	for term in ["我怎么赢", "开局先做", "为什么建城", "怪兽为何重要", "何时结束"]:
		_expect(rendered_text.contains(term), "rules board renders player-facing question card: %s" % term)
	var kpi_grid := board.find_child("RulesQuickReferenceKpiGrid", true, false)
	var module_grid := board.find_child("RulesQuickReferenceModuleGrid", true, false)
	var keyword_rail := board.find_child("RulesQuickReferenceKeywordRail", true, false)
	_expect(kpi_grid != null and kpi_grid.get_child_count() >= 8, "rules board renders at least eight first-glance rule cards")
	_expect(module_grid != null and module_grid.get_child_count() >= 10, "rules board renders table modules instead of a prose-only rulebook")
	_expect(keyword_rail != null and keyword_rail.get_child_count() >= 8, "rules board renders a keyword legend for compact card text")
	root.remove_child(board)
	board.queue_free()
	main.queue_free()
	await process_frame


func _node_text(node: Node) -> String:
	var parts: Array[String] = []
	_collect_text(node, parts)
	return "\n".join(parts)


func _collect_text(node: Node, parts: Array[String]) -> void:
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		_collect_text(child, parts)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("player_rules_in_game_test passed")
		quit(0)
	else:
		printerr("player_rules_in_game_test failed: %d failure(s)" % _failures.size())
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
