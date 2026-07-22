extends Control
class_name InstalledCommodityContinuousEconomyCharacterizationBench

const SUPPORT := preload("res://tests/support/commodity_flow_v06_test_support.gd")

@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var cases_text: RichTextLabel = %CasesText

var _checks := 0
var _failures: Array[String] = []
var _case_rows: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_market_first_case()
	_run_warehouse_and_public_case()
	status_label.text = "PASS" if _failures.is_empty() else "FAIL"
	status_label.modulate = Color(0.42, 0.92, 0.62) if _failures.is_empty() else Color(1.0, 0.36, 0.32)
	summary_label.text = "%d checks · %d failures" % [_checks, _failures.size()]
	ownership_text.text = (
		"[b]唯一商品流 owner[/b]\nCommodityFlowRuntimeController\n\n"
		+ "[b]路线事实 owner[/b]\nRouteNetworkRuntimeController\n\n"
		+ "[b]自动顺序[/b]\n市场 → 区域基础消费 → 仓库 → 浪费产能\n\n"
		+ "[b]公共流[/b]\n只投影已提交实际流，不公开供应者或候选路线"
	)
	cases_text.text = "\n".join(_case_rows)
	print("INSTALLED_COMMODITY_CONTINUOUS_ECONOMY_CHARACTERIZATION_BENCH|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	await get_tree().process_frame
	get_tree().quit(_failures.size())


func _run_market_first_case() -> void:
	var region := SUPPORT.region("bench.market")
	var market := SUPPORT.facility("bench.market.facility", "bench.market", "market", 1)
	var fixture := SUPPORT.create_fixture(get_tree(), [region], [market], [])
	var flow: Node = fixture.get("flow")
	var bridge = fixture.get("bridge")
	_check(bool((fixture.get("configured", {}) as Dictionary).get("configured", false)), "controller_configured")
	_check(bool(SUPPORT.install(flow, market, SUPPORT.DEFAULT_PRODUCT_ID, "demand", 1, 1).get("finalized", false)), "market_demand_installed_first")
	var no_supply: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	_check(int(no_supply.get("market_backlog_milliunits", 0)) == 10000, "backlog_grows_without_supply")
	var factory := SUPPORT.facility("bench.factory", "bench.market", "factory", 0)
	bridge.facts["facilities"] = [market, factory]
	_check(bool(SUPPORT.install(flow, factory, SUPPORT.DEFAULT_PRODUCT_ID, "production", 0, 2).get("finalized", false)), "factory_installed_later")
	var no_route: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	_check(int(no_route.get("market_sold_milliunits", -1)) == 0, "same_region_requires_route_network_fact")
	bridge.facts["route_candidates"] = [
		SUPPORT.route("bench.local.route", "bench.market", "bench.market", 1000000, "bench.local.route", ["local"], 0),
	]
	var recovery_one: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	var recovery_two: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	_check(int(recovery_one.get("market_sold_milliunits", 0)) == 20000 and int(recovery_one.get("market_backlog_milliunits", -1)) == 10000, "steady_precedes_recovery")
	_check(int(recovery_two.get("market_backlog_milliunits", -1)) == 0, "backlog_recovers_to_zero")
	SUPPORT.free_fixture(fixture)


func _run_warehouse_and_public_case() -> void:
	var regions := [
		SUPPORT.region("bench.source", ["bench.sink"], "land"),
		SUPPORT.region("bench.sink", ["bench.source"], "sea"),
	]
	var factory := SUPPORT.facility("bench.shared.factory", "bench.source", "factory", 0)
	var market := SUPPORT.facility("bench.shared.market", "bench.sink", "market", 1)
	var warehouse := SUPPORT.facility("bench.shared.warehouse", "bench.sink", "warehouse", 2)
	var route := SUPPORT.route("bench.shared.route", "bench.source", "bench.sink", 15, "bench.shared.resource", ["land"], 1)
	var fixture := SUPPORT.create_fixture(get_tree(), regions, [factory, market, warehouse], [route])
	var flow: Node = fixture.get("flow")
	var bridge = fixture.get("bridge")
	SUPPORT.install(flow, factory, SUPPORT.DEFAULT_PRODUCT_ID, "production", 0, 2)
	SUPPORT.install(flow, market, SUPPORT.DEFAULT_PRODUCT_ID, "demand", 1, 1)
	var advance: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	_check(int(advance.get("market_sold_milliunits", 0)) == 10000, "market_phase_first")
	_check(int(advance.get("ambient_consumed_milliunits", 0)) == 1000, "ambient_phase_second")
	_check(int(advance.get("stored_milliunits", 0)) == 5000, "warehouse_uses_remaining_shared_capacity")
	_check(int(advance.get("wasted_milliunits", 0)) == 4000, "unmatched_output_becomes_waste")
	var public_flow: Dictionary = flow.call("recent_actual_flow_snapshot")
	var serialized_public := JSON.stringify(public_flow).to_lower()
	_check(not serialized_public.contains("owner") and not serialized_public.contains("installation") and not serialized_public.contains("transaction"), "public_actual_flow_privacy")
	var kinds: Dictionary = {}
	for row_variant in public_flow.get("rows", []):
		if row_variant is Dictionary:
			kinds[str((row_variant as Dictionary).get("flow_kind", ""))] = true
	_check(kinds.has("market_sale") and kinds.has("ambient_consumption") and kinds.has("warehouse_inbound"), "public_actual_flow_kinds")
	var saved: Dictionary = flow.call("to_save_data")
	_check(int(saved.get("state_version", 0)) == 3, "current_save_schema")
	var restored_fixture := SUPPORT.create_fixture(get_tree(), regions, [factory, market, warehouse], [route])
	var restored_flow: Node = restored_fixture.get("flow")
	_check(bool(restored_flow.call("apply_save_data", saved).get("applied", false)), "save_restore_applies")
	_check(JSON.stringify(saved) == JSON.stringify(restored_flow.call("to_save_data")), "save_restore_exact")
	SUPPORT.free_fixture(fixture)
	SUPPORT.free_fixture(restored_fixture)


func _check(condition: bool, case_id: String) -> void:
	_checks += 1
	var passed := condition
	_case_rows.append("[color=#68d391]PASS[/color]  %s" % case_id if passed else "[color=#fc8181]FAIL[/color]  %s" % case_id)
	if passed:
		return
	_failures.append(case_id)
	push_error(case_id)
