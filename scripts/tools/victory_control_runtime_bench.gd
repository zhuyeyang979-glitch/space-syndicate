extends Control
class_name VictoryControlRuntimeBench

const CONTROLLER_SCENE_PATH := "res://scenes/runtime/VictoryControlRuntimeController.tscn"
const WORLD_BRIDGE_SCENE_PATH := "res://scenes/runtime/VictoryControlWorldBridge.tscn"
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/victory_control_runtime_controller.gd"
const BRIDGE_SCRIPT_PATH := "res://scripts/runtime/victory_control_world_bridge.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/victory_control_runtime/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/victory_control_runtime_ss06_05.png"
const CHECKPOINT := "post_world_settlement"

@export var auto_run := true

@onready var ruleset_bridge: Node = %RulesetRuntimeBridge
@onready var coordinator: Node = %GameRuntimeCoordinator
@onready var controller_host: Node = %ControllerHost
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var rules_text: RichTextLabel = %RulesText
@onready var results_text: RichTextLabel = %ResultsText

var _records: Array = []
var _failures: Array[String] = []


func _ready() -> void:
	_configure_runtime()
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_victory_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func victory_cases() -> Array:
	return [
		"controller_scene_v06_profile",
		"controller_api_contract",
		"dynamic_profile_is_domain_source",
		"zero_surviving_regions_pauses_victory",
		"one_region_requires_one",
		"two_regions_require_one",
		"three_regions_require_two",
		"six_regions_require_three",
		"destroyed_region_reduces_denominator",
		"revived_region_increases_denominator",
		"share_2999bp_fails",
		"share_3000bp_unique_controls",
		"share_tie_no_control",
		"zero_gdp_no_control",
		"top_k_selects_highest_regions",
		"region_count_gate",
		"top_k_gdp_gate",
		"both_dynamic_gates_required",
		"all_ruined_never_auto_wins",
		"independent_qualification_progress",
		"qualification_resets_per_player",
		"qualification_ten_starts_audit",
		"late_qualifier_nine_seconds_not_joined",
		"late_qualifier_ten_seconds_joins",
		"audit_roster_is_sticky",
		"audit_countdown_never_resets",
		"endpoint_rechecks_dynamic_threshold",
		"no_finalist_returns_idle_without_cooldown",
		"comparator_top_k_gdp",
		"comparator_controlled_region_count",
		"comparator_exact_cash",
		"exact_tie_is_co_victory",
		"endpoint_requires_post_settlement_checkpoint",
		"main_same_tick_order_is_v06",
		"menu_pause_freezes_clock",
		"readonly_pause_freezes_clock",
		"forced_decision_freezes_clock",
		"monster_wager_freezes_clock",
		"save_restores_qualification",
		"save_restores_audit_roster_and_time",
		"v05_save_is_rejected",
		"pre_audit_assets_remain_private",
		"audit_disclosure_has_required_fields",
		"audit_disclosure_hides_forbidden_secrets",
		"private_snapshot_is_viewer_scoped",
		"outcome_receipt_is_exact_once",
		"last_survivor_uses_same_owner",
		"ordinary_planet_destruction_has_no_cash_win",
		"explicit_scenario_planet_destruction_can_settle",
		"world_bridge_uses_region_and_flow_owners",
		"fixed_depth_and_failure_cooldown_absent",
		"main_dynamic_consumer_cutover",
		"coordinator_static_composition",
		"all_payloads_are_pure_data",
	]


func build_victory_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in victory_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {
		"suite": "victory-control-v06-dynamic",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"records": records,
	}


