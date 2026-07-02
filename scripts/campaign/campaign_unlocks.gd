extends RefCounted
class_name CampaignUnlocks


func compute_unlocked_chapter_ids(campaign: Dictionary, completed_chapter_ids: Array) -> Array:
	var chapters: Array = campaign.get("chapters", []) if campaign.get("chapters", []) is Array else []
	var completed := {}
	for id_variant in completed_chapter_ids:
		completed[str(id_variant)] = true
	var unlocked := {}
	if not chapters.is_empty() and chapters[0] is Dictionary:
		unlocked[str((chapters[0] as Dictionary).get("id", ""))] = true
	for chapter_variant in chapters:
		if not (chapter_variant is Dictionary):
			continue
		var chapter: Dictionary = chapter_variant
		var chapter_id := str(chapter.get("id", ""))
		if not bool(completed.get(chapter_id, false)):
			continue
		var unlocks: Array = chapter.get("unlocks", []) if chapter.get("unlocks", []) is Array else []
		for unlock_variant in unlocks:
			var unlock_id := str(unlock_variant).strip_edges()
			if unlock_id != "":
				unlocked[unlock_id] = true
	var result: Array = []
	for chapter_variant in chapters:
		if chapter_variant is Dictionary:
			var id := str((chapter_variant as Dictionary).get("id", ""))
			if bool(unlocked.get(id, false)):
				result.append(id)
	return result


func collect_reward_unlocks(chapter: Dictionary) -> Array:
	var reward: Dictionary = chapter.get("reward", {}) if chapter.get("reward", {}) is Dictionary else {}
	var result: Array = []
	var unlock_chapter := str(reward.get("unlock_chapter", "")).strip_edges()
	if unlock_chapter != "":
		result.append({"kind": "chapter", "id": unlock_chapter, "label": "下一关"})
	for key in ["unlock_codex", "unlock_role", "unlock_scenario"]:
		var value: Variant = reward.get(key, [])
		if value is Array:
			for item in value:
				var text := str(item).strip_edges()
				if text != "":
					result.append({"kind": key.replace("unlock_", ""), "id": text, "label": text})
		else:
			var text := str(value).strip_edges()
			if text != "":
				result.append({"kind": key.replace("unlock_", ""), "id": text, "label": text})
	return result
