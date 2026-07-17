extends Control
class_name EconomyCashflowRuntimeCutoverBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const PROJECT_BRIDGE := preload("res://tests/legacy_v05/economy/city_product_project_bridge_v05.gd")
const CITY_FIXTURES := preload("res://tests/helpers/city_world_fixture_factory.gd")
const OUTPUT_DIR := "user://space_syndicate_design_qa/economy_cashflow_runtime_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/economy_cashflow_runtime_cutover_sprint_4.png"

@export var auto_run := true

@onready var ruleset_bridge: Node = %RulesetRuntimeBridge
@onready var coordinator: Node = %GameRuntimeCoordinator
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var ownership_text: RichTextLabel = %OwnershipText

var _records: Array = []
var _failures: Array[String] = []
var _real_main: Control = null


func _ready() -> void:
	print("EconomyCashflowRuntimeCutoverBench ready: auto_run=%s editor_hint=%s" % [auto_run, Engine.is_editor_hint()])
	_configure_runtime()
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_cutover_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func cutover_cases() -> Array:
	return [
		"controller_scene_composition",
		"ruleset_realtime_income_enabled",
		"scene_owned_cadence_config",
		"sub_tick_accumulator",
		"exact_one_second_tick",
		"multi_tick_catchup",
		"session_pause_preserves_accumulator",
		"forced_global_block_preserves_accumulator",
		"game_over_blocks_cashflow",
		"exact_one_minute_owner_payout",
		"fractional_remainder_carries",
		"project_share_split_payout",
		"project_remainders_conserve_value",
		"eliminated_player_no_payout",
		"destroyed_city_source_excluded",
		"ledger_and_cash_history_parity",
		"real_main_owner_delegates",
		"real_main_project_share_delegates",
		"legacy_save_timer_restores",
		"privacy_pure_data_and_main_legacy_authority_inactive",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {
		"suite": "economy-cashflow-runtime-cutover-v04",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"records": records,
	}


func run_cutover_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	_configure_runtime()
	_real_main = await _prepare_real_main()
	for case_id_variant in cutover_cases():
		var case_id := str(case_id_variant)
		var record := _run_case(case_id)
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "failed"))])
	_release_real_main()
	await get_tree().process_frame
	await get_tree().process_frame
	var manifest := {
		"suite": "economy-cashflow-runtime-cutover-v04",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": _records.size(),
		"passed_count": _passed_count(),
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("EconomyCashflowRuntimeCutoverBench manifest: %s" % MANIFEST_PATH)
	print("EconomyCashflowRuntimeCutoverBench report: %s" % REPORT_PATH)
	print("EconomyCashflowRuntimeCutoverBench screenshot: %s" % SCREENSHOT_PATH)
	print("EconomyCashflowRuntimeCutoverBench passed: %d/%d" % [_passed_count(), _records.size()])
	if not _failures.is_empty():
		push_error("EconomyCashflowRuntimeCutoverBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)


func _run_case(case_id: String) -> Dictionary:
	var controller := _controller_node()
	var passed := false
	var notes := ""
	var flags := {}
	match case_id:
		"controller_scene_composition":
			passed = controller != null and controller.scene_file_path == "res://scenes/runtime/EconomyCashflowRuntimeController.tscn"
			notes = "GameRuntimeCoordinator composes the editable cashflow authority"
		"ruleset_realtime_income_enabled":
			_reset_controller()
			var debug: Dictionary = controller.call("debug_snapshot") if controller != null else {}
			passed = bool(debug.get("realtime_income_enabled", false)) and bool(debug.get("controller_authoritative", false))
			flags["controller_ready"] = bool(debug.get("controller_ready", false))
			notes = "realtime income capability comes from the active v0.4 Ruleset profile"
		"scene_owned_cadence_config":
			_reset_controller()
			var debug: Dictionary = controller.call("debug_snapshot") if controller != null else {}
			passed = is_equal_approx(float(debug.get("tick_interval_seconds", 0.0)), 1.0) and is_equal_approx(float(debug.get("basis_seconds", 0.0)), 60.0)
			flags["input_seconds"] = 1.0
			notes = "Inspector-owned cadence remains one-second ticks over a sixty-second GDP basis"
		"sub_tick_accumulator":
			_reset_controller()
			var ticks: Array = coordinator.call("advance_economy_cashflow", 0.4, {"overlay_visible": true})
			passed = ticks.is_empty() and is_equal_approx(float(coordinator.call("economy_cashflow_accumulator_seconds")), 0.4)
			flags["input_seconds"] = 0.4
			flags["emitted_tick_count"] = ticks.size()
			notes = "non-blocking UI leaves a sub-tick remainder in the controller"
		"exact_one_second_tick":
			_reset_controller()
			var ticks: Array = coordinator.call("advance_economy_cashflow", 1.0, {"overlay_visible": true})
			passed = ticks == [1.0] and is_zero_approx(float(coordinator.call("economy_cashflow_accumulator_seconds")))
			flags["input_seconds"] = 1.0
			flags["emitted_tick_count"] = ticks.size()
			notes = "exactly one active second emits one settlement tick"
		"multi_tick_catchup":
			_reset_controller()
			var ticks: Array = coordinator.call("advance_economy_cashflow", 3.4, {})
			passed = ticks.size() == 3 and is_equal_approx(float(coordinator.call("economy_cashflow_accumulator_seconds")), 0.4)
			flags["input_seconds"] = 3.4
			flags["emitted_tick_count"] = ticks.size()
			notes = "catch-up emits deterministic one-second plans and preserves the fractional clock remainder"
		"session_pause_preserves_accumulator":
			_reset_controller()
			coordinator.call("begin_session", {"session_id": "cashflow-bench", "scenario_id": "first_table", "seed": 4})
			coordinator.call("advance_economy_cashflow", 0.35, {})
			coordinator.call("pause_session")
			var session_ticks: Array = coordinator.call("advance_economy_cashflow", 4.0, {})
			coordinator.call("resume_session")
			var tree_pause_ticks: Array = coordinator.call("advance_economy_cashflow", 2.0, {"time_paused": true})
			passed = session_ticks.is_empty() and tree_pause_ticks.is_empty() and is_equal_approx(float(coordinator.call("economy_cashflow_accumulator_seconds")), 0.35)
			flags["input_seconds"] = 6.35
			flags["blocking_checked"] = true
			notes = "session pause and SceneTree/time pause both preserve the accumulated active time"
		"forced_global_block_preserves_accumulator":
			_reset_controller()
			coordinator.call("advance_economy_cashflow", 0.25, {})
			var ticks: Array = coordinator.call("advance_economy_cashflow", 5.0, {"global_blocked": true})
			passed = ticks.is_empty() and is_equal_approx(float(coordinator.call("economy_cashflow_accumulator_seconds")), 0.25)
			flags["input_seconds"] = 5.25
			flags["blocking_checked"] = true
			notes = "forced-decision global blocking does not consume cashflow time"
		"game_over_blocks_cashflow":
			_reset_controller()
			coordinator.call("advance_economy_cashflow", 0.2, {})
			var ticks: Array = coordinator.call("advance_economy_cashflow", 10.0, {"game_over": true})
			passed = ticks.is_empty() and is_equal_approx(float(coordinator.call("economy_cashflow_accumulator_seconds")), 0.2)
			flags["input_seconds"] = 10.2
			flags["blocking_checked"] = true
			notes = "game-over state freezes cadence without losing the pre-existing remainder"
		"exact_one_minute_owner_payout":
			_reset_controller()
			var result := _settle([_source("gdp:city:a:player:0", "project_share", 0, 0, 73, 0.0)], 60.0)
			passed = bool(result.get("valid", false)) and int(result.get("payout_total", 0)) == 73 and int(result.get("payout_event_count", 0)) == 1
			flags.merge(_settlement_flags(result, 60.0), true)
			notes = "one full GDP basis pays the exact owner GDP/min value"
		"fractional_remainder_carries":
			_reset_controller()
			var first := _settle([_source("gdp:city:f:player:0", "project_share", 0, 0, 40, 0.0)], 1.0)
			var first_event := _first_event(first)
			var second := _settle([_source("gdp:city:f:player:0", "project_share", 0, 0, 40, float(first_event.get("remainder_after", 0.0)))], 1.0)
			var second_event := _first_event(second)
			passed = int(first_event.get("paid_amount", -1)) == 0 and int(second_event.get("paid_amount", -1)) == 1 and is_equal_approx(float(second_event.get("remainder_after", -1.0)), 1.0 / 3.0)
			flags.merge(_settlement_flags(second, 2.0), true)
			flags["remainder_checked"] = true
			notes = "flooring is explicit and the fractional value carries into the next plan"
		"project_share_split_payout":
			_reset_controller()
			var result := _settle([_source("project:a:0", "project_share", 1, 0, 30, 0.0), _source("project:a:1", "project_share", 1, 1, 70, 0.0)], 60.0)
			var events: Array = result.get("payout_events", []) if result.get("payout_events", []) is Array else []
			passed = int(result.get("payout_total", 0)) == 100 and events.size() == 2 and int((events[0] as Dictionary).get("paid_amount", 0)) + int((events[1] as Dictionary).get("paid_amount", 0)) == 100
			flags.merge(_settlement_flags(result, 60.0), true)
			notes = "precomputed project GDP shares remain exact when converted into payout events"
		"project_remainders_conserve_value":
			_reset_controller()
			var result := _settle([_source("project:r:0", "project_share", 2, 0, 1, 0.8), _source("project:r:1", "project_share", 2, 1, 2, 0.4)], 12.0)
			var remainder_total := 0.0
			for event_variant in result.get("payout_events", []):
				remainder_total += float((event_variant as Dictionary).get("remainder_after", 0.0))
			var expected_value := 1.2 + 3.0 * 12.0 / 60.0
			passed = is_equal_approx(float(result.get("payout_total", 0)) + remainder_total, expected_value)
			flags.merge(_settlement_flags(result, 12.0), true)
			flags["remainder_checked"] = true
			notes = "paid integers plus both project remainders conserve the accrued value"
		"eliminated_player_no_payout":
			_reset_controller()
			var result := _settle([_source("gdp:city:eliminated:player:1", "project_share", 0, 1, 500, 0.0, false)], 60.0)
			passed = int(result.get("payout_total", -1)) == 0 and int(result.get("payout_event_count", -1)) == 0
			flags.merge(_settlement_flags(result, 60.0), true)
			notes = "main marks eliminated-player sources ineligible before payout planning"
		"destroyed_city_source_excluded":
			_reset_controller()
			var result := _settle([_source("gdp:city:destroyed:player:0", "project_share", 3, 0, 500, 0.0, false)], 60.0)
			passed = int(result.get("payout_total", -1)) == 0 and int(result.get("payout_event_count", -1)) == 0
			flags.merge(_settlement_flags(result, 60.0), true)
			notes = "destroyed cities are excluded by the main compatibility adapter"
		"ledger_and_cash_history_parity":
			var result := _exercise_real_main_owner_cashflow()
			passed = bool(result.get("paid", false)) and bool(result.get("ledger_checked", false)) and bool(result.get("history_checked", false))
			flags["payout_total"] = int(result.get("payout_total", 0))
			flags["payout_event_count"] = 1 if bool(result.get("paid", false)) else 0
			flags["main_delegation_checked"] = true
			notes = "existing main ledger and cash-history writers still apply controller payout events"
		"real_main_owner_delegates":
			var result := _exercise_real_main_owner_cashflow()
			passed = bool(result.get("paid", false)) and bool(result.get("controller_recorded", false)) and int(result.get("cash_delta", 0)) == int(result.get("payout_total", -1))
			flags["payout_total"] = int(result.get("payout_total", 0))
			flags["payout_event_count"] = 1 if bool(result.get("paid", false)) else 0
			flags["main_delegation_checked"] = true
			notes = "historical case id retained: real main derives the sole contributor's receipt attribution and delegates payout arithmetic to the scene-owned controller"
		"real_main_project_share_delegates":
			var result := _exercise_real_main_project_cashflow()
			passed = bool(result.get("paid", false)) and bool(result.get("both_players_paid", false)) and bool(result.get("controller_recorded", false)) and int(result.get("cash_delta_total", 0)) == int(result.get("payout_total", -1))
			flags["payout_total"] = int(result.get("payout_total", 0))
			flags["payout_event_count"] = int(result.get("payout_event_count", 0))
			flags["main_delegation_checked"] = true
			flags["remainder_checked"] = true
			notes = "real project GDP rows are attributed to both contributors and routed as receipt+player sources before controller payout planning"
		"legacy_save_timer_restores":
			_reset_controller()
			controller.call("apply_legacy_save_snapshot", {"economy_cashflow_timer": 0.625})
			var legacy: Dictionary = controller.call("to_legacy_save_snapshot")
			var real_coordinator := _real_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _real_main != null else null
			var captured: Dictionary = {}
			var apply_error := ERR_UNCONFIGURED
			var restored_accumulator := -1.0
			if real_coordinator != null:
				real_coordinator.call("apply_economy_cashflow_legacy_save_snapshot", {"economy_cashflow_timer": 0.625})
				captured = _real_main.call("_capture_run_state")
				real_coordinator.call("apply_economy_cashflow_legacy_save_snapshot", {"economy_cashflow_timer": 0.0})
				apply_error = int(_real_main.call("_apply_run_state", captured))
				restored_accumulator = float(real_coordinator.call("economy_cashflow_accumulator_seconds"))
			passed = is_equal_approx(float(controller.call("accumulator_seconds")), 0.625) and is_equal_approx(float(legacy.get("economy_cashflow_timer", 0.0)), 0.625) and is_equal_approx(float(captured.get("economy_cashflow_timer", 0.0)), 0.625) and apply_error == OK and is_equal_approx(restored_accumulator, 0.625)
			flags["save_compatibility_checked"] = true
			flags["main_delegation_checked"] = true
			notes = "real main captures and reapplies the unchanged v1 top-level timer key through controller authority"
		"privacy_pure_data_and_main_legacy_authority_inactive":
			_reset_controller()
			_settle([_source("gdp:city:private:player:2", "project_share", 4, 2, 60, 0.0).merged({"hidden_owner": "secret-owner", "private_target": 991}, true)], 1.0)
			var debug: Dictionary = controller.call("debug_snapshot")
			var private_ui: Dictionary = controller.call("private_ui_snapshot", 2)
			var encoded := JSON.stringify({"debug": debug, "private_ui": private_ui})
			var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
			var network_source := FileAccess.get_file_as_string("res://scripts/runtime/city_trade_network_runtime_controller.gd")
			var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
			passed = _is_data_only(debug) and _is_data_only(private_ui) and not encoded.contains("secret-owner") and not encoded.contains("private_target") and not main_source.contains("var economy_cashflow_timer") and not main_source.contains("ECONOMY_CASHFLOW_TICK_SECONDS") and not main_source.contains("ECONOMY_CASHFLOW_BASIS_SECONDS") and not main_source.contains("func _settle_city_project_cashflow_seconds") and main_source.contains("advance_economy_cashflow") and main_source.contains('"settle_cashflow_seconds"') and network_source.contains('call("settle_sources"') and coordinator_source.contains("func settle_economy_sources(")
			flags["privacy_checked"] = true
			flags["pure_data_checked"] = true
			flags["main_delegation_checked"] = true
			notes = "snapshots retain no source identity; main owns no timer or payout loop, and CityTradeNetworkRuntimeController delegates payout arithmetic to EconomyCashflowRuntimeController"
	return _record(case_id, passed, notes, flags)


func _configure_runtime() -> void:
	if coordinator != null and ruleset_bridge != null:
		coordinator.call("configure", ruleset_bridge.call("debug_snapshot"))


func _reset_controller() -> void:
	if coordinator != null:
		coordinator.call("reset_state")


func _controller_node() -> Node:
	return coordinator.get_node_or_null("EconomyCashflowRuntimeController") if coordinator != null else null


func _source(source_id: String, source_kind: String, district_index: int, player_index: int, gdp_per_minute: int, remainder: float, eligible: bool = true) -> Dictionary:
	return {
		"source_id": source_id,
		"source_kind": source_kind,
		"district_index": district_index,
		"player_index": player_index,
		"gdp_per_minute": gdp_per_minute,
		"remainder": remainder,
		"role_bonus_gdp_per_minute": 0,
		"role_bonus_basis_gdp_per_minute": maxi(1, gdp_per_minute),
		"eligible": eligible,
	}


func _settle(sources: Array, seconds: float) -> Dictionary:
	return coordinator.call("settle_economy_sources", seconds, {"sources": sources}) if coordinator != null else {}


func _first_event(result: Dictionary) -> Dictionary:
	var events: Array = result.get("payout_events", []) if result.get("payout_events", []) is Array else []
	return events[0] as Dictionary if not events.is_empty() and events[0] is Dictionary else {}


func _settlement_flags(result: Dictionary, input_seconds: float) -> Dictionary:
	return {
		"input_seconds": input_seconds,
		"payout_total": int(result.get("payout_total", 0)),
		"payout_event_count": int(result.get("payout_event_count", 0)),
	}


func _prepare_real_main() -> Control:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return null
	var main := packed.instantiate() as Control
	if main == null:
		return null
	main.visible = false
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.call("_new_game")
	await get_tree().process_frame
	main.set_process(false)
	return main


func _reset_real_main() -> bool:
	if _real_main == null or not is_instance_valid(_real_main):
		return false
	_real_main.call("_new_game")
	_real_main.set_process(false)
	return true


func _first_land_district() -> int:
	if _real_main == null:
		return -1
	var districts: Array = ((_real_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array
	for index in range(districts.size()):
		var district: Dictionary = districts[index] if districts[index] is Dictionary else {}
		if not bool(district.get("destroyed", false)) and str(district.get("terrain", "land")) == "land":
			return index
	return -1


func _prepare_owner_city() -> Dictionary:
	if not _reset_real_main():
		return {}
	var district_index := _first_land_district()
	if district_index < 0:
		return {}
	var city_variant: Variant = CITY_FIXTURES.create_city_surface(_real_main, 0, district_index, "Cashflow fixture")
	return {"district_index": district_index, "city": city_variant if city_variant is Dictionary else {}}


func _exercise_real_main_owner_cashflow() -> Dictionary:
	var prepared := _prepare_owner_city()
	if prepared.is_empty():
		return {}
	var players: Array = ((_real_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array
	var before: Dictionary = (players[0] as Dictionary).duplicate(true)
	var before_cash := int(before.get("cash", 0))
	var before_ledger_size := (before.get("economic_ledger", []) as Array).size()
	var before_history_size := (before.get("cash_history", []) as Array).size()
	var payout_total := int(_real_main.call("_settle_city_cashflow_seconds", 60.0))
	players = ((_real_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array
	var after: Dictionary = players[0] if players[0] is Dictionary else {}
	var coordinator_node := _real_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var debug: Dictionary = coordinator_node.call("debug_snapshot") if coordinator_node != null else {}
	var economy: Dictionary = debug.get("economy_cashflow", {}) if debug.get("economy_cashflow", {}) is Dictionary else {}
	return {
		"paid": payout_total > 0,
		"payout_total": payout_total,
		"cash_delta": int(after.get("cash", 0)) - before_cash,
		"ledger_checked": (after.get("economic_ledger", []) as Array).size() > before_ledger_size,
		"history_checked": (after.get("cash_history", []) as Array).size() > before_history_size,
		"controller_recorded": int(economy.get("last_payout_total", -1)) == payout_total and int(economy.get("last_payout_event_count", 0)) >= 1,
	}


func _exercise_real_main_project_cashflow() -> Dictionary:
	var prepared := _prepare_owner_city()
	if prepared.is_empty():
		return {}
	var district_index := int(prepared.get("district_index", -1))
	var city: Dictionary = prepared.get("city", {}) if prepared.get("city", {}) is Dictionary else {}
	var active_projects: Array = PROJECT_BRIDGE.active_projects(city)
	if active_projects.is_empty() or not (active_projects[0] is Dictionary):
		return {}
	var project: Dictionary = active_projects[0]
	var second_contribution := PROJECT_BRIDGE.apply_project_contribution(city, district_index, 1, {
		"product_id": str(project.get("product_id", "")),
		"project_direction": str(project.get("direction", "production")),
		"slot_index": int(project.get("slot_index", 0)),
		"contribution_units": int((project.get("contribution_by_player", {}) as Dictionary).get("0", 1)),
	}, 101)
	city = (second_contribution.get("city", {}) as Dictionary).duplicate(true)
	var districts: Array = ((_real_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array
	(districts[district_index] as Dictionary)["city"] = city
	((_real_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	_real_main.call("_refresh_city_networks")
	var players: Array = ((_real_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array
	var before_zero := int((players[0] as Dictionary).get("cash", 0))
	var before_one := int((players[1] as Dictionary).get("cash", 0))
	var payout_total := int(_real_main.call("_settle_city_cashflow_seconds", 60.0))
	players = ((_real_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array
	var zero_delta := int((players[0] as Dictionary).get("cash", 0)) - before_zero
	var one_delta := int((players[1] as Dictionary).get("cash", 0)) - before_one
	var coordinator_node := _real_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var debug: Dictionary = coordinator_node.call("debug_snapshot") if coordinator_node != null else {}
	var economy: Dictionary = debug.get("economy_cashflow", {}) if debug.get("economy_cashflow", {}) is Dictionary else {}
	return {
		"paid": payout_total > 0,
		"payout_total": payout_total,
		"payout_event_count": int(economy.get("last_payout_event_count", 0)),
		"cash_delta_total": zero_delta + one_delta,
		"both_players_paid": zero_delta > 0 and one_delta > 0,
		"controller_recorded": int(economy.get("last_payout_total", -1)) == payout_total and int(economy.get("last_payout_event_count", 0)) == 2,
	}


func _release_real_main() -> void:
	if _real_main != null and is_instance_valid(_real_main):
		_real_main.queue_free()
	_real_main = null


func _record(case_id: String, passed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var controller := _controller_node()
	var debug: Dictionary = controller.call("debug_snapshot") if controller != null else {}
	return {
		"case_id": case_id,
		"input_seconds": float(flags.get("input_seconds", 0.0)),
		"emitted_tick_count": int(flags.get("emitted_tick_count", 0)),
		"payout_total": int(flags.get("payout_total", 0)),
		"payout_event_count": int(flags.get("payout_event_count", 0)),
		"remainder_checked": bool(flags.get("remainder_checked", false)),
		"blocking_checked": bool(flags.get("blocking_checked", false)),
		"main_delegation_checked": bool(flags.get("main_delegation_checked", false)),
		"save_compatibility_checked": bool(flags.get("save_compatibility_checked", false)),
		"privacy_checked": bool(flags.get("privacy_checked", false)),
		"pure_data_checked": bool(flags.get("pure_data_checked", false)),
		"controller_ready": bool(flags.get("controller_ready", debug.get("controller_ready", false))),
		"passed": passed,
		"notes": notes,
	}


func _passed_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count


func _update_ui(manifest: Dictionary) -> void:
	var passed := int(manifest.get("passed_count", 0))
	var total := int(manifest.get("record_count", 0))
	summary_label.text = "Economy cashflow ownership: %d/%d | 1s cadence / 60s basis" % [passed, total]
	status_label.text = "PASS" if passed == total else "FAIL"
	status_label.add_theme_color_override("font_color", Color("#4ade80") if passed == total else Color("#fb7185"))
	ownership_text.text = "[b]EconomyCashflowRuntimeController[/b]\n- one-second cadence and active-time accumulator\n- floor and fractional-remainder arithmetic\n- pure payout-event planning\n- legacy v1 timer adapter\n\n[b]main.gd compatibility boundary[/b]\n- computes existing GDP and project allocations\n- applies cash, ledger and cash-history mutations\n- owns no duplicate cadence, floor loop or remainder split"


func _markdown_report(manifest: Dictionary) -> String:
	var lines := [
		"# Economy Cashflow Runtime Cutover QA",
		"",
		"- Ruleset: `v0.4`",
		"- Cadence: `1 second`",
		"- GDP basis: `60 seconds`",
		"- Passed: **%d/%d**" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"- Output: `%s`" % OUTPUT_DIR,
		"",
		"| Case | Ticks | Payout | Events | Passed | Notes |",
		"| --- | ---: | ---: | ---: | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| %s | %d | %d | %d | %s | %s |" % [str(record.get("case_id", "")), int(record.get("emitted_tick_count", 0)), int(record.get("payout_total", 0)), int(record.get("payout_event_count", 0)), "yes" if bool(record.get("passed", false)) else "no", str(record.get("notes", "")).replace("|", "/")])
	return "\n".join(lines) + "\n"


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for file_name: String in ["manifest.json", "report.md"]:
		var path := OUTPUT_DIR + file_name
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(ProjectSettings.globalize_path(SCREENSHOT_PATH))


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
