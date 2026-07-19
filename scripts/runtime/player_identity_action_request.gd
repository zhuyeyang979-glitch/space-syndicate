extends RefCounted
class_name PlayerIdentityActionRequest

const SCHEMA_VERSION := 1
const SOURCE_SURFACES := [
	&"game_screen",
	&"player_board",
	&"hand_rack",
	&"planet_map",
	&"district_supply",
	&"top_commodity_track",
	&"right_inspector",
	&"forced_decision",
]

var schema_version := SCHEMA_VERSION
var request_id := ""
var viewer_index := -1
var authorized_player_index := -1
var authorization_revision := 0
var session_id := ""
var session_revision := 0
var source_surface: StringName = &""
var request_revision := 0


func validation_report() -> Dictionary:
	if schema_version != SCHEMA_VERSION:
		return _invalid("request_schema_invalid")
	if not _canonical_identifier(request_id, 128):
		return _invalid("request_id_invalid")
	if viewer_index < 0:
		return _invalid("viewer_index_invalid")
	if authorized_player_index < 0:
		return _invalid("authorized_player_index_invalid")
	if authorization_revision <= 0:
		return _invalid("authorization_revision_invalid")
	if not _canonical_identifier(session_id, 160):
		return _invalid("session_id_invalid")
	if session_revision <= 0:
		return _invalid("session_revision_invalid")
	if not SOURCE_SURFACES.has(source_surface):
		return _invalid("source_surface_invalid")
	if request_revision <= 0:
		return _invalid("request_revision_invalid")
	return {"valid": true, "reason_code": ""}


func fingerprint() -> String:
	if not bool(validation_report().get("valid", false)):
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(to_dictionary()).to_utf8_buffer())
	return context.finish().hex_encode()


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"request_id": request_id,
		"viewer_index": viewer_index,
		"authorized_player_index": authorized_player_index,
		"authorization_revision": authorization_revision,
		"session_id": session_id,
		"session_revision": session_revision,
		"source_surface": source_surface,
		"request_revision": request_revision,
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


static func _invalid(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code}
