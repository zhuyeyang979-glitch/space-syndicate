extends RefCounted
class_name GameActionOfferV1

const ACTION_INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")
const SCHEMA_VERSION := 1
const FIELDS := [
	"schema_version",
	"semantic_action_id",
	"action_family_id",
	"source_revision",
	"actor_scope",
	"public_or_private_target_spec",
	"legality_state",
	"disabled_reason_id",
	"cost_spec",
	"requirement_spec",
	"consequence_spec",
	"presentation_token_ids",
	"offer_fingerprint",
]
const UNSEALED_FIELDS := [
	"schema_version",
	"semantic_action_id",
	"action_family_id",
	"source_revision",
	"actor_scope",
	"public_or_private_target_spec",
	"legality_state",
	"disabled_reason_id",
	"cost_spec",
	"requirement_spec",
	"consequence_spec",
	"presentation_token_ids",
]
const TARGET_SPEC_FIELDS := [
	"visibility_scope_id",
	"target_kind_id",
	"target_bindings",
	"requires_target",
]
const TARGET_BINDING_FIELDS := ["target_role_id", "target_id"]
const COST_SPEC_FIELDS := ["cost_kind_id", "amount_units", "resource_id"]
const REQUIREMENT_SPEC_FIELDS := ["requirement_ids", "source_revision_required"]
const CONSEQUENCE_SPEC_FIELDS := ["committed_effect_refs", "refresh_scope"]
const ACTOR_SCOPES := ["current_actor", "authorized_actor", "system"]
const LEGALITY_STATES := ["available", "disabled"]
const TARGET_VISIBILITY_SCOPES := ["public", "viewer_private", "actor_private"]
const REFRESH_SCOPES := ["none", "live", "map", "full"]


static func build(unsealed: Dictionary) -> Dictionary:
	if not SemanticWireV1.is_closed_data(unsealed) \
			or not SemanticWireV1.exact_fields(unsealed, UNSEALED_FIELDS):
		return {}
	var sealed := SemanticWireV1.sealed_copy(unsealed, "offer_fingerprint")
	return sealed if bool(validation_report(sealed).get("valid", false)) else {}


static func validation_report(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not SemanticWireV1.is_closed_data(value):
		return SemanticWireV1.invalid_result("game_action_offer_not_closed_data")
	var offer := value as Dictionary
	if not SemanticWireV1.exact_fields(offer, FIELDS):
		return SemanticWireV1.invalid_result("game_action_offer_fields_invalid")
	if offer.get("schema_version") != SCHEMA_VERSION:
		return SemanticWireV1.invalid_result("game_action_offer_schema_version_invalid")
	for field in ["semantic_action_id", "action_family_id", "disabled_reason_id"]:
		if not SemanticWireV1.is_stable_id(offer.get(field)):
			return SemanticWireV1.invalid_result("game_action_offer_%s_invalid" % field)
	var action_id := str(offer.get("semantic_action_id", ""))
	var contract := ACTION_INTENT.action_contract(action_id)
	if contract.is_empty():
		return SemanticWireV1.invalid_result("game_action_offer_action_id_unknown")
	if str(offer.get("action_family_id", "")) \
			!= str(contract.get("action_family_id", "")):
		return SemanticWireV1.invalid_result("game_action_offer_action_family_mismatch")
	if not SemanticWireV1.is_nonnegative_integer(offer.get("source_revision")):
		return SemanticWireV1.invalid_result("game_action_offer_source_revision_invalid")
	if str(offer.get("actor_scope", "")) not in ACTOR_SCOPES:
		return SemanticWireV1.invalid_result("game_action_offer_actor_scope_invalid")
	if str(offer.get("legality_state", "")) not in LEGALITY_STATES:
		return SemanticWireV1.invalid_result("game_action_offer_legality_state_invalid")
	if str(offer.get("legality_state", "")) == "available" \
			and str(offer.get("disabled_reason_id", "")) != "none":
		return SemanticWireV1.invalid_result("game_action_offer_available_reason_invalid")
	if str(offer.get("legality_state", "")) == "disabled" \
			and str(offer.get("disabled_reason_id", "")) == "none":
		return SemanticWireV1.invalid_result("game_action_offer_disabled_reason_missing")
	var nested_error := _target_spec_error(offer.get("public_or_private_target_spec"))
	if not nested_error.is_empty():
		return SemanticWireV1.invalid_result(nested_error)
	nested_error = _cost_spec_error(offer.get("cost_spec"))
	if not nested_error.is_empty():
		return SemanticWireV1.invalid_result(nested_error)
	nested_error = _requirement_spec_error(offer.get("requirement_spec"))
	if not nested_error.is_empty():
		return SemanticWireV1.invalid_result(nested_error)
	nested_error = _consequence_spec_error(offer.get("consequence_spec"))
	if not nested_error.is_empty():
		return SemanticWireV1.invalid_result(nested_error)
	if SemanticWireV1.stable_id_array_error(offer.get("presentation_token_ids"), true, false) != "":
		return SemanticWireV1.invalid_result("game_action_offer_presentation_tokens_invalid")
	if not SemanticWireV1.is_fingerprint(offer.get("offer_fingerprint")) \
			or str(offer.get("offer_fingerprint", "")) != SemanticWireV1.fingerprint(offer, "offer_fingerprint"):
		return SemanticWireV1.invalid_result("game_action_offer_fingerprint_invalid")
	return SemanticWireV1.valid_result()


static func detached_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) \
		if bool(validation_report(value).get("valid", false)) else {}


