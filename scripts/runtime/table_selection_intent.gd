extends RefCounted
class_name TableSelectionIntent

const SCHEMA_VERSION := 1
const KIND_MAP_LAYER: StringName = &"map_layer"
const MAP_LAYER_IDS := [
	&"all",
	&"product",
	&"intel",
	&"weather",
	&"monster",
	&"city",
]

var schema_version := SCHEMA_VERSION
var request_id := ""
var selection_kind: StringName = KIND_MAP_LAYER
var viewer_index := -1
var authorization_revision := 0
var expected_selection_revision := -1
var map_layer_id: StringName = &""
var source_surface: StringName = &"planet_map"
var request_revision := 0


func validation_report() -> Dictionary:
	if schema_version != SCHEMA_VERSION:
		return _invalid("intent_schema_invalid")
	if not PlayerIdentityActionRequest._canonical_identifier(request_id, 128):
		return _invalid("request_id_invalid")
	if selection_kind != KIND_MAP_LAYER:
		return _invalid("selection_kind_invalid")
	if viewer_index < 0:
		return _invalid("viewer_index_invalid")
	if authorization_revision <= 0:
		return _invalid("authorization_revision_invalid")
	if expected_selection_revision < 0:
		return _invalid("selection_revision_invalid")
	if not MAP_LAYER_IDS.has(map_layer_id):
		return _invalid("map_layer_invalid")
	if source_surface != &"planet_map":
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
		"expected_selection_revision": expected_selection_revision,
		"map_layer_id": map_layer_id,
		"source_surface": source_surface,
		"request_revision": request_revision,
	}


static func _invalid(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code}
