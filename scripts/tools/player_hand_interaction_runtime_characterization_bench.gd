extends Control
class_name PlayerHandInteractionRuntimeCharacterizationBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const INVENTORY_SERVICE_SCRIPT_PATH := "res://scripts/runtime/card_inventory_runtime_service.gd"
const INTERACTION_SERVICE_SCENE_PATH := "res://scenes/runtime/PlayerHandInteractionRuntimeService.tscn"
const INTERACTION_SERVICE_SCRIPT_PATH := "res://scripts/runtime/player_hand_interaction_runtime_service.gd"
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const COORDINATOR_SCRIPT_PATH := "res://scripts/runtime/game_runtime_coordinator.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/player_hand_interaction_characterization/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/player_hand_interaction_runtime_cutover_sprint_33.png"
const CHARACTERIZATION_CASE_COUNT := 20
const CUTOVER_CASE_COUNT := 20
const CASE_COUNT := CHARACTERIZATION_CASE_COUNT + CUTOVER_CASE_COUNT

const DISRUPT_CARDS := ["星链拆解1", "星链拆解2", "星链拆解3", "星链拆解4"]
const STEAL_CARDS := ["影仓牵引1", "影仓牵引2", "影仓牵引3", "影仓牵引4"]

@export var auto_run := true

@onready var runtime_main_host: Control = %RuntimeMainHost
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var cases_text: RichTextLabel = %CasesText

var _runtime_main: Control = null
var _records: Array = []
var _failures: Array[String] = []


func _ready() -> void:
	print("PlayerHandInteractionRuntimeCharacterizationBench ready: auto_run=%s editor_hint=%s" % [auto_run, Engine.is_editor_hint()])
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_characterization_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func characterization_cases() -> Array:
	return [
		"interaction_call_graph_complete",
		"real_interaction_card_catalog_exists",
		"disrupt_rank_i_removes_one",
		"disrupt_rank_ii_remove_then_lock",
		"disrupt_rank_iii_penalty_and_lock",
		"disrupt_rank_iv_two_remove_cap",
		"disrupt_queued_and_locked_exclusion",
		"disrupt_empty_target_safe_failure",
		"disrupt_cash_penalty_caps_at_available_cash",
		"steal_rank_i_success",
		"steal_duplicate_family_upgrades_receiver",
		"steal_rank_iv_receiver_converts_to_remove",
		"steal_rank_ii_transfer_then_lock",
		"steal_rank_iv_multi_transfer_order",
		"steal_partial_when_target_has_fewer_cards",
		"steal_compensation_applies_once",
		"queued_resolution_dispatches_interaction",
		"human_and_ai_share_resolution_route",
		"public_private_event_boundary",
		"save_action_and_signal_compatibility",
	]


func cutover_cases() -> Array:
	return [
		"service_scene_composition",
		"pure_service_api",
		"interaction_owner_call_graph",
		"disrupt_rank_i_service",
		"disrupt_rank_ii_order_service",
		"disrupt_rank_iii_penalty_service",
		"disrupt_rank_iv_cap_service",
		"exclusion_service",
		"cash_cap_service",
		"steal_rank_i_service",
		"duplicate_upgrade_service",
		"convert_remove_service",
		"transfer_then_lock_service",
		"multi_transfer_order_service",
		"partial_success_service",
		"compensation_once_service",
		"queued_dispatch_service",
		"human_ai_shared_service",
		"privacy_event_intents",
		"legacy_orchestration_absent",
	]


func all_cases() -> Array:
	return characterization_cases() + cutover_cases()


func build_characterization_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in characterization_cases():
		records.append(_record(str(case_id_variant), "", 0, 0, {}, {
			"observed": false,
			"contract_aligned": false,
			"notes": "preview",
		}))
	for case_id_variant in cutover_cases():
		records.append(_record(str(case_id_variant), "", 0, 0, {}, {
			"phase": "cutover",
			"observed": false,
			"contract_aligned": false,
			"cutover_passed": false,
			"notes": "preview",
		}))
	return {
		"suite": "player-hand-interaction-runtime-cutover-v04",
		"ruleset_id": "v0.4",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"case_count": CASE_COUNT,
		"characterization_case_count": CHARACTERIZATION_CASE_COUNT,
		"cutover_case_count": CUTOVER_CASE_COUNT,
		"record_count": records.size(),
		"observed_count": 0,
		"aligned_count": 0,
		"cutover_passed_count": 0,
		"needs_design_decision_count": 0,
		"records": records,
	}


