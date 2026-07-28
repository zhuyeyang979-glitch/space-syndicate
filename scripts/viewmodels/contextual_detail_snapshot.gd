extends RefCounted
class_name ContextualDetailSnapshot

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

const FIELDS := [
	"schema_version",
	"source_revision",
	"viewer_index",
	"authorization_revision",
	"visibility_scope",
	"context_kind",
	"context_id",
	"title",
	"subtitle",
	"body",
	"chips",
	"actions",
	"deep_links",
]
const ACTION_FIELDS := ["id", "label", "disabled", "tooltip", "application_intent"]
const VALID_CONTEXT_KINDS := [
	"hand_card",
	"commodity_card",
	"bound_action",
	"public_track",
	"public_commodity",
	"region",
]
const VALID_VISIBILITY_SCOPES := ["public", "viewer_private"]
const FORBIDDEN_KEYS := [
	"opponent_cash", "opponent_exact_cash", "rival_cash", "exact_cash",
	"opponent_hand", "opponent_hand_count", "opponent_discard", "rival_hand",
	"rival_hand_count", "rival_discard", "private_hand", "private_discard",
	"hidden_owner", "hidden_owner_id", "true_owner", "anonymous_true_player",
	"private_target_player_binding", "ai_plan", "ai_score", "learning_metadata",
	"decision_samples", "future_rack", "future_track_sequence", "rng_state",
	"runtime_instance_id",
	"node", "object", "resource", "callable", "node_path", "method_name",
]

var _value: Dictionary = {}


func apply_dictionary(value: Variant) -> ContextualDetailSnapshot:
	_value = (value as Dictionary).duplicate(true) if bool(validation_report(value).get("valid", false)) else {}
	return self


func to_ui_dictionary() -> Dictionary:
	return _value.duplicate(true)


static func validation_report(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return _invalid("contextual_detail_not_closed_data")
	var projection := value as Dictionary
	if not WIRE.exact_fields(projection, FIELDS) \
			or int(projection.get("schema_version", 0)) != 1 \
			or not WIRE.is_nonnegative_integer(projection.get("source_revision")) \
			or not WIRE.is_nonnegative_integer(projection.get("viewer_index")) \
			or not WIRE.is_positive_integer(projection.get("authorization_revision")):
		return _invalid("contextual_detail_identity_invalid")
	if str(projection.get("visibility_scope", "")) not in VALID_VISIBILITY_SCOPES \
			or str(projection.get("context_kind", "")) not in VALID_CONTEXT_KINDS \
			or str(projection.get("context_id", "")).strip_edges().is_empty() \
			or str(projection.get("title", "")).strip_edges().is_empty():
		return _invalid("contextual_detail_scope_invalid")
	if not (projection.get("chips") is Array) \
			or not (projection.get("actions") is Array) \
			or not (projection.get("deep_links") is Array):
		return _invalid("contextual_detail_collections_invalid")
	if WIRE.contains_key_recursive(projection, FORBIDDEN_KEYS):
		return _invalid("contextual_detail_private_field_forbidden")
	for chip_variant in projection.get("chips", []) as Array:
		if not (chip_variant is Dictionary):
			return _invalid("contextual_detail_chip_invalid")
		for key_variant in (chip_variant as Dictionary).keys():
			if str(key_variant) not in ["text", "tooltip", "accent"]:
				return _invalid("contextual_detail_chip_field_invalid")
	for key in ["actions", "deep_links"]:
		for entry_variant in projection.get(key, []) as Array:
			if not _valid_action(entry_variant):
				return _invalid("contextual_detail_action_invalid")
	return {"valid": true, "reason_id": "ok"}


static func _valid_action(value: Variant) -> bool:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return false
	var action := value as Dictionary
	return WIRE.exact_fields(action, ACTION_FIELDS) \
		and str(action.get("id", "")).strip_edges().length() > 0 \
		and str(action.get("label", "")).strip_edges().length() > 0 \
		and action.get("disabled") is bool \
		and action.get("application_intent") is Dictionary


static func _invalid(reason_id: String) -> Dictionary:
	return {"valid": false, "reason_id": reason_id}
