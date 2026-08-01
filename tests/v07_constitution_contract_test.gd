extends SceneTree

const CONSTITUTION_PATH := "res://docs/rules/v07_game_constitution.json"
const CONSTITUTION_MD_PATH := "res://docs/rules/v07_game_constitution.md"
const DEFAULTS_PATH := "res://docs/rules/v07_balance_defaults.json"
const PRECEDENCE_PATH := "res://docs/rules/v07_rule_precedence.md"
const DELTA_PATH := "res://docs/migration/v06_to_v07_rule_delta.json"
const DELTA_MD_PATH := "res://docs/migration/v06_to_v07_rule_delta.md"
const PROGRAM_STATE_PATH := "res://docs/development/current_program_state.json"
const AGENTS_PATH := "res://AGENTS.md"
const V06_RULEBOOK_PATH := "res://docs/tabletop_rulebook_v06.md"

const REQUIRED_CONSTITUTION_KEYS := [
	"schema_version",
	"constitution_id",
	"ruleset_id",
	"status",
	"authority_level",
	"current_production_ruleset",
	"target_development_ruleset",
	"authority_precedence",
	"constitutional_rule_value_schema",
	"constitutional_rules",
	"balance_defaults_reference",
	"inherited_v06_rules",
	"retired_rules",
	"semantic_obligations",
	"save_obligations",
	"player_presentation_obligations",
	"privacy_obligations",
	"cutover_obligations",
	"open_constitutional_questions",
]
const REQUIRED_RULE_KEYS := ["rule_id", "domain", "value", "statement"]
const REQUIRED_INHERITED_KEYS := [
	"rule_id",
	"source_ruleset_id",
	"semantics_inherited",
	"implementation_inherited",
	"value",
	"statement",
]
const REQUIRED_RETIRED_KEYS := ["rule_id", "active_in_v07"]
const REQUIRED_DEFAULTS_KEYS := [
	"schema_version",
	"defaults_id",
	"ruleset_id",
	"status",
	"authority_level",
	"default_value_schema",
	"defaults",
	"required_balance_tests",
]
const REQUIRED_DEFAULT_KEYS := [
	"default_id",
	"value",
	"unit",
	"balance_tunable",
	"constitutional",
	"constitutional_anchor",
]
const REQUIRED_DELTA_KEYS := [
	"schema_version",
	"matrix_id",
	"source_ruleset",
	"target_constitution",
	"status",
	"historical_pre_constitution_oracles",
	"entries",
]
const REQUIRED_DELTA_ENTRY_KEYS := [
	"rule_id",
	"v06_rule",
	"v07_rule",
	"classification",
	"affected_core_owner",
	"affected_ai_domain",
	"affected_player_surface",
	"affected_save_section",
	"affected_rng_stream",
	"affected_tests",
	"cutover_gate",
	"legacy_deletion_gate",
]
const ALLOWED_DELTA_CLASSES := ["unchanged", "modified", "retired", "new", "balance_rebased"]
const PRODUCTION_BEGIN := "<!-- CURRENT_PRODUCTION_V06_ONLY_BEGIN -->"
const PRODUCTION_END := "<!-- CURRENT_PRODUCTION_V06_ONLY_END -->"
const REQUIRED_RULE_VALUE_SCHEMA_KEYS := [
	"schema_version",
	"closed_object_keys_by_rule_id",
	"closed_string_list_rule_ids",
	"bool_rule_ids",
	"number_rule_ids",
	"enum_string_rule_ids",
]
const REQUIRED_DEFAULT_VALUE_SCHEMA_KEYS := [
	"schema_version",
	"closed_object_keys_by_default_id",
	"bool_default_ids",
	"number_default_ids",
	"enum_string_default_ids",
]
const EXPECTED_V07_SAVE_STATE := [
	"normal_draw_pile_order",
	"normal_hand",
	"normal_discard",
	"committed_escrow",
	"merge_history_and_instance_identity",
	"normal_card_levels",
	"commodity_inventory_and_levels",
	"bound_action_sources",
	"six_color_assets_and_fixed_point_remainders",
	"asset_reservations",
	"frozen_gdp_snapshot",
	"submission_window",
	"player_local_queues",
	"anonymous_global_queue",
	"unified_track_items_and_positions",
	"track_type_supply_state",
	"track_color_supply_state",
	"market_color_cycle",
	"locked_stances",
	"hidden_lead_order_and_cursor",
	"macro_round_direction",
	"solar_state",
	"victory_macro_round_gate",
]
const EXPECTED_V07_RNG_STREAMS := [
	"starter_deck_shuffle",
	"normal_deck_reshuffle_by_player",
	"unified_track_type_draw",
	"unified_track_color_draw",
	"unified_track_normal_card_draw",
	"unified_track_commodity_draw",
	"initial_hidden_lead_order",
]
const EXPECTED_AUTHORITY_SECRET_FIELDS := [
	"other_track_segments",
	"future_track_sequence",
	"future_supply_bags",
	"hidden_lead_identity",
	"hidden_lead_order",
	"effective_weights",
	"raw_contribution_breakdown",
	"other_private_stances",
	"other_hands",
	"other_commodity_inventories",
	"other_exact_assets",
	"other_reservations",
	"other_local_queues",
	"rng_state",
	"save_payload",
]
const EXPECTED_SEMANTIC_DOMAINS := [
	"unified_card_track",
	"market_color_cycle",
	"hidden_lead_cycle",
	"normal_draw_pile",
	"normal_hand",
	"normal_discard",
	"normal_card_merge",
	"commodity_inventory",
	"commodity_merge",
	"bound_actions",
	"six_color_assets",
	"asset_cycle_snapshot",
	"asset_reservations",
	"card_batch_submission",
	"prebound_targets",
	"anonymous_resolution",
	"solar_facility_efficiency",
	"macro_round_victory_gate",
]
const EXPECTED_PRIVACY_PUBLIC := [
	"current_six_color_distribution",
	"revealed_stances_with_actor_identity",
	"track_and_cycle_timers",
	"rule_allowed_resolution_facts",
]
const EXPECTED_PRIVACY_VIEWER_PRIVATE := [
	"own_track_segment",
	"own_hidden_next_stance",
	"own_stance_lock",
	"self_lead_notice",
	"own_hand",
	"own_commodity_inventory",
	"own_assets_and_reservations",
	"own_local_queue",
]
const EXPECTED_HISTORICAL_PRE_CONSTITUTION_ORACLES := [
	"docs/rules/shared_partial_visibility_commodity_track_direction.md",
	"docs/rules/shared_partial_visibility_commodity_track_contract.md",
	"docs/rules/shared_partial_visibility_commodity_track_contract.json",
	"docs/rules/shared_partial_visibility_commodity_track_test_vectors.json",
	"docs/migration/shared_partial_visibility_commodity_track_gap_audit.md",
	"docs/migration/shared_partial_visibility_commodity_track_gap_audit.json",
	"docs/migration/shared_partial_visibility_commodity_track_implementation_plan.md",
	"docs/migration/shared_partial_visibility_commodity_track_implementation_plan.json",
	"docs/migration/shared_partial_visibility_commodity_track_three_layer_handoff.md",
	"docs/migration/v07_global_semantic_action_spine_cutover.md",
	"docs/migration/v07_global_semantic_action_spine_cutover.json",
	"tests/shared_partial_visibility_commodity_track_three_layer_semantics_test.gd",
	"tests/support/shared_commodity_track_core_semantics_reference.gd",
	"tests/support/shared_commodity_track_semantic_query_source_reference.gd",
	"tests/support/shared_commodity_track_ai_semantics_reference.gd",
	"tests/support/shared_commodity_track_player_semantics_reference.gd",
	"scenes/tools/SharedCommodityTrackThreeLayerSemanticsBench.tscn",
	"README.md",
	"docs/rules_v06_runtime_directive.md",
	"docs/semantic/global_three_layer_semantic_registry.json",
]

