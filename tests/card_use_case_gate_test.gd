extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for card use-case gate")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var diagnostics := _diagnostics(main)
	_expect(diagnostics != null, "Coordinator exposes GameplayBalanceDiagnosticsRuntimeService")
	if diagnostics != null:
		var report: Dictionary = diagnostics.card_one_glance_audit_report()
		_expect(int(report.get("checked_count", 0)) >= 80, "card one-glance audit covers the real card codex pool")
		_expect(bool(report.get("passed", false)), "all codex cards have use-case, short effect, route, art/stat, price, rank, gate, and target chips; failures=%s generic=%s" % [
			str(report.get("failures", [])),
			str(report.get("generic_examples", [])),
		])
		_expect((report.get("route_counts", {}) as Dictionary).size() >= 8, "card one-glance audit still covers multiple strategy routes")
		_expect(int(report.get("generic_use_case_count", -1)) == 0, "no card falls back to a generic '临场改局势' use-case")
	if diagnostics != null:
		_check_card_use_case(main, "城市融资1", "加城市GDP")
		_check_card_use_case(main, "商品看涨1", "押商品上涨")
		_check_card_use_case(main, "商品看跌1", "押商品下跌")
		_check_card_use_case(main, "业主透镜1", "查城市业主")
		_check_card_use_case(main, "相位否决1", "反制互动牌")
		var monster_card := String(main.call("_monster_card_name", 0, 1)) if main.has_method("_monster_card_name") else ""
		if monster_card != "":
			_check_card_use_case(main, monster_card, "召唤/升级怪兽")
	root.remove_child(main)
	main.queue_free()
	_finish()


func _check_card_use_case(main: Node, card_name: String, expected: String) -> void:
	var source: Dictionary = _diagnostics(main).card_one_glance_source(card_name)
	_expect(not source.is_empty(), "%s has a one-glance source" % card_name)
	var use_case := String(source.get("use_case", ""))
	var quick_effect := String(source.get("quick_effect", ""))
	_expect(use_case == expected, "%s use-case is '%s'" % [card_name, expected])
	_expect(quick_effect.begins_with(expected + "｜"), "%s quick effect starts with its use-case" % card_name)


func _diagnostics(main: Node) -> GameplayBalanceDiagnosticsRuntimeService:
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	return coordinator.gameplay_balance_diagnostics_service() if coordinator is GameRuntimeCoordinator else null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Card use-case gate test passed.")
		quit(0)
		return
	push_error("Card use-case gate test failed:\n- " + "\n- ".join(_failures))
	quit(1)
