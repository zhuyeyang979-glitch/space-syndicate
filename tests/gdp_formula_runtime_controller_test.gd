extends SceneTree

const RETIRED_CONTROLLER_SCENE := "res://scenes/runtime/GdpFormulaRuntimeController.tscn"
const CURRENT_OWNER_SCENE := "res://scenes/runtime/CommodityFlowRuntimeController.tscn"
const COORDINATOR_SCENE := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const RULESET_PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var retired_packed := load(RETIRED_CONTROLLER_SCENE) as PackedScene
	var current_packed := load(CURRENT_OWNER_SCENE) as PackedScene
	_expect(retired_packed != null and current_packed != null, "retired GDP marker and current Commodity Flow owner scenes load")
	if retired_packed == null or current_packed == null:
		_finish()
		return

	var retired := retired_packed.instantiate()
	root.add_child(retired)
	var retired_debug: Dictionary = retired.call("debug_snapshot")
	_expect(
		bool(retired_debug.get("retired", false))
		and str(retired_debug.get("retired_by", "")) == "SS06-02B"
		and str(retired_debug.get("replacement_owner", "")) == "CommodityFlowRuntimeController.sale_receipts"
		and not retired.has_method("calculate_city_gdp")
		and not retired.has_method("calculate_transit_gdp"),
		"GdpFormulaRuntimeController exposes only its audited retirement marker"
	)

	var current := current_packed.instantiate()
	root.add_child(current)
	current.call("configure", RULESET_PROFILE.call("debug_snapshot"))
	var current_debug: Dictionary = current.call("debug_snapshot")
	var public_receipts: Array = current.call("recent_sale_receipts_snapshot", -1)
	var region_gdp: Dictionary = current.call("region_gdp_snapshot", "region.0001")
	_expect(
		current.has_method("advance_world")
		and current.has_method("recent_sale_receipts_snapshot")
		and current.has_method("region_gdp_snapshot")
		and current.has_method("to_save_data")
		and bool(current_debug.get("controller_authoritative", false))
		and str(current_debug.get("runtime_owner", "")) == "CommodityFlowRuntimeController",
		"CommodityFlowRuntimeController owns Sale Receipts and receipt-derived GDP"
	)
	_expect(
		public_receipts.is_empty()
		and int(region_gdp.get("region_gdp_per_minute_cents", -1)) == 0
		and _is_data_only(current_debug)
		and _is_data_only(region_gdp),
		"empty current-owner snapshots are pure data and do not synthesize legacy project GDP"
	)

	var coordinator_source := FileAccess.get_file_as_string(COORDINATOR_SCENE)
	_expect(
		coordinator_source.contains("CommodityFlowRuntimeController.tscn")
		and not coordinator_source.contains("GdpFormulaRuntimeController.tscn"),
		"GameRuntimeCoordinator composes only the current GDP owner"
	)

	retired.queue_free()
	current.queue_free()
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
		print("GDP_FORMULA_RUNTIME_RETIREMENT_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("GDP_FORMULA_RUNTIME_RETIREMENT_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_data_only(item):
				return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not _is_data_only(key) or not _is_data_only(value[key]):
				return false
		return true
	return false
