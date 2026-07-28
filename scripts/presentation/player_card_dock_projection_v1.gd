extends RefCounted
class_name PlayerCardDockProjectionV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")

const SCHEMA_VERSION := 1
const CAPACITY_MODE_SHARED_V06 := "SHARED_V06"
const CAPACITY_MODE_INDEPENDENT_V07 := "INDEPENDENT_V07"
const RUNTIME_RULESET_V06 := "v0.6"
const RUNTIME_RULESET_V07 := "v0.7"
const CARD_LIMIT := 5

const FIELDS := [
	"schema_version",
	"viewer_index",
	"actor_id",
	"authorization_revision",
	"source_revision",
	"runtime_ruleset_id",
	"capacity_mode",
	"visibility_scope",
	"normal_cards",
	"commodity_cards",
	"bound_actions",
	"normal_count",
	"normal_limit",
	"commodity_count",
	"commodity_limit",
	"shared_capacity_count",
	"shared_capacity_limit",
	"projection_fingerprint",
]
const NORMAL_CARD_FIELDS := [
	"card_instance_id",
	"card_semantic_id",
	"display_name",
	"illustration_key",
	"category_id",
	"facility_kind",
	"industry_id",
	"rank",
	"play_state",
	"disabled_reason_id",
	"game_action_offer",
	"source_revision",
]
const COMMODITY_CARD_FIELDS := [
	"commodity_card_instance_id",
	"card_semantic_id",
	"commodity_id",
	"color_id",
	"level",
	"base_units",
	"display_name",
	"illustration_key",
	"play_state",
	"disabled_reason_id",
	"legal_target_summary",
	"game_action_offer",
	"source_revision",
]
const BOUND_ACTION_FIELDS := [
	"bound_action_instance_id",
	"action_semantic_id",
	"source_entity_id",
	"source_entity_kind",
	"display_name",
	"illustration_key",
	"action_class",
	"cooldown",
	"charges",
	"enabled",
	"disabled_reason_id",
	"game_action_offer",
	"source_revision",
]
const FORBIDDEN_KEYS := [
	"rival_hand",
	"rival_commodity_inventory",
	"rival_cash",
	"hidden_owner",
	"true_owner",
	"anonymous_true_player",
	"private_target_player_binding",
	"ai_plan",
	"ai_score",
	"learning_metadata",
	"decision_samples",
	"future_rack",
	"future_track_sequence",
	"rng_state",
	"node",
	"object",
	"resource",
	"callable",
	"node_path",
	"method_name",
]


static func build(unsealed: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) or unsealed.has("projection_fingerprint"):
		return {}
	var sealed := unsealed.duplicate(true)
	sealed["projection_fingerprint"] = WIRE.fingerprint(sealed)
	return sealed if bool(validation_report(sealed).get("valid", false)) else {}


static func detached_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) \
		if bool(validation_report(value).get("valid", false)) else {}


static func matches_viewer_authorization(
	value: Variant,
	viewer_index: int,
	authorization_revision: int
) -> bool:
	return viewer_index >= 0 and authorization_revision > 0 \
		and bool(validation_report(value).get("valid", false)) \
		and int((value as Dictionary).get("viewer_index", -1)) == viewer_index \
		and int((value as Dictionary).get("authorization_revision", 0)) \
		== authorization_revision


