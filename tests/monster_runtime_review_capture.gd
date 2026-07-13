extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const CARD_ART_SCRIPT_PATH := "res://scripts/card_art_view.gd"
const MONSTER_ART_SCRIPT_PATH := "res://scripts/monster_art_view.gd"
const MAP_VIEW_SCRIPT_PATH := "res://scripts/map_view.gd"
const OUTPUT_DIR := "res://reports/art/monster_reviews"
const CAPTURE_SIZE := Vector2i(1600, 960)

var _failures: Array[String] = []
var _saved_paths: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_prepare_output_dir()
	_place_capture_window()
	DisplayServer.window_set_size(CAPTURE_SIZE)
	get_root().size = CAPTURE_SIZE

	var packed := load(MAIN_SCENE_PATH)
	if not (packed is PackedScene):
		_failures.append("main scene did not load for per-monster runtime review")
		_finish()
		return
	var main := (packed as PackedScene).instantiate()
	get_root().add_child(main)
	if main is CanvasItem:
		(main as CanvasItem).visible = false
	await _pump_frames(2)

	var monster_sources := main.call("_art_identity_audit_monster_sources") as Array
	var action_sources := main.call("_art_identity_audit_monster_action_sources") as Array
	var card_sources := await _monster_card_sources(main, monster_sources.size())

	get_root().remove_child(main)
	main.queue_free()
	await _pump_frames(2)

	if monster_sources.is_empty():
		_failures.append("no monsters available for runtime review capture")
		_finish()
		return

	for i in range(monster_sources.size()):
		var monster_source: Dictionary = monster_sources[i] if monster_sources[i] is Dictionary else {}
		var card_source: Dictionary = card_sources[i] if i < card_sources.size() and card_sources[i] is Dictionary else {}
		await _capture_monster_runtime_review(i, monster_source, card_source, _actions_for_monster(action_sources, String(monster_source.get("name", ""))))

	_finish()


func _monster_card_sources(main: Node, count: int) -> Array:
	var result := []
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var card_script := load(CARD_ART_SCRIPT_PATH)
	var probe: Control = null
	if card_script != null:
		probe = card_script.new() as Control
	if probe != null:
		get_root().add_child(probe)
		await process_frame
	for i in range(count):
		var card_name := String(main.call("_monster_card_name", i, 1)) if main.has_method("_monster_card_name") else ""
		var skill: Dictionary = coordinator.call("card_definition", card_name) as Dictionary if card_name != "" and coordinator != null else {}
		var source := {
			"name": card_name,
			"kind": String(skill.get("kind", "monster_card")),
			"tags": String(main.call("_skill_tag_text", skill)) if main.has_method("_skill_tag_text") else "怪兽卡",
			"rank": int(coordinator.call("card_rank", card_name)) if coordinator != null else 1,
			"accent": main.call("_card_theme_color", skill) as Color if main.has_method("_card_theme_color") else Color("#ef4444"),
			"stats": String(main.call("_art_identity_card_stats", card_name, skill)) if main.has_method("_art_identity_card_stats") else "",
		}
		if probe != null:
			probe.call(
				"set_card",
				String(source.get("name", "")),
				String(source.get("kind", "monster_card")),
				String(source.get("tags", "怪兽卡")),
				source.get("accent", Color("#ef4444")) as Color,
				int(source.get("rank", 1)),
				false,
				String(source.get("stats", ""))
			)
			var profile := probe.call("card_visual_profile_snapshot") as Dictionary
			source["sprite_key"] = String(profile.get("sprite_key", ""))
			source["visual_source_id"] = String(profile.get("visual_source_id", ""))
		result.append(source)
	if probe != null:
		probe.queue_free()
	return result


func _actions_for_monster(action_sources: Array, monster_name: String) -> Array:
	var result := []
	for source_variant in action_sources:
		if not (source_variant is Dictionary):
			continue
		var source := source_variant as Dictionary
		if String(source.get("monster_name", "")) == monster_name:
			result.append(source)
	return result


