extends SceneTree

const SHOWCASE_SCENE := "res://scenes/ui/VerticalSliceShowcase.tscn"
const FIXTURE_PATH := "res://data/showcase/scenario_lab_bridge_fixture.json"
const SNAPSHOT_DIR := "user://space_syndicate_ui_snapshots"
const CAPTURE_SIZE := Vector2i(1600, 960)
const CAPTURE_PLAN := [
	{"scenario_id": "first_table", "file": "scenario_lab_first_table_payload_1600x960.png"},
	{"scenario_id": "monster_pressure", "file": "scenario_lab_monster_pressure_payload_1600x960.png"},
	{"scenario_id": "public_track_intro", "file": "scenario_lab_public_track_intro_payload_1600x960.png"},
	{"scenario_id": "bid_practice", "file": "scenario_lab_bid_practice_payload_1600x960.png"},
	{"scenario_id": "__unsafe__", "file": "scenario_lab_unsafe_payload_rejected_1600x960.png"},
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
		_failures.append("VerticalSliceShowcase scene did not load")
		_finish()
		return
	var fixture := _load_fixture()
	var showcase := packed.instantiate() as Control
	get_root().size = CAPTURE_SIZE
	get_root().add_child(showcase)
	await _pump_frames(8)
	for item_variant in CAPTURE_PLAN:
		var item: Dictionary = item_variant
		var scenario_id := str(item.get("scenario_id", "first_table"))
		var payload := _payload_for(fixture, scenario_id)
		showcase.call("play_scenario_payload", payload)
		await _pump_frames(8)
		await _save_viewport_snapshot(str(item.get("file", "scenario_lab_payload.png")))
	get_root().remove_child(showcase)
	showcase.queue_free()
	_finish()


func _load_fixture() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	return parsed if parsed is Dictionary else {}


func _payload_for(fixture: Dictionary, scenario_id: String) -> Dictionary:
	if scenario_id == "__unsafe__":
		return fixture.get("unsafe_payload_example", {}) if fixture.get("unsafe_payload_example", {}) is Dictionary else {}
	var payloads: Array = fixture.get("payloads", []) if fixture.get("payloads", []) is Array else []
	for payload_variant in payloads:
		if payload_variant is Dictionary and str((payload_variant as Dictionary).get("scenario_id", "")) == scenario_id:
			return payload_variant
	_failures.append("Missing payload for %s" % scenario_id)
	return {}


func _prepare_snapshot_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SNAPSHOT_DIR))


func _place_capture_window() -> void:
	var screen_count := DisplayServer.get_screen_count()
	var screen_index := 1 if screen_count > 1 else 0
	DisplayServer.window_set_current_screen(screen_index)
	DisplayServer.window_set_size(CAPTURE_SIZE)
	DisplayServer.window_set_position(DisplayServer.screen_get_position(screen_index) + Vector2i(80, 80))


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


func _finish() -> void:
	if _failures.is_empty():
		print("Scenario Lab payload capture complete:")
		for path in _saved_paths:
			print(path)
		quit(0)
	else:
		printerr("Scenario Lab payload capture failed:")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
