extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_CAPTURE_PATH := "user://space_syndicate_visual_main.png"
const GLOBE_CAPTURE_PATH := "user://space_syndicate_visual_globe.png"
const FULL_GLOBE_CAPTURE_PATH := "user://space_syndicate_visual_full_globe.png"
const STEADY_GLOBE_CAPTURE_PATH := "user://space_syndicate_visual_steady_globe.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	get_root().size = Vector2i(1600, 960)
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Unable to load main scene for visual snapshot.")
		quit(1)
		return
	var main := packed.instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	main.set("configured_player_count", 4)
	main.set("configured_monster_indices", [0, 1, 2, 3])
	main.call("_new_game")
	main.call("_close_menu")
	await _settle_frames(4)
	var player_box := main.get("player_box") as VBoxContainer
	var player_panel := main.call("_panel_container", player_box) as Control
	if player_panel == null or player_panel.get_global_rect().end.y > float(get_root().size.y) + 1.0:
		push_error("Player hand panel extends below the 1600x960 viewport.")
		quit(1)
		return
	if not _save_viewport_png(MAIN_CAPTURE_PATH):
		quit(1)
		return

	var map_view := main.get("map_view") as Control
	if map_view == null:
		push_error("Main map view is missing.")
		quit(1)
		return
	map_view.set("_view_zoom", 0.34)
	map_view.queue_redraw()
	await _settle_frames(4)
	if not _save_viewport_png(GLOBE_CAPTURE_PATH):
		quit(1)
		return

	main.call("_open_fullscreen_map")
	var full_map_view := main.get("full_map_view") as Control
	if full_map_view == null:
		push_error("Fullscreen map view is missing.")
		quit(1)
		return
	full_map_view.set("_view_zoom", 0.34)
	full_map_view.queue_redraw()
	await _settle_frames(4)
	if not _save_viewport_png(FULL_GLOBE_CAPTURE_PATH):
		quit(1)
		return
	main.set("movement_trails", [])
	main.set("action_callouts", [])
	main.set("map_event_effects", [])
	main.call("_refresh_ui")
	full_map_view.queue_redraw()
	await _settle_frames(4)
	if not _save_viewport_png(STEADY_GLOBE_CAPTURE_PATH):
		quit(1)
		return

	print("VISUAL_MAIN=%s" % ProjectSettings.globalize_path(MAIN_CAPTURE_PATH))
	print("VISUAL_GLOBE=%s" % ProjectSettings.globalize_path(GLOBE_CAPTURE_PATH))
	print("VISUAL_FULL_GLOBE=%s" % ProjectSettings.globalize_path(FULL_GLOBE_CAPTURE_PATH))
	print("VISUAL_STEADY_GLOBE=%s" % ProjectSettings.globalize_path(STEADY_GLOBE_CAPTURE_PATH))
	main.queue_free()
	await process_frame
	quit(0)


func _settle_frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _save_viewport_png(path: String) -> bool:
	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Viewport image is empty for %s." % path)
		return false
	var result := image.save_png(path)
	if result != OK:
		push_error("Failed to save %s: %d" % [path, result])
		return false
	return true
