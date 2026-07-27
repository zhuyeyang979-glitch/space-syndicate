extends RefCounted
class_name GameActionReceiptV1

const ACTION_INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")
const SCHEMA_VERSION := 1
const FIELDS := [
	"schema_version",
	"semantic_action_id",
	"accepted",
	"reason_id",
	"request_id",
	"request_fingerprint",
	"authoritative_revision",
	"committed_effect_refs",
	"public_projection_ref",
	"viewer_private_projection_ref",
	"idempotent_replay",
	"request_id_collision",
	"refresh_scope",
	"receipt_fingerprint",
]
const UNSEALED_FIELDS := [
	"schema_version",
	"semantic_action_id",
	"accepted",
	"reason_id",
	"request_id",
	"request_fingerprint",
	"authoritative_revision",
	"committed_effect_refs",
	"public_projection_ref",
	"viewer_private_projection_ref",
	"idempotent_replay",
	"request_id_collision",
	"refresh_scope",
]
const REFRESH_SCOPES := ["none", "live", "map", "full"]


static func build(unsealed: Dictionary) -> Dictionary:
	if not SemanticWireV1.is_closed_data(unsealed) \
			or not SemanticWireV1.exact_fields(unsealed, UNSEALED_FIELDS):
		return {}
	var sealed := SemanticWireV1.sealed_copy(unsealed, "receipt_fingerprint")
	return sealed if bool(validation_report(sealed).get("valid", false)) else {}


static func validation_report(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not SemanticWireV1.is_closed_data(value):
		return SemanticWireV1.invalid_result("game_action_receipt_not_closed_data")
	var receipt := value as Dictionary
	if not SemanticWireV1.exact_fields(receipt, FIELDS):
		return SemanticWireV1.invalid_result("game_action_receipt_fields_invalid")
	if receipt.get("schema_version") != SCHEMA_VERSION:
		return SemanticWireV1.invalid_result("game_action_receipt_schema_version_invalid")
	for field in [
		"semantic_action_id",
		"reason_id",
		"request_id",
		"public_projection_ref",
		"viewer_private_projection_ref",
	]:
		if not SemanticWireV1.is_stable_id(receipt.get(field)):
			return SemanticWireV1.invalid_result("game_action_receipt_%s_invalid" % field)
	if ACTION_INTENT.action_contract(str(receipt.get("semantic_action_id", ""))).is_empty():
		return SemanticWireV1.invalid_result("game_action_receipt_action_id_unknown")
	if not SemanticWireV1.is_fingerprint(receipt.get("request_fingerprint")):
		return SemanticWireV1.invalid_result("game_action_receipt_request_fingerprint_invalid")
	if not (receipt.get("accepted") is bool) \
			or not (receipt.get("idempotent_replay") is bool) \
			or not (receipt.get("request_id_collision") is bool):
		return SemanticWireV1.invalid_result("game_action_receipt_boolean_invalid")
	if not SemanticWireV1.is_nonnegative_integer(receipt.get("authoritative_revision")):
		return SemanticWireV1.invalid_result("game_action_receipt_revision_invalid")
	if SemanticWireV1.stable_id_array_error(receipt.get("committed_effect_refs"), true, false) != "":
		return SemanticWireV1.invalid_result("game_action_receipt_effect_refs_invalid")
	if str(receipt.get("refresh_scope", "")) not in REFRESH_SCOPES:
		return SemanticWireV1.invalid_result("game_action_receipt_refresh_scope_invalid")
	if bool(receipt.get("accepted", false)) and bool(receipt.get("request_id_collision", false)):
		return SemanticWireV1.invalid_result("game_action_receipt_collision_acceptance_invalid")
	if bool(receipt.get("idempotent_replay", false)) \
			and bool(receipt.get("request_id_collision", false)):
		return SemanticWireV1.invalid_result("game_action_receipt_replay_collision_invalid")
	if not bool(receipt.get("accepted", false)) \
			and not (receipt.get("committed_effect_refs", []) as Array).is_empty():
		return SemanticWireV1.invalid_result("game_action_receipt_rejected_effects_invalid")
	if not SemanticWireV1.is_fingerprint(receipt.get("receipt_fingerprint")) \
			or str(receipt.get("receipt_fingerprint", "")) != SemanticWireV1.fingerprint(receipt, "receipt_fingerprint"):
		return SemanticWireV1.invalid_result("game_action_receipt_fingerprint_invalid")
	return SemanticWireV1.valid_result()


static func detached_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) \
		if bool(validation_report(value).get("valid", false)) else {}


static func replay_copy(value: Dictionary) -> Dictionary:
	if not bool(validation_report(value).get("valid", false)) \
			or bool(value.get("request_id_collision", false)):
		return {}
	var unsealed := value.duplicate(true)
	unsealed.erase("receipt_fingerprint")
	unsealed["idempotent_replay"] = true
	return build(unsealed)


static func request_binding_matches(receipt: Dictionary, intent: Dictionary) -> bool:
	if not bool(validation_report(receipt).get("valid", false)) \
			or not bool(ACTION_INTENT.validation_report(intent).get("valid", false)):
		return false
	return str(receipt.get("request_id", "")) == str(intent.get("request_id", "")) \
		and str(receipt.get("semantic_action_id", "")) \
			== str(intent.get("semantic_action_id", "")) \
		and str(receipt.get("request_fingerprint", "")) \
			== ACTION_INTENT.request_fingerprint(intent)
