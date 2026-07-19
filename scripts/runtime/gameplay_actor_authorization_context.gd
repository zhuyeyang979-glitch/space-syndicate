extends RefCounted
class_name GameplayActorAuthorizationContext

const SCHEMA_VERSION := 1

var schema_version := SCHEMA_VERSION
var request_id := ""
var authorized := false
var reason_code := ""
var viewer_index := -1
var authorized_actor_player_index := -1
var authorization_revision := 0
var session_id := ""
var session_revision := 0
var source_surface: StringName = &""
var issued_at_operation_revision := 0


func is_valid() -> bool:
	return schema_version == SCHEMA_VERSION \
		and PlayerIdentityActionRequest._canonical_identifier(request_id, 160) \
		and authorized \
		and reason_code == "authorized" \
		and viewer_index >= 0 \
		and authorized_actor_player_index == viewer_index \
		and authorization_revision > 0 \
		and PlayerIdentityActionRequest._canonical_identifier(session_id, 160) \
		and session_revision > 0 \
		and PlayerIdentityActionRequest.SOURCE_SURFACES.has(source_surface) \
		and issued_at_operation_revision > 0


func fingerprint() -> String:
	if not is_valid():
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(to_dictionary()).to_utf8_buffer())
	return context.finish().hex_encode()


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"request_id": request_id,
		"authorized": authorized,
		"reason_code": reason_code,
		"viewer_index": viewer_index,
		"authorized_actor_player_index": authorized_actor_player_index,
		"authorization_revision": authorization_revision,
		"session_id": session_id,
		"session_revision": session_revision,
		"source_surface": source_surface,
		"issued_at_operation_revision": issued_at_operation_revision,
	}


static func from_dictionary(data: Dictionary) -> GameplayActorAuthorizationContext:
	var context := GameplayActorAuthorizationContext.new()
	context.schema_version = int(data.get("schema_version", -1))
	context.request_id = str(data.get("request_id", ""))
	context.authorized = bool(data.get("authorized", false))
	context.reason_code = str(data.get("reason_code", ""))
	context.viewer_index = int(data.get("viewer_index", -1))
	context.authorized_actor_player_index = int(data.get("authorized_actor_player_index", -1))
	context.authorization_revision = int(data.get("authorization_revision", 0))
	context.session_id = str(data.get("session_id", ""))
	context.session_revision = int(data.get("session_revision", 0))
	context.source_surface = StringName(data.get("source_surface", &""))
	context.issued_at_operation_revision = int(data.get("issued_at_operation_revision", 0))
	return context


static func denied(reason: String, operation_revision: int, source: StringName = &"game_screen", rejected_request_id: String = "") -> GameplayActorAuthorizationContext:
	var context := GameplayActorAuthorizationContext.new()
	context.request_id = rejected_request_id
	context.reason_code = reason
	context.source_surface = source
	context.issued_at_operation_revision = operation_revision
	return context
