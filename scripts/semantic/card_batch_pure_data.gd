@tool
extends RefCounted
class_name CardBatchPureData

const FORBIDDEN_RUNTIME_KEY_FRAGMENTS := [
	"node", "object", "callable", "resource", "scene", "viewport",
	"engine_frame", "engine_time", "presentation_time",
]
const RETIRED_COUNTER_KEYS := [
	"counter_stack", "counter_window", "pending_counter_input",
	"pending_counter_decision", "counter_submission_queue",
]
const RETIRED_COUNTER_SYMBOLS := [
	"counter", "counter_window", "counter_stack", "pending_counter_input",
	"pending_counter_decision", "forced_card_response",
	"mid_resolution_card_submission",
]
const RETIRED_COUNTER_PREFIXES := [
	"card_counter", "counter_check", "counter_pass", "counter_play",
	"counter_window", "counter_stack", "pending_counter_input",
	"pending_counter_decision", "counter_submission_queue",
]


static func is_pure_json_data(value: Variant) -> bool:
	if value is Object or value is Callable:
		return false
	if value is float:
		return is_finite(value)
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if not (key is String or key is StringName):
				return false
			if not is_pure_json_data((value as Dictionary).get(key)):
				return false
		return true
	if value is Array:
		for item in value as Array:
			if not is_pure_json_data(item):
				return false
		return true
	return typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]


static func canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array[String] = []
		for key in source.keys():
			keys.append(str(key))
		keys.sort()
		var result := {}
		for key in keys:
			result[key] = canonicalize(source.get(key))
		return result
	if value is Array:
		var result: Array = []
		for item in value as Array:
			result.append(canonicalize(item))
		return result
	if value is StringName:
		return String(value)
	# JSON has one numeric production grammar. Godot may restore an integral JSON
	# token as float, so canonical identity deliberately folds exact integral
	# floats back to integers. This keeps save/load from changing fingerprints.
	if value is float and is_finite(value) and value == floor(value) and absf(value) <= 9_007_199_254_740_991.0:
		return int(value)
	return value


static func stable_serialize(value: Variant) -> String:
	if not is_pure_json_data(value):
		return ""
	return JSON.stringify(canonicalize(value))


static func stable_fingerprint(value: Variant) -> String:
	var serialized := stable_serialize(value)
	return serialized.sha256_text() if not serialized.is_empty() else ""


static func duplicate_pure(value: Variant) -> Variant:
	if not is_pure_json_data(value):
		return null
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


static func first_forbidden_runtime_key(value: Variant, path: String = "root") -> String:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var lowered := key.to_lower()
			for fragment in FORBIDDEN_RUNTIME_KEY_FRAGMENTS:
				if lowered == fragment or lowered.ends_with("_%s" % fragment):
					return "%s.%s" % [path, key]
			var nested := first_forbidden_runtime_key((value as Dictionary).get(key_variant), "%s.%s" % [path, key])
			if not nested.is_empty():
				return nested
	elif value is Array:
		for index in range((value as Array).size()):
			var nested := first_forbidden_runtime_key((value as Array)[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
	return ""


static func first_retired_counter_key(value: Variant, path: String = "root") -> String:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if key.to_lower() in RETIRED_COUNTER_KEYS or _is_retired_counter_symbol(key):
				return "%s.%s" % [path, key]
			var nested := first_retired_counter_key((value as Dictionary).get(key_variant), "%s.%s" % [path, key])
			if not nested.is_empty():
				return nested
	elif value is Array:
		for index in range((value as Array).size()):
			var nested := first_retired_counter_key((value as Array)[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
	elif value is String or value is StringName:
		if _is_retired_counter_symbol(str(value)):
			return path
	return ""


static func _is_retired_counter_symbol(value: String) -> bool:
	var normalized := value.strip_edges().to_lower()
	for separator in ["-", " ", ".", ":", "/", "\\"]:
		normalized = normalized.replace(separator, "_")
	while normalized.contains("__"):
		normalized = normalized.replace("__", "_")
	if normalized in RETIRED_COUNTER_SYMBOLS:
		return true
	for prefix in RETIRED_COUNTER_PREFIXES:
		if normalized == prefix or normalized.begins_with("%s_" % prefix):
			return true
	return false


static func has_exact_keys(value: Dictionary, expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true


static func string_array(value: Variant, reject_duplicates: bool = false) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for item in value as Array:
		var text := str(item)
		if text.is_empty() or (reject_duplicates and text in result):
			continue
		result.append(text)
	return result
