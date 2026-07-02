extends RefCounted
class_name CampaignProgressMapSnapshot

var ui: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	var progress: Dictionary = data.get("progress", data) if data.get("progress", data) is Dictionary else {}
	ui = {
		"title": str(progress.get("title", "战役进度")),
		"progress_text": "%d/%d｜%d%%" % [
			int(progress.get("completed_count", 0)),
			maxi(1, int(progress.get("total_chapters", 1))),
			int(progress.get("completion_percent", 0)),
		],
		"current_chapter_id": str(progress.get("current_chapter_id", "")),
		"chapters": (progress.get("chapter_statuses", []) as Array).duplicate(true) if progress.get("chapter_statuses", []) is Array else [],
	}
	return self


func to_ui_dictionary() -> Dictionary:
	return ui.duplicate(true)
