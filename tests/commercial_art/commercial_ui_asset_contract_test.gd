extends SceneTree

const REVIEW_SCENE := "res://scenes/tools/commercial_art/components/ui/CommercialUiAssetReview.tscn"
const SELECTOR := preload("res://scenes/tools/commercial_art/components/ui/commercial_font_locale_selector.gd")
const ICON_ROOT := "res://assets/third_party/commercial/icons/game_icons"
const UI_ROOT := "res://assets/third_party/commercial/ui"
const FONT_ROOT := "res://assets/third_party/commercial/fonts"
const REQUIRED_ICONS := {
	"life": ["leaf-swirl", "circle_with_leaf_notch", "98ce3ea895325014a928c4b6a6198d611cc7d3bf8375bf0c4fc99256534b9b83", "#59C878"],
	"energy": ["lightning-electron", "diamond", "49d4a332e159add1382ec8b37bfa5865450ddea58565023f54f2dd57ca6fe127", "#FF9F43"],
	"industry": ["cog", "hexagon", "cb39d49ca14c2c46ea7d0dcc9ddccfa040293a0216940079bc9598e2ba0352d2", "#98A3B3"],
	"technology": ["circuitry", "clipped_square", "daa78e6a814481a27864e59d4cf6c835d87ed2ed1562f85ee5d5728f8b68bb9e", "#4EA1FF"],
	"commerce": ["receive-money", "octagon", "1d2754b04cb7bd82d9a4f1ad4a90a96b19694bd738701fc2a0746dbad69cdae7", "#B66CFF"],
	"shipping": ["spaceship", "horizontal_capsule_with_chevrons", "53dd3f562faa3ee2a4185d6358308176db7dbcd18d4b32e6b8500d63d20ebaef", "#35D0C5"],
}
const BOARD_ICONS := [
	"draw_deck", "discard_pile", "shuffle", "merge", "lock", "turn",
	"target", "card_count", "gdp", "cash", "settlement", "player_order",
]
const INPUT_PROMPTS := [
	"mouse_click", "mouse_drag", "mouse_zoom",
	"keyboard_confirm", "keyboard_cancel", "keyboard_navigate",
	"gamepad_confirm", "gamepad_back", "gamepad_navigate",
]
const FONT_FILES := [
	"noto_sans_cjk/NotoSansCJKsc-Regular.otf",
	"noto_sans_cjk/NotoSansCJKsc-Bold.otf",
	"noto_sans_cjk/NotoSansCJKjp-Regular.otf",
	"noto_sans_cjk/NotoSansCJKjp-Bold.otf",
	"oxanium/Oxanium-Medium.ttf",
	"oxanium/Oxanium-SemiBold.ttf",
	"oxanium/Oxanium-Bold.ttf",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_exact_six_color_assets()
	_test_kenney_assets()
	_test_fonts_and_locale_policy()
	await _test_review_scene()
	_test_architecture_boundary()
	_finish()


func _test_exact_six_color_assets() -> void:
	var shapes: Dictionary = {}
	for asset_id in REQUIRED_ICONS.keys():
		var row: Array = REQUIRED_ICONS[asset_id]
		var slug := str(row[0])
		var shape := str(row[1])
		var expected_source_sha := str(row[2])
		var expected_color := str(row[3])
		var source_path := "%s/source/%s.svg" % [ICON_ROOT, slug]
		var normalized_path := "%s/normalized/%s.svg" % [ICON_ROOT, asset_id]
		_expect(FileAccess.file_exists(source_path), "%s_exact_source_svg_exists" % asset_id)
		_expect(FileAccess.get_sha256(source_path) == expected_source_sha, "%s_exact_source_svg_sha" % asset_id)
		var normalized_text := FileAccess.get_file_as_string(normalized_path)
		_expect(normalized_text.contains('viewBox="0 0 128 128"'), "%s_normalized_viewbox" % asset_id)
		_expect(normalized_text.contains('data-asset-key="icon.asset.%s"' % asset_id), "%s_stable_asset_key" % asset_id)
		_expect(normalized_text.contains('data-base-shape="%s"' % shape), "%s_noncolor_shape_contract" % asset_id)
		_expect(normalized_text.contains(expected_color), "%s_exact_color" % asset_id)
		_expect(normalized_text.contains('data-source-sha256="%s"' % expected_source_sha), "%s_source_fingerprint_embedded" % asset_id)
		shapes[shape] = true
		for size in [128, 64, 32]:
			var png_path := "%s/normalized/%s_%d.png" % [ICON_ROOT, asset_id, size]
			_expect(FileAccess.file_exists(png_path), "%s_%d_png_exists" % [asset_id, size])
			var texture := load(png_path) as Texture2D
			_expect(texture != null and texture.get_width() == size and texture.get_height() == size, "%s_%d_png_dimensions" % [asset_id, size])
	_expect(shapes.size() == 6, "six_unique_base_shapes")
	var attribution := FileAccess.get_file_as_string("%s/ATTRIBUTION.txt" % ICON_ROOT)
	for required in ["Leaf Swirl", "Lightning Electron", "Cog", "Circuitry", "Receive Money", "Spaceship", "Lorc", "Delapouite", "CC BY 3.0"]:
		_expect(attribution.contains(required), "attribution_contains_%s" % required.to_snake_case())
	_expect(FileAccess.get_file_as_string("%s/LICENSE-CC-BY-3.0.txt" % ICON_ROOT).contains("Attribution 3.0 Unported"), "cc_by_3_legal_text_present")


func _test_kenney_assets() -> void:
	var panel_root := "%s/kenney_ui_scifi" % UI_ROOT
	for panel in ["panel_primary_9slice.svg", "panel_popup_9slice.svg", "button_primary_9slice.svg"]:
		var text := FileAccess.get_file_as_string("%s/%s" % [panel_root, panel])
		_expect(text.contains('data-nine-slice="true"'), "%s_nine_slice_contract" % panel.get_basename())
		for color in ["#111720", "#19222E", "#222F3D", "#617184", "#D8E5F0"]:
			_expect(text.contains(color), "%s_palette_%s" % [panel.get_basename(), color.trim_prefix("#")])
		_expect(text.contains('opacity="0.94"'), "%s_opacity_in_range" % panel.get_basename())
	for path in [
		"%s/kenney_pattern_pack/card_back_pattern.svg" % UI_ROOT,
		"%s/kenney_pattern_pack/asset_base_pattern.svg" % UI_ROOT,
	]:
		_expect(FileAccess.get_file_as_string(path).contains("low_frequency=true"), "%s_low_frequency_contract" % path.get_file().get_basename())
	for icon in BOARD_ICONS:
		_expect(FileAccess.file_exists("%s/kenney_board_game_icons/icons/%s.png" % [UI_ROOT, icon]), "board_icon_%s_exists" % icon)
	for prompt in INPUT_PROMPTS:
		var path := "%s/kenney_input_prompts/icons/%s.svg" % [UI_ROOT, prompt]
		_expect(FileAccess.file_exists(path), "input_prompt_%s_exists" % prompt)
		_expect(FileAccess.get_file_as_string(path).contains("supported_input_only=true"), "input_prompt_%s_supported_only" % prompt)
	_expect(not FileAccess.file_exists("%s/kenney_input_prompts/icons/gamepad_zoom.svg" % UI_ROOT), "unsupported_gamepad_zoom_not_packaged")
	for license_path in [
		"%s/kenney_ui_scifi/LICENSE-CC0.txt" % UI_ROOT,
		"%s/kenney_board_game_icons/LICENSE-CC0.txt" % UI_ROOT,
		"%s/kenney_input_prompts/LICENSE-CC0.txt" % UI_ROOT,
		"%s/kenney_pattern_pack/LICENSE-CC0.txt" % UI_ROOT,
	]:
		_expect(FileAccess.get_file_as_string(license_path).contains("Creative Commons Zero, CC0"), "%s_cc0_license" % license_path.get_base_dir().get_file())


func _test_fonts_and_locale_policy() -> void:
	for relative_path in FONT_FILES:
		var path := "%s/%s" % [FONT_ROOT, relative_path]
		_expect(FileAccess.file_exists(path), "%s_exists" % relative_path.get_file().get_basename())
		var file := FileAccess.open(path, FileAccess.READ)
		_expect(file != null and file.get_length() > 0 and file.get_length() <= 25 * 1024 * 1024, "%s_under_25mb" % relative_path.get_file().get_basename())
	_expect(FileAccess.get_file_as_string("%s/noto_sans_cjk/OFL-1.1.txt" % FONT_ROOT).contains("SIL OPEN FONT LICENSE Version 1.1"), "noto_ofl_present")
	_expect(FileAccess.get_file_as_string("%s/oxanium/OFL-1.1.txt" % FONT_ROOT).contains("SIL Open Font License, Version 1.1"), "oxanium_ofl_present")
	_expect(SELECTOR.body_font_path("zh_Hans") == SELECTOR.SC_REGULAR, "chinese_defaults_to_sc_regular")
	_expect(SELECTOR.body_font_path("zh-CN", true) == SELECTOR.SC_BOLD, "chinese_bold_uses_sc")
	_expect(SELECTOR.body_font_path("ja_JP") == SELECTOR.JP_REGULAR, "japanese_locale_uses_jp_regular")
	_expect(SELECTOR.body_font_path("ja", true) == SELECTOR.JP_BOLD, "japanese_bold_uses_jp")
	_expect(SELECTOR.display_font_path("medium") == SELECTOR.DISPLAY_MEDIUM, "display_medium_uses_oxanium")
	_expect(SELECTOR.display_font_path("semibold") == SELECTOR.DISPLAY_SEMIBOLD, "display_semibold_uses_oxanium")
	_expect(SELECTOR.display_font_path("bold") == SELECTOR.DISPLAY_BOLD, "display_bold_uses_oxanium")
	_expect(not bool(SELECTOR.contract_snapshot().get("oxanium_cjk_body_allowed", true)), "oxanium_forbidden_for_cjk_body")


func _test_review_scene() -> void:
	var packed := load(REVIEW_SCENE) as PackedScene
	_expect(packed != null, "commercial_ui_review_scene_loads")
	if packed == null:
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var snapshot: Dictionary = scene.call("debug_snapshot")
	if OS.get_cmdline_user_args().has("--print-layout"):
		print("COMMERCIAL_UI_LAYOUT %s" % JSON.stringify(scene.call("layout_snapshot")))
	var layout: Dictionary = scene.call("layout_snapshot")
	var root_layout: Dictionary = layout.get("root", {})
	var side_layout: Dictionary = layout.get("side_panel", {})
	var root_size: Array = root_layout.get("size", [])
	var side_position: Array = side_layout.get("global_position", [])
	var side_size: Array = side_layout.get("size", [])
	_expect(root_size == [1600.0, 960.0], "review_scene_matches_project_design_viewport")
	_expect(side_position.size() == 2 and side_size.size() == 2 and float(side_position[0]) + float(side_size[0]) <= 1578.0, "review_scene_side_panel_fits_safe_width")
	_expect(bool(snapshot.get("review_only", false)), "review_scene_declares_review_only")
	_expect(not bool(snapshot.get("creates_session", true)), "review_scene_creates_no_session")
	_expect(not bool(snapshot.get("writes_save", true)), "review_scene_writes_no_save")
	_expect(not bool(snapshot.get("consumes_rng", true)), "review_scene_consumes_no_rng")
	_expect(int(snapshot.get("six_color_icon_count", 0)) == 6, "review_scene_six_color_coverage")
	var keys: Array = snapshot.get("six_color_icon_keys", [])
	for asset_id in REQUIRED_ICONS.keys():
		_expect(keys.has("icon.asset.%s" % asset_id), "review_scene_has_%s_key" % asset_id)
	var frame_keys: Array = snapshot.get("card_frame_keys", [])
	for frame_key in ["card.frame.normal", "card.frame.commodity", "card.frame.bound_action", "card.back.normal"]:
		_expect(frame_keys.has(frame_key), "review_scene_has_%s" % frame_key.replace(".", "_"))
	_expect(int(snapshot.get("input_prompt_count", 0)) == 9, "review_scene_supported_input_prompt_count")
	_expect(int(snapshot.get("board_icon_count", 0)) == 12, "review_scene_board_icon_count")
	var normal_card := scene.get_node_or_null("SafeMargin/Rows/Body/CardsPanel/CardsMargin/CardRow/NormalSlot/NormalCard")
	_expect(normal_card != null and normal_card.has_method("contract_snapshot"), "review_card_contract_available")
	if normal_card != null and normal_card.has_method("contract_snapshot"):
		var card: Dictionary = normal_card.call("contract_snapshot")
		_expect(is_equal_approx(float(card.get("hover_scale", 0.0)), 1.08), "hover_scale_exact")
		_expect(is_equal_approx(float(card.get("hover_lift_pixels", 0.0)), 28.0), "hover_lift_exact")
		_expect(int(card.get("hover_duration_ms", 0)) == 120, "hover_duration_exact")
		_expect(is_equal_approx(float(card.get("drag_deadzone_pixels", 0.0)), 8.0), "drag_deadzone_exact")
		_expect(int(card.get("drag_lift_duration_ms", 0)) == 110, "drag_lift_duration_exact")
		_expect(is_equal_approx(float(card.get("drag_max_tilt_degrees", 0.0)), 4.0), "drag_tilt_exact")
		_expect(int(card.get("selected_outline_pixels", 0)) == 2, "selected_outline_exact")
		_expect(int(card.get("legal_target_glow_pixels", 0)) == 3, "legal_target_glow_exact")
		_expect(not bool(card.get("mutates_gameplay_state", true)) and not bool(card.get("consumes_rng", true)) and not bool(card.get("submits_gameplay_intent", true)), "card_interaction_is_presentation_only")
	scene.queue_free()
	await process_frame


func _test_architecture_boundary() -> void:
	var source_paths := [
		"res://scenes/tools/commercial_art/components/ui/commercial_font_locale_selector.gd",
		"res://scenes/tools/commercial_art/components/ui/commercial_review_card.gd",
		"res://scenes/tools/commercial_art/components/ui/commercial_asset_token.gd",
		"res://scenes/tools/commercial_art/components/ui/commercial_ui_asset_review.gd",
	]
	for path in source_paths:
		var text := FileAccess.get_file_as_string(path)
		for forbidden in ["V06SaveOwnerRegistry", "GameRuntimeCoordinator", "HTTPRequest", "HTTPClient", "RandomNumberGenerator", "scripts/main.gd"]:
			_expect(not text.contains(forbidden), "%s_has_no_%s" % [path.get_file().get_basename(), forbidden.to_snake_case()])


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("COMMERCIAL_UI_ASSET_CONTRACT_PASS %d/%d" % [_checks, _checks])
		quit(0)
		return
	for failure in _failures:
		push_error("COMMERCIAL_UI_ASSET_CONTRACT_FAIL %s" % failure)
	print("COMMERCIAL_UI_ASSET_CONTRACT_FAIL %d/%d" % [_checks - _failures.size(), _checks])
	quit(1)
