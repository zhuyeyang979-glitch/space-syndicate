extends RefCounted
class_name AiOutcomeVector

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const SCHEMA_VERSION := 1
const MAXIMUM_ABSOLUTE_VALUE := 1000000
const DIMENSIONS := [
	"self_economy",
	"opponent_economy",
	"board_control",
	"route_control",
	"hand_advantage",
	"tempo",
	"defense",
	"information",
	"victory_progress",
	"variance",
	"counter_risk",
]


static func zero() -> Dictionary:
	var result := {}
	for dimension in DIMENSIONS:
		result[dimension] = 0
	return result


static func build(source: Dictionary) -> Dictionary:
	return source.duplicate(true) if bool(validate(source).get("valid", false)) else {}


static func validate(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return WIRE.invalid_result("ai_outcome_vector.not_closed_data")
	var vector := value as Dictionary
	if not WIRE.exact_fields(vector, DIMENSIONS):
		return WIRE.invalid_result("ai_outcome_vector.fields_invalid")
	for dimension in DIMENSIONS:
		var amount: Variant = vector.get(dimension)
		if not WIRE.is_safe_integer(amount) \
				or int(amount) < -MAXIMUM_ABSOLUTE_VALUE \
				or int(amount) > MAXIMUM_ABSOLUTE_VALUE:
			return WIRE.invalid_result("ai_outcome_vector.%s_invalid" % dimension)
	return WIRE.valid_result()
