extends RefCounted
class_name CampaignProgressSave

const SAVE_SCRIPT := preload("res://scripts/campaign/campaign_save.gd")


func save_progress(progress: Dictionary, path: String = SAVE_SCRIPT.DEFAULT_PATH) -> bool:
	return SAVE_SCRIPT.new().save_progress(progress, path)


func load_progress(path: String = SAVE_SCRIPT.DEFAULT_PATH) -> Dictionary:
	return SAVE_SCRIPT.new().load_progress(path)


func reset(path: String = SAVE_SCRIPT.DEFAULT_PATH) -> void:
	SAVE_SCRIPT.new().reset(path)
