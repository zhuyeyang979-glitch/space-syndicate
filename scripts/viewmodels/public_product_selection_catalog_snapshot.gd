extends RefCounted
class_name PublicProductSelectionCatalogSnapshot

const ENTRY_SCRIPT := preload("res://scripts/viewmodels/public_product_selection_catalog_entry.gd")
const SCHEMA_VERSION := 1
const CATALOG_KIND := "product"
const SOURCE_OWNER_ID := "ProductMarketRuntimeController.PRODUCT_CATALOG"
const ALLOWED_INPUT_KEYS := [
	"schema_version",
	"catalog_kind",
	"session_id",
	"session_revision",
	"source_owner_id",
	"source_ready",
	"available",
	"unavailable_reason",
	"ordering_revision",
	"data_revision",
	"ordering_fingerprint",
	"entries",
]

var schema_version := SCHEMA_VERSION
var catalog_kind := CATALOG_KIND
var session_id := ""
var session_revision := 0
var source_owner_id := SOURCE_OWNER_ID
var source_ready := false
var available := false
var unavailable_reason := "unconfigured"
var ordering_revision := ""
var data_revision := ""
var ordering_fingerprint := ""
var entries: Array[ENTRY_SCRIPT] = []
var _valid := false


func build(
	source_available: bool,
	source_reason: String,
	source_entries: Array,
	source_session_id: String = "",
	source_session_revision: int = 0,
	source_is_ready: bool = false
) -> PublicProductSelectionCatalogSnapshot:
	var entry_rows: Array = []
	for source_variant in source_entries:
		if not (source_variant is Dictionary):
			return self
		var entry: ENTRY_SCRIPT = ENTRY_SCRIPT.new().apply_dictionary(source_variant as Dictionary)
		if entry == null or not entry.is_valid():
			return self
		entry_rows.append(entry.to_dictionary())
	return apply_dictionary({
		"schema_version": SCHEMA_VERSION,
		"catalog_kind": CATALOG_KIND,
		"session_id": source_session_id,
		"session_revision": source_session_revision,
		"source_owner_id": SOURCE_OWNER_ID,
		"source_ready": source_is_ready,
		"available": source_available,
		"unavailable_reason": source_reason,
		"ordering_revision": ordering_revision_for(entry_rows),
		"data_revision": data_revision_for(entry_rows),
		"ordering_fingerprint": ordering_fingerprint_for(entry_rows),
		"entries": entry_rows,
	})


func apply_dictionary(source: Dictionary) -> PublicProductSelectionCatalogSnapshot:
	_valid = false
	entries.clear()
	for key_variant in source.keys():
		if not ALLOWED_INPUT_KEYS.has(str(key_variant)):
			return self
	if not _input_types_valid(source):
		return self
	schema_version = int(source.get("schema_version", 0))
	catalog_kind = str(source.get("catalog_kind", "")).strip_edges()
	session_id = str(source.get("session_id", "")).strip_edges()
	session_revision = int(source.get("session_revision", 0))
	source_owner_id = str(source.get("source_owner_id", "")).strip_edges()
	source_ready = bool(source.get("source_ready", false))
	available = bool(source.get("available", false))
	unavailable_reason = str(source.get("unavailable_reason", "")).strip_edges()
	ordering_revision = str(source.get("ordering_revision", "")).strip_edges()
	data_revision = str(source.get("data_revision", "")).strip_edges()
	ordering_fingerprint = str(source.get("ordering_fingerprint", "")).strip_edges()
	var seen_ids: Dictionary = {}
	var source_entries: Array = source.get("entries", []) if source.get("entries", []) is Array else []
	for source_variant in source_entries:
		if not (source_variant is Dictionary):
			return self
		var entry: ENTRY_SCRIPT = ENTRY_SCRIPT.new().apply_dictionary(source_variant as Dictionary)
		if entry == null or not entry.is_valid() or seen_ids.has(entry.product_id):
			return self
		seen_ids[entry.product_id] = true
		entries.append(entry)
	_valid = _validation_errors().is_empty()
	return self


func is_valid() -> bool:
	return _valid and _validation_errors().is_empty()