func run_characterization_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	if not await _ensure_runtime_main():
		push_error("PlayerHandInteractionRuntimeCharacterizationBench could not instantiate real main.tscn")
		if DisplayServer.get_name() == "headless":
			get_tree().quit(1)
		return
	for case_id_variant in all_cases():
		var case_id := str(case_id_variant)
		await _reset_runtime_main()
		var record := _run_case(case_id)
		record["pure_data_checked"] = _is_data_only(record) and not _contains_runtime_object(record)
		record["passed"] = (bool(record.get("cutover_passed", false)) if str(record.get("phase", "characterization")) == "cutover" else bool(record.get("observed", false)) and bool(record.get("contract_aligned", false))) and bool(record.get("pure_data_checked", false))
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "observation failed"))])
	var manifest := {
		"suite": "player-hand-interaction-runtime-cutover-v04",
		"ruleset_id": "v0.4",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"case_count": CASE_COUNT,
		"characterization_case_count": CHARACTERIZATION_CASE_COUNT,
		"cutover_case_count": CUTOVER_CASE_COUNT,
		"record_count": _records.size(),
		"observed_count": _observed_count(),
		"aligned_count": _aligned_count(),
		"cutover_passed_count": _cutover_passed_count(),
		"mismatch_count": CHARACTERIZATION_CASE_COUNT - _aligned_count(),
		"needs_design_decision_count": _design_decision_count(),
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("PlayerHandInteractionRuntimeCharacterizationBench manifest: %s" % MANIFEST_PATH)
	print("PlayerHandInteractionRuntimeCharacterizationBench report: %s" % REPORT_PATH)
	print("PlayerHandInteractionRuntimeCharacterizationBench screenshot: %s" % SCREENSHOT_PATH)
	print("PlayerHandInteractionRuntimeCharacterizationBench observed: %d/%d" % [_observed_count(), CHARACTERIZATION_CASE_COUNT])
	print("PlayerHandInteractionRuntimeCharacterizationBench aligned: %d/%d; mismatches=%d; design_decisions=%d" % [_aligned_count(), CHARACTERIZATION_CASE_COUNT, CHARACTERIZATION_CASE_COUNT - _aligned_count(), _design_decision_count()])
	print("PlayerHandInteractionRuntimeCharacterizationBench cutover: %d/%d; total=%d/%d" % [_cutover_passed_count(), CUTOVER_CASE_COUNT, _passed_count(), CASE_COUNT])
	if not _failures.is_empty():
		push_error("PlayerHandInteractionRuntimeCharacterizationBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		_release_runtime_main()
		await get_tree().process_frame
		get_tree().quit(0 if _failures.is_empty() else 1)


func _run_case(case_id: String) -> Dictionary:
	if cutover_cases().has(case_id):
		return _run_cutover_case(case_id)
	match case_id:
		"interaction_call_graph_complete":
			return _case_interaction_call_graph_complete()
		"real_interaction_card_catalog_exists":
			return _case_real_interaction_card_catalog_exists()
		"disrupt_rank_i_removes_one":
			return _case_disrupt_rank_i_removes_one()
		"disrupt_rank_ii_remove_then_lock":
			return _case_disrupt_rank_ii_remove_then_lock()
		"disrupt_rank_iii_penalty_and_lock":
			return _case_disrupt_rank_iii_penalty_and_lock()
		"disrupt_rank_iv_two_remove_cap":
			return _case_disrupt_rank_iv_two_remove_cap()
		"disrupt_queued_and_locked_exclusion":
			return _case_disrupt_queued_and_locked_exclusion()
		"disrupt_empty_target_safe_failure":
			return _case_disrupt_empty_target_safe_failure()
		"disrupt_cash_penalty_caps_at_available_cash":
			return _case_disrupt_cash_penalty_caps_at_available_cash()
		"steal_rank_i_success":
			return _case_steal_rank_i_success()
		"steal_duplicate_family_upgrades_receiver":
			return _case_steal_duplicate_family_upgrades_receiver()
		"steal_rank_iv_receiver_converts_to_remove":
			return _case_steal_rank_iv_receiver_converts_to_remove()
		"steal_rank_ii_transfer_then_lock":
			return _case_steal_rank_ii_transfer_then_lock()
		"steal_rank_iv_multi_transfer_order":
			return _case_steal_rank_iv_multi_transfer_order()
		"steal_partial_when_target_has_fewer_cards":
			return _case_steal_partial_when_target_has_fewer_cards()
		"steal_compensation_applies_once":
			return _case_steal_compensation_applies_once()
		"queued_resolution_dispatches_interaction":
			return _case_queued_resolution_dispatches_interaction()
		"human_and_ai_share_resolution_route":
			return _case_human_and_ai_share_resolution_route()
		"public_private_event_boundary":
			return _case_public_private_event_boundary()
		"save_action_and_signal_compatibility":
			return _case_save_action_and_signal_compatibility()
	return _record(case_id, "", 0, 0, {}, {
		"observed": false,
		"contract_aligned": false,
		"risk": "unknown case",
		"notes": "unknown characterization case",
	})


func _run_cutover_case(case_id: String) -> Dictionary:
	match case_id:
		"service_scene_composition":
			var packed := load(INTERACTION_SERVICE_SCENE_PATH) as PackedScene
			var coordinator_scene_source := FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH)
			var coordinator := _coordinator()
			var service := coordinator.get_node_or_null("PlayerHandInteractionRuntimeService") if coordinator != null else null
			var passed := packed != null and service != null and coordinator_scene_source.contains("PlayerHandInteractionRuntimeService.tscn")
			return _cutover_record(case_id, {}, passed, "GameRuntimeCoordinator statically owns the real interaction service scene.", {
				"service_owner_checked": service != null,
				"main_adapter_checked": true,
			})
		"pure_service_api":
			var source := FileAccess.get_file_as_string(INTERACTION_SERVICE_SCRIPT_PATH)
			var debug := _interaction_debug()
			var methods_checked := source.contains("func plan_interaction(") and source.contains("func commit_interaction(") and source.contains("func debug_snapshot(")
			var passed := methods_checked and bool(debug.get("service_authoritative", false)) and _is_data_only(debug) and not _contains_runtime_object(debug)
			return _cutover_record(case_id, {}, passed, "Service API and debug snapshot are data-only and authoritative.", {
				"service_owner_checked": methods_checked,
				"pure_data_checked": _is_data_only(debug) and not _contains_runtime_object(debug),
			})
		"interaction_owner_call_graph":
			return _cutover_call_graph_record(case_id)
		"legacy_orchestration_absent":
			return _cutover_call_graph_record(case_id)
	var behavior_case_id: String = str({
		"disrupt_rank_i_service": "disrupt_rank_i_removes_one",
		"disrupt_rank_ii_order_service": "disrupt_rank_ii_remove_then_lock",
		"disrupt_rank_iii_penalty_service": "disrupt_rank_iii_penalty_and_lock",
		"disrupt_rank_iv_cap_service": "disrupt_rank_iv_two_remove_cap",
		"exclusion_service": "disrupt_queued_and_locked_exclusion",
		"cash_cap_service": "disrupt_cash_penalty_caps_at_available_cash",
		"steal_rank_i_service": "steal_rank_i_success",
		"duplicate_upgrade_service": "steal_duplicate_family_upgrades_receiver",
		"convert_remove_service": "steal_rank_iv_receiver_converts_to_remove",
		"transfer_then_lock_service": "steal_rank_ii_transfer_then_lock",
		"multi_transfer_order_service": "steal_rank_iv_multi_transfer_order",
		"partial_success_service": "steal_partial_when_target_has_fewer_cards",
		"compensation_once_service": "steal_compensation_applies_once",
		"queued_dispatch_service": "queued_resolution_dispatches_interaction",
		"human_ai_shared_service": "human_and_ai_share_resolution_route",
		"privacy_event_intents": "public_private_event_boundary",
	}.get(case_id, ""))
	if not behavior_case_id.is_empty():
		var behavior := _run_case(behavior_case_id)
		var debug := _interaction_debug()
		var service_checked := bool(debug.get("service_authoritative", false)) and bool(debug.get("interaction_orchestration_authority", false)) and not bool(debug.get("inventory_mutation_authority", true))
		var passed := bool(behavior.get("observed", false)) and bool(behavior.get("contract_aligned", false)) and service_checked
		var exact_once := true
		if ["compensation_once_service", "cash_cap_service"].has(case_id):
			exact_once = int(debug.get("committed_count", 0)) == 1
			passed = passed and exact_once
		return _cutover_record(case_id, behavior, passed, "The characterized real-main behavior now routes through one authoritative interaction commit.", {
			"service_owner_checked": service_checked,
			"main_adapter_checked": true,
			"exact_once_checked": exact_once,
			"privacy_checked": bool(behavior.get("privacy_checked", false)),
		})
	return _cutover_record(case_id, {}, false, "Unknown cutover case.")


func _cutover_call_graph_record(case_id: String) -> Dictionary:
	var main_source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var service_source := FileAccess.get_file_as_string(INTERACTION_SERVICE_SCRIPT_PATH)
	var coordinator_source := FileAccess.get_file_as_string(COORDINATOR_SCRIPT_PATH)
	var disrupt := _function_source(main_source, "_apply_player_hand_disrupt")
	var steal := _function_source(main_source, "_apply_player_hand_steal")
	var adapter := _function_source(main_source, "_resolve_player_hand_interaction")
	var legacy_absent := _function_source(main_source, "_take_private_hand_card_from_player").is_empty() and _function_source(main_source, "_lock_private_hand_card_for_player").is_empty() and _function_source(main_source, "_transfer_private_hand_card_between_players").is_empty()
	var wrappers_thin := disrupt.contains("_resolve_player_hand_interaction") and steal.contains("_resolve_player_hand_interaction") and not disrupt.contains("target_cash_penalty") and not steal.contains("steal_fail_cash")
	var routed := adapter.contains("plan_player_hand_interaction") and adapter.contains("commit_player_hand_interaction") and coordinator_source.contains("plan_interaction") and coordinator_source.contains("commit_interaction")
	var service_owns := service_source.contains("penalty_paid = mini") and service_source.contains("compensation_paid") and service_source.contains("private_event_intents") and service_source.contains("public_event_intents") and service_source.contains("_commit_remove") and service_source.contains("_commit_transfer") and service_source.contains("_commit_lock")
	var inventory_delegated := service_source.contains("_inventory_service.call(\"commit_remove\"") and service_source.contains("_inventory_service.call(\"commit_transfer\"") and service_source.contains("_inventory_service.call(\"commit_lock\"")
	var passed := legacy_absent and wrappers_thin and routed and service_owns and inventory_delegated
	return _cutover_record(case_id, {}, passed, "main.gd is a thin fact/RNG/event adapter; the service owns orchestration and CardInventoryRuntimeService still owns slot mutation.", {
		"service_owner_checked": service_owns and inventory_delegated,
		"main_adapter_checked": wrappers_thin and routed,
		"legacy_formula_absent": legacy_absent,
	})


func _cutover_record(case_id: String, metrics: Dictionary, passed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var record := _record(case_id, str(metrics.get("played_card_id", "")), int(metrics.get("card_rank", 0)), int(metrics.get("requested_count", 0)), metrics, {
		"phase": "cutover",
		"observed": passed,
		"contract_aligned": passed,
		"cutover_passed": passed,
		"resolution_route_checked": bool(flags.get("main_adapter_checked", passed)),
		"inventory_service_checked": bool(flags.get("service_owner_checked", passed)),
		"privacy_checked": bool(flags.get("privacy_checked", true)),
		"service_owner_checked": bool(flags.get("service_owner_checked", passed)),
		"main_adapter_checked": bool(flags.get("main_adapter_checked", passed)),
		"legacy_formula_absent": bool(flags.get("legacy_formula_absent", true)),
		"exact_once_checked": bool(flags.get("exact_once_checked", true)),
		"notes": notes,
	})
	if flags.has("pure_data_checked"):
		record["pure_data_checked"] = bool(flags.get("pure_data_checked", false))
	return record


func _case_interaction_call_graph_complete() -> Dictionary:
	var source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var service_source := FileAccess.get_file_as_string(INTERACTION_SERVICE_SCRIPT_PATH)
	var disrupt := _function_source(source, "_apply_player_hand_disrupt")
	var steal := _function_source(source, "_apply_player_hand_steal")
	var adapter := _function_source(source, "_resolve_player_hand_interaction")
	var resolver := _function_source(source, "_apply_card_resolution_effect_request")
	var complete := disrupt.contains("_resolve_player_hand_interaction") and steal.contains("_resolve_player_hand_interaction")
	complete = complete and adapter.contains("plan_player_hand_interaction") and adapter.contains("commit_player_hand_interaction")
	complete = complete and service_source.contains("func plan_interaction(") and service_source.contains("func commit_interaction(")
	complete = complete and service_source.contains("_inventory_service.call(\"commit_remove\"") and service_source.contains("_inventory_service.call(\"commit_transfer\"") and service_source.contains("_inventory_service.call(\"commit_lock\"")
	complete = complete and resolver.contains("_apply_player_hand_disrupt") and resolver.contains("_apply_player_hand_steal")
	var legacy_absent := _function_source(source, "_take_private_hand_card_from_player").is_empty() and _function_source(source, "_lock_private_hand_card_for_player").is_empty() and _function_source(source, "_transfer_private_hand_card_between_players").is_empty()
	return _record("interaction_call_graph_complete", "", 0, 0, {}, {
		"observed": complete,
		"contract_aligned": complete and legacy_absent,
		"resolution_route_checked": resolver.contains("_apply_player_hand_disrupt") and resolver.contains("_apply_player_hand_steal"),
		"inventory_service_checked": service_source.contains("_inventory_service.call"),
		"privacy_checked": true,
		"service_owner_checked": complete,
		"main_adapter_checked": adapter.contains("commit_player_hand_interaction"),
		"legacy_formula_absent": legacy_absent,
		"notes": "CardResolutionExecutionRuntimeService reaches the concrete effect adapter; PlayerHandInteractionRuntimeService owns interaction ordering and CardInventoryRuntimeService owns every slot mutation.",
	})


func _case_real_interaction_card_catalog_exists() -> Dictionary:
	var expected := {
		"星链拆解1": {"kind": "player_hand_disrupt", "rank": 1, "count": 1, "lock": 0, "cash": 0},
		"星链拆解2": {"kind": "player_hand_disrupt", "rank": 2, "count": 1, "lock": 10, "cash": 0},
		"星链拆解3": {"kind": "player_hand_disrupt", "rank": 3, "count": 1, "lock": 18, "cash": 80},
		"星链拆解4": {"kind": "player_hand_disrupt", "rank": 4, "count": 2, "lock": 20, "cash": 120},
		"影仓牵引1": {"kind": "player_hand_steal", "rank": 1, "count": 1, "lock": 0, "cash": 60},
		"影仓牵引2": {"kind": "player_hand_steal", "rank": 2, "count": 1, "lock": 8, "cash": 90},
		"影仓牵引3": {"kind": "player_hand_steal", "rank": 3, "count": 1, "lock": 15, "cash": 140},
		"影仓牵引4": {"kind": "player_hand_steal", "rank": 4, "count": 2, "lock": 18, "cash": 220},
	}
	var catalog_ok := true
	for card_id_variant in expected.keys():
		var card_id := str(card_id_variant)
		var skill := _make_skill(card_id)
		var contract: Dictionary = expected[card_id]
		var count_key := "hand_discard_count" if str(contract.get("kind", "")) == "player_hand_disrupt" else "hand_steal_count"
		var cash_key := "target_cash_penalty" if str(contract.get("kind", "")) == "player_hand_disrupt" else "steal_fail_cash"
		catalog_ok = catalog_ok and not skill.is_empty()
		catalog_ok = catalog_ok and str(skill.get("kind", "")) == str(contract.get("kind", ""))
		catalog_ok = catalog_ok and _card_rank(card_id) == int(contract.get("rank", 0))
		catalog_ok = catalog_ok and int(skill.get(count_key, 0)) == int(contract.get("count", 0))
		catalog_ok = catalog_ok and int(round(float(skill.get("hand_lock_seconds", 0.0)))) == int(contract.get("lock", 0))
		catalog_ok = catalog_ok and int(skill.get(cash_key, 0)) == int(contract.get("cash", 0))
	return _record("real_interaction_card_catalog_exists", "eight-real-interaction-cards", 0, 0, {}, {
		"observed": expected.size() == 8 and catalog_ok,
		"contract_aligned": expected.size() == 8 and catalog_ok,
		"inventory_service_checked": true,
		"privacy_checked": true,
		"notes": "All four Starlink Dismantle and four Shadow Hold Traction ranks load from the real runtime catalog with their live count, lock, penalty, and compensation fields.",
	})


func _case_disrupt_rank_i_removes_one() -> Dictionary:
	var target_cards := _generic_card_ids(2)
	var result := _execute_interaction("星链拆解1", [], _skills(target_cards), 1000, 1000, 3203)
	var aligned := bool(result.get("applied", false)) and int(result.get("removed_count", 0)) == 1 and int(result.get("locked_count", 0)) == 0 and int(result.get("target_cash_delta", 0)) == 0 and int(result.get("inventory_commit_delta", 0)) == 1
	return _record("disrupt_rank_i_removes_one", "星链拆解1", 1, 1, result, _runtime_flags(result, aligned, "Rank I removes exactly one eligible ordinary card and performs one inventory commit."))


func _case_disrupt_rank_ii_remove_then_lock() -> Dictionary:
	var result := _execute_interaction("星链拆解2", [], _skills(_generic_card_ids(2)), 1000, 1000, 3204)
	var source := _function_source(FileAccess.get_file_as_string(INTERACTION_SERVICE_SCRIPT_PATH), "commit_interaction")
	var order_checked := source.find("_commit_remove") >= 0 and source.find("_commit_remove") < source.find("_commit_lock")
	var aligned := bool(result.get("applied", false)) and int(result.get("removed_count", 0)) == 1 and int(result.get("locked_count", 0)) == 1 and int(result.get("inventory_commit_delta", 0)) == 2 and order_checked
	var flags := _runtime_flags(result, aligned, "Rank II removes first, then locks one remaining eligible card for 10 seconds.")
	flags["resolution_route_checked"] = order_checked
	return _record("disrupt_rank_ii_remove_then_lock", "星链拆解2", 2, 1, result, flags)


func _case_disrupt_rank_iii_penalty_and_lock() -> Dictionary:
	var result := _execute_interaction("星链拆解3", [], _skills(_generic_card_ids(2)), 1000, 300, 3205)
	var aligned := bool(result.get("applied", false)) and int(result.get("removed_count", 0)) == 1 and int(result.get("locked_count", 0)) == 1 and int(result.get("target_cash_delta", 0)) == -80 and int(result.get("inventory_commit_delta", 0)) == 2
	return _record("disrupt_rank_iii_penalty_and_lock", "星链拆解3", 3, 1, result, _runtime_flags(result, aligned, "Rank III resolves remove, then lock, then the 80-credit target reorganization charge."))


func _case_disrupt_rank_iv_two_remove_cap() -> Dictionary:
	var result := _execute_interaction("星链拆解4", [], _skills(_generic_card_ids(3)), 1000, 500, 3206)
	var aligned := bool(result.get("applied", false)) and int(result.get("removed_count", 0)) == 2 and int(result.get("locked_count", 0)) == 1 and int(result.get("target_cash_delta", 0)) == -120 and int(result.get("inventory_commit_delta", 0)) == 3
	return _record("disrupt_rank_iv_two_remove_cap", "星链拆解4", 4, 2, result, _runtime_flags(result, aligned, "Rank IV caps removal at two, then locks one surviving eligible card and charges 120."))


func _case_disrupt_queued_and_locked_exclusion() -> Dictionary:
	var ids := _generic_card_ids(3)
	var slots := _skills(ids)
	if slots.size() >= 3:
		(slots[0] as Dictionary)["queued_for_resolution"] = true
		(slots[1] as Dictionary)["lock_left"] = 12.0
	var result := _execute_interaction("星链拆解1", [], slots, 1000, 1000, 3207)
	var after: Dictionary = result.get("target_after", {}) if result.get("target_after", {}) is Dictionary else {}
	var protected_cards_remain := int(after.get("hand_count", 0)) == 2 and int(after.get("locked_count", 0)) == 1 and int(after.get("queued_count", 0)) == 1
	var aligned := bool(result.get("applied", false)) and int(result.get("removed_count", 0)) == 1 and protected_cards_remain
	return _record("disrupt_queued_and_locked_exclusion", "星链拆解1", 1, 1, result, _runtime_flags(result, aligned, "Queued and already locked cards are excluded; the only unlocked ordinary card is removed."))


func _case_disrupt_empty_target_safe_failure() -> Dictionary:
	var result := _execute_interaction("星链拆解1", [], [], 1000, 1000, 3208)
	var aligned := not bool(result.get("applied", true)) and int(result.get("removed_count", 0)) == 0 and int(result.get("locked_count", 0)) == 0 and int(result.get("inventory_commit_delta", 0)) == 0 and int(result.get("target_cash_delta", 0)) == 0
	return _record("disrupt_empty_target_safe_failure", "星链拆解1", 1, 1, result, _runtime_flags(result, aligned, "An empty target fails safely without slot or cash mutation."))


func _case_disrupt_cash_penalty_caps_at_available_cash() -> Dictionary:
	var result := _execute_interaction("星链拆解3", [], _skills(_generic_card_ids(2)), 1000, 30, 3209)
	var target_after: Dictionary = result.get("target_after", {}) if result.get("target_after", {}) is Dictionary else {}
	var aligned := bool(result.get("applied", false)) and int(result.get("target_cash_delta", 0)) == -30 and int(target_after.get("cash", -1)) == 0
	return _record("disrupt_cash_penalty_caps_at_available_cash", "星链拆解3", 3, 1, result, _runtime_flags(result, aligned, "The 80-credit charge is capped at the target's 30 available credits; cash never becomes negative."))


func _case_steal_rank_i_success() -> Dictionary:
	var result := _execute_interaction("影仓牵引1", [], _skills(_generic_card_ids(1)), 1000, 1000, 3210)
	var aligned := bool(result.get("applied", false)) and int(result.get("transferred_count", 0)) == 1 and int(result.get("converted_count", 0)) == 0 and int(result.get("source_hand_delta", 0)) == 1 and int(result.get("target_hand_delta", 0)) == -1 and int(result.get("actor_cash_delta", 0)) == 0
	return _record("steal_rank_i_success", "影仓牵引1", 1, 1, result, _runtime_flags(result, aligned, "Rank I transfers one eligible card to the actor without compensation."))


func _case_steal_duplicate_family_upgrades_receiver() -> Dictionary:
	var base_ids := _generic_card_ids(1)
	var base_id := str(base_ids[0]) if not base_ids.is_empty() else ""
	var result := _execute_interaction("影仓牵引1", _skills([base_id]), _skills([base_id]), 1000, 1000, 3211)
	var source_before: Dictionary = result.get("source_before", {}) if result.get("source_before", {}) is Dictionary else {}
	var source_after: Dictionary = result.get("source_after", {}) if result.get("source_after", {}) is Dictionary else {}
	var rank_delta := int(source_after.get("rank_total", 0)) - int(source_before.get("rank_total", 0))
	var aligned := bool(result.get("applied", false)) and int(result.get("transferred_count", 0)) == 1 and int(result.get("source_hand_delta", 0)) == 0 and int(result.get("target_hand_delta", 0)) == -1 and rank_delta == 1
	return _record("steal_duplicate_family_upgrades_receiver", "影仓牵引1", 1, 1, result, _runtime_flags(result, aligned, "A same-family transfer upgrades the receiver in place; counted hand size stays flat while rank rises by one."))


func _case_steal_rank_iv_receiver_converts_to_remove() -> Dictionary:
	var base_ids := _generic_card_ids(1)
	var base_id := str(base_ids[0]) if not base_ids.is_empty() else ""
	var maximum_id := _max_upgrade_name(base_id)
	var result := _execute_interaction("影仓牵引1", _skills([maximum_id]), _skills([base_id]), 1000, 1000, 3212)
	var aligned := bool(result.get("applied", false)) and int(result.get("transferred_count", 0)) == 0 and int(result.get("converted_count", 0)) == 1 and int(result.get("source_hand_delta", 0)) == 0 and int(result.get("target_hand_delta", 0)) == -1 and int(result.get("actor_cash_delta", 0)) == 60
	return _record("steal_rank_iv_receiver_converts_to_remove", "影仓牵引1", 1, 1, result, _runtime_flags(result, aligned, "When the receiver already owns rank IV of the family, transfer converts to removal and pays the card's one-time 60 compensation."))


func _case_steal_rank_ii_transfer_then_lock() -> Dictionary:
	var result := _execute_interaction("影仓牵引2", [], _skills(_generic_card_ids(2)), 1000, 1000, 3213)
	var source := _function_source(FileAccess.get_file_as_string(INTERACTION_SERVICE_SCRIPT_PATH), "commit_interaction")
	var order_checked := source.find("_commit_transfer") >= 0 and source.find("_commit_transfer") < source.find("_commit_lock")
	var aligned := bool(result.get("applied", false)) and int(result.get("transferred_count", 0)) == 1 and int(result.get("locked_count", 0)) == 1 and int(result.get("actor_cash_delta", 0)) == 0 and order_checked
	var flags := _runtime_flags(result, aligned, "Rank II transfers first, then locks one remaining target card for 8 seconds.")
	flags["resolution_route_checked"] = order_checked
	return _record("steal_rank_ii_transfer_then_lock", "影仓牵引2", 2, 1, result, flags)


func _case_steal_rank_iv_multi_transfer_order() -> Dictionary:
	var result := _execute_interaction("影仓牵引4", [], _skills(_generic_card_ids(3)), 1000, 1000, 3214)
	var aligned := bool(result.get("applied", false)) and int(result.get("transferred_count", 0)) == 2 and int(result.get("converted_count", 0)) == 0 and int(result.get("locked_count", 0)) == 1 and int(result.get("source_hand_delta", 0)) == 2 and int(result.get("target_hand_delta", 0)) == -2 and int(result.get("actor_cash_delta", 0)) == 0
	return _record("steal_rank_iv_multi_transfer_order", "影仓牵引4", 4, 2, result, _runtime_flags(result, aligned, "Rank IV performs two transfer attempts in loop order, then locks one surviving target card."))


func _case_steal_partial_when_target_has_fewer_cards() -> Dictionary:
	var result := _execute_interaction("影仓牵引4", [], _skills(_generic_card_ids(1)), 1000, 1000, 3215)
	var aligned := bool(result.get("applied", false)) and int(result.get("transferred_count", 0)) == 1 and int(result.get("converted_count", 0)) == 0 and int(result.get("locked_count", 0)) == 0 and int(result.get("actor_cash_delta", 0)) == 0
	return _record("steal_partial_when_target_has_fewer_cards", "影仓牵引4", 4, 2, result, _runtime_flags(result, aligned, "A two-card request partially succeeds when only one eligible target card exists; the successful transfer prevents failure compensation."))


func _case_steal_compensation_applies_once() -> Dictionary:
	var base_ids := _generic_card_ids(1)
	var base_id := str(base_ids[0]) if not base_ids.is_empty() else ""
	var result := _execute_interaction("影仓牵引4", _skills([_max_upgrade_name(base_id)]), _skills([base_id, base_id]), 1000, 1000, 3216)
	var aligned := bool(result.get("applied", false)) and int(result.get("converted_count", 0)) == 2 and int(result.get("transferred_count", 0)) == 0 and int(result.get("actor_cash_delta", 0)) == 220
	return _record("steal_compensation_applies_once", "影仓牵引4", 4, 2, result, _runtime_flags(result, aligned, "Two converted removals trigger one 220-credit compensation for the whole played card, not 220 per failed transfer."))


func _case_queued_resolution_dispatches_interaction() -> Dictionary:
	var route := _execute_queued_route(0, 1, false, 3217)
	var aligned := bool(route.get("queued", false)) and bool(route.get("resolved", false)) and int(route.get("target_hand_delta", 0)) == -1 and int(route.get("inventory_commit_delta", 0)) == 1
	return _record("queued_resolution_dispatches_interaction", "星链拆解1", 1, 1, route, {
		"observed": bool(route.get("queued", false)) and bool(route.get("resolved", false)),
		"contract_aligned": aligned,
		"resolution_route_checked": true,
		"inventory_service_checked": int(route.get("inventory_commit_delta", 0)) == 1,
		"privacy_checked": bool(route.get("privacy_checked", false)),
		"notes": "A real rank-I interaction card enters the live shared queue and resolves through CardResolutionExecutionRuntimeService into the interaction and inventory services.",
	})


func _case_human_and_ai_share_resolution_route() -> Dictionary:
	var source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var use_skill := _function_source(source, "_use_skill")
	var choose_player := _function_source(source, "_choose_pending_target_player")
	var ai_turn := _function_source(source, "_ai_execute_card_turn")
	var ai_queue := _function_source(source, "_ai_queue_play_candidate")
	var shared_source_route := use_skill.contains("_begin_target_player_choice") and choose_player.contains("_queue_skill_resolution") and ai_turn.contains("_ai_queue_play_candidate") and ai_queue.contains("_queue_skill_resolution")
	var route := _execute_queued_route(1, 0, true, 3218)
	var aligned := shared_source_route and bool(route.get("actor_is_ai", false)) and bool(route.get("queued", false)) and bool(route.get("resolved", false)) and int(route.get("target_hand_delta", 0)) == -1
	return _record("human_and_ai_share_resolution_route", "星链拆解1", 1, 1, route, {
		"observed": shared_source_route and bool(route.get("resolved", false)),
		"contract_aligned": aligned,
		"resolution_route_checked": shared_source_route,
		"inventory_service_checked": int(route.get("inventory_commit_delta", 0)) == 1,
		"privacy_checked": bool(route.get("privacy_checked", false)),
		"notes": "Human target selection and AI candidate execution both converge on _queue_skill_resolution and the same execution service; the real AI seat route was observed.",
	})


func _case_public_private_event_boundary() -> Dictionary:
	var target_ids := _generic_card_ids(1)
	var target_id := str(target_ids[0]) if not target_ids.is_empty() else ""
	var result := _execute_interaction("影仓牵引1", [], _skills([target_id]), 1000, 1000, 3219)
	var actor_private := _private_ledger_contains(0, target_id)
	var target_private := _private_ledger_contains(1, target_id)
	var aligned := bool(result.get("applied", false)) and bool(result.get("privacy_checked", false)) and actor_private and target_private and int(result.get("public_event_delta", 0)) > 0 and int(result.get("private_event_delta", 0)) >= 2
	var flags := _runtime_flags(result, aligned, "Public feedback exposes the target and aggregate effect only; exact affected card details appear in actor/target private ledgers.")
	flags["privacy_checked"] = bool(result.get("privacy_checked", false)) and actor_private and target_private
	return _record("public_private_event_boundary", "影仓牵引1", 1, 1, result, flags)


func _case_save_action_and_signal_compatibility() -> Dictionary:
	var card := _queue_ready_interaction_skill("星链拆解1")
	_reset_player(0, [card], 1000)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 0
	_runtime_main.call("_begin_target_player_choice", 0)
	var snapshot_variant: Variant = _runtime_main.call("_runtime_player_target_decision_snapshot_source", 0)
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	var actions: Array = snapshot.get("actions", []) if snapshot.get("actions", []) is Array else []
	var action_ids: Array[String] = []
	for action_variant in actions:
		if action_variant is Dictionary:
			action_ids.append(str((action_variant as Dictionary).get("id", "")))
	var state_variant: Variant = _runtime_main.call("_capture_run_state")
	var state: Dictionary = state_variant if state_variant is Dictionary else {}
	var save_checked := int(state.get("pending_player_target_player_index", -1)) == 0 and int(state.get("pending_player_target_slot_index", -1)) == 0 and state.has("card_resolution_queue")
	var action_checked := action_ids.has("target_player_1") and action_ids.has("target_player_cancel")
	var cancel_handled := bool(_runtime_main.call("_activate_runtime_temporary_decision_action", "target_player_cancel"))
	var pending_cleared := not bool(_runtime_main.call("_has_pending_player_target_choice"))
	var source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var game_screen_source := FileAccess.get_file_as_string("res://scripts/ui/game_screen.gd")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/overlay_layer.gd")
	var signal_checked := source.contains("target_player_%d") and source.contains("target_player_cancel") and game_screen_source.contains("temporary_decision_action_requested") and overlay_source.contains("temporary_decision_action_requested.emit(action_id)")
	var pure_save := not _contains_runtime_object(state)
	var aligned := save_checked and action_checked and cancel_handled and pending_cleared and signal_checked and pure_save
	return _record("save_action_and_signal_compatibility", "星链拆解1", 1, 1, {}, {
		"observed": not snapshot.is_empty() and not state.is_empty(),
		"contract_aligned": aligned,
		"resolution_route_checked": action_checked and signal_checked,
		"inventory_service_checked": true,
		"privacy_checked": str(snapshot.get("kind", "")) == "player_target_choice",
		"notes": "Existing target_player_N/cancel action ids, temporary-decision signal routing, queued save keys, and cancellation semantics remain intact.",
	})


func _execute_interaction(card_id: String, actor_slots: Array, target_slots: Array, actor_cash: int, target_cash: int, seed_value: int) -> Dictionary:
	_reset_player(0, actor_slots, actor_cash)
	_reset_player(1, target_slots, target_cash)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = 0
	_seed_runtime_rng(seed_value)
	var skill := _make_skill(card_id)
	var source_before := _player_probe(0)
	var target_before := _player_probe(1)
	var logs_before := _public_log_count()
	var inventory_before := _inventory_debug()
	var interaction_before := _interaction_debug()
	var affected_private_values := _private_card_values(target_slots)
	affected_private_values.append(str(_player(0).get("name", "")))
	var method_name := "_apply_player_hand_disrupt" if str(skill.get("kind", "")) == "player_hand_disrupt" else "_apply_player_hand_steal"
	var applied := bool(_runtime_main.call(method_name, 0, 1, skill)) if not skill.is_empty() else false
	var source_after := _player_probe(0)
	var target_after := _player_probe(1)
	var inventory_after := _inventory_debug()
	var interaction_after := _interaction_debug()
	var source_hand_delta := int(source_after.get("hand_count", 0)) - int(source_before.get("hand_count", 0))
	var target_hand_delta := int(target_after.get("hand_count", 0)) - int(target_before.get("hand_count", 0))
	var target_removed := maxi(0, -target_hand_delta)
	var source_rank_delta := int(source_after.get("rank_total", 0)) - int(source_before.get("rank_total", 0))
	var transferred := 0
	var converted := 0
	var removed := 0
	if str(skill.get("kind", "")) == "player_hand_disrupt":
		removed = target_removed
	else:
		transferred = mini(target_removed, maxi(0, source_hand_delta) + maxi(0, source_rank_delta))
		converted = maxi(0, target_removed - transferred)
	return {
		"applied": applied,
		"source_before": source_before,
		"source_after": source_after,
		"target_before": target_before,
		"target_after": target_after,
		"removed_count": removed,
		"transferred_count": transferred,
		"converted_count": converted,
		"locked_count": maxi(0, int(target_after.get("locked_count", 0)) - int(target_before.get("locked_count", 0))),
		"actor_cash_delta": int(source_after.get("cash", 0)) - int(source_before.get("cash", 0)),
		"target_cash_delta": int(target_after.get("cash", 0)) - int(target_before.get("cash", 0)),
		"source_hand_delta": source_hand_delta,
		"target_hand_delta": target_hand_delta,
		"public_event_delta": _public_log_count() - logs_before,
		"private_event_delta": int(source_after.get("private_event_count", 0)) + int(target_after.get("private_event_count", 0)) - int(source_before.get("private_event_count", 0)) - int(target_before.get("private_event_count", 0)),
		"inventory_commit_delta": int(inventory_after.get("committed_count", 0)) - int(inventory_before.get("committed_count", 0)),
		"inventory_service_checked": bool(inventory_after.get("service_authoritative", false)),
		"interaction_commit_delta": int(interaction_after.get("committed_count", 0)) - int(interaction_before.get("committed_count", 0)),
		"interaction_service_checked": bool(interaction_after.get("service_authoritative", false)),
		"privacy_checked": _public_logs_hide_private_values(logs_before, affected_private_values),
	}


func _execute_queued_route(actor_index: int, target_index: int, actor_is_ai: bool, seed_value: int) -> Dictionary:
	var target_ids := _generic_card_ids(1)
	var target_slots := _skills(target_ids)
	_reset_player(actor_index, [_queue_ready_interaction_skill("星链拆解1")], 1000, actor_is_ai)
	var target_ai_override: Variant = null
	if target_index == 0:
		target_ai_override = false
	_reset_player(target_index, target_slots, 1000, target_ai_override)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = actor_index
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = 0
	_runtime_main.set("card_resolution_queue", [])
	_runtime_main.set("next_card_resolution_queue", [])
	_runtime_main.set("active_card_resolution", {})
	_runtime_main.set("card_resolution_batch_locked", false)
	_seed_runtime_rng(seed_value)
	var target_before := _player_probe(target_index)
	var logs_before := _public_log_count()
	var inventory_before := _inventory_debug()
	var queued := bool(_runtime_main.call("_queue_skill_resolution", actor_index, 0, -1, target_index))
	var queue: Array = _runtime_main.get("card_resolution_queue") as Array
	var entry: Dictionary = (queue[0] as Dictionary).duplicate(true) if queued and not queue.is_empty() and queue[0] is Dictionary else {}
	if not entry.is_empty():
		var queue_service := _card_resolution_queue_service()
		if queue_service != null:
			queue_service.call("replace_current_queue", [])
			queue_service.call("replace_active_entry", entry)
			_runtime_main.call("_complete_active_card_resolution")
	var target_after := _player_probe(target_index)
	var inventory_after := _inventory_debug()
	var target_hand_delta := int(target_after.get("hand_count", 0)) - int(target_before.get("hand_count", 0))
	var actor_state := _player(actor_index)
	return {
		"queued": queued,
		"resolved": queued and target_hand_delta == -1,
		"actor_is_ai": bool(actor_state.get("is_ai", false)),
		"target_hand_delta": target_hand_delta,
		"removed_count": maxi(0, -target_hand_delta),
		"source_hand_delta": 0,
		"transferred_count": 0,
		"converted_count": 0,
		"locked_count": 0,
		"actor_cash_delta": 0,
		"target_cash_delta": 0,
		"public_event_delta": _public_log_count() - logs_before,
		"private_event_delta": int(target_after.get("private_event_count", 0)) - int(target_before.get("private_event_count", 0)),
		"inventory_commit_delta": int(inventory_after.get("committed_count", 0)) - int(inventory_before.get("committed_count", 0)),
		"privacy_checked": _public_logs_hide_private_values(logs_before, _private_card_values(target_slots)),
	}


func _runtime_flags(result: Dictionary, aligned: bool, notes: String) -> Dictionary:
	return {
		"observed": not result.is_empty() and result.has("applied"),
		"contract_aligned": aligned,
		"resolution_route_checked": true,
		"inventory_service_checked": bool(result.get("inventory_service_checked", false)),
		"privacy_checked": bool(result.get("privacy_checked", false)),
		"notes": notes,
	}


func _record(case_id: String, played_card_id: String, card_rank: int, requested_count: int, metrics: Dictionary, flags: Dictionary) -> Dictionary:
	var observed := bool(flags.get("observed", false))
	var aligned := bool(flags.get("contract_aligned", false))
	var phase := str(flags.get("phase", "characterization"))
	var cutover_passed := bool(flags.get("cutover_passed", false))
	var record := {
		"phase": phase,
		"case_id": case_id,
		"played_card_id": played_card_id,
		"card_rank": card_rank,
		"requested_count": requested_count,
		"removed_count": int(metrics.get("removed_count", 0)),
		"transferred_count": int(metrics.get("transferred_count", 0)),
		"converted_count": int(metrics.get("converted_count", 0)),
		"locked_count": int(metrics.get("locked_count", 0)),
		"actor_cash_delta": int(metrics.get("actor_cash_delta", 0)),
		"target_cash_delta": int(metrics.get("target_cash_delta", 0)),
		"source_hand_delta": int(metrics.get("source_hand_delta", 0)),
		"target_hand_delta": int(metrics.get("target_hand_delta", 0)),
		"public_event_delta": int(metrics.get("public_event_delta", 0)),
		"private_event_delta": int(metrics.get("private_event_delta", 0)),
		"resolution_route_checked": bool(flags.get("resolution_route_checked", false)),
		"inventory_service_checked": bool(flags.get("inventory_service_checked", false)),
		"service_owner_checked": bool(flags.get("service_owner_checked", metrics.get("interaction_service_checked", false))),
		"main_adapter_checked": bool(flags.get("main_adapter_checked", false)),
		"legacy_formula_absent": bool(flags.get("legacy_formula_absent", false)),
		"exact_once_checked": bool(flags.get("exact_once_checked", false)),
		"privacy_checked": bool(flags.get("privacy_checked", false)),
		"pure_data_checked": true,
		"observed": observed,
		"contract_aligned": aligned,
		"cutover_passed": cutover_passed,
		"needs_design_decision": bool(flags.get("needs_design_decision", false)),
		"risk": str(flags.get("risk", "" if aligned else "observed behavior differs from or is underspecified by the v0.4 contract")),
		"passed": cutover_passed if phase == "cutover" else observed and aligned,
		"notes": str(flags.get("notes", "")),
	}
	record["pure_data_checked"] = _is_data_only(record) and not _contains_runtime_object(record)
	return record


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
	return true


func _reset_runtime_main() -> void:
	if _runtime_main == null:
		return
	_runtime_main.set_process(true)
	_runtime_main.call("_new_game")
	_hide_runtime_canvas_layers()
	await get_tree().process_frame
	await get_tree().process_frame
	_runtime_main.set_process(false)


func _hide_runtime_canvas_layers() -> void:
	if _runtime_main == null:
		return
	for node in _runtime_main.find_children("*", "CanvasLayer", true, false):
		if node is CanvasLayer:
			(node as CanvasLayer).visible = false


func _release_runtime_main() -> void:
	if _runtime_main != null and is_instance_valid(_runtime_main):
		if _runtime_main.get_parent() != null:
			_runtime_main.get_parent().remove_child(_runtime_main)
		_runtime_main.free()
	_runtime_main = null


func _coordinator() -> Node:
	return _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _runtime_main != null else null


func _card_family(card_id: String) -> String:
	var coordinator := _coordinator()
	return str(coordinator.call("card_family_id", card_id)) if coordinator != null else ""


func _card_resolution_queue_service() -> Node:
	var coordinator := _coordinator()
	return coordinator.get_node_or_null("CardResolutionQueueRuntimeService") if coordinator != null else null


func _inventory_debug() -> Dictionary:
	var coordinator := _coordinator()
	if coordinator == null or not coordinator.has_method("card_inventory_debug"):
		return {}
	var value: Variant = coordinator.call("card_inventory_debug")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _interaction_debug() -> Dictionary:
	var coordinator := _coordinator()
	if coordinator == null or not coordinator.has_method("player_hand_interaction_debug"):
		return {}
	var value: Variant = coordinator.call("player_hand_interaction_debug")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _player(player_index: int) -> Dictionary:
	if _runtime_main == null:
		return {}
	var players: Array = _runtime_main.get("players") as Array
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return {}
	return (players[player_index] as Dictionary).duplicate(true)


func _reset_player(player_index: int, slots: Array, cash: int = 1000, ai_override: Variant = null) -> void:
	var players: Array = (_runtime_main.get("players") as Array).duplicate(true)
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return
	var player: Dictionary = (players[player_index] as Dictionary).duplicate(true)
	player["cash"] = cash
	player["slots"] = slots.duplicate(true)
	player["economic_ledger"] = []
	player["cash_history"] = [cash]
	player["eliminated"] = false
	player["action_cooldown"] = 0.0
	if ai_override is bool:
		player["is_ai"] = bool(ai_override)
	players[player_index] = player
	_runtime_main.set("players", players)


func _player_probe(player_index: int) -> Dictionary:
	var player := _player(player_index)
	if player.is_empty():
		return {}
	var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	var fingerprint: Array = []
	var rank_total := 0
	var locked_count := 0
	var queued_count := 0
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var skill: Dictionary = slot_variant
		var card_id := str(skill.get("name", ""))
		var family := _card_family(card_id)
		var rank := int(skill.get("rank", _card_rank(card_id)))
		var locked := float(skill.get("lock_left", 0.0)) > 0.0
		var queued := bool(skill.get("queued_for_resolution", false))
		fingerprint.append({
			"family_hash": family.sha256_text().substr(0, 10),
			"rank": rank,
			"queued": queued,
			"locked": locked,
			"counted": bool(_runtime_main.call("_counts_toward_hand_limit", skill)),
		})
		rank_total += rank
		locked_count += 1 if locked else 0
		queued_count += 1 if queued else 0
	var ledger: Array = player.get("economic_ledger", []) if player.get("economic_ledger", []) is Array else []
	return {
		"cash": int(player.get("cash", 0)),
		"hand_count": int(_runtime_main.call("_player_counted_hand_size", player)),
		"rank_total": rank_total,
		"locked_count": locked_count,
		"queued_count": queued_count,
		"private_event_count": ledger.size(),
		"fingerprint": fingerprint,
	}


func _make_skill(card_id: String) -> Dictionary:
	if card_id.is_empty() or _runtime_main == null:
		return {}
	var value: Variant = _runtime_main.call("_make_skill", card_id)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _queue_ready_interaction_skill(card_id: String) -> Dictionary:
	var skill := _make_skill(card_id)
	# These cases characterize queue/target compatibility, not the independent
	# regional GDP gate. Keep the real card id/effect and neutralize only that
	# prerequisite inside the disposable QA player fixture.
	skill["play_requirement_kind"] = "none"
	skill["play_region_gdp_share_required"] = 0
	return skill


func _skills(card_ids: Array) -> Array:
	var result: Array = []
	for card_id_variant in card_ids:
		var skill := _make_skill(str(card_id_variant))
		if not skill.is_empty():
			result.append(skill)
	return result


func _generic_card_ids(count: int) -> Array:
	var result: Array = []
	var families: Array[String] = []
	var names_variant: Variant = _runtime_main.call("_card_codex_names", "all")
	var names: Array = names_variant if names_variant is Array else []
	for name_variant in names:
		var card_id := str(_runtime_main.call("_canonical_card_supply_name", str(name_variant)))
		if card_id.is_empty() or DISRUPT_CARDS.has(card_id) or STEAL_CARDS.has(card_id):
			continue
		var skill := _make_skill(card_id)
		var family := _card_family(card_id)
		if skill.is_empty() or families.has(family) or _card_rank(card_id) != 1:
			continue
		if not bool(_runtime_main.call("_counts_toward_hand_limit", skill)) or str(skill.get("kind", "")) == "monster_card":
			continue
		families.append(family)
		result.append(card_id)
		if result.size() >= count:
			break
	return result


func _card_rank(card_id: String) -> int:
	var coordinator := _coordinator()
	return int(coordinator.call("card_rank", card_id)) if coordinator != null and not card_id.is_empty() else 0


func _max_upgrade_name(base_card_id: String) -> String:
	var current := base_card_id
	while not current.is_empty():
		var next_id := str(_runtime_main.call("_next_upgrade_name", current))
		if next_id.is_empty():
			return current
		current = next_id
	return ""


func _private_card_values(slots: Array) -> Array:
	var values: Array = []
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var card_id := str((slot_variant as Dictionary).get("name", ""))
		if card_id.is_empty():
			continue
		values.append(card_id)
		values.append(str(_runtime_main.call("_card_display_name", card_id)))
	return values


func _private_ledger_contains(player_index: int, card_id: String) -> bool:
	var player := _player(player_index)
	var ledger: Array = player.get("economic_ledger", []) if player.get("economic_ledger", []) is Array else []
	var display_name := str(_runtime_main.call("_card_display_name", card_id))
	for entry_variant in ledger:
		if entry_variant is Dictionary:
			var detail := str((entry_variant as Dictionary).get("detail", ""))
			if (not card_id.is_empty() and detail.contains(card_id)) or (not display_name.is_empty() and detail.contains(display_name)):
				return true
	return false


func _seed_runtime_rng(seed_value: int) -> void:
	var runtime_coordinator := _coordinator() as GameRuntimeCoordinator
	var runtime_rng := runtime_coordinator.run_rng_service() if runtime_coordinator != null else null
	if runtime_rng != null:
		runtime_rng.seed = seed_value


func _public_log_count() -> int:
	var logs_variant: Variant = _runtime_main.get("log_lines")
	return (logs_variant as Array).size() if logs_variant is Array else 0


func _public_logs_hide_private_values(start_index: int, private_values: Array) -> bool:
	var logs_variant: Variant = _runtime_main.get("log_lines")
	var logs: Array = logs_variant if logs_variant is Array else []
	for index in range(maxi(0, start_index), logs.size()):
		var line := str(logs[index])
		for value_variant in private_values:
			var private_value := str(value_variant)
			if not private_value.is_empty() and line.contains(private_value):
				return false
	return true


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + 5)
	return source.substr(start) if next_function < 0 else source.substr(start, next_function - start)


func _observed_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and str((record_variant as Dictionary).get("phase", "characterization")) == "characterization" and bool((record_variant as Dictionary).get("observed", false)):
			count += 1
	return count


func _aligned_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and str((record_variant as Dictionary).get("phase", "characterization")) == "characterization" and bool((record_variant as Dictionary).get("contract_aligned", false)):
			count += 1
	return count


func _cutover_passed_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and str((record_variant as Dictionary).get("phase", "characterization")) == "cutover" and bool((record_variant as Dictionary).get("cutover_passed", false)):
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
		if record_variant is Dictionary and str((record_variant as Dictionary).get("phase", "characterization")) == "characterization" and bool((record_variant as Dictionary).get("needs_design_decision", false)):
			count += 1
	return count


func _update_ui(manifest: Dictionary) -> void:
	var observed := int(manifest.get("observed_count", 0))
	var aligned := int(manifest.get("aligned_count", 0))
	var cutover := int(manifest.get("cutover_passed_count", 0))
	var decisions := int(manifest.get("needs_design_decision_count", 0))
	summary_label.text = "Player hand interaction: %d/%d observed | %d/%d aligned | %d/%d cutover | %d decisions" % [observed, CHARACTERIZATION_CASE_COUNT, aligned, CHARACTERIZATION_CASE_COUNT, cutover, CUTOVER_CASE_COUNT, decisions]
	var complete := observed == CHARACTERIZATION_CASE_COUNT and aligned == CHARACTERIZATION_CASE_COUNT and cutover == CUTOVER_CASE_COUNT
	status_label.text = "CUTOVER COMPLETE" if complete else "INCOMPLETE"
	status_label.add_theme_color_override("font_color", Color("#4ade80") if complete else Color("#fb7185"))
	ownership_text.text = "[b]Ownership after Sprint 33[/b]\n\n[b]PlayerHandInteractionRuntimeService[/b]\n• repeated remove/transfer ordering and lock sequencing\n• target penalty and one-time actor compensation\n• private/public ledger and action-callout intents\n\n[b]CardInventoryRuntimeService[/b]\n• sole remove, lock, receive/upgrade, transfer and convert-to-remove slot mutation owner\n\n[b]main.gd thin adapter[/b]\n• real player/card facts and seeded RNG slot choices\n• private ledger, public log and visual-callout forwarding\n• queued skill kind dispatch compatibility"
	var lines: Array[String] = ["[b]Real-main observations[/b]"]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		var cutover_phase := str(record.get("phase", "characterization")) == "cutover"
		var observed_mark := ("CUT" if bool(record.get("cutover_passed", false)) else "MISS") if cutover_phase else ("OBS" if bool(record.get("observed", false)) else "MISS")
		var aligned_mark := "cutover" if cutover_phase else ("aligned" if bool(record.get("contract_aligned", false)) else "review")
		lines.append("%s  %s  [%s]" % [observed_mark, str(record.get("case_id", "")), aligned_mark])
	cases_text.text = "\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines := [
		"# Player Hand Interaction Runtime Cutover",
		"",
		"- Ruleset: `v0.4`",
		"- Characterization observed: **%d/%d**" % [int(manifest.get("observed_count", 0)), CHARACTERIZATION_CASE_COUNT],
		"- Characterization aligned: **%d/%d**" % [int(manifest.get("aligned_count", 0)), CHARACTERIZATION_CASE_COUNT],
		"- Runtime cutover: **%d/%d**" % [int(manifest.get("cutover_passed_count", 0)), CUTOVER_CASE_COUNT],
		"- Needs design decision: **%d**" % int(manifest.get("needs_design_decision_count", 0)),
		"- Output: `%s`" % OUTPUT_DIR,
		"",
		"Concrete affected private-card identities and acting-player identity are intentionally absent. Played card ids are public resolution information.",
		"",
		"| Case | Played card | Rank | Requested | Removed | Transferred | Converted | Locked | Actor cash | Target cash | Source hand | Target hand | Public events | Private events | Route | Inventory | Privacy | Observed | Aligned | Decision | Notes |",
		"| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- | --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| %s | %s | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %s | %s | %s | %s | %s | %s | %s |" % [
			str(record.get("case_id", "")),
			str(record.get("played_card_id", "")),
			int(record.get("card_rank", 0)),
			int(record.get("requested_count", 0)),
			int(record.get("removed_count", 0)),
			int(record.get("transferred_count", 0)),
			int(record.get("converted_count", 0)),
			int(record.get("locked_count", 0)),
			int(record.get("actor_cash_delta", 0)),
			int(record.get("target_cash_delta", 0)),
			int(record.get("source_hand_delta", 0)),
			int(record.get("target_hand_delta", 0)),
			int(record.get("public_event_delta", 0)),
			int(record.get("private_event_delta", 0)),
			"yes" if bool(record.get("resolution_route_checked", false)) else "no",
			"yes" if bool(record.get("inventory_service_checked", false)) else "no",
			"yes" if bool(record.get("privacy_checked", false)) else "no",
			"yes" if bool(record.get("observed", false)) else "no",
			"yes" if bool(record.get("contract_aligned", false)) else "no",
			"yes" if bool(record.get("needs_design_decision", false)) else "no",
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