func _capture_monster_runtime_review(index: int, monster_source: Dictionary, card_source: Dictionary, action_sources: Array) -> void:
	var monster_name := String(monster_source.get("name", "怪兽"))
	var profile: Dictionary = monster_source.get("profile", {}) as Dictionary
	var accent: Color = profile.get("accent", Color("#94a3b8")) as Color

	var board := Control.new()
	board.name = "MonsterRuntimeReview_%02d" % (index + 1)
	board.size = Vector2(CAPTURE_SIZE)
	get_root().add_child(board)
	_add_background(board, accent)
	_add_label(board, "Space Syndicate Monster Review %02d｜%s" % [index + 1, monster_name], Vector2(34, 24), Vector2(1180, 38), 27, Color("#f8fafc"))
	_add_label(board, "逐只验收：本体美术、怪兽卡面、地图 token、动作演出必须能互相对应；MOS/Moth kaiju 只能服务其中一只怪兽。", Vector2(36, 62), Vector2(1480, 26), 14, Color("#cbd5e1"))
	_add_source_strip(board, monster_source, card_source, Vector2(1120, 28))

	_add_monster_art_panel(board, monster_source, Vector2(42, 116), Vector2(360, 500))
	_add_monster_card_panel(board, card_source, Vector2(440, 116), Vector2(260, 360))
	_add_action_profile_panel(board, action_sources, Vector2(740, 116), Vector2(790, 330))
	await _pump_frames(2)
	_add_token_map_panel(board, monster_source, Vector2(440, 520), Vector2(420, 300))
	_add_action_map_panel(board, monster_source, _representative_actions(action_sources), Vector2(900, 482), Vector2(630, 360))
	_add_review_checklist(board, monster_source, card_source, action_sources, Vector2(42, 660), Vector2(360, 216))

	await _pump_frames(40)
	await _save_viewport_snapshot("art_monster_review_%02d.png" % (index + 1))
	get_root().remove_child(board)
	board.queue_free()
	await _pump_frames(2)


func _add_monster_art_panel(parent: Control, monster_source: Dictionary, position: Vector2, size: Vector2) -> void:
	_add_panel(parent, position, size, "图鉴/本体造型")
	var script := load(MONSTER_ART_SCRIPT_PATH)
	if script == null:
		_failures.append("monster art script failed to load")
		return
	var monster := script.new() as Control
	if monster == null:
		_failures.append("monster art view failed to instantiate")
		return
	monster.position = position + Vector2(22, 54)
	monster.size = Vector2(size.x - 44.0, size.y - 88.0)
	monster.custom_minimum_size = monster.size
	monster.call(
		"set_monster",
		String(monster_source.get("name", "")),
		String(monster_source.get("style", "")),
		int(monster_source.get("hp", 0)),
		int(monster_source.get("armor", 0)),
		String(monster_source.get("move_text", "")),
		monster_source.get("profile", {}) as Dictionary,
		false
	)
	var profile_snapshot := monster.call("monster_visual_profile_snapshot") as Dictionary
	monster.set_meta("review_sprite_key", String(profile_snapshot.get("sprite_key", "")))
	parent.add_child(monster)


func _add_monster_card_panel(parent: Control, card_source: Dictionary, position: Vector2, size: Vector2) -> void:
	_add_panel(parent, position, size, "怪兽牌卡面")
	var script := load(CARD_ART_SCRIPT_PATH)
	if script == null:
		_failures.append("card art script failed to load")
		return
	var card := script.new() as Control
	if card == null:
		_failures.append("card art view failed to instantiate")
		return
	card.position = position + Vector2(40, 56)
	card.size = Vector2(180, 250)
	card.custom_minimum_size = card.size
	card.call(
		"set_card",
		String(card_source.get("name", "")),
		String(card_source.get("kind", "monster_card")),
		String(card_source.get("tags", "怪兽卡")),
		card_source.get("accent", Color("#ef4444")) as Color,
		int(card_source.get("rank", 1)),
		false,
		String(card_source.get("stats", ""))
	)
	parent.add_child(card)
	_add_label(parent, _short(String(card_source.get("name", "怪兽牌")), 16), position + Vector2(28, 318), Vector2(size.x - 56, 22), 14, Color("#f8fafc"))
	_add_label(parent, String(card_source.get("stats", "")), position + Vector2(28, 342), Vector2(size.x - 56, 20), 10, Color("#cbd5e1"))


