extends RefCounted
class_name PlayerTextSpecV05

const ALLOWED_AUDIENCES := [
	"machine_identifier",
	"developer_diagnostic",
	"translator_metadata",
	"player_visible",
	"player_assistive",
	"player_generated",
]
const RELEASE_AUDIENCES := ["player_visible", "player_assistive", "player_generated"]
const ALLOWED_VISIBILITY_SCOPES := [
	"public",
	"viewer_private",
	"revealed_at_endgame",
	"spectator_sanitized",
	"developer_only",
]
const ALLOWED_ARGUMENT_TYPES := [
	"string",
	"integer",
	"number",
	"boolean",
	"localized_key",
	"currency_cents",
	"basis_points",
	"seconds",
	"gdp_per_minute",
]
const ALLOWED_SPEC_FIELDS := [
	"message_key",
	"args",
	"audience",
	"visibility_scope",
	"viewer_index",
	"surface",
	"severity",
	"assistive_message_key",
	"developer_event_code",
	"sanitized",
]
const FORBIDDEN_ARGUMENT_KEYS := [
	"error",
	"args.error",
	"stack",
	"stack_trace",
	"node_path",
	"resource_path",
	"card_id",
	"action_id",
	"reason_code",
	"hidden_owner",
	"private_target",
	"private_discard",
	"ai_plan",
]


static func validate_spec(spec: Dictionary, catalog: Resource, release_mode: bool = true) -> Dictionary:
	var errors: Array[String] = []
	if catalog == null or not catalog.has_method("entry_snapshot"):
		return {"valid": false, "errors": ["catalog_missing"], "normalized_spec": {}}
	for key_variant in spec.keys():
		var key := str(key_variant)
		if not ALLOWED_SPEC_FIELDS.has(key):
			errors.append("unexpected_spec_field:%s" % key)
	var message_key := str(spec.get("message_key", ""))
	var audience := str(spec.get("audience", ""))
	var visibility_scope := str(spec.get("visibility_scope", ""))
	var viewer_index := int(spec.get("viewer_index", -1))
	var args_variant: Variant = spec.get("args", {})
	var spec_args: Dictionary = args_variant as Dictionary if args_variant is Dictionary else {}
	if message_key.is_empty() or not is_stable_ascii_id(message_key):
		errors.append("message_key_invalid")
	if not ALLOWED_AUDIENCES.has(audience):
		errors.append("audience_invalid")
	elif release_mode and not RELEASE_AUDIENCES.has(audience):
		errors.append("audience_not_release_visible")
	if not ALLOWED_VISIBILITY_SCOPES.has(visibility_scope):
		errors.append("visibility_scope_invalid")
	if visibility_scope == "viewer_private" and viewer_index < 0:
		errors.append("viewer_private_requires_viewer")
	if not (args_variant is Dictionary):
		errors.append("args_not_dictionary")
	elif not is_pure_data(spec_args):
		errors.append("args_not_pure_data")
	for arg_key_variant in spec_args.keys():
		var arg_key := str(arg_key_variant)
		if FORBIDDEN_ARGUMENT_KEYS.has(arg_key):
			errors.append("forbidden_argument:%s" % arg_key)
	var entry: Dictionary = catalog.call("entry_snapshot", message_key)
	if entry.is_empty():
		errors.append("message_key_missing")
	else:
		var expected_types: Dictionary = entry.get("argument_types", {}) as Dictionary
		for expected_key_variant in expected_types.keys():
			var expected_key := str(expected_key_variant)
			if not spec_args.has(expected_key):
				errors.append("argument_missing:%s" % expected_key)
			elif not _argument_matches_type(spec_args[expected_key], str(expected_types[expected_key])):
				errors.append("argument_type_invalid:%s" % expected_key)
		for actual_key_variant in spec_args.keys():
			var actual_key := str(actual_key_variant)
			if not expected_types.has(actual_key):
				errors.append("argument_unexpected:%s" % actual_key)
		if audience != str(entry.get("audience", "")):
			errors.append("audience_catalog_mismatch")
	if audience == "player_generated" and not bool(spec.get("sanitized", false)):
		errors.append("player_generated_not_sanitized")
	var developer_event_code := str(spec.get("developer_event_code", ""))
	if not developer_event_code.is_empty() and not is_stable_ascii_id(developer_event_code, true):
		errors.append("developer_event_code_invalid")
	var normalized_spec := {
		"message_key": message_key,
		"args": spec_args.duplicate(true),
		"audience": audience,
		"visibility_scope": visibility_scope,
		"viewer_index": viewer_index,
		"surface": str(spec.get("surface", entry.get("surface", "label"))),
		"severity": str(spec.get("severity", "informational")),
		"assistive_message_key": str(spec.get("assistive_message_key", entry.get("assistive_message_key", ""))),
		"developer_event_code": developer_event_code,
		"sanitized": bool(spec.get("sanitized", false)),
	}
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"normalized_spec": normalized_spec,
	}


static func is_stable_ascii_id(value: String, allow_uppercase: bool = false) -> bool:
	if value.is_empty() or value.begins_with(".") or value.ends_with(".") or value.contains(".."):
		return false
	for character in value:
		var code := character.unicode_at(0)
		var lower := code >= 97 and code <= 122
		var upper := allow_uppercase and code >= 65 and code <= 90
		var digit := code >= 48 and code <= 57
		if not lower and not upper and not digit and character != "." and character != "_" and character != "-":
			return false
	return true


static func is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not is_pure_data(item):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not (key is String or key is int) or not is_pure_data(value[key]):
				return false
		return true
	return false


static func _argument_matches_type(value: Variant, type_id: String) -> bool:
	if not ALLOWED_ARGUMENT_TYPES.has(type_id):
		return false
	match type_id:
		"string":
			return value is String
		"integer", "currency_cents", "basis_points", "seconds", "gdp_per_minute":
			return value is int
		"number":
			return value is int or value is float
		"boolean":
			return value is bool
		"localized_key":
			return value is String and is_stable_ascii_id(str(value))
	return false
