extends RefCounted
class_name CampaignSave

const DEFAULT_PATH := "user://campaign_progress.save"


func save_progress(progress: Dictionary, path: String = DEFAULT_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_safe_progress(progress), "\t"))
	file.close()
	return true


func load_progress(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return _safe_progress(parsed as Dictionary) if parsed is Dictionary else {}


func reset(path: String = DEFAULT_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _safe_progress(value: Dictionary) -> Dictionary:
	return {
		"campaign_id": str(value.get("campaign_id", "tutorial_campaign")),
		"completed_chapter_ids": _string_array(value.get("completed_chapter_ids", [])),
		"unlocked_chapter_ids": _string_array(value.get("unlocked_chapter_ids", [])),
		"selected_chapter_id": str(value.get("selected_chapter_id", value.get("current_chapter_id", ""))).strip_edges(),
		"last_completed_chapter_id": str(value.get("last_completed_chapter_id", "")).strip_edges(),
	}


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			var text := str(item).strip_edges()
			if text != "":
				result.append(text)
	return result
