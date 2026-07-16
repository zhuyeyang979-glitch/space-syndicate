extends Control
class_name CardResolutionQueueRuntimeCharacterizationBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/card_resolution_runtime_controller.gd"
const QUEUE_SERVICE_SCENE_PATH := "res://scenes/runtime/CardResolutionQueueRuntimeService.tscn"
const QUEUE_SERVICE_SCRIPT_PATH := "res://scripts/runtime/card_resolution_queue_runtime_service.gd"
const INVENTORY_SERVICE_SCRIPT_PATH := "res://scripts/runtime/card_inventory_runtime_service.gd"
const COORDINATOR_SCRIPT_PATH := "res://scripts/runtime/game_runtime_coordinator.gd"
const SHARED_WINDOW_SCRIPT_PATH := "res://scripts/cards/shared_card_group_window.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/card_resolution_queue_characterization/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/card_resolution_queue_runtime_cutover_sprint_35.png"
const PRE_CUTOVER_MAIN_SHA256 := "CF4DE493ECEEFF6C88D5F4CB919DB477B6CDDA5104D2AFA8BBC9D946FD044050"
const CHARACTERIZATION_CASE_COUNT := 28
const CUTOVER_CASE_COUNT := 28
const CASE_COUNT := CHARACTERIZATION_CASE_COUNT + CUTOVER_CASE_COUNT
const BASE_CARD_ID := "轨道融资1"
const COUNTER_CARD_ID := "相位否决1"
const INTERACTION_CARD_ID := "星链拆解1"

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
	print("CardResolutionQueueRuntimeCharacterizationBench ready: auto_run=%s editor_hint=%s" % [auto_run, Engine.is_editor_hint()])
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_characterization_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func characterization_cases() -> Array:
	return [
		"queue_call_graph_complete",
		"timing_controller_boundary_unchanged",
		"first_submit_starts_batch",
		"same_player_group_order_one_to_two",
		"third_card_rejected_without_mutation",
		"duplicate_card_submit_rejected",
		"organize_phase_accepts_submission",
		"lock_phase_rejects_new_cards",
		"persistent_card_stays_and_marks_queued",
		"consumable_card_leaves_slot_on_queue",
		"play_cost_paid_exactly_once",
		"insufficient_cost_and_bid_rejects_atomically",
		"equal_fixed_bids_are_allowed",
		"arbitrary_priority_bid_rejected",
		"fixed_bid_tiers_sort_descending",
		"equal_bid_uses_clockwise_reference",
		"player_group_remains_contiguous",
		"lock_writes_batch_position_and_priority_bid",
		"start_next_pops_one_active_entry",
		"invalid_entry_skips_without_stall",
		"active_resolution_blocks_normal_submission",
		"counter_routes_to_next_queue",
		"one_counter_per_player_per_window",
		"finish_batch_promotes_next_queue",
		"promotion_rewrites_window_group_and_order",
		"current_queue_save_load_parity",
		"active_and_next_queue_save_load_parity",
		"public_snapshot_privacy_boundary",
	]


func cutover_cases() -> Array:
	return [
		"service_scene_composition",
		"coordinator_composes_service",
		"service_configured_v05_domain",
		"service_owns_current_queue",
		"service_owns_active_entry",
		"service_owns_next_queue",
		"service_owns_resolution_sequence",
		"service_submission_plan_pure",
		"service_submission_commit",
		"inventory_service_owns_queue_slot_mutation",
		"submission_adapter_uses_both_services",
		"third_card_atomic_via_service",
		"duplicate_submission_atomic_via_service",
		"equal_fixed_bids_service",
		"group_sort_service",
		"lock_metadata_service",
		"public_wager_pool_receipt_service",
		"start_next_service",
		"invalid_skip_service",
		"counter_route_service",
		"active_complete_service",
		"next_promotion_service",
		"legacy_save_service",
		"public_debug_privacy",
		"timing_controller_still_sole_owner",
		"card_effect_resolver_unchanged",
		"main_queue_storage_absent",
		"legacy_queue_algorithms_absent",
	]


func all_cases() -> Array:
	var result := characterization_cases()
	result.append_array(cutover_cases())
	return result


func build_characterization_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in all_cases():
		records.append(_record(str(case_id_variant), "preview", {}, {
			"observed": false,
			"contract_aligned": false,
			"notes": "preview",
		}))
	return {
		"suite": "card-resolution-queue-runtime-cutover-v05",
		"ruleset_id": "v0.5",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"main_scene": MAIN_SCENE_PATH,
		"pre_cutover_main_sha256": PRE_CUTOVER_MAIN_SHA256,
		"characterization_case_count": CHARACTERIZATION_CASE_COUNT,
		"cutover_case_count": CUTOVER_CASE_COUNT,
		"case_count": CASE_COUNT,
		"record_count": records.size(),
		"observed_count": 0,
		"aligned_count": 0,
		"needs_design_decision_count": 0,
		"records": records,
	}