var _checks := 0
var _failures: Array[String] = []
var _constitutional_rule_count := 0
var _balance_default_count := 0
var _inherited_rule_count := 0
var _retired_rule_count := 0
var _delta_entry_count := 0
var _conflicting_unqualified_v06_target_rule_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var constitution := _read_json(CONSTITUTION_PATH)
	var defaults := _read_json(DEFAULTS_PATH)
	var delta := _read_json(DELTA_PATH)
	var program_state := _read_json(PROGRAM_STATE_PATH)
	_expect(not constitution.is_empty(), "V0.7 constitution JSON parses")
	_expect(not defaults.is_empty(), "V0.7 balance defaults JSON parses")
	_expect(not delta.is_empty(), "V0.6 to V0.7 delta JSON parses")
	_expect(not program_state.is_empty(), "current program state JSON parses")
	_validate_constitution(constitution)
	_validate_defaults(defaults, constitution)
	_validate_delta(delta)
	_validate_program_state(program_state)
	_validate_documents_and_links()
	_validate_agents_precedence_and_conflicts()
	_finish()


func _validate_constitution(constitution: Dictionary) -> void:
	_expect(_has_exact_keys(constitution, REQUIRED_CONSTITUTION_KEYS), "constitution top level is closed")
	_expect(int(constitution.get("schema_version", 0)) == 1, "constitution schema version is 1")
	_expect(str(constitution.get("constitution_id", "")) == "space_syndicate.v07.complete", "constitution ID is frozen")
	_expect(str(constitution.get("ruleset_id", "")) == "v0.7", "constitution ruleset ID is v0.7")
	_expect(str(constitution.get("status", "")) == "frozen_target_constitution", "constitution status is frozen target")
	_expect(str(constitution.get("authority_level", "")) == "highest_target_rule_authority", "constitution has highest target authority")
	_expect(str(constitution.get("current_production_ruleset", "")) == "v0.6", "current production remains v0.6")
	_expect(str(constitution.get("target_development_ruleset", "")) == "v0.7", "target development ruleset is v0.7")
	var questions: Array = constitution.get("open_constitutional_questions", []) if constitution.get("open_constitutional_questions", []) is Array else []
	_expect(questions.is_empty(), "open constitutional question count is zero")

	var rules: Array = constitution.get("constitutional_rules", []) if constitution.get("constitutional_rules", []) is Array else []
	_constitutional_rule_count = rules.size()
	_expect(_constitutional_rule_count == 76, "constitution contains the frozen 76-rule concept set")
	var rule_index: Dictionary = {}
	for rule_variant in rules:
		_expect(rule_variant is Dictionary, "every constitutional rule is an object")
		if not (rule_variant is Dictionary):
			continue
		var rule: Dictionary = rule_variant
		_expect(_has_exact_keys(rule, REQUIRED_RULE_KEYS), "%s has the closed constitutional rule shape" % str(rule.get("rule_id", "<missing>")))
		var rule_id := str(rule.get("rule_id", ""))
		_expect(rule_id.begins_with("v07."), "%s uses a stable V0.7 rule ID" % rule_id)
		_expect(not rule_index.has(rule_id), "%s is unique" % rule_id)
		_expect(not str(rule.get("domain", "")).is_empty(), "%s names a domain" % rule_id)
		_expect(not str(rule.get("statement", "")).is_empty(), "%s has a human statement" % rule_id)
		rule_index[rule_id] = rule
	var rule_value_schema: Dictionary = constitution.get("constitutional_rule_value_schema", {}) if constitution.get("constitutional_rule_value_schema", {}) is Dictionary else {}
	_validate_rule_value_schema(rule_index, rule_value_schema)

	_expect(_rule_value(rule_index, "v07.track.single_unified_track") == true, "unified card track is constitutional")
	var legacy_track: Dictionary = _rule_value(rule_index, "v07.track.legacy_sources_retired") as Dictionary
	_expect(legacy_track.get("separate_normal_card_track", true) == false and legacy_track.get("separate_commodity_track", true) == false and legacy_track.get("region_bound_normal_card_pool", true) == false, "separate and region-bound tracks are retired")
	var uniform: Dictionary = _rule_value(rule_index, "v07.color_cycle.uniform_reset") as Dictionary
	_expect(int(uniform.get("equal_weight_per_color", 0)) == 1 and int(uniform.get("total_weight", 0)) == 6, "color cycle uses six equal baseline weights")
	_expect(uniform.get("previous_cycle_distribution_inherited", true) == false and uniform.get("cycle_modifiers_compound", true) == false, "color cycles neither inherit nor compound")
	var gdp_independence: Dictionary = _rule_value(rule_index, "v07.color_cycle.gdp_independence") as Dictionary
	_expect(gdp_independence.get("gdp_affects_track_color_distribution", true) == false and gdp_independence.get("gdp_affects_track_card_type_distribution", true) == false, "GDP has no unified-track supply influence")
	var stance: Dictionary = _rule_value(rule_index, "v07.color_cycle.stance_intent") as Dictionary
	_expect(bool(stance.get("colors_must_differ", false)) and bool(stance.get("last_legal_unlocked_selection_auto_locks_at_boundary", false)), "last legal distinct-color stance auto-locks at the boundary")
	var stance_reveal: Dictionary = _rule_value(rule_index, "v07.color_cycle.reveal_and_privacy") as Dictionary
	_expect(bool(stance_reveal.get("stance_directions_public_after_reveal", false)) and bool(stance_reveal.get("stance_actor_identity_public_after_reveal", false)) and stance_reveal.get("effective_weights_public", true) == false and stance_reveal.get("lead_identity_public", true) == false, "revealed stances identify actors while lead and weight remain hidden")
	var influence: Dictionary = _rule_value(rule_index, "v07.color_cycle.influence_weight") as Dictionary
	_expect(int(influence.get("normal_player_influence_basis_points", 0)) == 300 and int(influence.get("lead_player_influence_basis_points", 0)) == 600 and str(influence.get("weight_lead_timing", "")) == "lead_at_boundary_entry_before_cursor_advance" and bool(influence.get("cursor_advances_after_distribution_commit", false)), "normal/lead influence is fixed at 3/6 points and uses the boundary-entry lead before cursor advance")
	var lead_notice: Dictionary = _rule_value(rule_index, "v07.lead.private_self_notice") as Dictionary
	_expect(bool(lead_notice.get("self_notice_private", false)) and bool(lead_notice.get("notice_includes_double_influence", false)) and lead_notice.get("different_public_animation", true) == false and lead_notice.get("different_input_flow", true) == false, "lead receives a private double-influence notice without a side channel")

	var starter: Dictionary = _rule_value(rule_index, "v07.starter.deck_composition") as Dictionary
	var starter_ids: Array = starter.get("card_ids", []) if starter.get("card_ids", []) is Array else []
	_expect(int(starter.get("deck_size", 0)) == 12 and starter_ids.size() == 12 and _unique_string_count(starter_ids) == 12, "starter deck has twelve stable unique card IDs")
	var initial_deal: Dictionary = _rule_value(rule_index, "v07.starter.initial_deal") as Dictionary
	_expect(int(initial_deal.get("initial_hand_size", 0)) == 5 and int(initial_deal.get("remaining_draw_pile_size", 0)) == 7, "initial deal is five cards with seven remaining")
	_expect(int(_rule_value(rule_index, "v07.hand.normal_limit")) == 5, "normal hand limit is five")
	var maintenance: Dictionary = _rule_value(rule_index, "v07.hand.maintenance_sequence") as Dictionary
	_expect(maintenance.get("world_time_advances", true) == false and str(maintenance.get("timeout_policy", "")) == "auto_end_without_additional_merge" and str(maintenance.get("timeout_seconds_default_id", "")) == "v07.balance.hand_maintenance_timeout_seconds" and bool(maintenance.get("already_committed_merges_preserved", false)), "maintenance pauses world time and auto-ends safely on its balance timeout")
	var commodity_inventory: Dictionary = _rule_value(rule_index, "v07.commodity.separate_inventory") as Dictionary
	_expect(int(commodity_inventory.get("limit", 0)) == 5 and commodity_inventory.get("uses_normal_hand", true) == false, "commodity inventory is an independent five slots")
	var commodity_merge: Dictionary = _rule_value(rule_index, "v07.commodity_merge.edges_and_cap") as Dictionary
	_expect(int(commodity_merge.get("maximum_level", 0)) == 3 and commodity_merge.get("edges", []) == ["L1+L1=L2", "L2+L1=L3"], "commodity merge ends at level III with the two frozen edges")

	_expect(int(_rule_value(rule_index, "v07.assets.per_color_cap")) == 6, "six-color asset cap is six per color")
	var asset_terms: Dictionary = _rule_value(rule_index, "v07.assets.player_term_and_colors") as Dictionary
	_expect(asset_terms.get("retired_player_terms", []) == ["mana", "mana_points", "法力", "法力值", "玛娜"] and (asset_terms.get("localized_player_asset_names_zh", []) as Array).size() == 6, "all retired mana terms and six Chinese asset names are machine-readable")
	var recovery: Dictionary = _rule_value(rule_index, "v07.assets.no_continuous_recovery") as Dictionary
	_expect(recovery.get("continuous_recovery", true) == false and str(recovery.get("recovery_mode", "")) == "cycle_end_top_up", "asset recovery is cycle-end top-up")
	var batch: Dictionary = _rule_value(rule_index, "v07.batch.one_shot_window") as Dictionary
	_expect(int(batch.get("duration_seconds", 0)) == 30 and bool(batch.get("one_shot", false)), "submission window is thirty-second one-shot")
	var active_capacity: Dictionary = _rule_value(rule_index, "v07.batch.shared_active_capacity") as Dictionary
	_expect(int(active_capacity.get("maximum", 0)) == 5 and active_capacity.get("capacity_modifiers_allowed", true) == false, "maximum active actions per player is an absolute five")
	var prebound: Dictionary = _rule_value(rule_index, "v07.batch.prebound_targets_and_local_order") as Dictionary
	_expect(bool(prebound.get("complete_targets_selected_before_lock", false)), "targets are complete before lock")
	var reservation: Dictionary = _rule_value(rule_index, "v07.reservation.full_queue") as Dictionary
	_expect(bool(reservation.get("full_queue_affordability_required", false)) and bool(reservation.get("per_action_reservation_required", false)), "lock requires full per-action reservation")

	var counter: Dictionary = _rule_value(rule_index, "v07.counter.retired") as Dictionary
	_expect(counter.get("interactive_counters", true) == false and counter.get("counter_window", true) == false and counter.get("counter_stack", true) == false, "interactive counters and stack are retired")
	var round_robin: Dictionary = _rule_value(rule_index, "v07.resolution.round_robin") as Dictionary
	_expect(str(round_robin.get("mode", "")) == "round_robin_by_local_action_index" and bool(round_robin.get("player_local_order_preserved", false)), "anonymous resolution is local-index round robin")
	var anonymous: Dictionary = _rule_value(rule_index, "v07.resolution.owner_anonymous_public_queue") as Dictionary
	_expect((anonymous.get("hidden_fields", []) as Array).has("actor_id") and anonymous.get("owner_specific_animation_or_audio", true) == false, "public resolution queue hides owner and side channels")

	var solar: Dictionary = _rule_value(rule_index, "v07.solar.efficiency") as Dictionary
	_expect(float(solar.get("sunlit_multiplier", 0.0)) == 2.0 and float(solar.get("dark_multiplier", 0.0)) == 1.0, "sunlit/dark facility multipliers are 2.0/1.0")
	var solar_scope: Dictionary = _rule_value(rule_index, "v07.solar.non_effects_and_authority") as Dictionary
	_expect((solar_scope.get("does_not_affect", []) as Array).has("card_purchase_legality"), "sunlight card purchase rule is retired")
	var victory_gate: Array = _rule_value(rule_index, "v07.victory.complete_boundary_gate") as Array
	_expect(victory_gate.has("batch_complete") and victory_gate.has("hand_maintenance_complete") and victory_gate.has("macro_round_complete") and victory_gate.has("every_player_led_once"), "game end waits for complete batch maintenance and macro round")
	var inherited_end: Dictionary = _rule_value(rule_index, "v07.victory.inherit_qualification") as Dictionary
	_expect(str(inherited_end.get("inherited_scope", "")) == "all_unmodified_v06_end_conditions_and_victory_audit_comparison" and str(inherited_end.get("mid_macro_round_result", "")) == "pending_without_immediate_final_settlement", "every inherited end condition enters the pending macro-round gate")

	var inherited: Array = constitution.get("inherited_v06_rules", []) if constitution.get("inherited_v06_rules", []) is Array else []
	_inherited_rule_count = inherited.size()
	_expect(_inherited_rule_count == 10, "ten inherited V0.6 semantic groups are explicit")
	for inherited_variant in inherited:
		_expect(inherited_variant is Dictionary and _has_exact_keys(inherited_variant as Dictionary, REQUIRED_INHERITED_KEYS), "inherited rule uses the closed shape")
		if inherited_variant is Dictionary:
			var inherited_rule: Dictionary = inherited_variant
			_expect(str(inherited_rule.get("source_ruleset_id", "")) == "v0.6" and bool(inherited_rule.get("semantics_inherited", false)) and inherited_rule.get("implementation_inherited", true) == false, "%s inherits semantics but not implementation" % str(inherited_rule.get("rule_id", "<missing>")))

	var retired: Array = constitution.get("retired_rules", []) if constitution.get("retired_rules", []) is Array else []
	_retired_rule_count = retired.size()
	_expect(_retired_rule_count == 22, "twenty-two retired target rules are explicit")
	for retired_variant in retired:
		_expect(retired_variant is Dictionary and _has_exact_keys(retired_variant as Dictionary, REQUIRED_RETIRED_KEYS), "retired rule uses the closed shape")
		if retired_variant is Dictionary:
			_expect((retired_variant as Dictionary).get("active_in_v07", true) == false, "%s is false in V0.7" % str((retired_variant as Dictionary).get("rule_id", "<missing>")))

	var semantics: Dictionary = constitution.get("semantic_obligations", {}) if constitution.get("semantic_obligations", {}) is Dictionary else {}
	_expect(_has_exact_keys(semantics, ["three_wings", "required_domains", "required_domains_x_three_wings_cross_product", "typed_intent_required", "authoritative_receipt_required", "privacy_policy_required", "rng_ownership_required", "ai_rule_copy_allowed", "ui_legality_recalculation_allowed", "save_second_authority_allowed", "localized_name_rule_inference_allowed", "main_business_state_allowed", "global_three_layer_complete"]), "semantic obligations are closed")
	_expect(semantics.get("three_wings", []) == ["core_semantics", "ai_semantics", "player_semantics"], "semantic obligations name the exact three wings")
	_expect(semantics.get("required_domains", []) == EXPECTED_SEMANTIC_DOMAINS, "semantic obligations cover the exact eighteen V0.7 domains")
	_expect(bool(semantics.get("required_domains_x_three_wings_cross_product", false)), "every required domain owes Core, AI, and player semantics")
	_expect(bool(semantics.get("typed_intent_required", false)) and bool(semantics.get("authoritative_receipt_required", false)) and bool(semantics.get("privacy_policy_required", false)) and bool(semantics.get("rng_ownership_required", false)), "typed intent, receipt, privacy, and RNG obligations are mandatory")
	_expect(semantics.get("ai_rule_copy_allowed", true) == false and semantics.get("ui_legality_recalculation_allowed", true) == false and semantics.get("save_second_authority_allowed", true) == false and semantics.get("localized_name_rule_inference_allowed", true) == false and semantics.get("main_business_state_allowed", true) == false and semantics.get("global_three_layer_complete", true) == false, "duplicate AI/UI/Save/name/Main authority is forbidden without false completion")
	var save: Dictionary = constitution.get("save_obligations", {}) if constitution.get("save_obligations", {}) is Dictionary else {}
	_expect(_has_exact_keys(save, ["versioned_v07_schema_required", "v06_save_to_v07_direct_resume", "v06_save_backup_required", "required_state", "required_rng_streams", "ui_ai_hover_drag_animation_rng_draw_allowed"]), "Save and RNG obligations are closed")
	_expect(save.get("v06_save_to_v07_direct_resume", true) == false and bool(save.get("v06_save_backup_required", false)), "V0.6 Save cannot directly resume as V0.7 and requires backup")
	_expect(bool(save.get("versioned_v07_schema_required", false)) and save.get("required_state", []) == EXPECTED_V07_SAVE_STATE, "V0.7 Save covers the exact twenty-three authoritative state groups")
	_expect(save.get("required_rng_streams", []) == EXPECTED_V07_RNG_STREAMS and save.get("ui_ai_hover_drag_animation_rng_draw_allowed", true) == false, "seven exact rule RNG streams are separated from UI and observation")
	var presentation: Dictionary = constitution.get("player_presentation_obligations", {}) if constitution.get("player_presentation_obligations", {}) is Dictionary else {}
	_expect(_has_exact_keys(presentation, ["top_surface", "six_color_symbols", "player_card_dock", "asset_display", "hand_interaction", "region_popup_normal_card_purchase", "planet_requirements", "replaceable_baseline_assets_required", "visual_resource_may_own_rules"]), "player presentation obligations are closed")
	var top_surface: Dictionary = presentation.get("top_surface", {}) if presentation.get("top_surface", {}) is Dictionary else {}
	_expect(_has_exact_keys(top_surface, ["unified_track_count", "mixed_card_kinds_visually_distinct", "shows_current_six_color_distribution", "shows_public_stance_directions", "shows_public_stance_actor_identity", "shows_viewer_local_segment", "shows_track_countdown", "shows_other_player_segments", "shows_future_track", "shows_lead_weight_owner"]), "top player surface obligation is closed")
	_expect(int(top_surface.get("unified_track_count", 0)) == 1 and bool(top_surface.get("shows_public_stance_actor_identity", false)) and top_surface.get("shows_other_player_segments", true) == false, "player UI has one unified viewer-private track surface and actor-linked public stances")
	_expect(presentation.get("region_popup_normal_card_purchase", true) == false and presentation.get("visual_resource_may_own_rules", true) == false, "region popup purchase and visual rule ownership are retired")
	var privacy: Dictionary = constitution.get("privacy_obligations", {}) if constitution.get("privacy_obligations", {}) is Dictionary else {}
	_expect(_has_exact_keys(privacy, ["public", "viewer_private", "authority_secret", "public_resolution_owner_anonymous", "timing_animation_audio_identity_leak_allowed"]), "privacy obligations are closed")
	_expect(privacy.get("public", []) == EXPECTED_PRIVACY_PUBLIC, "privacy contract freezes the exact public facts")
	_expect(privacy.get("viewer_private", []) == EXPECTED_PRIVACY_VIEWER_PRIVATE, "privacy contract freezes the exact viewer-private facts")
	_expect(privacy.get("authority_secret", []) == EXPECTED_AUTHORITY_SECRET_FIELDS, "privacy contract freezes all authority-secret fields")
	_expect(bool(privacy.get("public_resolution_owner_anonymous", false)) and privacy.get("timing_animation_audio_identity_leak_allowed", true) == false, "resolution remains owner-anonymous without presentation side channels")
	var cutover: Dictionary = constitution.get("cutover_obligations", {}) if constitution.get("cutover_obligations", {}) is Dictionary else {}
	_expect(_has_exact_keys(cutover, ["docs_only_freeze", "runtime_implementation_allowed_by_this_task", "reference_runtime_implementation_allowed_by_this_task", "production_cutover_allowed_by_this_task", "target_rules_pretend_to_be_runtime", "current_runtime_overrides_target_constitution", "v06_remains_current_player_runtime_until_atomic_cutover", "old_tests_may_veto_target_constitution", "production_change_requires_explicit_atomic_cutover_task", "long_term_compatibility_dual_writer_allowed", "old_authority_deletion_required_in_same_domain_cutover"]), "cutover obligations are closed")
	_expect(bool(cutover.get("docs_only_freeze", false)) and cutover.get("runtime_implementation_allowed_by_this_task", true) == false and cutover.get("production_cutover_allowed_by_this_task", true) == false, "constitution freeze performs no runtime implementation or cutover")
	_expect(cutover.get("target_rules_pretend_to_be_runtime", true) == false and cutover.get("current_runtime_overrides_target_constitution", true) == false and bool(cutover.get("v06_remains_current_player_runtime_until_atomic_cutover", false)) and cutover.get("old_tests_may_veto_target_constitution", true) == false and bool(cutover.get("production_change_requires_explicit_atomic_cutover_task", false)) and cutover.get("long_term_compatibility_dual_writer_allowed", true) == false and bool(cutover.get("old_authority_deletion_required_in_same_domain_cutover", false)), "target/runtime precedence and atomic single-writer cutover are enforced")