func _add_action_profile_panel(parent: Control, action_sources: Array, position: Vector2, size: Vector2) -> void:
	_add_panel(parent, position, size, "动作 profile / 攻击比例")
	_add_label(parent, "每行必须不是只换名字：motion、effect、range、knock、impact 都要可审计。", position + Vector2(24, 44), Vector2(size.x - 48, 22), 12, Color("#94a3b8"))
	for i in range(min(action_sources.size(), 6)):
		var source: Dictionary = action_sources[i]
		var profile: Dictionary = source.get("profile", {}) as Dictionary
		var y := position.y + 82.0 + float(i) * 38.0
		var effect_color := _effect_color(String(profile.get("effect_layer", "")))
		var chip := ColorRect.new()
		chip.position = Vector2(position.x + 24.0, y + 7.0)
		chip.size = Vector2(16, 16)
		chip.color = effect_color
		parent.add_child(chip)
		_add_label(parent, _short(String(source.get("action_name", "行动")), 12), Vector2(position.x + 50.0, y), Vector2(150, 22), 13, Color("#f8fafc"))
		_add_label(parent, "%s / %s" % [String(profile.get("motion_family", "")), String(profile.get("effect_layer", ""))], Vector2(position.x + 204.0, y), Vector2(290, 22), 11, Color("#cbd5e1"))
		_add_label(parent, "距%dm 击%dm 投%dm %.2fs" % [
			int(round(float(profile.get("range_meters", 0.0)))),
			int(round(float(profile.get("knockback_meters", 0.0)))),
			int(round(float(profile.get("throw_meters", 0.0)))),
			float(profile.get("impact_seconds", 0.0)),
		], Vector2(position.x + 500.0, y), Vector2(250, 22), 11, Color("#fde68a"))


func _add_token_map_panel(parent: Control, monster_source: Dictionary, position: Vector2, size: Vector2) -> void:
	_add_panel(parent, position, size, "主地图 token 比例")
	var map_view := _new_map_view(position + Vector2(18, 52), size - Vector2(36, 74))
	if map_view == null:
		return
	parent.add_child(map_view)
	var profile: Dictionary = monster_source.get("profile", {}) as Dictionary
	var marker := {
		"position": Vector2(390, 190),
		"label": "1",
		"name": String(monster_source.get("name", "怪兽")),
		"color": profile.get("accent", Color("#ef4444")) as Color,
		"slot_color": Color("#facc15"),
		"secondary": profile.get("secondary", Color("#e2e8f0")) as Color,
		"glyph": String(profile.get("glyph", "怪")),
		"motif": String(profile.get("motif", "beast")),
		"upstream_source_id": String(profile.get("upstream_source_id", "")),
		"visual_source_id": String(profile.get("visual_source_id", "")),
		"sprite_key": String(profile.get("sprite_key", "")),
		"sprite_cell": String(profile.get("sprite_cell", "")),
	}
	map_view.call("set_map", _single_monster_districts(), 780.0, 380.0, -1, [], [], [], [], [marker], [], [], "", "monster")
	if map_view.has_method("zoom_to_local_projection"):
		map_view.call("zoom_to_local_projection")


