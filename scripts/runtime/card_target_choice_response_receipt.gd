extends RefCounted
class_name CardTargetChoiceResponseReceipt

const SCHEMA_VERSION := 1

var schema_version := SCHEMA_VERSION
var request_id := ""
var decision_id := ""
var decision_kind: StringName = &""
var option_id := ""
var viewer_index := -1
var accepted := false
var applied := false
var queued := false
var cancelled := false
var choice_cleared := false
var target_index := -1
var reason_code := ""
var player_message := ""
var idempotent_replay := false
var request_id_collision := false
var visibility_scope: StringName = &"viewer_private"


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"request_id": request_id,
		"decision_id": decision_id,
		"decision_kind": decision_kind,
		"option_id": option_id,
		"viewer_index": viewer_index,
		"accepted": accepted,
		"applied": applied,
		"queued": queued,
		"cancelled": cancelled,
		"choice_cleared": choice_cleared,
		"target_index": target_index,
		"reason_code": reason_code,
		"player_message": player_message,
		"idempotent_replay": idempotent_replay,
		"request_id_collision": request_id_collision,
		"visibility_scope": visibility_scope,
	}


func public_summary() -> Dictionary:
	if not queued:
		return {
			"schema_version": schema_version,
			"publishable": false,
			"visibility_scope": &"viewer_private_only",
		}
	var result := {
		"schema_version": schema_version,
		"decision_kind": decision_kind,
		"queued": queued,
		"publishable": true,
		"result_kind": &"target_choice_resolved",
		"visibility_scope": &"public_redacted",
	}
	# A chosen target is public table information; the responding actor and card
	# identity remain deliberately absent from this projection.
	if queued and target_index >= 0:
		result["public_target_index"] = target_index
	return result
