extends RefCounted
class_name DistrictSupplyActionReceipt

var request_id := ""
var action_kind: StringName = &""
var accepted := false
var applied := false
var reason_code := ""
var actor_player_index := -1
var district_index := -1
var card_id := ""
var quote_id := ""
var price := -1
var requires_discard := false
var focus_district_index := -1
var close_drawer := false
var presentation_refresh_requested := false
var idempotent_replay := false
var request_id_collision := false
var visibility_scope: StringName = &"viewer_private"


func to_dictionary() -> Dictionary:
	return {
		"request_id": request_id,
		"action_kind": action_kind,
		"accepted": accepted,
		"applied": applied,
		"reason_code": reason_code,
		"actor_player_index": actor_player_index,
		"district_index": district_index,
		"card_id": card_id,
		"quote_id": quote_id,
		"price": price,
		"requires_discard": requires_discard,
		"focus_district_index": focus_district_index,
		"close_drawer": close_drawer,
		"presentation_refresh_requested": presentation_refresh_requested,
		"idempotent_replay": idempotent_replay,
		"request_id_collision": request_id_collision,
		"visibility_scope": visibility_scope,
	}


func public_summary() -> Dictionary:
	return {
		"action_kind": action_kind,
		"accepted": accepted,
		"applied": applied,
		"result_kind": &"district_supply_action_resolved" if accepted else &"district_supply_action_rejected",
		"presentation_refresh_requested": presentation_refresh_requested,
		"visibility_scope": &"public_redacted",
	}
