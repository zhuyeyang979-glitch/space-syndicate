extends Control
class_name MonsterRuntimeCharacterizationBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/monster_runtime_controller.gd"
const CONTROLLER_SCENE_PATH := "res://scenes/runtime/MonsterRuntimeController.tscn"
const WORLD_BRIDGE_SCENE_PATH := "res://scenes/runtime/MonsterRuntimeWorldBridge.tscn"
const OUTPUT_DIR := "user://space_syndicate_design_qa/monster_runtime_characterization/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/monster_runtime_hard_cutover_sprint_45.png"
const RULESET_ID := "v0.4"
const CASE_COUNT := 53
const TARGET_WEIGHT_FOCUSED_CASES := [
	"alive_target_has_positive_weight",
	"special_target_factors_are_positive",
	"public_target_factor_summary_is_safe",
]
const FIXED_SEED := 440044
const BASELINE_MAIN_SHA256 := "46eb1f21e1d8182d78d16af4858eb3b90081da2c9644b50f81594469a667cc99"
const BASELINE_MAIN_METRICS := {
	"total_lines": 31788,
	"nonblank_lines": 28518,
	"function_count": 1583,
	"top_level_variable_count": 164,
	"constant_count": 276,
}

@export var auto_run := true

@onready var runtime_main_host: Control = %RuntimeMainHost
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var cases_text: RichTextLabel = %CasesText

var _runtime_main: Control
var _runtime_monsters: MonsterRuntimeController
var _baseline_players: Array = []
var _baseline_districts: Array = []
var _records: Array = []
var _failures: Array[String] = []
var _main_source := ""
var _controller_source := ""


func _ready() -> void:
	print("MonsterRuntimeCharacterizationBench ready: auto_run=%s editor_hint=%s" % [auto_run, Engine.is_editor_hint()])
	if auto_run and not Engine.is_editor_hint():
		if OS.get_cmdline_args().has("--target-weight-focused"):
			call_deferred("run_target_weight_focused_suite")
		else:
			call_deferred("run_characterization_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func characterization_cases() -> Array:
	return [
		"monster_call_graph_complete",
		"production_main_cutover_delta",
		"runtime_monster_catalog_exists",
		"actor_creation_shape",
		"actor_owner_hidden_initially",
		"first_summon_free_placement",
		"control_limit_rejects_second_bound_monster",
		"same_family_upgrade_restores_state",
		"rank_iv_card_refreshes_without_rank_five",
		"duration_decrements_in_realtime",
		"duration_expiry_removes_even_when_down",
		"removal_resequences_slots_and_selection",
		"active_count_excludes_down",
		"action_table_and_rank_weights",
		"destroyed_district_excluded_from_target_candidates",
		"target_weight_fact_breakdown",
		"alive_target_has_positive_weight",
		"special_target_factors_are_positive",
		"public_target_factor_summary_is_safe",
		"fixed_seed_target_is_deterministic",
		"target_pick_shared_rng_sequence",
		"lure_overrides_target_once",
		"movement_mode_and_terrain_multiplier",
		"movement_starts_linear_not_teleport",
		"movement_arrival_updates_position_and_clears_motion",
		"flight_has_no_trample_damage",
		"attack_out_of_range_is_atomic",
		"armor_absorbs_before_hp",
		"lethal_damage_marks_down",
		"owner_damage_cash_reveal_sequence",
		"nearest_monster_encounter_opens_wager_before_damage",
		"wager_freezes_planet_simulation",
		"wager_uses_v04_20_30_timing",
		"wager_carries_public_bid_pool_once",
		"wager_percentage_and_public_bet_contract",
		"wager_timeout_refunds_no_damage_and_retains_pool",
		"current_monster_save_shape",
		"monster_save_restore_and_legacy_defaults",
		"public_marker_and_report_privacy_boundary",
		"sprint45_deletion_candidates_complete",
		"controller_scene_composition",
		"world_bridge_scene_composition",
		"coordinator_static_instances",
		"controller_api_contract",
		"controller_state_owner",
		"main_runtime_algorithms_absent",
		"main_legacy_state_fields_absent",
		"main_dynamic_compatibility_routes_to_controller",
		"ai_monster_route_uses_controller",
		"card_world_bridges_resolve_controller_state",
		"monster_save_owner_cutover",
		"debug_snapshot_privacy_and_pure_data",
		"no_parallel_monster_engine",
	]


func build_characterization_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in characterization_cases():
		records.append(_record(str(case_id_variant), false, false, "preview"))
	return {
		"suite": "monster-runtime-hard-cutover-v04",
		"ruleset_id": RULESET_ID,
		"runtime_owner": CONTROLLER_SCRIPT_PATH,
		"runtime_cutover_enabled": true,
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"case_count": CASE_COUNT,
		"record_count": records.size(),
		"observed_count": 0,
		"aligned_count": 0,
		"needs_design_decision_count": 0,
		"baseline_main_sha256": BASELINE_MAIN_SHA256,
		"baseline_main_metrics": BASELINE_MAIN_METRICS.duplicate(true),
		"records": records,
	}


func run_characterization_suite() -> void:
	_records.clear()
	_failures.clear()
	_main_source = FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	_controller_source = FileAccess.get_file_as_string(CONTROLLER_SCRIPT_PATH)
	_prepare_output_dir()
	if not await _ensure_runtime_main():
		push_error("MonsterRuntimeCharacterizationBench could not instantiate real main.tscn")
		if DisplayServer.get_name() == "headless":
			get_tree().quit(1)
		return
	for case_id_variant in characterization_cases():
		var case_id := str(case_id_variant)
		_reset_fixture()
		var record := _run_case(case_id)
		record["pure_data_checked"] = _is_data_only(record) and not _contains_runtime_object(record)
		record["passed"] = bool(record.get("observed", false)) and bool(record.get("contract_aligned", false)) and bool(record.get("pure_data_checked", false))
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "observation failed"))])
	var metrics := _main_metrics()
	var manifest := {
		"suite": "monster-runtime-hard-cutover-v04",
		"ruleset_id": RULESET_ID,
		"runtime_owner": CONTROLLER_SCRIPT_PATH,
		"runtime_cutover_enabled": true,
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"case_count": CASE_COUNT,
		"record_count": _records.size(),
		"observed_count": _observed_count(),
		"aligned_count": _aligned_count(),
		"mismatch_count": CASE_COUNT - _aligned_count(),
		"needs_design_decision_count": _design_decision_count(),
		"passed_count": _passed_count(),
		"baseline_main_sha256": BASELINE_MAIN_SHA256,
		"current_main_sha256": _main_source.sha256_text(),
		"main_unchanged": false,
		"main_cutover_delta_checked": int(metrics.get("nonblank_lines", 999999)) < int(BASELINE_MAIN_METRICS.get("nonblank_lines", 0)) and int(metrics.get("function_count", 999999)) < int(BASELINE_MAIN_METRICS.get("function_count", 0)),
		"removed_nonblank_lines": int(BASELINE_MAIN_METRICS.get("nonblank_lines", 0)) - int(metrics.get("nonblank_lines", 0)),
		"removed_functions": int(BASELINE_MAIN_METRICS.get("function_count", 0)) - int(metrics.get("function_count", 0)),
		"main_metrics": metrics,
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("MonsterRuntimeCharacterizationBench manifest: %s" % MANIFEST_PATH)
	print("MonsterRuntimeCharacterizationBench report: %s" % REPORT_PATH)
	print("MonsterRuntimeCharacterizationBench screenshot: %s" % SCREENSHOT_PATH)
	print("MonsterRuntimeCharacterizationBench observed: %d/%d" % [_observed_count(), CASE_COUNT])
	print("MonsterRuntimeCharacterizationBench aligned: %d/%d; mismatches=%d; design_decisions=%d" % [_aligned_count(), CASE_COUNT, CASE_COUNT - _aligned_count(), _design_decision_count()])
	print("MonsterRuntimeCharacterizationBench hard cutover: %s removed_nonblank=%d removed_functions=%d sha=%s" % [str(bool(manifest.get("main_cutover_delta_checked", false))), int(manifest.get("removed_nonblank_lines", 0)), int(manifest.get("removed_functions", 0)), str(manifest.get("current_main_sha256", ""))])
	if not _failures.is_empty():
		push_error("MonsterRuntimeCharacterizationBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		_release_runtime_main()
		for _frame in range(4):
			await get_tree().process_frame
		get_tree().quit(0 if _failures.is_empty() else 1)


func run_suite() -> void:
	run_characterization_suite()


func run_target_weight_focused_suite() -> void:
	_records.clear()
	_failures.clear()
	if not await _ensure_runtime_main():
		push_error("Monster target-weight focused bench could not instantiate real main.tscn")
		get_tree().quit(1)
		return
	for case_id in TARGET_WEIGHT_FOCUSED_CASES:
		_reset_fixture()
		var record := _run_case(case_id)
		record["pure_data_checked"] = _is_data_only(record) and not _contains_runtime_object(record)
		record["passed"] = bool(record.get("observed", false)) and bool(record.get("contract_aligned", false)) and bool(record.get("pure_data_checked", false))
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "observation failed"))])
	var passed := _passed_count()
	print("MONSTER_TARGET_WEIGHT_FOCUSED_TEST %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", passed, TARGET_WEIGHT_FOCUSED_CASES.size()])
	if not _failures.is_empty():
		push_error("Monster target-weight focused bench failed:\n- %s" % "\n- ".join(_failures))
	_release_runtime_main()
	for _frame in range(4):
		await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _run_case(case_id: String) -> Dictionary:
	match case_id:
		"monster_call_graph_complete":
			return _case_monster_call_graph_complete()
		"production_main_cutover_delta":
			return _case_production_main_cutover_delta()
		"runtime_monster_catalog_exists":
			return _case_runtime_monster_catalog_exists()
		"actor_creation_shape":
			return _case_actor_creation_shape()
		"actor_owner_hidden_initially":
			return _case_actor_owner_hidden_initially()
		"first_summon_free_placement":
			return _case_first_summon_free_placement()
		"control_limit_rejects_second_bound_monster":
			return _case_control_limit_rejects_second_bound_monster()
		"same_family_upgrade_restores_state":
			return _case_same_family_upgrade_restores_state()
		"rank_iv_card_refreshes_without_rank_five":
			return _case_rank_iv_card_refreshes_without_rank_five()
		"duration_decrements_in_realtime":
			return _case_duration_decrements_in_realtime()
		"duration_expiry_removes_even_when_down":
			return _case_duration_expiry_removes_even_when_down()
		"removal_resequences_slots_and_selection":
			return _case_removal_resequences_slots_and_selection()
		"active_count_excludes_down":
			return _case_active_count_excludes_down()
		"action_table_and_rank_weights":
			return _case_action_table_and_rank_weights()
		"destroyed_district_excluded_from_target_candidates":
			return _case_destroyed_district_excluded_from_target_candidates()
		"target_weight_fact_breakdown":
			return _case_target_weight_fact_breakdown()
		"alive_target_has_positive_weight":
			return _case_alive_target_has_positive_weight()
		"special_target_factors_are_positive":
			return _case_special_target_factors_are_positive()
		"public_target_factor_summary_is_safe":
			return _case_public_target_factor_summary_is_safe()
		"fixed_seed_target_is_deterministic":
			return _case_fixed_seed_target_is_deterministic()
		"target_pick_shared_rng_sequence":
			return _case_target_pick_shared_rng_sequence()
		"lure_overrides_target_once":
			return _case_lure_overrides_target_once()
		"movement_mode_and_terrain_multiplier":
			return _case_movement_mode_and_terrain_multiplier()
		"movement_starts_linear_not_teleport":
			return _case_movement_starts_linear_not_teleport()
		"movement_arrival_updates_position_and_clears_motion":
			return _case_movement_arrival_updates_position_and_clears_motion()
		"flight_has_no_trample_damage":
			return _case_flight_has_no_trample_damage()
		"attack_out_of_range_is_atomic":
			return _case_attack_out_of_range_is_atomic()
		"armor_absorbs_before_hp":
			return _case_armor_absorbs_before_hp()
		"lethal_damage_marks_down":
			return _case_lethal_damage_marks_down()
		"owner_damage_cash_reveal_sequence":
			return _case_owner_damage_cash_reveal_sequence()
		"nearest_monster_encounter_opens_wager_before_damage":
			return _case_nearest_monster_encounter_opens_wager_before_damage()
		"wager_freezes_planet_simulation":
			return _case_wager_freezes_planet_simulation()
		"wager_uses_v04_20_30_timing":
			return _case_wager_uses_v04_20_30_timing()
		"wager_carries_public_bid_pool_once":
			return _case_wager_carries_public_bid_pool_once()
		"wager_percentage_and_public_bet_contract":
			return _case_wager_percentage_and_public_bet_contract()
		"wager_timeout_refunds_no_damage_and_retains_pool":
			return _case_wager_timeout_refunds_no_damage_and_retains_pool()
		"current_monster_save_shape":
			return _case_current_monster_save_shape()
		"monster_save_restore_and_legacy_defaults":
			return _case_monster_save_restore_and_legacy_defaults()
		"public_marker_and_report_privacy_boundary":
			return _case_public_marker_and_report_privacy_boundary()
		"sprint45_deletion_candidates_complete":
			return _case_sprint45_deletion_candidates_complete()
		"controller_scene_composition":
			return _case_controller_scene_composition()
		"world_bridge_scene_composition":
			return _case_world_bridge_scene_composition()
		"coordinator_static_instances":
			return _case_coordinator_static_instances()
		"controller_api_contract":
			return _case_controller_api_contract()
		"controller_state_owner":
			return _case_controller_state_owner()
		"main_runtime_algorithms_absent":
			return _case_main_runtime_algorithms_absent()
		"main_legacy_state_fields_absent":
			return _case_main_legacy_state_fields_absent()
		"main_dynamic_compatibility_routes_to_controller":
			return _case_main_dynamic_compatibility_routes_to_controller()
		"ai_monster_route_uses_controller":
			return _case_ai_monster_route_uses_controller()
		"card_world_bridges_resolve_controller_state":
			return _case_card_world_bridges_resolve_controller_state()
		"monster_save_owner_cutover":
			return _case_monster_save_owner_cutover()
		"debug_snapshot_privacy_and_pure_data":
			return _case_debug_snapshot_privacy_and_pure_data()
		"no_parallel_monster_engine":
			return _case_no_parallel_monster_engine()
	return _record(case_id, false, false, "Unknown characterization case.")