func _add_action_map_panel(parent: Control, monster_source: Dictionary, action_sources: Array, position: Vector2, size: Vector2) -> void:
	_add_panel(parent, position, size, "运行态动作演出")
	var map_view := _new_map_view(position + Vector2(18, 52), size - Vector2(36, 76))
	if map_view == null:
		return
	parent.add_child(map_view)
	var districts := _action_districts(action_sources.size())
	var events := _action_events(monster_source, action_sources)
	map_view.call("set_map", districts, 900.0, 420.0, -1, [], [], [], events, [], [], [], "", "all")
	if map_view.has_method("zoom_to_local_projection"):
		map_view.call("zoom_to_local_projection")


func _new_map_view(position: Vector2, size: Vector2) -> Control:
	var script := load(MAP_VIEW_SCRIPT_PATH)
	if script == null:
		_failures.append("map view script failed to load")
		return null
	var map_view := script.new() as Control
	if map_view == null:
		_failures.append("map view failed to instantiate")
		return null
	map_view.position = position
	map_view.size = size
	map_view.custom_minimum_size = size
	return map_view


func _single_monster_districts() -> Array:
	return [
		{"name": "城市靶区", "center": Vector2(390, 190), "radius_m": 82.0, "polygon": [Vector2(250, 110), Vector2(520, 118), Vector2(538, 268), Vector2(242, 276)], "terrain": "land", "destroyed": false, "city": {"active": true, "hp": 10, "level": 2}, "products": [], "demands": []},
	]


func _action_districts(action_count: int) -> Array:
	var districts := []
	for i in range(maxi(1, action_count) * 2):
		var pair := int(i / 2)
		var endpoint := i % 2
		var x := 125.0 + float(endpoint) * 250.0
		var y := 95.0 + float(pair) * 88.0
		districts.append({
			"name": "动作%d%s" % [pair + 1, "A" if endpoint == 0 else "B"],
			"center": Vector2(x, y),
			"radius_m": 54.0,
			"polygon": [Vector2(x - 70, y - 36), Vector2(x + 74, y - 32), Vector2(x + 66, y + 42), Vector2(x - 64, y + 46)],
			"terrain": "ocean" if pair == 1 else "land",
			"destroyed": false,
			"city": {"active": endpoint == 1, "hp": 10, "level": 1},
			"products": [],
			"demands": [],
		})
	return districts


func _action_events(monster_source: Dictionary, action_sources: Array) -> Array:
	var events := []
	var profile: Dictionary = monster_source.get("profile", {}) as Dictionary
	var accent: Color = profile.get("accent", Color("#ef4444")) as Color
	for i in range(action_sources.size()):
		var source: Dictionary = action_sources[i]
		var action_profile: Dictionary = source.get("profile", {}) as Dictionary
		var from_pos := Vector2(125, 95 + float(i) * 88.0)
		var to_pos := Vector2(375, 95 + float(i) * 88.0)
		var motion := String(action_profile.get("motion_family", ""))
		events.append({
			"kind": "laser" if ["beam_line", "blast_projectile", "repair_beam", "miasma_zone", "roar_wave"].has(motion) else "melee",
			"position": to_pos,
			"from": from_pos,
			"to": to_pos,
			"color": accent.lerp(_effect_color(String(action_profile.get("effect_layer", ""))), 0.36),
			"label": String(source.get("action_name", "行动")),
			"life": 0.58,
			"duration": 1.20,
			"radius_m": max(80.0, float(action_profile.get("range_meters", 120.0))),
			"motion_family": motion,
			"pose_key": String(action_profile.get("pose_key", "")),
			"effect_layer": String(action_profile.get("effect_layer", "")),
			"profile_key": String(action_profile.get("profile_key", "")),
			"range_meters": float(action_profile.get("range_meters", 0.0)),
			"knockback_meters": float(action_profile.get("knockback_meters", 0.0)),
			"throw_meters": float(action_profile.get("throw_meters", 0.0)),
			"impact_seconds": float(action_profile.get("impact_seconds", 0.45)),
		})
	return events


