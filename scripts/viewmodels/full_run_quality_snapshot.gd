extends RefCounted
class_name FullRunQualitySnapshot

const SCHEMA_VERSION := 1
const MAX_EVENT_LENGTH := 96
const VALID_PHASE_PREFIXES := [
	"setup",
	"first_run",
	"decision_window",
	"play",
	"qualification",
	"audit",
	"settlement",
	"finished",
	"blocked",
]
const FORBIDDEN_INPUT_KEYS := [
	"players",
	"cash",
	"cash_cents",
	"hand",
	"slots",
	"discard",
	"owner",
	"owner_id",
	"owner_player_index",
	"hidden_owner",
	"city_guesses",
	"ai_memory",
	"ai_plan",
	"utility_scores",
	"raw_envelope",
	"envelope",
]
const PUBLIC_KEYS := [
	"schema",
	"valid",
	"seed",
	"phase",
	"elapsed",
	"progress",
	"decision_window",
	"settlement",
	"invalid_actions",
	"nonfinite",
	"last_event",
]


static func compose(source: Dictionary) -> Dictionary:
	var seed_value := int(source.get("seed", 0))
	if not _is_data_only(source) or _contains_forbidden_key(source):
		return _invalid_snapshot(seed_value, "telemetry_input_not_public")
	var elapsed_source: Dictionary = _dictionary(source.get("elapsed", {}))
	var decision_source: Dictionary = _dictionary(source.get("decision_window", {}))
	var progress_source: Dictionary = _dictionary(source.get("progress", {}))
	var settlement_source: Dictionary = _dictionary(source.get("settlement", {}))
	var invalid_source: Dictionary = _dictionary(source.get("invalid_actions", {}))
	var observed_public_facts: Variant = source.get("observed_public_facts", {})
	var nonfinite_paths: Array[String] = []
	_collect_nonfinite_paths(observed_public_facts, "public", nonfinite_paths)
	var phase := _normalized_phase(str(source.get("phase", "blocked")))
	return {
		"schema": SCHEMA_VERSION,
		"valid": true,
		"seed": seed_value,
		"phase": phase,
		"elapsed": {
			"wall_seconds": maxf(0.0, float(elapsed_source.get("wall_seconds", 0.0))),
			"world_seconds": maxf(0.0, float(elapsed_source.get("world_seconds", 0.0))),
		},
		"progress": {
			"controlled_region_count": maxi(0, int(progress_source.get("controlled_region_count", 0))),
			"required_region_count": maxi(0, int(progress_source.get("required_region_count", 0))),
			"top_k_gdp_per_minute": maxi(0, int(progress_source.get("top_k_gdp_per_minute", 0))),
			"required_top_k_gdp_per_minute": maxi(0, int(progress_source.get("required_top_k_gdp_per_minute", 0))),
			"owned_facility_count": maxi(0, int(progress_source.get("owned_facility_count", 0))),
			"eligible": bool(progress_source.get("eligible", false)),
		},
		"decision_window": {
			"active": bool(decision_source.get("active", false)),
			"kind": _safe_token(str(decision_source.get("kind", "none"))),
			"priority_group": _safe_token(str(decision_source.get("priority_group", ""))),
			"blocks_global_time": bool(decision_source.get("blocks_global_time", false)),
			"blocks_player_actions": bool(decision_source.get("blocks_player_actions", false)),
			"visible_to_scripted_player": bool(decision_source.get("visible_to_scripted_player", true)),
		},
		"settlement": {
			"state": _safe_token(str(settlement_source.get("state", "idle"))),
			"completed": bool(settlement_source.get("completed", false)),
			"outcome_id": _safe_token(str(settlement_source.get("outcome_id", ""))),
			"reason_code": _safe_token(str(settlement_source.get("reason_code", ""))),
			"winner_count": maxi(0, int(settlement_source.get("winner_count", 0))),
			"presentation_ready": bool(settlement_source.get("presentation_ready", false)),
		},
		"invalid_actions": {
			"count": maxi(0, int(invalid_source.get("count", 0))),
			"last_reason_code": _safe_token(str(invalid_source.get("last_reason_code", ""))),
		},
		"nonfinite": {
			"count": nonfinite_paths.size(),
			"paths": nonfinite_paths,
		},
		"last_event": _safe_event(str(source.get("last_event", ""))),
	}


static func public_contract() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"public_keys": PUBLIC_KEYS.duplicate(),
	}


static func _invalid_snapshot(seed_value: int, reason_code: String) -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"valid": false,
		"seed": seed_value,
		"phase": "blocked",
		"elapsed": {"wall_seconds": 0.0, "world_seconds": 0.0},
		"progress": {"controlled_region_count": 0, "required_region_count": 0, "top_k_gdp_per_minute": 0, "required_top_k_gdp_per_minute": 0, "owned_facility_count": 0, "eligible": false},
		"decision_window": {
			"active": false,
			"kind": "none",
			"priority_group": "",
			"blocks_global_time": false,
			"blocks_player_actions": false,
			"visible_to_scripted_player": true,
		},
		"settlement": {
			"state": "idle",
			"completed": false,
			"outcome_id": "",
			"reason_code": "",
			"winner_count": 0,
			"presentation_ready": false,
		},
		"invalid_actions": {"count": 0, "last_reason_code": reason_code},
		"nonfinite": {"count": 0, "paths": []},
		"last_event": "blocked:%s" % _safe_token(reason_code),
	}


static func _normalized_phase(value: String) -> String:
	var normalized := _safe_token(value)
	for prefix_variant in VALID_PHASE_PREFIXES:
		var prefix := str(prefix_variant)
		if normalized == prefix or normalized.begins_with("%s." % prefix):
			return normalized
	return "blocked"


static func _safe_event(value: String) -> String:
	return _safe_token(value).substr(0, MAX_EVENT_LENGTH)


static func _safe_token(value: String) -> String:
	var normalized := value.strip_edges()
	var result := ""
	for index in range(normalized.length()):
		var code := normalized.unicode_at(index)
		var allowed := (code >= 48 and code <= 57) \
			or (code >= 65 and code <= 90) \
			or (code >= 97 and code <= 122) \
			or code in [45, 46, 47, 58, 95]
		if allowed:
			result += String.chr(code)
	return result


static func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			if FORBIDDEN_INPUT_KEYS.has(key):
				return true
			if _contains_forbidden_key((value as Dictionary).get(key_variant)):
				return true
		return false
	if value is Array:
		for item_variant in value as Array:
			if _contains_forbidden_key(item_variant):
				return true
	return false


static func _collect_nonfinite_paths(value: Variant, path: String, output: Array[String]) -> void:
	if value is float:
		var number := float(value)
		if is_nan(number) or is_inf(number):
			output.append(path)
		return
	if value is Dictionary:
		var keys := (value as Dictionary).keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		for key_variant in keys:
			_collect_nonfinite_paths((value as Dictionary).get(key_variant), "%s.%s" % [path, _safe_token(str(key_variant))], output)
		return
	if value is Array:
		for index in range((value as Array).size()):
			_collect_nonfinite_paths((value as Array)[index], "%s.%d" % [path, index], output)


static func _is_data_only(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_ARRAY:
			for item_variant in value as Array:
				if not _is_data_only(item_variant):
					return false
			return true
		TYPE_DICTIONARY:
			for key_variant in (value as Dictionary).keys():
				if not _is_data_only(key_variant) or not _is_data_only((value as Dictionary).get(key_variant)):
					return false
			return true
	return false


static func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
