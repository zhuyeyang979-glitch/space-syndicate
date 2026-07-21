@tool
extends Node
class_name WorldSessionPresentationQuery

const PUBLIC_PLAYER_KEYS := ["name", "seat_type", "role_index", "role_card", "eliminated", "eliminated_at", "elimination_reason"]
const PRIVATE_CARD_KEYS := [
	"name",
	"kind",
	"rank",
	"price",
	"target_type",
	"cooldown",
	"cooldown_left",
	"family_id",
	"card_id",
	"persistent",
	"queued_for_resolution",
	"lock_left",
]
const PRIVATE_PLAYER_KEYS := ["cash", "cash_cents", "city_guesses", "city_guess_confidence", "city_guess_reasons", "known_card_owners", "eliminated"]

var _world_session_state: WorldSessionState
var _authorization: LocalViewerAuthorization
var _revision := 0
var _last_public_fingerprint := ""


func configure(world_session_state: WorldSessionState, authorization: LocalViewerAuthorization) -> void:
	_world_session_state = world_session_state
	_authorization = authorization


func public_projection() -> WorldSessionPublicProjection:
	var projection := WorldSessionPublicProjection.new()
	if _world_session_state == null:
		return projection
	var players: Array = []
	for index in range(_world_session_state.players.size()):
		var source: Dictionary = _world_session_state.players[index] if _world_session_state.players[index] is Dictionary else {}
		var row := _allowlist(source, PUBLIC_PLAYER_KEYS)
		row["player_index"] = index
		row["public_player_name"] = str(source.get("name", "玩家%d" % (index + 1)))
		row["role_name"] = str((source.get("role_card", {}) as Dictionary).get("name", "")) if source.get("role_card", {}) is Dictionary else ""
		row.erase("role_card")
		if TablePresentationPureDataPolicy.is_pure_data(row):
			players.append(TablePresentationPureDataPolicy.detached_copy(row))
	var districts: Array = []
	for index in range(_world_session_state.districts.size()):
		var source: Dictionary = _world_session_state.districts[index] if _world_session_state.districts[index] is Dictionary else {}
		var district := _public_district(source, index)
		if TablePresentationPureDataPolicy.is_pure_data(district):
			districts.append(TablePresentationPureDataPolicy.detached_copy(district))
	var fingerprint := JSON.stringify([players, districts, _world_session_state.game_time])
	if fingerprint != _last_public_fingerprint:
		_last_public_fingerprint = fingerprint
		_revision += 1
	projection.revision = _revision
	projection.game_time = _world_session_state.game_time
	projection.players = players
	projection.districts = districts
	return projection


func private_projection(viewer_index: int, subject_index: int) -> WorldSessionPrivateProjection:
	var projection := WorldSessionPrivateProjection.new()
	projection.viewer_index = viewer_index
	projection.subject_index = subject_index
	var context := _authorization.context() if _authorization != null else TablePresentationViewerContext.denied()
	projection.authorization_revision = context.authorization_revision
	if _world_session_state == null \
		or _authorization == null \
		or not _authorization.can_view_subject(viewer_index, subject_index) \
		or subject_index < 0 \
		or subject_index >= _world_session_state.players.size():
		return projection
	var source: Dictionary = _world_session_state.players[subject_index] if _world_session_state.players[subject_index] is Dictionary else {}
	var player := _allowlist(source, PRIVATE_PLAYER_KEYS)
	player["player_index"] = subject_index
	player["public_player_name"] = str(source.get("name", "玩家%d" % (subject_index + 1)))
	player["hand"] = _private_hand(source.get("slots", []))
	player["discard"] = _private_hand(source.get("discard", source.get("discarded_cards", [])))
	if not TablePresentationPureDataPolicy.is_pure_data(player):
		return projection
	projection.authorized = true
	projection.player = TablePresentationPureDataPolicy.detached_copy(player)
	return projection