func _validate_defaults(defaults: Dictionary, constitution: Dictionary) -> void:
	_expect(_has_exact_keys(defaults, REQUIRED_DEFAULTS_KEYS), "balance defaults top level is closed")
	_expect(int(defaults.get("schema_version", 0)) == 1, "balance defaults schema version is 1")
	_expect(str(defaults.get("ruleset_id", "")) == "v0.7", "balance defaults target v0.7")
	var rules: Array = constitution.get("constitutional_rules", []) if constitution.get("constitutional_rules", []) is Array else []
	var rule_ids: Dictionary = {}
	for rule_variant in rules:
		if rule_variant is Dictionary:
			rule_ids[str((rule_variant as Dictionary).get("rule_id", ""))] = true
	var entries: Array = defaults.get("defaults", []) if defaults.get("defaults", []) is Array else []
	_balance_default_count = entries.size()
	_expect(_balance_default_count == 24, "twenty-four initial balance defaults are explicit")
	var default_index: Dictionary = {}
	for entry_variant in entries:
		_expect(entry_variant is Dictionary, "every balance default is an object")
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		_expect(_has_exact_keys(entry, REQUIRED_DEFAULT_KEYS), "%s has the closed balance-default shape" % str(entry.get("default_id", "<missing>")))
		var default_id := str(entry.get("default_id", ""))
		_expect(default_id.begins_with("v07.balance."), "%s uses a stable balance ID" % default_id)
		_expect(not default_index.has(default_id), "%s is unique" % default_id)
		_expect(entry.get("balance_tunable", false) == true and entry.get("constitutional", true) == false, "%s is tunable and non-constitutional" % default_id)
		_expect(rule_ids.has(str(entry.get("constitutional_anchor", ""))), "%s anchors to a constitutional rule" % default_id)
		default_index[default_id] = entry
	var default_value_schema: Dictionary = defaults.get("default_value_schema", {}) if defaults.get("default_value_schema", {}) is Dictionary else {}
	_validate_default_value_schema(default_index, default_value_schema)
	_expect(int(_default_value(default_index, "v07.balance.market_color_cycle_seconds")) == 180, "initial market color cycle is 180 seconds")
	_expect(int(_default_value(default_index, "v07.balance.lead_tenure_seconds")) == 60, "initial lead tenure is 60 seconds")
	var kind_total := int(_default_value(default_index, "v07.balance.track_normal_card_ratio_basis_points")) + int(_default_value(default_index, "v07.balance.track_commodity_card_ratio_basis_points"))
	_expect(kind_total == 10000, "normal and commodity initial kind ratios total 10000 basis points")
	_expect(not default_index.has("v07.balance.player_count_influence_scale"), "balance defaults cannot scale the constitutional 300/600 influence")
	_expect(int(_default_value(default_index, "v07.balance.normal_card_base_purchase_cash")) == 5, "normal-card initial base purchase price is one rank-independent scalar")
	_expect(int(_default_value(default_index, "v07.balance.hand_maintenance_timeout_seconds")) == 20, "initial hand-maintenance timeout is twenty seconds")