func _case_monster_call_graph_complete() -> Dictionary:
	var controller_required := [
		"_make_auto_monster", "_summon_monster_from_card", "_upgrade_field_monster_from_card",
		"_update_auto_monster_durations", "_auto_monster_movement_tick", "_update_auto_monster_linear_movement",
		"_auto_special_monster_tick_for_slot", "_weighted_auto_monster_target", "_auto_monster_take_damage",
		"_open_monster_wager_for_pair", "_place_monster_wager", "_settle_monster_wager_at_index",
	]
	var missing: Array = []
	for function_name in controller_required:
		if not _controller_source.contains("func %s(" % str(function_name)):
			missing.append(function_name)
	var main_adapters := _main_source.contains("func _capture_run_state(") and _main_source.contains("func _apply_run_domain_state_compatibility_adapter(") and _main_source.contains("func _monster_runtime_controller_node(")
	var observed := missing.is_empty() and main_adapters and _controller_source.contains("var auto_monsters: Array = []") and _controller_source.contains("var active_monster_wagers: Array = []")
	return _record("monster_call_graph_complete", observed, observed, "Controller owns lifecycle entry points while main keeps only save/world adapters; missing=%s." % str(missing), {"call_graph_checked": true})


func _case_production_main_cutover_delta() -> Dictionary:
	var metrics := _main_metrics()
	var removed_lines := int(BASELINE_MAIN_METRICS.get("nonblank_lines", 0)) - int(metrics.get("nonblank_lines", 0))
	var removed_functions := int(BASELINE_MAIN_METRICS.get("function_count", 0)) - int(metrics.get("function_count", 0))
	var aligned := _main_source.sha256_text() != BASELINE_MAIN_SHA256 and removed_lines >= 1800 and removed_functions >= 100
	return _record("production_main_cutover_delta", true, aligned, "Hard cutover removed %d nonblank lines and %d functions from main.gd." % [removed_lines, removed_functions], {"call_graph_checked": true})


func _case_runtime_monster_catalog_exists() -> Dictionary:
	var count := int(_runtime_monsters.call("_catalog_size"))
	var names: Array = []
	var actions_ok := true
	for index in range(count):
		var entry: Dictionary = _runtime_monsters.call("_catalog_entry", index)
		names.append(str(entry.get("name", "")))
		actions_ok = actions_ok and not (_runtime_monsters.call("_catalog_actions", index) as Array).is_empty()
	var aligned := count >= 2 and actions_ok and not names.has("")
	return _record("runtime_monster_catalog_exists", count > 0, aligned, "%d real monster catalog entries expose action tables." % count, {"fixture_id": "catalog", "action_kind": "catalog"})


func _case_actor_creation_shape() -> Dictionary:
	var actor := _make_actor(0, _safe_district(), -1, 1)
	var required := ["uid", "catalog_index", "slot", "rank", "name", "hp", "max_hp", "duration", "remaining_time", "move", "position", "world_position", "down", "owner", "owner_revealed"]
	var aligned := not actor.is_empty()
	for key in required:
		aligned = aligned and actor.has(key)
	aligned = aligned and int(actor.get("hp", 0)) == int(actor.get("max_hp", -1)) and int(actor.get("rank", 0)) == 1
	return _record("actor_creation_shape", not actor.is_empty(), aligned, "A summoned actor starts with one stable world-state envelope.", _actor_metrics(actor))


func _case_actor_owner_hidden_initially() -> Dictionary:
	var actor := _make_actor(0, _safe_district(), 0, 1)
	_set_monsters([actor])
	var markers: Array = _runtime_main.call("_auto_monster_markers")
	var marker: Dictionary = markers[0] if not markers.is_empty() and markers[0] is Dictionary else {}
	var aligned := int(actor.get("owner", -1)) == 0 and not bool(actor.get("owner_revealed", true)) and not marker.has("owner") and not marker.has("owner_index")
	return _record("actor_owner_hidden_initially", true, aligned, "Binding exists in private world state but the public map marker excludes owner fields.", {"fixture_id": "hidden-binding", "privacy_checked": true})


func _case_first_summon_free_placement() -> Dictionary:
	var district_index := _safe_district()
	_runtime_main.set("selected_player", 0)
	_runtime_main.set("selected_district", district_index)
	var skill := _monster_skill(0, 1)
	skill["starter_play_free"] = true
	var accepted := bool(_runtime_monsters.call("_summon_monster_from_card", _player(0), skill))
	var monsters := _monsters()
	var actor: Dictionary = monsters[0] if monsters.size() == 1 else {}
	var aligned := accepted and monsters.size() == 1 and int(actor.get("position", -1)) == district_index and int(actor.get("owner", -1)) == 0 and not bool(actor.get("owner_revealed", true))
	return _record("first_summon_free_placement", accepted, aligned, "The starter_play_free card accepts any intact district and creates a hidden binding.", {"fixture_id": str(skill.get("name", "starter")), "start_district": district_index, "final_district": int(actor.get("position", -1)), "action_kind": "summon"})


