extends RefCounted
class_name RecommendedRoleSet

var role_indices: Array = []


func apply_dictionary(data: Dictionary) -> RefCounted:
	role_indices = _int_array(data.get("role_indices", [0, 1, 2, 3]))
	return self


func to_dictionary() -> Dictionary:
	return {"role_indices": role_indices.duplicate(true)}


func _int_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			result.append(int(item))
	return result
