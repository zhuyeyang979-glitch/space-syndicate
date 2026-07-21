extends RefCounted
class_name MonsterWagerResponseReceipt

const SCHEMA_VERSION := 1

var schema_version := SCHEMA_VERSION
var request_id := ""
var decision_id := ""
var decision_revision := 0
var wager_id := -1
var viewer_index := -1
var player_index := -1
var side: StringName = &""
var stake_percent := 0
var stake := 0
var accepted := false
var applied := false
var decision_closed := false
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
		"decision_revision": decision_revision,
		"wager_id": wager_id,
		"viewer_index": viewer_index,
		"player_index": player_index,
		"side": side,
		"stake_percent": stake_percent,
		"stake": stake,
		"accepted": accepted,
		"applied": applied,
		"decision_closed": decision_closed,
		"reason_code": reason_code,
		"player_message": player_message,
		"idempotent_replay": idempotent_replay,
		"request_id_collision": request_id_collision,
		"visibility_scope": visibility_scope,
	}


func public_summary() -> Dictionary:
	if not applied:
		return {
			"schema_version": schema_version,
			"publishable": false,
			"visibility_scope": &"viewer_private_only",
		}
	# Wager identity, side, percentage, and stake are intentionally public clues.
	# The response envelope and the player's remaining cash stay private.
	return {
		"schema_version": schema_version,
		"publishable": true,
		"visibility_scope": &"public_wager_clue",
		"result_kind": &"monster_wager_placed",
		"wager_id": wager_id,
		"public_player_index": player_index,
		"side": side,
		"stake_percent": stake_percent,
		"stake": stake,
		"decision_closed": decision_closed,
	}
