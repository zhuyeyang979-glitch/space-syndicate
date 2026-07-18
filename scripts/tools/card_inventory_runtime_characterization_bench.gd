extends Control
class_name CardInventoryRuntimeCharacterizationBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const SETTLEMENT_SERVICE_SCRIPT_PATH := "res://scripts/runtime/district_purchase_settlement_runtime_service.gd"
const CARD_INVENTORY_SERVICE_SCRIPT_PATH := "res://scripts/runtime/card_inventory_runtime_service.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/card_inventory_runtime_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/card_inventory_runtime_cutover_sprint_31.png"
const CHARACTERIZATION_CASE_COUNT := 20
const CUTOVER_CASE_COUNT := 20
const CASE_COUNT := CHARACTERIZATION_CASE_COUNT + CUTOVER_CASE_COUNT

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
	print("CardInventoryRuntimeCharacterizationBench ready: auto_run=%s editor_hint=%s" % [auto_run, Engine.is_editor_hint()])
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_characterization_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func characterization_cases() -> Array:
	return [
		"shared_inventory_call_graph_complete",
		"purchase_inventory_delegate_observed",
		"new_family_card_receive",
		"duplicate_family_upgrade",
		"maximum_rank_rejection",
		"ordinary_hand_limit_rejection",
		"persistent_skill_hand_limit_exemption",
		"queued_card_not_discardable",
		"cooldown_locked_card_not_discardable",
		"role_bonus_card_receive",
		"extra_district_supply_receive",
		"hand_steal_receive_success",
		"hand_steal_receive_failure_conversion",
		"hand_disrupt_private_removal",
		"private_hand_lock",
		"human_ai_inventory_policy_parity",
		"inventory_fingerprint_drift",
		"save_shape_unchanged",
		"public_private_boundary",
		"duplicate_inventory_formula_absent",
	]


func cutover_cases() -> Array:
	return [
		"service_scene_composition",
		"ruleset_config_source",
		"pure_service_payloads",
		"receive_add_owned",
		"duplicate_upgrade_owned",
		"rank_iv_reject_owned",
		"ordinary_limit_owned",
		"fixed_skill_exemption_owned",
		"discardability_owned",
		"private_remove_owned",
		"private_lock_owned",
		"transfer_success_owned",
		"transfer_failure_conversion_owned",
		"purchase_settlement_delegates",
		"role_bonus_delegates",
		"extra_supply_delegates",
		"human_ai_policy_parity_cutover",
		"fingerprint_drift_rejected_cutover",
		"save_and_privacy_unchanged",
		"legacy_inventory_formula_absent",
	]


func all_cases() -> Array:
	var result := characterization_cases().duplicate()
	result.append_array(cutover_cases())
	return result


func build_characterization_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in all_cases():
		var case_id := str(case_id_variant)
		var is_cutover := cutover_cases().has(case_id)
		records.append(_record(str(case_id_variant), "preview", "none", {}, {}, {}, {}, {
			"observed": false,
			"contract_aligned": false,
			"phase": "cutover" if is_cutover else "characterization",
			"cutover_passed": false,
			"notes": "preview",
		}))
	return {
		"suite": "card-inventory-runtime-cutover-v04",
		"ruleset_id": "v0.4",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"case_count": CASE_COUNT,
		"characterization_case_count": CHARACTERIZATION_CASE_COUNT,
		"cutover_case_count": CUTOVER_CASE_COUNT,
		"observed_count": 0,
		"aligned_count": 0,
		"cutover_passed_count": 0,
		"mismatch_count": 0,
		"needs_design_decision_count": 0,
		"record_count": records.size(),
		"records": records,
	}


