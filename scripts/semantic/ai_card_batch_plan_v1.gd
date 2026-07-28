@tool
extends RefCounted
class_name AiCardBatchPlanV1

const PURE = preload("res://scripts/semantic/card_batch_pure_data.gd")
const OBSERVATION = preload("res://scripts/semantic/ai_card_batch_observation_v1.gd")
const SUBMISSION = preload("res://scripts/semantic/card_batch_submission_v1.gd")
const TARGET = preload("res://scripts/semantic/card_batch_prebound_target_spec_v1.gd")

const SCHEMA_VERSION := 1
const RULESET_ID := "V0.7_REFERENCE_ONLY"
const STATUS_SUBMISSION_DRAFT_READY := "SUBMISSION_DRAFT_READY"
const STATUS_NO_LEGAL_SUBMISSION := "NO_LEGAL_SUBMISSION"
const STATUS_GAMEPLAY_INPUT_DISABLED := "GAMEPLAY_INPUT_DISABLED"
const STATUSES: Array[String] = [
	STATUS_SUBMISSION_DRAFT_READY,
	STATUS_NO_LEGAL_SUBMISSION,
	STATUS_GAMEPLAY_INPUT_DISABLED,
]
const LOCK_TIMING_IMMEDIATE := "IMMEDIATE_WITHIN_WINDOW"
const LOCK_TIMING_NONE := "NONE"
const FIELDS: Array[String] = [
	"schema_version",
	"ruleset_id",
	"decision_id",
	"observation_id",
	"observation_fingerprint",
	"viewer_actor_id",
	"phase",
	"decision_status",
	"lock_timing_id",
	"lock_remaining_phase_time_usec",
	"requested_window_id",
	"selected_source_pool",
	"selected_card_instance_id",
	"selected_target_binding_fingerprint",
	"submission_draft",
	"gameplay_intents",
	"rng_consumption_count",
	"decision_fingerprint",
]


static func build(
	observation: Dictionary,
	decision_status: String,
	submission_draft: Dictionary = {},
	lock_remaining_phase_time_usec: int = 0
) -> Dictionary:
	if not bool(OBSERVATION.validate(observation).get("valid", false)):
		return {}
	if decision_status not in STATUSES:
		return {}
	var selected_source_pool := ""
	var selected_card_instance_id := ""
	var selected_target_fingerprint := ""
	if not submission_draft.is_empty():
		selected_source_pool = str(submission_draft.get("source_pool", ""))
		selected_card_instance_id = str(submission_draft.get("card_instance_id", ""))
		selected_target_fingerprint = TARGET.fingerprint(
			submission_draft.get("target_binding", {}) as Dictionary
		)
	var observation_fingerprint := str(
		observation.get("observation_fingerprint", "")
	)
	var decision_seed := {
		"observation_fingerprint": observation_fingerprint,
		"decision_status": decision_status,
		"submission_draft": submission_draft,
	}
	var plan := {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"decision_id": "ai-card-batch-decision:%s" % (
			PURE.stable_fingerprint(decision_seed).left(24)
		),
		"observation_id": str(observation.get("observation_id", "")),
		"observation_fingerprint": observation_fingerprint,
		"viewer_actor_id": str(observation.get("viewer_actor_id", "")),
		"phase": str(observation.get("phase", "")),
		"decision_status": decision_status,
		"lock_timing_id": (
			LOCK_TIMING_IMMEDIATE
			if decision_status == STATUS_SUBMISSION_DRAFT_READY
			else LOCK_TIMING_NONE
		),
		"lock_remaining_phase_time_usec": lock_remaining_phase_time_usec,
		"requested_window_id": (
			str(observation.get("window_id", ""))
			if decision_status == STATUS_SUBMISSION_DRAFT_READY
			else ""
		),
		"selected_source_pool": selected_source_pool,
		"selected_card_instance_id": selected_card_instance_id,
		"selected_target_binding_fingerprint": selected_target_fingerprint,
		"submission_draft": submission_draft.duplicate(true),
		"gameplay_intents": [],
		"rng_consumption_count": 0,
		"decision_fingerprint": "",
	}
	plan["decision_fingerprint"] = _fingerprint_without_field(
		plan,
		"decision_fingerprint"
	)
	return plan if bool(validate(plan, observation).get("valid", false)) else {}


