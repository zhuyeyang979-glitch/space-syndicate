extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const CARD_ART_SCRIPT_PATH := "res://scripts/card_art_view.gd"
const MONSTER_ART_SCRIPT_PATH := "res://scripts/monster_art_view.gd"
const OUTPUT_DIR := "res://reports/art"
const CAPTURE_SIZE := Vector2i(1600, 960)

var _saved_paths: Array[String] = []
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_prepare_output_dir()
	_place_capture_window()
	var packed := load(MAIN_SCENE_PATH)
	if not (packed is PackedScene):
		_failures.append("main scene did not load")
		_finish()
		return
	var main := (packed as PackedScene).instantiate()
	get_root().add_child(main)
	if main is CanvasItem:
		(main as CanvasItem).visible = false
	await _pump_frames(2)
	var card_sources := _selected_card_sources(main, 16)
	var monster_sources := main.call("_art_identity_audit_monster_sources") as Array
	var action_sources := main.call("_art_identity_audit_monster_action_sources") as Array
	get_root().remove_child(main)
	main.queue_free()
	await _pump_frames(2)

	await _capture_card_monster_sheet(card_sources, monster_sources)
	await _capture_monster_action_sheet(action_sources)

	_finish()


func _capture_card_monster_sheet(card_sources: Array, monster_sources: Array) -> void:
	var board := Control.new()
	board.name = "ArtCardMonsterContactSheet"
	board.size = Vector2(CAPTURE_SIZE)
	board.z_index = 1000
	get_root().add_child(board)
	_add_background(board)
	_add_title(board, "Space Syndicate Art Contact Sheet｜卡牌插画 + 怪兽造型", Vector2(32, 20), 28)
	_add_subtitle(board, "硬约束：每张卡牌/每只怪兽都有唯一 sprite、构图、色彩、特效、纹样 profile。", Vector2(34, 58), 16)

	var card_script := load(CARD_ART_SCRIPT_PATH)
	for i in range(card_sources.size()):
		var source: Dictionary = card_sources[i]
		var card := card_script.new() as Control
		card.name = "ArtAuditCard_%02d" % i
		card.position = Vector2(34 + (i % 8) * 188, 96 + int(i / 8) * 240)
		card.size = Vector2(118, 164)
		card.custom_minimum_size = card.size
		card.call(
			"set_card",
			String(source.get("name", "")),
			String(source.get("kind", "")),
			String(source.get("tags", "")),
			source.get("accent", Color("#94a3b8")) as Color,
			int(source.get("rank", 1)),
			false,
			String(source.get("stats", ""))
		)
		board.add_child(card)
		_add_label(board, _short(String(source.get("name", "")), 10), card.position + Vector2(0, 170), Vector2(160, 20), 12, Color("#e2e8f0"))
		_add_label(board, _short(String(source.get("_visual_source_id", "")), 22), card.position + Vector2(0, 188), Vector2(170, 28), 8, Color("#94a3b8"))

	_add_section_label(board, "怪兽造型｜每只独立 body source / silhouette / effect layer", Vector2(34, 590))
	var monster_script := load(MONSTER_ART_SCRIPT_PATH)
	for i in range(monster_sources.size()):
		var source: Dictionary = monster_sources[i]
		var monster := monster_script.new() as Control
		monster.name = "ArtAuditMonster_%02d" % i
		monster.position = Vector2(34 + i * 190, 630)
		monster.size = Vector2(150, 210)
		monster.custom_minimum_size = monster.size
		monster.call(
			"set_monster",
			String(source.get("name", "")),
			String(source.get("style", "")),
			int(source.get("hp", 0)),
			int(source.get("armor", 0)),
			String(source.get("move_text", "")),
			source.get("profile", {}) as Dictionary,
			false
		)
		board.add_child(monster)
		var profile := monster.call("monster_visual_profile_snapshot") as Dictionary
		_add_label(board, _short(String(source.get("name", "")), 8), monster.position + Vector2(0, 214), Vector2(160, 22), 12, Color("#f8fafc"))
		_add_label(board, _short(String(profile.get("visual_source_id", "")), 20), monster.position + Vector2(0, 232), Vector2(174, 20), 8, Color("#94a3b8"))

	await _pump_frames(10)
	await _save_viewport_snapshot("art_card_monster_contact_sheet_1600x960.png")
	get_root().remove_child(board)
	board.queue_free()