func _case_control_limit_rejects_second_bound_monster() -> Dictionary:
	var limit := int(_runtime_monsters.call("_player_monster_control_limit", 0))
	var catalog_size := int(_runtime_monsters.call("_catalog_size"))
	var seeded: Array = []
	for index in range(mini(limit, maxi(0, catalog_size - 1))):
		seeded.append(_make_actor(index, _safe_district(), 0, 1))
	_set_monsters(seeded)
	_runtime_main.set("selected_player", 0)
	_runtime_main.set("selected_district", _safe_district())
	var requested_index := mini(limit, catalog_size - 1)
	var skill := _monster_skill(requested_index, 1)
	skill["starter_play_free"] = true
	var before := _monsters().size()
	var accepted := bool(_runtime_monsters.call("_summon_monster_from_card", _player(0), skill))
	var aligned := limit > 0 and before == limit and not accepted and _monsters().size() == before
	return _record("control_limit_rejects_second_bound_monster", true, aligned, "A different family is rejected atomically after the role's live binding limit is filled.", {"fixture_id": str(skill.get("name", "limit")), "action_kind": "summon_limit"})


func _case_same_family_upgrade_restores_state() -> Dictionary:
	var actor := _make_actor(0, _safe_district(), 0, 1)
	actor["hp"] = 1
	actor["remaining_time"] = 1.0
	actor["owner_revealed"] = true
	actor["owner_clue"] = "qa-clue"
	_set_monsters([actor])
	var accepted := bool(_runtime_monsters.call("_upgrade_field_monster_from_card", 0, _monster_skill(0, 1)))
	var upgraded := _monster(0)
	var aligned := accepted and int(upgraded.get("rank", 0)) == 2 and int(upgraded.get("hp", 0)) == int(upgraded.get("max_hp", -1)) and is_equal_approx(float(upgraded.get("remaining_time", 0.0)), float(upgraded.get("duration", -1.0))) and bool(upgraded.get("owner_revealed", false)) and str(upgraded.get("owner_clue", "")) == "qa-clue"
	return _record("same_family_upgrade_restores_state", accepted, aligned, "Same-family play increments rank, restores HP/lifetime, and preserves an already revealed binding clue.", _actor_metrics(upgraded).merged({"action_kind": "upgrade"}, true))


func _case_rank_iv_card_refreshes_without_rank_five() -> Dictionary:
	var actor := _make_actor(0, _safe_district(), 0, 4)
	actor["hp"] = 1
	actor["remaining_time"] = 1.0
	_set_monsters([actor])
	var accepted := bool(_runtime_monsters.call("_upgrade_field_monster_from_card", 0, _monster_skill(0, 4)))
	var refreshed := _monster(0)
	var aligned := accepted and int(refreshed.get("rank", 0)) == 4 and int(refreshed.get("hp", 0)) == int(refreshed.get("max_hp", -1)) and is_equal_approx(float(refreshed.get("remaining_time", 0.0)), float(refreshed.get("duration", -1.0)))
	return _record("rank_iv_card_refreshes_without_rank_five", accepted, aligned, "A rank-IV duplicate refreshes field state and never creates rank V.", _actor_metrics(refreshed).merged({"action_kind": "refresh"}, true))


func _case_duration_decrements_in_realtime() -> Dictionary:
	var actor := _make_actor(0, _safe_district(), -1, 1)
	actor["remaining_time"] = 10.0
	_set_monsters([actor])
	_runtime_monsters.call("_update_auto_monster_durations", 2.5)
	var remaining := float(_monster(0).get("remaining_time", -1.0))
	var aligned := is_equal_approx(remaining, 7.5)
	return _record("duration_decrements_in_realtime", true, aligned, "Lifetime is reduced by scaled runtime delta.", {"fixture_id": "duration", "lifetime_delta": -2.5})


func _case_duration_expiry_removes_even_when_down() -> Dictionary:
	var actor := _make_actor(0, _safe_district(), -1, 1)
	actor["remaining_time"] = 1.0
	actor["down"] = true
	_set_monsters([actor])
	_runtime_monsters.call("_update_auto_monster_durations", 1.5)
	var aligned := _monsters().is_empty()
	return _record("duration_expiry_removes_even_when_down", true, aligned, "Expired monsters leave whether active or down, matching the current runtime ordering.", {"fixture_id": "down-expiry", "lifetime_delta": -1.0})


func _case_removal_resequences_slots_and_selection() -> Dictionary:
	_set_monsters([_make_actor(0, _safe_district(), -1, 1), _make_actor(1, _other_district(_safe_district()), -1, 1)])
	_runtime_main.set("selected_auto_monster_slot", 1)
	_runtime_monsters.call("_remove_auto_monster", 0, "QA removal")
	var monsters := _monsters()
	var aligned := monsters.size() == 1 and int((monsters[0] as Dictionary).get("slot", -1)) == 0 and int(_runtime_main.get("selected_auto_monster_slot")) == 0
	return _record("removal_resequences_slots_and_selection", true, aligned, "Removal compacts slot indices and repairs current selection.", {"fixture_id": "two-monsters", "action_kind": "remove"})


func _case_active_count_excludes_down() -> Dictionary:
	var active := _make_actor(0, _safe_district(), -1, 1)
	var down := _make_actor(1, _safe_district(), -1, 1)
	down["down"] = true
	_set_monsters([active, down])
	var count := int(_runtime_monsters.call("_active_auto_monster_count"))
	return _record("active_count_excludes_down", true, count == 1, "Down monsters remain in the roster but do not count as active actors.", {"fixture_id": "active-plus-down"})


func _case_action_table_and_rank_weights() -> Dictionary:
	var rank_i := _make_actor(0, _safe_district(), -1, 1)
	var rank_iv := rank_i.duplicate(true)
	rank_iv["rank"] = 4
	var actions: Array = _runtime_monsters.call("_auto_monster_actions", rank_i)
	var weights_i: Array = _runtime_monsters.call("_auto_monster_action_weights", rank_i, false)
	var weights_iv: Array = _runtime_monsters.call("_auto_monster_action_weights", rank_iv, false)
	var not_lower := weights_i.size() == weights_iv.size()
	var increased := false
	for index in range(mini(weights_i.size(), weights_iv.size())):
		not_lower = not_lower and int(weights_iv[index]) >= int(weights_i[index])
		increased = increased or int(weights_iv[index]) > int(weights_i[index])
	var aligned := not actions.is_empty() and actions.size() == weights_i.size() and not_lower and increased
	return _record("action_table_and_rank_weights", not actions.is_empty(), aligned, "Rank escalation preserves the action table and raises, rather than lowers, high-rank weights.", {"fixture_id": str(rank_i.get("name", "monster")), "action_kind": "action_table"})


func _case_destroyed_district_excluded_from_target_candidates() -> Dictionary:
	var excluded := _safe_district()
	var districts := (_runtime_main.get("districts") as Array).duplicate(true)
	districts[excluded]["destroyed"] = true
	_runtime_main.set("districts", districts)
	var candidates: Array = _runtime_monsters.call("_auto_monster_target_candidates", _make_actor(0, _other_district(excluded), -1, 1))
	var absent := true
	for candidate_variant in candidates:
		if candidate_variant is Dictionary and int((candidate_variant as Dictionary).get("index", -1)) == excluded:
			absent = false
	return _record("destroyed_district_excluded_from_target_candidates", true, absent, "Destroyed districts have zero target weight and are absent from weighted candidates.", {"fixture_id": "destroyed-target", "target_district": excluded})


func _case_target_weight_fact_breakdown() -> Dictionary:
	var district_index := _safe_district()
	var actor := _make_actor(0, district_index, -1, 1)
	var parts: Dictionary = _runtime_monsters.call("_auto_monster_target_weight_parts", actor, district_index)
	var total := 0
	for value in parts.values():
		total += int(value)
	var weight := int(_runtime_monsters.call("_auto_monster_target_weight", actor, district_index))
	var required := ["base", "city", "competition", "warehouse", "resource", "distance", "miasma", "monster"]
	var aligned := weight == maxi(1, total)
	for key in required:
		aligned = aligned and parts.has(key)
	return _record("target_weight_fact_breakdown", true, aligned, "Target score is the visible sum of map pressure factors with a minimum live weight of one.", {"fixture_id": "target-facts", "target_district": district_index, "action_kind": "target_score"})


func _case_alive_target_has_positive_weight() -> Dictionary:
	var actor := _make_actor(0, _safe_district(), -1, 1)
	var candidates: Array = _runtime_monsters.call("_auto_monster_target_candidates", actor)
	var positive_alive_target := false
	var target_district := -1
	var districts: Array = _runtime_main.get("districts") as Array
	for candidate_variant: Variant in candidates:
		if not (candidate_variant is Dictionary):
			continue
		var candidate := candidate_variant as Dictionary
		var index := int(candidate.get("index", -1))
		if index < 0 or index >= districts.size() or not (districts[index] is Dictionary):
			continue
		if not bool((districts[index] as Dictionary).get("destroyed", false)) and int(candidate.get("weight", 0)) > 0:
			positive_alive_target = true
			target_district = index
			break
	return _record("alive_target_has_positive_weight", true, positive_alive_target, "The Monster owner always exposes at least one strictly positive weighted target while a live district exists.", {"fixture_id": "alive-target-weight", "target_district": target_district, "action_kind": "target_score"})


func _case_special_target_factors_are_positive() -> Dictionary:
	var fixture := _prepare_public_target_factor_fixture()
	var actor := fixture.get("actor", {}) as Dictionary
	var district_index := int(fixture.get("district_index", -1))
	var parts: Dictionary = _runtime_monsters.call("_auto_monster_target_weight_parts", actor, district_index, _runtime_monsters.auto_monsters)
	var special_parts := ["city", "competition", "warehouse", "resource", "miasma", "monster"]
	var missing: Array[String] = []
	for part_name in special_parts:
		if int(parts.get(part_name, 0)) <= 0:
			missing.append(part_name)
	return _record("special_target_factors_are_positive", true, missing.is_empty(), "Each special attraction factor is strictly positive in its explicit public-world fixture.", {"fixture_id": "special-target-factors", "target_district": district_index, "action_kind": "target_score", "risk": "Missing positive factors: %s" % ",".join(missing) if not missing.is_empty() else ""})


