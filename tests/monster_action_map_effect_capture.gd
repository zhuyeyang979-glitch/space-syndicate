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
		_failures.append("main scene did not load for monster action map-effect capture")
		_finish()
		return
	var main := (packed as PackedScene).instantiate()
	get_root().add_child(main)
	if main is CanvasItem:
		(main as CanvasItem).visible = false
	await _pump_frames(2)
	var action_sources := main.call("_art_identity_audit_monster_action_sources") as Array
	get_root().remove_child(main)
	main.queue_free()
	await _pump_frames(2)

	await _capture_action_effect_sheet(action_sources)
	_finish()


func _capture_action_effect_sheet(action_sources: Array) -> void:
	var board := Control.new()
	board.name = "MonsterActionMapEffectCapture"
	board.size = Vector2(CAPTURE_SIZE)
	get_root().add_child(board)
	_add_background(board)
	_add_label(board, "Space Syndicate Monster Action Map Effects｜主地图怪兽动作演出骨架", Vector2(32, 24), Vector2(1320, 34), 27, Color("#f8fafc"))
	_add_label(board, "硬约束：动作不能只换名字或伤害；MapView 必须消费 motion_family / effect_layer / pose_key，并在桌面上呈现不同攻击语法。", Vector2(34, 62), Vector2(1480, 26), 14, Color("#cbd5e1"))

	var selected_actions := _select_action_sources(action_sources)
	if selected_actions.size() < 6:
		_failures.append("not enough diverse monster action sources for map-effect capture")
		board.queue_free()
		return

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
	map_view.name = "MonsterActionEffectMapView"
	map_view.position = Vector2(72, 116)
	map_view.size = Vector2(1000, 742)
	map_view.custom_minimum_size = map_view.size
	board.add_child(map_view)
	await _pump_frames(1)

	var districts := _districts_for_action_effects(selected_actions)
	var events := _events_for_action_effects(selected_actions)
	map_view.call("set_map", districts, 1500.0, 940.0, -1, [], [], [], events, [], [], [], "", "all")
	if map_view.has_method("zoom_to_local_projection"):
		map_view.call("zoom_to_local_projection")
	_add_legend(board, selected_actions, Vector2(1112, 132))
	await _pump_frames(36)
	await _save_viewport_snapshot("art_monster_action_map_effects_1600x960.png")
	board.queue_free()


func _select_action_sources(action_sources: Array) -> Array:
	var wanted := [
		"beam_line",
		"blast_projectile",
		"dash_melee",
		"roll_crush",
		"miasma_zone",
		"repair_beam",
		"roar_wave",
		"throw_grapple",
	]
	var selected := []
	var used_motion := {}
	for motion in wanted:
		for source_variant in action_sources:
			if not (source_variant is Dictionary):
				continue
			var source := source_variant as Dictionary
			var profile := source.get("profile", {}) as Dictionary
			if String(profile.get("motion_family", "")) != String(motion):
				continue
			if used_motion.has(motion):
				continue
			selected.append(source)
			used_motion[motion] = true
			break
	if selected.size() < 8:
		for source_variant in action_sources:
			if selected.size() >= 8:
				break
			if not (source_variant is Dictionary):
				continue
			var source := source_variant as Dictionary
			var profile := source.get("profile", {}) as Dictionary
			var motion := String(profile.get("motion_family", ""))
			if motion == "" or used_motion.has(motion):
				continue
			selected.append(source)
			used_motion[motion] = true
	return selected


func _districts_for_action_effects(action_sources: Array) -> Array:
	var districts := []
	for i in range(action_sources.size() * 2):
		var pair := int(i / 2)
		var endpoint := i % 2
		var x := 210.0 + float(pair % 2) * 610.0 + float(endpoint) * 230.0
		var y := 150.0 + float(int(pair / 2)) * 205.0
		var terrain := "ocean" if pair % 3 == 1 else "land"
		districts.append({
			"name": "动作验收%d%s" % [pair + 1, "A" if endpoint == 0 else "B"],
			"center": Vector2(x, y),
			"radius_m": 62.0,
			"polygon": [
				Vector2(x - 82.0, y - 52.0),
				Vector2(x + 86.0, y - 46.0),
				Vector2(x + 76.0, y + 58.0),
				Vector2(x - 74.0, y + 62.0),
			],
			"terrain": terrain,
			"destroyed": false,
			"city": {"active": endpoint == 1, "hp": 10, "level": 1},
			"products": [],
			"demands": [],
		})
	return districts