func _validate_rule_value_schema(rule_index: Dictionary, schema: Dictionary) -> void:
	_expect(_has_exact_keys(schema, REQUIRED_RULE_VALUE_SCHEMA_KEYS), "constitutional value schema is closed")
	_expect(int(schema.get("schema_version", 0)) == 1, "constitutional value schema version is 1")
	var coverage: Dictionary = {}
	var object_schemas: Dictionary = schema.get("closed_object_keys_by_rule_id", {}) if schema.get("closed_object_keys_by_rule_id", {}) is Dictionary else {}
	for rule_id_variant in object_schemas.keys():
		var rule_id := str(rule_id_variant)
		_expect(rule_index.has(rule_id), "%s object schema references a real rule" % rule_id)
		_expect(not coverage.has(rule_id), "%s has one value schema" % rule_id)
		coverage[rule_id] = true
		var value: Variant = _rule_value(rule_index, rule_id)
		var expected_keys: Array = object_schemas.get(rule_id, []) if object_schemas.get(rule_id, []) is Array else []
		_expect(value is Dictionary, "%s value is a closed object" % rule_id)
		if value is Dictionary:
			_expect(_has_exact_keys(value as Dictionary, expected_keys), "%s object value has exactly its declared keys" % rule_id)
	for group_spec in [
		["closed_string_list_rule_ids", "closed_string_list"],
		["bool_rule_ids", "bool"],
		["number_rule_ids", "number"],
		["enum_string_rule_ids", "enum_string"],
	]:
		var group_key := str(group_spec[0])
		var value_type := str(group_spec[1])
		var ids: Array = schema.get(group_key, []) if schema.get(group_key, []) is Array else []
		for rule_id_variant in ids:
			var rule_id := str(rule_id_variant)
			_expect(rule_index.has(rule_id), "%s %s schema references a real rule" % [rule_id, value_type])
			_expect(not coverage.has(rule_id), "%s has one value schema" % rule_id)
			coverage[rule_id] = true
			var value: Variant = _rule_value(rule_index, rule_id)
			if value_type == "closed_string_list":
				_expect(value is Array and _all_nonempty_strings(value as Array), "%s is a closed nonempty string list" % rule_id)
			elif value_type == "bool":
				_expect(value is bool, "%s is a boolean" % rule_id)
			elif value_type == "number":
				_expect(value is int or value is float, "%s is numeric" % rule_id)
			else:
				_expect(value is String and not str(value).is_empty(), "%s is a nonempty enum string" % rule_id)
	_expect(coverage.size() == rule_index.size(), "constitutional value schema covers all 76 rules exactly once")
	for rule_id_variant in rule_index.keys():
		_expect(coverage.has(str(rule_id_variant)), "%s has a declared value schema" % str(rule_id_variant))


