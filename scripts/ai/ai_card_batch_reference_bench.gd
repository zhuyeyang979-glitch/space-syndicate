@tool
extends Node
class_name AiCardBatchReferenceBench

const OBSERVATION = preload("res://scripts/semantic/ai_card_batch_observation_v1.gd")
const PLAN = preload("res://scripts/semantic/ai_card_batch_plan_v1.gd")
const TARGET = preload("res://scripts/semantic/card_batch_prebound_target_spec_v1.gd")
const SUBMISSION = preload("res://scripts/semantic/card_batch_submission_v1.gd")
const INVENTORY = preload("res://scripts/semantic/card_batch_inventory_state_v1.gd")
const PLANNER = preload("res://scripts/ai/ai_card_batch_planner_v1.gd")

@export var auto_run := true

@onready var _source_owner := (
	$ObservationSourceOwner as AiCardBatchObservationSourceOwner
)

var _snapshot: Dictionary = {}


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_reference_bench")


func run_reference_bench() -> Dictionary:
	var planner := PLANNER.new() as AiCardBatchPlannerV1
	if not _source_owner.configure_authorized_actor("ai.player.2", 2, 23):
		return {"passed": false, "reason_code": "ai_card_batch_authorization_failed"}
	var open_observation := _source_owner.issue_observation(
		_fixture_source(OBSERVATION.PHASE_CARD_WINDOW_OPEN, true)
	)
	var open_plan := planner.plan_submission_draft(open_observation)
	var resolution_observation := _source_owner.issue_observation(
		_fixture_source("CARD_RESOLUTION_ACTIVE", false)
	)
	var resolution_plan := planner.plan_submission_draft(resolution_observation)
	var submission_draft := open_plan.get("submission_draft", {}) as Dictionary
	var passed := (
		bool(OBSERVATION.validate(open_observation).get("valid", false))
		and bool(PLAN.validate(open_plan, open_observation).get("valid", false))
		and bool(SUBMISSION.validate(submission_draft, false).get("valid", false))
		and str(submission_draft.get("locked_at_window_id", "")).is_empty()
		and str(submission_draft.get("action_class", "")) == "proactive_defense"
		and str(open_plan.get("decision_status", "")) == PLAN.STATUS_SUBMISSION_DRAFT_READY
		and str(resolution_plan.get("decision_status", ""))
			== PLAN.STATUS_GAMEPLAY_INPUT_DISABLED
		and (resolution_plan.get("submission_draft", {}) as Dictionary).is_empty()
		and (resolution_plan.get("gameplay_intents", []) as Array).is_empty()
		and int(open_plan.get("rng_consumption_count", -1)) == 0
		and int(resolution_plan.get("rng_consumption_count", -1)) == 0
	)
	_snapshot = {
		"passed": passed,
		"ruleset_id": OBSERVATION.RULESET_ID,
		"production_cutover": false,
		"open_decision_status": str(open_plan.get("decision_status", "")),
		"selected_action_class": str(submission_draft.get("action_class", "")),
		"selected_source_pool": str(submission_draft.get("source_pool", "")),
		"prebound_target_ids": (
			submission_draft.get("target_binding", {}) as Dictionary
		).get("target_ids", []),
		"resolution_decision_status": str(
			resolution_plan.get("decision_status", "")
		),
		"resolution_submission_count": (
			0
			if (resolution_plan.get("submission_draft", {}) as Dictionary).is_empty()
			else 1
		),
		"resolution_gameplay_intent_count": (
			resolution_plan.get("gameplay_intents", []) as Array
		).size(),
		"rng_consumption_count": (
			int(open_plan.get("rng_consumption_count", 0))
			+ int(resolution_plan.get("rng_consumption_count", 0))
		),
		"counter_window_count": 0,
		"counter_stack_depth": 0,
		"observation_owner_audit": _source_owner.debug_snapshot(),
	}
	print(
		"AI_CARD_BATCH_REFERENCE_BENCH=%s snapshot=%s" % [
			"PASS" if passed else "FAIL",
			JSON.stringify(_snapshot),
		]
	)
	return _snapshot.duplicate(true)


func debug_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func _fixture_source(phase: String, include_candidate: bool) -> Dictionary:
	var inventory := INVENTORY.empty("ai.player.2")
	inventory["normal_cards"] = [{
		"card_instance_id": "card.ai.2.defense.1",
		"card_semantic_id": "v07.card.proactive-shield",
		"source_revision": 23,
	}]
	var candidates: Array = []
	if include_candidate:
		candidates.append({
			"card_instance_id": "card.ai.2.defense.1",
			"card_semantic_id": "v07.card.proactive-shield",
			"source_pool": "normal_hand",
			"source_revision": 23,
			"action_class": "proactive_defense",
			"order_priority": 10,
			"submission_sequence": 0,
			"base_utility": 2,
			"urgency": 3,
			"legal_target_options": [{
				"visibility_scope_id": "actor_private",
				"target_binding": TARGET.build(
					"facility",
					["facility.ai.player.2.alpha"],
					12,
					"shield-slot.1",
					"protect",
					1,
					{"defense_kind": "shield"}
				),
				"target_value": 3,
				"threat_level": 8,
				"synergy_value": 2,
			}],
		})
	var receipts: Array = []
	if not include_candidate:
		receipts.append({
			"receipt_id": "card-resolution-receipt.public.1",
			"result_kind": "defense_applied",
			"public_target_ids": ["facility.public.alpha"],
			"outcome_code": "damage_reduced",
			"batch_revision": 11,
		})
	return {
		"schema_version": OBSERVATION.SCHEMA_VERSION,
		"ruleset_id": OBSERVATION.RULESET_ID,
		"viewer_actor_id": "ai.player.2",
		"viewer_seat_index": 2,
		"visibility_scope_id": OBSERVATION.VISIBILITY_SCOPE_ID,
		"batch_id": "card-batch.4",
		"batch_revision": 11,
		"window_id": "card-window.7",
		"window_remaining_phase_time_usec": 18_000_000 if include_candidate else 0,
		"source_revision": 23,
		"phase": phase,
		"own_inventory": inventory if include_candidate else {},
		"legal_candidates": candidates,
		"public_resolution_receipts": receipts,
	}