static func target_ids(offer: Dictionary) -> Dictionary:
	if not bool(validation_report(offer).get("valid", false)):
		return {}
	var result := {}
	var spec := offer.get("public_or_private_target_spec", {}) as Dictionary
	for binding_variant in spec.get("target_bindings", []) as Array:
		var binding := binding_variant as Dictionary
		result[str(binding.get("target_role_id", ""))] = str(binding.get("target_id", ""))
	return result


static func accepts_intent(offer: Dictionary, intent: Dictionary) -> bool:
	if not bool(validation_report(offer).get("valid", false)) \
			or not bool(ACTION_INTENT.validation_report(intent).get("valid", false)):
		return false
	return str(offer.get("semantic_action_id", "")) \
			== str(intent.get("semantic_action_id", "")) \
		and int(offer.get("source_revision", -1)) \
			== int(intent.get("source_revision", -2)) \
		and str(offer.get("legality_state", "")) == "available"


static func _target_spec_error(value: Variant) -> String:
	if not (value is Dictionary) or not SemanticWireV1.is_closed_data(value):
		return "game_action_offer_target_spec_not_closed"
	var spec := value as Dictionary
	if not SemanticWireV1.exact_fields(spec, TARGET_SPEC_FIELDS):
		return "game_action_offer_target_spec_fields_invalid"
	for field in ["visibility_scope_id", "target_kind_id"]:
		if not SemanticWireV1.is_stable_id(spec.get(field)):
			return "game_action_offer_target_spec_identity_invalid"
	if str(spec.get("visibility_scope_id", "")) not in TARGET_VISIBILITY_SCOPES:
		return "game_action_offer_target_visibility_scope_invalid"
	if not (spec.get("requires_target") is bool) or not (spec.get("target_bindings") is Array):
		return "game_action_offer_target_spec_shape_invalid"
	var roles: Array[String] = []
	for binding_variant in spec.get("target_bindings") as Array:
		if not (binding_variant is Dictionary) or not SemanticWireV1.is_closed_data(binding_variant):
			return "game_action_offer_target_binding_not_closed"
		var binding := binding_variant as Dictionary
		if not SemanticWireV1.exact_fields(binding, TARGET_BINDING_FIELDS) \
				or not SemanticWireV1.is_stable_id(binding.get("target_role_id")) \
				or not SemanticWireV1.is_stable_id(binding.get("target_id")):
			return "game_action_offer_target_binding_invalid"
		var role := str(binding.get("target_role_id", ""))
		if roles.has(role):
			return "game_action_offer_target_binding_duplicate"
		roles.append(role)
	if bool(spec.get("requires_target", false)) and roles.is_empty():
		return "game_action_offer_required_target_missing"
	return ""


static func _cost_spec_error(value: Variant) -> String:
	if not (value is Dictionary) or not SemanticWireV1.is_closed_data(value):
		return "game_action_offer_cost_spec_not_closed"
	var spec := value as Dictionary
	if not SemanticWireV1.exact_fields(spec, COST_SPEC_FIELDS) \
			or not SemanticWireV1.is_stable_id(spec.get("cost_kind_id")) \
			or not SemanticWireV1.is_nonnegative_integer(spec.get("amount_units")) \
			or not SemanticWireV1.is_stable_id(spec.get("resource_id")):
		return "game_action_offer_cost_spec_invalid"
	return ""


static func _requirement_spec_error(value: Variant) -> String:
	if not (value is Dictionary) or not SemanticWireV1.is_closed_data(value):
		return "game_action_offer_requirement_spec_not_closed"
	var spec := value as Dictionary
	if not SemanticWireV1.exact_fields(spec, REQUIREMENT_SPEC_FIELDS) \
			or SemanticWireV1.stable_id_array_error(spec.get("requirement_ids"), true, false) != "" \
			or not (spec.get("source_revision_required") is bool):
		return "game_action_offer_requirement_spec_invalid"
	return ""


static func _consequence_spec_error(value: Variant) -> String:
	if not (value is Dictionary) or not SemanticWireV1.is_closed_data(value):
		return "game_action_offer_consequence_spec_not_closed"
	var spec := value as Dictionary
	if not SemanticWireV1.exact_fields(spec, CONSEQUENCE_SPEC_FIELDS) \
			or SemanticWireV1.stable_id_array_error(spec.get("committed_effect_refs"), true, false) != "" \
			or str(spec.get("refresh_scope", "")) not in REFRESH_SCOPES:
		return "game_action_offer_consequence_spec_invalid"
	return ""