func _capture_monster_action_sheet(action_sources: Array) -> void:
	var board := Control.new()
	board.name = "MonsterActionProfileContactSheet"
	board.size = Vector2(CAPTURE_SIZE)
	board.z_index = 1000
	get_root().add_child(board)
	_add_background(board)
	_add_title(board, "Monster Action Motion Contract｜怪兽动作比例/攻击演出硬约束", Vector2(32, 20), 26)
	_add_subtitle(board, "每个动作必须有独立 motion family、pose key、effect layer、米制范围/击退/移动比例；击退/投掷 impact ≤ 0.60s。", Vector2(34, 56), 15)

	var grouped := {}
	for source_variant in action_sources:
		var source: Dictionary = source_variant
		var monster_name := String(source.get("monster_name", "怪兽"))
		if not grouped.has(monster_name):
			grouped[monster_name] = []
		(grouped[monster_name] as Array).append(source)

	var monster_index := 0
	for monster_name_variant in grouped.keys():
		var monster_name := String(monster_name_variant)
		var row_y := 96 + monster_index * 96
		_add_label(board, monster_name, Vector2(34, row_y + 12), Vector2(110, 28), 16, Color("#f8fafc"))
		var actions := grouped[monster_name] as Array
		for action_index in range(actions.size()):
			var source: Dictionary = actions[action_index]
			var profile := source.get("profile", {}) as Dictionary
			var x := 160 + action_index * 230
			_add_action_card(board, source, profile, Vector2(x, row_y))
		monster_index += 1

	await _pump_frames(10)
	await _save_viewport_snapshot("art_monster_action_profiles_1600x960.png")
	get_root().remove_child(board)
	board.queue_free()


func _selected_card_sources(main: Node, limit: int) -> Array:
	var sources := main.call("_art_identity_audit_card_sources") as Array
	var script := load(CARD_ART_SCRIPT_PATH)
	var probe := script.new() as Control
	get_root().add_child(probe)
	var deferred: Array = []
	var by_visual_source := {}
	for source_variant in sources:
		var source: Dictionary = source_variant
		var decorated := _decorated_card_source(probe, source)
		var visual_source_id := String(decorated.get("_visual_source_id", ""))
		if visual_source_id != "" and not by_visual_source.has(visual_source_id) and deferred.size() + by_visual_source.size() < sources.size():
			by_visual_source[visual_source_id] = true
		deferred.append(decorated)
	var selected: Array = []
	var selected_names := {}
	for priority_name in [
		"城市融资1",
		"产业升级1",
		"交通升级1",
		"星际广告1",
		"诱导电波1",
		"过载补给1",
		"移动1",
		"普攻1",
		"格挡1",
		"区域破坏1",
	]:
		for source_variant in deferred:
			var source: Dictionary = source_variant
			if String(source.get("name", "")) != String(priority_name):
				continue
			if selected_names.has(priority_name):
				continue
			selected.append(source.duplicate(true))
			selected_names[String(priority_name)] = true
			break
		if selected.size() >= limit:
			probe.queue_free()
			return selected
	var selected_sources := {}
	for source_variant in deferred:
		var source: Dictionary = source_variant
		var visual_source_id := String(source.get("_visual_source_id", ""))
		if selected_names.has(String(source.get("name", ""))):
			continue
		if visual_source_id != "" and not selected_sources.has(visual_source_id):
			selected_sources[visual_source_id] = true
			selected.append(source.duplicate(true))
		if selected.size() >= limit:
			probe.queue_free()
			return selected
	var by_sprite := {}
	for source_variant in deferred:
		var source: Dictionary = source_variant
		var sprite_key := String(source.get("_sprite_key", ""))
		var count := int(by_sprite.get(sprite_key, 0))
		if count < 2 and selected.size() < limit:
			selected.append(source.duplicate(true))
			by_sprite[sprite_key] = count + 1
		if selected.size() >= limit:
			break
	probe.queue_free()
	return selected


func _decorated_card_source(probe: Control, source: Dictionary) -> Dictionary:
	probe.call(
		"set_card",
		String(source.get("name", "")),
		String(source.get("kind", "")),
		String(source.get("tags", "")),
		source.get("accent", Color("#94a3b8")) as Color,
		int(source.get("rank", 1)),
		false,
		String(source.get("stats", ""))
	)
	var profile := probe.call("card_visual_profile_snapshot") as Dictionary
	var decorated := source.duplicate(true)
	decorated["_profile_key"] = String(probe.call("card_visual_profile_key"))
	decorated["_visual_source_id"] = String(profile.get("visual_source_id", ""))
	decorated["_sprite_key"] = String(profile.get("sprite_key", ""))
	return decorated