static func validation_report(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return _invalid("player_card_dock_projection_not_closed_data")
	var projection := value as Dictionary
	if not WIRE.exact_fields(projection, FIELDS):
		return _invalid("player_card_dock_projection_fields_invalid")
	if projection.get("schema_version") != SCHEMA_VERSION:
		return _invalid("player_card_dock_projection_schema_invalid")
	if not WIRE.is_nonnegative_integer(projection.get("viewer_index")) \
			or not WIRE.is_stable_id(projection.get("actor_id")) \
			or not WIRE.is_nonnegative_integer(projection.get("authorization_revision")) \
			or int(projection.get("authorization_revision", 0)) <= 0 \
			or not WIRE.is_nonnegative_integer(projection.get("source_revision")):
		return _invalid("player_card_dock_projection_identity_invalid")
	if str(projection.get("actor_id", "")) != "player.%d" % int(projection.get("viewer_index", -1)):
		return _invalid("player_card_dock_projection_actor_binding_invalid")
	var capacity_mode := str(projection.get("capacity_mode", ""))
	var ruleset_id := str(projection.get("runtime_ruleset_id", ""))
	if capacity_mode not in [CAPACITY_MODE_SHARED_V06, CAPACITY_MODE_INDEPENDENT_V07] \
			or ruleset_id not in [RUNTIME_RULESET_V06, RUNTIME_RULESET_V07] \
			or str(projection.get("visibility_scope", "")) != "viewer_private":
		return _invalid("player_card_dock_projection_scope_invalid")
	if capacity_mode == CAPACITY_MODE_SHARED_V06 and ruleset_id != RUNTIME_RULESET_V06:
		return _invalid("player_card_dock_projection_v06_mode_invalid")
	if capacity_mode == CAPACITY_MODE_INDEPENDENT_V07 and ruleset_id != RUNTIME_RULESET_V07:
		return _invalid("player_card_dock_projection_v07_mode_invalid")
	for key in ["normal_cards", "commodity_cards", "bound_actions"]:
		if not (projection.get(key) is Array):
			return _invalid("player_card_dock_projection_pool_invalid")
	if WIRE.contains_key_recursive(projection, FORBIDDEN_KEYS):
		return _invalid("player_card_dock_projection_forbidden_private_field")
	var normal_cards := projection.get("normal_cards") as Array
	var commodity_cards := projection.get("commodity_cards") as Array
	var bound_actions := projection.get("bound_actions") as Array
	var normal_ids: Array[String] = []
	for value_variant in normal_cards:
		var reason := _normal_card_error(value_variant)
		if not reason.is_empty():
			return _invalid(reason)
		var item_id := str((value_variant as Dictionary).get("card_instance_id", ""))
		if normal_ids.has(item_id):
			return _invalid("player_card_dock_normal_card_duplicate")
		normal_ids.append(item_id)
	var commodity_ids: Array[String] = []
	for value_variant in commodity_cards:
		var reason := _commodity_card_error(value_variant)
		if not reason.is_empty():
			return _invalid(reason)
		var item_id := str((value_variant as Dictionary).get("commodity_card_instance_id", ""))
		if commodity_ids.has(item_id) or normal_ids.has(item_id):
			return _invalid("player_card_dock_commodity_card_duplicate")
		commodity_ids.append(item_id)
	var bound_ids: Array[String] = []
	for value_variant in bound_actions:
		var reason := _bound_action_error(value_variant)
		if not reason.is_empty():
			return _invalid(reason)
		var item_id := str((value_variant as Dictionary).get("bound_action_instance_id", ""))
		if bound_ids.has(item_id) or normal_ids.has(item_id) or commodity_ids.has(item_id):
			return _invalid("player_card_dock_bound_action_duplicate")
		bound_ids.append(item_id)
	if not _capacity_is_valid(projection, normal_cards.size(), commodity_cards.size()):
		return _invalid("player_card_dock_projection_capacity_invalid")
	if not WIRE.is_fingerprint(projection.get("projection_fingerprint")) \
			or str(projection.get("projection_fingerprint", "")) \
			!= WIRE.fingerprint(projection, "projection_fingerprint"):
		return _invalid("player_card_dock_projection_fingerprint_invalid")
	return WIRE.valid_result()


static func _normal_card_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "player_card_dock_normal_card_not_closed"
	var card := value as Dictionary
	if not WIRE.exact_fields(card, NORMAL_CARD_FIELDS) \
			or not WIRE.is_stable_id(card.get("card_instance_id")) \
			or not WIRE.is_stable_id(card.get("card_semantic_id")) \
			or not (card.get("display_name") is String) \
			or not (card.get("illustration_key") is String) \
			or not WIRE.is_stable_id(card.get("category_id")) \
			or not WIRE.is_stable_id(card.get("facility_kind")) \
			or not WIRE.is_stable_id(card.get("industry_id")) \
			or not WIRE.is_positive_integer(card.get("rank")) \
			or str(card.get("play_state", "")) not in ["available", "disabled"] \
			or not WIRE.is_stable_id(card.get("disabled_reason_id")) \
			or not WIRE.is_nonnegative_integer(card.get("source_revision")):
		return "player_card_dock_normal_card_invalid"
	var offer_error := _offer_error(
		card.get("game_action_offer"),
		int(card.get("source_revision", -1))
	)
	if not offer_error.is_empty():
		return offer_error
	var offer := card.get("game_action_offer") as Dictionary
	if str(card.get("play_state", "")) != str(offer.get("legality_state", "")) \
			or str(card.get("disabled_reason_id", "")) \
			!= str(offer.get("disabled_reason_id", "")):
		return "player_card_dock_normal_card_offer_state_mismatch"
	return ""


static func _commodity_card_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "player_card_dock_commodity_card_not_closed"
	var card := value as Dictionary
	if not WIRE.exact_fields(card, COMMODITY_CARD_FIELDS) \
			or not WIRE.is_stable_id(card.get("commodity_card_instance_id")) \
			or not WIRE.is_stable_id(card.get("card_semantic_id")) \
			or not WIRE.is_stable_id(card.get("commodity_id")) \
			or not WIRE.is_stable_id(card.get("color_id")) \
			or not WIRE.is_positive_integer(card.get("level")) \
			or not WIRE.is_positive_integer(card.get("base_units")) \
			or not (card.get("display_name") is String) \
			or not (card.get("illustration_key") is String) \
			or str(card.get("play_state", "")) not in ["available", "disabled"] \
			or not WIRE.is_stable_id(card.get("disabled_reason_id")) \
			or not (card.get("legal_target_summary") is String) \
			or not WIRE.is_nonnegative_integer(card.get("source_revision")):
		return "player_card_dock_commodity_card_invalid"
	var offer_error := _offer_error(
		card.get("game_action_offer"),
		int(card.get("source_revision", -1))
	)
	if not offer_error.is_empty():
		return offer_error
	var offer := card.get("game_action_offer") as Dictionary
	if str(card.get("play_state", "")) != str(offer.get("legality_state", "")) \
			or str(card.get("disabled_reason_id", "")) \
			!= str(offer.get("disabled_reason_id", "")):
		return "player_card_dock_commodity_card_offer_state_mismatch"
	return ""


static func _bound_action_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "player_card_dock_bound_action_not_closed"
	var action := value as Dictionary
	if not WIRE.exact_fields(action, BOUND_ACTION_FIELDS) \
			or not WIRE.is_stable_id(action.get("bound_action_instance_id")) \
			or not WIRE.is_stable_id(action.get("action_semantic_id")) \
			or not WIRE.is_stable_id(action.get("source_entity_id")) \
			or str(action.get("source_entity_kind", "")) not in ["monster", "military"] \
			or not (action.get("display_name") is String) \
			or not (action.get("illustration_key") is String) \
			or not WIRE.is_stable_id(action.get("action_class")) \
			or not WIRE.is_nonnegative_integer(action.get("cooldown")) \
			or not WIRE.is_safe_integer(action.get("charges")) \
			or int(action.get("charges", -2)) < -1 \
			or not (action.get("enabled") is bool) \
			or not WIRE.is_stable_id(action.get("disabled_reason_id")) \
			or not WIRE.is_nonnegative_integer(action.get("source_revision")):
		return "player_card_dock_bound_action_invalid"
	var offer_error := _offer_error(
		action.get("game_action_offer"),
		int(action.get("source_revision", -1))
	)
	if not offer_error.is_empty():
		return offer_error
	var offer := action.get("game_action_offer") as Dictionary
	if bool(action.get("enabled", false)) \
			!= (str(offer.get("legality_state", "")) == "available") \
			or str(action.get("disabled_reason_id", "")) \
			!= str(offer.get("disabled_reason_id", "")):
		return "player_card_dock_bound_action_offer_state_mismatch"
	return ""


static func _offer_error(value: Variant, source_revision: int) -> String:
	var validation := OFFER.validation_report(value)
	if not bool(validation.get("valid", false)):
		return "player_card_dock_game_action_offer_invalid"
	var offer := value as Dictionary
	if int(offer.get("source_revision", -1)) != source_revision:
		return "player_card_dock_game_action_offer_revision_mismatch"
	if str(offer.get("semantic_action_id", "")) != INTENT.ACTION_CARD_PLAY:
		return "player_card_dock_game_action_offer_action_invalid"
	if str(offer.get("actor_scope", "")) != "authorized_actor":
		return "player_card_dock_game_action_offer_actor_scope_invalid"
	var target_spec := offer.get("public_or_private_target_spec") as Dictionary
	if str(target_spec.get("visibility_scope_id", "")) != "viewer_private":
		return "player_card_dock_game_action_offer_target_scope_invalid"
	var targets := OFFER.target_ids(offer)
	if targets.has("player_id"):
		return "player_card_dock_private_target_player_binding_forbidden"
	return ""


static func _capacity_is_valid(projection: Dictionary, normal_count: int, commodity_count: int) -> bool:
	for field in [
		"normal_count", "normal_limit", "commodity_count", "commodity_limit",
		"shared_capacity_count", "shared_capacity_limit",
	]:
		if not WIRE.is_nonnegative_integer(projection.get(field)):
			return false
	if int(projection.get("normal_count", -1)) != normal_count \
			or int(projection.get("commodity_count", -1)) != commodity_count \
			or int(projection.get("normal_limit", -1)) != CARD_LIMIT \
			or int(projection.get("commodity_limit", -1)) != CARD_LIMIT \
			or normal_count > CARD_LIMIT \
			or commodity_count > CARD_LIMIT:
		return false
	var aggregate_count := normal_count + commodity_count
	if int(projection.get("shared_capacity_count", -1)) != aggregate_count:
		return false
	return int(projection.get("shared_capacity_limit", -1)) == (
		CARD_LIMIT if str(projection.get("capacity_mode", "")) == CAPACITY_MODE_SHARED_V06 \
		else CARD_LIMIT * 2
	) and aggregate_count <= int(projection.get("shared_capacity_limit", -1))


static func _invalid(reason_id: String) -> Dictionary:
	return {"valid": false, "reason_id": reason_id}
