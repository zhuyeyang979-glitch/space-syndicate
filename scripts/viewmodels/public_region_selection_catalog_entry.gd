extends RefCounted
class_name PublicRegionSelectionCatalogEntry

const ALLOWED_INPUT_KEYS := [
	"region_id",
	"public_index",
	"public_name",
	"public_status",
	"selectable",
	"disabled_reason",
	"public_terrain",
]

var region_id := ""
var public_index := -1
var public_name := ""
var public_status := ""
var selectable := false
var disabled_reason := ""
var public_terrain := ""
var _valid := false


func apply_dictionary(source: Dictionary) -> PublicRegionSelectionCatalogEntry:
	_valid = false
	for key_variant in source.keys():
		if not ALLOWED_INPUT_KEYS.has(str(key_variant)):
			return self
	if not _input_types_valid(source):
		return self
	region_id = str(source.get("region_id", ""))
	public_index = int(source.get("public_index", -1))
	public_name = str(source.get("public_name", "")).strip_edges()
	public_status = str(source.get("public_status", "")).strip_edges()
	selectable = bool(source.get("selectable", false))
	disabled_reason = str(source.get("disabled_reason", "")).strip_edges()
	public_terrain = str(source.get("public_terrain", "")).strip_edges()
	_valid = _validation_errors().is_empty()
	return self


func _input_types_valid(source: Dictionary) -> bool:
	for key in ["region_id", "public_name", "public_status", "disabled_reason", "public_terrain"]:
		if not source.has(key) or typeof(source[key]) != TYPE_STRING:
			return false
	return source.has("public_index") \
		and typeof(source["public_index"]) == TYPE_INT \
		and source.has("selectable") \
		and typeof(source["selectable"]) == TYPE_BOOL


func is_valid() -> bool:
	return _valid and _validation_errors().is_empty()


func to_dictionary() -> Dictionary:
	if not is_valid():
		return {}
	return {
		"region_id": region_id,
		"public_index": public_index,
		"public_name": public_name,
		"public_status": public_status,
		"selectable": selectable,
		"disabled_reason": disabled_reason,
		"public_terrain": public_terrain,
	}


func _validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if region_id.is_empty() or region_id != region_id.strip_edges():
		errors.append("region_id_invalid")
	if public_index < 0:
		errors.append("public_index_invalid")
	if public_name.is_empty():
		errors.append("public_name_missing")
	if public_status.is_empty():
		errors.append("public_status_missing")
	if selectable and not disabled_reason.is_empty():
		errors.append("selectable_disabled_reason_present")
	if not selectable and disabled_reason.is_empty():
		errors.append("disabled_reason_missing")
	return errors