func _add_action_card(parent: Control, source: Dictionary, profile: Dictionary, pos: Vector2) -> void:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = Vector2(208, 78)
	panel.custom_minimum_size = panel.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(_effect_color(String(profile.get("effect_layer", ""))), 0.18)
	style.border_color = _effect_color(String(profile.get("effect_layer", "")))
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 1)
	panel.add_child(stack)
	var name_label := Label.new()
	name_label.text = _short(String(source.get("action_name", "")), 12)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color("#f8fafc"))
	stack.add_child(name_label)
	var motion_label := Label.new()
	motion_label.text = "%s｜%s" % [String(profile.get("motion_family", "")), String(profile.get("effect_layer", ""))]
	motion_label.add_theme_font_size_override("font_size", 9)
	motion_label.add_theme_color_override("font_color", Color("#cbd5e1"))
	stack.add_child(motion_label)
	var scale_label := Label.new()
	scale_label.text = "距%s 击%s 动%s" % [
		str(int(round(float(profile.get("range_meters", 0.0))))),
		str(int(round(float(profile.get("knockback_meters", 0.0))))),
		str(int(round(float(profile.get("move_override_mps", -1.0))))),
	]
	scale_label.add_theme_font_size_override("font_size", 9)
	scale_label.add_theme_color_override("font_color", Color("#94a3b8"))
	stack.add_child(scale_label)
	var time_label := Label.new()
	time_label.text = "前%.2f / 中%.2f / 后%.2f / impact %.2f" % [
		float(profile.get("anticipation_seconds", 0.0)),
		float(profile.get("active_seconds", 0.0)),
		float(profile.get("recovery_seconds", 0.0)),
		float(profile.get("impact_seconds", 0.0)),
	]
	time_label.add_theme_font_size_override("font_size", 8)
	time_label.add_theme_color_override("font_color", Color("#64748b"))
	stack.add_child(time_label)


func _add_background(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = Color("#030712")
	bg.size = Vector2(CAPTURE_SIZE)
	parent.add_child(bg)
	var wash := ColorRect.new()
	wash.color = Color("#111827")
	wash.color.a = 0.45
	wash.position = Vector2(20, 20)
	wash.size = Vector2(CAPTURE_SIZE.x - 40, CAPTURE_SIZE.y - 40)
	parent.add_child(wash)


func _add_title(parent: Control, text: String, pos: Vector2, font_size: int) -> void:
	_add_label(parent, text, pos, Vector2(1200, 34), font_size, Color("#f8fafc"))


func _add_subtitle(parent: Control, text: String, pos: Vector2, font_size: int) -> void:
	_add_label(parent, text, pos, Vector2(1400, 26), font_size, Color("#94a3b8"))


func _add_section_label(parent: Control, text: String, pos: Vector2) -> void:
	_add_label(parent, text, pos, Vector2(980, 28), 18, Color("#fde68a"))


func _add_label(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _effect_color(effect_layer: String) -> Color:
	match effect_layer:
		"miasma_cloud":
			return Color("#a855f7")
		"repair_green":
			return Color("#22c55e")
		"electric_arc":
			return Color("#38bdf8")
		"blade_arc":
			return Color("#f472b6")
		"impact_burst":
			return Color("#f97316")
		"flame_burst":
			return Color("#ef4444")
		"ground_crack":
			return Color("#d97706")
		"shock_wave":
			return Color("#60a5fa")
		_:
			return Color("#94a3b8")


func _short(text: String, limit: int) -> String:
	if text.length() <= limit:
		return text
	return text.left(maxi(1, limit - 1)) + "…"


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))


func _place_capture_window() -> void:
	var screen_count := DisplayServer.get_screen_count()
	var screen_index := 1 if screen_count > 1 else 0
	DisplayServer.window_set_current_screen(screen_index)
	DisplayServer.window_set_size(CAPTURE_SIZE)
	DisplayServer.window_set_position(DisplayServer.screen_get_position(screen_index) + Vector2i(80, 80))
	get_root().size = CAPTURE_SIZE


func _pump_frames(count: int) -> void:
	for _i in range(maxi(1, count)):
		await process_frame


func _save_viewport_snapshot(file_name: String) -> void:
	var image := get_root().get_texture().get_image()
	var absolute_path := ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	var error := image.save_png(absolute_path)
	if error == OK:
		_saved_paths.append(absolute_path)
	else:
		_failures.append("%s failed with %s" % [file_name, error])


func _finish() -> void:
	if _failures.is_empty():
		print("Art contact sheet capture complete:")
		for path in _saved_paths:
			print(path)
		quit(0)
	else:
		printerr("Art contact sheet capture failed:")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
