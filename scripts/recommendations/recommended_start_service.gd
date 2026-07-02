extends RefCounted
class_name RecommendedStartService

const RECOMMENDATION_PATH := "res://data/recommendations/tutorial_recommended_set.json"


func load_recommendations(path: String = RECOMMENDATION_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return {}
	return _normalize(parsed as Dictionary)


func tutorial_setup() -> Dictionary:
	return load_recommendations()


func preset_by_id(preset_id: String) -> Dictionary:
	var data := load_recommendations()
	var presets: Array = data.get("presets", []) if data.get("presets", []) is Array else []
	for preset_variant in presets:
		if preset_variant is Dictionary and str((preset_variant as Dictionary).get("id", "")) == preset_id:
			return (preset_variant as Dictionary).duplicate(true)
	return {}


func preset_summaries() -> Array:
	var data := load_recommendations()
	var presets: Array = data.get("presets", []) if data.get("presets", []) is Array else []
	var result: Array = []
	for preset_variant in presets:
		if preset_variant is Dictionary:
			var preset: Dictionary = preset_variant
			result.append({
				"id": str(preset.get("id", "")),
				"title": str(preset.get("title", "")),
				"recommended_for": str(preset.get("recommended_for", "")),
				"learns": str(preset.get("learns", "")),
				"estimated_minutes": int(preset.get("estimated_minutes", 10)),
				"difficulty": str(preset.get("difficulty", "intro")),
				"action_id": "quick_preset_%s" % str(preset.get("id", "")),
			})
	return result


func _normalize(data: Dictionary) -> Dictionary:
	return {
		"id": str(data.get("id", "tutorial_recommended_set")),
		"title": str(data.get("title", "推荐配置")),
		"player_count": clampi(int(data.get("player_count", 4)), 3, 8),
		"ai_count": clampi(int(data.get("ai_count", 3)), 2, 7),
		"roguelike_depth": clampi(int(data.get("roguelike_depth", 1)), 1, 6),
		"role_indices": _int_array(data.get("role_indices", [0, 1, 2, 3])),
		"starter_monster_indices": _int_array(data.get("starter_monster_indices", [7, 6, 2, 4])),
		"presets": (data.get("presets", []) as Array).duplicate(true) if data.get("presets", []) is Array else [],
	}


func _int_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			result.append(int(item))
	return result
