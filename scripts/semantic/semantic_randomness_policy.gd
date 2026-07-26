extends RefCounted
class_name SemanticRandomnessPolicy

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const SCHEMA_VERSION := 1
const FIELDS := [
	"schema_version",
	"randomness_policy_id",
	"mode_id",
	"rng_owner_id",
	"stream_id",
	"draw_schedule_id",
	"draw_count_policy_id",
	"selection_order_id",
	"commit_policy_id",
	"failure_consumption_policy_id",
	"rollback_policy_id",
	"replay_policy_id",
	"result_visibility_policy_id",
]
const NONE_FIELDS := [
	"rng_owner_id",
	"stream_id",
	"draw_schedule_id",
	"draw_count_policy_id",
	"selection_order_id",
	"commit_policy_id",
	"failure_consumption_policy_id",
	"rollback_policy_id",
	"replay_policy_id",
]


static func build(
	source: Dictionary,
	registered_policy_ids: Array,
	registered_mode_ids: Array
) -> Dictionary:
	var report := validate(source, registered_policy_ids, registered_mode_ids)
	return source.duplicate(true) if bool(report.get("valid", false)) else {}


static func validate(
	value: Variant,
	registered_policy_ids: Array,
	registered_mode_ids: Array
) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return WIRE.invalid_result("semantic_randomness.not_closed_data")
	var policy := value as Dictionary
	if not WIRE.exact_fields(policy, FIELDS):
		return WIRE.invalid_result("semantic_randomness.fields_invalid")
	if policy.get("schema_version") != SCHEMA_VERSION:
		return WIRE.invalid_result("semantic_randomness.schema_version_invalid")
	for field in FIELDS:
		if field == "schema_version":
			continue
		if not WIRE.is_stable_id(policy.get(field)):
			return WIRE.invalid_result("semantic_randomness.%s_invalid" % field)
	if not registered_policy_ids.has(str(policy.get("randomness_policy_id", ""))):
		return WIRE.invalid_result("semantic_randomness.policy_id_unknown")
	var mode_id := str(policy.get("mode_id", ""))
	if not registered_mode_ids.has(mode_id):
		return WIRE.invalid_result("semantic_randomness.mode_id_unknown")
	for field in NONE_FIELDS:
		var is_none := str(policy.get(field, "")) == "none"
		if mode_id == "none" and not is_none:
			return WIRE.invalid_result("semantic_randomness.none_policy_not_explicit")
		if mode_id != "none" and is_none:
			return WIRE.invalid_result("semantic_randomness.random_policy_incomplete")
	return WIRE.valid_result()
