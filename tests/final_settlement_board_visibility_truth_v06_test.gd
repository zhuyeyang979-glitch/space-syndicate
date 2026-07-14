extends SceneTree

const BOARD_SCENE_PATH := "res://scenes/ui/FinalSettlementBoard.tscn"
const PRIVATE_CASH_SENTINEL := "987654.32"
const FORBIDDEN_PUBLIC_KEYS := [
	"cash",
	"cash_cents",
	"cash_ledger_cents",
	"available_cents",
	"escrow_cents",
	"economic_assets",
]

var _checks := 0
var _failures: Array[String] = []
var _emitted_actions: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(BOARD_SCENE_PATH) as PackedScene
	_expect(packed != null, "real FinalSettlementBoard scene loads")
	if packed == null:
		_finish()
		return
	var host := Control.new()
	host.name = "VisibleFinalSettlementTestHost"
	host.custom_minimum_size = Vector2(1200, 800)
	host.size = Vector2(1200, 800)
	root.add_child(host)
	var layout := VBoxContainer.new()
	layout.name = "VisibleFinalSettlementLayout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(layout)
	var board := packed.instantiate() as Control
	_expect(board != null, "real FinalSettlementBoard scene instantiates")
	if board == null:
		host.queue_free()
		_finish()
		return
	layout.add_child(board)
	board.action_requested.connect(_on_action_requested)
	await process_frame

	var snapshot := _public_board_snapshot()
	var forbidden_paths: Array[String] = []
	_collect_forbidden_key_paths(snapshot, "board", forbidden_paths)
	_expect(forbidden_paths.is_empty(), "board input follows the public projection boundary: %s" % [forbidden_paths])
	board.call("set_board", snapshot)
	await process_frame
	await process_frame

	_expect(board.name == "FinalSettlementBoardPanel", "production root keeps its established FinalSettlementBoardPanel identity")
	_expect(host.is_visible_in_tree() and layout.is_visible_in_tree() and board.is_visible_in_tree(), "real board is visible inside a visible parent container")
	_expect(board.size.x > 0.0 and board.size.y > 0.0 and board.get_global_rect().size.x > 0.0 and board.get_global_rect().size.y > 0.0, "real board receives a non-zero local and global layout size")
	_expect(str((board.find_child("FinalSettlementBoardTitle", true, false) as Label).text) == "终局结算｜公开结果", "board renders the supplied settlement title")
	_expect(_container_child_count(board, "FinalSettlementKpiGrid") == 2, "board renders the supplied KPI cards")
	_expect(_container_child_count(board, "FinalSettlementRankTrack") == 2, "board renders the supplied public rankings")
	_expect(_container_child_count(board, "FinalSettlementAfterActionGrid") == 2, "board renders the supplied after-actions")
	_expect(not _rendered_text(board).contains(PRIVATE_CASH_SENTINEL), "rendered board contains no exact opponent-cash sentinel")

	var first_counts := _dynamic_counts(board)
	board.call("set_board", snapshot.duplicate(true))
	await process_frame
	await process_frame
	var replay_counts := _dynamic_counts(board)
	_expect(_named_node_count(host, "FinalSettlementBoardPanel") == 1, "repeated set_board never creates a second board root")
	_expect(replay_counts == first_counts, "repeated set_board replaces dynamic children instead of duplicating them")
	_expect(board.is_visible_in_tree() and board.size.x > 0.0 and board.size.y > 0.0, "replayed board remains visible with non-zero size")

	var action_button := board.find_child("FinalSettlementAfterActionButton", true, false) as Button
	_expect(action_button != null, "replayed board exposes one actionable settlement control")
	if action_button != null:
		action_button.emit_signal("pressed")
		await process_frame
	_expect(_emitted_actions == ["standings"], "one button press emits exactly one stable action after repeated set_board")

	board.queue_free()
	host.queue_free()
	await process_frame
	_finish()