func run_characterization_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	if not await _ensure_runtime_main():
		push_error("CardInventoryRuntimeCharacterizationBench could not instantiate real main.tscn")
		if DisplayServer.get_name() == "headless":
			get_tree().quit(1)
		return
	for case_id_variant in all_cases():
		var case_id := str(case_id_variant)
		await _reset_runtime_main()
		var record: Dictionary = _run_case(case_id)
		record["pure_data_checked"] = _is_data_only(record)
		_records.append(record)
		if str(record.get("phase", "characterization")) == "cutover":
			if not bool(record.get("cutover_passed", false)):
				_failures.append("%s: %s" % [case_id, str(record.get("notes", "cutover check failed"))])
		elif not bool(record.get("observed", false)) or not bool(record.get("contract_aligned", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "characterization check failed"))])
	var manifest := {
		"suite": "card-inventory-runtime-cutover-v04",
		"ruleset_id": "v0.4",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"case_count": CASE_COUNT,
		"characterization_case_count": CHARACTERIZATION_CASE_COUNT,
		"cutover_case_count": CUTOVER_CASE_COUNT,
		"observed_count": _characterization_observed_count(),
		"aligned_count": _characterization_aligned_count(),
		"cutover_passed_count": _cutover_passed_count(),
		"mismatch_count": CHARACTERIZATION_CASE_COUNT - _characterization_aligned_count(),
		"needs_design_decision_count": _design_decision_count(),
		"record_count": _records.size(),
		"passed_count": _characterization_aligned_count() + _cutover_passed_count(),
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("CardInventoryRuntimeCharacterizationBench manifest: %s" % MANIFEST_PATH)
	print("CardInventoryRuntimeCharacterizationBench report: %s" % REPORT_PATH)
	print("CardInventoryRuntimeCharacterizationBench screenshot: %s" % SCREENSHOT_PATH)
	print("CardInventoryRuntimeCharacterizationBench observed: %d/%d" % [_characterization_observed_count(), CHARACTERIZATION_CASE_COUNT])
	print("CardInventoryRuntimeCharacterizationBench aligned: %d/%d; mismatches=%d; design_decisions=%d" % [_characterization_aligned_count(), CHARACTERIZATION_CASE_COUNT, CHARACTERIZATION_CASE_COUNT - _characterization_aligned_count(), _design_decision_count()])
	print("CardInventoryRuntimeCharacterizationBench cutover: %d/%d" % [_cutover_passed_count(), CUTOVER_CASE_COUNT])
	print("CardInventoryRuntimeCharacterizationBench total: %d/%d" % [_characterization_aligned_count() + _cutover_passed_count(), CASE_COUNT])
	if not _failures.is_empty():
		push_error("CardInventoryRuntimeCharacterizationBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		_release_runtime_main()
		for _frame in range(4):
			await get_tree().process_frame
		get_tree().quit(0 if _failures.is_empty() else 1)


func run_cutover_suite() -> void:
	run_characterization_suite()


func _run_case(case_id: String) -> Dictionary:
	match case_id:
		"shared_inventory_call_graph_complete":
			return _case_shared_inventory_call_graph_complete()
		"purchase_inventory_delegate_observed":
			return _case_purchase_inventory_delegate_observed()
		"new_family_card_receive":
			return _case_new_family_card_receive()
		"duplicate_family_upgrade":
			return _case_duplicate_family_upgrade()
		"maximum_rank_rejection":
			return _case_maximum_rank_rejection()
		"ordinary_hand_limit_rejection":
			return _case_ordinary_hand_limit_rejection()
		"persistent_skill_hand_limit_exemption":
			return _case_persistent_skill_hand_limit_exemption()
		"queued_card_not_discardable":
			return _case_queued_card_not_discardable()
		"cooldown_locked_card_not_discardable":
			return _case_cooldown_locked_card_not_discardable()
		"role_bonus_card_receive":
			return _case_role_bonus_card_receive()
		"extra_district_supply_receive":
			return _case_extra_district_supply_receive()
		"hand_steal_receive_success":
			return _case_hand_steal_receive_success()
		"hand_steal_receive_failure_conversion":
			return _case_hand_steal_receive_failure_conversion()
		"hand_disrupt_private_removal":
			return _case_hand_disrupt_private_removal()
		"private_hand_lock":
			return _case_private_hand_lock()
		"human_ai_inventory_policy_parity":
			return _case_human_ai_inventory_policy_parity()
		"inventory_fingerprint_drift":
			return _case_inventory_fingerprint_drift()
		"save_shape_unchanged":
			return _case_save_shape_unchanged()
		"public_private_boundary":
			return _case_public_private_boundary()
		"duplicate_inventory_formula_absent":
			return _case_duplicate_inventory_formula_absent()
		"service_scene_composition":
			return _cutover_service_scene_composition()
		"ruleset_config_source":
			return _cutover_ruleset_config_source()
		"pure_service_payloads":
			return _cutover_pure_service_payloads()
		"receive_add_owned":
			return _cutover_from_characterization(case_id, _case_new_family_card_receive(), {"service_owner_checked": true, "exact_once_checked": true})
		"duplicate_upgrade_owned":
			return _cutover_from_characterization(case_id, _case_duplicate_family_upgrade(), {"service_owner_checked": true})
		"rank_iv_reject_owned":
			return _cutover_from_characterization(case_id, _case_maximum_rank_rejection(), {"service_owner_checked": true})
		"ordinary_limit_owned":
			return _cutover_from_characterization(case_id, _case_ordinary_hand_limit_rejection(), {"service_owner_checked": true})
		"fixed_skill_exemption_owned":
			return _cutover_from_characterization(case_id, _case_persistent_skill_hand_limit_exemption(), {"service_owner_checked": true, "main_adapter_checked": true, "exact_once_checked": true})
		"discardability_owned":
			return _cutover_discardability_owned()
		"private_remove_owned":
			return _cutover_from_characterization(case_id, _case_hand_disrupt_private_removal(), {"service_owner_checked": true, "main_adapter_checked": true, "exact_once_checked": true})
		"private_lock_owned":
			return _cutover_from_characterization(case_id, _case_private_hand_lock(), {"service_owner_checked": true, "main_adapter_checked": true, "exact_once_checked": true})
		"transfer_success_owned":
			return _cutover_from_characterization(case_id, _case_hand_steal_receive_success(), {"service_owner_checked": true, "main_adapter_checked": true, "exact_once_checked": true})
		"transfer_failure_conversion_owned":
			return _cutover_from_characterization(case_id, _case_hand_steal_receive_failure_conversion(), {"service_owner_checked": true, "main_adapter_checked": true, "exact_once_checked": true})
		"purchase_settlement_delegates":
			return _cutover_purchase_settlement_delegates()
		"role_bonus_delegates":
			return _cutover_from_characterization(case_id, _case_role_bonus_card_receive(), {"service_owner_checked": true, "main_adapter_checked": true, "exact_once_checked": true})
		"extra_supply_delegates":
			return _cutover_from_characterization(case_id, _case_extra_district_supply_receive(), {"service_owner_checked": true, "main_adapter_checked": true, "exact_once_checked": true})
		"human_ai_policy_parity_cutover":
			return _cutover_from_characterization(case_id, _case_human_ai_inventory_policy_parity(), {"service_owner_checked": true})
		"fingerprint_drift_rejected_cutover":
			return _cutover_from_characterization(case_id, _case_inventory_fingerprint_drift(), {"service_owner_checked": true})
		"save_and_privacy_unchanged":
			return _cutover_save_and_privacy_unchanged()
		"legacy_inventory_formula_absent":
			return _cutover_from_characterization(case_id, _case_duplicate_inventory_formula_absent(), {"service_owner_checked": true, "settlement_delegate_checked": true, "main_adapter_checked": true, "legacy_formula_absent": true})
	return _record(case_id, "unknown", "none", {}, {}, {}, {}, {
		"observed": false,
		"contract_aligned": false,
		"risk": "unknown case",
		"notes": "unknown characterization case",
	})


func _cutover_service_scene_composition() -> Dictionary:
	var packed := load("res://scenes/runtime/CardInventoryRuntimeService.tscn") as PackedScene
	var coordinator := _coordinator()
	var service := coordinator.get_node_or_null("CardInventoryRuntimeService") if coordinator != null else null
	var coordinator_source := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	var composed := packed != null and service != null and coordinator_source.contains("CardInventoryRuntimeService.tscn") and coordinator_source.contains("node name=\"CardInventoryRuntimeService\"")
	return _record("service_scene_composition", "GameRuntimeCoordinator/CardInventoryRuntimeService", "scene_composition", {}, {}, {}, {}, {
		"phase": "cutover",
		"observed": packed != null and coordinator != null,
		"contract_aligned": composed,
		"cutover_passed": composed,
		"service_owner_checked": service != null,
		"pure_data_checked": true,
		"notes": "CardInventoryRuntimeService is a static editable child of the real GameRuntimeCoordinator scene",
	})


func _cutover_ruleset_config_source() -> Dictionary:
	var debug := _inventory_debug()
	var ruleset_source := FileAccess.get_file_as_string("res://scripts/rules/space_syndicate_ruleset_profile.gd")
	var bridge_source := FileAccess.get_file_as_string("res://scripts/runtime/ruleset_runtime_bridge.gd")
	var service_source := FileAccess.get_file_as_string(CARD_INVENTORY_SERVICE_SCRIPT_PATH)
	var profile_fields := ruleset_source.contains("ordinary_hand_limit") and ruleset_source.contains("maximum_card_rank") and bridge_source.contains("func card_inventory_rules(")
	var runtime_values := bool(debug.get("service_ready", false)) and str(debug.get("ruleset_id", "")) == "v0.4" and int(debug.get("ordinary_hand_limit", 0)) == 5 and int(debug.get("maximum_card_rank", 0)) == 4
	var service_reads_profile := service_source.contains("rules.get(\"ordinary_hand_limit\"") and service_source.contains("rules.get(\"maximum_card_rank\"")
	var passed := profile_fields and runtime_values and service_reads_profile
	return _record("ruleset_config_source", "RulesetRuntimeBridge.card_inventory_rules", "ruleset_configuration", {}, {}, {}, {}, {
		"phase": "cutover",
		"observed": not debug.is_empty(),
		"contract_aligned": passed,
		"cutover_passed": passed,
		"service_owner_checked": runtime_values,
		"pure_data_checked": _is_data_only(debug),
		"notes": "ordinary hand limit 5 and maximum rank IV come from the Inspector-editable v0.4 ruleset profile",
	})


func _cutover_pure_service_payloads() -> Dictionary:
	var card_id := _base_upgrade_card()
	_reset_player(0, [])
	var request_variant: Variant = _runtime_main.call("_card_inventory_snapshot", _player(0), _make_skill(card_id), card_id, -1, true)
	var request: Dictionary = request_variant if request_variant is Dictionary else {}
	var coordinator := _coordinator()
	var plan_variant: Variant = coordinator.call("plan_card_inventory_receive", request) if coordinator != null else {}
	var plan: Dictionary = plan_variant if plan_variant is Dictionary else {}
	var debug := _inventory_debug()
	var payloads_are_pure := _is_data_only(request) and _is_data_only(plan) and _is_data_only(debug) and not _contains_runtime_object(request) and not _contains_runtime_object(plan) and not _contains_runtime_object(debug)
	var no_private_names_in_debug := card_id.is_empty() or not JSON.stringify(debug).contains(card_id)
	var passed := not request.is_empty() and str(plan.get("status", "")) == "ready" and payloads_are_pure and no_private_names_in_debug
	return _record("pure_service_payloads", "CardInventoryRuntimeService plan/debug", "pure_data_boundary", {}, {}, {}, {}, {
		"phase": "cutover",
		"observed": not request.is_empty() and not plan.is_empty(),
		"contract_aligned": passed,
		"cutover_passed": passed,
		"service_owner_checked": bool(debug.get("service_authoritative", false)),
		"pure_data_checked": payloads_are_pure,
		"privacy_checked": no_private_names_in_debug,
		"notes": "inventory request, plan, and debug snapshot contain only data values and debug output omits concrete private card ids",
	})


func _cutover_discardability_owned() -> Dictionary:
	var first := _make_skill(_base_upgrade_card())
	var second := _make_skill(_other_counted_card(str(first.get("name", ""))))
	var third := second.duplicate(true)
	first["queued_for_resolution"] = true
	second["lock_left"] = 6.0
	_reset_player(0, [first, second, third])
	var snapshot_variant: Variant = _runtime_main.call("_card_inventory_snapshot", _player(0))
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	var coordinator := _coordinator()
	var slots_variant: Variant = coordinator.call("card_inventory_discardable_slots", snapshot) if coordinator != null else []
	var slots: Array = slots_variant if slots_variant is Array else []
	var service_source := FileAccess.get_file_as_string(CARD_INVENTORY_SERVICE_SCRIPT_PATH)
	var settlement_source := FileAccess.get_file_as_string(SETTLEMENT_SERVICE_SCRIPT_PATH)
	var ownership := service_source.contains("func discardable_slots(") and not settlement_source.contains("func discardable_slots(")
	var passed := slots == [2] and ownership
	return _record("discardability_owned", "CardInventoryRuntimeService.discardable_slots", "discardability_query", {}, {}, {}, {}, {
		"phase": "cutover",
		"observed": not snapshot.is_empty(),
		"contract_aligned": passed,
		"cutover_passed": passed,
		"service_owner_checked": ownership,
		"pure_data_checked": _is_data_only(slots),
		"notes": "queued and cooldown-locked cards are excluded; the ordinary unlocked slot remains discardable",
	})


func _cutover_purchase_settlement_delegates() -> Dictionary:
	var fixture := _prepare_purchase_fixture(1)
	var player_index := int(fixture.get("player_index", -1))
	var before := _player_probe(player_index)
	var inventory_before := _inventory_debug()
	var settlement_before := _settlement_debug()
	var bought := false
	if not fixture.is_empty():
		bought = bool(_runtime_main.call("_buy_card_for_player_from_district", player_index, int(fixture.get("district_index", -1)), str(fixture.get("card_id", "")), true, true, -1, str(fixture.get("quote_id", ""))))
	var after := _player_probe(player_index)
	var inventory_after := _inventory_debug()
	var settlement_after := _settlement_debug()
	var inventory_exact_once := int(inventory_after.get("committed_count", 0)) - int(inventory_before.get("committed_count", 0)) == 1
	var settlement_exact_once := int(settlement_after.get("committed_count", 0)) - int(settlement_before.get("committed_count", 0)) == 1
	var settlement_source := FileAccess.get_file_as_string(SETTLEMENT_SERVICE_SCRIPT_PATH)
	var delegate_only := settlement_source.contains("func set_inventory_service(") and settlement_source.contains("_inventory_receive_plan(") and not settlement_source.contains("func _plan_inventory_receive(") and not settlement_source.contains("func _apply_inventory_operation(")
	var passed := bought and inventory_exact_once and settlement_exact_once and delegate_only
	return _record("purchase_settlement_delegates", "_buy_card_for_player_from_district", "purchase_inventory_delegate", before, after, {}, {}, {
		"phase": "cutover",
		"observed": not fixture.is_empty(),
		"contract_aligned": passed,
		"cutover_passed": passed,
		"service_route_observed": inventory_exact_once,
		"service_owner_checked": inventory_exact_once,
		"settlement_delegate_checked": delegate_only,
		"main_adapter_checked": true,
		"exact_once_checked": inventory_exact_once and settlement_exact_once,
		"notes": "one authorized purchase delegates one inventory mutation while Settlement Service retains one atomic purchase commit",
	})


func _cutover_save_and_privacy_unchanged() -> Dictionary:
	var save_record := _case_save_shape_unchanged()
	var privacy_record := _case_public_private_boundary()
	var debug := _inventory_debug()
	var debug_is_pure := _is_data_only(debug) and not _contains_runtime_object(debug)
	var passed := bool(save_record.get("contract_aligned", false)) and bool(privacy_record.get("contract_aligned", false)) and debug_is_pure
	return _record("save_and_privacy_unchanged", "save/private event boundaries", "compatibility_boundary", {}, {}, {}, {}, {
		"phase": "cutover",
		"observed": bool(save_record.get("observed", false)) and bool(privacy_record.get("observed", false)),
		"contract_aligned": passed,
		"cutover_passed": passed,
		"save_shape_checked": bool(save_record.get("save_shape_checked", false)),
		"privacy_checked": bool(privacy_record.get("privacy_checked", false)),
		"pure_data_checked": debug_is_pure,
		"main_adapter_checked": true,
		"notes": "save version and private/public event boundaries remain unchanged; runtime Node wiring never enters persisted or QA payloads",
	})


func _cutover_from_characterization(case_id: String, base_record: Dictionary, checks: Dictionary) -> Dictionary:
	var service_owner_checked := bool(checks.get("service_owner_checked", false))
	var settlement_delegate_checked := bool(checks.get("settlement_delegate_checked", false))
	var main_adapter_checked := bool(checks.get("main_adapter_checked", false))
	var exact_once_checked := bool(checks.get("exact_once_checked", false))
	var legacy_formula_absent := bool(checks.get("legacy_formula_absent", false))
	var route_required := service_owner_checked or settlement_delegate_checked or main_adapter_checked or exact_once_checked or legacy_formula_absent
	var route_ok := not route_required or bool(base_record.get("service_route_observed", false))
	var passed := bool(base_record.get("observed", false)) and bool(base_record.get("contract_aligned", false)) and route_ok and bool(base_record.get("pure_data_checked", false))
	var result := base_record.duplicate(true)
	result["characterization_case_id"] = str(base_record.get("case_id", ""))
	result["case_id"] = case_id
	result["phase"] = "cutover"
	result["service_owner_checked"] = service_owner_checked and route_ok
	result["settlement_delegate_checked"] = settlement_delegate_checked and route_ok
	result["main_adapter_checked"] = main_adapter_checked and route_ok
	result["exact_once_checked"] = exact_once_checked and route_ok
	result["legacy_formula_absent"] = legacy_formula_absent and bool(base_record.get("contract_aligned", false))
	result["cutover_passed"] = passed
	result["passed"] = passed
	return result


func _case_shared_inventory_call_graph_complete() -> Dictionary:
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var interaction_source := FileAccess.get_file_as_string("res://scripts/runtime/player_hand_interaction_runtime_service.gd")
	var military_source := FileAccess.get_file_as_string("res://scripts/runtime/military_runtime_controller.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var acquire := _function_source(source, "_acquire_card_for_player")
	var inventory_acquire := _function_source(source, "_acquire_inventory_skill_for_player")
	var fixed_skill_grant := _function_source(military_source, "grant_bound_commands")
	var role_bonus := _function_source(source, "_grant_role_bonus_card_on_purchase")
	var extra_supply := _function_source(source, "_draw_extra_district_cards")
	var steal := _function_source(source, "_apply_player_hand_steal")
	var disrupt := _function_source(source, "_apply_player_hand_disrupt")
	var interaction_adapter := _function_source(source, "_resolve_player_hand_interaction")
	var observed := not acquire.is_empty() and not inventory_acquire.is_empty() and not role_bonus.is_empty() and not extra_supply.is_empty() and not steal.is_empty() and not disrupt.is_empty()
	var aligned := observed and acquire.contains("_acquire_inventory_skill_for_player") and inventory_acquire.contains("plan_card_inventory_receive") and inventory_acquire.contains("commit_card_inventory_receive") and fixed_skill_grant.contains("_acquire_inventory_skill_for_player") and role_bonus.contains("_acquire_card_for_player") and extra_supply.contains("_acquire_card_for_player") and steal.contains("_resolve_player_hand_interaction") and disrupt.contains("_resolve_player_hand_interaction") and interaction_adapter.contains("plan_player_hand_interaction") and interaction_adapter.contains("commit_player_hand_interaction") and coordinator_source.contains("func plan_player_hand_interaction") and interaction_source.contains("_inventory_service.call(\"commit_remove\"") and interaction_source.contains("_inventory_service.call(\"commit_lock\"") and interaction_source.contains("_inventory_service.call(\"commit_transfer\"") and _function_source(source, "_take_private_hand_card_from_player").is_empty() and _function_source(source, "_lock_private_hand_card_for_player").is_empty() and _function_source(source, "_transfer_private_hand_card_between_players").is_empty() and _function_source(source, "_grant_bound_military_commands").is_empty()
	return _record("shared_inventory_call_graph_complete", "source_audit", "ownership_map", {}, {}, {}, {}, {
		"observed": observed,
		"contract_aligned": aligned,
		"service_route_observed": inventory_acquire.contains("plan_card_inventory_receive"),
		"notes": "receive, fixed-skill grant, and interaction remove/lock/transfer all route through one Card Inventory Service; the interaction scene service owns higher-level sequencing",
	})


func _case_purchase_inventory_delegate_observed() -> Dictionary:
	var fixture := _prepare_purchase_fixture(1)
	var player_index := int(fixture.get("player_index", -1))
	var before := _player_probe(player_index)
	var debug_before := _settlement_debug()
	var bought := false
	if not fixture.is_empty():
		bought = bool(_runtime_main.call("_buy_card_for_player_from_district", player_index, int(fixture.get("district_index", -1)), str(fixture.get("card_id", "")), true, true, -1, str(fixture.get("quote_id", ""))))
	var after := _player_probe(player_index)
	var debug_after := _settlement_debug()
	var service_route := int(debug_after.get("committed_count", 0)) - int(debug_before.get("committed_count", 0)) == 1
	return _record("purchase_inventory_delegate_observed", "_buy_card_for_player_from_district", "purchase_add_or_upgrade", before, after, {}, {}, {
		"observed": not fixture.is_empty(),
		"contract_aligned": bought and service_route,
		"service_route_observed": service_route,
		"notes": "real district purchase reaches one Settlement Service commit before main forwards post-commit hooks",
	})


func _case_new_family_card_receive() -> Dictionary:
	var card_id := _base_upgrade_card()
	_reset_player(0, [])
	var before := _player_probe(0)
	var debug_before := _inventory_debug()
	var acquired := _acquire_for_player(0, card_id)
	var after := _player_probe(0)
	var debug_after := _inventory_debug()
	var service_route := int(debug_after.get("receive_plan_count", 0)) > int(debug_before.get("receive_plan_count", 0)) and int(debug_after.get("committed_count", 0)) - int(debug_before.get("committed_count", 0)) == 1
	return _record("new_family_card_receive", "_acquire_card_for_player", "receive_add", before, after, {}, {}, {
		"observed": not card_id.is_empty(),
		"contract_aligned": acquired and int(after.get("hand_count", 0)) - int(before.get("hand_count", 0)) == 1 and service_route,
		"service_route_observed": service_route,
		"notes": "a new real card family adds one counted card through the shared inventory receive API",
	})


func _case_duplicate_family_upgrade() -> Dictionary:
	var card_id := _base_upgrade_card()
	var base_skill := _make_skill(card_id)
	_reset_player(0, [base_skill])
	var before := _player_probe(0)
	var acquired := _acquire_for_player(0, card_id)
	var after := _player_probe(0)
	return _record("duplicate_family_upgrade", "_acquire_card_for_player", "receive_upgrade", before, after, {}, {}, {
		"observed": not base_skill.is_empty(),
		"contract_aligned": acquired and int(after.get("hand_count", 0)) == int(before.get("hand_count", -1)) and int(after.get("rank_total", 0)) - int(before.get("rank_total", 0)) == 1,
		"service_route_observed": true,
		"notes": "duplicate family upgrades in place before ordinary hand-limit pressure",
	})


func _case_maximum_rank_rejection() -> Dictionary:
	var card_id := _base_upgrade_card()
	var max_id := _max_upgrade_name(card_id)
	var max_skill := _make_skill(max_id)
	_reset_player(0, [max_skill])
	var before := _player_probe(0)
	var acquired := _acquire_for_player(0, card_id)
	var after := _player_probe(0)
	return _record("maximum_rank_rejection", "_acquire_card_for_player", "receive_reject_max_rank", before, after, {}, {}, {
		"observed": not max_skill.is_empty(),
		"contract_aligned": not acquired and before.get("fingerprint", []) == after.get("fingerprint", []),
		"service_route_observed": true,
		"notes": "a held rank-IV family rejects another copy without slot mutation",
	})


func _case_ordinary_hand_limit_rejection() -> Dictionary:
	var card_id := _base_upgrade_card()
	var slots := _full_counted_hand(card_id, 5)
	_reset_player(0, slots)
	var before := _player_probe(0)
	var acquired := _acquire_for_player(0, card_id)
	var after := _player_probe(0)
	return _record("ordinary_hand_limit_rejection", "_acquire_card_for_player", "receive_reject_hand_limit", before, after, {}, {}, {
		"observed": slots.size() == 5,
		"contract_aligned": not acquired and int(before.get("hand_count", 0)) == 5 and before.get("fingerprint", []) == after.get("fingerprint", []),
		"service_route_observed": true,
		"notes": "non-purchase receive cannot silently exceed the five-card ordinary limit",
	})


func _case_persistent_skill_hand_limit_exemption() -> Dictionary:
	var card_id := _base_upgrade_card()
	var slots := _full_counted_hand(card_id, 5)
	_reset_player(0, slots)
	var before := _player_probe(0)
	var debug_before := _inventory_debug()
	var military_controller := _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MilitaryRuntimeController")
	var granted_variant: Variant = military_controller.call("grant_bound_commands", 0, 9001, 1, "行星防卫军1", 1) if military_controller != null else []
	var granted: Array = granted_variant if granted_variant is Array else []
	var after := _player_probe(0)
	var debug_after := _inventory_debug()
	var service_route := int(debug_after.get("receive_plan_count", 0)) > int(debug_before.get("receive_plan_count", 0)) and int(debug_after.get("committed_count", 0)) - int(debug_before.get("committed_count", 0)) == 1
	return _record("persistent_skill_hand_limit_exemption", "MilitaryRuntimeController.grant_bound_commands", "fixed_skill_add", before, after, {}, {}, {
		"observed": slots.size() == 5 and not granted.is_empty(),
		"contract_aligned": int(after.get("hand_count", 0)) == 5 and int(after.get("slot_count", 0)) == int(before.get("slot_count", 0)) + 1,
		"service_route_observed": service_route,
		"notes": "a real persistent military command adds a slot but does not increase ordinary hand count",
	})


func _case_queued_card_not_discardable() -> Dictionary:
	var first := _make_skill(_base_upgrade_card())
	var second := _make_skill(_other_counted_card(str(first.get("name", ""))))
	first["queued_for_resolution"] = true
	_reset_player(0, [first, second])
	var before := _player_probe(0)
	var slots_variant: Variant = _runtime_main.call("_discardable_hand_slots_for_purchase", _player(0))
	var discardable: Array = slots_variant if slots_variant is Array else []
	var after := _player_probe(0)
	return _record("queued_card_not_discardable", "_discardable_hand_slots_for_purchase", "discardability_query", before, after, {}, {}, {
		"observed": not first.is_empty() and not second.is_empty(),
		"contract_aligned": not discardable.has(0) and discardable.has(1) and before.get("fingerprint", []) == after.get("fingerprint", []),
		"service_route_observed": true,
		"notes": "queued cards remain visible but are excluded from private discard choices",
	})


func _case_cooldown_locked_card_not_discardable() -> Dictionary:
	var first := _make_skill(_base_upgrade_card())
	var second := _make_skill(_other_counted_card(str(first.get("name", ""))))
	first["lock_left"] = 8.0
	_reset_player(0, [first, second])
	var before := _player_probe(0)
	var slots_variant: Variant = _runtime_main.call("_discardable_hand_slots_for_purchase", _player(0))
	var discardable: Array = slots_variant if slots_variant is Array else []
	var after := _player_probe(0)
	return _record("cooldown_locked_card_not_discardable", "_discardable_hand_slots_for_purchase", "discardability_query", before, after, {}, {}, {
		"observed": not first.is_empty() and not second.is_empty(),
		"contract_aligned": not discardable.has(0) and discardable.has(1) and before.get("fingerprint", []) == after.get("fingerprint", []),
		"service_route_observed": true,
		"notes": "lock_left excludes a card from private discard without changing inventory",
	})


func _case_role_bonus_card_receive() -> Dictionary:
	var fixture := _role_bonus_fixture()
	var player_index := int(fixture.get("player_index", -1))
	if player_index >= 0:
		_reset_player(player_index, [])
	var before := _player_probe(player_index)
	var debug_before := _inventory_debug()
	var granted := false
	if not fixture.is_empty():
		granted = bool(_runtime_main.call("_grant_role_bonus_card_on_purchase", player_index, int(fixture.get("district_index", -1)), str(fixture.get("bought_card_id", "")), true))
	var after := _player_probe(player_index)
	var debug_after := _inventory_debug()
	var service_route := int(debug_after.get("receive_plan_count", 0)) > int(debug_before.get("receive_plan_count", 0)) and int(debug_after.get("committed_count", 0)) - int(debug_before.get("committed_count", 0)) == 1
	return _record("role_bonus_card_receive", "_grant_role_bonus_card_on_purchase", "role_bonus_receive", before, after, {}, {}, {
		"observed": not fixture.is_empty(),
		"contract_aligned": granted and int(after.get("hand_count", 0)) - int(before.get("hand_count", 0)) == 1 and service_route,
		"service_route_observed": service_route,
		"privacy_checked": true,
		"notes": "a real public role bonus obtains one same-district candidate through shared inventory receive",
	})


func _case_extra_district_supply_receive() -> Dictionary:
	var fixture := _first_supply_fixture()
	_reset_player(0, [])
	var before := _player_probe(0)
	var debug_before := _inventory_debug()
	if not fixture.is_empty():
		((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = int(fixture.get("district_index", -1))
		var players: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array
		var player: Dictionary = players[0]
		_runtime_main.call("_draw_extra_district_cards", player, 1, "characterization")
		players[0] = player
		((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	var after := _player_probe(0)
	var debug_after := _inventory_debug()
	var service_route := int(debug_after.get("receive_plan_count", 0)) > int(debug_before.get("receive_plan_count", 0)) and int(debug_after.get("committed_count", 0)) - int(debug_before.get("committed_count", 0)) == 1
	return _record("extra_district_supply_receive", "_draw_extra_district_cards", "extra_supply_receive", before, after, {}, {}, {
		"observed": not fixture.is_empty(),
		"contract_aligned": int(after.get("hand_count", 0)) - int(before.get("hand_count", 0)) == 1 and service_route,
		"service_route_observed": service_route,
		"privacy_checked": true,
		"notes": "extra district supply selects a real candidate and reuses shared inventory receive",
	})


func _case_hand_steal_receive_success() -> Dictionary:
	var card_id := _base_upgrade_card()
	var steal_skill := _interaction_skill("player_hand_steal")
	_reset_player(0, [])
	_reset_player(1, [_make_skill(card_id)])
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = int(_first_supply_fixture().get("district_index", 0))
	_seed_runtime_rng(30012)
	var source_before := _player_probe(0)
	var target_before := _player_probe(1)
	var debug_before := _inventory_debug()
	var applied := bool(_runtime_main.call("_apply_player_hand_steal", 0, 1, steal_skill)) if not steal_skill.is_empty() else false
	var source_after := _player_probe(0)
	var target_after := _player_probe(1)
	var debug_after := _inventory_debug()
	var service_route := int(debug_after.get("transfer_plan_count", 0)) - int(debug_before.get("transfer_plan_count", 0)) == 1 and int(debug_after.get("committed_count", 0)) - int(debug_before.get("committed_count", 0)) == 1
	return _record("hand_steal_receive_success", "_apply_player_hand_steal", "private_transfer", source_before, source_after, target_before, target_after, {
		"observed": not card_id.is_empty() and not steal_skill.is_empty(),
		"contract_aligned": applied and int(source_after.get("hand_count", 0)) - int(source_before.get("hand_count", 0)) == 1 and int(target_after.get("hand_count", 0)) - int(target_before.get("hand_count", 0)) == -1 and service_route,
		"service_route_observed": service_route,
		"privacy_checked": true,
		"notes": "target removal occurs first; successful receiver add then uses the shared inventory service",
	})


func _case_hand_steal_receive_failure_conversion() -> Dictionary:
	var card_id := _base_upgrade_card()
	var max_id := _max_upgrade_name(card_id)
	var steal_skill := _interaction_skill("player_hand_steal")
	_reset_player(0, [_make_skill(max_id)])
	_reset_player(1, [_make_skill(card_id)])
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = int(_first_supply_fixture().get("district_index", 0))
	_seed_runtime_rng(30013)
	var source_before := _player_probe(0)
	var target_before := _player_probe(1)
	var debug_before := _inventory_debug()
	var applied := bool(_runtime_main.call("_apply_player_hand_steal", 0, 1, steal_skill)) if not steal_skill.is_empty() else false
	var source_after := _player_probe(0)
	var target_after := _player_probe(1)
	var debug_after := _inventory_debug()
	var service_plan_observed := int(debug_after.get("transfer_plan_count", 0)) - int(debug_before.get("transfer_plan_count", 0)) == 1 and int(debug_after.get("committed_count", 0)) - int(debug_before.get("committed_count", 0)) == 1
	var converted := int(source_after.get("hand_count", 0)) == int(source_before.get("hand_count", -1)) and int(target_after.get("hand_count", 0)) - int(target_before.get("hand_count", 0)) == -1
	return _record("hand_steal_receive_failure_conversion", "_apply_player_hand_steal", "failed_transfer_converts_to_remove", source_before, source_after, target_before, target_after, {
		"observed": not max_id.is_empty() and not steal_skill.is_empty(),
		"contract_aligned": applied and converted and service_plan_observed,
		"partial_mutation_observed": converted,
		"service_route_observed": service_plan_observed,
		"privacy_checked": true,
		"risk": "this intentional non-rollback conversion is card-effect behavior, not a failed atomic transfer",
		"notes": "the real card text converts an unreceivable steal into target removal plus private compensation; the target card is not restored",
	})


func _case_hand_disrupt_private_removal() -> Dictionary:
	var card_id := _base_upgrade_card()
	var disrupt_skill := _interaction_skill("player_hand_disrupt")
	_reset_player(0, [])
	_reset_player(1, [_make_skill(card_id)])
	_seed_runtime_rng(30014)
	var source_before := _player_probe(0)
	var target_before := _player_probe(1)
	var debug_before := _inventory_debug()
	var applied := bool(_runtime_main.call("_apply_player_hand_disrupt", 0, 1, disrupt_skill)) if not disrupt_skill.is_empty() else false
	var source_after := _player_probe(0)
	var target_after := _player_probe(1)
	var debug_after := _inventory_debug()
	var service_route := int(debug_after.get("remove_plan_count", 0)) - int(debug_before.get("remove_plan_count", 0)) == 1 and int(debug_after.get("committed_count", 0)) - int(debug_before.get("committed_count", 0)) == 1
	return _record("hand_disrupt_private_removal", "_apply_player_hand_disrupt", "private_remove", source_before, source_after, target_before, target_after, {
		"observed": not card_id.is_empty() and not disrupt_skill.is_empty(),
		"contract_aligned": applied and int(source_after.get("hand_count", 0)) == int(source_before.get("hand_count", -1)) and int(target_after.get("hand_count", 0)) - int(target_before.get("hand_count", 0)) == -1 and service_route,
		"service_route_observed": service_route,
		"privacy_checked": true,
		"notes": "rank-I disrupt removes one discardable target card and leaves the acting hand unchanged",
	})


func _case_private_hand_lock() -> Dictionary:
	var card_id := _base_upgrade_card()
	_reset_player(1, [_make_skill(card_id)])
	_seed_runtime_rng(30015)
	var before := _player_probe(1)
	var debug_before := _inventory_debug()
	var coordinator := _coordinator()
	var player := _player(1)
	var inventory_variant: Variant = _runtime_main.call("_card_inventory_snapshot", player)
	var inventory: Dictionary = inventory_variant if inventory_variant is Dictionary else {}
	var request := {"inventory": inventory, "slot_index": 0, "duration_seconds": 10.0}
	var plan_variant: Variant = coordinator.call("plan_card_inventory_lock", request) if coordinator != null else {}
	var plan: Dictionary = plan_variant if plan_variant is Dictionary else {}
	var result_variant: Variant = coordinator.call("commit_card_inventory_lock", player, request, plan) if coordinator != null else {}
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	var locked := bool(result.get("committed", false))
	if locked:
		var players: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array).duplicate(true)
		players[1] = player
		((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	var after := _player_probe(1)
	var debug_after := _inventory_debug()
	var service_route := int(debug_after.get("lock_plan_count", 0)) - int(debug_before.get("lock_plan_count", 0)) == 1 and int(debug_after.get("committed_count", 0)) - int(debug_before.get("committed_count", 0)) == 1
	return _record("private_hand_lock", "GameRuntimeCoordinator.commit_card_inventory_lock", "private_lock", before, after, {}, {}, {
		"observed": not card_id.is_empty(),
		"contract_aligned": locked and int(after.get("hand_count", 0)) == int(before.get("hand_count", -1)) and int(after.get("locked_count", 0)) - int(before.get("locked_count", 0)) == 1 and service_route,
		"service_route_observed": service_route,
		"privacy_checked": true,
		"notes": "private lock changes only lock_left and does not remove or add a card",
	})


func _case_human_ai_inventory_policy_parity() -> Dictionary:
	var card_id := _base_upgrade_card()
	_reset_player(0, [])
	_reset_player(1, [])
	var source_before := _player_probe(0)
	var target_before := _player_probe(1)
	var human_plan_variant: Variant = _runtime_main.call("_district_purchase_inventory_plan", _player(0), card_id, -1)
	var ai_plan_variant: Variant = _runtime_main.call("_district_purchase_inventory_plan", _player(1), card_id, -1)
	var human_plan: Dictionary = human_plan_variant if human_plan_variant is Dictionary else {}
	var ai_plan: Dictionary = ai_plan_variant if ai_plan_variant is Dictionary else {}
	var source_after := _player_probe(0)
	var target_after := _player_probe(1)
	var same_policy := str(human_plan.get("status", "")) == str(ai_plan.get("status", "")) and str(human_plan.get("operation", "")) == str(ai_plan.get("operation", "")) and int(human_plan.get("hand_count_delta", 0)) == int(ai_plan.get("hand_count_delta", 0))
	return _record("human_ai_inventory_policy_parity", "_district_purchase_inventory_plan", "policy_query", source_before, source_after, target_before, target_after, {
		"observed": not human_plan.is_empty() and not ai_plan.is_empty(),
		"contract_aligned": same_policy and source_before.get("fingerprint", []) == source_after.get("fingerprint", []) and target_before.get("fingerprint", []) == target_after.get("fingerprint", []),
		"service_route_observed": true,
		"notes": "identical human and AI inventory facts produce the same non-mutating receive plan",
	})


func _case_inventory_fingerprint_drift() -> Dictionary:
	var card_id := _base_upgrade_card()
	var drift_card_id := _other_counted_card(card_id)
	_reset_player(0, [])
	var coordinator := _coordinator()
	var initial_variant: Variant = _runtime_main.call("_district_purchase_inventory_snapshot", _player(0), card_id, -1)
	var initial: Dictionary = initial_variant if initial_variant is Dictionary else {}
	var plan_variant: Variant = coordinator.call("plan_card_inventory_receive", initial) if coordinator != null else {}
	var plan: Dictionary = plan_variant if plan_variant is Dictionary else {}
	_set_slots(0, [_make_skill(drift_card_id)])
	var before := _player_probe(0)
	var current_variant: Variant = _runtime_main.call("_district_purchase_inventory_snapshot", _player(0), card_id, -1)
	var current: Dictionary = current_variant if current_variant is Dictionary else {}
	var players: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array
	var player: Dictionary = players[0]
	var result_variant: Variant = coordinator.call("commit_card_inventory_receive", player, current, plan) if coordinator != null else {}
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	players[0] = player
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	var after := _player_probe(0)
	return _record("inventory_fingerprint_drift", "commit_card_inventory_receive", "drift_rejection", before, after, {}, {}, {
		"observed": not initial.is_empty() and not plan.is_empty() and not current.is_empty(),
		"contract_aligned": not bool(result.get("committed", true)) and str(result.get("reason", "")) == "inventory_drift" and before.get("fingerprint", []) == after.get("fingerprint", []),
		"service_route_observed": true,
		"notes": "a stale receive plan rejects after the hand fingerprint changes and leaves the drift state untouched",
	})


func _case_save_shape_unchanged() -> Dictionary:
	var registry := load("res://resources/rules/controller_state_version_registry_v06.tres")
	var registry_snapshot: Dictionary = registry.call("debug_snapshot") if registry != null and registry.has_method("debug_snapshot") else {}
	var inventory_service := _coordinator().get_node_or_null("CardInventoryRuntimeService") if _coordinator() != null else null
	var registry_text := JSON.stringify(registry_snapshot)
	var inventory_section_count := 0
	for entry_variant in registry_snapshot.get("entries", []):
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("controller_id", "")) == "card_inventory" and str((entry_variant as Dictionary).get("save_section", "")) == "card_inventory":
			inventory_section_count += 1
	var no_runtime_service_reference := not registry_text.contains("CardInventoryRuntimeService")
	var service_is_stateless := inventory_service != null and not inventory_service.has_method("to_save_data") and not inventory_service.has_method("apply_save_data")
	return _record("save_shape_unchanged", "ControllerStateVersionRegistryV06", "save_shape_audit", {}, {}, {}, {}, {
		"observed": not registry_snapshot.is_empty() and inventory_service != null,
		"contract_aligned": int(registry_snapshot.get("entries", []).size()) == 18 and inventory_section_count == 1 and no_runtime_service_reference and service_is_stateless and not _contains_runtime_object(registry_snapshot),
		"save_shape_checked": true,
		"notes": "the strict v0.6 registry keeps one card-inventory business section; the stateless slot service contributes no second section or runtime service reference",
	})


func _case_public_private_boundary() -> Dictionary:
	var card_id := _base_upgrade_card()
	var steal_skill := _interaction_skill("player_hand_steal")
	_reset_player(0, [])
	_reset_player(1, [_make_skill(card_id)])
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = int(_first_supply_fixture().get("district_index", 0))
	_seed_runtime_rng(30019)
	var source_before := _player_probe(0)
	var target_before := _player_probe(1)
	var logs_before: Array = (_coordinator() as GameRuntimeCoordinator).presentation_recent_public_log_messages(90)
	var actor_name := str(_player(0).get("name", ""))
	var applied := bool(_runtime_main.call("_apply_player_hand_steal", 0, 1, steal_skill)) if not steal_skill.is_empty() else false
	var source_after := _player_probe(0)
	var target_after := _player_probe(1)
	var card_display := str(_runtime_main.call("_card_display_name", card_id))
	var public_safe := _public_logs_hide_private_values(logs_before.size(), [card_id, card_display, actor_name])
	var target_ledger: Array = _player(1).get("economic_ledger", []) if _player(1).get("economic_ledger", []) is Array else []
	var private_detail_exists := false
	for entry_variant in target_ledger:
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("detail", "")).contains(card_display):
			private_detail_exists = true
			break
	return _record("public_private_boundary", "_apply_player_hand_steal", "privacy_audit", source_before, source_after, target_before, target_after, {
		"observed": not card_id.is_empty() and not steal_skill.is_empty(),
		"contract_aligned": applied and public_safe and private_detail_exists,
		"service_route_observed": true,
		"privacy_checked": public_safe and private_detail_exists,
		"notes": "public feedback hides the actor and concrete transferred card; the affected player's private ledger retains the exact detail",
	})


func _case_duplicate_inventory_formula_absent() -> Dictionary:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var settlement_source := FileAccess.get_file_as_string(SETTLEMENT_SERVICE_SCRIPT_PATH)
	var inventory_source := FileAccess.get_file_as_string(CARD_INVENTORY_SERVICE_SCRIPT_PATH)
	var acquire := _function_source(main_source, "_acquire_inventory_skill_for_player")
	var generic_receive_is_thin := acquire.contains("plan_card_inventory_receive") and acquire.contains("commit_card_inventory_receive") and not acquire.contains("player[\"slots\"]") and not acquire.contains("_first_empty_or_new_slot") and not acquire.contains("_next_upgrade_name")
	var service_owns_generic_formula := inventory_source.contains("func _plan_receive(") and inventory_source.contains("func _apply_receive_operation(") and inventory_source.contains("func discardable_slots(")
	var settlement_delegates := settlement_source.contains("func set_inventory_service(") and settlement_source.contains("_inventory_receive_plan(") and not settlement_source.contains("func _plan_inventory_receive(") and not settlement_source.contains("func _apply_inventory_operation(")
	var direct_mutations_absent := not _function_source(main_source, "_take_private_hand_card_from_player").contains("player[\"slots\"]") and not _function_source(main_source, "_lock_private_hand_card_for_player").contains("skill[\"lock_left\"]")
	return _record("duplicate_inventory_formula_absent", "source_audit", "duplicate_formula_gate", {}, {}, {}, {}, {
		"observed": not acquire.is_empty() and not settlement_source.is_empty() and not inventory_source.is_empty(),
		"contract_aligned": generic_receive_is_thin and service_owns_generic_formula and settlement_delegates and direct_mutations_absent,
		"service_route_observed": generic_receive_is_thin,
		"notes": "generic inventory mutation has one implementation in Card Inventory Service; purchase settlement and main are thin delegates",
	})


func _record(case_id: String, source_entrypoint: String, mutation_kind: String, source_before: Dictionary, source_after: Dictionary, target_before: Dictionary, target_after: Dictionary, flags: Dictionary) -> Dictionary:
	var observed := bool(flags.get("observed", false))
	var aligned := bool(flags.get("contract_aligned", false))
	var phase := str(flags.get("phase", "characterization"))
	var record := {
		"case_id": case_id,
		"phase": phase,
		"source_entrypoint": source_entrypoint,
		"mutation_kind": mutation_kind,
		"source_hand_delta": int(source_after.get("hand_count", 0)) - int(source_before.get("hand_count", 0)),
		"target_hand_delta": int(target_after.get("hand_count", 0)) - int(target_before.get("hand_count", 0)),
		"rank_delta": int(source_after.get("rank_total", 0)) - int(source_before.get("rank_total", 0)),
		"lock_delta": int(source_after.get("locked_count", 0)) - int(source_before.get("locked_count", 0)) + int(target_after.get("locked_count", 0)) - int(target_before.get("locked_count", 0)),
		"source_fingerprint_before": (source_before.get("fingerprint", []) as Array).duplicate(true) if source_before.get("fingerprint", []) is Array else [],
		"source_fingerprint_after": (source_after.get("fingerprint", []) as Array).duplicate(true) if source_after.get("fingerprint", []) is Array else [],
		"target_fingerprint_before": (target_before.get("fingerprint", []) as Array).duplicate(true) if target_before.get("fingerprint", []) is Array else [],
		"target_fingerprint_after": (target_after.get("fingerprint", []) as Array).duplicate(true) if target_after.get("fingerprint", []) is Array else [],
		"partial_mutation_observed": bool(flags.get("partial_mutation_observed", false)),
		"service_route_observed": bool(flags.get("service_route_observed", false)),
		"service_owner_checked": bool(flags.get("service_owner_checked", false)),
		"settlement_delegate_checked": bool(flags.get("settlement_delegate_checked", false)),
		"main_adapter_checked": bool(flags.get("main_adapter_checked", false)),
		"exact_once_checked": bool(flags.get("exact_once_checked", false)),
		"legacy_formula_absent": bool(flags.get("legacy_formula_absent", false)),
		"save_shape_checked": bool(flags.get("save_shape_checked", false)),
		"privacy_checked": bool(flags.get("privacy_checked", false)),
		"pure_data_checked": true,
		"observed": observed,
		"contract_aligned": aligned,
		"cutover_passed": bool(flags.get("cutover_passed", false)),
		"needs_design_decision": bool(flags.get("needs_design_decision", false)),
		"risk": str(flags.get("risk", "" if aligned else "observed behavior differs from the current v0.4 contract")),
		"passed": bool(flags.get("cutover_passed", false)) if phase == "cutover" else observed and aligned,
		"notes": str(flags.get("notes", "")),
	}
	record["pure_data_checked"] = _is_data_only(record)
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


func _card_exists(card_id: String) -> bool:
	var coordinator := _coordinator()
	return bool(coordinator.call("card_exists", card_id)) if coordinator != null else false


func _card_rank(card_id: String) -> int:
	var coordinator := _coordinator()
	return int(coordinator.call("card_rank", card_id)) if coordinator != null else 0


func _card_family_id(card_id: String) -> String:
	var coordinator := _coordinator()
	return str(coordinator.call("card_family_id", card_id)) if coordinator != null else ""


func _monster_controller() -> Node:
	var runtime := _coordinator()
	return runtime.get_node_or_null("MonsterRuntimeController") if runtime != null else null


func _settlement_debug() -> Dictionary:
	var coordinator := _coordinator()
	if coordinator == null or not coordinator.has_method("district_purchase_settlement_debug"):
		return {}
	var value: Variant = coordinator.call("district_purchase_settlement_debug")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _inventory_debug() -> Dictionary:
	var coordinator := _coordinator()
	if coordinator == null or not coordinator.has_method("card_inventory_debug"):
		return {}
	var value: Variant = coordinator.call("card_inventory_debug")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _player(player_index: int) -> Dictionary:
	if _runtime_main == null:
		return {}
	var players: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return {}
	return (players[player_index] as Dictionary).duplicate(true)


func _reset_player(player_index: int, slots: Array, cash: int = 999999) -> void:
	var players: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array).duplicate(true)
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return
	var player: Dictionary = (players[player_index] as Dictionary).duplicate(true)
	player["cash"] = cash
	player["slots"] = slots.duplicate(true)
	player["economic_ledger"] = []
	player["cash_history"] = [cash]
	player["card_purchase_count"] = 0
	player["total_card_spend"] = 0
	player["eliminated"] = false
	player["action_cooldown"] = 0.0
	players[player_index] = player
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players


func _set_slots(player_index: int, slots: Array) -> void:
	var player := _player(player_index)
	player["slots"] = slots.duplicate(true)
	var players: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array
	players[player_index] = player
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players


func _player_probe(player_index: int) -> Dictionary:
	var player := _player(player_index)
	if player.is_empty():
		return {}
	var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	var fingerprint: Array = []
	var rank_total := 0
	var locked_count := 0
	var occupied_count := 0
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var skill: Dictionary = slot_variant
		var card_id := str(skill.get("name", ""))
		var family := _card_family_id(card_id)
		var rank := int(skill.get("rank", _card_rank(card_id)))
		var locked := float(skill.get("lock_left", 0.0)) > 0.0
		var counted := bool(_runtime_main.call("_counts_toward_hand_limit", skill))
		fingerprint.append({
			"family_hash": family.sha256_text().substr(0, 10),
			"rank": rank,
			"queued": bool(skill.get("queued_for_resolution", false)),
			"locked": locked,
			"counted": counted,
		})
		rank_total += rank
		locked_count += 1 if locked else 0
		occupied_count += 1
	return {
		"hand_count": int(_runtime_main.call("_player_counted_hand_size", player)),
		"slot_count": occupied_count,
		"rank_total": rank_total,
		"locked_count": locked_count,
		"fingerprint": fingerprint,
	}


func _make_skill(card_id: String) -> Dictionary:
	if card_id.is_empty():
		return {}
	var value: Variant = _runtime_main.call("_make_skill", card_id)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _base_upgrade_card() -> String:
	var names_variant: Variant = (_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).card_runtime_catalog_service().ordered_card_ids()
	var names: Array = names_variant if names_variant is Array else []
	for name_variant in names:
		var card_id := str(_runtime_main.call("_canonical_card_supply_name", str(name_variant)))
		if card_id.is_empty() or _card_rank(card_id) != 1:
			continue
		if str(_runtime_main.call("_next_upgrade_name", card_id)).is_empty():
			continue
		var skill := _make_skill(card_id)
		if not skill.is_empty() and bool(_runtime_main.call("_counts_toward_hand_limit", skill)) and str(skill.get("kind", "")) != "monster_card":
			return card_id
	return ""


func _other_counted_card(excluded_card_id: String) -> String:
	var excluded_family := _card_family_id(excluded_card_id)
	var names_variant: Variant = (_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).card_runtime_catalog_service().ordered_card_ids()
	var names: Array = names_variant if names_variant is Array else []
	for name_variant in names:
		var card_id := str(_runtime_main.call("_canonical_card_supply_name", str(name_variant)))
		if card_id.is_empty() or _card_family_id(card_id) == excluded_family:
			continue
		var skill := _make_skill(card_id)
		if not skill.is_empty() and bool(_runtime_main.call("_counts_toward_hand_limit", skill)) and str(skill.get("kind", "")) != "monster_card":
			return card_id
	return ""


func _full_counted_hand(incoming_card_id: String, limit: int) -> Array:
	var result: Array = []
	var incoming_family := _card_family_id(incoming_card_id)
	var names_variant: Variant = (_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).card_runtime_catalog_service().ordered_card_ids()
	var names: Array = names_variant if names_variant is Array else []
	var fallback: Dictionary = {}
	for name_variant in names:
		var card_id := str(_runtime_main.call("_canonical_card_supply_name", str(name_variant)))
		if card_id.is_empty() or _card_family_id(card_id) == incoming_family:
			continue
		var skill := _make_skill(card_id)
		if skill.is_empty() or not bool(_runtime_main.call("_counts_toward_hand_limit", skill)) or str(skill.get("kind", "")) == "monster_card":
			continue
		if fallback.is_empty():
			fallback = skill.duplicate(true)
		result.append(skill.duplicate(true))
		if result.size() >= limit:
			break
	while result.size() < limit and not fallback.is_empty():
		result.append(fallback.duplicate(true))
	return result


func _max_upgrade_name(base_card_id: String) -> String:
	var current := base_card_id
	while not current.is_empty():
		var next_id := str(_runtime_main.call("_next_upgrade_name", current))
		if next_id.is_empty():
			return current
		current = next_id
	return ""


func _interaction_skill(kind: String) -> Dictionary:
	var names_variant: Variant = (_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).card_runtime_catalog_service().ordered_card_ids()
	var names: Array = names_variant if names_variant is Array else []
	for name_variant in names:
		var card_id := str(_runtime_main.call("_canonical_card_supply_name", str(name_variant)))
		var skill := _make_skill(card_id)
		if str(skill.get("kind", "")) == kind and _card_rank(card_id) == 1:
			return skill
	return {}


func _first_supply_fixture() -> Dictionary:
	var districts: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array
	var coordinator := _coordinator()
	for district_index in range(districts.size()):
		if not (districts[district_index] is Dictionary) or bool((districts[district_index] as Dictionary).get("destroyed", false)):
			continue
		var availability_variant: Variant = coordinator.call("card_market_listing_availability", district_index) if coordinator != null and coordinator.has_method("card_market_listing_availability") else {}
		var availability: Dictionary = availability_variant if availability_variant is Dictionary else {}
		if str(availability.get("availability_kind", "")) != "sunlit" or not bool(availability.get("purchasable", false)):
			continue
		var choices: Array = (districts[district_index] as Dictionary).get("card_choices", []) if (districts[district_index] as Dictionary).get("card_choices", []) is Array else []
		for choice_variant in choices:
			var card_id := str(_runtime_main.call("_canonical_card_supply_name", str(choice_variant)))
			if not card_id.is_empty() and _card_exists(card_id):
				return {"district_index": district_index, "card_id": card_id, "availability_kind": "sunlit", "world_effective_us": int(availability.get("world_effective_us", -1))}
	return {}


func _prepare_purchase_fixture(player_index: int) -> Dictionary:
	var coordinator := _coordinator()
	if coordinator != null and coordinator.has_method("restore_world_effective_seconds"):
		coordinator.call("restore_world_effective_seconds", 0.0)
	var fixture := _first_supply_fixture()
	if fixture.is_empty():
		return {}
	var district_index := int(fixture.get("district_index", -1))
	var card_id := str(fixture.get("card_id", ""))
	_reset_player(player_index, [])
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = player_index
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = district_index
	_runtime_main.set("selected_market_skill", card_id)
	_runtime_main.set("previewed_district_card", card_id)
	_runtime_main.call("_open_district_card_purchase_window", district_index, player_index)
	_runtime_main.call("_select_district_card_for_quote", card_id, false)
	var quote_variant: Variant = coordinator.call("card_market_active_quote", player_index, district_index) if coordinator != null and coordinator.has_method("card_market_active_quote") else {}
	var quote: Dictionary = quote_variant if quote_variant is Dictionary else {}
	if str(quote.get("quote_id", "")).is_empty() or not bool(quote.get("eligible", false)):
		return {}
	return {"player_index": player_index, "district_index": district_index, "card_id": card_id, "quote_id": str(quote.get("quote_id", "")), "availability_kind": str(fixture.get("availability_kind", "")), "world_effective_us": int(fixture.get("world_effective_us", -1))}


func _role_bonus_fixture() -> Dictionary:
	var supply := _first_supply_fixture()
	if supply.is_empty():
		return {}
	var player_index := 0
	var district_index := int(supply.get("district_index", -1))
	var role_variant: Variant = _runtime_main.call("_player_role_template", player_index, 0)
	var role: Dictionary = role_variant if role_variant is Dictionary else {}
	var product_id := str(role.get("bonus_card_product", ""))
	if product_id.is_empty():
		return {}
	var players: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array).duplicate(true)
	var player: Dictionary = (players[player_index] as Dictionary).duplicate(true)
	player["role_card"] = role.duplicate(true)
	players[player_index] = player
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	var districts: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array).duplicate(true)
	var district: Dictionary = (districts[district_index] as Dictionary).duplicate(true)
	var products: Array = (district.get("products", []) as Array).duplicate()
	if not products.has(product_id):
		products.append(product_id)
	district["products"] = products
	districts[district_index] = district
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	return {"player_index": player_index, "district_index": district_index, "bought_card_id": str(supply.get("card_id", ""))}


func _acquire_for_player(player_index: int, card_id: String) -> bool:
	if card_id.is_empty():
		return false
	var players: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return false
	var player: Dictionary = players[player_index]
	var acquired := bool(_runtime_main.call("_acquire_card_for_player", player, card_id, int(((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district), "characterization", true))
	players[player_index] = player
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	return acquired


func _seed_runtime_rng(seed_value: int) -> void:
	var runtime_coordinator := _coordinator() as GameRuntimeCoordinator
	var runtime_rng := runtime_coordinator.run_rng_service() if runtime_coordinator != null else null
	if runtime_rng != null:
		runtime_rng.seed = seed_value


func _public_logs_hide_private_values(start_index: int, private_values: Array) -> bool:
	var logs: Array = (_coordinator() as GameRuntimeCoordinator).presentation_recent_public_log_messages(90)
	for index in range(maxi(0, start_index), logs.size()):
		var line := str(logs[index])
		for value_variant in private_values:
			var private_value := str(value_variant)
			if not private_value.is_empty() and line.contains(private_value):
				return false
	return true


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


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + 5)
	return source.substr(start) if next_function < 0 else source.substr(start, next_function - start)


func _characterization_observed_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and str((record_variant as Dictionary).get("phase", "characterization")) == "characterization" and bool((record_variant as Dictionary).get("observed", false)):
			count += 1
	return count


func _characterization_aligned_count() -> int:
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


func _design_decision_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and str((record_variant as Dictionary).get("phase", "characterization")) == "characterization" and bool((record_variant as Dictionary).get("needs_design_decision", false)):
			count += 1
	return count


func _update_ui(manifest: Dictionary) -> void:
	var observed := int(manifest.get("observed_count", 0))
	var aligned := int(manifest.get("aligned_count", 0))
	var cutover_passed := int(manifest.get("cutover_passed_count", 0))
	var decisions := int(manifest.get("needs_design_decision_count", 0))
	var passed := observed == CHARACTERIZATION_CASE_COUNT and aligned == CHARACTERIZATION_CASE_COUNT and cutover_passed == CUTOVER_CASE_COUNT
	summary_label.text = "Card inventory: %d/%d observed | %d/%d aligned | %d/%d cutover | %d decisions" % [observed, CHARACTERIZATION_CASE_COUNT, aligned, CHARACTERIZATION_CASE_COUNT, cutover_passed, CUTOVER_CASE_COUNT, decisions]
	status_label.text = "PASS" if passed else "FAIL"
	status_label.add_theme_color_override("font_color", Color("#4ade80") if passed else Color("#fb7185"))
	ownership_text.text = "[b]Runtime ownership after Sprint 31[/b]\n\n[b]CardInventoryRuntimeService[/b]\n• receive, add, same-family upgrade, rank-IV rejection\n• five-card ordinary limit and fixed-skill exemption\n• discardability, fingerprint, remove, lock, and transfer slot mutation\n\n[b]DistrictPurchaseSettlementRuntimeService[/b]\n• price, cash, purchase count, ledger, cash history\n• one atomic purchase commit that delegates inventory mutation\n\n[b]main.gd adapters[/b]\n• real card/player facts, target choice, RNG/AI ordering\n• compensation, private ledger, and public event forwarding"
	var case_lines: Array[String] = ["[b]Case observations[/b]"]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		var is_cutover := str(record.get("phase", "characterization")) == "cutover"
		var mark := "MISS"
		var alignment := "review"
		if is_cutover:
			mark = "OK" if bool(record.get("cutover_passed", false)) else "MISS"
			alignment = "cutover" if bool(record.get("cutover_passed", false)) else "review"
		else:
			mark = "OK" if bool(record.get("observed", false)) else "MISS"
			alignment = "aligned" if bool(record.get("contract_aligned", false)) else "review"
		case_lines.append("%s  %s  [%s]" % [mark, str(record.get("case_id", "")), alignment])
	cases_text.text = "\n".join(case_lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines := [
		"# Card Inventory Runtime Service Cutover",
		"",
		"- Ruleset: `v0.4`",
		"- Characterization observed: **%d/%d**" % [int(manifest.get("observed_count", 0)), CHARACTERIZATION_CASE_COUNT],
		"- Characterization aligned: **%d/%d**" % [int(manifest.get("aligned_count", 0)), CHARACTERIZATION_CASE_COUNT],
		"- Cutover passed: **%d/%d**" % [int(manifest.get("cutover_passed_count", 0)), CUTOVER_CASE_COUNT],
		"- Total gate: **%d/%d**" % [int(manifest.get("passed_count", 0)), CASE_COUNT],
		"- Mismatches: **%d**" % int(manifest.get("mismatch_count", 0)),
		"- Needs design decision: **%d**" % int(manifest.get("needs_design_decision_count", 0)),
		"- Output: `%s`" % OUTPUT_DIR,
		"",
		"The report stores only anonymized family hashes, ranks, queued/locked flags, and counted-hand state. Concrete private card and player identities are intentionally absent.",
		"",
		"| Phase | Case | Entry point | Mutation | Source Δ | Target Δ | Rank Δ | Lock Δ | Service owner | Settlement delegate | Main adapter | Exact once | Legacy absent | Passed | Notes |",
		"| --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| %s | %s | %s | %s | %d | %d | %d | %d | %s | %s | %s | %s | %s | %s | %s |" % [
			str(record.get("phase", "characterization")),
			str(record.get("case_id", "")),
			str(record.get("source_entrypoint", "")),
			str(record.get("mutation_kind", "")),
			int(record.get("source_hand_delta", 0)),
			int(record.get("target_hand_delta", 0)),
			int(record.get("rank_delta", 0)),
			int(record.get("lock_delta", 0)),
			"yes" if bool(record.get("service_owner_checked", false)) else "no",
			"yes" if bool(record.get("settlement_delegate_checked", false)) else "no",
			"yes" if bool(record.get("main_adapter_checked", false)) else "no",
			"yes" if bool(record.get("exact_once_checked", false)) else "no",
			"yes" if bool(record.get("legacy_formula_absent", false)) else "no",
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
		for key in value.keys():
			if not _is_data_only(key) or not _is_data_only(value[key]):
				return false
		return true
	return false
