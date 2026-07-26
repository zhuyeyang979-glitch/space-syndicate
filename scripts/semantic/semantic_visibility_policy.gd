extends RefCounted
class_name SemanticVisibilityPolicy

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const SCHEMA_VERSION := 1
const FIELDS := [
	"schema_version",
	"visibility_policy_id",
	"definition_visibility_id",
	"source_identity_visibility_id",
	"actor_visibility_id",
	"target_choice_visibility_id",
	"outcome_visibility_id",
	"private_value_visibility_id",
	"ai_analysis_visibility_id",
	"redaction_policy_id",
]


static func build(source: Dictionary, registered_policy_ids: Array) -> Dictionary:
	var report := validate(source, registered_policy_ids)
	return source.duplicate(true) if bool(report.get("valid", false)) else {}


static func validate(value: Variant, registered_policy_ids: Array) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return WIRE.invalid_result("semantic_visibility.not_closed_data")
	var policy := value as Dictionary
	if not WIRE.exact_fields(policy, FIELDS):
		return WIRE.invalid_result("semantic_visibility.fields_invalid")
	if policy.get("schema_version") != SCHEMA_VERSION:
		return WIRE.invalid_result("semantic_visibility.schema_version_invalid")
	for field in FIELDS:
		if field == "schema_version":
			continue
		if not WIRE.is_stable_id(policy.get(field)):
			return WIRE.invalid_result("semantic_visibility.%s_invalid" % field)
	if not registered_policy_ids.has(str(policy.get("visibility_policy_id", ""))):
		return WIRE.invalid_result("semantic_visibility.policy_id_unknown")
	return WIRE.valid_result()
