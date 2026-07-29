extends RefCounted
class_name PublicPlayerRosterProjectionV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

const SCHEMA_VERSION := 1
const MAX_PLAYER_COUNT := 8

const FIELDS := [
	"schema_version",
	"viewer_index",
	"authorization_revision",
	"source_revision",
	"players",
	"projection_fingerprint",
]
const PLAYER_FIELDS := [
	"player_id",
	"public_order_index",
	"display_name",
	"role_display_name",
	"avatar_key",
	"accent",
	"public_status",
	"is_local_player",
	"is_eliminated",
	"is_inspected",
	"submission_lock_public_state",
]
const FORBIDDEN_KEYS := [
	"cash",
	"cash_cents",
	"exact_gdp_private_data",
	"normal_hand",
	"hand",
	"private_hand",
	"commodity_inventory",
	"bound_actions",
	"ai_plan",
	"hidden_owner",
	"hidden_lead",
	"private_target",
	"future_submission",
	"future_rack",
	"future_track_sequence",
	"rng_state",
	"node",
	"object",
	"resource",
	"callable",
	"node_path",
	"nodepath",
	"method",
	"method_name",
	"callback",
]


static func build(unsealed: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) or unsealed.has("projection_fingerprint"):
		return {}
	var sealed := WIRE.sealed_copy(unsealed, "projection_fingerprint")
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
		return _invalid("public_player_roster_projection_not_closed_data")
	var projection := value as Dictionary
	if not WIRE.exact_fields(projection, FIELDS):
		return _invalid("public_player_roster_projection_fields_invalid")
	if projection.get("schema_version") != SCHEMA_VERSION:
		return _invalid("public_player_roster_projection_schema_invalid")
	if not WIRE.is_nonnegative_integer(projection.get("viewer_index")) \
			or not WIRE.is_positive_integer(projection.get("authorization_revision")) \
			or not WIRE.is_nonnegative_integer(projection.get("source_revision")):
		return _invalid("public_player_roster_projection_binding_invalid")
	if not (projection.get("players") is Array):
		return _invalid("public_player_roster_projection_players_invalid")
	if WIRE.contains_key_recursive(projection, FORBIDDEN_KEYS):
		return _invalid("public_player_roster_projection_forbidden_field")
	var players := projection.get("players") as Array
	if players.size() > MAX_PLAYER_COUNT:
		return _invalid("public_player_roster_projection_player_count_invalid")
	var player_ids: Array[String] = []
	var order_indices: Array[int] = []
	var local_count := 0
	var inspected_count := 0
	var previous_order := -1
	for player_variant in players:
		var player_error := _player_error(player_variant)
		if not player_error.is_empty():
			return _invalid(player_error)
		var player := player_variant as Dictionary
		var player_id := str(player.get("player_id", ""))
		var order_index := int(player.get("public_order_index", -1))
		if player_ids.has(player_id) or order_indices.has(order_index):
			return _invalid("public_player_roster_projection_player_duplicate")
		if order_index <= previous_order:
			return _invalid("public_player_roster_projection_order_invalid")
		player_ids.append(player_id)
		order_indices.append(order_index)
		previous_order = order_index
		if bool(player.get("is_local_player", false)):
			local_count += 1
			if player_id != "player.%d" % int(projection.get("viewer_index", -1)):
				return _invalid("public_player_roster_projection_local_binding_invalid")
		if bool(player.get("is_inspected", false)):
			inspected_count += 1
	if local_count > 1 or inspected_count > 1:
		return _invalid("public_player_roster_projection_single_selection_invalid")
	if not WIRE.is_fingerprint(projection.get("projection_fingerprint")) \
			or str(projection.get("projection_fingerprint", "")) \
			!= WIRE.fingerprint(projection, "projection_fingerprint"):
		return _invalid("public_player_roster_projection_fingerprint_invalid")
	return WIRE.valid_result()


static func _player_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "public_player_roster_projection_player_not_closed"
	var player := value as Dictionary
	if not WIRE.exact_fields(player, PLAYER_FIELDS):
		return "public_player_roster_projection_player_fields_invalid"
	if not WIRE.is_stable_id(player.get("player_id")) \
			or not WIRE.is_nonnegative_integer(player.get("public_order_index")) \
			or not _display_text(player.get("display_name"), false, 160) \
			or not _display_text(player.get("role_display_name"), false, 160) \
			or not _display_text(player.get("avatar_key"), false, 160) \
			or not _display_text(player.get("accent"), false, 80) \
			or not WIRE.is_stable_id(player.get("public_status")) \
			or not (player.get("is_local_player") is bool) \
			or not (player.get("is_eliminated") is bool) \
			or not (player.get("is_inspected") is bool) \
			or not WIRE.is_stable_id(player.get("submission_lock_public_state")):
		return "public_player_roster_projection_player_invalid"
	return ""


static func _display_text(value: Variant, allow_empty: bool, max_length: int) -> bool:
	return value is String and (allow_empty or not str(value).is_empty()) \
		and str(value).length() <= max_length


static func _invalid(reason_id: String) -> Dictionary:
	return WIRE.invalid_result(reason_id)
