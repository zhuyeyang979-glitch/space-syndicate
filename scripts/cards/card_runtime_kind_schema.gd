@tool
extends RefCounted
class_name CardRuntimeKindSchema

const REQUIRED_BASE_FIELDS := ["kind", "move", "damage", "text", "range", "cost"]
const FORBIDDEN_RUNTIME_FIELDS := [
	"owner", "hidden_owner", "private_owner", "private_target", "private_discard",
	"private_plan", "opponent_hand", "ai_private_plan", "callable", "node", "resource",
]
const EXTERNAL_FINANCIAL_FIELDS := [
	"direction", "duration_seconds", "multiplier", "units", "requires_warehouse",
	"action_fee_cash", "margin_cash", "maximum_gain", "maximum_loss",
	"settlement_formula_id", "warehouse_loss_formula_id", "destruction_formula_id", "terms_version",
]


static func validate_definition(definition: Dictionary, field_rule: Dictionary) -> Dictionary:
	var errors: Array = []
	var allowed: Array = field_rule.get("allowed", []) if field_rule.get("allowed", []) is Array else []
	var required: Array = field_rule.get("required", []) if field_rule.get("required", []) is Array else []
	for key in REQUIRED_BASE_FIELDS:
		if not definition.has(key):
			errors.append("missing_required:%s" % key)
	for key in required:
		if not definition.has(str(key)):
			errors.append("missing_kind_required:%s" % str(key))
	for key_variant in definition.keys():
		var key := str(key_variant)
		if FORBIDDEN_RUNTIME_FIELDS.has(key):
			errors.append("runtime_field:%s" % key)
		if EXTERNAL_FINANCIAL_FIELDS.has(key):
			errors.append("external_financial_field:%s" % key)
		if not allowed.is_empty() and not allowed.has(key):
			errors.append("unexpected_field:%s" % key)
		if not _is_data_only(definition[key_variant]):
			errors.append("non_data_value:%s" % key)
	return {
		"valid": errors.is_empty(),
		"kind": str(definition.get("kind", "")),
		"errors": errors,
	}


static func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array or value is PackedStringArray:
		for item in value:
			if not _is_data_only(item):
				return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not (key is String or key is StringName) or not _is_data_only(value[key]):
				return false
		return true
	return false