func _case_public_target_factor_summary_is_safe() -> Dictionary:
	var fixture := _prepare_public_target_factor_fixture()
	var district_index := int(fixture.get("district_index", -1))
	var snapshot := _runtime_monsters.region_attraction_public_snapshot_v06(district_index)
	var entries: Array = snapshot.get("entries", []) as Array
	var allowed_top_level := ["available", "contract_version", "region_index", "entries", "reason_code"]
	var allowed_entry_keys := ["ordinal", "name", "factor_codes", "reason"]
	var special_codes := ["city", "competition", "warehouse", "resource", "miasma", "other_monster"]
	var schema_safe := bool(snapshot.get("available", false)) and not entries.is_empty()
	for key_variant: Variant in snapshot.keys():
		schema_safe = schema_safe and allowed_top_level.has(str(key_variant))
	var surfaced_special := false
	for entry_variant: Variant in entries:
		if not (entry_variant is Dictionary):
			schema_safe = false
			continue
		var entry := entry_variant as Dictionary
		for key_variant: Variant in entry.keys():
			schema_safe = schema_safe and allowed_entry_keys.has(str(key_variant))
		for code_variant: Variant in entry.get("factor_codes", []):
			surfaced_special = surfaced_special or special_codes.has(str(code_variant))
	var public_text := var_to_str(snapshot).to_lower()
	var forbidden_tokens := ["weight", "probability", "numerator", "denominator", "owner", "player_index", "权重", "%", "+n"]
	var privacy_safe := true
	for token in forbidden_tokens:
		privacy_safe = privacy_safe and not public_text.contains(token)
	var aligned := schema_safe and surfaced_special and privacy_safe
	return _record("public_target_factor_summary_is_safe", true, aligned, "The public attraction summary names a special factor without exposing raw weights, probabilities, or private ownership.", {"fixture_id": "public-target-summary", "target_district": district_index, "action_kind": "public_attraction", "privacy_checked": true})


func _case_fixed_seed_target_is_deterministic() -> Dictionary:
	var random := _runtime_rng()
	var actor := _make_actor(0, _safe_district(), -1, 1)
	random.seed = FIXED_SEED
	var first := int(_runtime_monsters.call("_weighted_auto_monster_target", actor))
	var first_state := random.state
	random.seed = FIXED_SEED
	var second := int(_runtime_monsters.call("_weighted_auto_monster_target", actor))
	var second_state := random.state
	var aligned := first >= 0 and first == second and first_state == second_state
	return _record("fixed_seed_target_is_deterministic", true, aligned, "The same world snapshot and shared seed produce the same target and RNG state.", {"fixture_id": "seed-%d" % FIXED_SEED, "target_district": first, "rng_checked": true})


func _case_target_pick_shared_rng_sequence() -> Dictionary:
	var random := _runtime_rng()
	var actor := _make_actor(0, _safe_district(), -1, 1)
	random.seed = FIXED_SEED + 1
	var target_a := int(_runtime_monsters.call("_weighted_auto_monster_target", actor))
	var next_a := random.randi()
	random.seed = FIXED_SEED + 1
	var target_b := int(_runtime_monsters.call("_weighted_auto_monster_target", actor))
	var next_b := random.randi()
	var aligned := target_a == target_b and next_a == next_b
	return _record("target_pick_shared_rng_sequence", true, aligned, "Target selection consumes the existing shared RNG sequence; no second monster RNG exists.", {"fixture_id": "shared-rng", "target_district": target_a, "rng_checked": true})


func _case_lure_overrides_target_once() -> Dictionary:
	var target := _other_district(_safe_district())
	var actor := _make_actor(0, _safe_district(), -1, 1)
	actor["lure_target_district"] = target
	actor["lure_moves_left"] = 1
	actor["lure_source"] = "qa"
	var selected := int(_runtime_monsters.call("_auto_monster_lure_target", actor))
	var consumed: Dictionary = _runtime_monsters.call("_consume_auto_monster_lure", actor)
	var aligned := selected == target and not consumed.has("lure_target_district") and not consumed.has("lure_moves_left") and not consumed.has("lure_source")
	return _record("lure_overrides_target_once", true, aligned, "A one-move lure supplies one explicit target and erases its private control fields after consumption.", {"fixture_id": "one-shot-lure", "target_district": target, "action_kind": "lure"})


func _case_movement_mode_and_terrain_multiplier() -> Dictionary:
	var district_index := _safe_district()
	var flying := _make_actor(0, district_index, -1, 1)
	flying["movement_traits"] = ["flying"]
	var aquatic := flying.duplicate(true)
	aquatic["movement_traits"] = ["aquatic"]
	var walker := flying.duplicate(true)
	walker["movement_traits"] = []
	walker["terrain_move_multiplier"] = {"default": 1.0, str((_runtime_main.get("districts") as Array)[district_index].get("terrain", "land")): 1.5}
	var multiplier := float(_runtime_monsters.call("_monster_terrain_move_multiplier", walker, district_index))
	var aligned := str(_runtime_monsters.call("_auto_monster_movement_mode", flying)) == "fly" and str(_runtime_monsters.call("_auto_monster_movement_mode", aquatic)) == "aquatic" and str(_runtime_monsters.call("_auto_monster_movement_mode", walker)) == "walk" and is_equal_approx(multiplier, 1.5)
	return _record("movement_mode_and_terrain_multiplier", true, aligned, "Movement mode follows ecology traits and terrain speed uses the actor's authored multiplier.", {"fixture_id": "movement-ecology", "action_kind": "movement"})


func _case_movement_starts_linear_not_teleport() -> Dictionary:
	var start := _safe_district()
	var target := _other_district(start)
	var actor := _make_actor(0, start, -1, 1)
	actor["lure_target_district"] = target
	actor["lure_moves_left"] = 1
	actor["lure_source"] = "qa"
	_set_monsters([actor])
	_runtime_monsters.call("_auto_monster_movement_tick")
	var moved := _monster(0)
	var aligned := int(moved.get("position", -1)) == start and moved.has("linear_move_target_position") and float(moved.get("linear_move_speed_mps", 0.0)) > 0.0 and not moved.has("lure_target_district")
	return _record("movement_starts_linear_not_teleport", true, aligned, "Automatic movement creates a time-based linear motion envelope while district ownership remains at the origin until arrival.", {"fixture_id": "linear-start", "start_district": start, "target_district": target, "final_district": int(moved.get("position", -1)), "action_kind": "move_start", "rng_checked": true})


func _case_movement_arrival_updates_position_and_clears_motion() -> Dictionary:
	var start := _safe_district()
	var target := _other_district(start)
	var actor := _make_actor(0, start, -1, 1)
	actor["movement_traits"] = ["flying"]
	var distance := float(_runtime_monsters.call("_start_entity_linear_motion", actor, _runtime_monsters.call("_district_center", target), 1000.0, "QA arrival", "fly", -1.0, "auto_move"))
	var projected_target := int(actor.get("linear_move_target_district", target))
	_set_monsters([actor])
	_runtime_monsters.call("_update_auto_monster_linear_movement", maxf(1.0, distance / 1000.0 + 1.0))
	var arrived := _monster(0)
	var aligned := distance > 0.5 and int(arrived.get("position", -1)) == projected_target and not arrived.has("linear_move_target_position") and not arrived.has("linear_move_speed_mps")
	return _record("movement_arrival_updates_position_and_clears_motion", true, aligned, "Arrival commits the projection-resolved destination district, runs arrival hooks, and clears transient movement state.", {"fixture_id": "linear-arrival", "start_district": start, "target_district": projected_target, "final_district": int(arrived.get("position", -1)), "action_kind": "move_arrive"})


func _case_flight_has_no_trample_damage() -> Dictionary:
	var actor := _make_actor(0, _safe_district(), -1, 1)
	actor["movement_traits"] = ["flying"]
	actor["move_damage"] = 99
	var damage := int(_runtime_monsters.call("_auto_monster_move_damage", actor, "fly"))
	return _record("flight_has_no_trample_damage", true, damage == 0, "Flying movement explicitly suppresses ordinary trample damage.", {"fixture_id": "flying", "action_kind": "move", "damage_delta": 0})


func _case_attack_out_of_range_is_atomic() -> Dictionary:
	var start := _safe_district()
	var target_district := _other_district(start)
	var actor := _qa_combat_actor(0, start, "QA Attacker", -1)
	var target := _qa_combat_actor(1, target_district, "QA Target", -1)
	_set_monsters([actor, target])
	var hp_before := int(target.get("hp", 0))
	var accepted := bool(_runtime_monsters.call("_auto_monster_use_action_on_other", 0, 1, {"name": "QA short attack", "damage": 5, "range": 0.1}, "QA", false))
	var aligned := not accepted and int(_monster(1).get("hp", -1)) == hp_before and (_runtime_main.get("active_monster_wagers") as Array).is_empty()
	return _record("attack_out_of_range_is_atomic", true, aligned, "An out-of-range attack changes neither HP nor wager state.", {"fixture_id": "range-reject", "start_district": start, "target_district": target_district, "action_kind": "attack_reject"})


func _case_armor_absorbs_before_hp() -> Dictionary:
	var district_index := _safe_district()
	var actor := _qa_combat_actor(0, district_index, "QA Attacker", -1)
	var target := _qa_combat_actor(1, district_index, "QA Armored", -1)
	target["hp"] = 10
	target["max_hp"] = 10
	target["armor"] = 2
	_set_monsters([actor, target])
	var accepted := bool(_runtime_monsters.call("_auto_monster_use_action_on_other", 0, 1, {"name": "QA impact", "damage": 5, "range": 100.0}, "QA", false))
	var after := _monster(1)
	var aligned := accepted and int(after.get("armor", -1)) == 0 and int(after.get("hp", -1)) == 7
	return _record("armor_absorbs_before_hp", accepted, aligned, "Armor is consumed before the remaining damage reaches HP.", {"fixture_id": "armor-two", "action_kind": "attack", "damage_delta": -3})


