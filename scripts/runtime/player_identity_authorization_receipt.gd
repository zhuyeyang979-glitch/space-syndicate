extends RefCounted
class_name PlayerIdentityAuthorizationReceipt

const SCHEMA_VERSION := 1

var schema_version := SCHEMA_VERSION
var request_id := ""
var authorized := false
var reason_code := ""
var viewer_index := -1
var authorized_player_index := -1
var authorization_revision := 0
var session_id := ""
var session_revision := 0
var source_surface: StringName = &""
var request_revision := 0
var idempotent_replay := false
var request_id_collision := false


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"request_id": request_id,
		"authorized": authorized,
		"reason_code": reason_code,
		"viewer_index": viewer_index,
		"authorized_player_index": authorized_player_index,
		"authorization_revision": authorization_revision,
		"session_id": session_id,
		"session_revision": session_revision,
		"source_surface": source_surface,
		"request_revision": request_revision,
		"idempotent_replay": idempotent_replay,
		"request_id_collision": request_id_collision,
	}
