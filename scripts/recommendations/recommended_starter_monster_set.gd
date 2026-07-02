extends RefCounted
class_name RecommendedStarterMonsterSet

var starter_monster_indices: Array = []


func apply_dictionary(data: Dictionary) -> RefCounted:
	starter_monster_indices = _int_array(data.get("starter_monster_indices", [7, 6, 2, 4]))
	return self


func to_dictionary() -> Dictionary:
	return {"starter_monster_indices": starter_monster_indices.duplicate(true)}


func _int_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			result.append(int(item))
	return result
