extends RefCounted
class_name AiOutcomeVectorV1

# Owns the neutral eleven-dimension AI evidence vector. This registry projects
# already-validated op IDs; it is not a card-rule or op-schema validator.
const MAX_ABSOLUTE_OUTCOME := 1000000
const MAX_RISK_INDEX := 100
const DIMENSIONS := [
	"self_economy", "opponent_economy", "board_control", "route_control",
	"hand_advantage", "tempo", "defense", "information", "victory_progress",
	"variance", "counter_risk",
]
const OP_NEUTRAL_PROJECTIONS := {
	"install_rate": {"self_economy": 1, "route_control": 1},
	"build_facility": {"self_economy": 1, "board_control": 1, "defense": 1},
	"upgrade_facility": {"self_economy": 1, "board_control": 1, "tempo": 1},
	"repair_facility": {"self_economy": 1, "tempo": 1, "defense": 1},
	"deploy_unit": {"board_control": 1, "tempo": 1, "defense": 1},
	"upgrade_same_family_unit": {"board_control": 1, "defense": 1},
	"extend_presence": {"board_control": 1, "tempo": 1},
	"heal_unit": {"defense": 1, "tempo": 1},
	"modify_supply": {"self_economy": 1, "route_control": 1, "variance": 1},
	"modify_demand": {"self_economy": 1, "victory_progress": 1, "variance": 1},
	"discard_random": {"opponent_economy": -1, "hand_advantage": 1, "tempo": 1, "variance": 1},
	"steal_random": {"opponent_economy": -1, "hand_advantage": 2, "variance": 1},
	"lock_random": {"hand_advantage": 1, "tempo": 1, "variance": 1},
	"counter_action": {"tempo": 1, "defense": 1},
	"install_organization_upgrade": {"self_economy": 1, "board_control": 1, "victory_progress": 1},
	"military_move": {"board_control": 1, "tempo": 1},
	"military_guard": {"defense": 1, "board_control": 1},
	"military_strike": {"opponent_economy": -1, "board_control": 1, "route_control": 1},
	"global_order": {"self_economy": 1, "route_control": 1, "variance": 1},
	"global_supply_spawn": {"self_economy": 1, "route_control": 1, "variance": 1},
}


static func project(spec: Dictionary, target_fact: Dictionary) -> Dictionary:
	var outcome := zero()
	var explanation_tokens: Array[String] = []
	for op_variant in spec.get("effect_ops", []) as Array:
		var op_id := str((op_variant as Dictionary).get("op_id", ""))
		_apply_registered_projection(outcome, op_id)
		_append_unique(explanation_tokens, "semantic.op.%s" % op_id)
	var adjustments := target_fact.get("outcome_adjustments", {}) as Dictionary
	for dimension in DIMENSIONS:
		if dimension == "counter_risk":
			continue
		outcome[dimension] = clampi(
			int(outcome.get(dimension, 0)) + int(adjustments.get(dimension, 0)),
			-MAX_ABSOLUTE_OUTCOME,
			MAX_ABSOLUTE_OUTCOME
		)
	var uncertainty := clampi(int(target_fact.get("uncertainty", 0)), 0, MAX_RISK_INDEX)
	var counter_risk := clampi(int(target_fact.get("counter_risk", 0)), 0, MAX_RISK_INDEX)
	outcome["counter_risk"] = counter_risk
	var response_id := str((spec.get("response", {}) as Dictionary).get("response_id", ""))
	if response_id == "counterable":
		_append_unique(explanation_tokens, "semantic.response.counterable")
	_append_unique(
		explanation_tokens,
		"semantic.target.%s" % str(target_fact.get("target_id", ""))
	)
	_append_unique(explanation_tokens, "semantic.legality.proven")
	var supplied_tokens: Array[String] = []
	for token in target_fact.get("explanation_tokens", []) as Array:
		supplied_tokens.append(str(token))
	supplied_tokens.sort()
	for token in supplied_tokens:
		_append_unique(explanation_tokens, token)
	if uncertainty > 0:
		_append_unique(explanation_tokens, "semantic.uncertainty.present")
	if counter_risk > 0:
		_append_unique(explanation_tokens, "semantic.counter_risk.present")
	return {
		"projected_outcomes": outcome,
		"uncertainty": uncertainty,
		"counter_risk": counter_risk,
		"explanation_tokens": explanation_tokens,
	}


static func zero() -> Dictionary:
	var result := {}
	for dimension in DIMENSIONS:
		result[dimension] = 0
	return result


static func is_valid(value: Variant) -> bool:
	if not (value is Dictionary) or (value as Dictionary).size() != DIMENSIONS.size():
		return false
	for dimension in DIMENSIONS:
		if not (value as Dictionary).has(dimension):
			return false
		var amount: Variant = (value as Dictionary).get(dimension)
		if not (amount is int) or absi(int(amount)) > MAX_ABSOLUTE_OUTCOME:
			return false
	return true


static func _apply_registered_projection(outcome: Dictionary, op_id: String) -> void:
	var projection: Variant = OP_NEUTRAL_PROJECTIONS.get(op_id)
	if not (projection is Dictionary):
		return
	for dimension_variant in (projection as Dictionary).keys():
		var dimension := str(dimension_variant)
		if not DIMENSIONS.has(dimension) or dimension == "counter_risk":
			continue
		outcome[dimension] = clampi(
			int(outcome.get(dimension, 0)) + int((projection as Dictionary).get(dimension, 0)),
			-MAX_ABSOLUTE_OUTCOME,
			MAX_ABSOLUTE_OUTCOME
		)


static func _append_unique(values: Array[String], value: String) -> void:
	if not values.has(value):
		values.append(value)
