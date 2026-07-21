extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const CARD_ART_SCRIPT_PATH := "res://scripts/card_art_view.gd"
const OUTPUT_DIR := "res://reports/art/card_reviews"
const CAPTURE_SIZE := Vector2i(1600, 960)
const CARDS_PER_PAGE := 8

const REVIEW_CARD_NAMES := [
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
	"业主透镜1",
	"出牌追帧1",
	"供应链保险1",
	"商品看涨1",
	"商品看跌1",
	"港仓囤货1",
	"城市买涨1",
	"城市做空1",
	"短期订单1",
	"星链拆解1",
	"影仓牵引1",
	"相位否决1",
	"制空战斗机1",
	"星海战舰1",
]

const REQUIRED_FIRST_RUN_FOCUS := {
	"城市融资1": "city_money",
	"产业升级1": "factory_upgrade",
	"交通升级1": "transit_route",
	"星际广告1": "broadcast",
	"诱导电波1": "lure_beacon",
	"过载补给1": "supply_cache",
	"移动1": "movement_arrow",
	"普攻1": "impact_attack",
	"格挡1": "shield_guard",
	"区域破坏1": "district_crack",
}

const REQUIRED_REVIEW_ANCHORS := {
	"城市融资1": "finance_tower",
	"产业升级1": "factory_core",
	"交通升级1": "transit_grid",
	"星际广告1": "broadcast_array",
	"诱导电波1": "lure_beacon",
	"过载补给1": "supply_cache",
	"移动1": "motion_vector",
	"普攻1": "impact_core",
	"格挡1": "shield_gate",
	"区域破坏1": "fracture_map",
	"业主透镜1": "intel_lens",
	"出牌追帧1": "intel_lens",
	"供应链保险1": "shield_route",
	"商品看涨1": "market_up",
	"商品看跌1": "market_down",
	"港仓囤货1": "warehouse_stack",
	"城市买涨1": "market_up",
	"城市做空1": "market_down",
	"短期订单1": "contract_bridge",
	"星链拆解1": "link_breaker",
	"影仓牵引1": "hand_pull",
	"相位否决1": "phase_null",
	"制空战斗机1": "air_wing",
	"星海战舰1": "naval_fleet",
}

const REQUIRED_REVIEW_SPRITES := {
	"城市融资1": "game_icon_bank",
	"产业升级1": "mech",
	"交通升级1": "kenney_enemy_ufo",
	"星际广告1": "laser",
	"诱导电波1": "monster_battler_rodent",
	"过载补给1": "tank",
	"移动1": "kenney_fish",
	"普攻1": "monster_battler_salamander",
	"格挡1": "atfield",
	"区域破坏1": "monster_battler_rock",
	"业主透镜1": "kenney_alien_blue",
	"出牌追帧1": "kenney_alien_blue",
	"供应链保险1": "atfield",
	"商品看涨1": "kenney_fish",
	"商品看跌1": "kenney_slime",
	"港仓囤货1": "game_icon_warehouse",
	"城市买涨1": "game_icon_profit",
	"城市做空1": "game_icon_fall_down",
	"短期订单1": "game_icon_contract",
	"星链拆解1": "game_icon_breaking_chain",
	"影仓牵引1": "game_icon_robber_hand",
	"相位否决1": "game_icon_cancel",
	"制空战斗机1": "kenney_enemy_ufo",
	"星海战舰1": "tank",
}

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
	var review_sources := await _review_card_sources(main)
	get_root().remove_child(main)
	main.queue_free()
	await _pump_frames(2)

	if _failures.is_empty():
		await _capture_review_pages(review_sources)
	_finish()


