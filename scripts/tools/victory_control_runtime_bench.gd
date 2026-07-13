extends Control
class_name VictoryControlRuntimeBench

const CONTROLLER_SCENE_PATH := "res://scenes/runtime/VictoryControlRuntimeController.tscn"
const WORLD_BRIDGE_SCENE_PATH := "res://scenes/runtime/VictoryControlWorldBridge.tscn"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const AI_SCRIPT_PATH := "res://scripts/runtime/ai_runtime_controller.gd"
const STANDINGS_SCRIPT_PATH := "res://scripts/runtime/standings_public_snapshot_service.gd"
const FINAL_SCRIPT_PATH := "res://scripts/runtime/final_settlement_public_snapshot_service.gd"
const SAVE_SCRIPT_PATH := "res://scripts/runtime/game_save_runtime_coordinator.gd"
const LEGACY_SMOKE_TEST_PATH := "res://tests/smoke_test.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/victory_control_runtime/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/victory_control_runtime_sprint_4.png"

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
		"controller_scene_composition",
		"controller_api_contract",
		"v05_profile_is_domain_source",
		"depth_i_to_vi_exact",
		"share_2999bp_fails",
		"share_3000bp_unique_controls",
		"share_3000bp_tie_no_control",
		"destroyed_region_no_control",
		"zero_gdp_region_no_control",
		"top_n_selects_highest_regions",
		"region_count_gate",
		"top_n_gdp_gate",
		"both_gates_required",
		"qualification_999_not_triggered",
		"qualification_10_starts_audit",
		"qualification_resets_on_loss",
		"audit_duration_120",
		"audit_does_not_cancel_midway",
		"late_sole_leader_joins_roster",
		"late_tied_leader_joins_roster",
		"roster_is_sticky_during_audit",
		"endpoint_only_roster_candidates",
		"endpoint_rechecks_eligibility",
		"endpoint_same_tick_leader_joins",
		"comparator_top_n_gdp",
		"comparator_region_count",
		"comparator_cash_ledger",
		"exact_tie_is_co_victory",
		"no_finalist_enters_cooldown",
		"cooldown_duration_30",
		"qualification_retriggers_after_cooldown",
		"menu_pause_freezes_clock",
		"readonly_pause_freezes_clock",
		"forced_decision_freezes_clock",
		"monster_wager_freezes_clock",
		"save_restores_qualification",
		"save_restores_audit_roster_and_time",
		"save_restores_cooldown",
		"invalid_save_fails_closed",
		"public_assets_only_for_roster",
		"public_hand_and_unit_counts_allowed",
		"public_snapshot_hides_private_contents",
		"private_snapshot_is_viewer_scoped",
		"outcome_receipt_exact_once",
		"session_finish_receipt_exact_once",
		"last_survivor_routes_to_controller",
		"planet_destroyed_uses_cash_only",
		"planet_destroyed_cash_tie_co_victory",
		"active_global_bridge_remains_v04",
		"all_controller_payloads_are_pure_data",
		"main_legacy_cash_victory_absent",
		"ai_consumes_victory_controller",
		"standings_consumes_public_snapshot",
		"final_settlement_consumes_receipt",
		"save_summary_has_no_legacy_score",
		"real_main_static_composition",
	]