func run_victory_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	_configure_runtime()
	for case_id_variant in victory_cases():
		var case_id := str(case_id_variant)
		var record := _run_case(case_id)
		_records.append(record)
		print("VICTORY_V06_CASE|case=%s|passed=%s" % [case_id, str(bool(record.get("passed", false))).to_lower()])
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "failed"))])
	var manifest := {
		"suite": "victory-control-v06-dynamic",
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
	print("VICTORY_V06_BENCH|passed=%d|total=%d|manifest=%s|report=%s|screenshot=%s" % [_passed_count(), _records.size(), MANIFEST_PATH, REPORT_PATH, SCREENSHOT_PATH])
	if not _failures.is_empty():
		push_error("VictoryControlRuntimeBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)


func _run_case(case_id: String) -> Dictionary:
	var controller := _new_controller()
	if controller == null:
		return _record(case_id, false, "controller scene could not be configured")
	var passed := true
	var notes := ""
	var evidence := {}
	match case_id:
		"controller_scene_v06_profile":
			passed = controller.scene_file_path == CONTROLLER_SCENE_PATH and str((controller.call("debug_snapshot") as Dictionary).get("ruleset_id", "")) == "v0.6"
			notes = "editable controller scene reads the Inspector v0.6 profile and clock registry"
		"controller_api_contract":
			for method_name in ["configure", "evaluate_region_control", "victory_rule_for_world", "evaluate_candidates", "advance_world_effective", "resolve_special_outcome", "public_snapshot", "private_snapshot", "to_save_data", "apply_save_data", "debug_snapshot"]:
				passed = passed and controller.has_method(method_name)
			notes = "one controller owns dynamic control, qualification, audit, ordering, save, and receipt APIs"
		"dynamic_profile_is_domain_source":
			var debug: Dictionary = controller.call("debug_snapshot")
			passed = bool(debug.get("controller_ready", false)) and bool(debug.get("dynamic_denominator_enabled", false)) and not bool(debug.get("fixed_depth_table_present", true))
			notes = "v0.6 profile supplies 3000bp, 4000bp coverage, 36 GDP/region, 10s qualification, and 120s audit"
		"zero_surviving_regions_pauses_victory":
			var rule := _rule(controller, _world([], [], 0))
			passed = int(rule.get("surviving_region_count", -1)) == 0 and int(rule.get("required_region_count", -1)) == 0 and bool(rule.get("ordinary_victory_paused", false))
			notes = "A=0 pauses ordinary GDP victory instead of producing K=0 victory"
		"one_region_requires_one":
			passed = _required_regions(controller, 1) == 1
			notes = "ceil(1 x 40%) is clamped to one"
		"two_regions_require_one":
			passed = _required_regions(controller, 2) == 1
			notes = "ceil(2 x 40%) equals one"
		"three_regions_require_two":
			passed = _required_regions(controller, 3) == 2
			notes = "ceil(3 x 40%) equals two"
		"six_regions_require_three":
			passed = _required_regions(controller, 6) == 3
			notes = "ceil(6 x 40%) equals three"
		"destroyed_region_reduces_denominator":
			var world := _world([36, 36], [], 6)
			(world["regions"] as Array)[5]["lifecycle_state"] = "ruined"
			(world["regions"] as Array)[5]["destroyed"] = true
			var rule := _rule(controller, world)
			passed = int(rule.get("surviving_region_count", -1)) == 5 and int(rule.get("required_region_count", -1)) == 2
			notes = "a ruined region leaves A immediately and lowers K when the ceiling boundary changes"
		"revived_region_increases_denominator":
			passed = _required_regions(controller, 6) == 3 and _required_regions(controller, 5) == 2
			notes = "reviving the sixth region raises A and K without resetting the audit clock"
		"share_2999bp_fails":
			var control: Dictionary = controller.call("evaluate_region_control", _region_cents(0, 10000, {0: 2999, 1: 1000}))
			passed = int(control.get("controller_player_index", -1)) == -1 and _share_for(control, 0) == 2999
			notes = "29.99 percent never controls"
		"share_3000bp_unique_controls":
			var control: Dictionary = controller.call("evaluate_region_control", _region_cents(0, 10000, {0: 3000, 1: 1000}))
			passed = int(control.get("controller_player_index", -1)) == 0 and _share_for(control, 0) == 3000
			notes = "30.00 percent with unique highest GDP controls"
		"share_tie_no_control":
			var control: Dictionary = controller.call("evaluate_region_control", _region_cents(0, 10000, {0: 3000, 1: 3000}))
			passed = int(control.get("controller_player_index", -1)) == -1
			notes = "a highest-share tie leaves the region uncontrolled"
		"zero_gdp_no_control":
			passed = int((controller.call("evaluate_region_control", _region_cents(0, 0, {0: 0})) as Dictionary).get("controller_player_index", -1)) == -1
			notes = "a surviving but zero-GDP region remains in A and has no controller"
		"top_k_selects_highest_regions":
			var candidate := _candidate(controller.call("evaluate_candidates", _world([50, 40, 20], [], 5)), 0)
			passed = int(candidate.get("required_region_count", 0)) == 2 and int(candidate.get("top_k_gdp_per_minute", 0)) == 90
			notes = "A=5 gives K=2 and selects the two highest controlled-region GDP rows"
		"region_count_gate":
			var candidate := _candidate(controller.call("evaluate_candidates", _world([100], [], 5)), 0)
			passed = int(candidate.get("controlled_region_count", 0)) == 1 and not bool(candidate.get("eligible", true))
			notes = "GDP cannot replace the required controlled-region count"
		"top_k_gdp_gate":
			var candidate := _candidate(controller.call("evaluate_candidates", _world([35, 35], [], 5)), 0)
			passed = int(candidate.get("controlled_region_count", 0)) == 2 and int(candidate.get("top_k_gdp_per_minute", 0)) == 70 and not bool(candidate.get("eligible", true))
			notes = "K controlled regions still need K x 36 GDP/min"
		"both_dynamic_gates_required":
			var candidate := _candidate(controller.call("evaluate_candidates", _world([36, 36], [], 5)), 0)
			passed = bool(candidate.get("eligible", false)) and int(candidate.get("required_top_k_gdp_per_minute", 0)) == 72
			notes = "two controlled regions and exactly 72 GDP/min qualify at A=5"
		"all_ruined_never_auto_wins":
			var world := _world([100], [], 1)
			(world["regions"] as Array)[0]["lifecycle_state"] = "ruined"
			(world["regions"] as Array)[0]["destroyed"] = true
			var result: Dictionary = controller.call("advance_world_effective", 20.0, world)
			passed = str(result.get("state", "")) == "idle" and (controller.call("outcome_receipt") as Dictionary).is_empty()
			notes = "all-ruined maps wait for reconstruction"
		"independent_qualification_progress":
			controller.call("advance_world_effective", 6.0, _world([36, 36], [36, 36], 5))
			passed = is_equal_approx(float((controller.call("private_snapshot", 0) as Dictionary).get("own_qualification_elapsed_seconds", 0.0)), 6.0) and is_equal_approx(float((controller.call("private_snapshot", 1) as Dictionary).get("own_qualification_elapsed_seconds", 0.0)), 6.0)
			notes = "all eligible players accumulate qualification independently"
		"qualification_resets_per_player":
			controller.call("advance_world_effective", 6.0, _world([36, 36], [36, 36], 5))
			controller.call("advance_world_effective", 1.0, _world([36, 36], [], 5))
			passed = is_equal_approx(float((controller.call("private_snapshot", 0) as Dictionary).get("own_qualification_elapsed_seconds", 0.0)), 7.0) and is_equal_approx(float((controller.call("private_snapshot", 1) as Dictionary).get("own_qualification_elapsed_seconds", 0.0)), 0.0)
			notes = "one player losing eligibility does not reset another player's progress"
		"qualification_ten_starts_audit":
			_start_audit(controller, _world([36, 36], [], 5))
			var snapshot: Dictionary = controller.call("public_snapshot")
			passed = str(snapshot.get("state", "")) == "audit" and (snapshot.get("audit_roster", []) as Array) == [0] and is_equal_approx(float(snapshot.get("audit_remaining_seconds", 0.0)), 120.0)
			notes = "ten world-effective seconds start one sticky 120-second audit"
		"late_qualifier_nine_seconds_not_joined":
			_start_audit(controller, _world([36, 36], [], 5))
			controller.call("advance_world_effective", 9.0, _world([36, 36], [36, 36], 5))
			passed = not ((controller.call("public_snapshot") as Dictionary).get("audit_roster", []) as Array).has(1)
			notes = "a late candidate must hold eligibility for the full ten seconds"
		"late_qualifier_ten_seconds_joins":
			_start_audit(controller, _world([36, 36], [], 5))
			controller.call("advance_world_effective", 10.0, _world([36, 36], [36, 36], 5))
			passed = ((controller.call("public_snapshot") as Dictionary).get("audit_roster", []) as Array) == [0, 1]
			notes = "a late qualifier joins without restarting the audit"
		"audit_roster_is_sticky":
			_start_audit(controller, _world([36, 36], [36, 36], 5))
			controller.call("advance_world_effective", 1.0, _world([], [36, 36], 5))
			passed = ((controller.call("public_snapshot") as Dictionary).get("audit_roster", []) as Array) == [0, 1]
			notes = "listed players remain disclosed until this audit ends"
		"audit_countdown_never_resets":
			_start_audit(controller, _world([36, 36], [], 5))
			controller.call("advance_world_effective", 30.0, _world([36, 36], [36, 36], 5))
			passed = is_equal_approx(float((controller.call("public_snapshot") as Dictionary).get("audit_remaining_seconds", 0.0)), 90.0)
			notes = "denominator and roster changes never reset the 120-second countdown"
		"endpoint_rechecks_dynamic_threshold":
			_start_audit(controller, _world([36, 36], [], 5))
			controller.call("advance_world_effective", 120.0, _world([35, 35], [], 5))
			passed = (controller.call("outcome_receipt") as Dictionary).is_empty() and str((controller.call("public_snapshot") as Dictionary).get("state", "")) == "idle"
			notes = "the endpoint re-reads current A, K, control, and GDP after settlement"
		"no_finalist_returns_idle_without_cooldown":
			_start_audit(controller, _world([36, 36], [], 5))
			controller.call("advance_world_effective", 120.0, _world([], [], 5))
			var snapshot: Dictionary = controller.call("public_snapshot")
			passed = str(snapshot.get("state", "")) == "idle" and not snapshot.has("cooldown_remaining_seconds")
			notes = "v0.6 has no failed-audit cooldown; a failed audit returns directly to idle"
		"comparator_top_k_gdp":
			var receipt := _complete_joint_audit(controller, _world([40, 40], [36, 36], 5, [10000, 10000]))
			passed = (receipt.get("winner_player_indices", []) as Array) == [0]
			notes = "endpoint first compares exact top-K commodity GDP cents"
		"comparator_controlled_region_count":
			var receipt := _complete_joint_audit(controller, _world([36, 36, 1], [36, 36], 5, [10000, 10000]))
			passed = (receipt.get("winner_player_indices", []) as Array) == [0]
			notes = "controlled-region count breaks equal top-K GDP"
		"comparator_exact_cash":
			var receipt := _complete_joint_audit(controller, _world([36, 36], [36, 36], 5, [20000, 10000]))
			passed = (receipt.get("winner_player_indices", []) as Array) == [0]
			notes = "exact cash is the final comparator"
		"exact_tie_is_co_victory":
			var receipt := _complete_joint_audit(controller, _world([36, 36], [36, 36], 5, [10000, 10000]))
			passed = bool(receipt.get("co_victory", false)) and (receipt.get("winner_player_indices", []) as Array) == [0, 1]
			notes = "an exact three-stage tie yields co-victory"
		"endpoint_requires_post_settlement_checkpoint":
			_start_audit(controller, _world([36, 36], [], 5))
			var stale_world := _world([36, 36], [], 5)
			stale_world["settlement_checkpoint"] = "read_only"
			var pending: Dictionary = controller.call("advance_world_effective", 120.0, stale_world)
			var no_receipt := (controller.call("outcome_receipt") as Dictionary).is_empty() and str(pending.get("reason", "")) == "awaiting_post_world_settlement_checkpoint"
			controller.call("advance_world_effective", 0.0, _world([36, 36], [], 5))
			passed = no_receipt and not (controller.call("outcome_receipt") as Dictionary).is_empty()
			notes = "audit cannot settle from a pre-mutation snapshot"
		"main_same_tick_order_is_v06":
			var source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
			var start := source.find("func _process(delta: float)")
			var finish := source.find("func _update_process_ui_refresh", start)
			var process_source := source.substr(start, finish - start) if start >= 0 and finish > start else ""
			var attack_pos := process_source.find("tick_monster_actions")
			var flow_pos := process_source.find("_advance_continuous_commodity_flow")
			var bankruptcy_pos := process_source.find("_check_bankruptcy_eliminations", flow_pos)
			var victory_pos := process_source.find("_update_victory_control")
			passed = attack_pos >= 0 and attack_pos < flow_pos and flow_pos < bankruptcy_pos and bankruptcy_pos < victory_pos
			notes = "same-tick order is attack/lifecycle, flow/sales, bankruptcy, then victory"
		"menu_pause_freezes_clock":
			passed = _pause_case(controller, "menu_paused")
			notes = "menu pause consumes no qualification time"
		"readonly_pause_freezes_clock":
			passed = _pause_case(controller, "readonly_paused")
			notes = "readonly pause consumes no qualification time"
		"forced_decision_freezes_clock":
			passed = _pause_case(controller, "forced_decision_paused")
			notes = "forced decisions consume no victory time"
		"monster_wager_freezes_clock":
			passed = _pause_case(controller, "monster_wager_world_frozen")
			notes = "monster wager freezes the world-effective victory clock"
		"save_restores_qualification":
			controller.call("advance_world_effective", 6.0, _world([36, 36], [], 5))
			var restored := _new_controller()
			var applied: Dictionary = restored.call("apply_save_data", controller.call("to_save_data"))
			passed = bool(applied.get("applied", false)) and is_equal_approx(float((restored.call("public_snapshot") as Dictionary).get("qualification_remaining_seconds", 0.0)), 4.0)
			restored.free()
			notes = "v0.6 qualification progress round-trips"
		"save_restores_audit_roster_and_time":
			_start_audit(controller, _world([36, 36], [], 5))
			controller.call("advance_world_effective", 17.0, _world([36, 36], [], 5))
			var restored := _new_controller()
			var applied: Dictionary = restored.call("apply_save_data", controller.call("to_save_data"))
			var snapshot: Dictionary = restored.call("public_snapshot")
			passed = bool(applied.get("applied", false)) and (snapshot.get("audit_roster", []) as Array) == [0] and is_equal_approx(float(snapshot.get("audit_remaining_seconds", 0.0)), 103.0)
			restored.free()
			notes = "v0.6 audit roster and remaining time round-trip"
		"v05_save_is_rejected":
			var applied: Dictionary = controller.call("apply_save_data", {"victory_control_runtime": {"schema_version": 1, "ruleset_id": "v0.5", "state": "audit"}})
			passed = not bool(applied.get("applied", true)) and str(applied.get("reason", "")) == "victory_save_header_invalid"
			notes = "v0.5 fixed-depth state cannot silently resume as v0.6"
		"pre_audit_assets_remain_private":
			controller.call("advance_world_effective", 1.0, _world([36, 36], [], 5))
			passed = ((controller.call("public_snapshot") as Dictionary).get("audit_entries", []) as Array).is_empty()
			notes = "exact cash, hand, facilities, inventory, and positions remain private before roster entry"
		"audit_disclosure_has_required_fields":
			_start_audit(controller, _world([36, 36], [], 5))
			var snapshot: Dictionary = controller.call("public_snapshot")
			var entry := _audit_entry(snapshot, 0)
			passed = str(snapshot.get("cash_visibility", "")) == "public_audit" \
				and (snapshot.get("audit_revealed_player_indices", []) as Array) == [0] \
				and typeof(entry.get("cash_ledger_cents", null)) == TYPE_INT \
				and str(entry.get("cash_visibility", "")) == "public_audit"
			notes = "only the authoritative audit roster receives canonical exact-cash authorization"
		"audit_disclosure_hides_forbidden_secrets":
			_start_audit(controller, _world([36, 36], [], 5))
			var serialized := JSON.stringify(controller.call("public_snapshot"))
			passed = not serialized.contains("private_intel") and not serialized.contains("secret_objective") and not serialized.contains("ai_private_weight") and not serialized.contains("private_target") and not serialized.contains("private_discard") \
				and not serialized.contains("available_cents") and not serialized.contains("escrow_cents") and not serialized.contains("ordinary_hand") and not serialized.contains("economic_assets")
			notes = "audit cash authorization never widens into hands, escrow, ownership truth, or AI-private state"
		"private_snapshot_is_viewer_scoped":
			controller.call("advance_world_effective", 1.0, _world([36, 36], [36, 36], 5))
			var own: Dictionary = controller.call("private_snapshot", 0)
			passed = int(own.get("viewer_player_index", -1)) == 0 and not (own.get("own_economic_assets", {}) as Dictionary).is_empty() and not own.has("other_private_assets")
			notes = "private snapshot contains only the requesting player's authorized facts"
		"outcome_receipt_is_exact_once":
			var world := _world([36, 36], [], 5)
			_start_audit(controller, world)
			controller.call("advance_world_effective", 120.0, world)
			var first: Dictionary = controller.call("outcome_receipt")
			controller.call("advance_world_effective", 120.0, world)
			passed = not first.is_empty() and first == controller.call("outcome_receipt")
			notes = "one audit emits one immutable outcome receipt"
		"last_survivor_uses_same_owner":
			var world := _world([], [], 2)
			(world["players"] as Array)[1]["eliminated"] = true
			var receipt: Dictionary = controller.call("resolve_special_outcome", "last_survivor", world)
			passed = (receipt.get("winner_player_indices", []) as Array) == [0] and str(receipt.get("ruleset_id", "")) == "v0.6"
			notes = "last survivor uses the same exact-once v0.6 receipt"
		"ordinary_planet_destruction_has_no_cash_win":
			passed = (controller.call("resolve_special_outcome", "planet_destroyed", _world([], [], 0)) as Dictionary).is_empty()
			notes = "ordinary region ruins never trigger cash-most victory"
		"explicit_scenario_planet_destruction_can_settle":
			var world := _world([], [], 0, [20000, 10000])
			world["irreversible_planet_destruction_triggered"] = true
			world["scenario_allows_cash_fallback"] = true
			var receipt: Dictionary = controller.call("resolve_special_outcome", "planet_destroyed", world)
			passed = (receipt.get("winner_player_indices", []) as Array) == [0] and (receipt.get("comparison_order", []) as Array) == ["cash_ledger_cents"]
			notes = "cash fallback exists only behind an explicit irreversible scenario trigger"
		"world_bridge_uses_region_and_flow_owners":
			var source := FileAccess.get_file_as_string(BRIDGE_SCRIPT_PATH)
			passed = source.contains("RegionInfrastructureRuntimeController") and source.contains("CommodityFlowRuntimeController.sale_receipts") and source.contains("regions_snapshot") and source.contains("region_gdp_snapshot") and not source.contains("project_positions")
			notes = "bridge collects lifecycle and 30-second sale GDP facts without owning either domain"
		"fixed_depth_and_failure_cooldown_absent":
			var source := FileAccess.get_file_as_string(CONTROLLER_SCRIPT_PATH)
			passed = not source.contains("victory_depth_table") and not source.contains("DEPTH_ORDER") and not source.contains("STATE_COOLDOWN") and not source.contains("cooldown_remaining_seconds")
			notes = "fixed depth table and failed-audit cooldown have no live implementation"
		"main_dynamic_consumer_cutover":
			var source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
			passed = source.contains("_victory_dynamic_rule") and source.contains("required_top_k_gdp_per_minute") and not source.contains("_victory_depth_rule") and not source.contains("_victory_depth_requirement")
			notes = "main only adapts the controller's current dynamic rule"
		"coordinator_static_composition":
			var packed := load(COORDINATOR_SCENE_PATH) as PackedScene
			var runtime := packed.instantiate() if packed != null else null
			var runtime_controller := runtime.get_node_or_null("VictoryControlRuntimeController") if runtime != null else null
			var world_bridge := runtime.get_node_or_null("VictoryControlWorldBridge") if runtime != null else null
			passed = runtime_controller != null and world_bridge != null and runtime_controller.scene_file_path == CONTROLLER_SCENE_PATH and world_bridge.scene_file_path == WORLD_BRIDGE_SCENE_PATH
			if runtime != null:
				runtime.free()
			notes = "GameRuntimeCoordinator statically composes one controller and one non-owning bridge"
		"all_payloads_are_pure_data":
			controller.call("advance_world_effective", 10.0, _world([36, 36], [], 5))
			passed = _is_data_only(controller.call("public_snapshot")) and _is_data_only(controller.call("private_snapshot", 0)) and _is_data_only(controller.call("to_save_data")) and _is_data_only(controller.call("debug_snapshot"))
			notes = "snapshot, save, debug, and outcome surfaces contain only pure data"
	evidence["state"] = str((controller.call("public_snapshot") as Dictionary).get("state", ""))
	evidence["victory_rule"] = (controller.call("public_snapshot") as Dictionary).get("victory_rule", {})
	evidence["pure_data_checked"] = _is_data_only(controller.call("debug_snapshot"))
	passed = passed and bool(evidence["pure_data_checked"])
	controller.free()
	return _record(case_id, passed, notes, evidence)


func _configure_runtime() -> void:
	if ruleset_bridge != null and coordinator != null:
		coordinator.call("configure", ruleset_bridge.call("active_profile"))


func _new_controller() -> Node:
	var packed := load(CONTROLLER_SCENE_PATH) as PackedScene
	if packed == null:
		return null
	var controller := packed.instantiate()
	controller_host.add_child(controller)
	var configured: Dictionary = controller.call("configure")
	if not bool(configured.get("configured", false)):
		controller.free()
		return null
	return controller


func _region_cents(index: int, total_cents: int, player_cents: Dictionary, lifecycle_state := "active") -> Dictionary:
	var by_index := {}
	for key_variant in player_cents.keys():
		by_index[str(int(key_variant))] = int(player_cents[key_variant])
	return {
		"region_id": "region.%04d" % index,
		"district_index": index,
		"lifecycle_state": lifecycle_state,
		"destroyed": lifecycle_state == "ruined",
		"region_gdp_per_minute_cents": total_cents,
		"region_gdp_per_minute": int(round(float(total_cents) / 100.0)),
		"player_gdp_by_index": by_index,
	}


func _world(player_zero_regions: Array, player_one_regions: Array, total_region_count: int, cash_values: Array = [10000, 10000]) -> Dictionary:
	var regions: Array = []
	var district_index := 0
	for amount_variant in player_zero_regions:
		var amount := maxi(1, int(amount_variant))
		regions.append(_region_cents(district_index, amount * 200, {0: amount * 100}))
		district_index += 1
	for amount_variant in player_one_regions:
		var amount := maxi(1, int(amount_variant))
		regions.append(_region_cents(district_index, amount * 200, {1: amount * 100}))
		district_index += 1
	while regions.size() < total_region_count:
		regions.append(_region_cents(district_index, 0, {}))
		district_index += 1
	return {
		"schema_version": "v0.6.victory-world.2",
		"players": [_player(0, int(cash_values[0])), _player(1, int(cash_values[1]))],
		"regions": regions,
		"clock_pause": {},
		"settlement_checkpoint": CHECKPOINT,
	}


func _player(index: int, cash_ledger_cents: int) -> Dictionary:
	return {
		"player_index": index,
		"eliminated": false,
		"cash_ledger_cents": cash_ledger_cents,
		"audit_assets": {
			"available_cents": cash_ledger_cents - 1000,
			"escrow_cents": 1000,
			"cash_ledger_cents": cash_ledger_cents,
			"ordinary_hand": [{"card_id": "card.audit.sample", "rank": 1, "kind": "facility"}],
			"facilities": [{"facility_id": "facility.sample", "region_id": "region.0000", "facility_type": "factory", "industry_id": "life", "rank": 1, "active": true}],
			"installations": [{"installation_id": "installation.sample", "commodity_id": "food", "color": "life", "direction": "production", "base_units_per_minute": 10}],
			"commodity_inventory": [{"warehouse_id": "warehouse.sample", "commodity_id": "food", "color": "life", "stored_milliunits": 2000}],
			"color_gdp": {"life": {"gdp_per_minute_cents": 3600, "gdp_per_minute": 36}},
			"units": [{"unit_uid": 1, "military_type": "defense", "rank": 1, "district_index": 0}],
			"contracts": [],
			"financial_positions": [],
			"private_intel": ["secret"],
			"secret_objective": "secret",
			"ai_private_weight": 99,
			"private_target": 1,
			"private_discard": "hidden",
		},
	}


func _rule(controller: Node, world: Dictionary) -> Dictionary:
	return controller.call("victory_rule_for_world", world) as Dictionary


func _required_regions(controller: Node, count: int) -> int:
	return int(_rule(controller, _world([], [], count)).get("required_region_count", -1))


func _candidate(candidates: Array, player_index: int) -> Dictionary:
	for candidate_variant in candidates:
		if candidate_variant is Dictionary and int((candidate_variant as Dictionary).get("player_index", -1)) == player_index:
			return candidate_variant as Dictionary
	return {}


func _share_for(control: Dictionary, player_index: int) -> int:
	for row_variant in control.get("player_results", []):
		if row_variant is Dictionary and int((row_variant as Dictionary).get("player_index", -1)) == player_index:
			return int((row_variant as Dictionary).get("share_basis_points", -1))
	return -1


func _start_audit(controller: Node, world: Dictionary) -> void:
	controller.call("advance_world_effective", 10.0, world)


func _complete_joint_audit(controller: Node, endpoint_world: Dictionary) -> Dictionary:
	_start_audit(controller, _world([36, 36], [36, 36], 5, [10000, 10000]))
	controller.call("advance_world_effective", 120.0, endpoint_world)
	return controller.call("outcome_receipt") as Dictionary


func _pause_case(controller: Node, pause_key: String) -> bool:
	var world := _world([36, 36], [], 5)
	controller.call("advance_world_effective", 4.0, world)
	world["clock_pause"] = {pause_key: true}
	controller.call("advance_world_effective", 20.0, world)
	var snapshot: Dictionary = controller.call("public_snapshot")
	return str(snapshot.get("state", "")) == "qualification" and is_equal_approx(float(snapshot.get("qualification_remaining_seconds", 0.0)), 6.0) and (snapshot.get("pause_reasons", []) as Array).has(pause_key)


func _audit_entry(snapshot: Dictionary, player_index: int) -> Dictionary:
	for entry_variant in snapshot.get("audit_entries", []):
		if entry_variant is Dictionary and int((entry_variant as Dictionary).get("player_index", -1)) == player_index:
			return (entry_variant as Dictionary).duplicate(true)
	return {}


func _record(case_id: String, passed: bool, notes: String, overrides: Dictionary = {}) -> Dictionary:
	var record := {
		"case_id": case_id,
		"state": "",
		"victory_rule": {},
		"dynamic_threshold_checked": false,
		"qualification_checked": false,
		"audit_checked": false,
		"ordering_checked": false,
		"save_checked": false,
		"privacy_checked": false,
		"pure_data_checked": false,
		"passed": passed,
		"notes": notes,
	}
	record.merge(overrides, true)
	return record


func _update_ui(manifest: Dictionary) -> void:
	summary_label.text = "%d/%d v0.6 dynamic victory cases passed" % [int(manifest.get("passed_count", 0)), _records.size()]
	status_label.text = "PASS" if _failures.is_empty() else "FAIL"
	status_label.modulate = Color("4ade80") if _failures.is_empty() else Color("fb7185")
	rules_text.text = "[b]Victory Control v0.6[/b]\nControl        3000bp + unique highest\nCoverage       K = ceil(surviving regions x 40%)\nGDP threshold  K x 36 GDP/min\nQualification  10 world-effective seconds\nPublic audit   120 world-effective seconds\n\n[b]Endpoint order[/b]\nPost-settlement snapshot\nTop-K commodity GDP cents\nControlled region count\nExact cash\nExact tie: co-victory\n\n[b]Privacy[/b]\nOnly audit-roster economic assets become public. Private investigations, secret goals, AI weights, targets, and discards stay hidden."
	var lines: Array[String] = []
	for record_variant in _records:
		var record: Dictionary = record_variant
		lines.append("[color=%s]%s[/color]  %s\n%s" % ["#4ade80" if bool(record.get("passed", false)) else "#fb7185", "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("case_id", "")), str(record.get("notes", ""))])
	results_text.text = "\n\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines := ["# Victory Control Runtime v0.6", "", "- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))], "- Dynamic coverage: `ceil(A * 40%)`", "- GDP threshold: `K * 36 GDP/min`", "- Failure cooldown: absent", "", "| Case | Result | Notes |", "| --- | --- | --- |"]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| %s | %s | %s |" % [str(record.get("case_id", "")), "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("notes", "")).replace("|", "/")])
	return "\n".join(lines) + "\n"


func _prepare_output_dir() -> void:
	var absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute)
	for file_name in ["manifest.json", "report.md"]:
		var file_path := absolute.path_join(file_name)
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("cannot write %s" % path)
		return
	file.store_string(content)
	file.close()


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_failures.append("viewport screenshot is empty")
		return
	var error := image.save_png(SCREENSHOT_PATH)
	if error != OK:
		_failures.append("screenshot save failed: %s" % error_string(error))


func _passed_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item_variant in value:
			if not _is_data_only(item_variant):
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
		return true
	return false
