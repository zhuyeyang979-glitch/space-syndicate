extends Node

@export var auto_run := true

var _checks := 0
var _failures: Array[String] = []
var _run_started := false
var _last_result: Dictionary = {}


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("_run_auto_bench")


func _run_auto_bench() -> void:
	var result := await run_bench()
	get_tree().quit(0 if bool(result.get("passed", false)) else 1)


func run_bench() -> Dictionary:
	if _run_started:
		return _last_result.duplicate(true)
	_run_started = true
	await get_tree().process_frame
	await get_tree().process_frame
	var production_main := get_node_or_null("ProductionMain")
	var lifecycle := production_main.get_node_or_null("RuntimeServices/MenuLifecycleApplicationFlowController") as MenuLifecycleApplicationFlowController if production_main != null else null
	var flow := production_main.get_node_or_null("RuntimeServices/ApplicationFlowPort") as ApplicationFlowPort if production_main != null else null
	var coordinator := production_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator if production_main != null else null
	var world := production_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/WorldSessionState") as WorldSessionState if production_main != null else null
	var overlay := production_main.get_node_or_null("RuntimeGameScreen/OverlayLayer/RuntimeSurfaceLayer/MenuModalOverlay") as SpaceSyndicateMenuOverlay if production_main != null else null
	_check(lifecycle != null, "production composes one typed menu lifecycle owner")
	_check(flow != null and coordinator != null and world != null and overlay != null, "production menu dependencies exist")
	if lifecycle == null or flow == null or coordinator == null or world == null or overlay == null:
		return _finish()

	var initial_debug := lifecycle.debug_snapshot()
	_check(int(initial_debug.get("root_open_count", 0)) == 1, "startup opens the root lobby exactly once")
	_check(overlay.visible and str(overlay.debug_snapshot().get("title", "")) == "太空辛迪加｜星球赌桌", "startup root lobby is visible")
	_check(overlay.find_child("MainMenuPlanetLobbyPanel", true, false) != null, "root lobby is a scene-owned child")

	world.players = [
		{"name": "本地玩家"},
		{"name": "对手甲"},
		{"name": "对手乙"},
	]
	coordinator.begin_session({"session_id": "menu-lifecycle-bench", "scenario_id": "bench", "seed": 17, "player_count": 3})
	_check(lifecycle.open_pause_menu(), "pause menu opens through the lifecycle owner")
	_check(coordinator.session_is_paused(), "opening a menu pauses the authoritative session")
	_check(str(overlay.debug_snapshot().get("title", "")) == "暂停菜单", "pause shell is rendered")
	_check(overlay.find_child("PauseMenuSummaryBoard", true, false) != null, "pause summary uses the reusable scene")

	var pause_before := int(lifecycle.debug_snapshot().get("pause_open_count", 0))
	var pause_signals := [0]
	flow.pause_menu_requested.connect(func() -> void: pause_signals[0] = int(pause_signals[0]) + 1)
	_check(flow.request_pause_menu(), "typed pause request is accepted")
	_check(int(pause_signals[0]) == 1 and int(lifecycle.debug_snapshot().get("pause_open_count", 0)) == pause_before + 1, "typed pause request reaches the lifecycle exactly once")

	var page_before := int(lifecycle.debug_snapshot().get("page_prepare_count", 0))
	_check(flow.submit_action("rules"), "rules action remains routed")
	_check(flow.submit_action("economy"), "economy action remains routed")
	_check(flow.submit_action("standings"), "standings action remains routed")
	_check(int(lifecycle.debug_snapshot().get("page_prepare_count", 0)) == page_before + 3, "rules, economy, and standings share one exact page-opening lifecycle")
	_check(coordinator.session_is_paused(), "read-only pages keep the session paused")

	_check(flow.request_menu("终局结算", "公开结算摘要。", false), "external typed menu request is accepted")
	_check(str(overlay.debug_snapshot().get("title", "")) == "终局结算", "external menu request is rendered without Main")
	var requested_before := int(lifecycle.debug_snapshot().get("requested_shell_count", 0))
	_check(not flow.request_menu("", "", false), "invalid external menu request fails closed")
	_check(int(lifecycle.debug_snapshot().get("requested_shell_count", 0)) == requested_before, "rejected external request produces no shell")

	_check(lifecycle.open_pause_menu(), "pause menu can be reopened before continue")
	var close_before := int(lifecycle.debug_snapshot().get("close_count", 0))
	overlay.continue_requested.emit()
	_check(int(lifecycle.debug_snapshot().get("close_count", 0)) == close_before + 1, "continue signal closes exactly once")
	_check(not overlay.visible and not coordinator.session_is_paused(), "continue hides the shell and resumes the session")

	var main_source := FileAccess.get_file_as_string("res://scripts/" + "main.gd")
	for retired_symbol in [
		"func _open_main_menu(", "func _open_pause_menu(", "func _show_menu(", "func _close_menu(",
		"func _bind_menu_overlay_scene(", "func _on_menu_quick_nav_action_requested(", "MenuRootLobbyScene",
		"var menu_overlay", "var menu_preview_box", "var menu_load_run_button", "var speed_before_menu", "var time_scale",
	]:
		_check(not main_source.contains(retired_symbol), "Main menu lifecycle symbol is retired: %s" % retired_symbol)
	var lifecycle_source := FileAccess.get_file_as_string("res://scripts/runtime/menu_lifecycle_application_flow_controller.gd")
	_check(not lifecycle_source.contains("scripts/" + "main.gd") and not lifecycle_source.contains("/root/" + "Main") and not lifecycle_source.contains("current_scene"), "menu lifecycle has no Main or service-locator fallback")
	for private_token in ["hidden_owner", "true_owner", "owner_truth", "ai_plan", "decision_samples", "learning_bonus"]:
		_check(not lifecycle_source.to_lower().contains(private_token), "menu lifecycle contains no private token: %s" % private_token)
	return _finish()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> Dictionary:
	_last_result = {"passed": _failures.is_empty(), "checks": _checks, "failures": _failures.duplicate()}
	print("MenuLifecycleApplicationFlowBench: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		push_error("MenuLifecycleApplicationFlowBench failures:\n- " + "\n- ".join(_failures))
	return _last_result.duplicate(true)