func _case_lethal_damage_marks_down() -> Dictionary:
	var district_index := _safe_district()
	var actor := _qa_combat_actor(0, district_index, "QA Attacker", -1)
	var target := _qa_combat_actor(1, district_index, "QA Non-Reviver", -1)
	target["hp"] = 2
	target["max_hp"] = 2
	_set_monsters([actor, target])
	var dealt := int(_runtime_monsters.call("_auto_monster_take_damage", 1, 8, "QA lethal", 0))
	var after := _monster(1)
	var aligned := dealt == 2 and int(after.get("hp", -1)) == 0 and bool(after.get("down", false))
	return _record("lethal_damage_marks_down", true, aligned, "Non-revival monsters remain in the roster as down and stop automatic action.", {"fixture_id": "lethal", "action_kind": "damage", "damage_delta": -dealt})


func _case_owner_damage_cash_reveal_sequence() -> Dictionary:
	var district_index := _safe_district()
	var target := _qa_combat_actor(0, district_index, "QA Bound Monster", 0)
	target["hp"] = 100
	target["max_hp"] = 100
	target["owner_damage_cash_total"] = 100
	target["owner_damage_cash_pool"] = 100
	target["owner_damage_cash_lost"] = 0
	_set_monsters([target])
	_set_player_cash(0, 1000)
	var dealt := int(_runtime_monsters.call("_auto_monster_take_damage", 0, 10, "QA clue", -1))
	var after := _monster(0)
	var cash_delta := _player_cash(0) - 1000
	var aligned := dealt == 10 and cash_delta == -10 and bool(after.get("owner_revealed", false)) and int(after.get("owner_damage_cash_lost", 0)) == 10 and not str(after.get("owner_clue", "")).is_empty()
	return _record("owner_damage_cash_reveal_sequence", true, aligned, "HP damage first computes the capped binding cash loss, then records the public ownership clue.", {"fixture_id": "owner-clue", "action_kind": "damage_clue", "damage_delta": -dealt, "cash_delta": cash_delta, "privacy_checked": true})


func _case_nearest_monster_encounter_opens_wager_before_damage() -> Dictionary:
	_prepare_wager_pair(0)
	var hp_before := int(_monster(1).get("hp", 0))
	var accepted := bool(_runtime_monsters.call("_auto_monster_use_action_on_other", 0, 1, {"name": "QA collision", "damage": 4, "range": 100.0}, "QA encounter", true))
	var wagers: Array = _runtime_main.get("active_monster_wagers") as Array
	var pending_attack: Dictionary = (wagers[0] as Dictionary).get("pending_attack", {}) if wagers.size() == 1 else {}
	var aligned: bool = accepted and wagers.size() == 1 and int(_monster(1).get("hp", -1)) == hp_before and not pending_attack.is_empty()
	return _record("nearest_monster_encounter_opens_wager_before_damage", accepted, aligned, "A valid encounter opens the forced wager before resolving its pending attack.", {"fixture_id": "encounter", "action_kind": "wager_open", "wager_count_delta": wagers.size()})


func _case_wager_freezes_planet_simulation() -> Dictionary:
	var wager_id := _open_qa_wager(0)
	var freezes := bool(_runtime_monsters.call("_monster_wager_freezes_game"))
	return _record("wager_freezes_planet_simulation", wager_id > 0, wager_id > 0 and freezes, "An unresolved monster wager is the explicit planet-simulation freeze owner.", {"fixture_id": "wager-%d" % wager_id, "action_kind": "wager_freeze", "wager_count_delta": 1})


func _case_wager_uses_v04_20_30_timing() -> Dictionary:
	var wager_id := _open_qa_wager(0)
	var entry := _active_wager()
	var default_seconds := float(entry.get("seconds_total", 0.0))
	var remaining := float(entry.get("remaining_seconds", 0.0))
	var max_seconds := float(_runtime_monsters.call("_ruleset_timing_seconds", &"monster_wager_max_seconds"))
	var aligned := wager_id > 0 and is_equal_approx(default_seconds, 20.0) and is_equal_approx(remaining, 20.0) and is_equal_approx(max_seconds, 30.0)
	return _record("wager_uses_v04_20_30_timing", wager_id > 0, aligned, "The live Ruleset bridge supplies 20 seconds by default and a 30-second maximum capability.", {"fixture_id": "wager-timing", "action_kind": "wager_timing"})


func _case_wager_carries_public_bid_pool_once() -> Dictionary:
	var wager_id := _open_qa_wager(123)
	var entry := _active_wager()
	var aligned := wager_id > 0 and int(entry.get("public_card_bid_pool", -1)) == 123 and int(_runtime_main.get("public_card_bid_monster_wager_pool")) == 0
	return _record("wager_carries_public_bid_pool_once", wager_id > 0, aligned, "Opening transfers the accumulated public card-bid pool into exactly one wager.", {"fixture_id": "pool-123", "action_kind": "wager_pool", "cash_delta": 0})


func _case_wager_percentage_and_public_bet_contract() -> Dictionary:
	var wager_id := _open_qa_wager(0)
	var entry := _active_wager()
	var competitors: Array = _runtime_monsters.call("_monster_wager_competitors", entry)
	var side := str((competitors[0] as Dictionary).get("side", "")) if not competitors.is_empty() else ""
	var base_percent := int(_runtime_monsters.call("_monster_wager_base_percent", entry))
	var options: Array = _runtime_monsters.call("_monster_wager_percent_options", entry)
	var cash_before := _player_cash(0)
	var accepted := bool(_runtime_monsters.call("_place_monster_wager_percent", wager_id, side, base_percent, 0, false, {}))
	var after_entry := _active_wager()
	var public_bets: Array = after_entry.get("public_bets", []) if after_entry.get("public_bets", []) is Array else []
	var bet: Dictionary = public_bets[0] if not public_bets.is_empty() and public_bets[0] is Dictionary else {}
	var stake := int(bet.get("stake", 0))
	var aligned := accepted and base_percent >= 5 and base_percent <= 10 and options.size() <= 6 and int(options[0]) == base_percent and int(options[options.size() - 1]) <= base_percent + 5 and int(bet.get("player_index", -1)) == 0 and str(bet.get("side", "")) == side and int(bet.get("stake_percent", 0)) == base_percent and _player_cash(0) == cash_before - stake
	return _record("wager_percentage_and_public_bet_contract", accepted, aligned, "Wager identity, side, percentage, and amount are public; the hidden monster binding is not part of that payload.", {"fixture_id": "public-bet", "action_kind": "wager_bet", "cash_delta": -stake, "privacy_checked": true})


func _case_wager_timeout_refunds_no_damage_and_retains_pool() -> Dictionary:
	var wager_id := _open_qa_wager(123)
	var cash_before: Array = []
	for index in range((_runtime_main.get("players") as Array).size()):
		cash_before.append(_player_cash(index))
	_runtime_monsters.call("_force_monster_wager_missing_bets", wager_id, "QA timeout")
	var cash_restored := true
	for index in range(cash_before.size()):
		cash_restored = cash_restored and _player_cash(index) == int(cash_before[index])
	var history: Array = _runtime_main.get("resolved_monster_wager_history") as Array
	var resolved: Dictionary = history[history.size() - 1] if not history.is_empty() else {}
	var aligned := (_runtime_main.get("active_monster_wagers") as Array).is_empty() and cash_restored and int(_runtime_main.get("public_card_bid_monster_wager_pool")) == 123 and (resolved.get("winner_sides", []) as Array).is_empty() and int(resolved.get("public_card_bid_pool_retained", 0)) == 123
	return _record("wager_timeout_refunds_no_damage_and_retains_pool", not history.is_empty(), aligned, "A no-damage/tied forced decision refunds every player stake and carries only the existing public pool forward.", {"fixture_id": "timeout-no-damage", "action_kind": "wager_refund", "cash_delta": 0, "privacy_checked": true})


func _case_current_monster_save_shape() -> Dictionary:
	_set_monsters([_make_actor(0, _safe_district(), 0, 2)])
	_runtime_main.set("active_monster_wagers", [])
	var state: Dictionary = _runtime_main.call("_capture_run_state")
	var required := ["rng_state", "auto_monsters", "next_auto_monster_uid", "next_special_monster_slot", "selected_auto_monster_slot", "special_monster_timer", "monster_timer", "active_monster_wagers", "resolved_monster_wager_history", "monster_wager_sequence", "public_card_bid_monster_wager_pool"]
	var aligned := true
	for key in required:
		aligned = aligned and state.has(key)
	aligned = aligned and (state.get("auto_monsters", []) as Array).size() == 1
	return _record("current_monster_save_shape", true, aligned, "The v1 compatibility envelope retains monster roster, scheduler, selection, wager, public-pool, and shared RNG fields.", {"fixture_id": "save-shape", "save_checked": true, "privacy_checked": true})


func _case_monster_save_restore_and_legacy_defaults() -> Dictionary:
	var actor := _make_actor(0, _safe_district(), 0, 2)
	_set_monsters([actor])
	_runtime_main.set("selected_auto_monster_slot", 0)
	_runtime_main.set("next_special_monster_slot", 0)
	var state: Dictionary = _runtime_main.call("_capture_run_state")
	_runtime_main.set("auto_monsters", [])
	var restore_error := int(_runtime_main.call("_apply_run_domain_state_compatibility_adapter", state))
	var restored := _monster(0)
	var parity := restore_error == OK and int(restored.get("uid", -1)) == int(actor.get("uid", -2)) and str(restored.get("name", "")) == str(actor.get("name", "")) and int(restored.get("rank", 0)) == 2
	var legacy := state.duplicate(true)
	for key in ["auto_monsters", "next_auto_monster_uid", "next_special_monster_slot", "selected_auto_monster_slot", "active_monster_wagers", "resolved_monster_wager_history", "monster_wager_sequence", "public_card_bid_monster_wager_pool"]:
		legacy.erase(key)
	var legacy_error := int(_runtime_main.call("_apply_run_domain_state_compatibility_adapter", legacy))
	var defaults_ok := legacy_error == OK and (_runtime_main.get("auto_monsters") as Array).is_empty() and int(_runtime_main.get("next_auto_monster_uid")) == 1 and (_runtime_main.get("active_monster_wagers") as Array).is_empty() and int(_runtime_main.get("public_card_bid_monster_wager_pool")) == 0
	return _record("monster_save_restore_and_legacy_defaults", true, parity and defaults_ok, "Current saves round-trip private monster state; missing legacy keys normalize to safe empty/default values without advancing a second RNG.", {"fixture_id": "save-roundtrip", "save_checked": true, "rng_checked": true, "privacy_checked": true})


