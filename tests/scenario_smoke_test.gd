extends SceneTree

const LOADER_SCRIPT := preload("res://scripts/scenarios/scenario_loader.gd")
const FIXTURE_FACTORY_SCRIPT := preload("res://scripts/scenarios/scenario_fixture_factory.gd")
const BROWSER_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/scenario_browser_snapshot.gd")
const COACH_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/scenario_coach_snapshot.gd")
const LOG_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/scenario_action_log_snapshot.gd")
const REPLAY_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/scenario_replay_panel_snapshot.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var loader: Variant = LOADER_SCRIPT.new()
	var scenarios: Array = loader.load_all()
	_expect(scenarios.size() == 8, "loads the 8 required playable scenarios")
	var ids := {}
	for scenario_variant in scenarios:
		var scenario: Dictionary = scenario_variant if scenario_variant is Dictionary else {}
		var id := str(scenario.get("id", ""))
		ids[id] = true
		_expect(str(scenario.get("title", "")).strip_edges() != "", "%s has a title" % id)
		_expect(str(scenario.get("summary", "")).strip_edges() != "", "%s has a summary" % id)
		_expect(scenario.get("phases", []) is Array and (scenario.get("phases", []) as Array).size() > 0, "%s has playable phases" % id)
		_expect(str(scenario.get("allowed_private_information", "")) == "current_player_only", "%s keeps scenario privacy scoped to the current player" % id)
		for phase_variant in scenario.get("phases", []):
			var phase: Dictionary = phase_variant if phase_variant is Dictionary else {}
			var phase_id := str(phase.get("id", ""))
			_expect(str(phase.get("success_signal", "")).strip_edges() != "", "%s/%s has a real success signal" % [id, phase_id])
			_expect(str(phase.get("snapshot_key", "")).strip_edges() != "", "%s/%s has a replay snapshot key" % [id, phase_id])
			_expect(str(phase.get("focus_target", "")).strip_edges() != "", "%s/%s has a focus target for human recovery" % [id, phase_id])
			_expect(str(phase.get("stuck_hint", "")).strip_edges() != "", "%s/%s has a short stuck hint" % [id, phase_id])
	for required_id in LOADER_SCRIPT.SCENARIO_IDS:
		_expect(bool(ids.get(str(required_id), false)), "scenario pack includes %s" % str(required_id))
		var fixture: Dictionary = FIXTURE_FACTORY_SCRIPT.new().make_fixture(str(required_id), "start")
		_expect(not fixture.is_empty(), "%s fixture loads through ScenarioFixtureFactory" % str(required_id))
		_expect(fixture.get("table_state", {}) is Dictionary, "%s fixture exposes a table_state package" % str(required_id))
	var browser_snapshot: Dictionary = BROWSER_SNAPSHOT_SCRIPT.new().apply_dictionary({"scenarios": scenarios, "selected_id": "first_table"}).to_ui_dictionary()
	_expect(_actions_include_id(browser_snapshot.get("secondary_actions", []), "scenario_settings"), "scenario browser exposes teaching settings")
	await _check_component("res://scenes/ui/ScenarioBrowser.tscn", "set_browser", browser_snapshot)
	var first_fixture: Dictionary = FIXTURE_FACTORY_SCRIPT.new().make_fixture("first_table", "start")
	var empty_coach_snapshot: Dictionary = COACH_SNAPSHOT_SCRIPT.new().apply_dictionary({}).to_ui_dictionary()
	_expect(not bool(empty_coach_snapshot.get("visible", true)), "scenario coach hides empty default state instead of showing placeholder objective text")
	_expect(str(empty_coach_snapshot.get("goal", "")).strip_edges() == "", "empty scenario coach has no placeholder goal")
	_check_market_hand_coach_actions(scenarios)
	var coach_source: Dictionary = first_fixture.get("coach", {}) as Dictionary
	coach_source["font_scale_percent"] = 110
	coach_source["failed_attempts"] = 1
	var coach_snapshot: Dictionary = COACH_SNAPSHOT_SCRIPT.new().apply_dictionary(coach_source).to_ui_dictionary()
	_expect(_actions_include_id(coach_snapshot.get("secondary_actions", []), "scenario_close_coach"), "scenario coach can collapse to a chip")
	_expect(_actions_include_id(coach_snapshot.get("secondary_actions", []), "scenario_focus_target"), "scenario coach offers focus instead of fake completion")
	_expect(not _actions_include_id(coach_snapshot.get("secondary_actions", []), "scenario_skip_step"), "scenario coach does not expose a visible skip-step button")
	_expect(bool(coach_snapshot.get("help_visible", false)) and str(coach_snapshot.get("help_text", "")).strip_edges() != "", "scenario coach shows a short stuck hint after help requests")
	var stuck_primary: Dictionary = coach_snapshot.get("primary_action", {}) if coach_snapshot.get("primary_action", {}) is Dictionary else {}
	_expect(str(stuck_primary.get("id", "")) == "scenario_focus_target" and str(stuck_primary.get("label", "")) == "定位下一步", "scenario coach routes the stuck primary CTA to real focus navigation")
	_expect(int(coach_snapshot.get("font_scale_percent", 0)) == 110, "scenario coach carries a readable font-scale setting")
	await _check_component("res://scenes/ui/ScenarioCoach.tscn", "set_coach", coach_snapshot)
	await _check_component("res://scenes/ui/ScenarioActionLog.tscn", "set_log", LOG_SNAPSHOT_SCRIPT.new().apply_dictionary(first_fixture.get("action_log", {}) as Dictionary).to_ui_dictionary())
	await _check_component("res://scenes/ui/ScenarioReplayPanel.tscn", "set_replay", REPLAY_SNAPSHOT_SCRIPT.new().apply_dictionary(first_fixture.get("replay", {}) as Dictionary).to_ui_dictionary())
	if _failures.is_empty():
		print("Scenario smoke test passed.")
	else:
		push_error("Scenario smoke test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())


func _check_component(path: String, setter: String, data: Dictionary) -> void:
	var packed := load(path) as PackedScene
	_expect(packed != null, "%s loads" % path)
	if packed == null:
		return
	var node := packed.instantiate() as Control
	get_root().add_child(node)
	node.size = Vector2(1280, 720)
	await process_frame
	_expect(node is Control, "%s root is Control" % path)
	_expect(node.has_method(setter), "%s exposes %s" % [path, setter])
	if node.has_method(setter):
		node.call(setter, data)
		await process_frame
		_expect(node.get_combined_minimum_size().x <= 1280 and node.get_combined_minimum_size().y <= 720, "%s fits inside 1280x720 minimum layout" % path)
	node.queue_free()


func _actions_include_id(value: Variant, action_id: String) -> bool:
	var actions: Array = value if value is Array else []
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		if str(action.get("id", "")) == action_id:
			return true
	return false


func _check_market_hand_coach_actions(scenarios: Array) -> void:
	var market_hand := _scenario_by_id(scenarios, "market_hand")
	_expect(not market_hand.is_empty(), "market-hand tutorial scenario exists for coach action-copy checks")
	var expected_compact_goals := {
		"open_rack": "双击亮起区域。",
		"compare_cards": "悬停牌看用途。",
		"buy_pressure": "点右下可买牌。",
		"discard_private": "私密选旧牌。",
	}
	var phases: Array = market_hand.get("phases", []) if market_hand.get("phases", []) is Array else []
	for phase_variant in phases:
		if not (phase_variant is Dictionary):
			continue
		var phase: Dictionary = phase_variant
		var phase_id := str(phase.get("id", "")).strip_edges()
		if not expected_compact_goals.has(phase_id):
			continue
		var snapshot: Dictionary = COACH_SNAPSHOT_SCRIPT.new().apply_dictionary({
			"scenario_id": "market_hand",
			"title": "新手战役｜牌架课程：补给与手牌",
			"current_phase": phase,
			"current_index": expected_compact_goals.keys().find(phase_id),
			"total": expected_compact_goals.size(),
			"campaign_focus_mode": true,
		}).to_ui_dictionary()
		_expect(str(snapshot.get("goal", "")) == str(expected_compact_goals[phase_id]), "market-hand compact coach step %s is a concrete short action" % phase_id)
		var tooltip := str((snapshot.get("primary_action", {}) as Dictionary).get("tooltip", ""))
		_expect(_contains_any(tooltip, ["双击", "鼠标", "点", "选择", "右下", "私密"]), "market-hand compact coach step %s keeps concrete help in tooltip" % phase_id)


func _scenario_by_id(scenarios: Array, scenario_id: String) -> Dictionary:
	for scenario_variant in scenarios:
		if not (scenario_variant is Dictionary):
			continue
		var scenario: Dictionary = scenario_variant
		if str(scenario.get("id", "")).strip_edges() == scenario_id:
			return scenario
	return {}


func _contains_any(text: String, needles: Array) -> bool:
	for needle in needles:
		if text.contains(str(needle)):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)
