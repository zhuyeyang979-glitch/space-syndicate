extends Resource
class_name CompendiumContentPackResource

@export var pack_id := ""
@export var display_name := ""
@export_multiline var source_note := "Batch content resource. Entries are public codex references only."
@export var entries: Array[Resource] = []


func entry_resources() -> Array[Resource]:
	var result: Array[Resource] = []
	for entry in entries:
		if entry != null:
			result.append(entry)
	return result


func required_fields_missing() -> Array[String]:
	var missing: Array[String] = []
	if pack_id.strip_edges() == "":
		missing.append("pack_id")
	if display_name.strip_edges() == "":
		missing.append("display_name")
	if entry_resources().is_empty():
		missing.append("entries")
	return missing