func _validate_default_value_schema(default_index: Dictionary, schema: Dictionary) -> void:
	_expect(_has_exact_keys(schema, REQUIRED_DEFAULT_VALUE_SCHEMA_KEYS), "balance default value schema is closed")
	_expect(int(schema.get("schema_version", 0)) == 1, "balance default value schema version is 1")
	var coverage: Dictionary = {}
	var object_schemas: Dictionary = schema.get("closed_object_keys_by_default_id", {}) if schema.get("closed_object_keys_by_default_id", {}) is Dictionary else {}
	for default_id_variant in object_schemas.keys():
		var default_id := str(default_id_variant)
		_expect(default_index.has(default_id), "%s object schema references a real default" % default_id)
		_expect(not coverage.has(default_id), "%s has one value schema" % default_id)
		coverage[default_id] = true
		var value: Variant = _default_value(default_index, default_id)
		var expected_keys: Array = object_schemas.get(default_id, []) if object_schemas.get(default_id, []) is Array else []
		_expect(value is Dictionary, "%s value is a closed object" % default_id)
		if value is Dictionary:
			_expect(_has_exact_keys(value as Dictionary, expected_keys), "%s object value has exactly its declared keys" % default_id)
	for group_spec in [
		["bool_default_ids", "bool"],
		["number_default_ids", "number"],
		["enum_string_default_ids", "enum_string"],
	]:
		var group_key := str(group_spec[0])
		var value_type := str(group_spec[1])
		var ids: Array = schema.get(group_key, []) if schema.get(group_key, []) is Array else []
		for default_id_variant in ids:
			var default_id := str(default_id_variant)
			_expect(default_index.has(default_id), "%s %s schema references a real default" % [default_id, value_type])
			_expect(not coverage.has(default_id), "%s has one value schema" % default_id)
			coverage[default_id] = true
			var value: Variant = _default_value(default_index, default_id)
			if value_type == "bool":
				_expect(value is bool, "%s is a boolean" % default_id)
			elif value_type == "number":
				_expect(value is int or value is float, "%s is numeric" % default_id)
			else:
				_expect(value is String and not str(value).is_empty(), "%s is a nonempty enum string" % default_id)
	_expect(coverage.size() == default_index.size(), "balance value schema covers all 24 defaults exactly once")
	for default_id_variant in default_index.keys():
		_expect(coverage.has(str(default_id_variant)), "%s has a declared value schema" % str(default_id_variant))


