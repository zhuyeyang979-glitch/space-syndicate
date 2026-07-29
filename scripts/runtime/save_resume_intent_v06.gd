extends RefCounted
class_name SaveResumeIntentV06

const SCHEMA_VERSION := 2
const OPERATION_INSPECT := &"inspect"
const OPERATION_SAVE := &"save"
const OPERATION_RESUME := &"resume"
const ALLOWED_OPERATIONS := [OPERATION_INSPECT, OPERATION_SAVE, OPERATION_RESUME]
const ALLOWED_SURFACES := [&"root_menu", &"pause_menu", &"qa_driver"]
const FIELDS := [
	"schema_version",
	"request_id",
	"operation",
	"slot_id",
	"source_surface",
	"overwrite_existing",
	"preserve_incompatible_backup",
	"destructive_confirmed",
]

var schema_version := SCHEMA_VERSION
var request_id := ""
var operation: StringName = OPERATION_INSPECT
var slot_id: StringName = SaveSlotPolicyV06.PRODUCTION_SLOT_ID
var source_surface: StringName = &"root_menu"
var overwrite_existing := false
var preserve_incompatible_backup := false
var destructive_confirmed := false


static func inspect(request: String, source: StringName = &"root_menu") -> SaveResumeIntentV06:
	return _make(request, OPERATION_INSPECT, source, false, false)


static func save(request: String, source: StringName = &"pause_menu", confirmed := false) -> SaveResumeIntentV06:
	return _make(request, OPERATION_SAVE, source, confirmed, true, confirmed)


static func resume(request: String, source: StringName = &"root_menu", confirmed := false) -> SaveResumeIntentV06:
	return _make(request, OPERATION_RESUME, source, false, false, confirmed)


static func from_dictionary(source: Dictionary) -> SaveResumeIntentV06:
	if not _has_exact_fields(source, FIELDS) or not _field_types_valid(source):
		return null
	var intent := SaveResumeIntentV06.new()
	intent.schema_version = int(source.get("schema_version", 0))
	intent.request_id = str(source.get("request_id", ""))
	intent.operation = StringName(str(source.get("operation", "")))
	intent.slot_id = StringName(str(source.get("slot_id", "")))
	intent.source_surface = StringName(str(source.get("source_surface", "")))
	intent.overwrite_existing = bool(source.get("overwrite_existing", false))
	intent.preserve_incompatible_backup = bool(source.get("preserve_incompatible_backup", false))
	intent.destructive_confirmed = bool(source.get("destructive_confirmed", false))
	return intent if intent.is_valid() else null


func is_valid() -> bool:
	if schema_version != SCHEMA_VERSION or not ALLOWED_OPERATIONS.has(operation):
		return false
	if slot_id != SaveSlotPolicyV06.PRODUCTION_SLOT_ID or not ALLOWED_SURFACES.has(source_surface):
		return false
	if not _safe_token(request_id, 128):
		return false
	if operation == OPERATION_INSPECT:
		return not overwrite_existing and not preserve_incompatible_backup and not destructive_confirmed
	if operation == OPERATION_SAVE:
		return overwrite_existing == destructive_confirmed and preserve_incompatible_backup
	return not overwrite_existing and not preserve_incompatible_backup


func is_valid_for_production() -> bool:
	if not is_valid() or source_surface == &"qa_driver":
		return false
	if source_surface == &"root_menu":
		return operation in [OPERATION_INSPECT, OPERATION_RESUME]
	if source_surface == &"pause_menu":
		return operation in [OPERATION_INSPECT, OPERATION_SAVE]
	return false


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"request_id": request_id,
		"operation": String(operation),
		"slot_id": String(slot_id),
		"source_surface": String(source_surface),
		"overwrite_existing": overwrite_existing,
		"preserve_incompatible_backup": preserve_incompatible_backup,
		"destructive_confirmed": destructive_confirmed,
	}


func detached_copy() -> SaveResumeIntentV06:
	return from_dictionary(to_dictionary())


static func _make(
	request: String,
	operation_id: StringName,
	source: StringName,
	overwrite: bool,
	preserve_backup: bool,
	confirmed := false
) -> SaveResumeIntentV06:
	var intent := SaveResumeIntentV06.new()
	intent.request_id = request
	intent.operation = operation_id
	intent.source_surface = source
	intent.overwrite_existing = overwrite
	intent.preserve_incompatible_backup = preserve_backup
	intent.destructive_confirmed = confirmed
	return intent


static func _safe_token(value: String, maximum_length: int) -> bool:
	if value.is_empty() or value.length() > maximum_length or value.strip_edges() != value:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		var allowed := (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
			or code in [45, 46, 58, 95]
		)
		if not allowed:
			return false
	return true


static func _has_exact_fields(data: Dictionary, fields: Array) -> bool:
	if data.size() != fields.size():
		return false
	for field_variant in fields:
		if not data.has(str(field_variant)):
			return false
	return true


static func _field_types_valid(data: Dictionary) -> bool:
	if not (data.get("schema_version") is int):
		return false
	for field in ["request_id", "operation", "slot_id", "source_surface"]:
		if not (data.get(field) is String):
			return false
	for field in ["overwrite_existing", "preserve_incompatible_backup", "destructive_confirmed"]:
		if not (data.get(field) is bool):
			return false
	return true
