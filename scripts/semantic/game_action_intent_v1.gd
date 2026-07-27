extends RefCounted
class_name GameActionIntentV1

const SCHEMA_VERSION := 1
const ACTION_CARD_PLAY := "card.play"
const ACTION_CARD_GROUP_READY := "card.group.ready"
const ACTION_CARD_GROUP_REORDER := "card.group.reorder"
const ACTION_DISTRICT_SUPPLY_OPEN := "district.supply.open"
const ACTION_PLAYER_STRATEGY_OPEN_SUPPLY := "player.strategy.open-supply"
const ACTION_SESSION_END_TURN := "session.end-turn"
const FAMILY_CARD_PLAY := "card-play"
const FAMILY_CARD_RESOLUTION := "card-resolution"
const FAMILY_DISTRICT_SUPPLY := "district-supply"
const FAMILY_PLAYER_STRATEGY := "player-strategy"
const FAMILY_SESSION := "session"
const ACTION_IDS := [
	ACTION_CARD_PLAY,
	ACTION_CARD_GROUP_READY,
	ACTION_CARD_GROUP_REORDER,
	ACTION_DISTRICT_SUPPLY_OPEN,
	ACTION_PLAYER_STRATEGY_OPEN_SUPPLY,
	ACTION_SESSION_END_TURN,
]
const SUBMISSION_KINDS := [
	"human_click",
	"human_drag",
	"human_quick_action",
	"ai_decision",
	"system_default",
]
const FIELDS := [
	"schema_version",
	"request_id",
	"semantic_action_id",
	"source_revision",
	"actor_authorization",
	"target_ids",
	"parameters",
	"submission_kind",
	"intent_fingerprint",
]
const UNSEALED_FIELDS := [
	"schema_version",
	"request_id",
	"semantic_action_id",
	"source_revision",
	"actor_authorization",
	"target_ids",
	"parameters",
	"submission_kind",
]
const AUTHORIZATION_FIELDS := [
	"schema_version",
	"actor_kind_id",
	"actor_id",
	"actor_index",
	"actor_revision",
	"session_id",
	"session_revision",
	"authorization_proof_ref",
	"source_surface_id",
]
const ACTOR_KIND_IDS := ["human", "ai", "system"]
const TARGET_SCHEMAS := {
	"card-play-targets": {
		"required_fields": ["card_instance_id", "hand_slot_id"],
		"optional_fields": ["monster_id", "player_id", "region_id", "selected_resolution_id"],
		"field_kinds": {
			"card_instance_id": "stable_id",
			"hand_slot_id": "stable_id",
			"monster_id": "stable_id",
			"player_id": "stable_id",
			"region_id": "stable_id",
			"selected_resolution_id": "stable_id",
		},
	},
	"card-group-ready-targets": {
		"required_fields": ["resolution_id"],
		"optional_fields": [],
		"field_kinds": {"resolution_id": "stable_id"},
	},
	"card-group-reorder-targets": {
		"required_fields": ["resolution_id"],
		"optional_fields": [],
		"field_kinds": {"resolution_id": "stable_id"},
	},
	"district-targets": {
		"required_fields": ["region_id"],
		"optional_fields": [],
		"field_kinds": {"region_id": "stable_id"},
	},
	"no-targets": {
		"required_fields": [],
		"optional_fields": [],
		"field_kinds": {},
	},
}
const PARAMETER_SCHEMAS := {
	"no-parameters": {
		"required_fields": [],
		"optional_fields": [],
		"field_kinds": {},
	},
	"card-group-reorder-parameters": {
		"required_fields": ["direction"],
		"optional_fields": [],
		"field_kinds": {"direction": "safe_integer"},
	},
}
const ACTION_CONTRACTS := {
	ACTION_CARD_PLAY: {
		"action_family_id": FAMILY_CARD_PLAY,
		"target_schema_id": "card-play-targets",
		"parameter_schema_id": "no-parameters",
	},
	ACTION_CARD_GROUP_READY: {
		"action_family_id": FAMILY_CARD_RESOLUTION,
		"target_schema_id": "card-group-ready-targets",
		"parameter_schema_id": "no-parameters",
	},
	ACTION_CARD_GROUP_REORDER: {
		"action_family_id": FAMILY_CARD_RESOLUTION,
		"target_schema_id": "card-group-reorder-targets",
		"parameter_schema_id": "card-group-reorder-parameters",
	},
	ACTION_DISTRICT_SUPPLY_OPEN: {
		"action_family_id": FAMILY_DISTRICT_SUPPLY,
		"target_schema_id": "district-targets",
		"parameter_schema_id": "no-parameters",
	},
	ACTION_PLAYER_STRATEGY_OPEN_SUPPLY: {
		"action_family_id": FAMILY_PLAYER_STRATEGY,
		"target_schema_id": "district-targets",
		"parameter_schema_id": "no-parameters",
	},
	ACTION_SESSION_END_TURN: {
		"action_family_id": FAMILY_SESSION,
		"target_schema_id": "no-targets",
		"parameter_schema_id": "no-parameters",
	},
}


