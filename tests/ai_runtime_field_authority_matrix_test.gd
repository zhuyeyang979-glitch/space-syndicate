extends SceneTree

const MATRIX_PATH := "res://docs/save/alpha04c_ai_save_field_authority_matrix.json"
const CHARACTERIZATION_PATH := "res://reports/handoffs/alpha04c_ai_runtime_full_state_pre_v3_characterization.json"
const AUTHORITY_CLASSES := [
	"persisted_authority",
	"runtime_checkpoint_authority",
	"derived_post_restore_state",
]
const SAVE_FIELDS := [
	"schema_version", "ruleset_id", "policy_profile_id", "policy_fingerprint",
	"request_sequence", "ai_card_decision_timer", "ai_auction_reaction_timer",
	"ai_intel_decision_timer", "ai_card_decision_enabled", "player_index",
]
const PROFILE_FIELDS := [
	"profile_index", "name", "style", "build_bias", "business_bias",
	"monster_bias", "economy_bias", "bid_aggression", "exploration",
	"route_preferences",
]
const MEMORY_FIELDS := [
	"decision_samples", "action_counts", "last_plan",
	"economic_focus_product", "economic_focus_score", "economic_focus_reason",
	"economic_focus_cycle", "economic_focus_rankings", "strategic_intent",
	"strategic_intent_score", "strategic_intent_reason", "strategic_intent_cycle",
	"strategic_intent_rankings", "route_plan_product", "route_plan_stage",
	"route_plan_score", "route_plan_reason", "route_plan_cycle",
	"route_plan_target_city", "route_plan_partner_district", "route_plan_rankings",
	"game_phase", "competitive_posture", "score_gap_to_leader", "leader_index",
	"phase_reason", "learned_policy_values", "learning_updates",
	"learning_last_reward", "learning_last_tags", "episode_learning_updates",
	"episode_last_reward", "episode_last_top_n_gdp",
	"episode_last_controlled_regions", "episode_last_rank", "episode_last_result",
	"training_note",
]
const CHECKPOINT_FIELDS := [
	"save_state", "last_receipts", "card_target_pre_submit_rejection_count",
	"tick_timing_count", "tick_timing_total_usec", "tick_timing_max_usec",
	"actor_state_tick_cache", "actor_state_tick_cache_active",
	"actor_state_tick_cache_hit_count", "actor_state_tick_cache_miss_count",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MATRIX_PATH))
	_expect(parsed is Dictionary, "matrix_json_parses")
	var matrix: Dictionary = parsed if parsed is Dictionary else {}
	_expect(bool(matrix.get("field_authority_matrix_complete", false)), "matrix_marked_complete")
	_expect(int(matrix.get("unclassified_ai_save_field_count", -1)) == 0, "matrix_has_no_unclassified_field")
	_expect(bool(matrix.get("private_payload_redacted", false)), "matrix_private_payload_redacted")
	_expect(str(matrix.get("characterization_sha256", "")) == FileAccess.get_sha256(CHARACTERIZATION_PATH).to_lower(), "matrix_binds_current_redacted_characterization")
	var rows: Array = matrix.get("fields", []) if matrix.get("fields", []) is Array else []
	var covered: Dictionary = {}
	var classes_valid := not rows.is_empty()
	for row_variant in rows:
		if not (row_variant is Dictionary):
			classes_valid = false
			continue
		var row := row_variant as Dictionary
		classes_valid = classes_valid and str(row.get("authority_class", "")) in AUTHORITY_CLASSES
		classes_valid = classes_valid and row.get("writer_methods") is Array \
				and not (row.get("writer_methods") as Array).is_empty()
		classes_valid = classes_valid and row.get("reader_methods") is Array \
				and not (row.get("reader_methods") as Array).is_empty()
		classes_valid = classes_valid and not str(row.get("restore_policy", "")).is_empty()
		for field_variant in row.get("covered_fields", []) as Array:
			covered[str(field_variant)] = true
	_expect(classes_valid, "every_matrix_row_has_writer_reader_class_and_restore_policy")
	var required := SAVE_FIELDS + PROFILE_FIELDS + MEMORY_FIELDS + CHECKPOINT_FIELDS
	var missing: Array[String] = []
	for field in required:
		if not covered.has(field):
			missing.append(field)
	_expect(missing.is_empty(), "all_save_profile_memory_and_checkpoint_fields_classified:%s" % ",".join(missing))
	var audit: Dictionary = matrix.get("consumer_audit", {}) \
			if matrix.get("consumer_audit", {}) is Dictionary else {}
	_expect(int(audit.get("actor_tick_cache_exact_once_reader_count_across_save_barrier", -1)) == 0, "tick_cache_has_no_exact_once_cross_barrier_reader")
	_expect(int(audit.get("last_receipts_gameplay_reader_count", -1)) == 0 \
			and int(audit.get("last_receipts_exact_once_reader_count", -1)) == 0, "last_receipts_not_gameplay_or_exact_once_authority")
	print("AI_RUNTIME_FIELD_AUTHORITY_MATRIX_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