func _review_card_sources(main: Node) -> Array:
	var audit_sources := main.call("_art_identity_audit_card_sources") as Array
	var by_name := {}
	for source_variant in audit_sources:
		var source: Dictionary = source_variant
		by_name[String(source.get("name", ""))] = source
	var card_script := load(CARD_ART_SCRIPT_PATH)
	if card_script == null:
		_failures.append("card art script did not load")
		return []
	var probe := card_script.new() as Control
	if probe == null:
		_failures.append("CardArtView did not instantiate")
		return []
	get_root().add_child(probe)
	await process_frame

	var selected: Array = []
	var profile_keys := {}
	var sprite_counts := {}
	for card_name_variant in REVIEW_CARD_NAMES:
		var card_name := String(card_name_variant)
		if not by_name.has(card_name):
			_failures.append("review card missing from audit source list: %s" % card_name)
			continue
		var decorated := _decorated_card_source(probe, by_name[card_name] as Dictionary)
		var profile_key := String(decorated.get("_profile_key", ""))
		if profile_key == "":
			_failures.append("review card lacks profile key: %s" % card_name)
		elif profile_keys.has(profile_key):
			_failures.append("review cards share visual profile key: %s and %s" % [card_name, String(profile_keys[profile_key])])
		profile_keys[profile_key] = card_name
		if REQUIRED_FIRST_RUN_FOCUS.has(card_name):
			var expected_focus := String(REQUIRED_FIRST_RUN_FOCUS[card_name])
			if String(decorated.get("_first_run_art_focus", "")) != expected_focus:
				_failures.append("review card %s expected first-run focus %s, got %s" % [
					card_name,
					expected_focus,
					String(decorated.get("_first_run_art_focus", "")),
				])
		if REQUIRED_REVIEW_ANCHORS.has(card_name):
			var expected_anchor := String(REQUIRED_REVIEW_ANCHORS[card_name])
			if String(decorated.get("_illustration_anchor", "")) != expected_anchor:
				_failures.append("review card %s expected illustration anchor %s, got %s" % [
					card_name,
					expected_anchor,
					String(decorated.get("_illustration_anchor", "")),
				])
		if REQUIRED_REVIEW_SPRITES.has(card_name):
			var expected_sprite := String(REQUIRED_REVIEW_SPRITES[card_name])
			if String(decorated.get("_sprite_key", "")) != expected_sprite:
				_failures.append("review card %s expected sprite %s, got %s" % [
					card_name,
					expected_sprite,
					String(decorated.get("_sprite_key", "")),
				])
		var sprite_key := String(decorated.get("_sprite_key", ""))
		sprite_counts[sprite_key] = int(sprite_counts.get(sprite_key, 0)) + 1
		selected.append(decorated)
	probe.queue_free()
	if selected.size() != REVIEW_CARD_NAMES.size():
		_failures.append("expected %d review cards, got %d" % [REVIEW_CARD_NAMES.size(), selected.size()])
	if sprite_counts.size() < 12:
		_failures.append("expected at least 12 sprite families across review cards, got %d" % sprite_counts.size())
	for sprite_key_variant in sprite_counts.keys():
		var sprite_key := String(sprite_key_variant)
		var count := int(sprite_counts[sprite_key])
		if count > 3:
			_failures.append("review sprite %s appears %d times; max allowed is 3 for first-run review cards" % [sprite_key, count])
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
	decorated["_sprite_cell"] = String(profile.get("sprite_cell", ""))
	decorated["_layout_variant"] = str(profile.get("layout_variant", ""))
	decorated["_palette_variant"] = str(profile.get("palette_variant", ""))
	decorated["_effect_variant"] = str(profile.get("effect_variant", ""))
	decorated["_composition_variant"] = str(profile.get("composition_variant", ""))
	decorated["_motif_family"] = String(profile.get("motif_family", ""))
	decorated["_first_run_art_focus"] = String(profile.get("first_run_art_focus", ""))
	decorated["_illustration_anchor"] = String(profile.get("illustration_anchor", ""))
	return decorated


func _capture_review_pages(card_sources: Array) -> void:
	var page_count := int(ceil(float(card_sources.size()) / float(CARDS_PER_PAGE)))
	for page_index in range(page_count):
		var board := Control.new()
		board.name = "CardRuntimeReviewPage%02d" % (page_index + 1)
		board.size = Vector2(CAPTURE_SIZE)
		board.z_index = 1000
		get_root().add_child(board)
		_add_background(board)
		_add_title(board, "Card Review｜首局高频牌逐张审片 %d/%d" % [page_index + 1, page_count], Vector2(32, 16), 30)
		_add_subtitle(board, "每张卡必须有独立 visual profile、可读插画重心、手牌缩略图、简洁玩家速读；开发字段只出现在本审片图。", Vector2(34, 60), 14)
		for local_index in range(CARDS_PER_PAGE):
			var source_index := page_index * CARDS_PER_PAGE + local_index
			if source_index >= card_sources.size():
				break
			var source: Dictionary = card_sources[source_index]
			var column := local_index % 4
			var row := int(local_index / 4)
			_add_card_review_tile(board, source, Vector2(34 + column * 390, 104 + row * 410), source_index + 1)
		await _pump_frames(10)
		await _save_viewport_snapshot("art_card_review_first_run_%02d.png" % (page_index + 1))
		get_root().remove_child(board)
		board.queue_free()
		await _pump_frames(2)


