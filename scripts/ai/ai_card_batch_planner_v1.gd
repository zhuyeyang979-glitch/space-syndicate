@tool
extends RefCounted
class_name AiCardBatchPlannerV1

const OBSERVATION = preload("res://scripts/semantic/ai_card_batch_observation_v1.gd")
const PLAN = preload("res://scripts/semantic/ai_card_batch_plan_v1.gd")
const SUBMISSION = preload("res://scripts/semantic/card_batch_submission_v1.gd")
const TARGET = preload("res://scripts/semantic/card_batch_prebound_target_spec_v1.gd")

const MINIMUM_SUBMISSION_SCORE := 1


func plan_submission_draft(observation: Dictionary) -> Dictionary:
	if not bool(OBSERVATION.validate(observation).get("valid", false)):
		return {}
	if str(observation.get("phase", "")) != OBSERVATION.PHASE_CARD_WINDOW_OPEN:
		return PLAN.build(
			observation,
			PLAN.STATUS_GAMEPLAY_INPUT_DISABLED
		)
	var choice := _best_choice(observation)
	if choice.is_empty() or int(choice.get("score", 0)) < MINIMUM_SUBMISSION_SCORE:
		return PLAN.build(
			observation,
			PLAN.STATUS_NO_LEGAL_SUBMISSION
		)
	var candidate := choice.get("candidate", {}) as Dictionary
	var option := choice.get("option", {}) as Dictionary
	var target_binding := option.get("target_binding", {}) as Dictionary
	var submission_seed := {
		"observation_fingerprint": str(
			observation.get("observation_fingerprint", "")
		),
		"card_instance_id": str(candidate.get("card_instance_id", "")),
		"target_binding_fingerprint": TARGET.fingerprint(target_binding),
	}
	var submission_id := "ai-card-batch-submission:%s" % (
		str(JSON.stringify(submission_seed)).sha256_text().left(24)
	)
	var draft := SUBMISSION.build(
		submission_id,
		str(observation.get("viewer_actor_id", "")),
		str(candidate.get("card_instance_id", "")),
		str(candidate.get("card_semantic_id", "")),
		str(candidate.get("action_class", "")),
		str(candidate.get("source_pool", "")),
		int(candidate.get("source_revision", -1)),
		int(observation.get("viewer_seat_index", -1)),
		int(candidate.get("order_priority", 0)),
		int(candidate.get("submission_sequence", 0)),
		target_binding
	)
	if not bool(SUBMISSION.validate(draft, false).get("valid", false)) \
			or not str(draft.get("locked_at_window_id", "")).is_empty():
		return {}
	return PLAN.build(
		observation,
		PLAN.STATUS_SUBMISSION_DRAFT_READY,
		draft,
		int(observation.get("window_remaining_phase_time_usec", 0))
	)


func audit_snapshot() -> Dictionary:
	return {
		"rng_consumption_count": 0,
		"uses_random_number_generator": false,
		"uses_engine_random": false,
		"resolution_gameplay_intent_count": 0,
		"counter_decision_path_count": 0,
	}


func _best_choice(observation: Dictionary) -> Dictionary:
	var inventory := observation.get("own_inventory", {}) as Dictionary
	var best: Dictionary = {}
	for candidate_variant in observation.get("legal_candidates", []) as Array:
		var candidate := candidate_variant as Dictionary
		for option_variant in candidate.get("legal_target_options", []) as Array:
			var option := option_variant as Dictionary
			var score := _choice_score(candidate, option, inventory)
			var stable_key := "%s|%s" % [
				str(candidate.get("card_instance_id", "")),
				TARGET.fingerprint(option.get("target_binding", {})),
			]
			if best.is_empty() \
					or score > int(best.get("score", 0)) \
					or (
						score == int(best.get("score", 0))
						and stable_key < str(best.get("stable_key", ""))
					):
				best = {
					"score": score,
					"stable_key": stable_key,
					"candidate": candidate,
					"option": option,
				}
	return best


func _choice_score(
	candidate: Dictionary,
	option: Dictionary,
	inventory: Dictionary
) -> int:
	var action_class := str(candidate.get("action_class", ""))
	var score := int(candidate.get("base_utility", 0)) * 100
	score += int(candidate.get("urgency", 0)) * 24
	score += int(option.get("target_value", 0)) * 12
	score += int(option.get("synergy_value", 0)) * 9
	var threat_level := int(option.get("threat_level", 0))
	if action_class == "proactive_defense":
		score += threat_level * 36
	elif action_class == "insurance":
		score += threat_level * 18
	elif action_class == "batch_interference":
		score += threat_level * 8
	score += _pool_pressure_bonus(
		str(candidate.get("source_pool", "")),
		inventory
	)
	return score


func _pool_pressure_bonus(source_pool: String, inventory: Dictionary) -> int:
	if source_pool == "normal_hand":
		var normal_count := (inventory.get("normal_cards", []) as Array).size()
		var normal_limit := int(inventory.get("normal_hand_limit", 5))
		return 180 if normal_count >= normal_limit else normal_count * 12
	if source_pool == "commodity_inventory":
		var commodity_count := (
			inventory.get("commodity_cards", []) as Array
		).size()
		var commodity_limit := int(inventory.get("commodity_inventory_limit", 5))
		return 180 if commodity_count >= commodity_limit else commodity_count * 12
	# Bound actions have zero capacity cost by rule, so no hand-pressure bonus.
	return 0
