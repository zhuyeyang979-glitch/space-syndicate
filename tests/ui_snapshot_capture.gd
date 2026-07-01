extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const LAYOUT_DEMO_SCENE_PATH := "res://scenes/LayoutDemo.tscn"
const SNAPSHOT_DIR := "user://space_syndicate_ui_snapshots"
const CAPTURE_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 960),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var _saved_paths: Array[String] = []
var _capture_failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_prepare_snapshot_dir()
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if not (packed is PackedScene):
		push_error("UI snapshot capture failed: main scene did not load.")
		quit(1)
		return
	var layout_demo_packed := load(LAYOUT_DEMO_SCENE_PATH) as PackedScene
	if not (layout_demo_packed is PackedScene):
		push_error("UI snapshot capture failed: layout demo scene did not load.")
		quit(1)
		return
	for capture_size in CAPTURE_SIZES:
		await _capture_size_suite(packed, layout_demo_packed, capture_size)
	if _capture_failures.is_empty():
		print("UI snapshot capture complete:")
		for path in _saved_paths:
			print(path)
		quit(0)
	else:
		printerr("UI snapshot capture failed:")
		for failure in _capture_failures:
			printerr("- %s" % failure)
		quit(1)


func _capture_size_suite(packed: PackedScene, layout_demo_packed: PackedScene, capture_size: Vector2i) -> void:
	_place_capture_window(capture_size)
	DisplayServer.window_set_size(capture_size)
	get_root().size = capture_size
	var suffix := "%dx%d" % [capture_size.x, capture_size.y]
	var main := packed.instantiate()
	get_root().add_child(main)
	await _pump_frames(10)

	main.call("_open_main_menu")
	await _pump_frames(8)
	await _save_viewport_snapshot("main_menu_%s.png" % suffix)

	if capture_size == Vector2i(1600, 960):
		main.call("_open_card_codex_menu")
		await _pump_frames(8)
		await _save_viewport_snapshot("card_codex_grid_%s.png" % suffix)

		main.call("_open_card_codex_menu", 0)
		await _pump_frames(8)
		await _save_viewport_snapshot("card_codex_detail_%s.png" % suffix)

	main.set("configured_player_count", 4)
	main.set("configured_ai_player_count", 3)
	main.set("configured_role_indices", [0, 1, 2, 3, 4])
	main.set("configured_starter_monster_indices", [0, 1, 2, 3])
	main.call("_new_game")
	main.call("_close_menu")
	await _pump_frames(16)
	await _save_viewport_snapshot("play_table_%s.png" % suffix)

	get_root().remove_child(main)
	main.queue_free()
	await _pump_frames(4)

	var layout_demo := layout_demo_packed.instantiate()
	get_root().add_child(layout_demo)
	await _pump_frames(8)
	await _save_viewport_snapshot("layout_demo_%s.png" % suffix)
	get_root().remove_child(layout_demo)
	layout_demo.queue_free()
	await _pump_frames(4)


func _pump_frames(count: int) -> void:
	for _i in range(maxi(1, count)):
		await process_frame


func _prepare_snapshot_dir() -> void:
	var absolute_dir := ProjectSettings.globalize_path(SNAPSHOT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)


func _place_capture_window(capture_size: Vector2i) -> void:
	var screen_count := DisplayServer.get_screen_count()
	var screen_index := 1 if screen_count > 1 else 0
	DisplayServer.window_set_current_screen(screen_index)
	var screen_position := DisplayServer.screen_get_position(screen_index)
	DisplayServer.window_set_position(screen_position + Vector2i(40, 40))
	DisplayServer.window_set_size(capture_size)


func _save_viewport_snapshot(file_name: String) -> void:
	await process_frame
	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		var message := "viewport image is empty for %s; run this script with a visible renderer, not --headless." % file_name
		push_error("UI snapshot capture failed: %s" % message)
		_capture_failures.append(message)
		return
	var user_path := "%s/%s" % [SNAPSHOT_DIR, file_name]
	var error := image.save_png(user_path)
	if error != OK:
		var message := "failed to save %s: %s" % [user_path, error]
		push_error("UI snapshot capture failed to save %s" % message)
		_capture_failures.append(message)
		return
	_saved_paths.append(ProjectSettings.globalize_path(user_path))
