extends SceneTree

const CONSTITUTION_PATH := "res://docs/rules/v073_game_constitution.json"
const CONSTITUTION_MD_PATH := "res://docs/rules/v073_game_constitution.md"
const PRECEDENCE_PATH := "res://docs/rules/v073_rule_precedence.md"
const AGENTS_PATH := "res://AGENTS.md"

const HISTORICAL_FILES := {
	"res://docs/rules/v07_game_constitution.json": "81c8ae27eba50f4d68c8a379913baf0592a819412bca0109f7e5fc9ef9a5a5fc",
	"res://docs/rules/v07_game_constitution.md": "a0d2e4324898134bdc3a58cc232ce05e5ca39b8787549b8a55a6ab50f28abb72",
	"res://docs/rules/v07_balance_defaults.json": "8678cfa88eeff53f60b2e209598e670e2748189c3bb3bd0ebd21bf5c5e20c6f8",
	"res://docs/rules/v071_game_constitution.json": "a5a52a88bc5a139dc56accc46897c82ddc7c3ea1aacdcaa6f72a412815429473",
	"res://docs/rules/v071_game_constitution.md": "2b4822b915d46f575ad9f1ff4675bc3741c91a70cf19b4f56fc8f37ac9bed930",
	"res://docs/rules/v071_balance_defaults.json": "4ef853a914dafc4919848e2f28da824cb4b710058556c2013fd4cdcddc5d555a",
	"res://docs/rules/v072_game_constitution.json": "d6e93f053e961e6adf1a1410d9343fe9bccd315f429819ef59d75c2ecd6d7a33",
	"res://docs/rules/v072_game_constitution.md": "1e557e3cc3d00bcbe83f671275d90a5a3e829f7e73245f5e0cf818dd323c1304",
	"res://docs/rules/v072_balance_defaults.json": "91a9ee9bdc796013e4ac64d2ce9893267f65ce285b22551963371be610d67155",
	"res://docs/rules/v072_amendment_from_v071.json": "91c1fd7d3025b84b566c5beb023e596a90715ec03efe3e85899c6ca7f7a01195",
	"res://docs/rules/v072_amendment_from_v071.md": "9604d2a6d7d3a8e1f20da806054c9e73bb5f30363a484fefd1065c9e0504ec79",
	"res://docs/rules/v072_rule_precedence.md": "82908f46e882459fe732932258be19f9be506bc32a4a058f2eb8b156bc2139f5",
}

const AUTHORITY_PRECEDENCE := [
	"latest_explicit_user_rule_decision",
	"docs/rules/v073_game_constitution.json",
	"docs/rules/v073_game_constitution.md",
	"docs/rules/v072_game_constitution.json",
	"docs/rules/v072_game_constitution.md",
	"docs/rules/v071_game_constitution.json",
	"docs/rules/v071_game_constitution.md",
	"docs/rules/v07_game_constitution.json",
	"docs/rules/v07_game_constitution.md",
	"docs/tabletop_rulebook_v06.md_current_production_only",
	"older_rule_documents",
	"older_test_oracles",
	"older_code_behavior",
]

const AMENDMENT_RULE_IDS := [
	"v073.resolution.auction_rejected",
	"v073.resolution.fixed_hidden_round_robin",
	"v073.facility.prebound_unique_slot_modes",
	"v073.facility.authoritative_revalidation_no_conversion",
	"v073.facility.contention_fizzle_privacy_and_persistence",
]

