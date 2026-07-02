extends RefCounted
class_name MonsterEventPresenter


static func monster_spawn(at_point: Vector2, label: String = "怪兽出现") -> Dictionary:
	return {"type": "monster_spawn_pulse", "at": at_point, "label": label, "event_class": "monster_spawn"}


static func monster_move(from_point: Vector2, to_point: Vector2, label: String = "怪兽移动") -> Dictionary:
	return {"type": "monster_move_trail", "from": from_point, "to": to_point, "label": label, "event_class": "monster_move"}


static func monster_attack(from_point: Vector2, to_point: Vector2, frame: int = 0) -> Dictionary:
	var event_type := "monster_attack_windup" if frame <= 0 else "monster_attack_impact"
	return {"type": event_type, "from": from_point, "to": to_point, "label": "怪兽攻击", "event_class": "monster_attack", "progress": clampf(float(frame) / 24.0, 0.0, 1.0)}
