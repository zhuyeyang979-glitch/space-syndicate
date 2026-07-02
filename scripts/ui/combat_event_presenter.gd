extends RefCounted
class_name CombatEventPresenter


static func military_fire(from_point: Vector2, to_point: Vector2, label: String = "命中") -> Dictionary:
	return {"type": "military_fire_line", "from": from_point, "to": to_point, "label": label, "event_class": "military_fire"}


static func target_arrow(from_point: Vector2, to_point: Vector2, valid: bool, label: String) -> Dictionary:
	return {"type": "target_arrow", "from": from_point, "to": to_point, "valid": valid, "label": label}
