extends SceneTree

const CONTROLLER_SCENE := "res://scenes/runtime/EconomyCashflowRuntimeController.tscn"
const COORDINATOR_SCENE := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const RULESET_SCENE := "res://scenes/runtime/RulesetRuntimeBridge.tscn"
const MAIN_SCENE := "res://scenes/main.tscn"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var controller_packed := load(CONTROLLER_SCENE) as PackedScene
	var coordinator_packed := load(COORDINATOR_SCENE) as PackedScene
	var ruleset_packed := load(RULESET_SCENE) as PackedScene
	_expect(controller_packed != null and coordinator_packed != null and ruleset_packed != null, "cashflow runtime scenes load")
	if controller_packed == null or coordinator_packed == null or ruleset_packed == null:
		_finish()
		return
	var coordinator := coordinator_packed.instantiate()
	var ruleset := ruleset_packed.instantiate()
	_expect(coordinator != null and ruleset != null, "coordinator and ruleset instantiate")
	if coordinator == null or ruleset == null:
		_finish()
		return
	coordinator.call("configure", ruleset.call("debug_snapshot"))
	var controller := coordinator.get_node_or_null("EconomyCashflowRuntimeController")
	_expect(controller != null and controller.scene_file_path == CONTROLLER_SCENE, "GameRuntimeCoordinator composes the editable cashflow controller")
	var required_methods := ["configure", "reset_state", "advance_clock", "settle_sources", "accumulator_seconds", "to_legacy_save_snapshot", "apply_legacy_save_snapshot", "private_ui_snapshot", "debug_snapshot"]
	for method_name in required_methods:
		_expect(controller != null and controller.has_method(method_name), "controller exposes %s" % method_name)
	if controller != null:
		var debug: Dictionary = controller.call("debug_snapshot")
		_expect(bool(debug.get("controller_authoritative", false)) and bool(debug.get("realtime_income_enabled", false)), "v0.4 realtime-income capability configures controller authority")
		_expect(is_equal_approx(float(debug.get("tick_interval_seconds", 0.0)), 1.0) and is_equal_approx(float(debug.get("basis_seconds", 0.0)), 60.0), "scene owns the 1/60 cadence")
		controller.call("reset_state")
		var ticks: Array = controller.call("advance_clock", 2.25, {})
		_expect(ticks == [1.0, 1.0] and is_equal_approx(float(controller.call("accumulator_seconds")), 0.25), "clock emits deterministic ticks and retains sub-tick time")
		var payout: Dictionary = controller.call("settle_sources", 1.0, {"sources": [_source(40, 0.0)]})
		var event: Dictionary = (payout.get("payout_events", []) as Array)[0] as Dictionary
		_expect(int(event.get("paid_amount", -1)) == 0 and is_equal_approx(float(event.get("remainder_after", -1.0)), 2.0 / 3.0), "one-second GDP accrual floors explicitly and returns its remainder")
		var payout_two: Dictionary = controller.call("settle_sources", 1.0, {"sources": [_source(40, float(event.get("remainder_after", 0.0)))]})
		var event_two: Dictionary = (payout_two.get("payout_events", []) as Array)[0] as Dictionary
		_expect(int(event_two.get("paid_amount", -1)) == 1 and is_equal_approx(float(event_two.get("remainder_after", -1.0)), 1.0 / 3.0), "fractional remainder carries into the next payout plan")
		controller.call("apply_legacy_save_snapshot", {"economy_cashflow_timer": 0.75})
		var legacy: Dictionary = controller.call("to_legacy_save_snapshot")
		_expect(is_equal_approx(float(legacy.get("economy_cashflow_timer", 0.0)), 0.75), "legacy v1 timer key roundtrips through controller authority")
		_expect(_is_pure_data(debug) and _is_pure_data(controller.call("private_ui_snapshot", 0)) and _is_pure_data(payout_two), "controller inputs and outputs remain pure data")
	var main_packed := load(MAIN_SCENE) as PackedScene
	var main := main_packed.instantiate() if main_packed != null else null
	_expect(main != null, "main scene instantiates")
	if main != null:
		var nested := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/EconomyCashflowRuntimeController")
		_expect(nested != null and nested.scene_file_path == CONTROLLER_SCENE, "main scene composes cashflow controller beneath GameRuntimeCoordinator")
		main.free()
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var network_source := FileAccess.get_file_as_string("res://scripts/runtime/city_trade_network_runtime_controller.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	_expect(not main_source.contains("var economy_cashflow_timer") and not main_source.contains("ECONOMY_CASHFLOW_TICK_SECONDS") and not main_source.contains("ECONOMY_CASHFLOW_BASIS_SECONDS"), "main has no duplicate cashflow timer or cadence constants")
	_expect(not main_source.contains("func _settle_city_project_cashflow_seconds") and main_source.contains("advance_economy_cashflow") and main_source.contains("func _settle_city_cashflow_seconds") and main_source.contains('"settle_cashflow_seconds"') and network_source.contains('call("settle_sources"') and coordinator_source.contains("func settle_economy_sources("), "main keeps a narrow compatibility entry while CityTradeNetworkRuntimeController composes payout sources and delegates arithmetic to EconomyCashflowRuntimeController")
	coordinator.free()
	ruleset.free()
	_finish()


func _source(gdp_per_minute: int, remainder: float) -> Dictionary:
	return {
		"source_id": "gdp.region.0000.project.g1.player.0",
		"source_kind": "project_share",
		"district_index": 0,
		"player_index": 0,
		"gdp_per_minute": gdp_per_minute,
		"remainder": remainder,
		"role_bonus_gdp_per_minute": 0,
		"role_bonus_basis_gdp_per_minute": gdp_per_minute,
		"eligible": true,
	}


func _is_pure_data(value: Variant) -> bool:
	if typeof(value) == TYPE_OBJECT or value is Callable:
		return false
	if value is Dictionary:
		for key in value.keys():
			if not _is_pure_data(key) or not _is_pure_data(value[key]):
				return false
	elif value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("ECONOMY CASHFLOW RUNTIME: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("ECONOMY CASHFLOW RUNTIME PASS")
		quit(0)
		return
	print("ECONOMY CASHFLOW RUNTIME FAIL: %d" % failures.size())
	quit(1)