func _public_board_snapshot() -> Dictionary:
	return {
		"title": "终局结算｜公开结果",
		"title_tooltip": "只显示已经授权的公开胜利结果。",
		"tooltip": "终局结算公开面板。",
		"kpi_columns": 2,
		"money_columns": 1,
		"rank_columns": 2,
		"action_columns": 2,
		"chips": [
			{"text": "胜者:本地玩家", "tooltip": "公开胜者", "accent": Color("#facc15")},
			{"text": "审计完成", "tooltip": "公开审计状态", "accent": Color("#38bdf8")},
		],
		"kpis": [
			{"title": "Top-K归属GDP", "body": "144 GDP/min", "meta": "第一比较项", "accent": Color("#38bdf8")},
			{"title": "控制区域", "body": "2区", "meta": "第二比较项", "accent": Color("#4ade80")},
		],
		"money_title": "公开审计证据",
		"money_sources": [
			{"title": "#1 本地玩家", "start_line": "Top-K归属GDP 144/min", "settlement_line": "控制区域2", "income_line": "公开收入趋势", "status_line": "终点有效", "accent": Color("#facc15")},
		],
		"event_title": "公开事件",
		"event_lines": ["公开审计已经完成。"],
		"rank_title": "排名轨｜Top-K GDP → 控区 → 现金规则",
		"ranks": [
			{"title": "#1｜本地玩家｜胜者", "score": "144 GDP/min", "stats": "控区2", "income": "公开经济状态", "identity": "本地玩家", "accent": Color("#facc15")},
			{"title": "#2｜电脑对手", "score": "120 GDP/min", "stats": "控区1", "income": "公开经济状态", "identity": "电脑对手", "accent": Color("#38bdf8")},
		],
		"action_title": "赛后入口",
		"actions": [
			{"id": "standings", "title": "查看局势排名", "body": "查看公开排名。", "accent": Color("#facc15")},
			{"id": "new_run", "title": "开始新局", "body": "返回开局准备。", "accent": Color("#67e8f9")},
		],
	}


func _dynamic_counts(board: Node) -> Dictionary:
	return {
		"chips": _container_child_count(board, "FinalSettlementHeaderChipRail"),
		"kpis": _container_child_count(board, "FinalSettlementKpiGrid"),
		"money": _container_child_count(board, "FinalSettlementMoneySourcePanel"),
		"events": _container_child_count(board, "FinalSettlementEventLineBox"),
		"ranks": _container_child_count(board, "FinalSettlementRankTrack"),
		"actions": _container_child_count(board, "FinalSettlementAfterActionGrid"),
	}


func _container_child_count(parent: Node, container_name: String) -> int:
	var container := parent.find_child(container_name, true, false)
	return container.get_child_count() if container != null else -1


func _named_node_count(parent: Node, node_name: String) -> int:
	var count := 0
	if parent.name == node_name:
		count += 1
	for child in parent.get_children():
		count += _named_node_count(child, node_name)
	return count


func _rendered_text(parent: Node) -> String:
	var lines: Array[String] = []
	_collect_rendered_text(parent, lines)
	return "\n".join(lines)


func _collect_rendered_text(parent: Node, lines: Array[String]) -> void:
	if parent is Label:
		lines.append((parent as Label).text)
		lines.append((parent as Label).tooltip_text)
	elif parent is Button:
		lines.append((parent as Button).text)
		lines.append((parent as Button).tooltip_text)
	elif parent is Control:
		lines.append((parent as Control).tooltip_text)
	for child in parent.get_children():
		_collect_rendered_text(child, lines)


func _collect_forbidden_key_paths(value: Variant, path: String, result: Array[String]) -> void:
	if value is Dictionary:
		for key_variant in value.keys():
			var key := str(key_variant)
			var child_path := "%s.%s" % [path, key]
			if FORBIDDEN_PUBLIC_KEYS.has(key.to_lower()):
				result.append(child_path)
			_collect_forbidden_key_paths(value[key_variant], child_path, result)
	elif value is Array:
		for index in range(value.size()):
			_collect_forbidden_key_paths(value[index], "%s[%d]" % [path, index], result)


func _on_action_requested(action_id: String) -> void:
	_emitted_actions.append(action_id)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print("FINAL_SETTLEMENT_BOARD_VISIBILITY_TRUTH_V06_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(_failures.size())