func build_victory_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in victory_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {
		"suite": "victory-control-v05",
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
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "failed"))])
	var manifest := {
		"suite": "victory-control-v05",
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
	print("VictoryControlRuntimeBench manifest: %s" % MANIFEST_PATH)
	print("VictoryControlRuntimeBench report: %s" % REPORT_PATH)
	print("VictoryControlRuntimeBench screenshot: %s" % SCREENSHOT_PATH)
	print("VictoryControlRuntimeBench passed: %d/%d" % [_passed_count(), _records.size()])
	if not _failures.is_empty():
		push_error("VictoryControlRuntimeBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)


func _run_case(case_id: String) -> Dictionary:
	var controller := _new_controller()
	var passed := controller != null
	var notes := ""
	var evidence := {}
	if controller == null:
		return _record(case_id, false, "controller scene could not be instantiated")
	match case_id:
		"controller_scene_composition":
			passed = controller.scene_file_path == CONTROLLER_SCENE_PATH and controller.get("ruleset_profile") is Resource and controller.get("clock_domain_registry") is Resource
			notes = "the editable scene owns the v0.5 profile and world-effective clock registry"
		"controller_api_contract":
			var methods := ["configure", "evaluate_region_control", "evaluate_candidates", "advance_world_effective", "resolve_special_outcome", "public_snapshot", "private_snapshot", "to_save_data", "apply_save_data", "debug_snapshot"]
			for method_variant in methods:
				passed = passed and controller.has_method(str(method_variant))
			notes = "controller exposes one pure-data API for control, audit, outcome, and save ownership"
		"v05_profile_is_domain_source":
			var debug: Dictionary = controller.call("debug_snapshot")
			passed = bool(debug.get("controller_ready", false)) and str(debug.get("ruleset_id", "")) == "v0.5" and bool(debug.get("owns_victory_state", false))
			notes = "victory domain reads the Inspector v0.5 profile directly"
		"depth_i_to_vi_exact":
			var expected := {"I": [3, 90], "II": [4, 130], "III": [5, 180], "IV": [6, 230], "V": [7, 290], "VI": [8, 360]}
			for depth_id_variant in expected.keys():
				var rule: Dictionary = controller.call("depth_rule_for_tier", str(depth_id_variant))
				var values: Array = expected[depth_id_variant]
				passed = passed and int(rule.get("regions", 0)) == int(values[0]) and int(rule.get("depth", 0)) == int(values[1])
			notes = "depth I-VI resolve to 3/90, 4/130, 5/180, 6/230, 7/290, and 8/360"
		"share_2999bp_fails":
			var control: Dictionary = controller.call("evaluate_region_control", _region(0, 10000, {0: 2999, 1: 1000}))
			passed = int(control.get("controller_player_index", -1)) == -1 and _share_for(control, 0) == 2999
			notes = "29.99% never controls a region"
		"share_3000bp_unique_controls":
			var control: Dictionary = controller.call("evaluate_region_control", _region(0, 10000, {0: 3000, 1: 1000}))
			passed = int(control.get("controller_player_index", -1)) == 0 and _share_for(control, 0) == 3000
			notes = "30.00% with a unique highest share controls"
		"share_3000bp_tie_no_control":
			var control: Dictionary = controller.call("evaluate_region_control", _region(0, 10000, {0: 3000, 1: 3000}))
			passed = int(control.get("controller_player_index", -1)) == -1
			notes = "an exact highest-share tie leaves the region contested"
		"destroyed_region_no_control":
			var control: Dictionary = controller.call("evaluate_region_control", _region(0, 100, {0: 60}, true))
			passed = int(control.get("controller_player_index", -1)) == -1
			notes = "destroyed regions never award control"
		"zero_gdp_region_no_control":
			var control: Dictionary = controller.call("evaluate_region_control", _region(0, 0, {0: 0}))
			passed = int(control.get("controller_player_index", -1)) == -1
			notes = "zero-GDP regions never award control"
		"top_n_selects_highest_regions":
			var world := _candidate_world([60, 40, 30, 5], [], 10000, 10000)
			var candidate := _candidate(controller.call("evaluate_candidates", world), 0)
			passed = int(candidate.get("controlled_region_count", 0)) == 4 and int(candidate.get("top_n_gdp_per_minute", 0)) == 130
			notes = "Top N automatically selects the three highest controlled-region GDP values"
		"region_count_gate":
			var candidate := _candidate(controller.call("evaluate_candidates", _candidate_world([45, 45], [], 10000, 10000)), 0)
			passed = int(candidate.get("top_n_gdp_per_minute", 0)) == 90 and not bool(candidate.get("eligible", true))
			notes = "GDP alone does not replace the required controlled-region count"
		"top_n_gdp_gate":
			var candidate := _candidate(controller.call("evaluate_candidates", _candidate_world([29, 29, 29], [], 10000, 10000)), 0)
			passed = int(candidate.get("controlled_region_count", 0)) == 3 and int(candidate.get("top_n_gdp_per_minute", 0)) == 87 and not bool(candidate.get("eligible", true))
			notes = "region count alone does not replace the Top-N GDP threshold"
		"both_gates_required":
			var candidate := _candidate(controller.call("evaluate_candidates", _candidate_world([30, 30, 30], [], 10000, 10000)), 0)
			passed = bool(candidate.get("eligible", false))
			notes = "three controlled regions and exactly 90 Top-N GDP qualify at depth I"
		"qualification_999_not_triggered":
			controller.call("advance_world_effective", 9.99, _candidate_world([30, 30, 30], [], 10000, 10000))
			var snapshot: Dictionary = controller.call("public_snapshot")
			passed = str(snapshot.get("state", "")) == "qualification" and float(snapshot.get("qualification_remaining_seconds", 0.0)) > 0.0
			notes = "9.99 effective seconds do not start the audit"
		"qualification_10_starts_audit":
			controller.call("advance_world_effective", 10.0, _candidate_world([30, 30, 30], [], 10000, 10000))
			var snapshot: Dictionary = controller.call("public_snapshot")
			passed = str(snapshot.get("state", "")) == "audit" and is_equal_approx(float(snapshot.get("audit_remaining_seconds", 0.0)), 120.0)
			notes = "10 effective seconds start a fixed 120-second public audit"
		"qualification_resets_on_loss":
			controller.call("advance_world_effective", 7.0, _candidate_world([30, 30, 30], [], 10000, 10000))
			controller.call("advance_world_effective", 1.0, _candidate_world([29, 29, 29], [], 10000, 10000))
			var snapshot: Dictionary = controller.call("public_snapshot")
			passed = str(snapshot.get("state", "")) == "idle" and is_equal_approx(float(snapshot.get("qualification_remaining_seconds", -1.0)), 0.0)
			notes = "losing either threshold resets qualification progress"
		"audit_duration_120":
			_start_audit(controller, _candidate_world([30, 30, 30], [], 10000, 10000))
			controller.call("advance_world_effective", 119.99, _candidate_world([30, 30, 30], [], 10000, 10000))
			passed = str((controller.call("public_snapshot") as Dictionary).get("state", "")) == "audit"
			notes = "the audit remains active until the full 120 effective seconds elapse"
		"audit_does_not_cancel_midway":
			_start_audit(controller, _candidate_world([30, 30, 30], [], 10000, 10000))
			controller.call("advance_world_effective", 20.0, _candidate_world([29, 29, 29], [], 10000, 10000))
			var snapshot: Dictionary = controller.call("public_snapshot")
			passed = str(snapshot.get("state", "")) == "audit" and (snapshot.get("audit_roster", []) as Array).has(0)
			notes = "temporary loss of eligibility does not cancel or hide an active audit"
		"late_sole_leader_joins_roster":
			_start_audit(controller, _candidate_world([30, 30, 30], [], 10000, 10000))
			controller.call("advance_world_effective", 1.0, _candidate_world([], [40, 40, 40], 10000, 10000))
			var roster: Array = (controller.call("public_snapshot") as Dictionary).get("audit_roster", []) as Array
			passed = roster.has(0) and roster.has(1)
			notes = "a newly leading player joins the fixed public roster during audit"
		"late_tied_leader_joins_roster":
			_start_audit(controller, _candidate_world([40, 40, 40], [], 10000, 10000))
			controller.call("advance_world_effective", 1.0, _candidate_world([30, 30, 30], [30, 30, 30], 10000, 10000))
			var roster: Array = (controller.call("public_snapshot") as Dictionary).get("audit_roster", []) as Array
			passed = roster == [0, 1]
			notes = "exactly tied leaders are both added and published"
		"roster_is_sticky_during_audit":
			_start_audit(controller, _candidate_world([30, 30, 30], [], 10000, 10000))
			controller.call("advance_world_effective", 1.0, _candidate_world([], [40, 40, 40], 10000, 10000))
			var snapshot: Dictionary = controller.call("public_snapshot")
			passed = (snapshot.get("audit_roster", []) as Array).has(0) and not _audit_entry(snapshot, 0).is_empty()
			notes = "a listed player stays public for the rest of the audit even after falling behind"
		"endpoint_only_roster_candidates":
			_start_audit(controller, _candidate_world([30, 30, 30], [30, 30, 30], 20000, 10000))
			var endpoint := _three_player_world([40, 40, 40], [30, 30, 30], [30, 30, 30], [20000, 10000, 5000])
			controller.call("advance_world_effective", 120.0, endpoint)
			var receipt: Dictionary = controller.call("outcome_receipt")
			passed = not _ranking_has_player(receipt, 2)
			notes = "eligible non-leaders outside the audit roster are not endpoint finalists"
		"endpoint_rechecks_eligibility":
			_start_audit(controller, _candidate_world([30, 30, 30], [], 10000, 10000))
			controller.call("advance_world_effective", 120.0, _candidate_world([29, 29, 29], [], 10000, 10000))
			passed = str((controller.call("public_snapshot") as Dictionary).get("state", "")) == "cooldown" and (controller.call("outcome_receipt") as Dictionary).is_empty()
			notes = "roster players must satisfy both gates again at the endpoint"
		"endpoint_same_tick_leader_joins":
			_start_audit(controller, _candidate_world([30, 30, 30], [], 10000, 10000))
			controller.call("advance_world_effective", 120.0, _candidate_world([], [40, 40, 40], 10000, 10000))
			var receipt: Dictionary = controller.call("outcome_receipt")
			passed = (receipt.get("winner_player_indices", []) as Array) == [1] and ((receipt.get("audit_evidence", {}) as Dictionary).get("audit_roster", []) as Array).has(1)
			notes = "a same-tick new leader is published before endpoint ranking"
		"comparator_top_n_gdp":
			var receipt := _complete_tied_audit(controller, _candidate_world([40, 40, 40], [30, 30, 30], 10000, 10000))
			passed = (receipt.get("winner_player_indices", []) as Array) == [0]
			notes = "Top-N attributable GDP is the first endpoint comparator"
		"comparator_region_count":
			var receipt := _complete_tied_audit(controller, _candidate_world([30, 30, 30, 1], [30, 30, 30], 10000, 10000))
			passed = (receipt.get("winner_player_indices", []) as Array) == [0]
			notes = "controlled-region count breaks equal Top-N GDP"
		"comparator_cash_ledger":
			var receipt := _complete_tied_audit(controller, _candidate_world([30, 30, 30], [30, 30, 30], 20000, 10000))
			passed = (receipt.get("winner_player_indices", []) as Array) == [0]
			notes = "available plus escrow cash ledger is the final normal comparator"
		"exact_tie_is_co_victory":
			var receipt := _complete_tied_audit(controller, _candidate_world([30, 30, 30], [30, 30, 30], 10000, 10000))
			passed = bool(receipt.get("co_victory", false)) and (receipt.get("winner_player_indices", []) as Array) == [0, 1]
			notes = "an exact comparison-chain tie yields a co-victory receipt"
		"no_finalist_enters_cooldown":
			_start_audit(controller, _candidate_world([30, 30, 30], [], 10000, 10000))
			controller.call("advance_world_effective", 120.0, _candidate_world([29, 29, 29], [], 10000, 10000))
			var snapshot: Dictionary = controller.call("public_snapshot")
			passed = str(snapshot.get("state", "")) == "cooldown" and is_equal_approx(float(snapshot.get("cooldown_remaining_seconds", 0.0)), 30.0)
			notes = "an audit with no still-qualified finalist enters a 30-second cooldown"
		"cooldown_duration_30":
			_enter_cooldown(controller)
			controller.call("advance_world_effective", 29.99, _candidate_world([29, 29, 29], [], 10000, 10000))
			passed = str((controller.call("public_snapshot") as Dictionary).get("state", "")) == "cooldown"
			notes = "cooldown lasts the full 30 effective seconds"
		"qualification_retriggers_after_cooldown":
			_enter_cooldown(controller)
			controller.call("advance_world_effective", 30.0, _candidate_world([29, 29, 29], [], 10000, 10000))
			controller.call("advance_world_effective", 1.0, _candidate_world([30, 30, 30], [], 10000, 10000))
			passed = str((controller.call("public_snapshot") as Dictionary).get("state", "")) == "qualification"
			notes = "qualification can begin again after cooldown expires"
		"menu_pause_freezes_clock":
			passed = _pause_case(controller, "menu_paused")
			notes = "menu pause consumes no world-effective qualification time"
		"readonly_pause_freezes_clock":
			passed = _pause_case(controller, "readonly_paused")
			notes = "readonly pause consumes no world-effective qualification time"
		"forced_decision_freezes_clock":
			passed = _pause_case(controller, "forced_decision_paused")
			notes = "forced-decision preemption consumes no qualification time"
		"monster_wager_freezes_clock":
			passed = _pause_case(controller, "monster_wager_world_frozen")
			notes = "the wager world freeze consumes no victory clock time"
		"save_restores_qualification":
			controller.call("advance_world_effective", 6.0, _candidate_world([30, 30, 30], [], 10000, 10000))
			var restored := _new_controller()
			var applied: Dictionary = restored.call("apply_save_data", controller.call("to_save_data"))
			var snapshot: Dictionary = restored.call("public_snapshot")
			passed = bool(applied.get("applied", false)) and str(snapshot.get("state", "")) == "qualification" and is_equal_approx(float(snapshot.get("qualification_remaining_seconds", 0.0)), 4.0)
			restored.free()
			notes = "qualification elapsed time round-trips exactly"
		"save_restores_audit_roster_and_time":
			_start_audit(controller, _candidate_world([30, 30, 30], [], 10000, 10000))
			controller.call("advance_world_effective", 17.0, _candidate_world([30, 30, 30], [], 10000, 10000))
			var restored := _new_controller()
			var applied: Dictionary = restored.call("apply_save_data", controller.call("to_save_data"))
			var snapshot: Dictionary = restored.call("public_snapshot")
			passed = bool(applied.get("applied", false)) and (snapshot.get("audit_roster", []) as Array) == [0] and is_equal_approx(float(snapshot.get("audit_remaining_seconds", 0.0)), 103.0)
			restored.free()
			notes = "audit roster and remaining time survive save/load"
		"save_restores_cooldown":
			_enter_cooldown(controller)
			controller.call("advance_world_effective", 7.0, _candidate_world([], [], 10000, 10000))
			var restored := _new_controller()
			var applied: Dictionary = restored.call("apply_save_data", controller.call("to_save_data"))
			var snapshot: Dictionary = restored.call("public_snapshot")
			passed = bool(applied.get("applied", false)) and is_equal_approx(float(snapshot.get("cooldown_remaining_seconds", 0.0)), 23.0)
			restored.free()
			notes = "cooldown remaining time round-trips exactly"
		"invalid_save_fails_closed":
			var before: Dictionary = controller.call("public_snapshot")
			var applied: Dictionary = controller.call("apply_save_data", {"schema_version": 99, "ruleset_id": "v0.4", "state": "resolved"})
			var after: Dictionary = controller.call("public_snapshot")
			passed = not bool(applied.get("applied", true)) and str(before.get("state", "")) == str(after.get("state", ""))
			notes = "wrong ruleset or schema cannot mutate the active state"
		"public_assets_only_for_roster":
			_start_audit(controller, _candidate_world([30, 30, 30], [], 10000, 9000))
			var snapshot: Dictionary = controller.call("public_snapshot")
			passed = not _audit_entry(snapshot, 0).is_empty() and _audit_entry(snapshot, 1).is_empty()
			notes = "only listed players expose exact economic assets"
		"public_hand_and_unit_counts_allowed":
			_start_audit(controller, _candidate_world([30, 30, 30], [], 10000, 9000))
			var assets: Dictionary = _audit_entry(controller.call("public_snapshot"), 0).get("economic_assets", {}) as Dictionary
			passed = int(assets.get("hand_count", -1)) == 3 and int(assets.get("unit_count", -1)) == 2
			notes = "the rulebook-authorized counts are public without exposing contents"
		"public_snapshot_hides_private_contents":
			_start_audit(controller, _candidate_world([30, 30, 30], [], 10000, 9000))
			var text := JSON.stringify(controller.call("public_snapshot"))
			passed = not text.contains("hand_contents") and not text.contains("private_intel") and not text.contains("hidden_monster_owner") and not text.contains("ai_plan")
			notes = "public audit payloads exclude private hands, intel, monster ownership, and AI plans"
		"private_snapshot_is_viewer_scoped":
			controller.call("advance_world_effective", 1.0, _candidate_world([30, 30, 30], [], 10000, 9000))
			var own: Dictionary = controller.call("private_snapshot", 1)
			passed = int((own.get("own_candidate", {}) as Dictionary).get("player_index", -1)) == 1 and int((own.get("own_economic_assets", {}) as Dictionary).get("available_cents", -1)) == 8000 and int((own.get("own_economic_assets", {}) as Dictionary).get("cash_ledger_cents", -1)) == 9000
			notes = "viewer-private snapshot contains only the requested player's authorized facts"
		"outcome_receipt_exact_once":
			var receipt := _complete_tied_audit(controller, _candidate_world([30, 30, 30], [30, 30, 30], 10000, 10000))
			controller.call("advance_world_effective", 999.0, _candidate_world([40, 40, 40], [], 50000, 0))
			passed = receipt == controller.call("outcome_receipt") and str(receipt.get("outcome_id", "")) == "victory.v05.1"
			notes = "a resolved controller emits one immutable outcome receipt"
		"session_finish_receipt_exact_once":
			coordinator.call("reset_runtime_session")
			coordinator.call("begin_session", {"session_id": "victory-bench", "seed": 1})
			var first := {"outcome_id": "victory.v05.1", "winner_player_indices": [0]}
			var second := {"outcome_id": "victory.v05.2", "winner_player_indices": [1]}
			coordinator.call("finish_session", first)
			coordinator.call("finish_session", second)
			var saved: Dictionary = coordinator.call("session_to_save_data")
			var summary: Dictionary = saved.get("game_session_runtime", {}) as Dictionary
			passed = str(summary.get("session_state", "")) == "finished" and (summary.get("outcome_receipt", {}) as Dictionary) == first
			notes = "GameSession accepts the first pure-data outcome and ignores duplicate completion"
		"last_survivor_routes_to_controller":
			var world := _candidate_world([], [], 12000, 9000)
			(world.get("players", []) as Array)[1]["eliminated"] = true
			var receipt: Dictionary = controller.call("resolve_special_outcome", "last_survivor", world)
			passed = str(receipt.get("reason_code", "")) == "last_survivor" and (receipt.get("winner_player_indices", []) as Array) == [0]
			notes = "last-survivor completion uses the same versioned outcome path"
		"planet_destroyed_uses_cash_only":
			var world := _candidate_world([], [100, 100, 100], 20000, 10000)
			var receipt: Dictionary = controller.call("resolve_special_outcome", "planet_destroyed", world)
			passed = (receipt.get("winner_player_indices", []) as Array) == [0] and (receipt.get("comparison_order", []) as Array) == ["cash_ledger_cents"]
			notes = "planet destruction ignores GDP ranking and compares exact cash ledger only"
		"planet_destroyed_cash_tie_co_victory":
			var receipt: Dictionary = controller.call("resolve_special_outcome", "planet_destroyed", _candidate_world([], [], 10000, 10000))
			passed = bool(receipt.get("co_victory", false)) and (receipt.get("winner_player_indices", []) as Array) == [0, 1]
			notes = "equal cash ledgers share the planet-destruction victory"
		"active_global_bridge_remains_v04":
			var active: Dictionary = ruleset_bridge.call("active_profile")
			passed = str(active.get("ruleset_id", "")) == "v0.4"
			notes = "the global release bridge remains v0.4 during domain-by-domain integration"
		"all_controller_payloads_are_pure_data":
			controller.call("advance_world_effective", 10.0, _candidate_world([30, 30, 30], [], 10000, 10000))
			passed = _is_data_only(controller.call("public_snapshot")) and _is_data_only(controller.call("private_snapshot", 0)) and _is_data_only(controller.call("to_save_data")) and _is_data_only(controller.call("debug_snapshot"))
			notes = "snapshot, save, receipt, and debug surfaces contain no runtime objects"
		"main_legacy_cash_victory_absent":
			var source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
			var smoke_source := FileAccess.get_file_as_string(LEGACY_SMOKE_TEST_PATH)
			var forbidden := ["var game_over", "victory_countdown", "_roguelike_cash_goal", "_player_visible_settlement_estimate", "_player_final_score", "_final_score_rankings", "CITY_FINAL_VALUE"]
			for token_variant in forbidden:
				passed = passed and not source.contains(str(token_variant)) and not smoke_source.contains(str(token_variant))
			notes = "main and the active legacy smoke gate have no writable game-over flag, cash goal, city clearance, or countdown path"
		"ai_consumes_victory_controller":
			var source := FileAccess.get_file_as_string(AI_SCRIPT_PATH)
			passed = source.contains("set_victory_control_runtime_controller") and source.contains("_victory_public_snapshot") and not source.contains("cash_goal") and not source.contains("settlement_estimate")
			notes = "AI consumes authorized victory snapshots and the outcome receipt instead of recomputing scores"
		"standings_consumes_public_snapshot":
			var source := FileAccess.get_file_as_string(STANDINGS_SCRIPT_PATH)
			passed = source.contains("victory_control") and source.contains("audit_entries") and not source.contains("CITY_FINAL_VALUE")
			notes = "standings presents the public controller snapshot"
		"final_settlement_consumes_receipt":
			var source := FileAccess.get_file_as_string(FINAL_SCRIPT_PATH)
			passed = source.contains("outcome_receipt") and source.contains("consumes_outcome_receipt") and source.contains("winner") and not source.contains("city_clearance_value")
			notes = "final settlement presents an outcome receipt and never invents a second score"
		"save_summary_has_no_legacy_score":
			var source := FileAccess.get_file_as_string(SAVE_SCRIPT_PATH)
			passed = source.contains("_saved_victory_status_text") and not source.contains("_saved_player_score") and not source.contains("city_final_value")
			notes = "save summaries report receipt/audit status without cash-goal reconstruction"
		"real_main_static_composition":
			var packed := load(MAIN_SCENE_PATH) as PackedScene
			var main := packed.instantiate() if packed != null else null
			var runtime_controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/VictoryControlRuntimeController") if main != null else null
			var world_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/VictoryControlWorldBridge") if main != null else null
			passed = runtime_controller != null and world_bridge != null and runtime_controller.scene_file_path == CONTROLLER_SCENE_PATH and world_bridge.scene_file_path == WORLD_BRIDGE_SCENE_PATH
			if main != null:
				main.free()
			notes = "real main statically composes the single controller and non-owning world bridge"
	evidence["state"] = str((controller.call("public_snapshot") as Dictionary).get("state", ""))
	evidence["pure_data_checked"] = _is_data_only(controller.call("debug_snapshot"))
	evidence["legacy_fallback_used"] = bool((controller.call("debug_snapshot") as Dictionary).get("legacy_cash_goal_fallback_used", true))
	passed = passed and bool(evidence["pure_data_checked"]) and not bool(evidence["legacy_fallback_used"])
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


func _region(index: int, total_gdp: int, player_gdp: Dictionary, destroyed := false) -> Dictionary:
	var by_index := {}
	for player_key_variant in player_gdp.keys():
		by_index[str(int(player_key_variant))] = int(player_gdp[player_key_variant])
	return {"region_id": "region.%04d" % index, "district_index": index, "destroyed": destroyed, "region_gdp_per_minute": total_gdp, "player_gdp_by_index": by_index}


func _player(index: int, cash_ledger_cents: int) -> Dictionary:
	return {
		"player_index": index,
		"eliminated": false,
		"cash_ledger_cents": cash_ledger_cents,
		"audit_assets": {
			"available_cents": cash_ledger_cents - 1000,
			"escrow_cents": 1000,
			"cash_ledger_cents": cash_ledger_cents,
			"project_positions": [{"project_id": "region.%04d.slot.production.0.project.g1" % index, "share_basis_points": 5000}],
			"contracts": [],
			"warehouses": [],
			"financial_positions": [],
			"hand_count": 3,
			"unit_count": 2,
			"hand_contents": ["private.card"],
			"private_intel": ["private.clue"],
			"hidden_monster_owner": index,
			"ai_plan": "private.plan",
		},
	}


func _candidate_world(player_zero_regions: Array, player_one_regions: Array, player_zero_cash: int, player_one_cash: int, depth := "I") -> Dictionary:
	var regions: Array = []
	var district_index := 0
	for amount_variant in player_zero_regions:
		var amount := maxi(1, int(amount_variant))
		regions.append(_region(district_index, amount * 2, {0: amount, 1: 0}))
		district_index += 1
	for amount_variant in player_one_regions:
		var amount := maxi(1, int(amount_variant))
		regions.append(_region(district_index, amount * 2, {0: 0, 1: amount}))
		district_index += 1
	return {"schema_version": "v0.5.victory-world.1", "depth_tier": depth, "players": [_player(0, player_zero_cash), _player(1, player_one_cash)], "regions": regions, "clock_pause": {}}


func _three_player_world(player_zero_regions: Array, player_one_regions: Array, player_two_regions: Array, cash_values: Array) -> Dictionary:
	var regions: Array = []
	var district_index := 0
	for player_index in range(3):
		var amounts: Array = [player_zero_regions, player_one_regions, player_two_regions][player_index]
		for amount_variant in amounts:
			var amount := maxi(1, int(amount_variant))
			regions.append(_region(district_index, amount * 2, {player_index: amount}))
			district_index += 1
	return {"schema_version": "v0.5.victory-world.1", "depth_tier": "I", "players": [_player(0, int(cash_values[0])), _player(1, int(cash_values[1])), _player(2, int(cash_values[2]))], "regions": regions, "clock_pause": {}}


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


func _complete_tied_audit(controller: Node, endpoint_world: Dictionary) -> Dictionary:
	_start_audit(controller, _candidate_world([30, 30, 30], [30, 30, 30], 10000, 10000))
	controller.call("advance_world_effective", 120.0, endpoint_world)
	return controller.call("outcome_receipt") as Dictionary


func _enter_cooldown(controller: Node) -> void:
	_start_audit(controller, _candidate_world([30, 30, 30], [], 10000, 10000))
	controller.call("advance_world_effective", 120.0, _candidate_world([29, 29, 29], [], 10000, 10000))


func _pause_case(controller: Node, pause_key: String) -> bool:
	var world := _candidate_world([30, 30, 30], [], 10000, 10000)
	controller.call("advance_world_effective", 4.0, world)
	world["clock_pause"] = {pause_key: true}
	controller.call("advance_world_effective", 20.0, world)
	var snapshot: Dictionary = controller.call("public_snapshot")
	return str(snapshot.get("state", "")) == "qualification" and is_equal_approx(float(snapshot.get("qualification_remaining_seconds", 0.0)), 6.0) and (snapshot.get("pause_reasons", []) as Array).has(pause_key)


func _audit_entry(snapshot: Dictionary, player_index: int) -> Dictionary:
	for entry_variant in snapshot.get("audit_entries", []):
		if entry_variant is Dictionary and int((entry_variant as Dictionary).get("player_index", -1)) == player_index:
			return entry_variant as Dictionary
	return {}


func _ranking_has_player(receipt: Dictionary, player_index: int) -> bool:
	for ranking_variant in receipt.get("rankings", []):
		if ranking_variant is Dictionary and int((ranking_variant as Dictionary).get("player_index", -1)) == player_index:
			return true
	return false


func _record(case_id: String, passed: bool, notes: String, overrides: Dictionary = {}) -> Dictionary:
	var record := {
		"case_id": case_id,
		"state": "",
		"control_checked": false,
		"qualification_checked": false,
		"audit_checked": false,
		"ordering_checked": false,
		"save_checked": false,
		"privacy_checked": false,
		"session_checked": false,
		"pure_data_checked": false,
		"legacy_fallback_used": false,
		"passed": passed,
		"notes": notes,
	}
	record.merge(overrides, true)
	return record


func _update_ui(manifest: Dictionary) -> void:
	summary_label.text = "%d/%d victory-control cases passed" % [int(manifest.get("passed_count", 0)), _records.size()]
	status_label.text = "PASS" if _failures.is_empty() else "FAIL"
	status_label.modulate = Color("4ade80") if _failures.is_empty() else Color("fb7185")
	rules_text.text = "[b]Victory Control v0.5[/b]\nRegion control  3000bp + unique highest\nDepth I-VI      3/90 through 8/360\nQualification  10 effective seconds\nPublic audit    120 effective seconds\nFailure cooldown 30 effective seconds\n\n[b]Endpoint order[/b]\nTop-N attributable GDP\nControlled region count\nAvailable + escrow cash ledger\nExact tie: co-victory\n\n[b]Privacy[/b]\nOnly audit-roster balance sheets are public. Card contents, private intel, hidden monster ownership, and AI plans stay private."
	var lines: Array[String] = []
	for record_variant in _records:
		var record: Dictionary = record_variant
		lines.append("[color=%s]%s[/color]  %s\n%s" % ["#4ade80" if bool(record.get("passed", false)) else "#fb7185", "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("case_id", "")), str(record.get("notes", ""))])
	results_text.text = "\n\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines := ["# Victory Control Runtime v0.5", "", "- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))], "- Controller: `%s`" % CONTROLLER_SCENE_PATH, "- Legacy cash-goal fallback: absent", "", "| Case | Result | Notes |", "| --- | --- | --- |"]
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