func _case_public_marker_and_report_privacy_boundary() -> Dictionary:
	var actor := _make_actor(0, _safe_district(), 0, 1)
	actor["owner_revealed"] = false
	actor["owner_clue"] = "private qa clue"
	_set_monsters([actor])
	var markers: Array = _runtime_main.call("_auto_monster_markers")
	var marker: Dictionary = markers[0] if not markers.is_empty() and markers[0] is Dictionary else {}
	var forbidden := ["owner", "owner_index", "owner_clue", "hidden_owner", "private_target", "private_discard", "ai_private_plan"]
	var aligned := not marker.is_empty() and _dictionary_excludes_keys(marker, forbidden) and not JSON.stringify(marker).contains(str(_player(0).get("name", "__private__")))
	return _record("public_marker_and_report_privacy_boundary", not marker.is_empty(), aligned, "Public markers and this report expose monster identity/state but never hidden binding, private target, discard, or AI plan.", {"fixture_id": "public-marker", "privacy_checked": true})


func _case_sprint45_deletion_candidates_complete() -> Dictionary:
	var families := {
		"state": ["auto_monsters", "next_auto_monster_uid", "next_special_monster_slot", "selected_auto_monster_slot"],
		"spawn_upgrade": ["_make_auto_monster", "_summon_monster_from_card", "_upgrade_field_monster_from_card"],
		"lifecycle": ["_update_auto_monster_durations", "_remove_auto_monster", "_update_auto_monster_revivals"],
		"target_move": ["_auto_monster_target_weight_parts", "_weighted_auto_monster_target", "_auto_monster_movement_tick", "_update_auto_monster_linear_movement"],
		"combat": ["_auto_monster_use_action_on_other", "_auto_monster_take_damage", "_resolve_auto_monster_encounter"],
		"wager": ["_open_monster_wager_for_pair", "_place_monster_wager", "_settle_monster_wager_at_index"],
		"save": ["auto_monsters", "active_monster_wagers", "resolved_monster_wager_history", "monster_wager_sequence"],
	}
	var missing: Array = []
	var legacy: Array = []
	for family_variant in families.keys():
		for symbol_variant in families[family_variant]:
			var symbol := str(symbol_variant)
			if not _controller_source.contains(symbol):
				missing.append("%s:%s" % [str(family_variant), str(symbol_variant)])
			if symbol.begins_with("_") and _main_source.contains("func %s(" % symbol):
				legacy.append(symbol)
	for state_name in ["auto_monsters", "next_auto_monster_uid", "next_special_monster_slot", "selected_auto_monster_slot", "active_monster_wagers", "resolved_monster_wager_history", "monster_wager_sequence"]:
		if _main_source.contains("var %s" % state_name):
			legacy.append("var %s" % state_name)
	var aligned := missing.is_empty() and legacy.is_empty()
	return _record("sprint45_deletion_candidates_complete", true, aligned, "Controller contains every deletion family and main has no legacy definitions; missing=%s legacy=%s." % [str(missing), str(legacy)], {"fixture_id": "cutover-map", "call_graph_checked": true})


func _case_controller_scene_composition() -> Dictionary:
	var packed := load(CONTROLLER_SCENE_PATH) as PackedScene
	var instance := packed.instantiate() if packed != null else null
	var aligned := instance is MonsterRuntimeController and instance.name == "MonsterRuntimeController"
	if instance != null:
		instance.free()
	return _record("controller_scene_composition", packed != null, aligned, "MonsterRuntimeController is a real editable scene with the runtime script attached.", {"fixture_id": "controller-scene", "call_graph_checked": true})


func _case_world_bridge_scene_composition() -> Dictionary:
	var packed := load(WORLD_BRIDGE_SCENE_PATH) as PackedScene
	var instance := packed.instantiate() if packed != null else null
	var aligned := instance is MonsterRuntimeWorldBridge and instance.name == "MonsterRuntimeWorldBridge"
	if instance != null:
		instance.free()
	return _record("world_bridge_scene_composition", packed != null, aligned, "MonsterRuntimeWorldBridge is scene-owned and exposes no monster rule ownership.", {"fixture_id": "world-bridge", "call_graph_checked": true})


func _case_coordinator_static_instances() -> Dictionary:
	var source := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	var aligned := source.contains("MonsterRuntimeController.tscn") and source.contains("MonsterRuntimeWorldBridge.tscn") and source.contains("[node name=\"MonsterRuntimeController\"") and source.contains("[node name=\"MonsterRuntimeWorldBridge\"")
	return _record("coordinator_static_instances", not source.is_empty(), aligned, "GameRuntimeCoordinator statically composes the controller and bridge; no runtime new() path is needed.", {"fixture_id": "coordinator", "call_graph_checked": true})


func _case_controller_api_contract() -> Dictionary:
	var required := ["configure", "reset_state", "tick_wagers", "tick_motion", "tick_durations", "tick_revivals", "tick_action_timers", "resolve_targeted_skill", "to_save_data", "apply_save_data", "debug_snapshot"]
	var missing: Array = []
	for method_name in required:
		if not _runtime_monsters.has_method(method_name):
			missing.append(method_name)
	var aligned := missing.is_empty()
	return _record("controller_api_contract", true, aligned, "The hard-cutover API covers runtime phases, card targeting, save/load and public debug; missing=%s." % str(missing), {"fixture_id": "controller-api", "call_graph_checked": true})


func _case_controller_state_owner() -> Dictionary:
	var owned := ["auto_monsters", "next_auto_monster_uid", "next_special_monster_slot", "selected_auto_monster_slot", "active_monster_wagers", "resolved_monster_wager_history", "monster_wager_sequence", "public_card_bid_monster_wager_pool", "monster_timer", "special_monster_timer"]
	var missing: Array = []
	for state_name in owned:
		if not _controller_source.contains("var %s" % state_name):
			missing.append(state_name)
	var aligned := missing.is_empty()
	return _record("controller_state_owner", true, aligned, "All roster, cursor, timer and wager fields live on the controller; missing=%s." % str(missing), {"fixture_id": "state-owner", "call_graph_checked": true})


func _case_main_runtime_algorithms_absent() -> Dictionary:
	var retired := ["_make_auto_monster", "_summon_monster_from_card", "_upgrade_field_monster_from_card", "_auto_monster_movement_tick", "_weighted_auto_monster_target", "_auto_monster_take_damage", "_open_monster_wager_for_pair", "_settle_monster_wager_at_index", "_trigger_auto_monster_card_command", "_trigger_bound_monster_skill", "_apply_monster_takeover"]
	var remaining: Array = []
	for method_name in retired:
		if _main_source.contains("func %s(" % method_name):
			remaining.append(method_name)
	var aligned := remaining.is_empty()
	return _record("main_runtime_algorithms_absent", true, aligned, "Retired monster algorithms are absent from main.gd; remaining=%s." % str(remaining), {"fixture_id": "main-deletion", "call_graph_checked": true})


func _case_main_legacy_state_fields_absent() -> Dictionary:
	var retired := ["auto_monsters", "next_auto_monster_uid", "next_special_monster_slot", "selected_auto_monster_slot", "active_monster_wagers", "resolved_monster_wager_history", "monster_wager_sequence", "public_card_bid_monster_wager_pool", "monster_timer", "special_monster_timer"]
	var remaining: Array = []
	for state_name in retired:
		if _main_source.contains("var %s" % state_name):
			remaining.append(state_name)
	var aligned := remaining.is_empty()
	return _record("main_legacy_state_fields_absent", true, aligned, "main.gd has no parallel monster state fields; compatibility get/set routes to the controller.", {"fixture_id": "main-state-deletion", "call_graph_checked": true})


func _case_main_dynamic_compatibility_routes_to_controller() -> Dictionary:
	var actor := _make_actor(0, _safe_district(), -1, 1)
	_runtime_main.set("auto_monsters", [actor])
	var main_value: Array = _runtime_main.get("auto_monsters") as Array
	var controller_value := _runtime_monsters.roster_snapshot(true)
	var aligned := main_value.size() == 1 and controller_value.size() == 1 and int((main_value[0] as Dictionary).get("uid", 0)) == int((controller_value[0] as Dictionary).get("uid", -1))
	return _record("main_dynamic_compatibility_routes_to_controller", true, aligned, "Legacy reflective get/set is a thin compatibility adapter over the single controller state.", {"fixture_id": "compatibility-adapter", "call_graph_checked": true})


func _case_ai_monster_route_uses_controller() -> Dictionary:
	var source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var aligned := source.contains("var _monster_runtime_controller: MonsterRuntimeController") and source.contains("func _call_monster(") and source.contains("return _call_monster(&\"_monster_wager_entry_index_by_id\"") and not source.contains("return _call_world(&\"_monster_wager_entry_index_by_id\"")
	return _record("ai_monster_route_uses_controller", not source.is_empty(), aligned, "AI wager and target helpers call the authoritative monster controller directly.", {"fixture_id": "ai-route", "call_graph_checked": true})


