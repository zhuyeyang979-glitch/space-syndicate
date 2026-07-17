extends SceneTree

const RETIRED_CONTROLLER_SCENE := "res://scenes/runtime/EconomyCashflowRuntimeController.tscn"
const CURRENT_OWNER_SCENE := "res://scenes/runtime/CommodityFlowRuntimeController.tscn"
const CURRENT_WORLD_BRIDGE_SCENE := "res://scenes/runtime/CommodityFlowWorldBridge.tscn"
const COORDINATOR_SCENE := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const CURRENT_FOCUSED_TEST := "res://tests/commodity_flow_local_baseline_demand_v06_test.gd"
const CURRENT_CONTRACT := "res://docs/installed_commodity_continuous_economy_runtime_contract.md"
const RULESET_PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var retired_packed := load(RETIRED_CONTROLLER_SCENE) as PackedScene
	var current_packed := load(CURRENT_OWNER_SCENE) as PackedScene
	var bridge_packed := load(CURRENT_WORLD_BRIDGE_SCENE) as PackedScene
	var coordinator_packed := load(COORDINATOR_SCENE) as PackedScene
	_expect(
		retired_packed != null
		and current_packed != null
		and bridge_packed != null
		and coordinator_packed != null
		and load(CURRENT_FOCUSED_TEST) is Script
		and FileAccess.file_exists(CURRENT_CONTRACT),
		"retired marker and current Commodity Flow owner-focused assets load"
	)
	if retired_packed == null or current_packed == null or bridge_packed == null or coordinator_packed == null:
		_finish()
		return

	var retired := retired_packed.instantiate()
	root.add_child(retired)
	var retired_debug: Dictionary = retired.call("debug_snapshot")
	var retired_methods_absent := true
	for method_name in ["configure", "advance_clock", "settle_sources", "accumulator_seconds", "to_legacy_save_snapshot", "apply_legacy_save_snapshot", "private_ui_snapshot"]:
		retired_methods_absent = retired_methods_absent and not retired.has_method(method_name)
	_expect(
		bool(retired_debug.get("retired", false))
		and str(retired_debug.get("retired_by", "")) == "SS06-02B"
		and str(retired_debug.get("replacement_owner", "")) == "CommodityFlowRuntimeController"
		and retired_methods_absent,
		"EconomyCashflowRuntimeController is load-only retirement evidence without legacy runtime APIs"
	)

	var current := current_packed.instantiate()
	var bridge := bridge_packed.instantiate()
	root.add_child(current)
	root.add_child(bridge)
	var configured: Dictionary = current.call("configure", RULESET_PROFILE.call("debug_snapshot"))
	var current_debug: Dictionary = current.call("debug_snapshot")
	var bridge_debug: Dictionary = bridge.call("debug_snapshot")
	var public_receipts: Array = current.call("recent_sale_receipts_snapshot", -1)
	var region_gdp: Dictionary = current.call("region_gdp_snapshot", "region.0001")
	var current_save: Dictionary = current.call("to_save_data")
	_expect(
		bool(configured.get("configured", false))
		and bool(current_debug.get("controller_authoritative", false))
		and str(current_debug.get("runtime_owner", "")) == "CommodityFlowRuntimeController"
		and current.has_method("advance_world")
		and current.has_method("recent_sale_receipts_snapshot")
		and current.has_method("region_gdp_snapshot")
		and current.has_method("to_save_data"),
		"CommodityFlowRuntimeController is the current continuous-flow, Sale Receipt, and receipt-GDP owner"
	)
	_expect(
		str(bridge_debug.get("runtime_owner", "")) == "none"
		and str(bridge_debug.get("bridge_role", "")) == "commodity_flow_world_facts_and_atomic_cash_apply"
		and not bool(bridge_debug.get("owns_flow_rules", true))
		and not bool(bridge_debug.get("owns_sale_receipts", true))
		and bridge.has_method("apply_sale_receipt_batch"),
		"CommodityFlowWorldBridge remains non-owning and exposes atomic Sale Receipt cash application"
	)
	_expect(
		public_receipts.is_empty()
		and int(region_gdp.get("region_gdp_per_minute_cents", -1)) == 0
		and not current_save.has("economy_cashflow_timer")
		and _is_pure_data(current_debug)
		and _is_pure_data(region_gdp)
		and _is_pure_data(current_save),
		"current snapshots and save data are pure and do not revive the legacy cashflow timer"
	)

	var coordinator := coordinator_packed.instantiate()
	root.add_child(coordinator)
	var retired_owner := coordinator.get_node_or_null("EconomyCashflowRuntimeController")
	var composed_owner := coordinator.get_node_or_null("CommodityFlowRuntimeController")
	var composed_bridge := coordinator.get_node_or_null("CommodityFlowWorldBridge")
	_expect(
		retired_owner == null
		and composed_owner != null
		and composed_owner.scene_file_path == CURRENT_OWNER_SCENE
		and composed_bridge != null
		and composed_bridge.scene_file_path == CURRENT_WORLD_BRIDGE_SCENE,
		"GameRuntimeCoordinator composes only the current economy owner pair"
	)

	var coordinator_source := FileAccess.get_file_as_string(COORDINATOR_SCENE)
	var contract_source := FileAccess.get_file_as_string(CURRENT_CONTRACT)
	_expect(
		coordinator_source.contains("CommodityFlowRuntimeController.tscn")
		and coordinator_source.contains("CommodityFlowWorldBridge.tscn")
		and not coordinator_source.contains("EconomyCashflowRuntimeController.tscn")
		and contract_source.contains("Apply the cash batch atomically through the non-owning bridge.")
		and contract_source.contains("Public receipt projection removes commodity-owner identity")
		and contract_source.contains("active focused gates must replace old baseline/backpressure oracles"),
		"composition and focused contract preserve atomic cash, privacy, and retirement boundaries"
	)

	retired.queue_free()
	current.queue_free()
	bridge.queue_free()
	coordinator.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("ECONOMY_CASHFLOW_RETIREMENT_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("ECONOMY_CASHFLOW_RETIREMENT_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)


func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not _is_pure_data(key) or not _is_pure_data(value[key]):
				return false
		return true
	return false