func public_map_geometry_projection() -> WorldMapGeometryProjection:
	var projection := WorldMapGeometryProjection.new()
	if _world_session_state == null:
		return projection
	var geometry := _world_session_state.public_world_geometry_snapshot()
	projection.revision = int(geometry.get("revision", 0))
	projection.width_m = maxf(1.0, float(geometry.get("width_m", 1.0)))
	projection.height_m = maxf(1.0, float(geometry.get("height_m", 1.0)))
	projection.world_rect = Rect2(Vector2.ZERO, Vector2(projection.width_m, projection.height_m))
	return projection


func public_player_name(player_index: int) -> String:
	if _world_session_state == null or player_index < 0 or player_index >= _world_session_state.players.size():
		return "玩家%d" % (player_index + 1)
	var player: Dictionary = _world_session_state.players[player_index] if _world_session_state.players[player_index] is Dictionary else {}
	return str(player.get("name", "玩家%d" % (player_index + 1)))


func public_participant_names() -> Dictionary:
	var result := {}
	if _world_session_state == null:
		return result
	for player_index in range(_world_session_state.players.size()):
		result[str(player_index)] = public_player_name(player_index)
	return result


func debug_snapshot() -> Dictionary:
	return {
		"configured": _world_session_state != null and _authorization != null,
		"revision": _revision,
		"public_projection_is_allowlisted": true,
		"private_projection_requires_viewer_equals_subject": true,
		"mutable_world_collections_exposed": false,
	}


func _public_district(source: Dictionary, index: int) -> Dictionary:
	var row := {
		"region_index": index,
		"region_id": str(source.get("region_id", "region.%03d" % index)),
		"name": str(source.get("name", "区域%d" % (index + 1))),
		"center": source.get("center", Vector2.ZERO),
		"polygon": (source.get("polygon", []) as Array).duplicate(true) if source.get("polygon", []) is Array else [],
		"area_m2": float(source.get("area_m2", 0.0)),
		"radius_m": float(source.get("radius_m", 0.0)),
		"destroyed": bool(source.get("destroyed", false)),
		"miasma": bool(source.get("miasma", false)),
		"terrain": str(source.get("terrain", "land")),
		"terrain_label": str(source.get("terrain_label", "陆地")),
		"products": _string_array(source.get("products", [])),
		"demands": _string_array(source.get("demands", [])),
		"neighbors": _int_array(source.get("neighbors", [])),
		"transport_score": float(source.get("transport_score", 0.0)),
		"damage": int(source.get("damage", 0)),
	}
	var city: Dictionary = source.get("city", {}) if source.get("city", {}) is Dictionary else {}
	row["city"] = {
		"present": not city.is_empty(),
		"active": bool(city.get("active", true)) if not city.is_empty() else false,
		"level": int(city.get("level", 0)),
		"products": _string_array(city.get("products", [])),
		"demands": _string_array(city.get("demands", [])),
		"last_income": int(city.get("last_income", 0)),
		"competition_matches": int(city.get("competition_matches", 0)),
	}
	return row


func _private_hand(value: Variant) -> Array:
	var source: Array = value if value is Array else []
	var result: Array = []
	for slot_index in range(source.size()):
		if not (source[slot_index] is Dictionary):
			continue
		var card := _allowlist(source[slot_index] as Dictionary, PRIVATE_CARD_KEYS)
		card["slot_index"] = slot_index
		result.append(card)
	return result


func _allowlist(source: Dictionary, keys: Array) -> Dictionary:
	var result := {}
	for key_variant in keys:
		var key := str(key_variant)
		if source.has(key):
			result[key] = _safe_copy(source[key])
	return result


func _safe_copy(value: Variant) -> Variant:
	return TablePresentationPureDataPolicy.detached_copy(value)


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for entry in value:
			var text := str(entry).strip_edges()
			if not text.is_empty():
				result.append(text)
	return result


func _int_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for entry in value:
			result.append(int(entry))
	return result
