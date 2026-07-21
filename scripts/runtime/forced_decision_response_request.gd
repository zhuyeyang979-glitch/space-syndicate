extends PlayerIdentityActionRequest
class_name ForcedDecisionResponseRequest

const DECISION_KINDS := [
	&"monster_wager",
	&"counter_response",
	&"discard_purchase",
	&"monster_target_choice",
	&"player_target_choice",
	&"public_bid",
]

var decision_id := ""
var decision_kind: StringName = &""
var decision_revision := 0
var option_id := ""


func validation_report() -> Dictionary:
	var identity_validation := super.validation_report()
	if not bool(identity_validation.get("valid", false)):
		return identity_validation
	if source_surface != &"forced_decision":
		return _invalid("forced_decision_source_required")
	if not _canonical_identifier(decision_id, 160):
		return _invalid("decision_id_invalid")
	if not DECISION_KINDS.has(decision_kind):
		return _invalid("decision_kind_invalid")
	if decision_revision <= 0:
		return _invalid("decision_revision_invalid")
	if not _canonical_identifier(option_id, 160):
		return _invalid("option_id_invalid")
	return {"valid": true, "reason_code": ""}


func to_dictionary() -> Dictionary:
	var result := super.to_dictionary()
	result["decision_id"] = decision_id
	result["decision_kind"] = decision_kind
	result["decision_revision"] = decision_revision
	result["option_id"] = option_id
	return result
