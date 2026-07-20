extends RefCounted
class_name TableSelectionIntent

const SCHEMA_VERSION := 1
const KIND_MAP_LAYER: StringName = &"map_layer"
const KIND_INSPECT_PLAYER: StringName = &"inspect_player"
const KIND_SELECT_DISTRICT: StringName = &"select_district"
const KIND_SELECT_TRADE_PRODUCT: StringName = &"select_trade_product"
const KIND_SELECT_HAND_SLOT: StringName = &"select_hand_slot"
const MAP_LAYER_IDS := [
	&"all",
	&"product",
	&"intel",
	&"weather",
	&"monster",
	&"city",
]
const PLAYER_INSPECTION_SOURCE_SURFACES := [
	&"player_seat",
	&"player_board",
	&"fullscreen_hud",
	&"keyboard_hotkey",
	&"table_toolbar",
	&"qa_driver",
]
const DISTRICT_SELECTION_SOURCE_SURFACES := [
	&"planet_map",
	&"fullscreen_hud",
	&"keyboard_hotkey",
	&"qa_driver",
]
const TRADE_PRODUCT_SELECTION_SOURCE_SURFACES := [
	&"table_toolbar",
	&"keyboard_hotkey",
	&"player_board",
	&"qa_driver",
]
const HAND_SELECTION_SOURCE_SURFACES := [
	&"hand_rack",
	&"player_board",
	&"game_screen",
	&"qa_driver",
]

var schema_version := SCHEMA_VERSION
var request_id := ""
var selection_kind: StringName = KIND_MAP_LAYER
var viewer_index := -1
var authorization_revision := 0
var session_id := ""
var session_revision := 0
var expected_selection_revision := -1
var map_layer_id: StringName = &""
var target_player_index := -1
var target_district_index := -1
var target_trade_product_id := ""
var target_hand_slot := -2
var source_surface: StringName = &"planet_map"
var request_revision := 0


func validation_report() -> Dictionary:
	if schema_version != SCHEMA_VERSION:
		return _invalid("intent_schema_invalid")
	if not PlayerIdentityActionRequest._canonical_identifier(request_id, 128):
		return _invalid("request_id_invalid")
	if selection_kind not in [KIND_MAP_LAYER, KIND_INSPECT_PLAYER, KIND_SELECT_DISTRICT, KIND_SELECT_TRADE_PRODUCT, KIND_SELECT_HAND_SLOT]:
		return _invalid("selection_kind_invalid")
	if viewer_index < 0:
		return _invalid("viewer_index_invalid")
	if authorization_revision <= 0:
		return _invalid("authorization_revision_invalid")
	if expected_selection_revision < 0:
		return _invalid("selection_revision_invalid")
	if selection_kind != KIND_MAP_LAYER:
		if not PlayerIdentityActionRequest._canonical_identifier(session_id, 160):
			return _invalid("session_id_invalid")
		if session_revision <= 0:
			return _invalid("session_revision_invalid")
	match selection_kind:
		KIND_MAP_LAYER:
			if not MAP_LAYER_IDS.has(map_layer_id):
				return _invalid("map_layer_invalid")
			if source_surface != &"planet_map":
				return _invalid("source_surface_invalid")
		KIND_INSPECT_PLAYER:
			if target_player_index < 0:
				return _invalid("target_player_invalid")
			if not PLAYER_INSPECTION_SOURCE_SURFACES.has(source_surface):
				return _invalid("source_surface_invalid")
		KIND_SELECT_DISTRICT:
			if target_district_index < 0:
				return _invalid("target_district_invalid")
			if not DISTRICT_SELECTION_SOURCE_SURFACES.has(source_surface):
				return _invalid("source_surface_invalid")
		KIND_SELECT_TRADE_PRODUCT:
			if target_trade_product_id.length() > 80 or target_trade_product_id.strip_edges() != target_trade_product_id:
				return _invalid("target_trade_product_invalid")
			if not TRADE_PRODUCT_SELECTION_SOURCE_SURFACES.has(source_surface):
				return _invalid("source_surface_invalid")
		KIND_SELECT_HAND_SLOT:
			if target_hand_slot < -1:
				return _invalid("target_hand_slot_invalid")
			if not HAND_SELECTION_SOURCE_SURFACES.has(source_surface):
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
		"selection_kind": selection_kind,
		"viewer_index": viewer_index,
		"authorization_revision": authorization_revision,
		"session_id": session_id,
		"session_revision": session_revision,
		"expected_selection_revision": expected_selection_revision,
		"map_layer_id": map_layer_id,
		"target_player_index": target_player_index,
		"target_district_index": target_district_index,
		"target_trade_product_id": target_trade_product_id,
		"target_hand_slot": target_hand_slot,
		"source_surface": source_surface,
		"request_revision": request_revision,
	}


static func _invalid(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code}