func _validate_delta(delta: Dictionary) -> void:
	_expect(_has_exact_keys(delta, REQUIRED_DELTA_KEYS), "migration delta top level is closed")
	_expect(str(delta.get("source_ruleset", "")) == "v0.6" and str(delta.get("target_constitution", "")) == "space_syndicate.v07.complete", "migration delta maps V0.6 to the frozen V0.7 constitution")
	_expect(delta.get("historical_pre_constitution_oracles", []) == EXPECTED_HISTORICAL_PRE_CONSTITUTION_ORACLES, "machine migration inventory freezes all twenty pre-constitution or current-runtime references")
	for historical_path in EXPECTED_HISTORICAL_PRE_CONSTITUTION_ORACLES:
		_expect(FileAccess.file_exists("res://%s" % historical_path), "historical reference exists: %s" % historical_path)
	var entries: Array = delta.get("entries", []) if delta.get("entries", []) is Array else []
	_delta_entry_count = entries.size()
	_expect(_delta_entry_count == 28, "migration delta contains the frozen 28 atomic rule changes")
	var ids: Dictionary = {}
	for entry_variant in entries:
		_expect(entry_variant is Dictionary, "every migration delta is an object")
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var rule_id := str(entry.get("rule_id", "<missing>"))
		_expect(_has_exact_keys(entry, REQUIRED_DELTA_ENTRY_KEYS), "%s has the closed migration shape" % rule_id)
		_expect(not ids.has(rule_id), "%s is unique" % rule_id)
		ids[rule_id] = true
		_expect(str(entry.get("classification", "")) in ALLOWED_DELTA_CLASSES, "%s has an allowed classification" % rule_id)
		for key in ["affected_core_owner", "affected_ai_domain", "affected_player_surface", "affected_save_section", "affected_rng_stream", "affected_tests"]:
			_expect(entry.get(key, null) is Array, "%s.%s is an array" % [rule_id, key])
		_expect(not str(entry.get("cutover_gate", "")).is_empty() and not str(entry.get("legacy_deletion_gate", "")).is_empty(), "%s has cutover and deletion gates" % rule_id)


