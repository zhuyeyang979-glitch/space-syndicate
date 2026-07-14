extends Control
class_name IndustryCapacityCardGroupRuntimeBench

const CAPACITY_SCENE_PATH := "res://scenes/runtime/IndustryCapacityRuntimeService.tscn"
const CAPACITY_BRIDGE_SCENE_PATH := "res://scenes/runtime/IndustryCapacityWorldBridge.tscn"
const QUEUE_SCENE_PATH := "res://scenes/runtime/CardResolutionQueueRuntimeService.tscn"
const ELIGIBILITY_SCENE_PATH := "res://scenes/runtime/CardPlayEligibilityRuntimeService.tscn"
const WINDOW_SCENE_PATH := "res://scenes/runtime/CardResolutionRuntimeController.tscn"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const QUEUE_SCRIPT_PATH := "res://scripts/runtime/card_resolution_queue_runtime_service.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/industry_capacity_card_group_runtime/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/industry_capacity_card_group_runtime_sprint_5.png"

const INDUSTRY_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping"]
const DOMAIN_RULES := {
	"ruleset_id": "v0.5",
	"card_group": {
		"group_seconds": 8,
		"organize_seconds": 6,
		"lock_seconds": 2,
		"tutorial_group_card_limit": 1,
		"standard_group_card_limit": 2,
		"priority_bid_options_cents": [0, 5000, 10000],
	},
}

const CASE_IDS := [
	"capacity_service_scene_loads",
	"capacity_bridge_scene_loads",
	"coordinator_static_composition",
	"capacity_service_api_contract",
	"capacity_bridge_is_non_owning",
	"v05_domain_rules_are_source",
	"six_industries_are_exact",
	"catalog_products_map_once",
	"capacity_14_is_zero",
	"capacity_15_is_one",
	"capacity_39_is_one",
	"capacity_40_is_two",
	"capacity_79_is_two",
	"capacity_80_is_three",
	"capacity_139_is_three",
	"capacity_140_is_four",
	"same_industry_gdp_aggregates",
	"named_product_gdp_aggregates",
	"unknown_product_fails_closed",
	"product_industry_mismatch_fails_closed",
	"v04_cards_are_explicit_colorless_compatibility",
	"colorless_requirement_uses_no_capacity",
	"single_industry_requirement_passes",
	"single_industry_requirement_fails",
	"dual_industry_requires_both",
	"dual_industry_partial_fails",
	"either_industry_selects_first_available",
	"either_industry_uses_second_fallback",
	"named_product_requirement_passes",
	"named_product_gdp_requirement_fails",
	"unknown_named_product_fails",
	"two_primary_requirements_allowed",
	"third_primary_requirement_rejected",
	"blocked_v05_card_rejected",
	"influence_basis_points_pass",
	"influence_basis_points_fail",
	"first_capacity_reservation_commits",
	"same_group_capacity_is_cumulative",
	"different_players_reserve_independently",
	"capacity_revision_drift_rejects",
	"gdp_drift_after_submission_does_not_cancel",
	"reservation_stays_until_group_finishes",
	"reservation_releases_after_last_card",
	"reservation_release_is_exact_once",
	"card_window_total_is_eight_seconds",
	"organize_phase_is_six_seconds",
	"lock_phase_is_two_seconds",
	"tutorial_group_limit_is_one",
	"standard_group_limit_is_two",
	"all_active_players_ready_locks_early",
	"partial_ready_does_not_lock",
	"priority_bid_options_are_fixed",
	"invalid_priority_bid_rejected",
	"equal_bid_uses_clockwise_reference",
	"all_group_bids_enter_public_wager_pool",
	"public_wager_receipt_hides_payers",
	"wager_pool_receipt_is_exact_once",
	"wager_pool_has_no_previous_group_transfer",
	"queue_save_restores_capacity_reservations",
	"window_save_restores_ready_state",
	"public_queue_snapshot_hides_owner_and_targets",
	"all_runtime_payloads_are_pure_data",
	"production_bridge_and_catalog_remain_v04",
	"legacy_bid_chain_and_parallel_capacity_absent",
]

@export var auto_run := true

@onready var ruleset_bridge: Node = %RulesetRuntimeBridge
@onready var coordinator: Node = %GameRuntimeCoordinator
@onready var runtime_host: Node = %RuntimeHost
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var rules_text: RichTextLabel = %RulesText
@onready var results_text: RichTextLabel = %ResultsText

var _records: Array = []
var _failures: Array[String] = []
var _notes: Dictionary = {}


func _ready() -> void:
	_configure_static_runtime()
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_runtime_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func runtime_cases() -> Array:
	return CASE_IDS.duplicate()


func build_runtime_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in CASE_IDS:
		records.append(_record(str(case_id_variant), false, "preview"))
	return {
		"suite": "ss05-05-industry-capacity-card-group",
		"ruleset_id": "v0.5",
		"production_runtime_ruleset": "v0.4",
		"record_count": records.size(),
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"records": records,
	}


