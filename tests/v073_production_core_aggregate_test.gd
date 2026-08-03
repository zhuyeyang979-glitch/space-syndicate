extends SceneTree

const TRACK_CORE := preload("res://scripts/v07_semantic/v07_unified_card_track_core.gd")
const DBG_CORE := preload("res://scripts/v07_semantic/v07_dbg_deck_core.gd")
const ASSET_CORE := preload("res://scripts/v07_semantic/v07_asset_batch_core.gd")
const FACILITY_CORE := preload("res://scripts/v07_semantic/v073_fixed_order_facility_contention_core.gd")
const SOLAR_CORE := preload("res://scripts/v07_semantic/v07_solar_victory_core.gd")
const RUNTIME_PATH := "res://scripts/v073_runtime/v073_sample_runtime_owner.gd"
const MANIFEST_PATH := "res://docs/migration/v07_atomic_cutover_manifest.json"
const FOCUSED_TESTS := [
	"res://tests/v07_semantic/v07_unified_card_track_core_test.gd",
	"res://tests/v07_semantic/v07_dbg_deck_core_test.gd",
	"res://tests/v07_semantic/v07_asset_batch_core_test.gd",
	"res://tests/v07_semantic/v073_fixed_order_facility_contention_core_test.gd",
	"res://tests/v07_semantic/v07_solar_victory_core_test.gd",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var track_contract := (TRACK_CORE.new() as RefCounted).call("interface_contract_v1") as Dictionary
	var dbg_contract := DBG_CORE.three_wing_contract()
	var asset_contract := ASSET_CORE.contract_snapshot()
	var facility_contract := FACILITY_CORE.contract_snapshot()
	var solar_contract := SOLAR_CORE.interface_contract_v2()
	_test_identity(track_contract, dbg_contract, asset_contract, facility_contract, solar_contract)
	_test_rules(track_contract, dbg_contract, asset_contract, facility_contract, solar_contract)
	_test_production_composition()
	for path in FOCUSED_TESTS:
		_expect(FileAccess.file_exists(path), "focused Core gate exists: %s" % path)
	_finish()


func _test_identity(
	track: Dictionary,
	dbg: Dictionary,
	asset: Dictionary,
	facility: Dictionary,
	solar: Dictionary
) -> void:
	for row in [
		["unified_track", track, "v0.7.2"],
		["personal_dbg", dbg, "v0.7.2"],
		["asset_batch", asset, "v0.7.2"],
		["facility_contention", facility, "v0.7.3"],
		["solar_victory", solar, "v0.7.2"],
	]:
		var contract := row[1] as Dictionary
		var expected_ruleset := str(row[2])
		_expect(not contract.is_empty(), "%s contract is nonempty" % row[0])
		_expect(
			str(contract.get("ruleset_id", "")) == expected_ruleset,
			"%s keeps inherited ruleset identity %s" % [row[0], expected_ruleset]
		)


func _test_rules(
	track: Dictionary,
	dbg: Dictionary,
	asset: Dictionary,
	facility: Dictionary,
	solar: Dictionary
) -> void:
	_expect(bool(track.get("single_unified_track", false)), "Core owns one unified track")
	_expect(not bool(track.get("gdp_affects_track_color_distribution", true)), "GDP cannot alter track colors")
	_expect(not bool(track.get("gdp_affects_track_card_type_distribution", true)), "GDP cannot alter track card type")
	_expect(int(track.get("default_normal_card_ratio_basis_points", 0)) == 6000, "normal track ratio is 6000 bps")
	_expect(int(track.get("default_commodity_card_ratio_basis_points", 0)) == 4000, "commodity track ratio is 4000 bps")
	_expect(not bool(track.get("starter_track_spawn_allowed", true)), "Starter cards never spawn on track")
	_expect(int(dbg.get("starter_card_instance_count", 0)) == 12, "DBG creates twelve Starter cards")
	_expect(int(dbg.get("starter_primary_asset_cost", -1)) == 0, "Starter cost is zero")
	_expect(int(dbg.get("standard_l1_primary_asset_cost", -1)) == 1, "standard L1 cost is one")
	_expect(bool(dbg.get("player_merge_choice_required", false)), "normal merge is player-chosen")
	_expect(not bool(dbg.get("automatic_merge_allowed", true)), "automatic merge is disabled")
	_expect(int(dbg.get("commodity_inventory_limit", 0)) == 5, "commodity inventory cap is five")
	_expect(int(asset.get("initial_assets_per_color", -1)) == 0, "all six assets start at zero")
	_expect(int(asset.get("per_color_cap", 0)) == 6, "each asset color caps at six")
	_expect(int(asset.get("window_duration_ms", 0)) == 30000, "submission window is thirty seconds")
	_expect(bool(asset.get("full_queue_atomic_reservation", false)), "lock reserves the full queue")
	_expect(str(asset.get("resolution_mode", "")) == "round_robin_by_local_action_index", "batch resolution is layered round robin")
	_expect(str(asset.get("player_iteration_order", "")) == "frozen_hidden_lead_order", "round robin uses frozen hidden order")
	_expect(int(facility.get("resolution_order_writer_count", 0)) == 1, "facility order has one writer")
	_expect(int(facility.get("resolution_order_modifier_count", -1)) == 0, "facility order has no modifier")
	_expect(not bool(facility.get("cash_can_change_resolution_order", true)), "cash cannot alter resolution order")
	_expect(bool(facility.get("contention_asset_reservation_released", false)), "contention Fizzle releases reservation")
	_expect(str(facility.get("contention_normal_card_destination", "")) == "discard", "Fizzle discards the card")
	_expect(not bool(facility.get("contention_action_slot_refunded", true)), "Fizzle does not refund action slot")
	_expect(is_equal_approx(SOLAR_CORE.solar_multiplier(true), 2.0), "sunlit multiplier is 2.0")
	_expect(is_equal_approx(SOLAR_CORE.solar_multiplier(false), 1.0), "dark multiplier is 1.0")
	_expect(int(solar.get("solar_multiplier_application_count_per_channel", 0)) == 1, "solar multiplier applies once")


func _test_production_composition() -> void:
	var runtime_source := FileAccess.get_file_as_string(RUNTIME_PATH)
	for path in [
		"v07_unified_card_track_core.gd",
		"v07_dbg_deck_core.gd",
		"v07_asset_batch_core.gd",
		"v073_fixed_order_facility_contention_core.gd",
		"v07_solar_victory_core.gd",
	]:
		_expect(runtime_source.contains(path), "production runtime connects %s" % path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_expect(parsed is Dictionary, "production cutover manifest parses")
	if parsed is Dictionary:
		var manifest := parsed as Dictionary
		_expect(str(manifest.get("current_production_runtime_ruleset", "")) == "v0.7.3", "production ruleset is V0.7.3")
		_expect(int(manifest.get("v073_production_connection_count", 0)) == 19, "nineteen production domains are connected")
		_expect(int(manifest.get("v073_dual_write_count", -1)) == 0, "production has no dual write")
		_expect(int(manifest.get("v073_legacy_fallback_count", -1)) == 0, "production has no legacy fallback")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var passed := _failures.is_empty()
	print("V073_PRODUCTION_CORE_AGGREGATE|status=%s|passed=%d|total=%d|details=%s" % [
		"PASS" if passed else "FAIL",
		_checks - _failures.size(),
		_checks,
		JSON.stringify(_failures),
	])
	quit(0 if passed else 1)