static func validate(value: Dictionary, observation: Dictionary = {}) -> Dictionary:
	if not PURE.has_exact_keys(value, FIELDS):
		return _invalid("ai_card_batch_plan_fields_invalid")
	if int(value.get("schema_version", -1)) != SCHEMA_VERSION \
			or str(value.get("ruleset_id", "")) != RULESET_ID:
		return _invalid("ai_card_batch_plan_schema_invalid")
	if not PURE.is_pure_json_data(value) \
			or not PURE.first_forbidden_runtime_key(value).is_empty() \
			or not PURE.first_retired_counter_key(value).is_empty():
		return _invalid("ai_card_batch_plan_not_closed_data")
	if str(value.get("decision_status", "")) not in STATUSES:
		return _invalid("ai_card_batch_plan_status_invalid")
	if str(value.get("decision_id", "")).is_empty() \
			or str(value.get("observation_id", "")).is_empty() \
			or str(value.get("observation_fingerprint", "")).is_empty() \
			or str(value.get("viewer_actor_id", "")).is_empty():
		return _invalid("ai_card_batch_plan_identity_invalid")
	if str(value.get("phase", "")) not in OBSERVATION.PHASES:
		return _invalid("ai_card_batch_plan_phase_invalid")
	if not (value.get("submission_draft") is Dictionary) \
			or not (value.get("gameplay_intents") is Array):
		return _invalid("ai_card_batch_plan_payload_invalid")
	if not (value.get("gameplay_intents", []) as Array).is_empty():
		return _invalid("ai_card_batch_plan_bypasses_shared_submission")
	if int(value.get("rng_consumption_count", -1)) != 0:
		return _invalid("ai_card_batch_plan_rng_consumption_invalid")
	var status := str(value.get("decision_status", ""))
	var submission := value.get("submission_draft", {}) as Dictionary
	if status == STATUS_SUBMISSION_DRAFT_READY:
		if str(value.get("phase", "")) != OBSERVATION.PHASE_CARD_WINDOW_OPEN:
			return _invalid("ai_card_batch_plan_draft_outside_window")
		if str(value.get("lock_timing_id", "")) != LOCK_TIMING_IMMEDIATE \
				or int(value.get("lock_remaining_phase_time_usec", -1)) < 0 \
				or int(value.get("lock_remaining_phase_time_usec", 0)) \
					> OBSERVATION.WINDOW_DURATION_USEC:
			return _invalid("ai_card_batch_plan_lock_timing_invalid")
		if not bool(SUBMISSION.validate(submission, false).get("valid", false)) \
				or not str(submission.get("locked_at_window_id", "")).is_empty():
			return _invalid("ai_card_batch_plan_submission_invalid")
		if str(submission.get("actor_id", "")) != str(value.get("viewer_actor_id", "")):
			return _invalid("ai_card_batch_plan_actor_binding_invalid")
		if str(value.get("selected_source_pool", "")) \
				!= str(submission.get("source_pool", "")) \
				or str(value.get("selected_card_instance_id", "")) \
				!= str(submission.get("card_instance_id", "")) \
				or str(value.get("selected_target_binding_fingerprint", "")) \
				!= TARGET.fingerprint(submission.get("target_binding", {})):
			return _invalid("ai_card_batch_plan_selection_binding_invalid")
	else:
		if not submission.is_empty() \
				or str(value.get("lock_timing_id", "")) != LOCK_TIMING_NONE \
				or int(value.get("lock_remaining_phase_time_usec", -1)) != 0 \
				or not str(value.get("requested_window_id", "")).is_empty() \
				or not str(value.get("selected_source_pool", "")).is_empty() \
				or not str(value.get("selected_card_instance_id", "")).is_empty() \
				or not str(value.get("selected_target_binding_fingerprint", "")).is_empty():
			return _invalid("ai_card_batch_plan_empty_decision_payload_invalid")
		if status == STATUS_GAMEPLAY_INPUT_DISABLED \
				and str(value.get("phase", "")) == OBSERVATION.PHASE_CARD_WINDOW_OPEN:
			return _invalid("ai_card_batch_plan_open_window_disabled_invalid")
		if status == STATUS_NO_LEGAL_SUBMISSION \
				and str(value.get("phase", "")) != OBSERVATION.PHASE_CARD_WINDOW_OPEN:
			return _invalid("ai_card_batch_plan_no_candidate_phase_invalid")
	if not observation.is_empty():
		if not bool(OBSERVATION.validate(observation).get("valid", false)):
			return _invalid("ai_card_batch_plan_observation_invalid")
		for field in [
			"observation_id",
			"observation_fingerprint",
			"viewer_actor_id",
			"phase",
		]:
			if value.get(field) != observation.get(field):
				return _invalid("ai_card_batch_plan_observation_binding_invalid")
		if status == STATUS_SUBMISSION_DRAFT_READY:
			if str(value.get("requested_window_id", "")) \
					!= str(observation.get("window_id", "")):
				return _invalid("ai_card_batch_plan_window_binding_invalid")
			if not _submission_matches_observation_candidate(submission, observation):
				return _invalid("ai_card_batch_plan_candidate_binding_invalid")
	var expected_decision_seed := {
		"observation_fingerprint": str(value.get("observation_fingerprint", "")),
		"decision_status": status,
		"submission_draft": submission,
	}
	if str(value.get("decision_id", "")) != "ai-card-batch-decision:%s" % (
		PURE.stable_fingerprint(expected_decision_seed).left(24)
	):
		return _invalid("ai_card_batch_plan_decision_id_invalid")
	if str(value.get("decision_fingerprint", "")) \
			!= _fingerprint_without_field(value, "decision_fingerprint"):
		return _invalid("ai_card_batch_plan_fingerprint_invalid")
	return {
		"valid": true,
		"reason_code": "ai_card_batch_plan_valid",
		"normalized": value.duplicate(true),
	}