func _events_for_action_effects(action_sources: Array) -> Array:
	var events := []
	var colors := [Color("#a855f7"), Color("#fb923c"), Color("#38bdf8"), Color("#facc15"), Color("#22c55e"), Color("#f43f5e"), Color("#60a5fa"), Color("#e879f9")]
	for i in range(action_sources.size()):
		var source: Dictionary = action_sources[i]
		var profile: Dictionary = source.get("profile", {}) as Dictionary
		var from_pos := Vector2(210.0 + float(i % 2) * 610.0, 150.0 + float(int(i / 2)) * 205.0)
		var to_pos := from_pos + Vector2(230.0, 0.0)
		var motion := String(profile.get("motion_family", ""))
		var kind := "laser" if ["beam_line", "blast_projectile", "repair_beam", "miasma_zone", "roar_wave"].has(motion) else "melee"
		events.append({
			"kind": kind,
			"position": to_pos,
			"from": from_pos,
			"to": to_pos,
			"color": colors[i % colors.size()],
			"label": String(source.get("action_name", "兽技")),
			"life": 0.56,
			"duration": 1.20,
			"radius_m": max(80.0, float(profile.get("range_meters", 120.0))),
			"motion_family": motion,
			"pose_key": String(profile.get("pose_key", "")),
			"effect_layer": String(profile.get("effect_layer", "")),
			"profile_key": String(profile.get("profile_key", "")),
			"range_meters": float(profile.get("range_meters", 0.0)),
			"knockback_meters": float(profile.get("knockback_meters", 0.0)),
			"throw_meters": float(profile.get("throw_meters", 0.0)),
			"impact_seconds": float(profile.get("impact_seconds", 0.45)),
		})
	return events


func _add_legend(parent: Control, action_sources: Array, origin: Vector2) -> void:
	_add_label(parent, "地图动作效果核对", origin, Vector2(420, 28), 20, Color("#fde68a"))
	_add_label(parent, "每行显示：怪兽｜动作｜motion_family｜effect_layer。玩家正式 UI 不显示这些开发字段；这里是验收图。", origin + Vector2(0, 32), Vector2(445, 48), 12, Color("#94a3b8"))
	for i in range(action_sources.size()):
		var source: Dictionary = action_sources[i]
		var profile: Dictionary = source.get("profile", {}) as Dictionary
		var y := origin.y + 96.0 + float(i) * 70.0
		var chip := ColorRect.new()
		chip.color = Color("#38bdf8") if i % 2 == 0 else Color("#f97316")
		chip.position = Vector2(origin.x, y + 5.0)
		chip.size = Vector2(18, 18)
		parent.add_child(chip)
		_add_label(parent, "%d｜%s · %s" % [i + 1, String(source.get("monster_name", "怪兽")), String(source.get("action_name", "行动"))], Vector2(origin.x + 28.0, y), Vector2(390, 20), 14, Color("#f8fafc"))
		_add_label(parent, String(profile.get("motion_family", "")), Vector2(origin.x + 28.0, y + 22.0), Vector2(210, 18), 11, Color("#cbd5e1"))
		_add_label(parent, String(profile.get("effect_layer", "")), Vector2(origin.x + 235.0, y + 22.0), Vector2(210, 18), 11, Color("#cbd5e1"))
		_add_label(parent, "range %dm｜knock %dm" % [int(round(float(profile.get("range_meters", 0.0)))), int(round(float(profile.get("knockback_meters", 0.0))))], Vector2(origin.x + 28.0, y + 42.0), Vector2(390, 18), 10, Color("#94a3b8"))


func _add_background(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.name = "MonsterActionEffectBackground"
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
		print("Monster action map-effect capture complete:")
		print(_saved_path)
		quit(0)
	else:
		push_error("Monster action map-effect capture failed:\n- " + "\n- ".join(_failures))
		quit(_failures.size())
