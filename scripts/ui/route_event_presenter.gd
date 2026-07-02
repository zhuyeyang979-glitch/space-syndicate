extends RefCounted
class_name RouteEventPresenter


static func route_damage(from_point: Vector2, to_point: Vector2, label: String = "商路受损") -> Dictionary:
	return {"type": "route_damage_spark", "from": from_point, "to": to_point, "label": label, "event_class": "route_damage"}