func _case_card_world_bridges_resolve_controller_state() -> Dictionary:
	var eligibility := FileAccess.get_file_as_string("res://scripts/runtime/card_play_eligibility_world_bridge.gd")
	var execution := FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_execution_world_bridge.gd")
	var eligibility_uses_compatibility := eligibility.contains("_array_property(\"auto_monsters\")") and _main_source.contains("&\"auto_monsters\":") and _main_source.contains("return monster_controller.roster_snapshot(true)")
	var execution_uses_controller := execution.contains("func _monster_runtime_controller(") and execution.contains("monster_controller.call(\"roster_snapshot\", true)") and execution.contains("monster_controller.call(\"selected_actor_snapshot\", true)")
	var aligned := eligibility_uses_compatibility and execution_uses_controller
	return _record("card_world_bridges_resolve_controller_state", not eligibility.is_empty() and not execution.is_empty(), aligned, "Eligibility compatibility reads and execution target receipts both resolve the one controller-owned roster without parallel state.", {"fixture_id": "card-bridges", "call_graph_checked": true})


func _case_monster_save_owner_cutover() -> Dictionary:
	var state := _runtime_monsters.to_save_data()
	var required := ["auto_monsters", "next_auto_monster_uid", "next_special_monster_slot", "selected_auto_monster_slot", "active_monster_wagers", "resolved_monster_wager_history", "monster_wager_sequence", "public_card_bid_monster_wager_pool", "monster_timer", "special_monster_timer"]
	var aligned := _main_source.contains("monster_to_save_data") and _main_source.contains("apply_monster_save_data")
	for key in required:
		aligned = aligned and state.has(key)
	return _record("monster_save_owner_cutover", true, aligned, "Controller owns the legacy-compatible monster save envelope; main only merges and applies it through Coordinator.", {"fixture_id": "save-owner", "save_checked": true, "call_graph_checked": true})


func _case_debug_snapshot_privacy_and_pure_data() -> Dictionary:
	var actor := _make_actor(0, _safe_district(), 0, 1)
	actor["owner_clue"] = "private-cutover-clue"
	_set_monsters([actor])
	var snapshot := _runtime_monsters.debug_snapshot(-1)
	var encoded := JSON.stringify(snapshot)
	var aligned := _is_data_only(snapshot) and not _contains_runtime_object(snapshot) and not encoded.contains("private-cutover-clue") and not encoded.contains("\"owner\":") and not bool(snapshot.get("parallel_legacy_owner", true))
	return _record("debug_snapshot_privacy_and_pure_data", true, aligned, "Public controller debug is pure data and omits hidden binding owner/clue and runtime objects.", {"fixture_id": "debug-privacy", "privacy_checked": true})


func _case_no_parallel_monster_engine() -> Dictionary:
	var controllers := _runtime_main.find_children("MonsterRuntimeController", "", true, false)
	var bridges := _runtime_main.find_children("MonsterRuntimeWorldBridge", "", true, false)
	var bridge_snapshot: Dictionary = (bridges[0] as Node).call("debug_snapshot") if bridges.size() == 1 else {}
	var aligned := controllers.size() == 1 and bridges.size() == 1 and not bool(bridge_snapshot.get("owns_monster_state", true)) and not bool(bridge_snapshot.get("owns_targeting", true)) and not bool(bridge_snapshot.get("owns_combat", true)) and not bool(bridge_snapshot.get("owns_wagers", true))
	return _record("no_parallel_monster_engine", true, aligned, "Exactly one controller owns rules; the single bridge owns only world routing.", {"fixture_id": "single-owner", "call_graph_checked": true})


func _ensure_runtime_main() -> bool:
	if _runtime_main != null and is_instance_valid(_runtime_main):
		return true
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return false
	_runtime_main = packed.instantiate() as Control
	if _runtime_main == null:
		return false
	_runtime_main.name = "Main"
	_runtime_main.visible = false
	runtime_main_host.add_child(_runtime_main)
	_hide_runtime_canvas_layers()
	await get_tree().process_frame
	await get_tree().process_frame
	_runtime_main.call("_new_game")
	_runtime_monsters = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterRuntimeController") as MonsterRuntimeController
	_hide_runtime_canvas_layers()
	await get_tree().process_frame
	await get_tree().process_frame
	_runtime_main.set_process(false)
	_baseline_players = (_runtime_main.get("players") as Array).duplicate(true)
	_baseline_districts = (_runtime_main.get("districts") as Array).duplicate(true)
	return _runtime_monsters != null and not _baseline_players.is_empty() and not _baseline_districts.is_empty()


func _reset_fixture() -> void:
	_runtime_main.set_process(false)
	_runtime_main.set("players", _baseline_players.duplicate(true))
	_runtime_main.set("districts", _baseline_districts.duplicate(true))
	_runtime_main.set("auto_monsters", [])
	_runtime_main.set("next_auto_monster_uid", 1)
	_runtime_main.set("next_special_monster_slot", 0)
	_runtime_main.set("selected_auto_monster_slot", 0)
	_runtime_main.set("active_monster_wagers", [])
	_runtime_main.set("resolved_monster_wager_history", [])
	_runtime_main.set("monster_wager_sequence", 0)
	_runtime_main.set("public_card_bid_monster_wager_pool", 0)
	_runtime_main.set("monster_timer", 4.0)
	_runtime_main.set("special_monster_timer", 5.0)
	_runtime_main.set("opening_guide_dismissed", true)
	_runtime_main.set("game_over", false)
	_runtime_main.set("selected_player", 0)
	_runtime_main.set("selected_district", _safe_district())
	_runtime_main.set("movement_trails", [])
	_runtime_main.set("action_callouts", [])
	_runtime_main.set("map_event_effects", [])
	var players := (_runtime_main.get("players") as Array).duplicate(true)
	for index in range(players.size()):
		var player: Dictionary = (players[index] as Dictionary).duplicate(true)
		player["is_ai"] = false
		player["cash"] = 1000
		player["cash_history"] = [1000]
		player["economic_ledger"] = []
		player["eliminated"] = false
		players[index] = player
	_runtime_main.set("players", players)
	_runtime_rng().seed = FIXED_SEED


func _hide_runtime_canvas_layers() -> void:
	for node in _runtime_main.find_children("*", "CanvasLayer", true, false):
		if node is CanvasLayer:
			(node as CanvasLayer).visible = false


func _release_runtime_main() -> void:
	if _runtime_main != null and is_instance_valid(_runtime_main):
		for player_variant in _runtime_main.find_children("*", "AudioStreamPlayer", true, false):
			var player := player_variant as AudioStreamPlayer
			if player != null:
				player.stop()
				player.stream = null
		_runtime_main.queue_free()
	_runtime_main = null
	_runtime_monsters = null


func _runtime_rng() -> RunRngService:
	var runtime_coordinator := _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
	return runtime_coordinator.run_rng_service() if runtime_coordinator != null else null


func _safe_district() -> int:
	var districts: Array = _runtime_main.get("districts") as Array
	for index in range(districts.size()):
		if districts[index] is Dictionary and not bool((districts[index] as Dictionary).get("destroyed", false)):
			return index
	return 0


func _other_district(origin: int) -> int:
	var districts: Array = _runtime_main.get("districts") as Array
	for index in range(districts.size()):
		if index != origin and districts[index] is Dictionary and not bool((districts[index] as Dictionary).get("destroyed", false)):
			return index
	return origin


func _prepare_public_target_factor_fixture() -> Dictionary:
	var district_index := _safe_district()
	var districts := (_runtime_main.get("districts") as Array).duplicate(true)
	var district := (districts[district_index] as Dictionary).duplicate(true)
	district["destroyed"] = false
	district["miasma"] = true
	var focus_product := str((district.get("products", []) as Array)[0]) if not (district.get("products", []) as Array).is_empty() else "环晶电池"
	district["products"] = [focus_product]
	district["demands"] = [focus_product]
	district["city"] = {
		"active": true,
		"owner": 1,
		"products": [{"name": focus_product}],
		"demands": [focus_product],
		"competition_matches": 2,
		"warehouse_stockpile_count": 1,
		"warehouse_stockpile_units": 5,
		"warehouse_stockpile_products": [focus_product],
	}
	districts[district_index] = district
	_runtime_main.set("districts", districts)
	var actor := _make_actor(0, district_index, 0, 1)
	actor["name"] = "QA Public Alpha"
	actor["resource_focus"] = [focus_product]
	actor["remaining_time"] = 90.0
	actor["down"] = false
	var rival := _make_actor(1, district_index, 1, 1)
	rival["name"] = "QA Public Beta"
	rival["remaining_time"] = 90.0
	rival["down"] = false
	_set_monsters([actor, rival])
	return {"actor": actor, "district_index": district_index}


func _make_actor(catalog_index: int, district_index: int, owner_index: int, rank: int) -> Dictionary:
	var value: Variant = _runtime_monsters.call("_make_auto_monster", _runtime_monsters.auto_monsters.size(), catalog_index, district_index, owner_index, rank)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _qa_combat_actor(slot: int, district_index: int, actor_name: String, owner_index: int) -> Dictionary:
	var actor := _make_actor(0, district_index, owner_index, 1)
	actor["slot"] = slot
	actor["name"] = actor_name
	actor["hp"] = 20
	actor["max_hp"] = 20
	actor["armor"] = 0
	actor["down"] = false
	actor["revive_available"] = false
	actor["world_position"] = _runtime_monsters.call("_district_center", district_index)
	return actor


func _monster_skill(catalog_index: int, rank: int) -> Dictionary:
	var card_id := str(_runtime_monsters.call("_monster_card_name", catalog_index, rank))
	var value: Variant = _runtime_monsters.call("_make_skill", card_id)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _set_monsters(monsters: Array) -> void:
	var normalized := monsters.duplicate(true)
	for index in range(normalized.size()):
		if normalized[index] is Dictionary:
			(normalized[index] as Dictionary)["slot"] = index
	_runtime_monsters.auto_monsters = normalized


func _monsters() -> Array:
	return _runtime_monsters.roster_snapshot(true)


