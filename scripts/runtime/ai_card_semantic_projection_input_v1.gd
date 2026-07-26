extends RefCounted
class_name AiCardSemanticProjectionInputV1

# Owns the closed AI input boundary: CardInstanceState and viewer-authorized
# observation/legal-target facts. CardSemanticSpec validation stays upstream.
const CARD_SEMANTIC_SCHEMA_V1 := preload(
	"res://scripts/cards/semantic/card_semantic_schema_v1.gd"
)
const OUTCOME_VECTOR_V1 := preload("res://scripts/runtime/ai_outcome_vector_v1.gd")
const SCHEMA_VERSION := 1
const INFORMATION_SCOPE_ID := "actor_private"

const INSTANCE_REQUIRED_KEYS := [
	"schema_version", "instance_id", "card_id", "source_slot", "instance_revision",
	"queued", "locked", "cooldown_remaining_seconds",
]
const INSTANCE_ALLOWED_KEYS := INSTANCE_REQUIRED_KEYS + ["binding_refs"]
const OBSERVATION_KEYS := [
	"schema_version", "projection_id", "viewer_actor_id", "visibility_scope_id",
	"source_kind", "source_revision", "semantic_fingerprint", "card_id",
	"instance_id", "source_slot", "instance_revision", "world_revision",
	"legal_targets", "projection_fingerprint",
]
const LEGAL_TARGET_KEYS := [
	"schema_version", "target_id", "target_identity", "status_id", "source_revision",
	"instance_revision", "world_revision", "uncertainty", "counter_risk",
	"outcome_adjustments", "explanation_tokens", "legality_fingerprint",
]
const TARGET_IDENTITY_KEYS := ["schema_version", "target_id", "stable_id"]
const FORBIDDEN_OBSERVATION_KEYS := [
	"ai_private_plan", "ai_" + "score", "ai_" + "value", "bag", "bag_keys",
	"bag_order", "callable", "cash_cents", "current_" + "scene", "discard_choice",
	"exact_cash", "future_bag", "future_bag_keys", "hand", "hands", "hidden_owner",
	"ma" + "in", "method", "method_" + "name", "node", "opponent_hand",
	"opponent_slots", "owner", "owner_id", "owner_index", "personality_weight",
	"private_discard", "private_owner", "private_plan", "private_target", "resource",
	"rival_cash", "rival_hand", "rival_private", "rng_state", "route_plan",
	"save_payload", "sc" + "ore", "script_path", "seed", "supply_bag", "true_owner",
	"weight", "weights",
]


static func instance_state_error(instance: Dictionary) -> String:
	if not CARD_SEMANTIC_SCHEMA_V1.is_pure_data(instance) \
			or _contains_forbidden_observation_key(instance):
		return "invalid_instance_data"
	if not _allowed_and_required_keys(
		instance, INSTANCE_ALLOWED_KEYS, INSTANCE_REQUIRED_KEYS
	) or int(instance.get("schema_version", -1)) != SCHEMA_VERSION:
		return "invalid_instance_schema"
	if not _valid_stable_id(instance.get("instance_id")) \
			or not _valid_stable_id(instance.get("card_id")):
		return "invalid_instance_identity"
	if not (instance.get("source_slot") is int) \
			or int(instance.get("source_slot", -1)) < 0 \
			or not (instance.get("instance_revision") is int) \
			or int(instance.get("instance_revision", -1)) < 0:
		return "invalid_instance_revision"
	if not (instance.get("queued") is bool) or not (instance.get("locked") is bool):
		return "invalid_instance_state"
	var cooldown: Variant = instance.get("cooldown_remaining_seconds")
	if not (cooldown is int or cooldown is float) \
			or not is_finite(float(cooldown)) or float(cooldown) < 0.0:
		return "invalid_instance_cooldown"
	if instance.has("binding_refs") and not _valid_binding_refs(instance.get("binding_refs")):
		return "invalid_instance_bindings"
	return ""


static func instance_is_available(instance: Dictionary) -> bool:
	return not bool(instance.get("queued", false)) \
		and not bool(instance.get("locked", false)) \
		and float(instance.get("cooldown_remaining_seconds", 0.0)) <= 0.0