func _validate_program_state(program_state: Dictionary) -> void:
	var program: Dictionary = program_state.get("program", {}) if program_state.get("program", {}) is Dictionary else {}
	_expect(program.get("v07_highest_constitution_written", false) == true, "program state records written V0.7 constitution")
	_expect(program.get("v07_highest_constitution_frozen", false) == true, "program state records frozen V0.7 constitution")
	_expect(str(program.get("v07_constitution_id", "")) == "space_syndicate.v07.complete", "program state records the frozen constitution ID")
	_expect(str(program.get("current_production_runtime_ruleset", "")) == "v0.6" and str(program.get("target_development_constitution", "")) == "v0.7.1", "program state retains V0.7 as history while separating current v0.6 from the V0.7.1 target")
	_expect(program.get("v07_historical_constitution_retained", false) == true and int(program.get("v07_historical_constitution_content_change_count", -1)) == 0, "program state records byte-stable historical V0.7 authority")
	_expect(program.get("full_v0_7_runtime_cutover", true) == false and program.get("v07_semantic_kernel_ready", true) == false and program.get("v07_ai_semantics_ready", true) == false and program.get("v07_player_semantics_ready", true) == false and program.get("v07_save_schema_ready", true) == false, "program state makes no V0.7 runtime readiness claim")
	_expect(str(program.get("alpha04c_save_resume", "")) == "PARTIAL" and program.get("pr77_draft", false) == true, "Alpha 0.4-C remains partial and PR 77 remains draft")


func _validate_documents_and_links() -> void:
	for path in [CONSTITUTION_PATH, CONSTITUTION_MD_PATH, DEFAULTS_PATH, PRECEDENCE_PATH, DELTA_PATH, DELTA_MD_PATH, PROGRAM_STATE_PATH, AGENTS_PATH, V06_RULEBOOK_PATH]:
		_expect(FileAccess.file_exists(path), "%s exists" % path)
	var constitution_md := _read_text(CONSTITUTION_MD_PATH)
	_expect(constitution_md.contains("CONSTITUTION_ID=space_syndicate.v07.complete") and constitution_md.contains("OPEN_CONSTITUTIONAL_QUESTION_COUNT=0"), "human constitution identifies the frozen closed authority")
	_expect(constitution_md.contains("facility.factory.life.rank_1") and constitution_md.contains("facility.market.shipping.rank_1"), "human constitution lists stable starter card identities")
	var precedence := _read_text(PRECEDENCE_PATH)
	_expect(precedence.contains("HIGHEST_TARGET_RULE_AUTHORITY=V0.7_COMPLETE_CONSTITUTION") and precedence.contains("CURRENT_PLAYER_RUNTIME_RULE_AUTHORITY=V0.6_RULEBOOK"), "precedence document separates target and runtime authority")
	_expect(precedence.contains("shared_partial_visibility_commodity_track_contract.json") and precedence.contains("historical"), "old partial V0.7 contracts are explicitly historical")
	var delta_md := _read_text(DELTA_MD_PATH)
	_expect(delta_md.contains("v07.delta.region_racks_to_unified_track") and delta_md.contains("v07.delta.immediate_end_to_macro_round_gate"), "human migration matrix covers acquisition and terminal gates")
	var v06_rulebook := _read_text(V06_RULEBOOK_PATH)
	_expect(v06_rulebook.contains("v0.6"), "current-production rulebook remains explicitly versioned V0.6")