func _representative_actions(action_sources: Array) -> Array:
	var selected := []
	var used_motion := {}
	for source_variant in action_sources:
		if selected.size() >= 3:
			break
		if not (source_variant is Dictionary):
			continue
		var source := source_variant as Dictionary
		var profile: Dictionary = source.get("profile", {}) as Dictionary
		var motion := String(profile.get("motion_family", ""))
		if motion == "" or used_motion.has(motion):
			continue
		selected.append(source)
		used_motion[motion] = true
	while selected.size() < min(3, action_sources.size()):
		selected.append(action_sources[selected.size()])
	return selected


func _add_review_checklist(parent: Control, monster_source: Dictionary, card_source: Dictionary, action_sources: Array, position: Vector2, size: Vector2) -> void:
	_add_panel(parent, position, size, "审片硬指标")
	var profile: Dictionary = monster_source.get("profile", {}) as Dictionary
	var lines := [
		"本体 sprite: %s" % String(profile.get("sprite_key", "")),
		"来源: %s" % String(profile.get("upstream_source_id", "")),
		"卡面: %s" % String(card_source.get("name", "")),
		"动作数: %d｜至少 3 个代表动作进地图演出" % action_sources.size(),
		"玩家正式 UI 不显示 source/debug 字段",
	]
	for i in range(lines.size()):
		_add_label(parent, "✓ %s" % lines[i], position + Vector2(22, 48 + i * 30), Vector2(size.x - 44, 24), 12, Color("#dbeafe") if i % 2 == 0 else Color("#cbd5e1"))


func _add_source_strip(parent: Control, monster_source: Dictionary, card_source: Dictionary, position: Vector2) -> void:
	var profile: Dictionary = monster_source.get("profile", {}) as Dictionary
	_add_label(parent, "body: %s" % String(profile.get("visual_source_id", "")), position, Vector2(430, 18), 10, Color("#94a3b8"))
	_add_label(parent, "card: %s" % String(card_source.get("visual_source_id", "")), position + Vector2(0, 18), Vector2(430, 18), 10, Color("#94a3b8"))


func _add_panel(parent: Control, position: Vector2, size: Vector2, title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = position
	panel.size = size
	panel.custom_minimum_size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(Color("#334155"), 0.44)
	style.border_color = Color("#475569")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12.0)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	_add_label(parent, title, position + Vector2(20, 14), Vector2(size.x - 40, 24), 16, Color("#fde68a"))
	return panel


func _add_background(parent: Control, accent: Color) -> void:
	var bg := ColorRect.new()
	bg.name = "MonsterRuntimeReviewBackground"
	bg.color = Color("#020617")
	bg.size = Vector2(CAPTURE_SIZE)
	parent.add_child(bg)
	var halo := ColorRect.new()
	halo.name = "MonsterRuntimeReviewHalo"
	halo.color = Color("#020617").lerp(accent, 0.16)
	halo.position = Vector2(0, 0)
	halo.size = Vector2(CAPTURE_SIZE.x, 96)
	parent.add_child(halo)


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


func _effect_color(effect_layer: String) -> Color:
	match effect_layer:
		"electric_arc":
			return Color("#67e8f9")
		"blade_arc":
			return Color("#e0f2fe")
		"miasma_cloud":
			return Color("#a855f7")
		"repair_green":
			return Color("#22c55e")
		"flame_burst":
			return Color("#fb923c")
		"ground_crack":
			return Color("#92400e")
		"shock_wave":
			return Color("#fde68a")
		"impact_burst":
			return Color("#f97316")
	return Color("#94a3b8")


func _short(value: String, limit: int) -> String:
	var text := value.strip_edges()
	if text.length() <= limit:
		return text
	return "%s…" % text.substr(0, maxi(1, limit - 1))


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
		_saved_paths.append(absolute)


func _finish() -> void:
	if _failures.is_empty():
		print("Monster runtime review capture complete:")
		for path in _saved_paths:
			print(path)
		quit(0)
	else:
		push_error("Monster runtime review capture failed:\n- " + "\n- ".join(_failures))
		quit(_failures.size())
