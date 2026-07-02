extends RefCounted
class_name ScenarioActionLog

var entries: Array = []


func add_entry(data: Dictionary) -> void:
	var entry := {
		"time": str(data.get("time", "00:00")),
		"phase_id": str(data.get("phase_id", "")),
		"public_text": str(data.get("public_text", "")),
		"private_text": str(data.get("private_text", "")),
		"developer_text": str(data.get("developer_text", "")),
		"viewer_index": int(data.get("viewer_index", 0)),
		"snapshot_key": str(data.get("snapshot_key", "")),
		"focus_target": str(data.get("focus_target", "")),
	}
	entries.append(entry)


func apply_entries(value: Variant) -> RefCounted:
	entries = []
	var source: Array = value if value is Array else []
	for entry_variant in source:
		if entry_variant is Dictionary:
			add_entry(entry_variant as Dictionary)
	return self


func filtered_entries(viewer_index: int, include_developer: bool = false) -> Array:
	var filtered: Array = []
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var text := str(entry.get("public_text", "")).strip_edges()
		var private_text := str(entry.get("private_text", "")).strip_edges()
		if private_text != "" and int(entry.get("viewer_index", -1)) == viewer_index:
			text = "%s｜%s" % [text, private_text] if text != "" else private_text
		if include_developer and str(entry.get("developer_text", "")).strip_edges() != "":
			text = "%s｜DEV:%s" % [text, str(entry.get("developer_text", ""))]
		filtered.append({
			"time": str(entry.get("time", "00:00")),
			"phase_id": str(entry.get("phase_id", "")),
			"text": text,
			"snapshot_key": str(entry.get("snapshot_key", "")),
			"focus_target": str(entry.get("focus_target", "")),
		})
	return filtered


func to_test_dictionary() -> Dictionary:
	return {"entries": entries.duplicate(true)}
