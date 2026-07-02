extends RefCounted
class_name VisualEventSnapshot

const SUPPORTED_EVENT_TYPES := [
	"card_hover_glow",
	"card_pickup",
	"card_drag_valid",
	"card_drag_invalid",
	"card_play",
	"card_play_flyout",
	"card_reveal",
	"card_reveal_flash",
	"target_arrow",
	"monster_spawn",
	"monster_spawn_pulse",
	"monster_move",
	"monster_move_trail",
	"monster_attack",
	"monster_attack_windup",
	"monster_attack_impact",
	"city_damage",
	"city_damage_crack",
	"route_damage",
	"route_damage_spark",
	"military_fire",
	"military_fire_line",
	"cash_gain",
	"cash_gain_float",
	"gdp_delta",
	"gdp_delta_float",
	"final_countdown",
	"final_countdown_pulse",
]


static func normalize_events(events: Array) -> Array:
	var result: Array = []
	for event_variant in events:
		if event_variant is Dictionary:
			result.append(normalize_event(event_variant as Dictionary))
	return result


static func normalize_event(event_data: Dictionary) -> Dictionary:
	var event_type := str(event_data.get("type", "target_arrow")).strip_edges()
	if not SUPPORTED_EVENT_TYPES.has(event_type):
		event_type = "target_arrow"
	var from_point := _point_from(event_data.get("from", event_data.get("start", Vector2.ZERO)))
	var to_point := _point_from(event_data.get("to", event_data.get("end", from_point + Vector2(96, -64))))
	var at_point := _point_from(event_data.get("at", from_point.lerp(to_point, 0.5)))
	var progress := clampf(float(event_data.get("progress", 1.0)), 0.0, 1.0)
	return {
		"type": event_type,
		"event_class": _event_class(event_type),
		"from": from_point,
		"to": to_point,
		"at": at_point,
		"label": str(event_data.get("label", _default_label(event_type))),
		"reason": str(event_data.get("reason", "")),
		"valid": bool(event_data.get("valid", not event_type.contains("invalid"))),
		"progress": progress,
		"intensity": clampf(float(event_data.get("intensity", 1.0)), 0.0, 2.0),
		"duration": maxf(0.1, float(event_data.get("duration", 0.8))),
		"reduced_motion": bool(event_data.get("reduced_motion", false)),
	}


static func event_classes(events: Array) -> Array[String]:
	var classes: Array[String] = []
	for event_variant in events:
		if not (event_variant is Dictionary):
			continue
		var event_class := str((event_variant as Dictionary).get("event_class", _event_class(str((event_variant as Dictionary).get("type", "")))))
		if event_class != "" and not classes.has(event_class):
			classes.append(event_class)
	return classes


static func _point_from(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		var value_i: Vector2i = value
		return Vector2(value_i.x, value_i.y)
	if value is Array:
		var point_array: Array = value
		if point_array.size() >= 2:
			return Vector2(float(point_array[0]), float(point_array[1]))
	if value is Dictionary:
		var point_dict: Dictionary = value
		return Vector2(float(point_dict.get("x", 0.0)), float(point_dict.get("y", 0.0)))
	return Vector2.ZERO


static func _event_class(event_type: String) -> String:
	if event_type.begins_with("card_play"):
		return "card_play"
	if event_type.begins_with("card_reveal"):
		return "card_reveal"
	if event_type.begins_with("monster_spawn"):
		return "monster_spawn"
	if event_type.begins_with("monster_move"):
		return "monster_move"
	if event_type.begins_with("monster_attack"):
		return "monster_attack"
	if event_type.begins_with("city_damage"):
		return "city_damage"
	if event_type.begins_with("route_damage"):
		return "route_damage"
	if event_type.begins_with("military_fire"):
		return "military_fire"
	if event_type.begins_with("cash_gain"):
		return "cash_gain"
	if event_type.begins_with("gdp_delta"):
		return "gdp_delta"
	if event_type.begins_with("final_countdown"):
		return "final_countdown"
	return event_type


static func _default_label(event_type: String) -> String:
	match _event_class(event_type):
		"card_play":
			return "出牌"
		"card_reveal":
			return "公开"
		"monster_spawn":
			return "怪兽出现"
		"monster_move":
			return "移动"
		"monster_attack":
			return "攻击"
		"city_damage":
			return "城市受损"
		"route_damage":
			return "商路受损"
		"cash_gain":
			return "现金变化"
		"gdp_delta":
			return "GDP 变化"
		"final_countdown":
			return "终局"
	return "目标"
