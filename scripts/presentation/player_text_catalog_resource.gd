extends Resource
class_name PlayerTextCatalogResource

@export var schema_version: String = "v0.5"
@export var default_locale: String = "zh_Hans"
@export var safe_fallback_key: String = "ui.error.generic_safe"
@export var entries: Array[Resource] = []


func entry_for_key(message_key: String) -> Resource:
	for entry in entries:
		if entry != null and entry.message_key == message_key:
			return entry
	return null


func entry_snapshot(message_key: String) -> Dictionary:
	var entry: Resource = entry_for_key(message_key)
	return entry.to_snapshot() if entry != null else {}


func message_keys() -> Array[String]:
	var result: Array[String] = []
	for entry in entries:
		if entry != null:
			result.append(entry.message_key)
	return result


func debug_snapshot() -> Dictionary:
	var entry_snapshots: Array[Dictionary] = []
	for entry in entries:
		if entry != null:
			entry_snapshots.append(entry.to_snapshot())
	return {
		"schema_version": schema_version,
		"default_locale": default_locale,
		"safe_fallback_key": safe_fallback_key,
		"entries": entry_snapshots,
	}