static func _submission_matches_observation_candidate(
	submission: Dictionary,
	observation: Dictionary
) -> bool:
	for candidate_variant in observation.get("legal_candidates", []) as Array:
		if not (candidate_variant is Dictionary):
			continue
		var candidate := candidate_variant as Dictionary
		if str(submission.get("card_instance_id", "")) \
				!= str(candidate.get("card_instance_id", "")) \
				or str(submission.get("card_semantic_id", "")) \
				!= str(candidate.get("card_semantic_id", "")) \
				or str(submission.get("source_pool", "")) \
				!= str(candidate.get("source_pool", "")) \
				or int(submission.get("source_revision", -1)) \
				!= int(candidate.get("source_revision", -1)) \
				or str(submission.get("action_class", "")) \
				!= str(candidate.get("action_class", "")) \
				or int(submission.get("order_priority", 0)) \
				!= int(candidate.get("order_priority", 0)) \
				or int(submission.get("submission_sequence", -1)) \
				!= int(candidate.get("submission_sequence", -1)) \
				or int(submission.get("actor_seat_index", -1)) \
				!= int(observation.get("viewer_seat_index", -1)):
			continue
		var target_fingerprint := TARGET.fingerprint(
			submission.get("target_binding", {}) as Dictionary
		)
		for option_variant in candidate.get("legal_target_options", []) as Array:
			if option_variant is Dictionary \
					and TARGET.fingerprint(
						(option_variant as Dictionary).get("target_binding", {}) as Dictionary
					) == target_fingerprint:
				return true
	return false


static func _fingerprint_without_field(value: Dictionary, field: String) -> String:
	var copy := value.duplicate(true)
	copy[field] = ""
	return PURE.stable_fingerprint(copy)


static func _invalid(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code, "normalized": {}}
