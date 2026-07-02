extends SceneTree

const CAMPAIGN_SCRIPT := preload("res://scripts/campaign/campaign_definition.gd")
const PROGRESS_SCRIPT := preload("res://scripts/campaign/campaign_progress.gd")
const SAVE_SCRIPT := preload("res://scripts/campaign/campaign_save.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var campaign: Dictionary = CAMPAIGN_SCRIPT.new().load_by_id("tutorial_campaign")
	var progress: Variant = PROGRESS_SCRIPT.new().apply_state(campaign, [])
	var start: Dictionary = progress.to_dictionary()
	_expect(str(start.get("current_chapter_id", "")) == "00_tavern_entry", "campaign starts at prologue")
	_expect((start.get("unlocked_chapter_ids", []) as Array).has("00_tavern_entry"), "first chapter is unlocked")
	progress.mark_completed("00_tavern_entry")
	var after_first: Dictionary = progress.to_dictionary()
	_expect((after_first.get("completed_chapter_ids", []) as Array).has("00_tavern_entry"), "completed chapter is recorded")
	_expect((after_first.get("unlocked_chapter_ids", []) as Array).has("01_first_table"), "chapter unlock follows campaign data")
	_expect(str(after_first.get("current_chapter_id", "")) == "01_first_table", "next playable chapter advances")
	var save_path := "user://campaign_progress_test.save"
	var save := SAVE_SCRIPT.new()
	_expect(save.save_progress(after_first, save_path), "campaign progress save succeeds")
	var loaded: Dictionary = save.load_progress(save_path)
	_expect((loaded.get("completed_chapter_ids", []) as Array).has("00_tavern_entry"), "campaign progress load restores completed chapters")
	save.reset(save_path)
	_expect(save.load_progress(save_path).is_empty(), "campaign progress reset removes test save")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Campaign progress test passed.")
	else:
		push_error("Campaign progress test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
