@tool
extends Node
class_name PlayerRosterViewerQueryPort

const PROJECTION := preload("res://scripts/presentation/player_roster_projection_v1.gd")
const PLAYER_COLORS := [
	Color("#38bdf8"), Color("#f472b6"), Color("#facc15"), Color("#4ade80"),
	Color("#c084fc"), Color("#fb7185"), Color("#2dd4bf"), Color("#fb923c"),
]

var _ports: TablePresentationQueryPorts
var _query_count := 0
var _accepted_count := 0
var _rejected_count := 0


func configure(ports: TablePresentationQueryPorts) -> void:
	_ports = ports


func snapshot_for_viewer(viewer_index: int, expected_authorization_revision: int = -1) -> Dictionary:
	_query_count += 1
	if _ports == null:
		return _reject()
	var context := _ports.viewer_context()
	if context == null or not context.authorized or context.viewer_index != viewer_index \
			or (expected_authorization_revision >= 0 \
				and expected_authorization_revision != context.authorization_revision):
		return _reject()
	var public_projection := _ports.public_world_projection()
	if public_projection == null or public_projection.players.size() < 3 \
			or public_projection.players.size() > 8:
		return _reject()
	var rows: Array = []
	for public_order_index in range(public_projection.players.size()):
		var source_variant: Variant = public_projection.players[public_order_index]
		if not (source_variant is Dictionary):
			return _reject()
		var source := source_variant as Dictionary
		var player_index := int(source.get("player_index", -1))
		if player_index < 0:
			return _reject()
		rows.append({
			"player_index": player_index,
			"public_order_index": public_order_index,
			"public_player_name": str(source.get("public_player_name", "玩家%d" % (player_index + 1))),
			"role_name": str(source.get("role_name", "外星辛迪加")),
			"player_color": PLAYER_COLORS[wrapi(player_index, 0, PLAYER_COLORS.size())],
			"is_local_player": player_index == viewer_index,
			"public_status": "eliminated" if bool(source.get("eliminated", false)) else "ready",
			"is_publicly_active": false,
			"public_activity_is_anonymous": true,
		})
	var result := PROJECTION.build({
		"schema_version": PROJECTION.SCHEMA_VERSION,
		"source_revision": maxi(0, public_projection.revision),
		"viewer_index": viewer_index,
		"authorization_revision": context.authorization_revision,
		"visibility_scope": "viewer_scoped_public",
		"players": rows,
	})
	if result.is_empty():
		return _reject()
	_accepted_count += 1
	return result


func debug_snapshot() -> Dictionary:
	return {
		"configured": _ports != null,
		"query_count": _query_count,
		"accepted_count": _accepted_count,
		"rejected_count": _rejected_count,
		"viewer_authorized": true,
		"reads_private_state": false,
		"mutates_gameplay": false,
		"references_main": false,
	}


func _reject() -> Dictionary:
	_rejected_count += 1
	return {}