func to_dictionary() -> Dictionary:
	if not is_valid():
		return {}
	var entry_rows: Array = []
	for entry in entries:
		entry_rows.append(entry.to_dictionary())
	return {
		"schema_version": schema_version,
		"catalog_kind": catalog_kind,
		"session_id": session_id,
		"session_revision": session_revision,
		"source_owner_id": source_owner_id,
		"source_ready": source_ready,
		"available": available,
		"unavailable_reason": unavailable_reason,
		"ordering_revision": ordering_revision,
		"data_revision": data_revision,
		"ordering_fingerprint": ordering_fingerprint,
		"entries": entry_rows,
	}


func entry_by_id(product_id: String) -> ENTRY_SCRIPT:
	for entry in entries:
		if entry.product_id == product_id:
			return ENTRY_SCRIPT.new().apply_dictionary(entry.to_dictionary())
	return null


static func ordering_revision_for(entry_rows: Array) -> String:
	return JSON.stringify(["public_product_selection_order_revision_v1", _ordering_rows(entry_rows)]).sha256_text()


static func ordering_fingerprint_for(entry_rows: Array) -> String:
	return JSON.stringify(["public_product_selection_order_fingerprint_v1", _ordering_rows(entry_rows)]).sha256_text()


static func data_revision_for(entry_rows: Array) -> String:
	var rows: Array = []
	for entry_variant in entry_rows:
		if not (entry_variant is Dictionary):
			return ""
		var entry := entry_variant as Dictionary
		rows.append([
			str(entry.get("product_id", "")),
			int(entry.get("public_index", -1)),
			str(entry.get("public_name", "")),
			bool(entry.get("selectable", false)),
			str(entry.get("disabled_reason", "")),
			str(entry.get("public_category", "")),
		])
	return JSON.stringify(["public_product_selection_data_revision_v1", rows]).sha256_text()


static func _ordering_rows(entry_rows: Array) -> Array:
	var rows: Array = []
	for entry_variant in entry_rows:
		if not (entry_variant is Dictionary):
			return []
		var entry := entry_variant as Dictionary
		rows.append([
			str(entry.get("product_id", "")),
			int(entry.get("public_index", -1)),
			bool(entry.get("selectable", false)),
		])
	return rows


func _validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if schema_version != SCHEMA_VERSION:
		errors.append("schema_version_invalid")
	if catalog_kind != CATALOG_KIND:
		errors.append("catalog_kind_invalid")
	if source_owner_id != SOURCE_OWNER_ID:
		errors.append("source_owner_id_invalid")
	if source_ready != available:
		errors.append("source_ready_mismatch")
	if available and (session_id.is_empty() or session_revision <= 0):
		errors.append("active_session_identity_invalid")
	if not available and ((session_id.is_empty() and session_revision != 0) or (not session_id.is_empty() and session_revision <= 0)):
		errors.append("unavailable_session_identity_invalid")
	if available and entries.is_empty():
		errors.append("available_entries_missing")
	if available and not unavailable_reason.is_empty():
		errors.append("available_reason_present")
	if not available and (unavailable_reason.is_empty() or not entries.is_empty()):
		errors.append("unavailable_contract_invalid")
	for index in range(entries.size()):
		if entries[index].public_index != index:
			errors.append("public_index_noncontiguous")
	var rows: Array = []
	for entry in entries:
		rows.append(entry.to_dictionary())
	if not _is_sha256(ordering_revision) or ordering_revision != ordering_revision_for(rows):
		errors.append("ordering_revision_invalid")
	if not _is_sha256(ordering_fingerprint) or ordering_fingerprint != ordering_fingerprint_for(rows):
		errors.append("ordering_fingerprint_invalid")
	if not _is_sha256(data_revision) or data_revision != data_revision_for(rows):
		errors.append("data_revision_invalid")
	if not TablePresentationPureDataPolicy.is_pure_data(rows):
		errors.append("entries_not_pure_data")
	return errors


func _input_types_valid(source: Dictionary) -> bool:
	for key in ["catalog_kind", "session_id", "source_owner_id", "unavailable_reason", "ordering_revision", "data_revision", "ordering_fingerprint"]:
		if not source.has(key) or typeof(source[key]) != TYPE_STRING:
			return false
	for key in ["schema_version", "session_revision"]:
		if not source.has(key) or typeof(source[key]) != TYPE_INT:
			return false
	for key in ["source_ready", "available"]:
		if not source.has(key) or typeof(source[key]) != TYPE_BOOL:
			return false
	return source.has("entries") and source["entries"] is Array


func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true