static func observation_error(observation: Dictionary) -> String:
	if not CARD_SEMANTIC_SCHEMA_V1.is_pure_data(observation) \
			or _contains_forbidden_observation_key(observation):
		return "invalid_world_data"
	if not _exact_keys(observation, OBSERVATION_KEYS) \
			or int(observation.get("schema_version", -1)) != SCHEMA_VERSION:
		return "invalid_world_schema"
	for key in ["projection_id", "viewer_actor_id", "card_id", "instance_id"]:
		if not _valid_stable_id(observation.get(key)):
			return "invalid_world_identity"
	if not _valid_revision(observation.get("source_revision")) \
			or not (observation.get("source_slot") is int) \
			or int(observation.get("source_slot", -1)) < 0 \
			or not (observation.get("instance_revision") is int) \
			or int(observation.get("instance_revision", -1)) < 0 \
			or not (observation.get("world_revision") is int) \
			or int(observation.get("world_revision", -1)) < 0:
		return "invalid_world_revision"
	if not _valid_fingerprint(observation.get("semantic_fingerprint")) \
			or not _valid_fingerprint(observation.get("projection_fingerprint")):
		return "invalid_world_fingerprint"
	if str(observation.get("projection_fingerprint", "")) != CARD_SEMANTIC_SCHEMA_V1.fingerprint(
		observation, "projection_fingerprint"
	):
		return "stale_projection_fingerprint"
	var source_kind := str(observation.get("source_kind", ""))
	var visibility_scope := str(observation.get("visibility_scope_id", ""))
	if not CARD_SEMANTIC_SCHEMA_V1.SOURCE_KINDS.has(source_kind):
		return "unauthorized_source_kind"
	if not (CARD_SEMANTIC_SCHEMA_V1.SOURCE_VISIBILITY_SCOPES.get(
		source_kind, []
	) as Array).has(visibility_scope):
		return "unauthorized_visibility_scope"
	var targets: Variant = observation.get("legal_targets")
	if not (targets is Array) or (targets as Array).is_empty() \
			or (targets as Array).size() > 64:
		return "invalid_legal_targets"
	var identities: Array[String] = []
	for target_variant in targets as Array:
		if not (target_variant is Dictionary):
			return "invalid_legal_target_row"
		var target := target_variant as Dictionary
		var target_error := _legal_target_error(target, observation)
		if not target_error.is_empty():
			return target_error
		var identity := target.get("target_identity", {}) as Dictionary
		var identity_key := "%s|%s" % [
			str(identity.get("target_id", "")), str(identity.get("stable_id", "")),
		]
		if identities.has(identity_key):
			return "invalid_duplicate_legal_target"
		identities.append(identity_key)
	return ""


static func cross_boundary_error(
	spec: Dictionary,
	instance: Dictionary,
	observation: Dictionary
) -> String:
	var identity := spec.get("identity", {}) as Dictionary
	var card_id := str(identity.get("card_id", ""))
	if str(instance.get("card_id", "")) != card_id \
			or str(observation.get("card_id", "")) != card_id:
		return "unauthorized_card_identity"
	if str(observation.get("semantic_fingerprint", "")) \
			!= str(spec.get("semantic_fingerprint", "")):
		return "stale_semantic_revision"
	if str(observation.get("instance_id", "")) != str(instance.get("instance_id", "")):
		return "unauthorized_instance_identity"
	if int(observation.get("source_slot", -1)) != int(instance.get("source_slot", -2)):
		return "stale_source_slot"
	if int(observation.get("instance_revision", -1)) \
			!= int(instance.get("instance_revision", -2)):
		return "stale_instance_revision"
	var timing_id := str((spec.get("timing", {}) as Dictionary).get("timing_id", ""))
	var source_kind := str(observation.get("source_kind", ""))
	if timing_id == "response_window" and source_kind != "response_window":
		return "unauthorized_response_source"
	if source_kind == "response_window" and timing_id != "response_window":
		return "unauthorized_main_action_source"
	if source_kind == "public_rack" \
			and not bool(identity.get("available_for_acquisition", false)):
		return "unauthorized_unavailable_acquisition"
	var target_id := str((spec.get("target", {}) as Dictionary).get("target_id", ""))
	for target_variant in observation.get("legal_targets", []) as Array:
		if str((target_variant as Dictionary).get("target_id", "")) != target_id:
			return "unauthorized_target_contract"
	var op_ids: Array[String] = []
	for op_variant in spec.get("effect_ops", []) as Array:
		op_ids.append(str((op_variant as Dictionary).get("op_id", "")))
	if op_ids.has("counter_action") and (
		op_ids.size() != 1
		or timing_id != "response_window"
		or target_id != "response.incoming_direct_interaction"
		or str((spec.get("response", {}) as Dictionary).get("response_id", "")) != "counter"
	):
		return "unauthorized_counter_contract"
	return ""


