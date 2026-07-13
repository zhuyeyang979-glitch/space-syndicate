extends Resource
class_name PlayerTextUnitCatalogResource

@export var schema_version: String = "v0.5"
@export var entries: Array[Resource] = []


func entry_for_id(unit_id: String) -> Resource:
	for entry in entries:
		if entry != null and entry.unit_id == unit_id:
			return entry
	return null


func format_numeric_value(value: int, unit_id: String) -> String:
	var entry: Resource = entry_for_id(unit_id)
	if entry == null:
		return ""
	var scale_value: int = int(entry.get("scale"))
	var decimal_places: int = int(entry.get("decimal_places"))
	if scale_value <= 0:
		return ""
	var absolute_value: int = absi(value)
	var whole: int = int(float(absolute_value) / float(scale_value))
	var remainder: int = absolute_value % scale_value
	var sign_prefix: String = "-" if value < 0 else ""
	if decimal_places <= 0:
		return "%s%d" % [sign_prefix, whole]
	return "%s%d.%s" % [sign_prefix, whole, str(remainder).pad_zeros(decimal_places)]


func debug_snapshot() -> Dictionary:
	var entry_snapshots: Array[Dictionary] = []
	for entry in entries:
		if entry != null:
			entry_snapshots.append(entry.to_snapshot())
	return {
		"schema_version": schema_version,
		"entries": entry_snapshots,
	}
