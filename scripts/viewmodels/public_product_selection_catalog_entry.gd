extends RefCounted
class_name PublicProductSelectionCatalogEntry

const ALLOWED_INPUT_KEYS := [
	"product_id",
	"public_index",
	"public_name",
	"selectable",
	"disabled_reason",
	"public_category",
]

var product_id := ""
var public_index := -1
var public_name := ""
var selectable := false
var disabled_reason := ""
var public_category := ""
var _valid := false


func apply_dictionary(source: Dictionary) -> PublicProductSelectionCatalogEntry:
	_valid = false
	for key_variant in source.keys():
		if not ALLOWED_INPUT_KEYS.has(str(key_variant)):
			return self
	if not _input_types_valid(source):
		return self
	product_id = str(source.get("product_id", ""))
	public_index = int(source.get("public_index", -1))
	public_name = str(source.get("public_name", "")).strip_edges()
	selectable = bool(source.get("selectable", false))
	disabled_reason = str(source.get("disabled_reason", "")).strip_edges()
	public_category = str(source.get("public_category", "")).strip_edges()
	_valid = _validation_errors().is_empty()
	return self


func _input_types_valid(source: Dictionary) -> bool:
	for key in ["product_id", "public_name", "disabled_reason", "public_category"]:
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
		"product_id": product_id,
		"public_index": public_index,
		"public_name": public_name,
		"selectable": selectable,
		"disabled_reason": disabled_reason,
		"public_category": public_category,
	}


func _validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if product_id.is_empty() or product_id != product_id.strip_edges():
		errors.append("product_id_invalid")
	if public_index < 0:
		errors.append("public_index_invalid")
	if public_name.is_empty():
		errors.append("public_name_missing")
	if selectable and not disabled_reason.is_empty():
		errors.append("selectable_disabled_reason_present")
	if not selectable and disabled_reason.is_empty():
		errors.append("disabled_reason_missing")
	return errors