static func _legal_target_error(target: Dictionary, observation: Dictionary) -> String:
	if not _exact_keys(target, LEGAL_TARGET_KEYS) \
			or int(target.get("schema_version", -1)) != SCHEMA_VERSION:
		return "invalid_legal_target_schema"
	if str(target.get("status_id", "")) != "legal":
		return "unauthorized_legal_target_status"
	if not CARD_SEMANTIC_SCHEMA_V1.TARGET_IDS.has(str(target.get("target_id", ""))):
		return "invalid_legal_target_id"
	if target.get("source_revision") != observation.get("source_revision"):
		return "stale_legal_target_source_revision"
	if int(target.get("instance_revision", -1)) \
			!= int(observation.get("instance_revision", -2)):
		return "stale_legal_target_instance_revision"
	if int(target.get("world_revision", -1)) != int(observation.get("world_revision", -2)):
		return "stale_legal_target_world_revision"
	if not _valid_target_identity(target.get("target_identity"), str(target.get("target_id", ""))):
		return "invalid_target_identity"
	if not _valid_risk_index(target.get("uncertainty")) \
			or not _valid_risk_index(target.get("counter_risk")):
		return "invalid_target_risk"
	if not OUTCOME_VECTOR_V1.is_valid(target.get("outcome_adjustments")):
		return "invalid_target_outcomes"
	if not _valid_stable_id_array(target.get("explanation_tokens"), 32):
		return "invalid_target_explanations"
	if not _valid_fingerprint(target.get("legality_fingerprint")) \
			or str(target.get("legality_fingerprint", "")) \
				!= CARD_SEMANTIC_SCHEMA_V1.fingerprint(target, "legality_fingerprint"):
		return "stale_legality_fingerprint"
	return ""


static func _valid_binding_refs(value: Variant) -> bool:
	if not (value is Dictionary) \
			or (value as Dictionary).size() > CARD_SEMANTIC_SCHEMA_V1.TARGET_IDS.size():
		return false
	for key in (value as Dictionary).keys():
		if not CARD_SEMANTIC_SCHEMA_V1.TARGET_IDS.has(str(key)) \
				or not _valid_stable_id((value as Dictionary).get(key)):
			return false
	return true


static func _valid_target_identity(value: Variant, expected_target_id: String) -> bool:
	if not (value is Dictionary):
		return false
	var identity := value as Dictionary
	return _exact_keys(identity, TARGET_IDENTITY_KEYS) \
		and int(identity.get("schema_version", -1)) == SCHEMA_VERSION \
		and str(identity.get("target_id", "")) == expected_target_id \
		and _valid_stable_id(identity.get("stable_id"))


static func _contains_forbidden_observation_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).strip_edges().to_lower()
			if FORBIDDEN_OBSERVATION_KEYS.has(key) or key.contains("future_bag") \
					or key.contains("bag_order") or key.contains("hidden_owner") \
					or key.contains("rival_private"):
				return true
			if _contains_forbidden_observation_key((value as Dictionary).get(key_variant)):
				return true
	elif value is Array:
		for child in value as Array:
			if _contains_forbidden_observation_key(child):
				return true
	return false


static func _exact_keys(value: Dictionary, expected: Array) -> bool:
	return value.size() == expected.size() \
		and _allowed_and_required_keys(value, expected, expected)


static func _allowed_and_required_keys(
	value: Dictionary,
	allowed: Array,
	required: Array
) -> bool:
	for key in value.keys():
		if not allowed.has(str(key)):
			return false
	for key in required:
		if not value.has(str(key)):
			return false
	return true


static func _valid_stable_id(value: Variant) -> bool:
	return value is String and CARD_SEMANTIC_SCHEMA_V1.is_stable_id(value as String)


static func _valid_stable_id_array(value: Variant, maximum_size: int) -> bool:
	if not (value is Array) or (value as Array).size() > maximum_size:
		return false
	var seen: Array[String] = []
	for item in value as Array:
		if not _valid_stable_id(item) or seen.has(str(item)):
			return false
		seen.append(str(item))
	return true


static func _valid_fingerprint(value: Variant) -> bool:
	if not (value is String) or (value as String).length() != 64:
		return false
	for character in value as String:
		if not character in "0123456789abcdef":
			return false
	return true


static func _valid_revision(value: Variant) -> bool:
	return (value is int and int(value) >= 0) \
		or (value is String and (_valid_stable_id(value) or _valid_fingerprint(value)))


static func _valid_risk_index(value: Variant) -> bool:
	return value is int and int(value) >= 0 and int(value) <= 100
