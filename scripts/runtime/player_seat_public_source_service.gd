@tool
extends Node
class_name PlayerSeatPublicSourceService

var _world: Node


func bind_world(world: Node) -> void:
	_world = world


func compose_sources() -> Array:
	if _world == null or not is_instance_valid(_world):
		return []
	var players_variant: Variant = _world.get("players")
	var seat_count := (players_variant as Array).size() if players_variant is Array else 0
	if seat_count < 3 or seat_count > 8:
		return []
	var local_player_index := int(_safe_world_call(&"_local_human_player_index", [], 0))
	var result: Array = []
	for player_index in range(seat_count):
		var role_variant: Variant = _safe_world_call(&"_player_role_card_for_index", [player_index], {})
		var role: Dictionary = role_variant if role_variant is Dictionary else {}
		result.append({
			"player_index": player_index,
			"public_player_name": str(_safe_world_call(&"_player_name", [player_index], "玩家%d" % (player_index + 1))),
			"role_name": str(role.get("name", "外星辛迪加")),
			"player_color": _safe_world_call(&"_player_color", [player_index], Color.WHITE),
			"is_local_player": player_index == local_player_index,
			"public_status": &"eliminated" if bool(_safe_world_call(&"_player_is_eliminated", [player_index], false)) else &"ready",
			"is_publicly_active": false,
			"public_activity_is_anonymous": true,
		})
	return result


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _world != null and is_instance_valid(_world),
		"reads_public_accessors_only": true,
		"reads_private_cash": false,
		"reads_private_hand": false,
		"reads_hidden_owner": false,
		"reads_ai_plan": false,
	}


func _safe_world_call(method: StringName, args: Array, fallback: Variant) -> Variant:
	if _world == null or not _world.has_method(method):
		return fallback
	return _world.callv(method, args)
