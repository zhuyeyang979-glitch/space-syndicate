extends RefCounted
class_name PlayerVisibleSurfacePolicy

const FORBIDDEN_KEYS := [
	"rival_hand",
	"rival_hand_count",
	"rival_discard",
	"rival_commodity_inventory",
	"rival_cash",
	"opponent_hand",
	"opponent_hand_count",
	"opponent_discard",
	"opponent_cash",
	"opponent_exact_cash",
	"private_hand",
	"private_discard",
	"exact_cash",
	"hidden_owner",
	"hidden_owner_id",
	"true_owner",
	"anonymous_true_player",
	"private_target_player_binding",
	"ai_plan",
	"ai_score",
	"learning_metadata",
	"decision_samples",
	"future_rack",
	"future_track_sequence",
	"rng_state",
	"runtime_instance_id",
	"node",
	"object",
	"resource",
	"callable",
	"node_path",
	"nodepath",
	"method_name",
]


static func is_safe_closed_data(value: Variant) -> bool:
	return TablePresentationPureDataPolicy.is_pure_data(value) \
		and _forbidden_path(value, "").is_empty()


static func exact_fields(value: Dictionary, expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true


static func forbidden_path(value: Variant) -> String:
	return _forbidden_path(value, "")


static func safe_text(value: Variant, fallback: String = "", max_length: int = 256) -> String:
	var normalized := str(value).replace("\n", " ").strip_edges()
	if normalized.is_empty():
		normalized = fallback
	return normalized.left(maxi(1, max_length))


static func _forbidden_path(value: Variant, path: String) -> String:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var normalized_key := key.strip_edges().to_lower()
			var child_path := key if path.is_empty() else "%s.%s" % [path, key]
			if normalized_key in FORBIDDEN_KEYS:
				return child_path
			var nested := _forbidden_path((value as Dictionary).get(key_variant), child_path)
			if not nested.is_empty():
				return nested
	elif value is Array:
		for index in range((value as Array).size()):
			var child_path := "[%d]" % index if path.is_empty() else "%s[%d]" % [path, index]
			var nested := _forbidden_path((value as Array)[index], child_path)
			if not nested.is_empty():
				return nested
	return ""
