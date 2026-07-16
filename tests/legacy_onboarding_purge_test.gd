extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const FORBIDDEN_PRODUCTION_TOKENS := [
	"FirstRunCoach",
	"ScenarioCoach",
	"TutorialQuickStartBoard",
	"ScenarioRuntimeController",
	"FirstTableAuthoredRuntimeService",
	"RecommendedStartService",
	"CampaignMenu",
	"campaign_progress",
	"tutorial_campaign",
	"skirmish_campaign",
	"_start_campaign_chapter",
	"_start_scenario_from_menu",
	"_activate_first_run_coach_action",
	"_first_run_recommended_setup",
	"_first_run_recommended_start_district",
]
const REMOVED_PATHS := [
	"res://data/campaigns/tutorial_campaign.json",
	"res://data/campaigns/skirmish_campaign.json",
	"res://data/scenarios/first_table.json",
	"res://scenes/ui/FirstRunCoach.tscn",
	"res://scenes/ui/ScenarioCoach.tscn",
	"res://scenes/ui/CampaignMenu.tscn",
	"res://scenes/runtime/ScenarioRuntimeController.tscn",
	"res://scripts/campaign/campaign_progress.gd",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for path in REMOVED_PATHS:
		_expect(not FileAccess.file_exists(path) and not ResourceLoader.exists(path), "removed onboarding asset stays absent: %s" % path)

	for path in _production_text_paths():
		var source := FileAccess.get_file_as_string(path)
		for token in FORBIDDEN_PRODUCTION_TOKENS:
			_expect(not source.contains(token), "%s has no removed token %s" % [path, token])

	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "normal main scene still loads")
	if packed != null:
		var main := packed.instantiate()
		var save := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
		if save != null and save.has_method("set_qa_default_save_path_override"):
			save.call("set_qa_default_save_path_override", "user://test_runs/legacy_onboarding_purge.save")
		root.add_child(main)
		await process_frame
		await process_frame
		main.set("configured_player_count", 3)
		main.set("configured_ai_player_count", 2)
		main.set("configured_role_indices", [0, 1, 2])
		main.set("configured_starter_monster_indices", [0, 1, 2])
		main.call("_confirm_start_new_run_from_setup")
		for _frame in range(6):
			await process_frame
		var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
		var save_data: Dictionary = coordinator.call("session_to_save_data") if coordinator != null else {}
		var serialized := var_to_str(save_data).to_lower()
		for token in ["campaign", "tutorial", "first_run", "checkpoint", "reward_unlock"]:
			_expect(not serialized.contains(token), "normal save omits removed field token: %s" % token)
		_expect(main.find_child("FirstRunCoach", true, false) == null, "normal composition has no FirstRunCoach")
		_expect(main.find_child("ScenarioCoach", true, false) == null, "normal composition has no ScenarioCoach")
		main.queue_free()
		await process_frame
	_finish()


func _production_text_paths() -> Array[String]:
	var paths: Array[String] = []
	for root_path in ["res://scenes", "res://scripts"]:
		_collect_text_paths(root_path, paths)
	return paths


func _collect_text_paths(directory_path: String, paths: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var path := directory_path.path_join(name)
		if directory.current_is_dir():
			if not path.begins_with("res://scripts/tools"):
				_collect_text_paths(path, paths)
		elif path.ends_with(".gd") or path.ends_with(".tscn") or path.ends_with(".tres"):
			if path != "res://scripts/card_art_view.gd":
				paths.append(path)
		name = directory.get_next()
	directory.list_dir_end()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Legacy onboarding purge passed (%d checks)." % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("LEGACY ONBOARDING PURGE: %s" % failure)
	quit(1)
