extends SceneTree

const CONTRACT_PATH := "res://docs/rules/v07_uninterrupted_card_batch_contextual_table_ui_contract.json"
const CONTRACT_MD_PATH := "res://docs/rules/v07_uninterrupted_card_batch_contextual_table_ui_contract.md"
const EXPECTED_STATE_MACHINE := [
	"CARD_WINDOW_CLOSED",
	"CARD_WINDOW_OPEN",
	"CARD_WINDOW_LOCKING",
	"RESOLUTION_ORDER_BUILD",
	"RESOLUTION_ORDER_REVEAL",
	"CARD_RESOLUTION_ACTIVE",
	"CARD_EFFECT_COMMIT",
	"CARD_AFTERMATH",
	"BATCH_AFTERMATH",
	"BATCH_COMPLETE",
	"CARD_WINDOW_OPEN",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	_expect(parsed is Dictionary, "V0.7 uninterrupted-card-batch contract parses")
	if not (parsed is Dictionary):
		_finish()
		return
	var contract := parsed as Dictionary
	_test_authority(contract)
	_test_counter_retirement(contract)
	_test_state_machine(contract)
	_test_typed_contracts(contract)
	_test_resolution_contract(contract)
	_test_time_and_window_gate(contract)
	_test_three_pools_ai_and_ui(contract)
	_test_persistence_privacy_rng_and_architecture(contract)
	_test_phase_truth(contract)
	_test_human_readable_contract()
	_finish()


func _test_authority(contract: Dictionary) -> void:
	var authority := contract.get("authority", {}) as Dictionary
	_expect(str(authority.get("current_production_runtime_ruleset", "")) == "V0.6", "V0.6 remains the current production ruleset")
	_expect(str(authority.get("target_development_constitution", "")) == "V0.7", "V0.7 is the target development constitution")
	_expect(bool(authority.get("v07_highest_development_authority", false)), "V0.7 remains the highest future development authority")
	_expect(not bool(authority.get("full_v0_7_runtime_cutover", true)), "reference Phases A-D do not claim a V0.7 runtime cutover")
	_expect(not bool(authority.get("reference_layers_are_production_authority", true)), "reference layers are not production authority")
	_expect(bool(authority.get("v06_counter_runtime_preserved_until_atomic_cutover", false)), "V0.6 Counter remains preserved until atomic cutover")
	_expect(not bool(authority.get("new_v07_path_may_call_v06_counter_runtime", true)), "new V0.7 semantics cannot call the V0.6 Counter runtime")


func _test_counter_retirement(contract: Dictionary) -> void:
	var retirement := contract.get("counter_retirement", {}) as Dictionary
	_expect(bool(retirement.get("v07_interactive_counter_cards_retired", false)), "V0.7 interactive Counter cards are retired")
	_expect(bool(retirement.get("v07_counter_window_retired", false)), "V0.7 Counter Window is retired")
	_expect(bool(retirement.get("v07_counter_stack_retired", false)), "V0.7 Counter Stack is retired")
	_expect(not bool(retirement.get("resolution_accepts_new_card_submission", true)), "resolution accepts no new card submission")
	_expect(not bool(retirement.get("resolution_accepts_new_target_selection", true)), "resolution accepts no target reselection")
	_expect(not bool(retirement.get("resolution_accepts_player_gameplay_input", true)), "resolution accepts no player gameplay input")
	_expect(not bool(retirement.get("resolution_accepts_ai_gameplay_input", true)), "resolution accepts no AI gameplay input")
	_expect(int(retirement.get("mid_resolution_card_submission_count", -1)) == 0, "mid-resolution card submission count is zero")
	_expect(int(retirement.get("counter_window_count", -1)) == 0 and int(retirement.get("counter_stack_depth", -1)) == 0, "V0.7 has zero Counter windows and stack depth")


func _test_state_machine(contract: Dictionary) -> void:
	var states := contract.get("state_machine", []) as Array
	_expect(states == EXPECTED_STATE_MACHINE, "state machine order is frozen and uninterrupted")
	for state_variant in states:
		var state := str(state_variant)
		_expect(not state.contains("COUNTER") and not state.contains("RESPONSE"), "state is free of Counter/response semantics: %s" % state)
	var invariants := contract.get("state_machine_invariants", {}) as Dictionary
	_expect(int(invariants.get("card_submission_window_seconds", 0)) == 30, "card submission window is exactly 30 seconds")
	_expect(bool(invariants.get("card_window_is_one_shot", false)) and not bool(invariants.get("periodic_card_window_timer", true)), "card window is one-shot rather than periodic")
	_expect(bool(invariants.get("order_build_requires_window_lock", false)), "order build requires a locked window")
	_expect(bool(invariants.get("resolution_is_strictly_sequential", false)), "resolution is strictly sequential")
	_expect(not bool(invariants.get("resolution_requires_player_response", true)), "resolution requires no player response")
	_expect(bool(invariants.get("next_window_requires_batch_complete", false)), "next window requires batch completion")
	_expect(str(invariants.get("next_window_authoritative_receipt_kind", "")) == "CARD_BATCH_COMPLETE_RECEIPT", "one typed authoritative receipt gates the next window")
	_expect(bool(invariants.get("no_world_tick_between_resolving_cards", false)), "no world tick occurs between resolving cards")


func _test_typed_contracts(contract: Dictionary) -> void:
	var typed := contract.get("typed_contracts", {}) as Dictionary
	for type_name in ["CardBatchStateV1", "CardBatchSubmissionV1", "PreboundTargetSpecV1", "CardResolutionStateV1", "DefenseStatusV1"]:
		_expect(typed.get(type_name, []) is Array and not (typed.get(type_name, []) as Array).is_empty(), "%s has a frozen field allowlist" % type_name)
	var serialized := JSON.stringify(typed)
	for forbidden in typed.get("forbidden_reference_types", []) as Array:
		_expect(not serialized.contains('"%s"' % str(forbidden) + ":"), "typed fields contain no %s reference slot" % str(forbidden))
	var submission_lock := contract.get("submission_lock", {}) as Dictionary
	_expect(bool(submission_lock.get("all_strategic_choices_occur_during_card_window_open", false)), "all strategic choices occur before lock")
	for key in ["submission_mutable_after_lock", "target_mutable_after_lock", "mode_mutable_after_lock", "quantity_mutable_after_lock"]:
		_expect(not bool(submission_lock.get(key, true)), "%s is false" % key)


func _test_resolution_contract(contract: Dictionary) -> void:
	var invalidation := contract.get("target_invalidation", {}) as Dictionary
	_expect(str(invalidation.get("default_policy", "")) == "FIZZLE_NO_EFFECT", "invalid target default is FIZZLE_NO_EFFECT")
	_expect(invalidation.get("allowed_policies", []) == ["FIZZLE_NO_EFFECT", "COMMIT_LEGAL_REMAINDER", "REFUND_BY_AUTHORED_RULE", "DETERMINISTIC_FALLBACK"], "exactly four target invalidation policies are allowed")
	_expect(bool(invalidation.get("deterministic_fallback_requires_authored_rule", false)) and bool(invalidation.get("deterministic_fallback_uses_stable_ids", false)), "deterministic fallback is authored and stable-ID driven")
	_expect(not bool(invalidation.get("target_reselection_input_allowed", true)) and not bool(invalidation.get("ai_replanning_during_resolution_allowed", true)), "target reselection and AI replanning are forbidden")
	var defense := contract.get("defense_application", {}) as Dictionary
	_expect(bool(defense.get("defense_effect_is_existing_state", false)) and bool(defense.get("defense_effect_is_not_mid_resolution_card", false)), "defense is existing state, not a mid-resolution card")
	_expect(bool(defense.get("defense_application_requires_no_input", false)), "defense application needs no input")
	_expect(bool(defense.get("defense_application_inserts_no_queue_entry", false)), "defense application inserts no queue entry")
	_expect(not bool(defense.get("defense_application_uses_rng", true)) and not bool(defense.get("defense_application_is_recursive", true)), "defense is RNG-free and non-recursive")
	_expect(defense.get("multiple_defense_order", []) == ["active_from_revision", "source_card_instance_id", "defense_status_id"], "multiple defenses use one stable application order")


func _test_time_and_window_gate(contract: Dictionary) -> void:
	var domains := contract.get("time_domains", {}) as Dictionary
	var window := domains.get("CARD_WINDOW_OPEN", {}) as Dictionary
	var resolution := domains.get("RESOLUTION_ORDER_BUILD_THROUGH_BATCH_AFTERMATH", {}) as Dictionary
	_expect(bool(window.get("world_effective_time_running", false)) and bool(window.get("card_window_timer_running", false)), "world and card timer run during the open window")
	_expect(not bool(resolution.get("world_effective_time_running", true)) and not bool(resolution.get("card_window_timer_running", true)), "world and card timer pause throughout resolution")
	_expect(bool(resolution.get("presentation_time_running", false)) and bool(resolution.get("card_state_commits_sequentially", false)), "presentation continues while card state commits sequentially")
	var gate := contract.get("next_window_gate", {}) as Dictionary
	_expect((gate.get("required_facts", []) as Array).size() == 6, "next-window gate has six explicit authority facts")
	_expect(bool(gate.get("receipt_exact_once", false)), "batch-complete receipt is exact-once")
	_expect(not bool(gate.get("presentation_may_open_window", true)) and not bool(gate.get("timer_may_open_window", true)), "presentation and timer cannot open the next window")


func _test_three_pools_ai_and_ui(contract: Dictionary) -> void:
	var pools := contract.get("card_pools", {}) as Dictionary
	_expect(int(pools.get("normal_hand_limit", 0)) == 5 and int(pools.get("commodity_inventory_limit", 0)) == 5, "normal and commodity pools each have limit five")
	_expect(int(pools.get("bound_action_capacity_cost", -1)) == 0 and bool(pools.get("three_pools_independent", false)), "bound actions cost zero capacity and all three pools are independent")
	_expect(int(pools.get("bound_counter_action_count", -1)) == 0, "bound Counter action count is zero")
	var ai := contract.get("ai_semantics", {}) as Dictionary
	_expect(str(ai.get("planning_phase", "")) == "CARD_WINDOW_OPEN", "AI plans only in the card window")
	_expect(int(ai.get("mid_resolution_action_intent_count", -1)) == 0, "AI emits zero mid-resolution action intents")
	_expect(not bool(ai.get("reads_full_authority_state", true)) and bool(ai.get("uses_owner_bound_allowlisted_observation", false)), "AI uses an owner-bound allowlisted observation")
	_expect(bool(ai.get("uses_same_submission_contract_as_human", false)), "AI and human use the same submission contract")
	var player := contract.get("player_semantics", {}) as Dictionary
	_expect(bool(player.get("single_side_roster", false)), "player roster is on one side")
	_expect(int(player.get("roster_columns_3_to_4", 0)) == 1 and int(player.get("roster_columns_5_to_8", 0)) == 2, "roster is one column for 3-4 and two for 5-8")
	_expect(bool(player.get("right_fixed_region_panel_retired", false)) and bool(player.get("region_supply_is_contextual_popup", false)), "fixed region panel is replaced by a contextual popup")
	_expect(player.get("region_popup_close_triggers", []) == ["close_button", "ui_cancel", "blank_map_click", "same_region_click", "card_resolution", "target_selection", "menu_or_codex"], "all contextual popup close triggers are frozen")
	_expect(bool(player.get("resolution_overlay_is_transient", false)) and int(player.get("counter_ui_element_count", -1)) == 0, "resolution overlay is transient and contains zero Counter elements")


func _test_persistence_privacy_rng_and_architecture(contract: Dictionary) -> void:
	var persistence := contract.get("persistence_and_replay", {}) as Dictionary
	_expect(bool(persistence.get("reference_save_codec_ready", false)), "reference Save codec is executable")
	_expect(bool(persistence.get("reference_replay_identity_ready", false)), "reference replay identity is deterministic")
	_expect(bool(persistence.get("reference_private_defense_receipt_roundtrip_ready", false)), "private defense receipt roundtrips in the reference codec")
	_expect(not bool(persistence.get("production_save_migration_ready", true)), "production Save migration remains false")
	_expect(bool(persistence.get("future_save_includes_batch_target_defense_and_three_pools", false)), "future Save preserves batch, target, defense, and three pools")
	for key in ["future_save_includes_counter_window", "future_save_includes_counter_stack", "future_save_includes_pending_counter_input"]:
		_expect(not bool(persistence.get(key, true)), "%s is false" % key)
	_expect(not bool(persistence.get("current_production_save_schema_changed_in_phase_a", true)), "Phase A changes no production Save schema")
	var privacy := contract.get("privacy", {}) as Dictionary
	for key in privacy.keys():
		_expect(not bool(privacy.get(key, true)), "private field remains non-public: %s" % str(key))
	var rng := contract.get("rng", {}) as Dictionary
	for key in rng.keys():
		_expect(int(rng.get(key, -1)) == 0, "RNG boundary remains zero: %s" % str(key))
	var architecture := contract.get("architecture", {}) as Dictionary
	for key in architecture.keys():
		_expect(int(architecture.get(key, -1)) == 0, "architecture boundary remains zero: %s" % str(key))


func _test_phase_truth(contract: Dictionary) -> void:
	var cutover := contract.get("cutover", {}) as Dictionary
	_expect(str(contract.get("phase", "")) == "PHASE_A_TO_D_REFERENCE_SEMANTICS_READY", "contract reports reference Phases A-D ready")
	_expect(bool(cutover.get("phase_a_contract_ready", false)), "Phase A contract is ready")
	for key in ["phase_b_reference_core_ready", "phase_c_reference_ai_ready", "phase_d_reference_player_ui_ready"]:
		_expect(bool(cutover.get(key, false)), "reference readiness is true: %s" % key)
	for key in ["phase_b_production_core_runtime_ready", "phase_c_production_ai_runtime_ready", "phase_d_production_player_ui_ready", "save_migration_ready", "production_consumers_migrated", "old_v06_counter_authority_disabled", "full_v0_7_runtime_cutover"]:
		_expect(not bool(cutover.get(key, true)), "production readiness remains false: %s" % key)
	_expect(bool(cutover.get("atomic_cutover_required", false)), "production cutover remains atomic")


func _test_human_readable_contract() -> void:
	var source := FileAccess.get_file_as_string(CONTRACT_MD_PATH)
	_expect(source.contains("V06_COUNTER_RUNTIME_PRESERVED_UNTIL_V07_CUTOVER=true"), "human-readable contract preserves V0.6 runtime truth")
	_expect(source.contains("PHASE=PHASE_A_TO_D_REFERENCE_SEMANTICS_READY"), "human-readable contract records reference A-D readiness")
	_expect(source.contains("CARD_BATCH_COMPLETE_RECEIPT"), "human-readable contract names the authoritative next-window receipt")
	_expect(source.contains("FIZZLE_NO_EFFECT"), "human-readable contract states the target invalidation default")
	_expect(source.contains("FULL_V0_7_RUNTIME_CUTOVER=false"), "human-readable contract does not overclaim production cutover")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("V07_COUNTER_RULE_CONTRACT_PASS (%d checks)" % _checks)
		quit(0)
	else:
		print("V07_COUNTER_RULE_CONTRACT_FAIL (%d/%d failed)" % [_failures.size(), _checks])
		quit(1)
