extends RefCounted
class_name IntelApplicationIntent

const SCHEMA_VERSION := 1
const OPEN_INTEL := &"open_intel"

var schema_version := SCHEMA_VERSION
var intent_kind: StringName = OPEN_INTEL
var focused_history_entry_id := ""
var focused_region_id := ""


static func open(history_entry_id: String = "", region_id: String = "") -> IntelApplicationIntent:
	var intent := IntelApplicationIntent.new()
	intent.focused_history_entry_id = history_entry_id
	intent.focused_region_id = region_id
	return intent


static func from_dictionary(source: Dictionary) -> IntelApplicationIntent:
	if source.keys().size() != 3 \
			or not source.has("kind") \
			or not source.has("focused_history_entry_id") \
			or not source.has("focused_region_id"):
		return null
	var intent := open(str(source.get("focused_history_entry_id", "")), str(source.get("focused_region_id", "")))
	intent.intent_kind = StringName(source.get("kind", ""))
	return intent if intent.is_valid() else null


func is_valid() -> bool:
	if schema_version != SCHEMA_VERSION or intent_kind != OPEN_INTEL:
		return false
	if focused_history_entry_id.strip_edges() != focused_history_entry_id or focused_region_id.strip_edges() != focused_region_id:
		return false
	if not focused_history_entry_id.is_empty() and not _canonical_history_id(focused_history_entry_id):
		return false
	return focused_region_id.is_empty() or _canonical_region_id(focused_region_id)


func to_dictionary() -> Dictionary:
	return {
		"kind": intent_kind,
		"focused_history_entry_id": focused_history_entry_id,
		"focused_region_id": focused_region_id,
	}


static func _canonical_history_id(value: String) -> bool:
	if not value.begins_with("card-history:"):
		return false
	var suffix := value.trim_prefix("card-history:")
	return suffix.is_valid_int() and int(suffix) >= 0 and str(int(suffix)) == suffix


static func _canonical_region_id(value: String) -> bool:
	if value.length() > 96 or not value.begins_with("region."):
		return false
	var suffix := value.trim_prefix("region.")
	return not suffix.is_empty() and (suffix.is_valid_identifier() or suffix.is_valid_int())
