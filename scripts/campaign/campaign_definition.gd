extends RefCounted
class_name CampaignDefinition

const CHAPTER_SCRIPT := preload("res://scripts/campaign/campaign_chapter.gd")
const CAMPAIGN_DIR := "res://data/campaigns"
const CAMPAIGN_IDS := [
	"tutorial_campaign",
	"skirmish_campaign",
]

var id := ""
var title := ""
var subtitle := ""
var summary := ""
var recommended := false
var chapters: Array = []


func load_by_id(campaign_id: String) -> Dictionary:
	var path := "%s/%s.json" % [CAMPAIGN_DIR, campaign_id.strip_edges()]
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return {}
	var definition: Variant = apply_dictionary(parsed as Dictionary)
	return definition.to_dictionary() if definition.is_valid() else {}


func load_all() -> Array:
	var result: Array = []
	for campaign_id in CAMPAIGN_IDS:
		var campaign := load_by_id(str(campaign_id))
		if not campaign.is_empty():
			result.append(campaign)
	return result


func apply_dictionary(data: Dictionary) -> RefCounted:
	id = str(data.get("id", "")).strip_edges()
	title = str(data.get("title", id)).strip_edges()
	subtitle = str(data.get("subtitle", "")).strip_edges()
	summary = str(data.get("summary", "")).strip_edges()
	recommended = bool(data.get("recommended", false))
	chapters = []
	var raw_chapters: Array = data.get("chapters", []) if data.get("chapters", []) is Array else []
	for chapter_variant in raw_chapters:
		if not (chapter_variant is Dictionary):
			continue
		var chapter: Variant = CHAPTER_SCRIPT.new().apply_dictionary(chapter_variant as Dictionary)
		if chapter.is_valid():
			chapters.append(chapter.to_dictionary())
	chapters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order", 0)) < int(b.get("order", 0))
	)
	return self


func is_valid() -> bool:
	return id != "" and title != "" and chapters.size() >= 1


func chapter_by_id(chapter_id: String) -> Dictionary:
	for chapter_variant in chapters:
		if chapter_variant is Dictionary and str(chapter_variant.get("id", "")) == chapter_id:
			return (chapter_variant as Dictionary).duplicate(true)
	return {}


func first_chapter_id() -> String:
	if chapters.is_empty() or not (chapters[0] is Dictionary):
		return ""
	return str((chapters[0] as Dictionary).get("id", ""))


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"subtitle": subtitle,
		"summary": summary,
		"recommended": recommended,
		"chapters": chapters.duplicate(true),
	}
