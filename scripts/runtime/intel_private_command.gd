extends RefCounted
class_name IntelPrivateCommand

const SCHEMA_VERSION := 1
const COMMAND_KINDS := [
	&"set_city_owner_guess",
	&"clear_city_owner_guess",
	&"set_city_guess_confidence",
	&"set_city_guess_reason",
	&"set_card_history_note",
	&"set_card_history_tags",
	&"set_card_history_suspects",
	&"set_card_history_private_confidence",
	&"set_card_history_subscription",
	&"clear_card_history_annotation",
	&"use_residual_frame_catalog",
	&"use_public_evidence_exclusion",
]

var schema_version := SCHEMA_VERSION
var command_id := ""
var command_kind: StringName = &""
var viewer_index := -1
var subject_id := ""
var expected_owner_revision := ""
var payload: Dictionary = {}


static func create(
	id: String,
	kind: StringName,
	viewer: int,
	subject: String,
	expected_revision: String,
	command_payload: Dictionary = {}
) -> IntelPrivateCommand:
	var command := IntelPrivateCommand.new()
	command.command_id = id
	command.command_kind = kind
	command.viewer_index = viewer
	command.subject_id = subject
	command.expected_owner_revision = expected_revision
	command.payload = command_payload.duplicate(true)
	return command


func validation_report() -> Dictionary:
	if schema_version != SCHEMA_VERSION:
		return _invalid("command_schema_invalid")
	if not _canonical_identifier(command_id, 128):
		return _invalid("command_id_invalid")
	if not COMMAND_KINDS.has(command_kind):
		return _invalid("command_kind_unsupported")
	if viewer_index < 0:
		return _invalid("viewer_invalid")
	if subject_id.is_empty() or subject_id.strip_edges() != subject_id or subject_id.length() > 160:
		return _invalid("subject_id_invalid")
	if expected_owner_revision.is_empty() or expected_owner_revision.strip_edges() != expected_owner_revision or expected_owner_revision.length() > 128:
		return _invalid("expected_owner_revision_invalid")
	if not TablePresentationPureDataPolicy.is_pure_data(payload):
		return _invalid("payload_not_pure_data")
	return {"valid": true, "reason_code": ""}


func fingerprint() -> String:
	if not bool(validation_report().get("valid", false)):
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(_canonical_value({
		"schema_version": schema_version,
		"command_id": command_id,
		"command_kind": str(command_kind),
		"viewer_index": viewer_index,
		"subject_id": subject_id,
		"expected_owner_revision": expected_owner_revision,
		"payload": payload,
	})).to_utf8_buffer())
	return context.finish().hex_encode()


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"command_id": command_id,
		"command_kind": command_kind,
		"viewer_index": viewer_index,
		"subject_id": subject_id,
		"expected_owner_revision": expected_owner_revision,
		"payload": payload.duplicate(true),
	}


static func _canonical_identifier(value: String, maximum_length: int) -> bool:
	if value.is_empty() or value.length() > maximum_length or value.strip_edges() != value:
		return false
	for character in value:
		var is_ascii_letter := (character >= "a" and character <= "z") or (character >= "A" and character <= "Z")
		var is_digit := character >= "0" and character <= "9"
		if not (is_ascii_letter or is_digit or character in ["_", "-", ".", ":"]):
			return false
	return true


static func _canonical_value(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		var keys: Array[String] = []
		for key_variant in (value as Dictionary).keys():
			keys.append(str(key_variant))
		keys.sort()
		for key in keys:
			result[key] = _canonical_value((value as Dictionary).get(key))
		return result
	if value is Array:
		var result: Array = []
		for item_variant in value as Array:
			result.append(_canonical_value(item_variant))
		return result
	return value


static func _invalid(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code}