func _add_card_review_tile(parent: Control, source: Dictionary, pos: Vector2, serial: int) -> void:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = Vector2(360, 368)
	panel.custom_minimum_size = panel.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0f172a").lerp(source.get("accent", Color("#94a3b8")) as Color, 0.10)
	style.border_color = (source.get("accent", Color("#94a3b8")) as Color).lightened(0.20)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var name := String(source.get("name", ""))
	var accent := source.get("accent", Color("#94a3b8")) as Color
	_add_label(parent, "%02d｜%s" % [serial, name], pos + Vector2(14, 10), Vector2(226, 24), 15, Color("#f8fafc"))
	_add_label(parent, "%s｜%s" % [_kind_label(String(source.get("kind", ""))), _short(String(source.get("tags", "")), 22)], pos + Vector2(14, 34), Vector2(260, 24), 10, Color("#cbd5e1"))

	var card_script := load(CARD_ART_SCRIPT_PATH)
	var full_card := card_script.new() as Control
	full_card.name = "ReviewCardFull_%02d" % serial
	full_card.position = pos + Vector2(14, 66)
	full_card.size = Vector2(132, 184)
	full_card.custom_minimum_size = full_card.size
	full_card.call("set_card", name, String(source.get("kind", "")), String(source.get("tags", "")), accent, int(source.get("rank", 1)), false, String(source.get("stats", "")))
	parent.add_child(full_card)

	var mini_card := card_script.new() as Control
	mini_card.name = "ReviewCardMini_%02d" % serial
	mini_card.position = pos + Vector2(166, 72)
	mini_card.size = Vector2(82, 114)
	mini_card.custom_minimum_size = mini_card.size
	mini_card.call("set_card", name, String(source.get("kind", "")), String(source.get("tags", "")), accent, int(source.get("rank", 1)), true, String(source.get("stats", "")))
	parent.add_child(mini_card)
	_add_label(parent, "手牌缩略图", pos + Vector2(168, 190), Vector2(92, 18), 9, Color("#94a3b8"))

	var quick_text := _player_scan_text(source)
	_add_label(parent, quick_text, pos + Vector2(166, 216), Vector2(176, 54), 11, Color("#e2e8f0"))
	_add_chip(parent, pos + Vector2(166, 278), "美术:%s" % _short(String(source.get("_visual_source_id", "")), 20), accent)
	_add_chip(parent, pos + Vector2(166, 306), "重心:%s" % String(source.get("_illustration_anchor", "")), accent)
	_add_chip(parent, pos + Vector2(166, 334), "纹样:%s" % String(source.get("_motif_family", "")), accent)

	_add_label(parent, "profile", pos + Vector2(14, 260), Vector2(80, 18), 12, Color("#fde68a"))
	_add_label(parent, "sprite %s / %s" % [String(source.get("_sprite_key", "")), String(source.get("_sprite_cell", ""))], pos + Vector2(14, 282), Vector2(136, 34), 9, Color("#cbd5e1"))
	_add_label(parent, "L%s P%s E%s C%s" % [
		String(source.get("_layout_variant", "")),
		String(source.get("_palette_variant", "")),
		String(source.get("_effect_variant", "")),
		String(source.get("_composition_variant", "")),
	], pos + Vector2(14, 320), Vector2(136, 20), 9, Color("#94a3b8"))
	_add_label(parent, "玩家正式 UI 不显示这些 source/profile 字段", pos + Vector2(14, 340), Vector2(150, 22), 8, Color("#64748b"))


func _player_scan_text(source: Dictionary) -> String:
	var stats := String(source.get("stats", ""))
	var tags := String(source.get("tags", ""))
	var kind := _kind_label(String(source.get("kind", "")))
	var route := String(source.get("_motif_family", ""))
	var parts := []
	if stats != "":
		parts.append(stats)
	if tags != "":
		parts.append(_short(tags, 26))
	parts.append(kind)
	parts.append(route)
	return "｜".join(parts)


func _kind_label(kind: String) -> String:
	if kind == "":
		return "卡牌"
	if kind.contains("monster"):
		return "怪兽"
	if kind.contains("military"):
		return "军队"
	if kind.contains("contract"):
		return "合约"
	if kind.contains("intel"):
		return "情报"
	if kind.contains("futures") or kind.contains("gdp") or kind.contains("speculation"):
		return "金融"
	if kind.contains("economy") or kind.contains("product"):
		return "经济"
	if kind.contains("direct"):
		return "互动"
	return kind.replace("_", " ")


func _add_background(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = Color("#030712")
	bg.size = Vector2(CAPTURE_SIZE)
	parent.add_child(bg)
	for i in range(9):
		var wash := ColorRect.new()
		wash.color = Color("#172554").lerp(Color("#581c87"), float(i) / 8.0)
		wash.color.a = 0.07
		wash.position = Vector2(20 + i * 170, 92 + (i % 3) * 250)
		wash.size = Vector2(310, 220)
		parent.add_child(wash)


func _add_title(parent: Control, text: String, pos: Vector2, font_size: int) -> void:
	_add_label(parent, text, pos, Vector2(1250, 44), font_size, Color("#f8fafc"))


func _add_subtitle(parent: Control, text: String, pos: Vector2, font_size: int) -> void:
	_add_label(parent, text, pos, Vector2(1450, 28), font_size, Color("#94a3b8"))


func _add_chip(parent: Control, pos: Vector2, text: String, accent: Color) -> void:
	var chip := PanelContainer.new()
	chip.position = pos
	chip.size = Vector2(178, 22)
	chip.custom_minimum_size = chip.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.24)
	style.border_color = accent
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	chip.add_theme_stylebox_override("panel", style)
	parent.add_child(chip)
	_add_label(parent, _short(text, 26), pos + Vector2(8, 3), Vector2(164, 16), 8, Color("#f8fafc"))


func _add_label(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


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
		print("Card runtime review capture complete:")
		for path in _saved_paths:
			print(path)
		quit(0)
	else:
		printerr("Card runtime review capture failed:")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
