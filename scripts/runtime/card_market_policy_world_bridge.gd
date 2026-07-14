@tool
extends Node
class_name CardMarketPolicyWorldBridge

var _world: Node
var _capture_count := 0


func bind_world(world: Node) -> void:
	_world = world


func has_world() -> bool:
	return _world != null and is_instance_valid(_world)


func capture_market_facts(source_district_index: int) -> Dictionary:
	_capture_count += 1
	if not has_world():
		return {}
	var districts_variant: Variant = _world.get("districts")
	if not (districts_variant is Array):
		return {}
	var districts := districts_variant as Array
	if source_district_index < 0 or source_district_index >= districts.size() or not (districts[source_district_index] is Dictionary):
		return {}
	var district := districts[source_district_index] as Dictionary
	var center_variant: Variant = district.get("center", Vector2.ZERO)
	var center := center_variant as Vector2 if center_variant is Vector2 else Vector2.ZERO
	var monsters: Array = []
	var monster_controller_variant: Variant = _world.get("monster_runtime_controller")
	var monster_controller := monster_controller_variant as Node if monster_controller_variant is Node else null
	var roster_variant: Variant = monster_controller.call("roster_snapshot", false) if monster_controller != null and monster_controller.has_method("roster_snapshot") else []
	var roster: Array = roster_variant if roster_variant is Array else []
	for actor_variant: Variant in roster:
		if not (actor_variant is Dictionary):
			continue
		var actor := actor_variant as Dictionary
		var fact := {
			"district_index": int(actor.get("district_index", actor.get("position", -1))),
			"down": bool(actor.get("down", false)),
		}
		if actor.has("remaining_time"):
			fact["remaining_time"] = float(actor.get("remaining_time", 0.0))
		monsters.append(fact)
	return {
		"source_district_index": source_district_index,
		"source_center_x": center.x,
		"world_width": float(_world.get("map_width_m")),
		"source_destroyed": bool(district.get("destroyed", false)),
		"direct_neighbors": (district.get("neighbors", []) as Array).duplicate() if district.get("neighbors", []) is Array else [],
		"monsters": monsters,
	}


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": has_world(),
		"capture_count": _capture_count,
		"owns_world_state": false,
		"camera_fields_read": false,
		"private_player_fields_read": false,
		"monster_owner_fields_read": false,
	}
