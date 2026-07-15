extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const QA_SAVE_PATH := "user://test_runs/gameplay_balance_diagnostics_monster_art_profile.save"
const MonsterCatalogV06 := preload("res://scripts/runtime/monster_catalog_v06.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_delete_qa_save_file()
	var main := _instantiate_main()
	if main == null:
		_finish()
		return
	root.add_child(main)
	await process_frame
	await process_frame
	if main.has_method("_new_game"):
		main.call("_new_game")
	await process_frame
	await process_frame
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var diagnostics: GameplayBalanceDiagnosticsRuntimeService = coordinator.gameplay_balance_diagnostics_service() if coordinator is GameRuntimeCoordinator else null
	_expect(diagnostics != null, "GameRuntimeCoordinator exposes GameplayBalanceDiagnosticsRuntimeService")
	var snapshot: Dictionary = diagnostics.refresh_world_snapshot(false) if diagnostics != null else {}
	_expect(_monster_art_profiles_present(snapshot), "diagnostics monster facts use catalog-backed art profiles for every catalog entry")
	_expect(_production_symbol_absent("_monster_art_profile"), "production scripts have zero executable _monster_art_profile references")
	main.queue_free()
	await process_frame
	_delete_qa_save_file()
	_finish()


func _instantiate_main() -> Control:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main scene loads")
	if packed == null:
		return null
	var main := packed.instantiate() as Control
	_expect(main != null, "main scene instantiates")
	if main == null:
		return null
	main.visible = false
	var save := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	_expect(save != null and save.has_method("set_qa_default_save_path_override"), "QA save-path override exists before main enters the tree")
	if save == null or not save.has_method("set_qa_default_save_path_override"):
		main.queue_free()
		return null
	_expect(bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)), "focused gate uses only the isolated QA save path")
	return main


func _monster_art_profiles_present(snapshot: Dictionary) -> bool:
	var monsters: Array = snapshot.get("monsters", []) if snapshot.get("monsters", []) is Array else []
	if monsters.size() != MonsterCatalogV06.catalog_size():
		return false
	for monster_variant in monsters:
		if not (monster_variant is Dictionary):
			return false
		if not bool((monster_variant as Dictionary).get("has_art_profile", false)):
			return false
	return true


func _production_symbol_absent(symbol: String) -> bool:
	for path_variant in _production_script_files("res://scripts"):
		var source := FileAccess.get_file_as_string(str(path_variant))
		if source.contains(symbol):
			return false
	return true


func _production_script_files(root_path: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(root_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	while true:
		var item := dir.get_next()
		if item == "":
			break
		if item.begins_with("."):
			continue
		var path := "%s/%s" % [root_path, item]
		if dir.current_is_dir():
			if path == "res://scripts/tools":
				continue
			result.append_array(_production_script_files(path))
		elif path.ends_with(".gd"):
			result.append(path)
	dir.list_dir_end()
	return result


func _delete_qa_save_file() -> void:
	if FileAccess.file_exists(QA_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_SAVE_PATH))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("GAMEPLAY BALANCE DIAGNOSTICS MONSTER ART PROFILE PASS")
		quit(0)
	else:
		print("GAMEPLAY BALANCE DIAGNOSTICS MONSTER ART PROFILE FAIL: %s" % ", ".join(_failures))
		quit(1)
