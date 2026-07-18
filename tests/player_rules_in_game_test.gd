extends SceneTree

const RULES_SNAPSHOT := preload("res://scripts/viewmodels/rules_quick_reference_snapshot_v06.gd")
const RULES_BOARD_SCENE_PATH := "res://scenes/ui/RulesQuickReferenceBoard.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_rules_are_game_ui_data()
	await _check_rules_board_renders_player_questions()
	_finish()


func _check_rules_are_game_ui_data() -> void:
	var snapshot: Dictionary = RULES_SNAPSHOT.compose(1120.0)
	var snapshot_text := var_to_str(snapshot)
	for term in [
		"区域怎样算控制",
		"怎样进入终局",
		"审计怎样结算",
		"现金为 0 会出局吗",
		"普通牌从哪里买",
		"怎样升级手牌",
		"何时自动合并",
		"哪些旧规则已退役",
	]:
		_expect(snapshot_text.contains(term), "game rules UI answers player question: %s" % term)
	for module_term in [
		"动态区域胜利",
		"商品 GDP 控制",
		"公开审计",
		"破产",
		"日照动态市场",
		"主动合并",
		"满手领取例外",
		"退役旧链路",
	]:
		_expect(snapshot_text.contains(module_term), "game rules UI exposes table module: %s" % module_term)
	_expect(str(snapshot.get("visibility_scope", "")) == "public_static_rules", "rules snapshot is explicitly public static presentation data")
	_expect(not snapshot_text.contains("player_index") and not snapshot_text.contains("cash") and not snapshot_text.contains("hand"), "rules snapshot does not expose runtime player state")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(not main_source.contains("func _rules_quick_reference_snapshot"), "Main no longer owns a duplicate rules snapshot builder")
	var application_flow_source := FileAccess.get_file_as_string("res://scripts/runtime/application_flow_controller.gd")
	_expect(application_flow_source.contains("RULES_SNAPSHOT_SCRIPT.compose") and not main_source.contains("RulesQuickReferenceSnapshotV06Script.compose"), "ApplicationFlowController composes the v0.6 pure-data rules snapshot without a Main fallback")


func _check_rules_board_renders_player_questions() -> void:
	var board_scene := load(RULES_BOARD_SCENE_PATH) as PackedScene
	_expect(board_scene != null, "rules board scene loads")
	if board_scene == null:
		return
	var board := board_scene.instantiate() as Control
	_expect(board != null and board.has_method("set_board"), "rules board instantiates and accepts game data")
	if board == null or not board.has_method("set_board"):
		return
	root.add_child(board)
	await process_frame
	board.call("set_board", RULES_SNAPSHOT.compose(1120.0))
	await process_frame
	var rendered_text := _node_text(board)
	for term in ["区域怎样算控制", "普通牌从哪里买", "怎样升级手牌", "现金为 0 会出局吗"]:
		_expect(rendered_text.contains(term), "rules board renders player-facing question card: %s" % term)
	var kpi_grid := board.find_child("RulesQuickReferenceKpiGrid", true, false)
	var module_grid := board.find_child("RulesQuickReferenceModuleGrid", true, false)
	var keyword_rail := board.find_child("RulesQuickReferenceKeywordRail", true, false)
	_expect(kpi_grid != null and kpi_grid.get_child_count() >= 8, "rules board renders at least eight first-glance rule cards")
	_expect(module_grid != null and module_grid.get_child_count() >= 8, "rules board renders v0.6 rule modules instead of a prose-only rulebook")
	_expect(keyword_rail != null and keyword_rail.get_child_count() >= 8, "rules board renders a keyword legend for compact card text")
	root.remove_child(board)
	board.queue_free()
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
