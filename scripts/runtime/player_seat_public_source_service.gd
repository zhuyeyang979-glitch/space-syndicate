@tool
extends Node
class_name PlayerSeatPublicSourceService

const PLAYER_COLORS: Array[Color] = [
	Color("#38bdf8"),
	Color("#f472b6"),
	Color("#facc15"),
	Color("#4ade80"),
	Color("#c084fc"),
	Color("#fb7185"),
	Color("#2dd4bf"),
	Color("#fb923c"),
]

var _cached_signature := ""
var _cached_sources: Array = []
var _last_public_revision := -1
var _compose_count := 0
var _rebuild_count := 0


func compose_sources(public_world: WorldSessionPublicProjection, local_player_index: int) -> Array:
	_compose_count += 1
	var players := public_world.players if public_world != null else []
	var public_revision := public_world.revision if public_world != null else 0
	var signature := _source_signature(players, local_player_index)
	_last_public_revision = public_revision
	if signature == _cached_signature:
		return _cached_sources.duplicate(true)
	_cached_signature = signature
	_cached_sources = _compose_uncached(players, local_player_index)
	_rebuild_count += 1
	return _cached_sources.duplicate(true)


func _compose_uncached(players: Array, local_player_index: int) -> Array:
	if players.size() < 3 or players.size() > 8 or local_player_index < 0:
		return []
	var result: Array = []
	var seen := {}
	var has_local_player := false
	for source_index in range(players.size()):
		var player: Dictionary = players[source_index] if players[source_index] is Dictionary else {}
		var player_index := int(player.get("player_index", source_index))
		if player_index < 0 or seen.has(player_index):
			return []
		seen[player_index] = true
		has_local_player = has_local_player or player_index == local_player_index
		result.append({
			"player_index": player_index,
			"public_player_name": str(player.get("public_player_name", "玩家%d" % (player_index + 1))),
			"role_name": str(player.get("role_name", "外星辛迪加")),
			"player_color": PLAYER_COLORS[wrapi(player_index, 0, PLAYER_COLORS.size())],
			"is_local_player": player_index == local_player_index,
			"public_status": _public_status(player),
			"is_publicly_active": false,
			"public_activity_is_anonymous": true,
		})
	return result if has_local_player else []


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": true,
		"uses_public_world_projection": true,
		"last_public_revision": _last_public_revision,
		"compose_count": _compose_count,
		"rebuild_count": _rebuild_count,
		"cached_seat_count": _cached_sources.size(),
		"references_main": false,
		"reads_private_cash": false,
		"reads_private_hand": false,
		"reads_hidden_owner": false,
		"reads_ai_plan": false,
	}


func _source_signature(players: Array, local_player_index: int) -> String:
	var rows: Array = []
	for source_index in range(players.size()):
		var player: Dictionary = players[source_index] if players[source_index] is Dictionary else {}
		rows.append({
			"player_index": int(player.get("player_index", source_index)),
			"public_player_name": str(player.get("public_player_name", "")),
			"role_name": str(player.get("role_name", "")),
			"public_status": str(player.get("public_status", "")),
			"eliminated": bool(player.get("eliminated", false)),
		})
	return JSON.stringify({"local_player_index": local_player_index, "players": rows})


func _public_status(player: Dictionary) -> StringName:
	if bool(player.get("eliminated", false)):
		return &"eliminated"
	var status := StringName(str(player.get("public_status", "ready")))
	return status if status in [&"ready", &"waiting", &"disconnected", &"eliminated"] else &"ready"
