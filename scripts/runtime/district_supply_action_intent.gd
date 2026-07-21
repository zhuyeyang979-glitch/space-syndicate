extends RefCounted
class_name DistrictSupplyActionIntent

const SCHEMA_VERSION := 1
const KIND_OPEN: StringName = &"open"
const KIND_CLOSE: StringName = &"close"
const KIND_PREVIEW: StringName = &"preview"
const KIND_QUOTE: StringName = &"quote"
const KIND_PURCHASE: StringName = &"purchase"
const KIND_DISCARD_CONFIRM: StringName = &"discard_confirm"
const KIND_DISCARD_CANCEL: StringName = &"discard_cancel"
const KINDS := [KIND_OPEN, KIND_CLOSE, KIND_PREVIEW, KIND_QUOTE, KIND_PURCHASE, KIND_DISCARD_CONFIRM, KIND_DISCARD_CANCEL]

var request_id := ""
var action_kind: StringName = KIND_OPEN
var actor_player_index := -1
var authorization_revision := 0
var session_id := ""
var session_revision := 0
var district_index := -1
var card_id := ""
var discard_slot := -1
var locked_quote_id := ""
var source_surface: StringName = &"district_supply"
var request_revision := 0


func validation_report() -> Dictionary:
	if request_id.is_empty() or request_id.length() > 160:
		return {"valid": false, "reason_code": "request_id_invalid"}
	if action_kind not in KINDS:
		return {"valid": false, "reason_code": "action_kind_invalid"}
	if actor_player_index < 0 or authorization_revision <= 0:
		return {"valid": false, "reason_code": "actor_authority_invalid"}
	if session_id.is_empty() or session_revision <= 0 or request_revision <= 0:
		return {"valid": false, "reason_code": "session_binding_invalid"}
	if source_surface not in PlayerIdentityActionRequest.SOURCE_SURFACES:
		return {"valid": false, "reason_code": "source_surface_invalid"}
	if action_kind in [KIND_OPEN, KIND_PREVIEW, KIND_QUOTE, KIND_PURCHASE] and district_index < 0:
		return {"valid": false, "reason_code": "district_index_invalid"}
	if action_kind in [KIND_PREVIEW, KIND_QUOTE, KIND_PURCHASE] and card_id.is_empty():
		return {"valid": false, "reason_code": "card_id_invalid"}
	if action_kind == KIND_DISCARD_CONFIRM and discard_slot < 0:
		return {"valid": false, "reason_code": "discard_slot_invalid"}
	return {"valid": true, "reason_code": ""}


func fingerprint() -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(to_dictionary()).to_utf8_buffer())
	return context.finish().hex_encode()


func to_dictionary() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"request_id": request_id,
		"action_kind": action_kind,
		"actor_player_index": actor_player_index,
		"authorization_revision": authorization_revision,
		"session_id": session_id,
		"session_revision": session_revision,
		"district_index": district_index,
		"card_id": card_id,
		"discard_slot": discard_slot,
		"locked_quote_id": locked_quote_id,
		"source_surface": source_surface,
		"request_revision": request_revision,
	}