const RULE_FIELDS := ["rule_id", "domain", "value", "supersedes", "statement"]
const MODES := ["BUILD_NEW", "UPGRADE_OWN", "REPAIR_OWN"]
const BID_SAVE_FIELDS := [
	"initiative_bid",
	"bid_cash",
	"bid_reservation",
	"bid_rank",
	"bid_histogram",
	"auction_status",
	"auction_receipt",
	"public_tiebreak_cursor",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var constitution := _read_json(CONSTITUTION_PATH)
	_expect(not constitution.is_empty(), "V0.7.3 constitution parses")
	_expect(str(constitution.get("constitution_id", "")) == "space_syndicate.v073.complete", "constitution ID is exact")
	_expect(str(constitution.get("ruleset_id", "")) == "v0.7.3", "ruleset ID is exact")
	_expect(str(constitution.get("status", "")) == "frozen_highest_target_constitution", "constitution is frozen highest target")
	_expect(str(constitution.get("current_production_ruleset", "")) == "v0.6", "production remains V0.6")
	_expect(str(constitution.get("target_development_ruleset", "")) == "v0.7.3", "target is V0.7.3")
	_expect(constitution.get("authority_precedence", []) == AUTHORITY_PRECEDENCE, "authority precedence is closed and exact")

	_test_approval(constitution)
	var by_id := _test_inheritance_and_rules(constitution)
	_test_auction_absence(constitution, by_id)
	_test_fixed_round_robin(by_id)
	_test_facility_modes(by_id)
	_test_revalidation(by_id)
	_test_contention_fizzle(constitution, by_id)
	_test_save_ai_rng_and_cutover(constitution)
	_test_history_and_human_authority(constitution)
	_finish()


func _test_approval(constitution: Dictionary) -> void:
	var approval: Dictionary = constitution.get("approval", {})
	_expect(bool(approval.get("approved", false)), "V0.7.3 decision is approved")
	_expect(bool(approval.get("user_rejects_resolution_order_auction", false)), "resolution-order auction rejection is explicit")
	_expect(bool(approval.get("user_rejects_initiative_cash_bidding", false)), "initiative cash-bidding rejection is explicit")
	_expect(bool(approval.get("user_approves_fixed_round_robin_resolution", false)), "fixed round robin is approved")
	_expect(bool(approval.get("user_approves_prebound_facility_contention", false)), "prebound facility contention is approved")
	_expect(bool(approval.get("user_approves_facility_build_fizzle_on_slot_contention", false)), "contention Fizzle is approved")
	_expect((approval.get("decision_ids", []) as Array).size() == 5, "five explicit user decisions are closed")
	_expect(str(approval.get("approved_profile_id", "")) == "V073_STARTER_FREE_FIXED_ORDER_CONTENTION", "approved profile is exact")
	_expect(not bool(approval.get("human_fun_proven", true)) and bool(approval.get("human_test_required", false)), "freeze does not claim human fun")


func _test_inheritance_and_rules(constitution: Dictionary) -> Dictionary:
	var inheritance: Dictionary = constitution.get("inheritance", {})
	_expect(str(inheritance.get("source_constitution_id", "")) == "space_syndicate.v072.complete", "V0.7.3 inherits V0.7.2")
	_expect(str(inheritance.get("source_sha256", "")) == HISTORICAL_FILES["res://docs/rules/v072_game_constitution.json"], "inheritance pins the V0.7.2 blob")
	_expect(int(inheritance.get("inherited_constitutional_rule_count", 0)) == 92, "all 92 V0.7.2 effective rules are inherited")
	_expect(int(inheritance.get("v073_amendment_rule_count", 0)) == 5, "five V0.7.3 amendment rules are composed")
	_expect(int(inheritance.get("effective_constitutional_rule_count", 0)) == 97, "effective rule count is explicit")
	_expect(constitution.get("structural_amendment_rule_ids", []) == AMENDMENT_RULE_IDS, "amendment rule IDs are ordered and exact")

	var rules: Array = constitution.get("constitutional_rules", [])
	_expect(rules.size() == 5, "five V0.7.3 rule objects are present")
	var by_id: Dictionary = {}
	for rule_variant in rules:
		_expect(rule_variant is Dictionary, "every amendment rule is an object")
		if not (rule_variant is Dictionary):
			continue
		var rule := rule_variant as Dictionary
		var rule_id := str(rule.get("rule_id", ""))
		_expect(_exact_fields(rule, RULE_FIELDS), "%s has the closed rule shape" % rule_id)
		_expect(rule_id.begins_with("v073.") and not by_id.has(rule_id), "%s is unique" % rule_id)
		by_id[rule_id] = rule
		_expect(not str(rule.get("domain", "")).is_empty(), "%s has a domain" % rule_id)
		_expect(rule.get("value", null) is Dictionary and not (rule.get("value", {}) as Dictionary).is_empty(), "%s has a closed value" % rule_id)
		_expect(rule.get("supersedes", null) is Array and not (rule.get("supersedes", []) as Array).is_empty(), "%s names superseded interpretation" % rule_id)
		_expect(not str(rule.get("statement", "")).is_empty(), "%s has a statement" % rule_id)
	for rule_id in AMENDMENT_RULE_IDS:
		_expect(by_id.has(rule_id), "%s is frozen" % rule_id)
	return by_id


func _test_auction_absence(constitution: Dictionary, by_id: Dictionary) -> void:
	var auction: Dictionary = (by_id.get("v073.resolution.auction_rejected", {}) as Dictionary).get("value", {})
	for field in ["initiative_auction_enabled", "resolution_order_bidding_enabled", "cash_can_change_resolution_order"]:
		_expect(not bool(auction.get(field, true)), "%s is false" % field)
	for field in [
		"resolution_order_modifier_count",
		"initiative_auction_core_count",
		"initiative_bid_intent_count",
		"initiative_bid_owner_count",
		"initiative_bid_save_field_count",
		"initiative_bid_ui_surface_count",
		"ai_initiative_bid_policy_count",
		"ai_resolution_order_purchase_action_count",
	]:
		_expect(int(auction.get(field, -1)) == 0, "%s is zero" % field)
	_expect(int(auction.get("resolution_order_writer_count", 0)) == 1, "there is exactly one resolution-order writer")
	_expect(auction.get("prohibited_save_fields", []) == BID_SAVE_FIELDS, "all bid Save fields are explicitly forbidden")
	_expect((auction.get("prohibited_runtime_types", []) as Array).size() == 5, "five auction runtime types are explicitly prohibited")
	_expect(str(auction.get("historical_proposal_status", "")) == "REJECTED_RULE_PROPOSAL", "historical auction proposal is rejected")
	_expect(not bool(auction.get("historical_proposal_runtime_authority", true)), "historical auction proposal has no runtime authority")

	var absence: Dictionary = constitution.get("auction_absence_contract", {})
	for field in [
		"initiative_auction_core_count",
		"initiative_bid_owner_count",
		"initiative_bid_intent_count",
		"initiative_bid_save_field_count",
		"initiative_bid_ui_surface_count",
		"ai_initiative_bid_policy_count",
	]:
		_expect(int(absence.get(field, -1)) == 0, "root auction absence keeps %s at zero" % field)
	_expect(not bool(absence.get("cash_can_change_resolution_order", true)), "root contract forbids cash order changes")


func _test_fixed_round_robin(by_id: Dictionary) -> void:
	var value: Dictionary = (by_id.get("v073.resolution.fixed_hidden_round_robin", {}) as Dictionary).get("value", {})
	_expect(str(value.get("resolution_order_mode", "")) == "fixed_hidden_round_robin", "resolution mode is exact")
	_expect(str(value.get("batch_resolution_order_source", "")) == "frozen_hidden_lead_order_at_batch_lock", "batch order has one frozen source")
	_expect(bool(value.get("frozen_batch_turn_order_created_at_batch_lock", false)), "batch turn order freezes at lock")
	_expect(int(value.get("resolution_order_writer_count", 0)) == 1 and int(value.get("resolution_order_modifier_count", -1)) == 0, "order has one writer and zero modifiers")
	_expect(not bool(value.get("resolution_order_mutation_after_batch_lock", true)), "order cannot mutate after lock")
	_expect(int(value.get("local_action_index_minimum", -1)) == 0 and int(value.get("local_action_index_maximum", -1)) == 4, "local action layers are zero through four")
	_expect(value.get("algorithm", []) == ["for_each_local_action_index_ascending", "for_each_player_in_frozen_batch_turn_order", "append_action_if_present"], "layered algorithm is exact")
	_expect(bool(value.get("player_local_order_preserved", false)) and bool(value.get("one_action_per_player_per_layer", false)), "local order is preserved with one action per player per layer")
	_expect(bool(value.get("empty_queue_skipped", false)) and bool(value.get("single_remaining_player_tail_continues", false)), "empty queues skip and lone tail continues")
	_expect(not bool(value.get("whole_player_queue_contiguous_before_next_player", true)), "whole player queues do not resolve contiguously")
	for field in [
		"cash_order_modifier_allowed",
		"six_color_asset_order_modifier_allowed",
		"card_order_modifier_allowed",
		"role_order_modifier_allowed",
		"organization_order_modifier_allowed",
		"facility_order_modifier_allowed",
		"market_lead_affected_by_bid",
		"track_order_affected_by_bid",
		"batch_order_affected_by_bid",
		"victory_macro_round_affected_by_bid",
		"public_initiative_tiebreak_order_created",
	]:
		_expect(not bool(value.get(field, true)), "%s is false" % field)
	_expect(value.get("typed_order_semantics", []) == ["MARKET_LEAD_WEIGHT", "TRACK_POSITION_ORDER", "BATCH_RESOLUTION_TURN_ORDER"], "typed order semantics remain separate")
	_expect(not bool(value.get("typed_order_reverse_inference_allowed", true)), "typed orders cannot reverse-own each other")
	var example: Dictionary = value.get("example", {})
	_expect(example.get("anonymous_global_queue", []) == ["A1", "B1", "C1", "D1", "A2", "B2", "D2", "A3", "D3", "D4"], "canonical four-player layering is exact")


func _test_facility_modes(by_id: Dictionary) -> void:
	var value: Dictionary = (by_id.get("v073.facility.prebound_unique_slot_modes", {}) as Dictionary).get("value", {})
	_expect(str(value.get("facility_slot_kind", "")) == "region_unique_facility_slot", "facility slot kind is unique")
	_expect(value.get("facility_slot_unique_key", []) == ["region_id", "facility_type", "industry_id"], "slot key is region/type/industry")
	_expect(bool(value.get("facility_action_mode_required", false)), "facility action mode is required")
	_expect(value.get("allowed_facility_action_modes", []) == MODES, "the three facility modes are closed and exact")
	_expect(not bool(value.get("facility_action_mode_mutable_after_lock", true)), "mode is immutable after lock")
	_expect(not bool(value.get("target_reselection_during_resolution", true)), "target cannot be reselected")
	_expect(str(value.get("inapplicable_field_encoding", "")) == "closed_none", "inapplicable fields use closed none")
	_expect(not bool(value.get("omitted_then_inferred_field_allowed", true)), "fields cannot be omitted then guessed")
	var required: Array = value.get("required_prebound_fields", [])
	for field in [
		"region_id", "region_revision", "facility_type", "industry_id", "target_slot_id",
		"target_slot_generation", "facility_action_mode", "expected_occupancy",
		"expected_facility_id", "expected_facility_generation", "expected_owner_id",
		"expected_rank", "expected_damage_revision",
	]:
		_expect(field in required, "facility prebind requires %s" % field)
	var requirements: Dictionary = value.get("submission_requirements", {})
	_expect(_exact_fields(requirements, MODES), "submission requirements contain exactly the three modes")
	_expect(str((requirements.get("BUILD_NEW", {}) as Dictionary).get("expected_occupancy", "")) == "empty", "BUILD requires empty occupancy")
	_expect(str((requirements.get("UPGRADE_OWN", {}) as Dictionary).get("expected_owner_id", "")) == "self", "UPGRADE requires self ownership")
	_expect(str((requirements.get("REPAIR_OWN", {}) as Dictionary).get("expected_owner_id", "")) == "self", "REPAIR requires self ownership")


func _test_revalidation(by_id: Dictionary) -> void:
	var value: Dictionary = (by_id.get("v073.facility.authoritative_revalidation_no_conversion", {}) as Dictionary).get("value", {})
	_expect(str(value.get("authoritative_revalidator", "")) == "region_infrastructure_owner", "infrastructure Owner performs final revalidation")
	_expect(not bool(value.get("viewer_snapshot_may_decide_final_legality", true)) and not bool(value.get("ui_may_decide_final_legality", true)), "UI and viewer snapshots cannot decide final legality")
	var revalidated: Array = value.get("revalidated_fields", [])
	for field in ["target_slot_id", "target_slot_generation", "occupancy", "facility_id", "facility_generation", "owner_id", "facility_action_mode", "rank", "damage_revision"]:
		_expect(field in revalidated, "authority revalidates %s" % field)
	var results: Array = value.get("typed_results", [])
	_expect(results.size() == 6, "six typed facility outcomes are closed")
	for result_id in [
		"facility_action_resolved",
		"facility_target_invalid_slot_occupied",
		"facility_target_invalid_generation_changed",
		"facility_target_invalid_owner_changed",
		"facility_target_invalid_rank_changed",
		"facility_target_invalid_damage_changed",
	]:
		_expect(result_id in results, "%s is a typed result" % result_id)
	for field in [
		"build_to_upgrade_auto_conversion",
		"build_to_repair_auto_conversion",
		"upgrade_to_repair_auto_conversion",
		"repair_to_upgrade_auto_conversion",
		"target_reselection_during_resolution",
		"different_region_fallback_allowed",
		"different_industry_fallback_allowed",
		"different_facility_type_fallback_allowed",
		"other_players_facility_fallback_allowed",
	]:
		_expect(not bool(value.get(field, true)), "%s is forbidden" % field)
	_expect(int(value.get("build_to_upgrade_auto_conversion_count", -1)) == 0, "BUILD-to-UPGRADE conversion count is zero")
	_expect(int(value.get("build_to_repair_auto_conversion_count", -1)) == 0, "BUILD-to-REPAIR conversion count is zero")


func _test_contention_fizzle(constitution: Dictionary, by_id: Dictionary) -> void:
	var value: Dictionary = (by_id.get("v073.facility.contention_fizzle_privacy_and_persistence", {}) as Dictionary).get("value", {})
	_expect(bool(value.get("build_slot_contention_fizzle", false)), "slot contention causes Fizzle")
	_expect(str(value.get("invalid_target_policy_id", "")) == "FIZZLE_FULL_ASSET_REFUND", "contention uses the inherited default Fizzle policy")
	_expect(not bool(value.get("target_reselected", true)), "contention never reselects a target")
	_expect(bool(value.get("asset_reservation_released", false)), "reserved assets are released")
	_expect(str(value.get("normal_card_destination", "")) == "discard", "normal card enters discard")
	_expect(not bool(value.get("action_slot_refunded", true)) and not bool(value.get("card_returned_to_hand", true)), "action slot and hand card are not returned")
	for field in ["facility_created", "facility_upgraded", "facility_repaired"]:
		_expect(not bool(value.get(field, true)), "%s remains false on Fizzle" % field)
	_expect(bool(value.get("starter_facility_uses_same_policy", false)), "Starter facility uses the same contention policy")
	_expect(int(value.get("starter_refund_asset_value", -1)) == 0 and str(value.get("starter_card_destination", "")) == "discard", "Starter releases zero and enters discard")
	_expect(not bool(value.get("starter_action_slot_refunded", true)), "Starter action slot is not refunded")
	_expect(int(value.get("initiative_cash_spent", -1)) == 0 and str(value.get("initiative_cash_refund", "")) == "not_applicable", "initiative cash is absent")
	_expect(bool(value.get("public_history_owner_anonymous", false)), "public contention history is anonymous")
	_expect(int(value.get("anonymous_owner_direct_disclosure_rate_required", -1)) == 0, "direct owner disclosure rate is zero")
	_expect((value.get("public_history_forbidden_fields", []) as Array).size() == 6, "six direct owner cues are forbidden")
	_expect(value.get("save_forbidden_fields", []) == BID_SAVE_FIELDS, "Fizzle Save explicitly forbids bid state")
	for field in [
		"restore_must_not_reorder_batch_players",
		"restore_must_not_reselect_target",
		"restore_must_not_convert_facility_mode",
		"restore_must_not_repeat_build",
		"restore_must_not_repeat_fizzle",
		"restore_must_not_repeat_asset_refund",
		"restore_must_not_repeat_card_discard",
	]:
		_expect(bool(value.get(field, false)), "%s is required" % field)
	_expect(not bool(value.get("v072_save_to_v073_direct_resume", true)), "V0.7.2 Save cannot silently resume")
	_expect(not bool(value.get("v06_save_to_v073_direct_resume", true)) and bool(value.get("v06_save_backup_required", false)), "V0.6 Save fails closed with backup")
	var ai_forbidden: Array = value.get("ai_forbidden_contention_inputs", [])
	for field in ["other_player_locked_facility_targets", "other_player_local_card_order", "other_player_hands", "complete_hidden_turn_order", "future_action_owner", "anonymous_queue_owner"]:
		_expect(field in ai_forbidden, "AI cannot read %s" % field)
	_expect(int(value.get("player_ui_auction_surface_count", -1)) == 0, "contention UI has zero auction surfaces")

	var privacy: Dictionary = constitution.get("ai_player_privacy_obligations", {})
	_expect(bool(privacy.get("public_queue_owner_anonymous", false)), "root privacy keeps the public queue anonymous")
	_expect(not bool(privacy.get("complete_hidden_order_public", true)) and not bool(privacy.get("other_player_targets_public", true)), "hidden order and rival targets stay private")
	_expect(not bool(privacy.get("owner_specific_animation_or_audio_allowed", true)), "animation and audio cannot leak owner")
	_expect(bool(privacy.get("ai_and_human_contention_information_parity", false)), "AI and human contention information is symmetric")


func _test_save_ai_rng_and_cutover(constitution: Dictionary) -> void:
	var save: Dictionary = constitution.get("save_obligations", {})
	_expect(bool(save.get("versioned_v073_schema_required", false)), "V0.7.3 Save schema must be versioned")
	_expect(not bool(save.get("v072_save_to_v073_direct_resume", true)), "V0.7.2 direct resume is forbidden")
	_expect(not bool(save.get("v06_save_to_v073_direct_resume", true)) and bool(save.get("v06_save_backup_required", false)), "V0.6 direct resume is forbidden with backup")
	_expect(not bool(save.get("silent_default_of_new_fields_allowed", true)), "new fields cannot silently default")
	for field in ["frozen_hidden_lead_order", "frozen_batch_turn_order", "player_local_queues", "local_action_index", "anonymous_global_queue", "resolution_cursor"]:
		_expect(field in save.get("required_batch_state", []), "Save requires %s" % field)
	for field in ["facility_action_mode", "target_slot_id", "target_slot_generation", "expected_occupancy", "expected_facility_id", "expected_facility_generation", "expected_owner_id", "expected_rank", "expected_damage_revision", "invalid_target_policy_id"]:
		_expect(field in save.get("required_facility_action_state", []), "Save requires %s" % field)
	for forbidden in BID_SAVE_FIELDS:
		_expect(forbidden not in save.get("required_batch_state", []) and forbidden not in save.get("required_facility_action_state", []), "Save does not require forbidden %s" % forbidden)
	_expect(int(save.get("forbidden_auction_state_count", -1)) == 0, "stored auction state count is zero")
	_expect(int(save.get("restore_rng_draw_delta", -1)) == 0, "restore advances RNG by zero")

	var rng: Dictionary = constitution.get("rng_obligations", {})
	_expect(int(rng.get("new_rng_stream_count", -1)) == 0, "V0.7.3 adds no RNG stream")
	_expect(int(rng.get("resolution_order_rng_stream_count", -1)) == 0 and int(rng.get("facility_contention_rng_stream_count", -1)) == 0, "order and contention add no RNG streams")
	_expect(not bool(rng.get("restore_rng_advance_allowed", true)), "restore RNG advance is forbidden")

	var detached: Dictionary = constitution.get("detached_implementation_obligations", {})
	_expect(str(detached.get("target_ruleset_id", "")) == "v0.7.3", "detached target is V0.7.3")
	_expect(int(detached.get("production_connection_count", -1)) == 0 and int(detached.get("v06_mutation_count", -1)) == 0 and int(detached.get("dual_write_count", -1)) == 0, "detached implementation has zero production connection, V0.6 mutation, and dual write")
	var atomic: Dictionary = constitution.get("atomic_cutover_obligations", {})
	_expect(atomic.get("domains", []) == ["card_batch", "anonymous_resolution", "region_infrastructure", "facility_target_contention"], "four contention domains form one atomic group")
	_expect(not bool(atomic.get("mixed_v06_v073_facility_interpretation_allowed", true)) and not bool(atomic.get("dual_write_allowed", true)), "mixed interpretation and dual write are forbidden")
	var cutover: Dictionary = constitution.get("cutover_obligations", {})
	_expect(bool(cutover.get("docs_only_freeze", false)), "this constitution lane is docs-only")
	_expect(not bool(cutover.get("production_cutover_allowed_by_this_task", true)), "docs freeze does not authorize production cutover")
	_expect(not bool(cutover.get("v073_full_runtime_cutover", true)) and not bool(cutover.get("v06_and_v073_dual_write_allowed", true)), "no V0.7.3 cutover or dual write occurred")


func _test_history_and_human_authority(constitution: Dictionary) -> void:
	for path in HISTORICAL_FILES:
		_expect(_file_sha256(path) == str(HISTORICAL_FILES[path]), "%s remains byte-identical" % path)
	var baselines: Dictionary = constitution.get("historical_baselines", {})
	for version in ["v07", "v071", "v072"]:
		var baseline: Dictionary = baselines.get(version, {})
		_expect(int(baseline.get("content_change_count", -1)) == 0, "%s historical content change count is zero" % version)
		_expect(bool(baseline.get("retained_as_immutable_history", false)), "%s remains immutable history" % version)

	var agents := FileAccess.get_file_as_string(AGENTS_PATH)
	_expect(agents.find("docs/rules/v073_game_constitution.json") < agents.find("docs/rules/v072_game_constitution.json"), "AGENTS places V0.7.3 before V0.7.2")
	_expect(agents.contains("HIGHEST_TARGET_RULE_AUTHORITY=V0.7.3_COMPLETE_CONSTITUTION"), "AGENTS names V0.7.3 highest authority")
	_expect(agents.contains("CURRENT_PLAYER_RUNTIME_RULE_AUTHORITY=V0.6_RULEBOOK"), "AGENTS retains V0.6 runtime authority")
	var human := FileAccess.get_file_as_string(CONSTITUTION_MD_PATH)
	for decision in [
		"USER_REJECTS_RESOLUTION_ORDER_AUCTION=true",
		"USER_REJECTS_INITIATIVE_CASH_BIDDING=true",
		"USER_APPROVES_FIXED_ROUND_ROBIN_RESOLUTION=true",
		"USER_APPROVES_PREBOUND_FACILITY_CONTENTION=true",
		"USER_APPROVES_FACILITY_BUILD_FIZZLE_ON_SLOT_CONTENTION=true",
	]:
		_expect(human.contains(decision), "human constitution records %s" % decision)
	_expect(human.contains("HUMAN_FUN_PROVEN=false") and human.contains("FULL_V0_7_3_RUNTIME_CUTOVER=false"), "human constitution preserves freeze boundaries")
	var precedence := FileAccess.get_file_as_string(PRECEDENCE_PATH)
	_expect(precedence.contains("HIGHEST_TARGET_RULE_AUTHORITY=V0.7.3_COMPLETE_CONSTITUTION"), "precedence companion names V0.7.3")


func _exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _file_sha256(path: String) -> String:
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if hashing.update(FileAccess.get_file_as_bytes(path)) != OK:
		return ""
	return hashing.finish().hex_encode().to_lower()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var passed := _failures.is_empty()
	print("V073_CONSTITUTION_CONTRACT_TEST|status=%s|checks=%d|failures=%d|amendment_rule_count=5|resolution_order_writer_count=1|initiative_auction_core_count=0|initiative_bid_save_field_count=0|initiative_bid_ui_surface_count=0|ai_initiative_bid_policy_count=0|v072_historical_change_count=0|human_fun_proven=false|details=%s" % [
		"PASS" if passed else "FAIL", _checks, _failures.size(), JSON.stringify(_failures)
	])
	quit(0 if passed else 1)
