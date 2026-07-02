extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAP_VIEW_SCRIPT_PATH := "res://scripts/map_view.gd"
const OUTPUT_DIR := "res://reports/art"
const CAPTURE_SIZE := Vector2i(1600, 960)

var _failures: Array[String] = []
var _saved_path := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_prepare_output_dir()
	_place_capture_window()
	DisplayServer.window_set_size(CAPTURE_SIZE)
	get_root().size = CAPTURE_SIZE

	var packed := load(MAIN_SCENE_PATH)
	if not (packed is PackedScene):
		_failures.append("main scene did not load for monster map token capture")
		_finish()
		return
	var main := (packed as PackedScene).instantiate()
	get_root().add_child(main)
	if main is CanvasItem:
		(main as CanvasItem).visible = false
	await _pump_frames(2)
	var monster_sources := main.call("_art_identity_audit_monster_sources") as Array
	get_root().remove_child(main)
	main.queue_free()
	await _pump_frames(2)

	await _capture_map_token_sheet(monster_sources)
	_finish()


func _capture_map_token_sheet(monster_sources: Array) -> void:
	var board := Control.new()
	board.name = "MonsterMapTokenCapture"
	board.size = Vector2(CAPTURE_SIZE)
	get_root().add_child(board)
	_add_background(board)
	_add_label(board, "Space Syndicate Monster Map Tokens｜主地图怪兽 Token 骨架", Vector2(32, 24), Vector2(1200, 34), 28, Color("#f8fafc"))
	_add_label(board, "硬约束：游戏地图上的怪兽不能只靠编号/颜色；必须消费和图鉴一致的 sprite_key / visual_source_id / upstream_source_id。", Vector2(34, 62), Vector2(1450, 26), 15, Color("#cbd5e1"))

	var map_script := load(MAP_VIEW_SCRIPT_PATH)
	if map_script == null:
		_failures.append("map view script did not load")
		board.queue_free()
		return
	var map_view := map_script.new() as Control
	if map_view == null:
		_failures.append("map view did not instantiate")
		board.queue_free()
		return
	map_view.name = "MonsterTokenMapView"
	map_view.position = Vector2(110, 118)
	map_view.size = Vector2(900, 720)
	map_view.custom_minimum_size = map_view.size
	board.add_child(map_view)
	await _pump_frames(1)

	var districts := _districts_for_monster_tokens(monster_sources)
	var markers := _markers_for_monster_tokens(monster_sources)
	map_view.call("set_map", districts, 1400.0, 900.0, -1, [], [], [], [], markers, [], [], "", "monster")
	if map_view.has_method("zoom_to_local_projection"):
		map_view.call("zoom_to_local_projection")

	_add_legend(board, monster_sources, Vector2(1060, 126))
	await _pump_frames(34)
	await _save_viewport_snapshot("art_monster_map_tokens_1600x960.png")
	board.queue_free()


func _districts_for_monster_tokens(monster_sources: Array) -> Array:
	var districts := []
	for i in range(monster_sources.size()):
		var x := 210.0 + float(i % 4) * 300.0
		var y := 190.0 + float(int(i / 4)) * 320.0
		districts.append({
			"name": "Token验收%d" % (i + 1),
			"center": Vector2(x, y),
			"radius_m": 76.0,
			"polygon": [
				Vector2(x - 110.0, y - 88.0),
				Vector2(x + 108.0, y - 70.0),
				Vector2(x + 118.0, y + 76.0),
				Vector2(x - 96.0, y + 96.0),
			],
			"terrain": "land",
			"destroyed": false,
			"city": {"active": i % 2 == 0, "hp": 10, "level": 1},
			"products": [],
			"demands": [],
		})
	return districts


func _markers_for_monster_tokens(monster_sources: Array) -> Array:
	var markers := []
	for i in range(monster_sources.size()):
		var source: Dictionary = monster_sources[i]
		var profile: Dictionary = source.get("profile", {}) as Dictionary
		markers.append({
			"position": Vector2(210.0 + float(i % 4) * 300.0, 190.0 + float(int(i / 4)) * 320.0),
			"label": "%d" % (i + 1),
			"name": String(source.get("name", "怪兽")),
			"color": profile.get("accent", Color("#ef4444")) as Color,
			"slot_color": Color("#facc15"),
			"secondary": profile.get("secondary", Color("#e2e8f0")) as Color,
			"glyph": String(profile.get("glyph", "怪")),
			"motif": String(profile.get("motif", "beast")),
			"upstream_source_id": String(profile.get("upstream_source_id", "")),
			"visual_source_id": String(profile.get("visual_source_id", "")),
			"sprite_key": String(profile.get("sprite_key", "")),
			"sprite_cell": String(profile.get("sprite_cell", "")),
			"down": false,
		})
	return markers


func _add_legend(parent: Control, monster_sources: Array, origin: Vector2) -> void:
	_add_label(parent, "地图 Token 来源核对", origin, Vector2(420, 28), 20, Color("#fde68a"))
	_add_label(parent, "每行显示：怪兽名｜sprite_key｜上游素材源。玩家正式 UI 不会展示这些开发字段；这里是验收图。", origin + Vector2(0, 32), Vector2(460, 42), 12, Color("#94a3b8"))
	for i in range(monster_sources.size()):
		var source: Dictionary = monster_sources[i]
		var profile: Dictionary = source.get("profile", {}) as Dictionary
		var y := origin.y + 92.0 + float(i) * 58.0
		var accent: Color = profile.get("accent", Color("#94a3b8")) as Color
		var chip := ColorRect.new()
		chip.color = accent
		chip.position = Vector2(origin.x, y + 5.0)
		chip.size = Vector2(18, 18)
		parent.add_child(chip)
		_add_label(parent, "%d｜%s" % [i + 1, String(source.get("name", "怪兽"))], Vector2(origin.x + 28.0, y), Vector2(240, 20), 15, Color("#f8fafc"))
		_add_label(parent, String(profile.get("sprite_key", "")), Vector2(origin.x + 28.0, y + 20.0), Vector2(260, 18), 11, Color("#cbd5e1"))
		_add_label(parent, String(profile.get("upstream_source_id", "")), Vector2(origin.x + 250.0, y + 20.0), Vector2(250, 18), 10, Color("#94a3b8"))


func _add_background(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.name = "MonsterMapTokenBackground"
	bg.color = Color("#020617")
	bg.size = Vector2(CAPTURE_SIZE)
	parent.add_child(bg)


func _add_label(parent: Control, text: String, position: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))


func _place_capture_window() -> void:
	var screen_count := DisplayServer.get_screen_count()
	var screen_index := 1 if screen_count > 1 else 0
	var screen_position := DisplayServer.screen_get_position(screen_index)
	DisplayServer.window_set_current_screen(screen_index)
	DisplayServer.window_set_position(screen_position + Vector2i(32, 32))


func _pump_frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _save_viewport_snapshot(file_name: String) -> void:
	var image := get_root().get_texture().get_image()
	var absolute := ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	var err := image.save_png(absolute)
	if err != OK:
		_failures.append("failed to save %s: %s" % [file_name, str(err)])
	else:
		_saved_path = absolute


func _finish() -> void:
	if _failures.is_empty():
		print("Monster map token capture complete:")
		print(_saved_path)
		quit(0)
	else:
		push_error("Monster map token capture failed:\n- " + "\n- ".join(_failures))
		quit(_failures.size())
