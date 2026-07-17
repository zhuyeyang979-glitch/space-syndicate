extends RefCounted
class_name TablePresentationPureDataPolicy

const ALLOWED_SCALAR_TYPES := [
	TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME,
	TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_RECT2, TYPE_RECT2I, TYPE_COLOR,
]


static func is_pure_data(value: Variant) -> bool:
	var value_type := typeof(value)
	if ALLOWED_SCALAR_TYPES.has(value_type):
		return true
	if value_type == TYPE_ARRAY:
		for child in value as Array:
			if not is_pure_data(child):
				return false
		return true
	if value_type == TYPE_DICTIONARY:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String or key_variant is StringName or key_variant is int):
				return false
			if not is_pure_data((value as Dictionary)[key_variant]):
				return false
		return true
	return false


static func detached_copy(value: Variant) -> Variant:
	if not is_pure_data(value):
		return null
	if value is Dictionary:
		var result := {}
		for key_variant in (value as Dictionary).keys():
			result[key_variant] = detached_copy((value as Dictionary)[key_variant])
		return result
	if value is Array:
		var result: Array = []
		for child in value as Array:
			result.append(detached_copy(child))
		return result
	return value