func _validate_agents_precedence_and_conflicts() -> void:
	var agents := _read_text(AGENTS_PATH)
	_expect(agents.count(PRODUCTION_BEGIN) == 1 and agents.count(PRODUCTION_END) == 1, "AGENTS has one qualified current-production V0.6 boundary")
	_expect(agents.contains("## Rule Authority And Version Precedence"), "AGENTS declares rule precedence near the front")
	_expect(agents.contains("docs/rules/v07_game_constitution.json") and agents.contains("docs/rules/v07_game_constitution.md"), "AGENTS references both V0.7 constitution authorities")
	_expect(agents.contains("authoritative current-production V0.6 player rules"), "AGENTS scopes the V0.6 rulebook to current production")
	_expect(agents.contains("CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6") and agents.contains("FULL_V0_7_1_RUNTIME_CUTOVER=false"), "AGENTS separates current runtime from the V0.7.1 target constitution")
	var begin_index := agents.find(PRODUCTION_BEGIN)
	var end_index := agents.find(PRODUCTION_END)
	_expect(begin_index >= 0 and end_index > begin_index, "AGENTS production markers are ordered")
	var target_scope := agents
	if begin_index >= 0 and end_index > begin_index:
		target_scope = agents.substr(0, begin_index) + agents.substr(end_index + PRODUCTION_END.length())
	var target_authority_texts := [target_scope, _read_text(CONSTITUTION_MD_PATH), _read_text(PRECEDENCE_PATH)]
	var constitution := _read_json(CONSTITUTION_PATH)
	for rule_variant in constitution.get("constitutional_rules", []):
		if rule_variant is Dictionary:
			var rule: Dictionary = rule_variant
			target_authority_texts.append("%s %s" % [str(rule.get("statement", "")), JSON.stringify(rule.get("value"))])
	var delta := _read_json(DELTA_PATH)
	for entry_variant in delta.get("entries", []):
		if entry_variant is Dictionary:
			target_authority_texts.append(str((entry_variant as Dictionary).get("v07_rule", "")))
	var normalized_target_scope := "\n".join(target_authority_texts).to_lower()
	var stale_positive_claims := [
		"preserve this loop unless the user explicitly changes it",
		"players browse region-specific ordinary-card racks",
		"every region's current ordinary-card rack is public",
		"purchase eligibility is derived from the listing's authoritative source region",
		"live monsters in or adjacent to that source raise its price",
		"gdp drives the long horizon",
		"gdp baseline determines track supply",
		"gdp rank controls track visibility",
		"separate commodity track=true",
		"separate normal card track=true",
		"continuous mana recovery=true",
		"mana pool cap=100",
		"mana cap is 100",
		"purchased normal cards enter the hand",
		"purchased normal card enters the hand",
		"normal hand limit can increase above five",
		"submission capacity can increase above five",
		"normal card auto merge=true",
		"commodity auto merge=true",
		"normal cards automatically merge",
		"commodity cards automatically merge",
		"l3+l1->l4",
		"commodity maximum level=l4",
		"interactive counter window=true",
		"counter stack remains active",
		"whole player queue resolves contiguously",
		"player's entire queue resolves before the next player",
		"immediate final settlement on victory qualification",
		"original end condition immediately ends the game",
		"region popup normal card purchase=true",
		"## v0.7 commodity semantic constitution",
	]
	_conflicting_unqualified_v06_target_rule_count = 0
	for claim in stale_positive_claims:
		_conflicting_unqualified_v06_target_rule_count += normalized_target_scope.count(claim)
	_expect(_conflicting_unqualified_v06_target_rule_count == 0, "unqualified V0.6 target-rule conflict count is zero")


func _rule_value(rule_index: Dictionary, rule_id: String) -> Variant:
	_expect(rule_index.has(rule_id), "%s exists" % rule_id)
	var rule: Dictionary = rule_index.get(rule_id, {}) if rule_index.get(rule_id, {}) is Dictionary else {}
	return rule.get("value")


func _default_value(default_index: Dictionary, default_id: String) -> Variant:
	_expect(default_index.has(default_id), "%s exists" % default_id)
	var entry: Dictionary = default_index.get(default_id, {}) if default_index.get(default_id, {}) is Dictionary else {}
	return entry.get("value")


func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	var actual_keys: Array[String] = []
	for key in value.keys():
		actual_keys.append(str(key))
	actual_keys.sort()
	var expected_keys: Array[String] = []
	for key in expected:
		expected_keys.append(str(key))
	expected_keys.sort()
	return actual_keys == expected_keys


func _unique_string_count(values: Array) -> int:
	var unique: Dictionary = {}
	for value in values:
		unique[str(value)] = true
	return unique.size()


func _all_nonempty_strings(values: Array) -> bool:
	for value in values:
		if not (value is String) or str(value).is_empty():
			return false
	return not values.is_empty()


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("V07_CONSTITUTION_CONTRACT_TEST|status=PASS|checks=%d|failures=0|constitutional_rules=%d|balance_defaults=%d|inherited=%d|retired=%d|delta_entries=%d|conflicting_unqualified_v06_target_rules=%d" % [_checks, _constitutional_rule_count, _balance_default_count, _inherited_rule_count, _retired_rule_count, _delta_entry_count, _conflicting_unqualified_v06_target_rule_count])
		quit(0)
		return
	print("V07_CONSTITUTION_CONTRACT_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