func _monster(slot: int) -> Dictionary:
	var monsters: Array = _runtime_monsters.auto_monsters
	if slot < 0 or slot >= monsters.size() or not (monsters[slot] is Dictionary):
		return {}
	return (monsters[slot] as Dictionary).duplicate(true)


func _player(player_index: int) -> Dictionary:
	var players: Array = _runtime_main.get("players") as Array
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return {}
	return (players[player_index] as Dictionary).duplicate(true)


func _player_cash(player_index: int) -> int:
	return int(_player(player_index).get("cash", 0))


func _set_player_cash(player_index: int, cash: int) -> void:
	var players := (_runtime_main.get("players") as Array).duplicate(true)
	var player: Dictionary = (players[player_index] as Dictionary).duplicate(true)
	player["cash"] = cash
	player["cash_history"] = [cash]
	players[player_index] = player
	_runtime_main.set("players", players)


func _prepare_wager_pair(public_pool: int) -> void:
	var district_index := _safe_district()
	var actor := _qa_combat_actor(0, district_index, "QA Alpha", -1)
	var target := _qa_combat_actor(1, district_index, "QA Beta", -1)
	target["world_position"] = actor["world_position"]
	_set_monsters([actor, target])
	_runtime_monsters.public_card_bid_monster_wager_pool = public_pool
	_runtime_main.set("opening_guide_dismissed", true)


func _open_qa_wager(public_pool: int) -> int:
	_prepare_wager_pair(public_pool)
	return int(_runtime_monsters.call("_open_monster_wager_for_pair", 0, 1, "QA wager", {}))


func _active_wager() -> Dictionary:
	var wagers: Array = _runtime_monsters.active_monster_wagers
	return (wagers[0] as Dictionary).duplicate(true) if not wagers.is_empty() and wagers[0] is Dictionary else {}


func _actor_metrics(actor: Dictionary) -> Dictionary:
	return {
		"fixture_id": str(actor.get("name", "monster")),
		"monster_name": str(actor.get("name", "")),
		"start_district": int(actor.get("position", -1)),
		"final_district": int(actor.get("position", -1)),
		"action_kind": "actor_state",
	}


func _record(case_id: String, observed: bool, aligned: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var record := {
		"case_id": case_id,
		"fixture_id": str(flags.get("fixture_id", "")),
		"monster_name": str(flags.get("monster_name", "")),
		"start_district": int(flags.get("start_district", -1)),
		"target_district": int(flags.get("target_district", -1)),
		"final_district": int(flags.get("final_district", -1)),
		"action_kind": str(flags.get("action_kind", "")),
		"damage_delta": int(flags.get("damage_delta", 0)),
		"route_pressure_delta": int(flags.get("route_pressure_delta", 0)),
		"city_gdp_delta": int(flags.get("city_gdp_delta", 0)),
		"lifetime_delta": float(flags.get("lifetime_delta", 0.0)),
		"wager_count_delta": int(flags.get("wager_count_delta", 0)),
		"cash_delta": int(flags.get("cash_delta", 0)),
		"call_graph_checked": bool(flags.get("call_graph_checked", false)),
		"rng_checked": bool(flags.get("rng_checked", false)),
		"save_checked": bool(flags.get("save_checked", false)),
		"privacy_checked": bool(flags.get("privacy_checked", false)),
		"pure_data_checked": true,
		"observed": observed,
		"contract_aligned": aligned,
		"needs_design_decision": bool(flags.get("needs_design_decision", false)),
		"risk": str(flags.get("risk", "" if aligned else "Observed behavior differs from or is underspecified by the v0.4 contract.")),
		"passed": observed and aligned,
		"notes": notes,
	}
	return record


func _dictionary_excludes_keys(value: Dictionary, forbidden: Array) -> bool:
	for key_variant in value.keys():
		if forbidden.has(str(key_variant).to_lower()):
			return false
		var nested: Variant = value[key_variant]
		if nested is Dictionary and not _dictionary_excludes_keys(nested, forbidden):
			return false
		if nested is Array:
			for item in nested:
				if item is Dictionary and not _dictionary_excludes_keys(item, forbidden):
					return false
	return true


func _main_metrics() -> Dictionary:
	var lines := _main_source.split("\n")
	var total_lines := lines.size()
	if total_lines > 0 and str(lines[total_lines - 1]).is_empty():
		total_lines -= 1
	var nonblank := 0
	var functions := 0
	var variables := 0
	var constants := 0
	for line_variant in lines:
		var line := str(line_variant)
		if not line.strip_edges().is_empty():
			nonblank += 1
		if line.begins_with("func "):
			functions += 1
		elif line.begins_with("var "):
			variables += 1
		elif line.begins_with("const "):
			constants += 1
	return {"total_lines": total_lines, "nonblank_lines": nonblank, "function_count": functions, "top_level_variable_count": variables, "constant_count": constants}


func _observed_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("observed", false)):
			count += 1
	return count


func _aligned_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("contract_aligned", false)):
			count += 1
	return count


func _passed_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count


func _design_decision_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("needs_design_decision", false)):
			count += 1
	return count


func _update_ui(manifest: Dictionary) -> void:
	var observed := int(manifest.get("observed_count", 0))
	var aligned := int(manifest.get("aligned_count", 0))
	var decisions := int(manifest.get("needs_design_decision_count", 0))
	var cutover_checked := bool(manifest.get("main_cutover_delta_checked", false))
	summary_label.text = "Monster runtime: %d/%d observed | %d/%d aligned | %d decisions | hard cutover=%s" % [observed, CASE_COUNT, aligned, CASE_COUNT, decisions, str(cutover_checked)]
	var complete := observed == CASE_COUNT and aligned == CASE_COUNT and cutover_checked
	status_label.text = "HARD CUTOVER COMPLETE" if complete else "HARD CUTOVER INCOMPLETE"
	status_label.add_theme_color_override("font_color", Color("#4ade80") if complete else Color("#fb7185"))
	ownership_text.text = "[b]Current owner: MonsterRuntimeController[/b]\n\nState\n• roster, selection, timers, wager pools\n\nDecision and lifecycle\n• target weights and shared RNG gateway\n• movement, pressure, action selection\n• combat, defeat, revival and wagers\n\nNarrow world boundary\n• MonsterRuntimeWorldBridge\n• main.gd save/world adapters only\n\nPresentation remains external\n• PlanetMonsterToken\n• MonsterCodexPublicSnapshotService\n• MonsterWagerDecisionPanel"
	var lines: Array[String] = ["[b]Real-main observations[/b]"]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		var mark := "PASS" if bool(record.get("passed", false)) else "REVIEW"
		lines.append("%s  %s" % [mark, str(record.get("case_id", ""))])
	cases_text.text = "\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var metrics: Dictionary = manifest.get("main_metrics", {})
	var lines := [
		"# Monster Runtime Hard Cutover - Sprint 45",
		"",
		"- Ruleset: `v0.4`",
		"- Runtime owner: `MonsterRuntimeController`",
		"- Observed: **%d/%d**" % [int(manifest.get("observed_count", 0)), CASE_COUNT],
		"- Contract aligned: **%d/%d**" % [int(manifest.get("aligned_count", 0)), CASE_COUNT],
		"- Needs design decision: **%d**" % int(manifest.get("needs_design_decision_count", 0)),
		"- Hard cutover delta checked: **%s**" % str(bool(manifest.get("main_cutover_delta_checked", false))),
		"- Removed from main: **%d nonblank lines / %d functions**" % [int(manifest.get("removed_nonblank_lines", 0)), int(manifest.get("removed_functions", 0))],
		"- Main SHA-256: `%s`" % str(manifest.get("current_main_sha256", "")),
		"- Main metrics: %d nonblank lines / %d functions / %d variables / %d constants" % [int(metrics.get("nonblank_lines", 0)), int(metrics.get("function_count", 0)), int(metrics.get("top_level_variable_count", 0)), int(metrics.get("constant_count", 0))],
		"",
		"Hidden monster binding, private targets/discards, and AI private plans are intentionally absent. Public wager identity and percentage remain visible because rulebook section 15 makes them public.",
		"",
		"| Case | Fixture | Action | Start | Target | Final | Damage | Lifetime | Wagers | Cash | RNG | Save | Privacy | Observed | Aligned | Decision | Notes |",
		"| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- | --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| %s | %s | %s | %d | %d | %d | %d | %.1f | %d | %d | %s | %s | %s | %s | %s | %s | %s |" % [
			str(record.get("case_id", "")), str(record.get("fixture_id", "")), str(record.get("action_kind", "")),
			int(record.get("start_district", -1)), int(record.get("target_district", -1)), int(record.get("final_district", -1)),
			int(record.get("damage_delta", 0)), float(record.get("lifetime_delta", 0.0)), int(record.get("wager_count_delta", 0)), int(record.get("cash_delta", 0)),
			"yes" if bool(record.get("rng_checked", false)) else "no", "yes" if bool(record.get("save_checked", false)) else "no", "yes" if bool(record.get("privacy_checked", false)) else "no",
			"yes" if bool(record.get("observed", false)) else "no", "yes" if bool(record.get("contract_aligned", false)) else "no", "yes" if bool(record.get("needs_design_decision", false)) else "no",
			str(record.get("notes", "")).replace("|", "/"),
		])
	return "\n".join(lines) + "\n"


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for file_name in ["manifest.json", "report.md"]:
		var path := OUTPUT_DIR + str(file_name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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
	if image == null:
		_failures.append("viewport image unavailable")
		return
	var absolute_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	if error != OK:
		_failures.append("screenshot save failed: %s" % error_string(error))


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
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


func _contains_runtime_object(value: Variant) -> bool:
	if value is Callable or value is Object:
		return true
	if value is Array:
		for item in value:
			if _contains_runtime_object(item):
				return true
	if value is Dictionary:
		for key in value.keys():
			if _contains_runtime_object(key) or _contains_runtime_object(value[key]):
				return true
	return false
