extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const SNAPSHOT_DIR := "user://space_syndicate_ui_snapshots"
const CAPTURE_SIZE := Vector2i(1600, 1000)

var _saved_paths: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(CAPTURE_SIZE)
	get_root().size = CAPTURE_SIZE
	_prepare_snapshot_dir()
	var packed := load(MAIN_SCENE_PATH)
	if not (packed is PackedScene):
		push_error("UI snapshot capture failed: main scene did not load.")
		quit(1)
		return
	var main := (packed as PackedScene).instantiate()
	get_root().add_child(main)
	await _pump_frames(10)

	main.call("_open_main_menu")
	await _pump_frames(8)
	await _save_viewport_snapshot("01_main_menu.png")

	main.call("_open_card_codex_menu")
	await _pump_frames(8)
	await _save_viewport_snapshot("02_card_codex_grid.png")

	main.call("_open_card_codex_menu", 0)
	await _pump_frames(8)
	await _save_viewport_snapshot("03_card_codex_detail.png")

	main.set("configured_player_count", 4)
	main.set("configured_ai_player_count", 3)
	main.set("configured_role_indices", [0, 1, 2, 3, 4])
	main.set("configured_starter_monster_indices", [0, 1, 2, 3])
	main.call("_new_game")
	main.call("_close_menu")
	await _pump_frames(16)
	await _save_viewport_snapshot("04_play_table.png")

	print("UI snapshot capture complete:")
	for path in _saved_paths:
		print(path)
	quit(0)


func _pump_frames(count: int) -> void:
	for _i in range(maxi(1, count)):
		await process_frame


func _prepare_snapshot_dir() -> void:
	var absolute_dir := ProjectSettings.globalize_path(SNAPSHOT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)


func _save_viewport_snapshot(file_name: String) -> void:
	await process_frame
	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("UI snapshot capture failed: viewport image is empty for %s." % file_name)
		return
	var user_path := "%s/%s" % [SNAPSHOT_DIR, file_name]
	var error := image.save_png(user_path)
	if error != OK:
		push_error("UI snapshot capture failed to save %s: %s" % [user_path, error])
		return
	_saved_paths.append(ProjectSettings.globalize_path(user_path))
