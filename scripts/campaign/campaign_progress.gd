extends RefCounted
class_name CampaignProgress

const UNLOCKS_SCRIPT := preload("res://scripts/campaign/campaign_unlocks.gd")

var campaign: Dictionary = {}
var completed_chapter_ids: Array = []
var current_chapter_id := ""
var unlocked_chapter_ids: Array = []


func apply_state(definition: Dictionary, completed_ids: Array = [], selected_chapter_id: String = "") -> RefCounted:
	campaign = definition.duplicate(true)
	completed_chapter_ids = _unique_strings(completed_ids)
	unlocked_chapter_ids = UNLOCKS_SCRIPT.new().compute_unlocked_chapter_ids(campaign, completed_chapter_ids)
	current_chapter_id = selected_chapter_id.strip_edges()
	if current_chapter_id == "" or not unlocked_chapter_ids.has(current_chapter_id):
		current_chapter_id = next_chapter_id()
	return self


func mark_completed(chapter_id: String) -> void:
	var id := chapter_id.strip_edges()
	if id == "":
		return
	if not completed_chapter_ids.has(id):
		completed_chapter_ids.append(id)
	unlocked_chapter_ids = UNLOCKS_SCRIPT.new().compute_unlocked_chapter_ids(campaign, completed_chapter_ids)
	current_chapter_id = next_chapter_id()


func reset() -> void:
	completed_chapter_ids = []
	unlocked_chapter_ids = UNLOCKS_SCRIPT.new().compute_unlocked_chapter_ids(campaign, completed_chapter_ids)
	current_chapter_id = next_chapter_id()


func next_chapter_id() -> String:
	var chapters: Array = campaign.get("chapters", []) if campaign.get("chapters", []) is Array else []
	for chapter_variant in chapters:
		if not (chapter_variant is Dictionary):
			continue
		var id := str((chapter_variant as Dictionary).get("id", "")).strip_edges()
		if id != "" and unlocked_chapter_ids.has(id) and not completed_chapter_ids.has(id):
			return id
	return str(chapters.back().get("id", "")) if not chapters.is_empty() and chapters.back() is Dictionary else ""


func chapter_statuses() -> Array:
	var result: Array = []
	var chapters: Array = campaign.get("chapters", []) if campaign.get("chapters", []) is Array else []
	for chapter_variant in chapters:
		if not (chapter_variant is Dictionary):
			continue
		var chapter: Dictionary = chapter_variant
		var chapter_id := str(chapter.get("id", ""))
		result.append({
			"id": chapter_id,
			"title": str(chapter.get("title", chapter_id)),
			"subtitle": str(chapter.get("subtitle", "")),
			"order": int(chapter.get("order", 0)),
			"estimated_minutes": int(chapter.get("estimated_minutes", 5)),
			"difficulty": str(chapter.get("difficulty", "intro")),
			"completed": completed_chapter_ids.has(chapter_id),
			"unlocked": unlocked_chapter_ids.has(chapter_id),
			"current": chapter_id == current_chapter_id,
			"action_id": "campaign_chapter_%s" % chapter_id,
		})
	return result


func completion_percent() -> int:
	var total := (campaign.get("chapters", []) as Array).size() if campaign.get("chapters", []) is Array else 0
	if total <= 0:
		return 0
	return int(round(100.0 * float(completed_chapter_ids.size()) / float(total)))


func to_dictionary() -> Dictionary:
	return {
		"campaign_id": str(campaign.get("id", "")),
		"title": str(campaign.get("title", "")),
		"subtitle": str(campaign.get("subtitle", "")),
		"summary": str(campaign.get("summary", "")),
		"completed_chapter_ids": completed_chapter_ids.duplicate(true),
		"unlocked_chapter_ids": unlocked_chapter_ids.duplicate(true),
		"current_chapter_id": current_chapter_id,
		"next_chapter_id": next_chapter_id(),
		"completion_percent": completion_percent(),
		"chapter_statuses": chapter_statuses(),
		"total_chapters": (campaign.get("chapters", []) as Array).size() if campaign.get("chapters", []) is Array else 0,
		"completed_count": completed_chapter_ids.size(),
	}


func _unique_strings(value: Array) -> Array:
	var seen := {}
	var result: Array = []
	for item in value:
		var text := str(item).strip_edges()
		if text != "" and not bool(seen.get(text, false)):
			seen[text] = true
			result.append(text)
	return result