func run_runtime_suite() -> void:
	_records.clear()
	_failures.clear()
	_notes.clear()
	_prepare_output_dir()
	_configure_static_runtime()
	var checks := _evaluate_checks()
	for case_id_variant in CASE_IDS:
		var case_id := str(case_id_variant)
		var passed := bool(checks.get(case_id, false))
		var record := _record(case_id, passed, str(_notes.get(case_id, "verified")))
		_records.append(record)
		if not passed:
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "failed"))])
	var manifest := {
		"suite": "ss05-05-industry-capacity-card-group",
		"ruleset_id": "v0.5",
		"production_runtime_ruleset": "v0.4",
		"record_count": _records.size(),
		"passed_count": _passed_count(),
		"failed_count": _failures.size(),
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("IndustryCapacityCardGroupRuntimeBench manifest: %s" % MANIFEST_PATH)
	print("IndustryCapacityCardGroupRuntimeBench report: %s" % REPORT_PATH)
	print("IndustryCapacityCardGroupRuntimeBench screenshot: %s" % SCREENSHOT_PATH)
	print("IndustryCapacityCardGroupRuntimeBench passed: %d/%d" % [_passed_count(), _records.size()])
	if not _failures.is_empty():
		push_error("IndustryCapacityCardGroupRuntimeBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)


func debug_snapshot() -> Dictionary:
	return {
		"record_count": _records.size(),
		"passed_count": _passed_count(),
		"failures": _failures.duplicate(),
		"records": _records.duplicate(true),
	}


func _evaluate_checks() -> Dictionary:
	var checks := {}
	var capacity := _new_runtime(CAPACITY_SCENE_PATH)
	var capacity_bridge := _new_runtime(CAPACITY_BRIDGE_SCENE_PATH)
	var eligibility := _new_runtime(ELIGIBILITY_SCENE_PATH)
	var queue := _new_runtime(QUEUE_SCENE_PATH)
	var window := _new_runtime(WINDOW_SCENE_PATH)
	checks["capacity_service_scene_loads"] = capacity != null and capacity.scene_file_path == CAPACITY_SCENE_PATH
	checks["capacity_bridge_scene_loads"] = capacity_bridge != null and capacity_bridge.scene_file_path == CAPACITY_BRIDGE_SCENE_PATH
	checks["capacity_service_api_contract"] = capacity != null and _has_methods(capacity, ["configure", "derive_player_capacity", "capacity_for_gdp", "availability_snapshot", "debug_snapshot"])
	checks["capacity_bridge_is_non_owning"] = capacity_bridge != null and _bridge_is_non_owning(capacity_bridge)
	checks["coordinator_static_composition"] = coordinator != null and coordinator.get_node_or_null("IndustryCapacityRuntimeService") != null and coordinator.get_node_or_null("IndustryCapacityWorldBridge") != null
	checks["v05_domain_rules_are_source"] = queue != null and eligibility != null and _configure_domain_services(queue, eligibility)

	if capacity == null or eligibility == null or queue == null or window == null:
		for case_id_variant in CASE_IDS:
			var case_id := str(case_id_variant)
			if not checks.has(case_id):
				checks[case_id] = false
				_notes[case_id] = "required runtime scene did not instantiate"
		return checks

	var capacity_configuration: Dictionary = capacity.call("configure")
	checks["six_industries_are_exact"] = bool(capacity_configuration.get("valid", false)) and _same_string_set((capacity.call("debug_snapshot") as Dictionary).get("industry_ids", []), INDUSTRY_IDS)
	checks["catalog_products_map_once"] = _catalog_maps_products_once(capacity.get("product_industry_catalog"))
	var threshold_expectations := {14: 0, 15: 1, 39: 1, 40: 2, 79: 2, 80: 3, 139: 3, 140: 4}
	var threshold_cases := {14: "capacity_14_is_zero", 15: "capacity_15_is_one", 39: "capacity_39_is_one", 40: "capacity_40_is_two", 79: "capacity_79_is_two", 80: "capacity_80_is_three", 139: "capacity_139_is_three", 140: "capacity_140_is_four"}
	for value_variant in threshold_expectations.keys():
		var value := int(value_variant)
		checks[str(threshold_cases[value])] = int(capacity.call("capacity_for_gdp", value)) == int(threshold_expectations[value])

	var catalog: Resource = capacity.get("product_industry_catalog")
	var products := _representative_products(catalog)
	var life_product := str(products.get("life", ""))
	var aggregation: Dictionary = capacity.call("derive_player_capacity", 0, [
		_project_row(life_product, "life", 10, 0),
		_project_row(life_product, "life", 30, 1),
	])
	checks["same_industry_gdp_aggregates"] = _industry_gdp(aggregation, "life") == 40 and _industry_capacity(aggregation, "life") == 2
	checks["named_product_gdp_aggregates"] = int((aggregation.get("products", {}) as Dictionary).get(life_product, 0)) == 40
	var unknown_snapshot: Dictionary = capacity.call("derive_player_capacity", 0, [_project_row("qa.unknown.product", "life", 20, 0)])
	checks["unknown_product_fails_closed"] = not bool(unknown_snapshot.get("valid", true)) and (unknown_snapshot.get("errors", []) as Array).has("unknown_product:qa.unknown.product")
	var mismatch_snapshot: Dictionary = capacity.call("derive_player_capacity", 0, [_project_row(life_product, "shipping", 20, 0)])
	checks["product_industry_mismatch_fails_closed"] = not bool(mismatch_snapshot.get("valid", true)) and (mismatch_snapshot.get("errors", []) as Array).has("industry_mismatch:%s" % life_product)

	var full_capacity := _capacity_snapshot(capacity, products, {"life": 40, "energy": 40, "industry": 40, "technology": 40, "commerce": 40, "shipping": 40})
	var availability: Dictionary = capacity.call("availability_snapshot", full_capacity, {})
	var facts := _eligibility_facts(availability)
	var compatibility: Dictionary = eligibility.call("requirement_status", {"skill": {"name": "legacy.qa.card", "kind": "qa"}}, facts)
	checks["v04_cards_are_explicit_colorless_compatibility"] = bool(compatibility.get("industry_capacity_satisfied", false)) and str((compatibility.get("industry_capacity_status", {}) as Dictionary).get("compatibility_mode", "")) == "v04_colorless"
	var colorless := _requirement_result(eligibility, [_requirement("colorless", [], 0)], facts)
	checks["colorless_requirement_uses_no_capacity"] = _requirement_passed(colorless) and (_reservation(colorless).get("industries", {}) as Dictionary).is_empty()
	var single := _requirement_result(eligibility, [_requirement("single_industry", ["life"], 2)], facts)
	checks["single_industry_requirement_passes"] = _requirement_passed(single) and int((_reservation(single).get("industries", {}) as Dictionary).get("life", 0)) == 2
	var low_facts := _eligibility_facts(capacity.call("availability_snapshot", _capacity_snapshot(capacity, products, {"life": 15}), {}))
	var single_low := _requirement_result(eligibility, [_requirement("single_industry", ["life"], 2)], low_facts)
	checks["single_industry_requirement_fails"] = _requirement_reason(single_low) == "industry_capacity_insufficient"
	var dual := _requirement_result(eligibility, [_requirement("dual_industry", ["life", "energy"], 2)], facts)
	checks["dual_industry_requires_both"] = _requirement_passed(dual) and int((_reservation(dual).get("industries", {}) as Dictionary).get("life", 0)) == 2 and int((_reservation(dual).get("industries", {}) as Dictionary).get("energy", 0)) == 2
	var partial_facts := _eligibility_facts(capacity.call("availability_snapshot", _capacity_snapshot(capacity, products, {"life": 15, "energy": 40}), {}))
	checks["dual_industry_partial_fails"] = _requirement_reason(_requirement_result(eligibility, [_requirement("dual_industry", ["life", "energy"], 2)], partial_facts)) == "industry_capacity_insufficient"
	var either := _requirement_result(eligibility, [_requirement("either_industry", ["life", "energy"], 2)], facts)
	checks["either_industry_selects_first_available"] = _selected_industry(either) == "life"
	var either_fallback := _requirement_result(eligibility, [_requirement("either_industry", ["life", "energy"], 2)], partial_facts)
	checks["either_industry_uses_second_fallback"] = _selected_industry(either_fallback) == "energy"
	var named := _named_requirement(life_product, 30, 1)
	var named_result := _requirement_result(eligibility, [named], facts)
	checks["named_product_requirement_passes"] = _requirement_passed(named_result) and _selected_industry(named_result) == "life"
	checks["named_product_gdp_requirement_fails"] = _requirement_reason(_requirement_result(eligibility, [_named_requirement(life_product, 50, 1)], facts)) == "named_product_gdp_insufficient"
	checks["unknown_named_product_fails"] = _requirement_reason(_requirement_result(eligibility, [_named_requirement("qa.unknown.product", 1, 1)], facts)) == "unknown_named_product"
	checks["two_primary_requirements_allowed"] = _requirement_passed(_requirement_result(eligibility, [_requirement("single_industry", ["life"], 1), _requirement("single_industry", ["energy"], 1)], facts))
	checks["third_primary_requirement_rejected"] = _requirement_reason(_requirement_result(eligibility, [_requirement("colorless", [], 0), _requirement("colorless", [], 0), _requirement("colorless", [], 0)], facts)) == "too_many_primary_requirements"
	var blocked: Dictionary = eligibility.call("requirement_status", {"skill": {"schema_version": "v0.5", "migration_status": "blocked", "card_id": "qa.blocked"}}, facts)
	checks["blocked_v05_card_rejected"] = _requirement_reason(blocked) == "v05_card_migration_blocked"
	var influence_facts := facts.duplicate(true)
	influence_facts["selected_district"] = 3
	influence_facts["share_basis_points_by_district"] = {"3": 3000}
	var influence_requirement := _requirement("colorless", [], 0)
	influence_requirement["region_scope"] = "selected_region"
	influence_requirement["required_influence_bp"] = 3000
	checks["influence_basis_points_pass"] = _requirement_passed(_requirement_result(eligibility, [influence_requirement], influence_facts))
	influence_facts["share_basis_points_by_district"] = {"3": 2999}
	checks["influence_basis_points_fail"] = _requirement_reason(_requirement_result(eligibility, [influence_requirement], influence_facts)) == "influence_insufficient"

	_configure_domain_services(queue, eligibility)
	var life_two := _capacity_snapshot(capacity, products, {"life": 40})
	var first := _submit(queue, 0, 0, 0, _capacity_reservation(life_two, {"life": 1}), life_two, 2)
	checks["first_capacity_reservation_commits"] = bool((first.get("commit", {}) as Dictionary).get("committed", false)) and int((queue.call("reserved_capacity_for_player", 0) as Dictionary).get("life", 0)) == 1
	var cumulative := _submit(queue, 0, 1, 0, _capacity_reservation(life_two, {"life": 2}), life_two, 2)
	checks["same_group_capacity_is_cumulative"] = not bool((cumulative.get("plan", {}) as Dictionary).get("accepted", true)) and str((cumulative.get("plan", {}) as Dictionary).get("reason", "")) == "industry_capacity_insufficient"
	var life_two_player_one := _capacity_snapshot(capacity, products, {"life": 40}, 1)
	var independent := _submit(queue, 1, 0, 0, _capacity_reservation(life_two_player_one, {"life": 2}), life_two_player_one, 2)
	checks["different_players_reserve_independently"] = bool((independent.get("commit", {}) as Dictionary).get("committed", false)) and int((queue.call("reserved_capacity_for_player", 1) as Dictionary).get("life", 0)) == 2
	var drift_reservation := _capacity_reservation(life_two, {"life": 1})
	drift_reservation["capacity_revision"] = "stale"
	var drift := _submit(_fresh_queue(), 0, 0, 0, drift_reservation, life_two, 2)
	checks["capacity_revision_drift_rejects"] = str((drift.get("plan", {}) as Dictionary).get("reason", "")) == "capacity_revision_drift"
	var drift_queue := _fresh_queue()
	_submit(drift_queue, 0, 0, 0, _capacity_reservation(life_two, {"life": 1}), life_two, 2)
	var drift_lock: Dictionary = drift_queue.call("lock_batch", {"reference_player": 0, "player_count": 4, "industry_capacity": _capacity_snapshot(capacity, products, {"life": 0})})
	checks["gdp_drift_after_submission_does_not_cancel"] = bool(drift_lock.get("locked", false))

	var group_queue := _fresh_queue()
	_submit(group_queue, 0, 0, 0, _capacity_reservation(life_two, {"life": 1}), life_two, 2)
	_submit(group_queue, 0, 1, 0, _capacity_reservation(life_two, {"life": 1}), life_two, 2)
	group_queue.call("lock_batch", {"reference_player": 0, "player_count": 4})
	var first_start: Dictionary = group_queue.call("start_next", {"game_time": 1.0})
	var first_complete: Dictionary = group_queue.call("complete_active", int((first_start.get("active_entry", {}) as Dictionary).get("resolution_id", -1)), {})
	checks["reservation_stays_until_group_finishes"] = (first_complete.get("capacity_release_receipt", {}) as Dictionary).is_empty() and int((group_queue.call("reserved_capacity_for_player", 0) as Dictionary).get("life", 0)) == 2
	var second_start: Dictionary = group_queue.call("start_next", {"game_time": 2.0})
	var second_complete: Dictionary = group_queue.call("complete_active", int((second_start.get("active_entry", {}) as Dictionary).get("resolution_id", -1)), {})
	var release: Dictionary = second_complete.get("capacity_release_receipt", {}) if second_complete.get("capacity_release_receipt", {}) is Dictionary else {}
	checks["reservation_releases_after_last_card"] = bool(release.get("released", false)) and int((group_queue.call("reserved_capacity_for_player", 0) as Dictionary).get("life", 0)) == 0
	var duplicate_complete: Dictionary = group_queue.call("complete_active", -1, {})
	checks["reservation_release_is_exact_once"] = not bool(duplicate_complete.get("completed", true)) and (duplicate_complete.get("capacity_release_receipt", {}) as Dictionary if duplicate_complete.get("capacity_release_receipt", {}) is Dictionary else {}).is_empty()

	window.call("configure", {"total_window_seconds": 8.0, "lock_seconds": 2.0, "display_seconds": 5.0, "counter_seconds": 5.0})
	window.call("begin_group_window", -1.0, 0, 1)
	checks["card_window_total_is_eight_seconds"] = is_equal_approx(float(window.get("simultaneous_timer")), 8.0)
	checks["organize_phase_is_six_seconds"] = str(window.call("current_phase", {"queue_empty": false, "active_present": false, "lock_duration": 2.0})) == "organize" and SharedCardGroupWindow.phase_for_remaining(2.01, 2.0) == "organize"
	window.set("simultaneous_timer", 2.0)
	checks["lock_phase_is_two_seconds"] = str(window.call("current_phase", {"queue_empty": false, "active_present": false, "lock_duration": 2.0})) == "lock" and not bool(window.call("submissions_open", {"queue_empty": false, "active_present": false, "lock_duration": 2.0}))
	checks["tutorial_group_limit_is_one"] = SharedCardGroupWindow.card_limit(1) == 1 and not bool(SharedCardGroupWindow.can_submit([{"player_index": 0}], 0, 8.0, 1, 2.0).get("allowed", true))
	checks["standard_group_limit_is_two"] = SharedCardGroupWindow.card_limit(3) == 2 and bool(SharedCardGroupWindow.can_submit([{"player_index": 0}], 0, 8.0, 2, 2.0).get("allowed", false)) and not bool(SharedCardGroupWindow.can_submit([{"player_index": 0}, {"player_index": 0}], 0, 8.0, 2, 2.0).get("allowed", true))
	window.call("begin_group_window", -1.0, 0, 2)
	window.call("set_player_ready", 0, true, [0, 1])
	window.call("set_player_ready", 1, true, [0, 1])
	var ready_commands: Array = window.call("tick", 0.0, {"queue_empty": false, "active_present": false, "active_player_indices": [0, 1], "lock_duration": 2.0})
	checks["all_active_players_ready_locks_early"] = _has_transition(ready_commands, "all_ready_lock") and _has_transition(ready_commands, "lock_batch")
	window.call("reset_state")
	window.call("begin_group_window", -1.0, 0, 3)
	window.call("set_player_ready", 0, true, [0, 1])
	var partial_commands: Array = window.call("tick", 0.0, {"queue_empty": false, "active_present": false, "active_player_indices": [0, 1], "lock_duration": 2.0})
	checks["partial_ready_does_not_lock"] = not _has_transition(partial_commands, "all_ready_lock") and not bool(window.get("batch_locked"))
	# Historical v0.5 evidence remains readable, but v0.6 intentionally has no priority-bid API.
	checks["priority_bid_options_are_fixed"] = false
	var invalid_bid := _submit(_fresh_queue(), 0, 0, 2500, _capacity_reservation(life_two, {}), life_two, 2)
	checks["invalid_priority_bid_rejected"] = str((invalid_bid.get("plan", {}) as Dictionary).get("reason", "")) == "invalid_priority_bid"
	var tie_queue := _fresh_queue()
	_submit(tie_queue, 2, 0, 5000, _capacity_reservation(life_two, {}), life_two, 2)
	_submit(tie_queue, 1, 0, 5000, _capacity_reservation(life_two, {}), life_two, 2)
	var tie_sorted: Array = tie_queue.call("sort_current", 0, 4)
	checks["equal_bid_uses_clockwise_reference"] = tie_sorted.size() == 2 and int((tie_sorted[0] as Dictionary).get("player_index", -1)) == 1 and int((tie_sorted[1] as Dictionary).get("player_index", -1)) == 2
	var wager_queue := _fresh_queue()
	_submit(wager_queue, 1, 0, 5000, _capacity_reservation(life_two, {}), life_two, 2)
	_submit(wager_queue, 2, 0, 10000, _capacity_reservation(life_two, {}), life_two, 2)
	var wager_lock: Dictionary = wager_queue.call("lock_batch", {"reference_player": 0, "player_count": 4})
	var wager_receipt: Dictionary = wager_lock.get("public_wager_pool_receipt", {}) if wager_lock.get("public_wager_pool_receipt", {}) is Dictionary else {}
	checks["all_group_bids_enter_public_wager_pool"] = int(wager_receipt.get("total_cents", 0)) == 15000 and (wager_receipt.get("records", []) as Array).size() == 2
	var wager_public: Dictionary = wager_queue.call("public_snapshot")
	checks["public_wager_receipt_hides_payers"] = not JSON.stringify(wager_public).contains("payer_player_index") and not JSON.stringify(wager_public).contains("player_index")
	var second_lock: Dictionary = wager_queue.call("lock_batch", {"reference_player": 0, "player_count": 4})
	checks["wager_pool_receipt_is_exact_once"] = not bool(second_lock.get("locked", true)) and str(second_lock.get("reason", "")) == "wager_pool_receipt_duplicate"
	checks["wager_pool_has_no_previous_group_transfer"] = str(wager_receipt.get("recipient_kind", "")) == "public_monster_wager_pool" and not JSON.stringify(wager_receipt).contains("previous_group") and not JSON.stringify(wager_receipt).contains("recipient_player")

	var save_queue := _fresh_queue()
	_submit(save_queue, 0, 0, 0, _capacity_reservation(life_two, {"life": 1}), life_two, 2)
	var save_data: Dictionary = save_queue.call("to_legacy_save_snapshot")
	var restored_queue := _fresh_queue()
	restored_queue.call("apply_legacy_save_snapshot", save_data)
	checks["queue_save_restores_capacity_reservations"] = int((restored_queue.call("reserved_capacity_for_player", 0) as Dictionary).get("life", 0)) == 1
	window.call("reset_state")
	window.call("begin_group_window", -1.0, 0, 4)
	window.call("set_player_ready", 0, true, [0, 1])
	var window_save: Dictionary = window.call("to_save_data")
	var restored_window := _new_runtime(WINDOW_SCENE_PATH)
	restored_window.call("configure", {"total_window_seconds": 8.0, "lock_seconds": 2.0})
	restored_window.call("apply_save_data", window_save)
	checks["window_save_restores_ready_state"] = bool((restored_window.get("ready_players") as Dictionary).get("0", false)) and int(restored_window.get("window_sequence")) == 4
	var private_queue := _fresh_queue()
	var private_result := _submit(private_queue, 2, 0, 0, _capacity_reservation(life_two, {}), life_two, 2, {"target_player_index": 3, "private_discard": "secret", "selected_district": 4})
	var public_snapshot: Dictionary = private_queue.call("public_snapshot")
	checks["public_queue_snapshot_hides_owner_and_targets"] = bool((private_result.get("commit", {}) as Dictionary).get("committed", false)) and not JSON.stringify(public_snapshot).contains("target_player_index") and not JSON.stringify(public_snapshot).contains("private_discard") and not JSON.stringify(public_snapshot).contains("player_index")
	checks["all_runtime_payloads_are_pure_data"] = _is_data_only(full_capacity) and _is_data_only(single) and _is_data_only(queue.call("queue_state_snapshot")) and _is_data_only(wager_receipt) and _is_data_only(window.call("debug_snapshot"))
	checks["production_bridge_and_catalog_remain_v04"] = _production_owners_remain_v04()
	checks["legacy_bid_chain_and_parallel_capacity_absent"] = _legacy_algorithms_absent()

	for case_id_variant in CASE_IDS:
		var case_id := str(case_id_variant)
		_notes[case_id] = _case_note(case_id)
		if not checks.has(case_id):
			checks[case_id] = false
	return checks


func _configure_static_runtime() -> void:
	if ruleset_bridge != null and coordinator != null:
		coordinator.call("configure", ruleset_bridge.call("active_profile"))


func _configure_domain_services(queue: Node, eligibility: Node) -> bool:
	queue.call("configure", DOMAIN_RULES)
	eligibility.call("configure", DOMAIN_RULES)
	var queue_debug: Dictionary = queue.call("debug_snapshot")
	var eligibility_debug: Dictionary = eligibility.call("debug_snapshot")
	return bool(queue_debug.get("service_ready", false)) and str(queue_debug.get("ruleset_id", "")) == "v0.5" and bool(eligibility_debug.get("service_ready", false)) and str(eligibility_debug.get("ruleset_id", "")) == "v0.5"


func _new_runtime(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate()
	runtime_host.add_child(node)
	return node


func _fresh_queue() -> Node:
	var queue := _new_runtime(QUEUE_SCENE_PATH)
	queue.call("configure", DOMAIN_RULES)
	return queue


func _capacity_snapshot(service: Node, representative_products: Dictionary, values: Dictionary, player_index: int = 0) -> Dictionary:
	var rows: Array = []
	var index := 0
	for industry_id_variant in INDUSTRY_IDS:
		var industry_id := str(industry_id_variant)
		var value := maxi(0, int(values.get(industry_id, 0)))
		if value > 0:
			rows.append(_project_row(str(representative_products.get(industry_id, "")), industry_id, value, index))
			index += 1
	return service.call("derive_player_capacity", player_index, rows)


func _project_row(product_id: String, industry_id: String, gdp: int, index: int) -> Dictionary:
	return {
		"district_index": index,
		"project_id": "qa.project.%d" % index,
		"slot_id": "region.qa.slot.production.%d" % index,
		"generation": 1,
		"product_id": product_id,
		"industry_id": industry_id,
		"attributable_gdp_per_minute": gdp,
	}


func _representative_products(catalog: Resource) -> Dictionary:
	var result := {}
	if catalog == null or not catalog.has_method("debug_snapshot"):
		return result
	var snapshot: Dictionary = catalog.call("debug_snapshot")
	for product_variant in snapshot.get("products", []):
		if not (product_variant is Dictionary):
			continue
		var product := product_variant as Dictionary
		var industry_id := str(product.get("industry_id", ""))
		if INDUSTRY_IDS.has(industry_id) and not result.has(industry_id):
			result[industry_id] = str(product.get("product_id", ""))
	return result


func _catalog_maps_products_once(catalog: Resource) -> bool:
	if catalog == null or not catalog.has_method("debug_snapshot"):
		return false
	var snapshot: Dictionary = catalog.call("debug_snapshot")
	var seen := {}
	for product_variant in snapshot.get("products", []):
		if not (product_variant is Dictionary):
			return false
		var product := product_variant as Dictionary
		var product_id := str(product.get("product_id", ""))
		var industry_id := str(product.get("industry_id", ""))
		if product_id.is_empty() or seen.has(product_id) or not INDUSTRY_IDS.has(industry_id):
			return false
		seen[product_id] = industry_id
	return not seen.is_empty()


func _eligibility_facts(availability: Dictionary) -> Dictionary:
	return {
		"player_valid": true,
		"player_eliminated": false,
		"player_cash": 1000,
		"player_count": 4,
		"monster_count": 1,
		"selected_district": 0,
		"best_share_district": 0,
		"share_basis_points_by_district": {"0": 10000},
		"industry_capacity_available": availability.duplicate(true),
		"queue_preflight": {"batch_locked": false, "active_present": false},
	}


func _requirement(kind: String, industries: Array, capacity: int) -> Dictionary:
	return {
		"requirement_kind": kind,
		"industry_ids": industries.duplicate(),
		"required_capacity": capacity,
		"product_id": "",
		"required_product_gdp": 0,
		"region_scope": "none",
		"required_influence_bp": 0,
	}


func _named_requirement(product_id: String, product_gdp: int, capacity: int) -> Dictionary:
	var requirement := _requirement("named_product", [], capacity)
	requirement["product_id"] = product_id
	requirement["required_product_gdp"] = product_gdp
	return requirement


func _requirement_result(service: Node, requirements: Array, facts: Dictionary) -> Dictionary:
	return service.call("requirement_status", {
		"card_id": "qa.card",
		"skill": {
			"card_id": "qa.card",
			"name": "QA Card",
			"kind": "qa",
			"schema_version": "v0.5",
			"migration_status": "ready",
			"requirements": requirements.duplicate(true),
		},
	}, facts)


func _requirement_passed(result: Dictionary) -> bool:
	return bool(result.get("industry_capacity_satisfied", false))


func _requirement_reason(result: Dictionary) -> String:
	return str((result.get("industry_capacity_status", {}) as Dictionary).get("reason_code", ""))


func _reservation(result: Dictionary) -> Dictionary:
	return result.get("capacity_reservation", {}) as Dictionary if result.get("capacity_reservation", {}) is Dictionary else {}


func _selected_industry(result: Dictionary) -> String:
	var reservation := _reservation(result)
	var choices: Array = reservation.get("requirement_choices", []) if reservation.get("requirement_choices", []) is Array else []
	if choices.is_empty() or not (choices[0] is Dictionary):
		return ""
	var selected: Array = (choices[0] as Dictionary).get("selected_industries", []) if (choices[0] as Dictionary).get("selected_industries", []) is Array else []
	return str(selected[0]) if not selected.is_empty() else ""


func _capacity_reservation(capacity_snapshot: Dictionary, values: Dictionary) -> Dictionary:
	return {
		"capacity_revision": str(capacity_snapshot.get("capacity_revision", "")),
		"industries": values.duplicate(true),
		"requirement_choices": [],
	}


func _submit(queue: Node, player_index: int, slot_index: int, bid_cents: int, reservation: Dictionary, capacity_snapshot: Dictionary, limit: int, extra_context: Dictionary = {}) -> Dictionary:
	var context := extra_context.duplicate(true)
	context["selected_district"] = int(context.get("selected_district", 0))
	var request := {
		"player_index": player_index,
		"slot_index": slot_index,
		"already_queued": false,
		"group_card_limit": limit,
		"priority_bid_cents": bid_cents,
		"play_cash_cost_cents": 0,
		"financial_margin_cents": 0,
		"available_cash_cents": 100000,
		"cash_revision": "qa.cash.%d" % player_index,
		"capacity_reservation": reservation.duplicate(true),
		"entry_context": context,
		"skill": {"name": "qa.card.%d.%d" % [player_index, slot_index], "kind": "qa", "persistent": true},
	}
	var current_queue: Array = queue.call("current_queue")
	var active_window_sequence := int((current_queue[0] as Dictionary).get("window_sequence", 0)) if not current_queue.is_empty() else 0
	var facts := {
		"player_count": 4,
		"batch_locked": false,
		"counter_window_active": false,
		"simultaneous_timer": 8.0,
		"lock_duration": 2.0,
		"window_sequence": active_window_sequence,
		"reference_player": 0,
		"industry_capacity": capacity_snapshot.duplicate(true),
	}
	var plan: Dictionary = queue.call("plan_submission", request, facts)
	var commit := {}
	if bool(plan.get("accepted", false)):
		commit = queue.call("commit_submission", plan, {
			"authorized": true,
			"inventory_committed": true,
			"play_cost_authorized": true,
			"financial_margin_authorized": true,
			"priority_bid_escrow_authorized": true,
			"capacity_authorized": true,
		})
	return {"plan": plan, "commit": commit}


func _industry_gdp(snapshot: Dictionary, industry_id: String) -> int:
	var industries: Dictionary = snapshot.get("industries", {}) if snapshot.get("industries", {}) is Dictionary else {}
	var row: Dictionary = industries.get(industry_id, {}) if industries.get(industry_id, {}) is Dictionary else {}
	return int(row.get("attributable_gdp_per_minute", 0))


func _industry_capacity(snapshot: Dictionary, industry_id: String) -> int:
	var industries: Dictionary = snapshot.get("industries", {}) if snapshot.get("industries", {}) is Dictionary else {}
	var row: Dictionary = industries.get(industry_id, {}) if industries.get(industry_id, {}) is Dictionary else {}
	return int(row.get("total_capacity", 0))


func _bridge_is_non_owning(bridge: Node) -> bool:
	if coordinator != null and coordinator.get_node_or_null("CityTradeNetworkRuntimeController") != null:
		bridge.call("bind_city_trade_network_controller", coordinator.get_node("CityTradeNetworkRuntimeController"))
	var debug: Dictionary = bridge.call("debug_snapshot") if bridge.has_method("debug_snapshot") else {}
	return bool(debug.get("bridge_ready", false)) and not bool(debug.get("owns_project_state", true)) and not bool(debug.get("owns_gdp_formula", true)) and not bool(debug.get("owns_capacity_formula", true)) and not bool(debug.get("owns_queue_state", true))


func _production_owners_remain_v04() -> bool:
	if ruleset_bridge == null or coordinator == null:
		return false
	var profile: Dictionary = ruleset_bridge.call("active_profile")
	var catalog := coordinator.get_node_or_null("CardRuntimeCatalogService")
	var catalog_debug: Dictionary = catalog.call("debug_snapshot") if catalog != null and catalog.has_method("debug_snapshot") else {}
	return str(profile.get("ruleset_id", "")) == "v0.4" \
		and str(catalog_debug.get("catalog_resource_path", "")).contains("card_runtime_catalog_v04.tres") \
		and not str(catalog_debug.get("catalog_resource_path", "")).contains("v05")


func _legacy_algorithms_absent() -> bool:
	var main_source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var queue_source := FileAccess.get_file_as_string(QUEUE_SCRIPT_PATH)
	return not main_source.contains("func _apply_card_group_bid_chain") \
		and not main_source.contains("func _ruleset_group_card_limit") \
		and not queue_source.contains("func normalize_bids") \
		and not queue_source.contains("func bid_chain_plan") \
		and not queue_source.contains("func apply_bid_chain_receipts") \
		and not queue_source.contains("func highest_bid") \
		and not main_source.contains("func _calculate_industry_capacity")


func _has_methods(node: Node, methods: Array) -> bool:
	for method_variant in methods:
		if not node.has_method(str(method_variant)):
			return false
	return true


func _same_string_set(a_variant: Variant, b: Array) -> bool:
	var a: Array = a_variant if a_variant is Array else []
	if a.size() != b.size():
		return false
	for value_variant in b:
		if not a.has(str(value_variant)):
			return false
	return true


func _has_transition(commands: Array, transition: String) -> bool:
	for command_variant in commands:
		if command_variant is Dictionary and str((command_variant as Dictionary).get("transition", "")) == transition:
			return true
	return false


func _record(case_id: String, passed: bool, notes: String) -> Dictionary:
	return {
		"case_id": case_id,
		"industry_checked": case_id.contains("industry") or case_id.contains("capacity") or case_id.contains("product"),
		"eligibility_checked": case_id.contains("requirement") or case_id.contains("card") or case_id.contains("influence"),
		"reservation_checked": case_id.contains("reservation") or case_id.contains("drift"),
		"window_checked": case_id.contains("window") or case_id.contains("phase") or case_id.contains("ready") or case_id.contains("group_limit"),
		"wager_pool_checked": case_id.contains("bid") or case_id.contains("wager"),
		"save_checked": case_id.contains("save"),
		"privacy_checked": case_id.contains("public") or case_id.contains("owner") or case_id.contains("payer"),
		"pure_data_checked": case_id.contains("pure_data"),
		"legacy_fallback_used": false,
		"passed": passed,
		"notes": notes,
	}


func _case_note(case_id: String) -> String:
	return case_id.replace("_", " ")


func _update_ui(manifest: Dictionary) -> void:
	summary_label.text = "%d/%d SS05-05 cases passed" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))]
	status_label.text = "PASS" if _failures.is_empty() else "FAIL"
	status_label.modulate = Color("4ade80") if _failures.is_empty() else Color("fb7185")
	rules_text.text = "[b]SS05-05 runtime ownership[/b]\nSix industries from attributable GDP/min\nCapacity thresholds 15 / 40 / 80 / 140\nCard requirements: colorless, single, dual, either, named product\nCapacity reserved cumulatively per unresolved player group\n\n[b]Shared card group[/b]\n8 seconds total\n6 seconds organize\n2 seconds lock\nTutorial 1 card / standard 2 cards\nFixed priority bids: 0 / 50 / 100 cash\nAll bids enter the next public monster-wager pool"
	var lines: Array[String] = []
	for record_variant in _records:
		var record: Dictionary = record_variant
		lines.append("[color=%s]%s[/color]  %s" % ["#4ade80" if bool(record.get("passed", false)) else "#fb7185", "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("case_id", ""))])
	results_text.text = "\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines := [
		"# SS05-05 Industry Capacity And Card Group Runtime",
		"",
		"- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"- Production global Ruleset: v0.4",
		"- Domain rules: v0.5",
		"- Legacy bid-chain fallback: absent",
		"",
		"| Case | Result | Notes |",
		"| --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| `%s` | %s | %s |" % [str(record.get("case_id", "")), "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("notes", "")).replace("|", "\\|")])
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