static func build(unsealed: Dictionary) -> Dictionary:
	if not SemanticWireV1.is_closed_data(unsealed) \
			or not SemanticWireV1.exact_fields(unsealed, UNSEALED_FIELDS):
		return {}
	var sealed := SemanticWireV1.sealed_copy(unsealed, "intent_fingerprint")
	return sealed if bool(validation_report(sealed).get("valid", false)) else {}


static func validation_report(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not SemanticWireV1.is_closed_data(value):
		return SemanticWireV1.invalid_result("game_action_intent_not_closed_data")
	var intent := value as Dictionary
	if not SemanticWireV1.exact_fields(intent, FIELDS):
		return SemanticWireV1.invalid_result("game_action_intent_fields_invalid")
	if intent.get("schema_version") != SCHEMA_VERSION:
		return SemanticWireV1.invalid_result("game_action_intent_schema_version_invalid")
	if not SemanticWireV1.is_stable_id(intent.get("request_id")):
		return SemanticWireV1.invalid_result("game_action_intent_request_id_invalid")
	var action_id := str(intent.get("semantic_action_id", ""))
	if action_id not in ACTION_IDS:
		return SemanticWireV1.invalid_result("game_action_intent_action_id_invalid")
	if not SemanticWireV1.is_nonnegative_integer(intent.get("source_revision")):
		return SemanticWireV1.invalid_result("game_action_intent_source_revision_invalid")
	var authorization_error := _authorization_error(intent.get("actor_authorization"))
	if not authorization_error.is_empty():
		return SemanticWireV1.invalid_result(authorization_error)
	if str(intent.get("submission_kind", "")) not in SUBMISSION_KINDS:
		return SemanticWireV1.invalid_result("game_action_intent_submission_kind_invalid")
	var contract := ACTION_CONTRACTS.get(action_id, {}) as Dictionary
	var target_error := SemanticWireV1.closed_payload_error(
		intent.get("target_ids"),
		str(contract.get("target_schema_id", "")),
		TARGET_SCHEMAS
	)
	if not target_error.is_empty():
		return SemanticWireV1.invalid_result("game_action_intent_targets.%s" % target_error)
	var parameter_error := SemanticWireV1.closed_payload_error(
		intent.get("parameters"),
		str(contract.get("parameter_schema_id", "")),
		PARAMETER_SCHEMAS
	)
	if not parameter_error.is_empty():
		return SemanticWireV1.invalid_result("game_action_intent_parameters.%s" % parameter_error)
	if action_id == ACTION_CARD_GROUP_REORDER \
			and int((intent.get("parameters", {}) as Dictionary).get("direction", 0)) not in [-1, 1]:
		return SemanticWireV1.invalid_result("game_action_intent_reorder_direction_invalid")
	var actor_kind := str((intent.get("actor_authorization", {}) as Dictionary).get("actor_kind_id", ""))
	var submission_kind := str(intent.get("submission_kind", ""))
	var submission_matches_actor := (
		(actor_kind == "human" and submission_kind in [
			"human_click", "human_drag", "human_quick_action",
		])
		or (actor_kind == "ai" and submission_kind == "ai_decision")
		or (actor_kind == "system" and submission_kind == "system_default")
	)
	if not submission_matches_actor:
		return SemanticWireV1.invalid_result("game_action_intent_actor_submission_mismatch")
	if not SemanticWireV1.is_fingerprint(intent.get("intent_fingerprint")) \
			or str(intent.get("intent_fingerprint", "")) != SemanticWireV1.fingerprint(intent, "intent_fingerprint"):
		return SemanticWireV1.invalid_result("game_action_intent_fingerprint_invalid")
	return SemanticWireV1.valid_result()


static func detached_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) \
		if bool(validation_report(value).get("valid", false)) else {}


static func request_fingerprint(value: Variant) -> String:
	return str((value as Dictionary).get("intent_fingerprint", "")) \
		if bool(validation_report(value).get("valid", false)) else ""


static func action_contract(action_id: String) -> Dictionary:
	var contract: Variant = ACTION_CONTRACTS.get(action_id)
	return (contract as Dictionary).duplicate(true) if contract is Dictionary else {}


static func action_family_id(action_id: String) -> String:
	return str(action_contract(action_id).get("action_family_id", ""))


static func _authorization_error(value: Variant) -> String:
	if not (value is Dictionary) or not SemanticWireV1.is_closed_data(value):
		return "game_action_intent_authorization_not_closed"
	var authorization := value as Dictionary
	if not SemanticWireV1.exact_fields(authorization, AUTHORIZATION_FIELDS):
		return "game_action_intent_authorization_fields_invalid"
	if authorization.get("schema_version") != SCHEMA_VERSION \
			or str(authorization.get("actor_kind_id", "")) not in ACTOR_KIND_IDS:
		return "game_action_intent_authorization_kind_invalid"
	for field in ["actor_id", "session_id", "authorization_proof_ref", "source_surface_id"]:
		if not SemanticWireV1.is_stable_id(authorization.get(field)):
			return "game_action_intent_authorization_%s_invalid" % field
	for field in ["actor_index", "actor_revision", "session_revision"]:
		if not SemanticWireV1.is_nonnegative_integer(authorization.get(field)):
			return "game_action_intent_authorization_%s_invalid" % field
	return ""
