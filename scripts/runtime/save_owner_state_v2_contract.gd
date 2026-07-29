extends RefCounted
class_name SaveOwnerStateV2Contract

const RNG_CONTINUATION_KEYS := [
	"rng",
	"rng_state",
	"rng_cursor",
	"rng_seed",
	"random_number_generator",
]


static func has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in expected:
		if not value.has(str(key_variant)):
			return false
	return true


static func is_codec_data(value: Variant) -> bool:
	if value == null or value is String or value is bool or value is int:
		return true
	if value is float:
		return is_finite(float(value))
	if value is Vector2:
		var vector := value as Vector2
		return is_finite(vector.x) and is_finite(vector.y)
	if value is Color:
		var color := value as Color
		return is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a)
	if value is Array:
		for item_variant in value as Array:
			if not is_codec_data(item_variant):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String or key_variant is StringName) \
					or not is_codec_data((value as Dictionary)[key_variant]):
				return false
		return true
	return false


static func contains_rng_continuation(value: Variant) -> bool:
	if value is Array:
		for item_variant in value as Array:
			if contains_rng_continuation(item_variant):
				return true
	elif value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).strip_edges().to_lower()
			if RNG_CONTINUATION_KEYS.has(key) or key.begins_with("rng_"):
				return true
			if contains_rng_continuation((value as Dictionary)[key_variant]):
				return true
	return false


static func fingerprint(value: Variant) -> String:
	return JSON.stringify(canonicalize(value)).sha256_text()


static func canonicalize(value: Variant) -> Variant:
	if value is Vector2:
		var vector := value as Vector2
		return {"$type": "Vector2", "x": vector.x, "y": vector.y}
	if value is Color:
		var color := value as Color
		return {"$type": "Color", "a": color.a, "b": color.b, "g": color.g, "r": color.r}
	if value is Array:
		var canonical_array: Array = []
		for item_variant in value as Array:
			canonical_array.append(canonicalize(item_variant))
		return canonical_array
	if value is Dictionary:
		var canonical_dictionary: Dictionary = {}
		var keys: Array[String] = []
		for key_variant in (value as Dictionary).keys():
			keys.append(str(key_variant))
		keys.sort()
		for key in keys:
			canonical_dictionary[key] = canonicalize((value as Dictionary).get(key))
		return canonical_dictionary
	return value
