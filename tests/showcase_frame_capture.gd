extends SceneTree

const SHOWCASE_SCENE := "res://scenes/ui/VerticalSliceShowcase.tscn"
const SNAPSHOT_DIR := "user://space_syndicate_ui_snapshots"
const CAPTURE_SIZE := Vector2i(1600, 960)
const FRAME_PLAN := [
	{"stage": "board_idle", "file": "showcase_board_idle_1600x960.png"},
	{"stage": "card_hover", "file": "showcase_card_hover_1600x960.png"},
	{"stage": "card_drag_valid", "file": "showcase_card_drag_valid_1600x960.png"},
	{"stage": "card_drag_invalid", "file": "showcase_card_drag_invalid_1600x960.png"},
	{"stage": "card_play_frame_00", "file": "showcase_card_play_frame_00.png"},
	{"stage": "card_play_frame_08", "file": "showcase_card_play_frame_08.png"},
	{"stage": "card_play_frame_16", "file": "showcase_card_play_frame_16.png"},
	{"stage": "monster_spawn", "file": "showcase_monster_spawn_1600x960.png"},
	{"stage": "monster_attack_frame_00", "file": "showcase_monster_attack_frame_00.png"},
	{"stage": "monster_attack_frame_12", "file": "showcase_monster_attack_frame_12.png"},
	{"stage": "monster_attack_frame_24", "file": "showcase_monster_attack_frame_24.png"},
	{"stage": "public_track_reveal", "file": "showcase_public_track_reveal_1600x960.png"},
	{"stage": "bid_highlight", "file": "showcase_bid_highlight_1600x960.png"},
	{"stage": "balance_report_preview", "file": "balance_report_preview_1600x960.png"},
	{"stage": "board_idle", "file": "first_table_board_idle_1600x960.png"},
	{"stage": "card_play_frame_16", "file": "first_table_card_play_frame_16.png"},
	{"stage": "monster_attack_frame_24", "file": "monster_pressure_attack_frame_24.png"},
	{"stage": "public_track_reveal", "file": "public_track_intro_reveal_1600x960.png"},
	{"stage": "bid_highlight", "file": "bid_practice_highlight_1600x960.png"},
]

var _saved_paths: Array[String] = []
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_prepare_snapshot_dir()
	_place_capture_window()
	var packed := load(SHOWCASE_SCENE) as PackedScene
	if packed == null:
		push_error("showcase_frame_capture failed: scene did not load")
		quit(1)
		return
	var showcase := packed.instantiate() as Control
	get_root().size = CAPTURE_SIZE
	get_root().add_child(showcase)
	await _pump_frames(8)
	for frame_variant in FRAME_PLAN:
		var frame: Dictionary = frame_variant
		showcase.call("play_stage", str(frame.get("stage", "board_idle")))
		await _pump_frames(8)
		await _save_viewport_snapshot(str(frame.get("file", "showcase.png")))
	get_root().remove_child(showcase)
	showcase.queue_free()
	if _failures.is_empty():
		print("Showcase frame capture complete:")
		for path in _saved_paths:
			print(path)
		quit(0)
	else:
		printerr("Showcase frame capture failed:")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)


func _prepare_snapshot_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SNAPSHOT_DIR))


func _place_capture_window() -> void:
	var screen_count := DisplayServer.get_screen_count()
	var screen_index := 1 if screen_count > 1 else 0
	DisplayServer.window_set_current_screen(screen_index)
	DisplayServer.window_set_size(CAPTURE_SIZE)
	DisplayServer.window_set_position(DisplayServer.screen_get_position(screen_index) + Vector2i(50, 50))


func _pump_frames(count: int) -> void:
	for _i in range(maxi(1, count)):
		await process_frame


func _save_viewport_snapshot(file_name: String) -> void:
	var image := get_root().get_texture().get_image()
	var absolute_path := ProjectSettings.globalize_path("%s/%s" % [SNAPSHOT_DIR, file_name])
	var error := image.save_png(absolute_path)
	if error == OK:
		_saved_paths.append(absolute_path)
	else:
		_failures.append("%s failed with %s" % [file_name, error])
