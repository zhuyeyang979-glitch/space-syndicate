extends Resource
class_name CompendiumCodexEntryResource

@export var entry_id := ""
@export var display_name := ""
@export var subtitle := ""
@export_multiline var summary := ""
@export var accent := "#38bdf8"
@export var chips: PackedStringArray = []
@export_multiline var source_note := "Codex content resource only. This is not a rules data source."


func entry_kind() -> String:
	return "entry"


func required_fields_missing() -> Array[String]:
	var missing: Array[String] = []
	if entry_id.strip_edges() == "":
		missing.append("entry_id")
	if display_name.strip_edges() == "":
		missing.append("display_name")
	if summary.strip_edges() == "":
		missing.append("summary")
	return missing


func is_valid_entry() -> bool:
	return required_fields_missing().is_empty()


func entry_payload() -> Dictionary:
	return {
		"entry_id": entry_id,
		"entry_type": entry_kind(),
		"display_name": display_name,
		"title": display_name,
		"subtitle": subtitle,
		"summary": summary,
		"accent": accent,
		"chips": _chips_to_payload(chips, accent),
		"source_note": source_note,
	}


func to_payload() -> Dictionary:
	return entry_payload()


func _chips_to_payload(values: PackedStringArray, default_accent: String = "") -> Array:
	var result: Array = []
	var chip_accent := default_accent if default_accent.strip_edges() != "" else accent
	for value in values:
		var text := str(value).strip_edges()
		if text != "":
			result.append({"text": text, "accent": chip_accent})
	return result


func _string_array(values: PackedStringArray) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		var text := str(value).strip_edges()
		if text != "":
			result.append(text)
	return result


func _note_cards(values: PackedStringArray, title_prefix: String, default_accent: String) -> Array:
	var result: Array = []
	var index := 1
	for value in values:
		var text := str(value).strip_edges()
		if text == "":
			continue
		result.append({
			"title": "%s %d" % [title_prefix, index],
			"body": text,
			"accent": default_accent,
		})
		index += 1
	return result