func run_characterization_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	if not await _ensure_runtime_main():
		push_error("CardResolutionQueueRuntimeCharacterizationBench could not instantiate real main.tscn")
		if DisplayServer.get_name() == "headless":
			get_tree().quit(1)
		return
	var main_sha256 := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH).sha256_text().to_upper()
	for case_id_variant in all_cases():
		var case_id := str(case_id_variant)
		await _reset_runtime_main()
		var record := _run_case(case_id)
		record["pure_data_checked"] = _is_data_only(record) and not _contains_runtime_object(record)
		record["passed"] = bool(record.get("observed", false)) and bool(record.get("contract_aligned", false)) and bool(record.get("pure_data_checked", false))
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "observation failed"))])
	var manifest := {
		"suite": "card-resolution-queue-runtime-cutover-v05",
		"ruleset_id": "v0.5",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"main_scene": MAIN_SCENE_PATH,
		"pre_cutover_main_sha256": PRE_CUTOVER_MAIN_SHA256,
		"actual_main_sha256": main_sha256,
		"main_changed_by_cutover": main_sha256 != PRE_CUTOVER_MAIN_SHA256,
		"characterization_case_count": CHARACTERIZATION_CASE_COUNT,
		"cutover_case_count": CUTOVER_CASE_COUNT,
		"case_count": CASE_COUNT,
		"record_count": _records.size(),
		"observed_count": _observed_count(),
		"aligned_count": _aligned_count(),
		"mismatch_count": CASE_COUNT - _aligned_count(),
		"needs_design_decision_count": _design_decision_count(),
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("CardResolutionQueueRuntimeCharacterizationBench manifest: %s" % MANIFEST_PATH)
	print("CardResolutionQueueRuntimeCharacterizationBench report: %s" % REPORT_PATH)
	print("CardResolutionQueueRuntimeCharacterizationBench screenshot: %s" % SCREENSHOT_PATH)
	print("CardResolutionQueueRuntimeCharacterizationBench characterization: %d/%d" % [_passed_count_for(characterization_cases()), CHARACTERIZATION_CASE_COUNT])
	print("CardResolutionQueueRuntimeCharacterizationBench cutover: %d/%d" % [_passed_count_for(cutover_cases()), CUTOVER_CASE_COUNT])
	print("CardResolutionQueueRuntimeCharacterizationBench total: %d/%d; observed=%d; aligned=%d; design_decisions=%d" % [_passed_count(), CASE_COUNT, _observed_count(), _aligned_count(), _design_decision_count()])
	if not _failures.is_empty():
		push_error("CardResolutionQueueRuntimeCharacterizationBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		await _release_runtime_main()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().quit(0 if _failures.is_empty() else 1)


func _run_case(case_id: String) -> Dictionary:
	match case_id:
		"queue_call_graph_complete":
			return _case_queue_call_graph_complete()
		"timing_controller_boundary_unchanged":
			return _case_timing_controller_boundary_unchanged()
		"first_submit_starts_batch":
			return _case_first_submit_starts_batch()
		"same_player_group_order_one_to_two":
			return _case_same_player_group_order_one_to_two()
		"third_card_rejected_without_mutation":
			return _case_third_card_rejected_without_mutation()
		"duplicate_card_submit_rejected":
			return _case_duplicate_card_submit_rejected()
		"organize_phase_accepts_submission":
			return _case_organize_phase_accepts_submission()
		"lock_phase_rejects_new_cards":
			return _case_lock_phase_rejects_new_cards()
		"persistent_card_stays_and_marks_queued":
			return _case_persistent_card_stays_and_marks_queued()
		"consumable_card_leaves_slot_on_queue":
			return _case_consumable_card_leaves_slot_on_queue()
		"play_cost_paid_exactly_once":
			return _case_play_cost_paid_exactly_once()
		"insufficient_cost_and_bid_rejects_atomically":
			return _case_insufficient_cost_and_bid_rejects_atomically()
		"equal_fixed_bids_are_allowed":
			return _case_equal_fixed_bids_are_allowed()
		"arbitrary_priority_bid_rejected":
			return _case_arbitrary_priority_bid_rejected()
		"fixed_bid_tiers_sort_descending":
			return _case_fixed_bid_tiers_sort_descending()
		"equal_bid_uses_clockwise_reference":
			return _case_equal_bid_uses_clockwise_reference()
		"player_group_remains_contiguous":
			return _case_player_group_remains_contiguous()
		"lock_writes_batch_position_and_priority_bid":
			return _case_lock_writes_batch_position_and_priority_bid()
		"start_next_pops_one_active_entry":
			return _case_start_next_pops_one_active_entry()
		"invalid_entry_skips_without_stall":
			return _case_invalid_entry_skips_without_stall()
		"active_resolution_blocks_normal_submission":
			return _case_active_resolution_blocks_normal_submission()
		"counter_routes_to_next_queue":
			return _case_counter_routes_to_next_queue()
		"one_counter_per_player_per_window":
			return _case_one_counter_per_player_per_window()
		"finish_batch_promotes_next_queue":
			return _case_finish_batch_promotes_next_queue()
		"promotion_rewrites_window_group_and_order":
			return _case_promotion_rewrites_window_group_and_order()
		"current_queue_save_load_parity":
			return _case_current_queue_save_load_parity()
		"active_and_next_queue_save_load_parity":
			return _case_active_and_next_queue_save_load_parity()
		"public_snapshot_privacy_boundary":
			return _case_public_snapshot_privacy_boundary()
	if cutover_cases().has(case_id):
		return _run_cutover_case(case_id)
	return _record(case_id, "unknown", {}, {"observed": false, "contract_aligned": false, "risk": "unknown case", "notes": "unknown characterization case"})


func _case_queue_call_graph_complete() -> Dictionary:
	var main_source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var controller_source := FileAccess.get_file_as_string(CONTROLLER_SCRIPT_PATH)
	var service_source := FileAccess.get_file_as_string(QUEUE_SERVICE_SCRIPT_PATH)
	var queue_submit := _function_source(main_source, "_queue_skill_resolution")
	var queue_lock := _function_source(main_source, "_lock_card_resolution_batch")
	var queue_start := _function_source(main_source, "_start_next_card_resolution")
	var queue_finish := _function_source(main_source, "_finish_card_resolution_batch")
	var queue_promote := _function_source(main_source, "_promote_next_card_resolution_batch")
	var effect_adapter := _function_source(main_source, "_apply_card_resolution_effect_request")
	var observed := not queue_submit.is_empty() and not queue_lock.is_empty() and not queue_start.is_empty() and not queue_finish.is_empty() and not queue_promote.is_empty() and not effect_adapter.is_empty()
	var aligned := observed and not main_source.contains("var card_resolution_queue := []") and not main_source.contains("var next_card_resolution_queue := []") and not main_source.contains("var active_card_resolution := {}") and queue_submit.contains("plan_card_resolution_queue_submission") and queue_submit.contains("commit_card_resolution_queue_submission") and queue_lock.contains("service.call(\"lock_batch\"") and queue_start.contains("service.call(\"start_next\"") and queue_promote.contains("service.call(\"promote_next_batch\"") and service_source.contains("var _current_queue: Array = []") and service_source.contains("var _next_queue: Array = []") and service_source.contains("var _active_entry: Dictionary = {}") and not controller_source.contains("var _current_queue")
	return _record("queue_call_graph_complete", "source-audit", {}, {
		"observed": observed,
		"contract_aligned": aligned,
		"ordering_checked": aligned,
		"service_owner_checked": aligned,
		"main_adapter_checked": aligned,
		"legacy_formula_absent": aligned,
		"notes": "CardResolutionQueueRuntimeService owns current/next/active containers and queue lifecycle; main.gd is a world/inventory/event adapter while the controller owns timing only.",
	})


func _case_timing_controller_boundary_unchanged() -> Dictionary:
	var controller := _controller()
	var controller_source := FileAccess.get_file_as_string(CONTROLLER_SCRIPT_PATH)
	var shared_window_source := FileAccess.get_file_as_string(SHARED_WINDOW_SCRIPT_PATH)
	var main_source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var observed := controller != null and controller.has_method("tick") and controller.has_method("current_phase") and controller.has_method("to_save_data") and controller.has_method("apply_save_data")
	var aligned := observed and controller_source.contains("total_window_seconds") and controller_source.contains("lock_seconds") and shared_window_source.contains("const TOTAL_SECONDS := 8.0") and shared_window_source.contains("const ORGANIZE_SECONDS := 6.0") and shared_window_source.contains("const LOCK_SECONDS := 2.0") and not controller_source.contains("func _apply_card_resolution_effect_request") and main_source.contains("func _apply_card_resolution_effect_request")
	return _record("timing_controller_boundary_unchanged", "CardResolutionRuntimeController", {}, {
		"observed": observed,
		"contract_aligned": aligned,
		"timing_boundary_checked": aligned,
		"notes": "CardResolutionRuntimeController remains the sole 8/6/2 timing owner and does not execute queue entries or card effects.",
	})


func _case_first_submit_starts_batch() -> Dictionary:
	_prepare_players([[ _qa_skill() ]], [1000])
	var accepted := _submit(0, 0)
	var queue := _queue()
	var entry: Dictionary = queue[0] if not queue.is_empty() and queue[0] is Dictionary else {}
	var observed := accepted and queue.size() == 1
	var aligned := observed and int(_runtime_main.get("card_resolution_batch_reference_player")) == 0 and float(_runtime_main.get("card_resolution_simultaneous_timer")) > 6.0 and int(entry.get("group_order", 0)) == 1 and int(entry.get("window_sequence", 0)) == 1 and not str(entry.get("group_id", "")).is_empty()
	return _record("first_submit_starts_batch", BASE_CARD_ID, _queue_metrics(accepted), {
		"observed": observed,
		"contract_aligned": aligned,
		"ordering_checked": aligned,
		"timing_boundary_checked": float(_runtime_main.get("card_resolution_simultaneous_timer")) > 6.0,
		"notes": "The first committed card starts one 8-second batch, establishes the reference seat, and enters group order 1.",
	})


func _case_same_player_group_order_one_to_two() -> Dictionary:
	_prepare_players([_skills(3)], [1000])
	var accepted := _submit(0, 0) and _submit(0, 1)
	var orders: Array = []
	for entry_variant in _queue():
		if entry_variant is Dictionary:
			orders.append(int((entry_variant as Dictionary).get("group_order", 0)))
	var aligned := accepted and orders == [1, 2] and _group_ids().size() == 1
	return _record("same_player_group_order_one_to_two", BASE_CARD_ID, _queue_metrics(accepted), {
		"observed": accepted and _queue().size() == 2,
		"contract_aligned": aligned,
		"ordering_checked": aligned,
		"notes": "One player contributes a contiguous one-to-two-card ordered group in a standard shared window.",
	})


func _case_third_card_rejected_without_mutation() -> Dictionary:
	_prepare_players([_skills(3)], [1000])
	_submit(0, 0)
	_submit(0, 1)
	var cash_before := _player_cash(0)
	var hand_before := _hand_count(0)
	var queue_before := _queue().duplicate(true)
	var accepted := _submit(0, 2)
	var aligned := not accepted and _player_cash(0) == cash_before and _hand_count(0) == hand_before and _queue() == queue_before and _slot_is_card(0, 2)
	return _record("third_card_rejected_without_mutation", BASE_CARD_ID, _queue_metrics(accepted, _player_cash(0) - cash_before, _hand_count(0) - hand_before), {
		"observed": _queue().size() == 2,
		"contract_aligned": aligned,
		"notes": "The standard third card is rejected atomically and remains in the private hand.",
	})


func _case_duplicate_card_submit_rejected() -> Dictionary:
	_prepare_players([[ _qa_skill({"persistent": true}) ]], [1000])
	var first := _submit(0, 0)
	var cash_before := _player_cash(0)
	var second := _submit(0, 0)
	var aligned := first and not second and _queue().size() == 1 and _slot_queued(0, 0) and _player_cash(0) == cash_before
	return _record("duplicate_card_submit_rejected", BASE_CARD_ID, _queue_metrics(second), {
		"observed": first and _queue().size() == 1,
		"contract_aligned": aligned,
		"notes": "A persistent card already marked queued cannot be submitted twice.",
	})


func _case_organize_phase_accepts_submission() -> Dictionary:
	_prepare_players([[ _qa_skill() ], [ _qa_skill() ]], [1000, 1000])
	var first := _submit(0, 0)
	_runtime_main.set("card_resolution_simultaneous_timer", 4.0)
	var second := _submit(1, 0)
	var aligned := first and second and _queue().size() == 2 and str(_runtime_main.call("_card_group_window_phase")) == "organize"
	return _record("organize_phase_accepts_submission", BASE_CARD_ID, _queue_metrics(second), {
		"observed": first and _queue().size() >= 1,
		"contract_aligned": aligned,
		"timing_boundary_checked": str(_runtime_main.call("_card_group_window_phase")) == "organize",
		"notes": "A second player can commit a card during the six-second organize phase.",
	})


func _case_lock_phase_rejects_new_cards() -> Dictionary:
	_prepare_players([[ _qa_skill() ], [ _qa_skill() ]], [1000, 1000])
	_submit(0, 0)
	_runtime_main.set("card_resolution_simultaneous_timer", 2.0)
	var cash_before := _player_cash(1)
	var hand_before := _hand_count(1)
	var accepted := _submit(1, 0)
	var aligned := not accepted and _queue().size() == 1 and _player_cash(1) == cash_before and _hand_count(1) == hand_before and _slot_is_card(1, 0)
	return _record("lock_phase_rejects_new_cards", BASE_CARD_ID, _queue_metrics(accepted, _player_cash(1) - cash_before, _hand_count(1) - hand_before), {
		"observed": _queue().size() == 1,
		"contract_aligned": aligned,
		"timing_boundary_checked": str(_runtime_main.call("_card_group_window_phase")) == "lock",
		"notes": "At two seconds the card stays in hand and no cash or queue state changes.",
	})


func _case_persistent_card_stays_and_marks_queued() -> Dictionary:
	_prepare_players([[ _qa_skill({"persistent": true}) ]], [1000])
	var accepted := _submit(0, 0)
	var entry := _first_queue_entry()
	var aligned := accepted and _slot_is_card(0, 0) and _slot_queued(0, 0) and not bool(entry.get("consumed_on_queue", true))
	return _record("persistent_card_stays_and_marks_queued", BASE_CARD_ID, _queue_metrics(accepted), {
		"observed": accepted,
		"contract_aligned": aligned,
		"ordering_checked": aligned,
		"notes": "A persistent card remains in its slot with queued_for_resolution=true.",
	})


func _case_consumable_card_leaves_slot_on_queue() -> Dictionary:
	_prepare_players([[ _qa_skill({"persistent": false}) ]], [1000])
	var accepted := _submit(0, 0)
	var entry := _first_queue_entry()
	var aligned := accepted and not _slot_is_card(0, 0) and bool(entry.get("consumed_on_queue", false)) and bool((entry.get("skill", {}) as Dictionary).get("queued_for_resolution", false))
	return _record("consumable_card_leaves_slot_on_queue", BASE_CARD_ID, _queue_metrics(accepted, 0, _hand_count(0) - 1), {
		"observed": accepted,
		"contract_aligned": aligned,
		"ordering_checked": aligned,
		"notes": "A one-use card is removed from the hand at commitment while its queued snapshot keeps the flag.",
	})


func _case_play_cost_paid_exactly_once() -> Dictionary:
	_prepare_players([[ _qa_skill({"play_cash": 100}) ]], [1000])
	var accepted := _submit(0, 0)
	var after_submit := _player_cash(0)
	var entry := _first_queue_entry()
	var queued_skill: Dictionary = entry.get("skill", {}) if entry.get("skill", {}) is Dictionary else {}
	if bool(entry.get("play_cost_paid_on_queue", false)):
		queued_skill["_play_cost_paid_on_queue"] = true
	_runtime_main.call("_finish_played_skill", 0, -1, queued_skill, 0.0)
	var after_finish := _player_cash(0)
	var aligned := accepted and after_submit == 900 and after_finish == 900 and bool(entry.get("play_cost_paid_on_queue", false)) and int(entry.get("play_cash_cost_cents", 0)) == 10000
	return _record("play_cost_paid_exactly_once", BASE_CARD_ID, _queue_metrics(accepted, after_submit - 1000, _hand_count(0) - 1), {
		"observed": accepted and after_submit < 1000,
		"contract_aligned": aligned,
		"notes": "The action fee is charged at commitment and resolution cleanup does not charge it again.",
	})


func _case_insufficient_cost_and_bid_rejects_atomically() -> Dictionary:
	_prepare_players([[ _qa_skill({"play_cash": 80}) ]], [100])
	_set_player_field(0, "queued_card_tip", 50)
	var accepted := _submit(0, 0)
	var aligned := not accepted and _player_cash(0) == 100 and _hand_count(0) == 1 and _queue().is_empty() and _slot_is_card(0, 0)
	return _record("insufficient_cost_and_bid_rejects_atomically", BASE_CARD_ID, _queue_metrics(accepted, _player_cash(0) - 100, _hand_count(0) - 1), {
		"observed": not accepted,
		"contract_aligned": aligned,
		"notes": "A player who cannot reserve both action fee and group bid keeps cash, hand, and queue unchanged.",
	})


func _case_equal_fixed_bids_are_allowed() -> Dictionary:
	_prepare_players([[ _qa_skill() ], [ _qa_skill() ]], [1000, 1000])
	_set_player_field(0, "queued_card_tip", 100)
	_set_player_field(1, "queued_card_tip", 100)
	var first := _submit(0, 0)
	var second := _submit(1, 0)
	var second_entry := _queue_entry_for_player(1)
	var aligned := first and second and int(_queue_entry_for_player(0).get("priority_bid_cents", 0)) == 10000 and int(second_entry.get("priority_bid_cents", -1)) == 10000
	return _record("equal_fixed_bids_are_allowed", BASE_CARD_ID, _queue_metrics(second), {
		"observed": first and second,
		"contract_aligned": aligned,
		"ordering_checked": aligned,
		"notes": "Multiple groups may use the same fixed priority tier; clockwise seat order breaks the tie.",
	})


func _case_arbitrary_priority_bid_rejected() -> Dictionary:
	var service := _queue_service()
	var request := _submission_request()
	request["priority_bid_cents"] = 7500
	var plan_variant: Variant = service.call("plan_submission", request, _submission_facts()) if service != null else {}
	var plan: Dictionary = plan_variant if plan_variant is Dictionary else {}
	var aligned := not bool(plan.get("accepted", false)) and str(plan.get("reason", "")) == "invalid_priority_bid" and (plan.get("allowed_bid_options_cents", []) as Array) == [0, 5000, 10000]
	return _record("arbitrary_priority_bid_rejected", "7500-cents", _queue_metrics(false), {
		"observed": not plan.is_empty(),
		"contract_aligned": aligned,
		"ordering_checked": aligned,
		"notes": "The queue rejects arbitrary bids instead of normalizing them into a hidden tier.",
	})


func _case_fixed_bid_tiers_sort_descending() -> Dictionary:
	_prepare_players([[], [], []], [1000, 1000, 1000])
	_runtime_main.set("card_resolution_batch_reference_player", 3)
	_runtime_main.set("card_resolution_queue", [_entry(2, 3, 0, 1), _entry(0, 1, 10000, 1), _entry(1, 2, 5000, 1)])
	_runtime_main.call("_sort_card_resolution_queue")
	var players_in_order := _queue_player_order()
	var aligned := players_in_order == [0, 1, 2]
	return _record("fixed_bid_tiers_sort_descending", "10000-5000-0-cents", _queue_metrics(true), {
		"observed": players_in_order.size() == 3,
		"contract_aligned": aligned,
		"ordering_checked": aligned,
		"notes": "The fixed 100/50/0 cash tiers sort descending before clockwise tie-breaking.",
	})


func _case_equal_bid_uses_clockwise_reference() -> Dictionary:
	_prepare_players([[], [], [], []], [1000, 1000, 1000, 1000])
	_runtime_main.set("card_resolution_batch_reference_player", 3)
	_runtime_main.set("card_resolution_queue", [_entry(2, 3, 0, 1), _entry(3, 4, 0, 1), _entry(1, 2, 0, 1), _entry(0, 1, 0, 1)])
	_runtime_main.call("_sort_card_resolution_queue")
	var players_in_order := _queue_player_order()
	var aligned := players_in_order == [0, 1, 2, 3]
	return _record("equal_bid_uses_clockwise_reference", "zero-bid-clockwise", _queue_metrics(true), {
		"observed": players_in_order.size() == 4,
		"contract_aligned": aligned,
		"ordering_checked": aligned,
		"notes": "Zero-bid groups follow clockwise seat distance after reference seat 3.",
	})


func _case_player_group_remains_contiguous() -> Dictionary:
	_prepare_players([[], [], []], [1000, 1000, 1000])
	_runtime_main.set("card_resolution_batch_reference_player", 2)
	_runtime_main.set("card_resolution_queue", [_entry(0, 1, 10000, 2), _entry(1, 3, 5000, 1), _entry(0, 2, 10000, 1), _entry(2, 4, 0, 1)])
	_runtime_main.call("_sort_card_resolution_queue")
	var sorted := _queue()
	var aligned := sorted.size() == 4 and int((sorted[0] as Dictionary).get("player_index", -1)) == 0 and int((sorted[1] as Dictionary).get("player_index", -1)) == 0 and int((sorted[0] as Dictionary).get("group_order", 0)) == 1 and int((sorted[1] as Dictionary).get("group_order", 0)) == 2
	return _record("player_group_remains_contiguous", "two-card-group", _queue_metrics(true), {
		"observed": sorted.size() == 4,
		"contract_aligned": aligned,
		"ordering_checked": aligned,
		"notes": "A player's cards remain contiguous and respect authored group order.",
	})


func _case_lock_writes_batch_position_and_priority_bid() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	_runtime_main.set("card_resolution_batch_reference_player", 1)
	_runtime_main.set("card_resolution_queue", [_entry(0, 1, 0, 1), _entry(1, 2, 0, 1)])
	_runtime_main.call("_lock_card_resolution_batch")
	var entries: Array = []
	var active := _active_entry()
	if not active.is_empty():
		entries.append(active)
	entries.append_array(_queue())
	var annotations_ok := entries.size() == 2
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		annotations_ok = annotations_ok and int(entry.get("batch_position", 0)) == index + 1 and entry.has("locked_priority_bid_cents")
	var aligned := bool(_runtime_main.get("card_resolution_batch_locked")) and not active.is_empty() and annotations_ok
	return _record("lock_writes_batch_position_and_priority_bid", "two-zero-bid-groups", _queue_metrics(true), {
		"observed": entries.size() == 2,
		"contract_aligned": aligned,
		"ordering_checked": annotations_ok,
		"timing_boundary_checked": float(_runtime_main.get("card_resolution_simultaneous_timer")) == 0.0,
		"notes": "Closing the shared window locks fixed priority-bid and position metadata, then immediately promotes one entry to active.",
	})


func _case_start_next_pops_one_active_entry() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	_runtime_main.set("card_resolution_batch_locked", true)
	_runtime_main.set("card_resolution_queue", [_entry(0, 11, 0, 1), _entry(1, 12, 0, 1)])
	_runtime_main.call("_start_next_card_resolution")
	var active := _active_entry()
	var aligned := int(active.get("resolution_id", -1)) == 11 and _queue().size() == 1 and int((_queue()[0] as Dictionary).get("resolution_id", -1)) == 12
	return _record("start_next_pops_one_active_entry", "two-entry-pop", _queue_metrics(true), {
		"observed": not active.is_empty(),
		"contract_aligned": aligned,
		"ordering_checked": aligned,
		"notes": "Starting resolution pops exactly one front entry into active state.",
	})


func _case_invalid_entry_skips_without_stall() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	var invalid_entry := _entry(0, 21, 0, 1)
	invalid_entry["skill"] = {}
	_runtime_main.set("card_resolution_batch_locked", true)
	_runtime_main.set("card_resolution_queue", [invalid_entry, _entry(1, 22, 0, 1)])
	_runtime_main.call("_start_next_card_resolution")
	var active := _active_entry()
	var aligned := int(active.get("resolution_id", -1)) == 22 and _queue().is_empty()
	return _record("invalid_entry_skips_without_stall", "invalid-then-valid", _queue_metrics(true), {
		"observed": not active.is_empty(),
		"contract_aligned": aligned,
		"ordering_checked": aligned,
		"notes": "An entry without a usable card snapshot is skipped and the next valid card starts.",
	})


func _case_active_resolution_blocks_normal_submission() -> Dictionary:
	_prepare_players([[ _qa_skill() ], []], [1000, 1000])
	_runtime_main.set("card_resolution_batch_locked", true)
	_runtime_main.set("active_card_resolution", _entry(1, 31, 0, 1))
	var cash_before := _player_cash(0)
	var accepted := _submit(0, 0)
	var aligned := not accepted and _queue().is_empty() and _next_queue().is_empty() and _slot_is_card(0, 0) and _player_cash(0) == cash_before
	return _record("active_resolution_blocks_normal_submission", BASE_CARD_ID, _queue_metrics(accepted), {
		"observed": not _active_entry().is_empty(),
		"contract_aligned": aligned,
		"notes": "Normal cards cannot enter while a locked group is resolving; the card remains private and unspent.",
	})


func _case_counter_routes_to_next_queue() -> Dictionary:
	_prepare_counter_fixture(1)
	var accepted := _submit(1, 0)
	var next_entry: Dictionary = _next_queue()[0] if not _next_queue().is_empty() and _next_queue()[0] is Dictionary else {}
	var aligned := accepted and _queue().is_empty() and _next_queue().size() == 1 and bool(next_entry.get("queued_behind_resolution", false)) and str(next_entry.get("group_id", "")).begins_with("counter_")
	return _record("counter_routes_to_next_queue", COUNTER_CARD_ID, _queue_metrics(accepted), {
		"observed": accepted,
		"contract_aligned": aligned,
		"ordering_checked": aligned,
		"timing_boundary_checked": bool(_runtime_main.get("card_resolution_counter_window_active")),
		"notes": "A legal response card enters next_card_resolution_queue instead of interrupting active state directly.",
	})


func _case_one_counter_per_player_per_window() -> Dictionary:
	_prepare_counter_fixture(2)
	var first := _submit(1, 0)
	var cash_before := _player_cash(1)
	var second := _submit(1, 1)
	var aligned := first and not second and _next_queue().size() == 1 and _slot_is_card(1, 1) and _player_cash(1) == cash_before
	return _record("one_counter_per_player_per_window", COUNTER_CARD_ID, _queue_metrics(second), {
		"observed": first and _next_queue().size() == 1,
		"contract_aligned": aligned,
		"notes": "One player cannot submit a second response in the same five-second response window.",
	})


func _case_finish_batch_promotes_next_queue() -> Dictionary:
	_prepare_players([[], [], []], [1000, 1000, 1000])
	_runtime_main.set("last_card_resolution_player_index", 2)
	_runtime_main.set("card_resolution_batch_locked", true)
	_runtime_main.set("next_card_resolution_queue", [_next_entry(0, 41, 1), _next_entry(1, 42, 1)])
	_runtime_main.call("_finish_card_resolution_batch")
	var aligned := _next_queue().is_empty() and _queue().size() == 2 and _active_entry().is_empty() and not bool(_runtime_main.get("card_resolution_batch_locked")) and float(_runtime_main.get("card_resolution_simultaneous_timer")) > 6.0
	return _record("finish_batch_promotes_next_queue", "two-next-batch-cards", _queue_metrics(true), {
		"observed": _queue().size() == 2,
		"contract_aligned": aligned,
		"ordering_checked": aligned,
		"timing_boundary_checked": float(_runtime_main.get("card_resolution_simultaneous_timer")) > 6.0,
		"notes": "Finishing an empty active batch promotes all waiting response cards into a new organize window.",
	})


func _case_promotion_rewrites_window_group_and_order() -> Dictionary:
	_prepare_players([[], [], []], [1000, 1000, 1000])
	_runtime_main.set("game_time", 77.0)
	_runtime_main.set("card_group_window_sequence", 9)
	_runtime_main.set("next_card_resolution_queue", [_next_entry(0, 51, 1), _next_entry(0, 52, 2), _next_entry(1, 53, 1)])
	_runtime_main.call("_promote_next_card_resolution_batch", 2)
	var queue := _queue()
	var aligned := queue.size() == 3 and int(_runtime_main.get("card_group_window_sequence")) == 10
	var player_zero_orders: Array = []
	for entry_variant in queue:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		aligned = aligned and not bool(entry.get("queued_behind_resolution", true)) and is_equal_approx(float(entry.get("promoted_time", -1.0)), 77.0) and int(entry.get("window_sequence", 0)) == 10 and str(entry.get("group_id", "")).contains("10")
		if int(entry.get("player_index", -1)) == 0:
			player_zero_orders.append(int(entry.get("group_order", 0)))
	aligned = aligned and player_zero_orders == [1, 2]
	return _record("promotion_rewrites_window_group_and_order", "promoted-response-group", _queue_metrics(true), {
		"observed": queue.size() == 3,
		"contract_aligned": aligned,
		"ordering_checked": aligned,
		"notes": "Promotion clears queued-behind state and assigns a new window, group id, timestamp, and per-player order.",
	})


func _case_current_queue_save_load_parity() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	var expected_queue := [_entry(0, 61, 100, 1), _entry(1, 62, 0, 1)]
	_runtime_main.set("card_resolution_queue", expected_queue.duplicate(true))
	_runtime_main.set("card_resolution_batch_reference_player", 1)
	_runtime_main.set("card_resolution_simultaneous_timer", 17.0)
	var state_variant: Variant = _runtime_main.call("_capture_run_state")
	var state: Dictionary = state_variant if state_variant is Dictionary else {}
	_runtime_main.set("card_resolution_queue", [])
	var apply_error := int(_runtime_main.call("_apply_run_state", state)) if not state.is_empty() else ERR_INVALID_DATA
	var restored := _queue()
	var aligned := apply_error == OK and _resolution_ids(restored) == [61, 62] and int(_runtime_main.get("card_resolution_batch_reference_player")) == 1 and is_equal_approx(float(_runtime_main.get("card_resolution_simultaneous_timer")), 17.0)
	return _record("current_queue_save_load_parity", "legacy-save-current-queue", _queue_metrics(true), {
		"observed": not state.is_empty() and state.has("card_resolution_queue"),
		"contract_aligned": aligned,
		"save_checked": aligned,
		"notes": "Save version 1 round-trips current queue order and timing reference without a schema change.",
	})


func _case_active_and_next_queue_save_load_parity() -> Dictionary:
	_prepare_players([[], [], []], [1000, 1000, 1000])
	_runtime_main.set("active_card_resolution", _entry(0, 71, 100, 1))
	_runtime_main.set("next_card_resolution_queue", [_next_entry(1, 72, 1), _next_entry(2, 73, 1)])
	_runtime_main.set("card_resolution_batch_locked", true)
	_runtime_main.set("card_resolution_timer", 2.5)
	var state_variant: Variant = _runtime_main.call("_capture_run_state")
	var state: Dictionary = state_variant if state_variant is Dictionary else {}
	_runtime_main.set("active_card_resolution", {})
	_runtime_main.set("next_card_resolution_queue", [])
	var apply_error := int(_runtime_main.call("_apply_run_state", state)) if not state.is_empty() else ERR_INVALID_DATA
	var aligned := apply_error == OK and int(_active_entry().get("resolution_id", -1)) == 71 and _resolution_ids(_next_queue()) == [72, 73] and bool(_runtime_main.get("card_resolution_batch_locked")) and is_equal_approx(float(_runtime_main.get("card_resolution_timer")), 2.5)
	return _record("active_and_next_queue_save_load_parity", "legacy-save-active-next", _queue_metrics(true), {
		"observed": not state.is_empty() and state.has("active_card_resolution") and state.has("next_card_resolution_queue"),
		"contract_aligned": aligned,
		"save_checked": aligned,
		"notes": "Active and next-batch entries round-trip with locked/timer state through the existing save envelope.",
	})


func _case_public_snapshot_privacy_boundary() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	var entry := _entry(1, 81, 90, 1)
	entry["target_player"] = 0
	entry["contract_target_owner"] = 0
	entry["private_target"] = "PRIVATE_TARGET_MARKER"
	entry["private_discard"] = "PRIVATE_DISCARD_MARKER"
	entry["ai_private_plan"] = "AI_PRIVATE_PLAN_MARKER"
	_runtime_main.set("card_resolution_queue", [entry])
	var table_variant: Variant = _runtime_main.call("_runtime_table_snapshot")
	var table_snapshot: Dictionary = table_variant if table_variant is Dictionary else {}
	var snapshot: Dictionary = table_snapshot.get("card_resolution_track", {}) if table_snapshot.get("card_resolution_track", {}) is Dictionary else {}
	var serialized := str(snapshot)
	var forbidden_absent := not serialized.contains("PRIVATE_TARGET_MARKER") and not serialized.contains("PRIVATE_DISCARD_MARKER") and not serialized.contains("AI_PRIVATE_PLAN_MARKER") and not _contains_key_recursive(snapshot, "player_index") and not _contains_key_recursive(snapshot, "contract_target_owner")
	var entries: Array = snapshot.get("entries", []) if snapshot.get("entries", []) is Array else []
	var public_entry: Dictionary = entries[0] if not entries.is_empty() and entries[0] is Dictionary else {}
	var owner_hint := str(public_entry.get("owner_hint", ""))
	var aligned := not snapshot.is_empty() and forbidden_absent and not owner_hint.contains("玩家2") and str(snapshot.get("privacy_hint", "")).contains("隐藏归属")
	return _record("public_snapshot_privacy_boundary", "viewer-safe-public-track", _queue_metrics(true), {
		"observed": not snapshot.is_empty() and not entries.is_empty(),
		"contract_aligned": aligned,
		"privacy_checked": aligned,
		"notes": "Public track exposes card/group/bid clues while owner, private targets, discards, and AI plans stay absent.",
	})


func _run_cutover_case(case_id: String) -> Dictionary:
	match case_id:
		"service_scene_composition":
			return _case_service_scene_composition()
		"coordinator_composes_service":
			return _case_coordinator_composes_service()
		"service_configured_v05_domain":
			return _case_service_configured_v05_domain()
		"service_owns_current_queue":
			return _case_service_owns_state(case_id, "current")
		"service_owns_active_entry":
			return _case_service_owns_state(case_id, "active")
		"service_owns_next_queue":
			return _case_service_owns_state(case_id, "next")
		"service_owns_resolution_sequence":
			return _case_service_owns_state(case_id, "sequence")
		"service_submission_plan_pure":
			return _case_service_submission_plan_pure()
		"service_submission_commit":
			return _case_service_submission_commit()
		"inventory_service_owns_queue_slot_mutation":
			return _case_inventory_service_owns_queue_slot_mutation()
		"submission_adapter_uses_both_services":
			return _case_submission_adapter_uses_both_services()
		"third_card_atomic_via_service":
			return _cutover_behavior_record(case_id, "third_card_rejected_without_mutation")
		"duplicate_submission_atomic_via_service":
			return _cutover_behavior_record(case_id, "duplicate_card_submit_rejected")
		"equal_fixed_bids_service":
			return _cutover_behavior_record(case_id, "equal_fixed_bids_are_allowed")
		"group_sort_service":
			return _cutover_behavior_record(case_id, "fixed_bid_tiers_sort_descending")
		"lock_metadata_service":
			return _cutover_behavior_record(case_id, "lock_writes_batch_position_and_priority_bid")
		"public_wager_pool_receipt_service":
			return _case_public_wager_pool_receipt_service()
		"start_next_service":
			return _cutover_behavior_record(case_id, "start_next_pops_one_active_entry")
		"invalid_skip_service":
			return _cutover_behavior_record(case_id, "invalid_entry_skips_without_stall")
		"counter_route_service":
			return _cutover_behavior_record(case_id, "counter_routes_to_next_queue")
		"active_complete_service":
			return _case_active_complete_service()
		"next_promotion_service":
			return _cutover_behavior_record(case_id, "promotion_rewrites_window_group_and_order")
		"legacy_save_service":
			return _case_legacy_save_service()
		"public_debug_privacy":
			return _case_public_debug_privacy()
		"timing_controller_still_sole_owner":
			return _case_timing_controller_still_sole_owner()
		"card_effect_resolver_unchanged":
			return _case_card_effect_resolver_unchanged()
		"main_queue_storage_absent":
			return _case_main_queue_storage_absent()
		"legacy_queue_algorithms_absent":
			return _case_legacy_queue_algorithms_absent()
	return _record(case_id, "cutover-unknown", {}, {"observed": false, "contract_aligned": false, "notes": "unknown cutover case"})


func _case_service_scene_composition() -> Dictionary:
	var packed := load(QUEUE_SERVICE_SCENE_PATH) as PackedScene
	var instance := packed.instantiate() if packed != null else null
	var observed := instance != null
	var aligned := observed and instance.scene_file_path == QUEUE_SERVICE_SCENE_PATH \
		and instance.has_method("plan_submission") and instance.has_method("commit_submission") \
		and instance.has_method("lock_batch") and instance.has_method("start_next") \
		and instance.has_method("complete_active") and instance.has_method("promote_next_batch") \
		and instance.has_method("to_legacy_save_snapshot") and instance.has_method("debug_snapshot")
	if instance != null:
		instance.free()
	return _record("service_scene_composition", QUEUE_SERVICE_SCENE_PATH, {}, {
		"observed": observed,
		"contract_aligned": aligned,
		"service_owner_checked": aligned,
		"notes": "The editable runtime scene exposes the complete queue lifecycle API.",
	})


func _case_coordinator_composes_service() -> Dictionary:
	var service := _queue_service()
	var coordinator := _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var debug_variant: Variant = coordinator.call("debug_snapshot") if coordinator != null and coordinator.has_method("debug_snapshot") else {}
	var debug: Dictionary = debug_variant if debug_variant is Dictionary else {}
	var queue_debug: Dictionary = debug.get("card_resolution_queue", {}) if debug.get("card_resolution_queue", {}) is Dictionary else {}
	var observed := service != null and coordinator != null
	var aligned := observed and service.scene_file_path == QUEUE_SERVICE_SCENE_PATH and bool(queue_debug.get("service_ready", false)) and bool(queue_debug.get("service_authoritative", false))
	return _record("coordinator_composes_service", "GameRuntimeCoordinator", _queue_metrics(false), {
		"observed": observed,
		"contract_aligned": aligned,
		"service_owner_checked": aligned,
		"main_adapter_checked": coordinator.has_method("plan_card_resolution_queue_submission") and coordinator.has_method("commit_card_resolution_queue_submission") if coordinator != null else false,
		"notes": "GameRuntimeCoordinator statically composes and configures the queue service.",
	})


func _case_service_configured_v05_domain() -> Dictionary:
	var debug := _queue_service_debug()
	var aligned := bool(debug.get("service_ready", false)) and bool(debug.get("service_authoritative", false)) and str(debug.get("ruleset_id", "")) == "v0.5" and not bool(debug.get("timing_authority", true)) and not bool(debug.get("card_effect_authority", true)) and not bool(debug.get("inventory_authority", true))
	return _record("service_configured_v05_domain", "v0.5", _queue_metrics(false), {
		"observed": not debug.is_empty(),
		"contract_aligned": aligned,
		"service_owner_checked": aligned,
		"notes": "The service uses the v0.5 card-group domain while owning queue state only; timing, effects, inventory, and world cash remain outside its boundary.",
	})


func _case_service_owns_state(case_id: String, state_kind: String) -> Dictionary:
	var service := _queue_service()
	if service == null:
		return _record(case_id, state_kind, {}, {"observed": false, "contract_aligned": false, "notes": "queue service missing"})
	var resolution_id := 201
	match state_kind:
		"current":
			service.call("replace_current_queue", [_entry(0, resolution_id, 0, 1)])
		"active":
			service.call("replace_active_entry", _entry(0, resolution_id, 0, 1))
		"next":
			service.call("replace_next_queue", [_next_entry(0, resolution_id, 1)])
		"sequence":
			service.call("replace_resolution_sequence", resolution_id)
	var main_value: Variant
	var service_value: Variant
	match state_kind:
		"current":
			main_value = _runtime_main.get("card_resolution_queue")
			service_value = service.call("current_queue")
		"active":
			main_value = _runtime_main.get("active_card_resolution")
			service_value = service.call("active_entry")
		"next":
			main_value = _runtime_main.get("next_card_resolution_queue")
			service_value = service.call("next_queue")
		_:
			main_value = _runtime_main.get("card_resolution_sequence")
			service_value = service.call("resolution_sequence")
	var observed: bool = main_value == service_value
	var main_source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var aligned: bool = observed and not main_source.contains("var card_resolution_queue := []") and not main_source.contains("var next_card_resolution_queue := []") and not main_source.contains("var active_card_resolution := {}") and not main_source.contains("var card_resolution_sequence := 0")
	return _record(case_id, state_kind, _queue_metrics(false), {
		"observed": observed,
		"contract_aligned": aligned,
		"service_owner_checked": aligned,
		"main_adapter_checked": observed,
		"legacy_formula_absent": aligned,
		"notes": "Legacy property access reflects service state without a mirrored main.gd container.",
	})


func _submission_request() -> Dictionary:
	return {
		"player_index": 0,
		"slot_index": 0,
		"already_queued": false,
		"reactive_counter": false,
		"group_card_limit": 2,
		"priority_bid_cents": 0,
		"play_cash_cost_cents": 0,
		"available_cash_cents": 100000,
		"skill": _qa_skill(),
		"entry_context": {"queued_time": 1.0, "selected_district": 0},
	}


func _submission_facts() -> Dictionary:
	return {
		"player_count": 4,
		"counter_window_active": false,
		"batch_locked": false,
		"simultaneous_timer": 8.0,
		"lock_duration": 2.0,
		"window_sequence": 0,
		"reference_player": -1,
	}


func _case_service_submission_plan_pure() -> Dictionary:
	var service := _queue_service()
	var before := service.call("queue_state_snapshot") as Dictionary if service != null else {}
	var plan_variant: Variant = service.call("plan_submission", _submission_request(), _submission_facts()) if service != null else {}
	var plan: Dictionary = plan_variant if plan_variant is Dictionary else {}
	var after := service.call("queue_state_snapshot") as Dictionary if service != null else {}
	var pure := _is_data_only(plan) and not _contains_runtime_object(plan)
	var aligned := bool(plan.get("accepted", false)) and before == after and pure and int((plan.get("entry", {}) as Dictionary).get("resolution_id", -1)) == 1
	return _record("service_submission_plan_pure", BASE_CARD_ID, _queue_metrics(false), {
		"observed": not plan.is_empty(),
		"contract_aligned": aligned,
		"service_owner_checked": service != null,
		"plan_checked": aligned,
		"pure_data_checked": pure,
		"notes": "Planning is pure and allocates deterministic metadata without mutating queue state.",
	})


func _case_service_submission_commit() -> Dictionary:
	var service := _queue_service()
	var plan: Dictionary = service.call("plan_submission", _submission_request(), _submission_facts()) as Dictionary if service != null else {}
	var result: Dictionary = service.call("commit_submission", plan, {"authorized": true, "inventory_committed": true, "play_cost_authorized": true}) as Dictionary if service != null else {}
	var queue := service.call("current_queue") as Array if service != null else []
	var aligned := bool(result.get("committed", false)) and queue.size() == 1 and int((queue[0] as Dictionary).get("resolution_id", -1)) == 1 and int(service.call("resolution_sequence")) == 1
	return _record("service_submission_commit", BASE_CARD_ID, _queue_metrics(bool(result.get("committed", false))), {
		"observed": not result.is_empty(),
		"contract_aligned": aligned,
		"service_owner_checked": aligned,
		"plan_checked": bool(plan.get("accepted", false)),
		"commit_checked": aligned,
		"notes": "An authorized plan commits exactly one entry and advances the service-owned sequence once.",
	})


func _case_inventory_service_owns_queue_slot_mutation() -> Dictionary:
	_prepare_players([[ _qa_skill({"persistent": false}) ]], [1000])
	var accepted := _submit(0, 0)
	var coordinator := _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var inventory_debug: Dictionary = coordinator.call("card_inventory_debug") as Dictionary if coordinator != null else {}
	var queue_debug := _queue_service_debug()
	var aligned := accepted and not _slot_is_card(0, 0) and int(inventory_debug.get("queue_commit_plan_count", 0)) >= 1 and int(inventory_debug.get("queue_committed_count", 0)) == 1 and int(queue_debug.get("commit_count", 0)) == 1
	return _record("inventory_service_owns_queue_slot_mutation", BASE_CARD_ID, _queue_metrics(accepted), {
		"observed": accepted,
		"contract_aligned": aligned,
		"service_owner_checked": bool(queue_debug.get("service_authoritative", false)),
		"plan_checked": int(inventory_debug.get("queue_commit_plan_count", 0)) >= 1,
		"commit_checked": aligned,
		"notes": "CardInventoryRuntimeService removes or marks the slot; Queue Service only commits queue metadata.",
	})


func _case_submission_adapter_uses_both_services() -> Dictionary:
	var main_source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var adapter := _function_source(main_source, "_queue_skill_resolution")
	var aligned := adapter.contains("plan_card_resolution_queue_submission") and adapter.contains("commit_card_resolution_queue_submission") and adapter.contains("plan_card_inventory_queue_commit") and adapter.contains("commit_card_inventory_queue_commit") and not adapter.contains("slots[slot_index] = null") and not adapter.contains("_card_resolution_current_queue().append") and not adapter.contains("_card_resolution_next_queue().append")
	return _record("submission_adapter_uses_both_services", "main-adapter", {}, {
		"observed": not adapter.is_empty(),
		"contract_aligned": aligned,
		"service_owner_checked": aligned,
		"plan_checked": aligned,
		"commit_checked": aligned,
		"main_adapter_checked": aligned,
		"legacy_formula_absent": aligned,
		"notes": "main.gd validates world facts, coordinates both services, then forwards existing payment and events.",
	})


func _cutover_behavior_record(case_id: String, characterization_case_id: String) -> Dictionary:
	var behavior := _run_case(characterization_case_id)
	var debug := _queue_service_debug()
	var aligned := bool(behavior.get("observed", false)) and bool(behavior.get("contract_aligned", false)) and bool(debug.get("service_authoritative", false))
	return _record(case_id, str(behavior.get("fixture_id", characterization_case_id)), _queue_metrics(bool(behavior.get("accepted", false))), {
		"observed": bool(behavior.get("observed", false)),
		"contract_aligned": aligned,
		"ordering_checked": bool(behavior.get("ordering_checked", false)),
		"timing_boundary_checked": bool(behavior.get("timing_boundary_checked", false)),
		"save_checked": bool(behavior.get("save_checked", false)),
		"privacy_checked": bool(behavior.get("privacy_checked", false)),
		"service_owner_checked": bool(debug.get("service_authoritative", false)),
		"plan_checked": int(debug.get("plan_count", 0)) > 0,
		"commit_checked": int(debug.get("commit_count", 0)) > 0 or ["group_sort_service", "lock_metadata_service", "start_next_service", "invalid_skip_service", "next_promotion_service"].has(case_id),
		"main_adapter_checked": true,
		"notes": "Cutover ownership replay: %s" % str(behavior.get("notes", "")),
	})


func _case_public_wager_pool_receipt_service() -> Dictionary:
	_prepare_players([[], [], []], [1000, 1000, 1000])
	_runtime_main.set("card_resolution_batch_reference_player", 2)
	_runtime_main.set("card_resolution_queue", [_entry(0, 301, 10000, 1), _entry(1, 302, 5000, 1), _entry(2, 303, 0, 1)])
	var service := _queue_service()
	var lock_variant: Variant = service.call("lock_batch", {"reference_player": 2, "player_count": 3}) if service != null else {}
	var lock_result: Dictionary = lock_variant if lock_variant is Dictionary else {}
	var receipt: Dictionary = lock_result.get("public_wager_pool_receipt", {}) if lock_result.get("public_wager_pool_receipt", {}) is Dictionary else {}
	var annotations_ok := _queue().size() == 3
	for entry_variant in _queue():
		if entry_variant is Dictionary:
			annotations_ok = annotations_ok and (entry_variant as Dictionary).has("locked_priority_bid_cents") and (entry_variant as Dictionary).has("priority_bid_recipient_kind")
	var aligned := bool(lock_result.get("locked", false)) and int(receipt.get("total_cents", 0)) == 15000 and str(receipt.get("recipient_kind", "")) == "public_monster_wager_pool" and annotations_ok
	return _record("public_wager_pool_receipt_service", "10000-5000-0-cents", _queue_metrics(true), {
		"observed": not receipt.is_empty(),
		"contract_aligned": aligned,
		"service_owner_checked": annotations_ok,
		"commit_checked": aligned,
		"notes": "Queue lock emits one exact public receipt that aggregates every fixed group bid into the next monster-wager pool.",
	})


func _case_active_complete_service() -> Dictionary:
	var service := _queue_service()
	var entry := _entry(0, 401, 0, 1)
	service.call("replace_active_entry", entry)
	var result: Dictionary = service.call("complete_active", 401, {}) as Dictionary
	var aligned := bool(result.get("completed", false)) and (service.call("active_entry") as Dictionary).is_empty() and int((result.get("entry", {}) as Dictionary).get("resolution_id", -1)) == 401
	return _record("active_complete_service", BASE_CARD_ID, _queue_metrics(true), {
		"observed": not result.is_empty(),
		"contract_aligned": aligned,
		"service_owner_checked": aligned,
		"commit_checked": aligned,
		"notes": "Completing active state clears it exactly once and returns the resolved entry for the unchanged effect path.",
	})


func _case_legacy_save_service() -> Dictionary:
	var coordinator := _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	_runtime_main.set("card_resolution_queue", [_entry(0, 501, 0, 1)])
	_runtime_main.set("next_card_resolution_queue", [_next_entry(1, 502, 1)])
	_runtime_main.set("active_card_resolution", _entry(2, 503, 0, 1))
	_runtime_main.set("card_resolution_sequence", 503)
	var snapshot: Dictionary = coordinator.call("card_resolution_queue_legacy_save_snapshot") as Dictionary if coordinator != null else {}
	_queue_service().call("reset_state")
	if coordinator != null:
		coordinator.call("apply_card_resolution_queue_legacy_save_snapshot", snapshot)
	var aligned := _resolution_ids(_queue()) == [501] and _resolution_ids(_next_queue()) == [502] and int(_active_entry().get("resolution_id", -1)) == 503 and int(_runtime_main.get("card_resolution_sequence")) == 503
	return _record("legacy_save_service", "save-v1-adapter", _queue_metrics(true), {
		"observed": not snapshot.is_empty(),
		"contract_aligned": aligned,
		"service_owner_checked": aligned,
		"save_checked": aligned,
		"notes": "Legacy save keys round-trip through the service without changing save version or schema.",
	})


func _case_public_debug_privacy() -> Dictionary:
	var entry := _entry(1, 601, 90, 1)
	entry["private_target"] = "PRIVATE_TARGET_MARKER"
	entry["private_discard"] = "PRIVATE_DISCARD_MARKER"
	entry["ai_private_plan"] = "AI_PRIVATE_PLAN_MARKER"
	_queue_service().call("replace_current_queue", [entry])
	var public_snapshot: Dictionary = _queue_service().call("public_snapshot") as Dictionary
	var debug := _queue_service_debug()
	var serialized := JSON.stringify({"public": public_snapshot, "debug": debug})
	var aligned := _is_data_only(public_snapshot) and _is_data_only(debug) and not serialized.contains("PRIVATE_TARGET_MARKER") and not serialized.contains("PRIVATE_DISCARD_MARKER") and not serialized.contains("AI_PRIVATE_PLAN_MARKER") and not _contains_key_recursive(public_snapshot, "player_index")
	return _record("public_debug_privacy", "privacy-markers", _queue_metrics(true), {
		"observed": not public_snapshot.is_empty() and not debug.is_empty(),
		"contract_aligned": aligned,
		"service_owner_checked": true,
		"privacy_checked": aligned,
		"pure_data_checked": aligned,
		"notes": "Public/debug snapshots expose counts and public clues without owner or private plan payloads.",
	})


func _case_timing_controller_still_sole_owner() -> Dictionary:
	var controller_source := FileAccess.get_file_as_string(CONTROLLER_SCRIPT_PATH)
	var service_source := FileAccess.get_file_as_string(QUEUE_SERVICE_SCRIPT_PATH)
	var debug := _queue_service_debug()
	var aligned := controller_source.contains("func tick(") and controller_source.contains("total_window_seconds") and controller_source.contains("lock_seconds") and not service_source.contains("func tick(") and not bool(debug.get("timing_authority", true))
	return _record("timing_controller_still_sole_owner", "8-6-2-boundary", {}, {
		"observed": _controller() != null,
		"contract_aligned": aligned,
		"timing_boundary_checked": aligned,
		"service_owner_checked": aligned,
		"notes": "CardResolutionRuntimeController remains the sole 8/6/2 timer after the v0.5 domain cutover.",
	})


func _case_card_effect_resolver_unchanged() -> Dictionary:
	var main_source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var service_source := FileAccess.get_file_as_string(QUEUE_SERVICE_SCRIPT_PATH)
	var resolver := _function_source(main_source, "_apply_card_resolution_effect_request")
	var aligned := not resolver.is_empty() and resolver.contains("match handler_id:") and not resolver.contains("CardResolutionQueueRuntimeService") and not service_source.contains("func _apply_card_resolution_effect_request") and not service_source.contains("_apply_area_trade_contract")
	return _record("card_effect_resolver_unchanged", "effect-boundary", {}, {
		"observed": not resolver.is_empty(),
		"contract_aligned": aligned,
		"service_owner_checked": aligned,
		"legacy_formula_absent": aligned,
		"notes": "Queue Service never resolves card effects; the Sprint 37 world adapter remains outside queue ownership.",
	})


func _case_main_queue_storage_absent() -> Dictionary:
	var main_source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var service_source := FileAccess.get_file_as_string(QUEUE_SERVICE_SCRIPT_PATH)
	var absent := not main_source.contains("var card_resolution_queue := []") and not main_source.contains("var next_card_resolution_queue := []") and not main_source.contains("var active_card_resolution := {}") and not main_source.contains("var card_resolution_sequence := 0") and not main_source.contains("var card_resolution_priority_reference_player")
	var service_owns := service_source.contains("var _current_queue: Array = []") and service_source.contains("var _next_queue: Array = []") and service_source.contains("var _active_entry: Dictionary = {}") and service_source.contains("var _resolution_sequence := 0")
	return _record("main_queue_storage_absent", "source-delete-gate", {}, {
		"observed": absent,
		"contract_aligned": absent and service_owns,
		"service_owner_checked": service_owns,
		"main_adapter_checked": main_source.contains("func _card_resolution_current_queue()"),
		"legacy_formula_absent": absent,
		"notes": "main.gd has no current/active/next/sequence storage; compatibility access is a stateless service forwarder.",
	})


func _case_legacy_queue_algorithms_absent() -> Dictionary:
	var main_source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var submit := _function_source(main_source, "_queue_skill_resolution")
	var sorter := _function_source(main_source, "_sort_card_resolution_queue")
	var locker := _function_source(main_source, "_lock_card_resolution_batch")
	var starter := _function_source(main_source, "_start_next_card_resolution")
	var promoter := _function_source(main_source, "_promote_next_card_resolution_batch")
	var absent := not submit.contains(".append(entry)") and not submit.contains("slots[slot_index] =") and not sorter.contains("flatten_groups") and not main_source.contains("func _normalize_card_resolution_queue_bids") and not main_source.contains("func _apply_card_group_bid_chain") and not locker.contains("waiting[\"batch_position\"]") and not starter.contains(".pop_front()") and not promoter.contains("card_resolution_queue = next_card_resolution_queue")
	var adapters := submit.contains("commit_card_resolution_queue_submission") and sorter.contains("service.call(\"sort_current\"") and locker.contains("service.call(\"lock_batch\"") and starter.contains("service.call(\"start_next\"") and promoter.contains("service.call(\"promote_next_batch\"") and main_source.contains("func _apply_card_group_wager_pool_receipt")
	return _record("legacy_queue_algorithms_absent", "source-delete-gate", {}, {
		"observed": absent,
		"contract_aligned": absent and adapters,
		"service_owner_checked": adapters,
		"main_adapter_checked": adapters,
		"legacy_formula_absent": absent,
		"notes": "All queue mutation algorithms have moved to the service; main.gd retains thin world/event adapters only.",
	})


func _queue_service() -> Node:
	return _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionQueueRuntimeService") if _runtime_main != null else null


func _queue_service_debug() -> Dictionary:
	var service := _queue_service()
	var value: Variant = service.call("debug_snapshot") if service != null and service.has_method("debug_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _prepare_counter_fixture(counter_count: int) -> void:
	var counter_slots: Array = []
	for _index in range(counter_count):
		counter_slots.append(_qa_counter_skill())
	_prepare_players([[], counter_slots], [1000, 1000])
	var active_skill := _qa_skill({"name": INTERACTION_CARD_ID, "kind": "player_hand_disrupt", "target_player_required": true})
	_runtime_main.set("active_card_resolution", _entry_with_skill(0, 90, 0, 1, active_skill))
	_runtime_main.set("card_resolution_batch_locked", true)
	_runtime_main.set("card_resolution_counter_window_active", true)
	_runtime_main.set("card_resolution_counter_timer", 5.0)


func _prepare_players(slot_sets: Array, cash_values: Array) -> void:
	var player_states: Array = (_runtime_main.get("players") as Array).duplicate(true)
	for player_index in range(mini(player_states.size(), slot_sets.size())):
		if not (player_states[player_index] is Dictionary):
			continue
		var player_state: Dictionary = (player_states[player_index] as Dictionary).duplicate(true)
		var slots_variant: Variant = slot_sets[player_index]
		player_state["slots"] = (slots_variant as Array).duplicate(true) if slots_variant is Array else []
		var cash := int(cash_values[player_index]) if player_index < cash_values.size() else 1000
		player_state["cash"] = cash
		player_state["cash_history"] = [cash]
		player_state["economic_ledger"] = []
		player_state["total_card_spend"] = 0
		player_state["total_card_income"] = 0
		player_state["queued_card_tip"] = 0
		player_state["action_cooldown"] = 0.0
		player_state["eliminated"] = false
		player_state["is_ai"] = false
		player_states[player_index] = player_state
	_runtime_main.set("players", player_states)
	_runtime_main.set("game_over", false)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 0
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = 0


func _clear_queue_state() -> void:
	_runtime_main.set("card_resolution_queue", [])
	_runtime_main.set("next_card_resolution_queue", [])
	_runtime_main.set("active_card_resolution", {})
	_runtime_main.set("resolved_card_history", [])
	_runtime_main.set("card_resolution_batch_locked", false)
	_runtime_main.set("card_resolution_simultaneous_timer", 8.0)
	_runtime_main.set("card_resolution_auction_timer", 0.0)
	_runtime_main.set("card_resolution_auction_open", false)
	_runtime_main.set("card_resolution_counter_window_active", false)
	_runtime_main.set("card_resolution_counter_timer", 0.0)
	_runtime_main.set("card_resolution_timer", 0.0)
	_runtime_main.set("card_resolution_batch_reference_player", -1)
	_runtime_main.set("last_card_resolution_player_index", -1)
	_runtime_main.set("card_resolution_sequence", 0)
	_runtime_main.set("card_group_window_sequence", 0)
	_runtime_main.set("card_resolution_force_duration", 2.0)
	_runtime_main.set("card_resolution_force_simultaneous_window", 8.0)
	_runtime_main.set("public_card_bid_monster_wager_pool", 0)
	var contract_controller := _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ContractRuntimeController")
	if contract_controller != null and contract_controller.has_method("reset_state"):
		contract_controller.call("reset_state")


func _qa_skill(overrides: Dictionary = {}) -> Dictionary:
	var card_id := str(overrides.get("name", BASE_CARD_ID))
	var value: Variant = _runtime_main.call("_make_skill", card_id)
	var skill: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {"name": card_id, "kind": "cash_gain", "cash": 0}
	skill["play_requirement_kind"] = "none"
	skill["play_region_gdp_share_required"] = 0
	skill["play_product"] = ""
	skill["play_flow_required"] = 0
	skill["play_cash"] = 0
	for key in overrides.keys():
		skill[key] = _duplicate_data(overrides[key])
	return skill


func _qa_counter_skill() -> Dictionary:
	return _qa_skill({"name": COUNTER_CARD_ID, "kind": "card_counter", "persistent": false})


func _skills(count: int) -> Array:
	var result: Array = []
	for _index in range(count):
		result.append(_qa_skill())
	return result


func _submit(player_index: int, slot_index: int, target_slot: int = -1, target_player_index: int = -1) -> bool:
	return bool(_runtime_main.call("_queue_skill_resolution", player_index, slot_index, target_slot, target_player_index))


func _entry(player_index: int, resolution_id: int, bid: int, group_order: int) -> Dictionary:
	return _entry_with_skill(player_index, resolution_id, bid, group_order, _qa_skill())


func _entry_with_skill(player_index: int, resolution_id: int, bid: int, group_order: int, skill: Dictionary) -> Dictionary:
	return {
		"player_index": player_index,
		"slot_index": -1,
		"resolution_id": resolution_id,
		"queued_order": resolution_id,
		"window_sequence": 9,
		"group_id": "window_9_group_%d" % player_index,
		"group_order": group_order,
		"group_size": group_order,
		"priority_bid_cents": bid,
		"priority_bid_escrowed": true,
		"locked_priority_bid_cents": 0,
		"play_cost_paid_on_queue": true,
		"consumed_on_queue": true,
		"queued_behind_resolution": false,
		"skill": skill.duplicate(true),
	}


func _next_entry(player_index: int, resolution_id: int, group_order: int) -> Dictionary:
	var entry := _entry(player_index, resolution_id, 0, group_order)
	entry["queued_behind_resolution"] = true
	entry["group_id"] = "counter_%d" % resolution_id
	return entry


func _queue() -> Array:
	var value: Variant = _runtime_main.get("card_resolution_queue")
	return (value as Array).duplicate(true) if value is Array else []


func _next_queue() -> Array:
	var value: Variant = _runtime_main.get("next_card_resolution_queue")
	return (value as Array).duplicate(true) if value is Array else []


func _active_entry() -> Dictionary:
	var value: Variant = _runtime_main.get("active_card_resolution")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _first_queue_entry() -> Dictionary:
	var queue := _queue()
	return (queue[0] as Dictionary).duplicate(true) if not queue.is_empty() and queue[0] is Dictionary else {}


func _queue_entry_for_player(player_index: int) -> Dictionary:
	for entry_variant in _queue():
		if entry_variant is Dictionary and int((entry_variant as Dictionary).get("player_index", -1)) == player_index:
			return (entry_variant as Dictionary).duplicate(true)
	return {}


func _queue_player_order() -> Array:
	var result: Array = []
	for entry_variant in _queue():
		if entry_variant is Dictionary:
			result.append(int((entry_variant as Dictionary).get("player_index", -1)))
	return result


func _group_ids() -> Array:
	var result: Array = []
	for entry_variant in _queue():
		if not (entry_variant is Dictionary):
			continue
		var group_id := str((entry_variant as Dictionary).get("group_id", ""))
		if not result.has(group_id):
			result.append(group_id)
	return result


func _resolution_ids(entries: Array) -> Array:
	var result: Array = []
	for entry_variant in entries:
		if entry_variant is Dictionary:
			result.append(int((entry_variant as Dictionary).get("resolution_id", -1)))
	return result


func _player(player_index: int) -> Dictionary:
	var player_states: Array = _runtime_main.get("players") as Array
	if player_index < 0 or player_index >= player_states.size() or not (player_states[player_index] is Dictionary):
		return {}
	return (player_states[player_index] as Dictionary).duplicate(true)


func _player_cash(player_index: int) -> int:
	return int(_player(player_index).get("cash", 0))


func _hand_count(player_index: int) -> int:
	var player_state := _player(player_index)
	return int(_runtime_main.call("_player_counted_hand_size", player_state)) if not player_state.is_empty() else 0


func _slot_is_card(player_index: int, slot_index: int) -> bool:
	var player_state := _player(player_index)
	var slots: Array = player_state.get("slots", []) if player_state.get("slots", []) is Array else []
	return slot_index >= 0 and slot_index < slots.size() and slots[slot_index] is Dictionary


func _slot_queued(player_index: int, slot_index: int) -> bool:
	if not _slot_is_card(player_index, slot_index):
		return false
	var slots: Array = _player(player_index).get("slots", []) as Array
	return bool((slots[slot_index] as Dictionary).get("queued_for_resolution", false))


func _set_player_field(player_index: int, key: String, value: Variant) -> void:
	var player_states: Array = (_runtime_main.get("players") as Array).duplicate(true)
	if player_index < 0 or player_index >= player_states.size() or not (player_states[player_index] is Dictionary):
		return
	var player_state: Dictionary = (player_states[player_index] as Dictionary).duplicate(true)
	player_state[key] = _duplicate_data(value)
	player_states[player_index] = player_state
	_runtime_main.set("players", player_states)


func _queue_metrics(accepted: bool, cash_delta: int = 0, hand_delta: int = 0) -> Dictionary:
	var groups_variant: Variant = _runtime_main.call("_card_resolution_groups") if _runtime_main != null else []
	var groups: Array = groups_variant if groups_variant is Array else []
	return {
		"queue_count": _queue().size(),
		"next_queue_count": _next_queue().size(),
		"active_present": not _active_entry().is_empty(),
		"group_count": groups.size(),
		"accepted": accepted,
		"cash_delta": cash_delta,
		"hand_delta": hand_delta,
	}


func _record(case_id: String, fixture_id: String, metrics: Dictionary, flags: Dictionary) -> Dictionary:
	var observed := bool(flags.get("observed", false))
	var aligned := bool(flags.get("contract_aligned", false))
	var record := {
		"case_id": case_id,
		"gate_kind": "cutover" if cutover_cases().has(case_id) else "characterization",
		"fixture_id": fixture_id,
		"queue_count": int(metrics.get("queue_count", 0)),
		"next_queue_count": int(metrics.get("next_queue_count", 0)),
		"active_present": bool(metrics.get("active_present", false)),
		"group_count": int(metrics.get("group_count", 0)),
		"accepted": bool(metrics.get("accepted", false)),
		"cash_delta": int(metrics.get("cash_delta", 0)),
		"hand_delta": int(metrics.get("hand_delta", 0)),
		"ordering_checked": bool(flags.get("ordering_checked", false)),
		"timing_boundary_checked": bool(flags.get("timing_boundary_checked", false)),
		"save_checked": bool(flags.get("save_checked", false)),
		"privacy_checked": bool(flags.get("privacy_checked", false)),
		"service_owner_checked": bool(flags.get("service_owner_checked", false)),
		"plan_checked": bool(flags.get("plan_checked", false)),
		"commit_checked": bool(flags.get("commit_checked", false)),
		"main_adapter_checked": bool(flags.get("main_adapter_checked", false)),
		"legacy_formula_absent": bool(flags.get("legacy_formula_absent", false)),
		"pure_data_checked": true,
		"observed": observed,
		"contract_aligned": aligned,
		"needs_design_decision": bool(flags.get("needs_design_decision", false)),
		"risk": str(flags.get("risk", "" if aligned else "observed runtime differs from or is underspecified by the v0.4 queue contract")),
		"passed": observed and aligned,
		"notes": str(flags.get("notes", "")),
	}
	record["pure_data_checked"] = _is_data_only(record) and not _contains_runtime_object(record)
	return record


func _controller() -> Node:
	return _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/CardResolutionRuntimeController") if _runtime_main != null else null


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
	_runtime_main.set_process(false)
	runtime_main_host.add_child(_runtime_main)
	_hide_runtime_canvas_layers()
	await get_tree().process_frame
	await get_tree().process_frame
	return true


func _reset_runtime_main() -> void:
	if _runtime_main == null:
		return
	_runtime_main.set_process(false)
	_runtime_main.call("_new_game")
	_hide_runtime_canvas_layers()
	_runtime_main.set_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	_clear_queue_state()


func _hide_runtime_canvas_layers() -> void:
	if _runtime_main == null:
		return
	for canvas_node in _runtime_main.find_children("*", "CanvasLayer", true, false):
		if canvas_node is CanvasLayer:
			(canvas_node as CanvasLayer).visible = false


func _release_runtime_main() -> void:
	if _runtime_main != null and is_instance_valid(_runtime_main):
		var audio_players: Array[AudioStreamPlayer] = []
		for player_variant in _runtime_main.find_children("*", "AudioStreamPlayer", true, false):
			var player := player_variant as AudioStreamPlayer
			if player != null:
				player.stop()
				audio_players.append(player)
		await get_tree().create_timer(0.2).timeout
		for player in audio_players:
			if is_instance_valid(player):
				player.stream = null
				player.free()
		_runtime_main.set("table_bgm_player", null)
		_runtime_main.set("table_sfx_players", {})
		if _runtime_main.get_parent() != null:
			_runtime_main.get_parent().remove_child(_runtime_main)
		_runtime_main.free()
	_runtime_main = null


func _function_source(source_text: String, function_name: String) -> String:
	var start := source_text.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next_function := source_text.find("\nfunc ", start + 5)
	return source_text.substr(start) if next_function < 0 else source_text.substr(start, next_function - start)


func _contains_key_recursive(value: Variant, target_key: String) -> bool:
	if value is Dictionary:
		for key_variant in value.keys():
			if str(key_variant) == target_key or _contains_key_recursive(value[key_variant], target_key):
				return true
	if value is Array:
		for item in value:
			if _contains_key_recursive(item, target_key):
				return true
	return false


func _duplicate_data(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value


func _observed_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("observed", false)):
			count += 1
	return count


func _passed_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count


func _passed_count_for(case_ids: Array) -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and case_ids.has(str((record_variant as Dictionary).get("case_id", ""))) and bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count


func _aligned_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("contract_aligned", false)):
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
	var passed := _passed_count()
	summary_label.text = "Queue lifecycle: %d/%d passed | %d observed | %d aligned | %d decisions" % [passed, CASE_COUNT, observed, aligned, decisions]
	status_label.text = "CUTOVER 56/56" if passed == CASE_COUNT else "INCOMPLETE"
	status_label.add_theme_color_override("font_color", Color("#4ade80") if passed == CASE_COUNT else Color("#fb7185"))
	ownership_text.text = "[b]SS05-05 queue ownership[/b]\n\n[b]CardResolutionQueueRuntimeService[/b]\n• current, active, and next queue state\n• capacity reservations and group ordering\n• fixed priority bids and public wager-pool receipt\n\n[b]CardResolutionRuntimeController[/b]\n• sole 8/6/2 clock, readiness, and phase owner\n\n[b]Adjacent owners[/b]\n• CardResolutionExecutionRuntimeService orders active execution\n• main.gd keeps concrete world-effect adapters\n• neither owner stores a second queue"
	var lines: Array[String] = ["[b]Characterization + cutover gates[/b]"]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		var observed_mark := "OBS" if bool(record.get("observed", false)) else "MISS"
		var aligned_mark := "aligned" if bool(record.get("contract_aligned", false)) else "review"
		lines.append("%s  %s  %s  [%s]" % [observed_mark, str(record.get("gate_kind", "")), str(record.get("case_id", "")), aligned_mark])
	cases_text.text = "\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines := [
		"# Card Resolution Queue Runtime v0.5 Alignment SS05-05",
		"",
		"- Card-group domain: `v0.5` (production global ruleset remains `v0.4`)",
		"- Observed: **%d/%d**" % [int(manifest.get("observed_count", 0)), CASE_COUNT],
		"- Contract aligned: **%d/%d**" % [int(manifest.get("aligned_count", 0)), CASE_COUNT],
		"- Passed: **%d/%d**" % [_passed_count(), CASE_COUNT],
		"- Characterization gate: **%d/%d**" % [_passed_count_for(characterization_cases()), CHARACTERIZATION_CASE_COUNT],
		"- Cutover gate: **%d/%d**" % [_passed_count_for(cutover_cases()), CUTOVER_CASE_COUNT],
		"- Needs design decision: **%d**" % int(manifest.get("needs_design_decision_count", 0)),
		"- Historical Sprint 35 main hash: `%s`" % PRE_CUTOVER_MAIN_SHA256,
		"- Main differs from historical Sprint 35: **%s**" % str(manifest.get("main_changed_by_cutover", false)),
		"- Output: `%s`" % OUTPUT_DIR,
		"",
		"Public QA records intentionally exclude acting-player identity, private targets, private discards, and AI plans.",
		"",
		"| Gate | Case | Fixture | Queue | Next | Active | Groups | Owner | Plan | Commit | Adapter | Legacy absent | Privacy | Observed | Aligned | Passed | Notes |",
		"| --- | --- | --- | ---: | ---: | --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| %s | %s | %s | %d | %d | %s | %d | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % [
			str(record.get("gate_kind", "")),
			str(record.get("case_id", "")),
			str(record.get("fixture_id", "")),
			int(record.get("queue_count", 0)),
			int(record.get("next_queue_count", 0)),
			"yes" if bool(record.get("active_present", false)) else "no",
			int(record.get("group_count", 0)),
			"yes" if bool(record.get("service_owner_checked", false)) else "no",
			"yes" if bool(record.get("plan_checked", false)) else "no",
			"yes" if bool(record.get("commit_checked", false)) else "no",
			"yes" if bool(record.get("main_adapter_checked", false)) else "no",
			"yes" if bool(record.get("legacy_formula_absent", false)) else "no",
			"yes" if bool(record.get("privacy_checked", false)) else "no",
			"yes" if bool(record.get("observed", false)) else "no",
			"yes" if bool(record.get("contract_aligned", false)) else "no",
			"yes" if bool(record.get("passed", false)) else "no",
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
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
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
		for key_variant in value.keys():
			if _contains_runtime_object(key_variant) or _contains_runtime_object(value[key_variant]):
				return true
	return false
