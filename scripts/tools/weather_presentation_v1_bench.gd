extends Control
class_name WeatherPresentationV1Bench

const FORECAST_VIEW_MODEL = preload("res://scripts/viewmodels/weather_forecast_view_model.gd")
const OVERLAY_VIEW_MODEL = preload("res://scripts/viewmodels/weather_map_overlay_view_model.gd")
const TELEMETRY_BUFFER = preload("res://scripts/ui/weather/weather_telemetry_buffer.gd")
const FORECAST_STRIP_SCENE = preload("res://scenes/ui/weather/WeatherForecastStrip.tscn")
const MAP_OVERLAY_SCENE = preload("res://scenes/ui/weather/WeatherMapOverlay.tscn")

const CAPTURE_SIZES := [Vector2i(1280, 720), Vector2i(1600, 960), Vector2i(1920, 1080)]
const OUTPUT_DIR := "user://weather_presentation_v1"

@export var auto_capture_on_ready := false

var _forecast_vm := FORECAST_VIEW_MODEL.new()
var _overlay_vm := OVERLAY_VIEW_MODEL.new()
var _telemetry := TELEMETRY_BUFFER.new(256)
var _jump_status: Label
var _mode_surfaces: Array[Control] = []
var _catalog_count := 0


func _ready() -> void:
	_build_surface()
	if auto_capture_on_ready:
		call_deferred("_run_and_quit")


func _run_and_quit() -> void:
	var result := await run_capture_suite()
	for failure: String in result["failures"]:
		push_error(failure)
	get_tree().quit(0 if (result["failures"] as Array).is_empty() else 1)


func run_capture_suite(output_dir: String = OUTPUT_DIR) -> Dictionary:
	var failures: Array[String] = []
	var saved_paths: Array[String] = []
	var bench_scene := load("res://scenes/tools/WeatherPresentationV1Bench.tscn") as PackedScene
	if bench_scene == null:
		return {"failures": ["bench scene failed to load"], "saved_paths": saved_paths}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	for capture_size: Vector2i in CAPTURE_SIZES:
		var viewport := SubViewport.new()
		viewport.name = "WeatherCapture_%dx%d" % [capture_size.x, capture_size.y]
		viewport.size = capture_size
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		viewport.transparent_bg = false
		get_tree().root.add_child(viewport)

		var preview := bench_scene.instantiate() as Control
		preview.set("auto_capture_on_ready", false)
		viewport.add_child(preview)
		preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await _pump_frames(5)

		for layout_failure: String in preview.call("layout_contract_failures", capture_size) as Array:
			failures.append("%dx%d: %s" % [capture_size.x, capture_size.y, layout_failure])
		var image := viewport.get_texture().get_image()
		if image.is_empty() or image.get_width() != capture_size.x or image.get_height() != capture_size.y:
			failures.append("%dx%d: capture dimensions invalid" % [capture_size.x, capture_size.y])
		elif not _has_visible_pixels(image):
			failures.append("%dx%d: capture was visually blank" % [capture_size.x, capture_size.y])
		else:
			var path := "%s/weather_presentation_v1_%dx%d.png" % [output_dir, capture_size.x, capture_size.y]
			var save_error := image.save_png(path)
			if save_error != OK:
				failures.append("%dx%d: screenshot save failed (%d)" % [capture_size.x, capture_size.y, save_error])
			else:
				saved_paths.append(ProjectSettings.globalize_path(path))

		viewport.remove_child(preview)
		preview.queue_free()
		get_tree().root.remove_child(viewport)
		viewport.queue_free()
		await _pump_frames(2)
	return {"failures": failures, "saved_paths": saved_paths}


func layout_contract_failures(expected_size: Vector2i) -> Array[String]:
	var failures: Array[String] = []
	if absf(size.x - expected_size.x) > 1.0 or absf(size.y - expected_size.y) > 1.0:
		failures.append("root size %.0fx%.0f did not match" % [size.x, size.y])
	if _catalog_count != 6:
		failures.append("weather catalog count was %d" % _catalog_count)
	if _mode_surfaces.size() != 3:
		failures.append("motion mode panel count was %d" % _mode_surfaces.size())
	var bounds := Rect2(Vector2.ZERO, Vector2(expected_size))
	for node: Node in find_children("*", "Control", true, false):
		var control := node as Control
		if not bool(control.get_meta("weather_layout_contract", false)):
			continue
		var rect := Rect2(control.global_position, control.size)
		if rect.size.x < 1.0 or rect.size.y < 1.0:
			failures.append("%s collapsed" % control.name)
		elif not bounds.grow(1.0).encloses(rect):
			failures.append("%s escaped viewport: %s" % [control.name, rect])
	return failures


func telemetry_snapshot() -> Dictionary:
	return _telemetry.snapshot()


static func definitions_fixture() -> Array:
	return [
		{"definition_id": "ion_storm", "display_name": "离子风暴", "icon_key": "ion_bolt", "accent_hex": "#63D7FF", "pattern_key": "diagonal"},
		{"definition_id": "gravity_tide", "display_name": "引力潮", "icon_key": "gravity_wave", "accent_hex": "#D6A8FF", "pattern_key": "concentric"},
		{"definition_id": "spore_season", "display_name": "孢子季", "icon_key": "spore", "accent_hex": "#8ED081", "pattern_key": "dots"},
		{"definition_id": "crystal_dust_storm", "display_name": "晶尘暴", "icon_key": "crystal", "accent_hex": "#F2C56B", "pattern_key": "facets"},
		{"definition_id": "deep_freeze", "display_name": "极寒期", "icon_key": "snowflake", "accent_hex": "#88B8FF", "pattern_key": "crosshatch"},
		{"definition_id": "solar_flare", "display_name": "太阳耀斑", "icon_key": "solar", "accent_hex": "#FF8E66", "pattern_key": "rays"},
	]


static func fixture_source(fixture_id: String) -> Dictionary:
	var events: Array = []
	match fixture_id:
		"full":
			events = [
				_event_fixture(101, "ion_storm", [_region(0, "晨星区"), _region(1, "环港区"), _region(2, "远脊区")], "active", 185_000_000, 1.0, "natural"),
				_event_fixture(102, "deep_freeze", [_region(5, "极冠区")], "queued", 420_000_000, 0.0, "monster"),
			]
		"reduced":
			events = [
				_event_fixture(201, "spore_season", [_region(3, "翠环区"), _region(4, "温室区")], "forecast", 310_000_000, 0.0, "card"),
				_event_fixture(202, "gravity_tide", [_region(6, "折跃区")], "forecast", 250_000_000, 0.0, "natural"),
			]
		"off":
			events = [
				_event_fixture(301, "crystal_dust_storm", [_region(7, "晶谷区")], "fading", 74_000_000, 0.42, "monster"),
				_event_fixture(302, "solar_flare", [_region(8, "日冕区")], "fading", 52_000_000, 0.28, "card"),
			]
		"clear":
			events = []
		_:
			return {}
	return {
		"schema_version": "weather_public_snapshot.v1",
		"clock_domain": "world_effective",
		"world_effective_us": 9_876_543_210,
		"source_revision": 42,
		"definitions": definitions_fixture(),
		"events": events,
	}


static func _event_fixture(event_id: int, definition_id: String, regions: Array, phase: String, remaining_us: int, intensity: float, source_type: String) -> Dictionary:
	return {
		"event_id": event_id,
		"definition_id": definition_id,
		"regions": regions,
		"phase": phase,
		"remaining_us": remaining_us,
		"intensity": intensity,
		"source_type": source_type,
		"effects": _effects_for(definition_id),
		"exploitation_hint": _exploitation_hint(definition_id),
		"counterplay_hint": _counterplay_hint(definition_id),
	}


static func _effects_for(definition_id: String) -> Array:
	match definition_id:
		"ion_storm":
			return [_effect("energy_growth", "economy", "能源增长", "提高", "opportunity", ["product.energy"]), _effect("air_route_efficiency", "route", "空中航线", "效率提高", "opportunity", ["route.air"]), _effect("flying_unit_risk", "military", "飞行单位", "风险增加", "risk", ["unit.flying"])]
		"gravity_tide":
			return [_effect("orbital_force", "military", "轨道与击退", "效果增强", "opportunity", ["effect.orbital", "effect.knockback"]), _effect("ocean_mobility", "route", "海洋移动", "效率降低", "risk", ["route.ocean"]), _effect("heavy_land_mobility", "military", "重型陆地单位", "机动受限", "risk", ["unit.land", "unit.mass.heavy"])]
		"spore_season":
			return [_effect("biological_supply", "economy", "生物/医药/食物", "产需提高", "opportunity", ["product.biological", "product.medicine", "product.food"]), _effect("polluted_route", "route", "污染航线", "效率降低", "risk", ["route.polluted"]), _effect("biological_attraction", "monster", "生物吸引", "强度提高", "risk", ["monster.biological"])]
		"crystal_dust_storm":
			return [_effect("crystal_output", "economy", "水晶产出", "提高", "opportunity", ["product.crystal"]), _effect("light_region_damage", "region", "轻度区域伤害", "封顶生效", "risk", ["region.damage.light"]), _effect("ranged_crystal_armor", "military", "远程/水晶护甲", "攻防偏移", "mixed", ["unit.ranged", "unit.armor.crystal"])]
		"deep_freeze":
			return [_effect("food_energy_demand", "economy", "食物与能源", "需求上升", "opportunity", ["product.food", "product.energy"]), _effect("land_mobility", "route", "陆地移动", "效率降低", "risk", ["route.land"]), _effect("cold_pressure", "monster", "城市维护/寒冷怪物", "压力增加", "risk", ["city.maintenance", "monster.cold"])]
		_:
			return [_effect("sunlit_energy_growth", "economy", "日照来源能源", "增长提高", "opportunity", ["source.sunlit", "product.energy"]), _effect("electronics_output", "economy", "电子产品", "生产受扰", "risk", ["product.electronics"]), _effect("intel_reach", "intel", "情报时长/范围", "降低", "risk", ["intel.duration", "intel.range"])]


static func _effect(effect_id: String, scope: String, label: String, value_text: String, polarity: String, tags: Array) -> Dictionary:
	return {"effect_id": effect_id, "scope": scope, "label": label, "value_text": value_text, "polarity": polarity, "classification_tags": tags}


static func _region(region_index: int, label: String) -> Dictionary:
	return {"region_index": region_index, "label": label}


static func _exploitation_hint(definition_id: String) -> String:
	match definition_id:
		"ion_storm": return "把能源增长与空中航线排在前段"
		"gravity_tide": return "利用轨道与击退效果窗口"
		"spore_season": return "集中安排生物科技生产"
		"crystal_dust_storm": return "提高水晶生产优先级"
		"deep_freeze": return "准备食物与能源库存"
		_:
			return "优先利用日照来源"


static func _counterplay_hint(definition_id: String) -> String:
	match definition_id:
		"ion_storm": return "减少暴露航线与传感依赖"
		"gravity_tide": return "延后重型单位跨区移动"
		"spore_season": return "为运输安排密封防护"
		"crystal_dust_storm": return "降低光学侦察依赖"
		"deep_freeze": return "减少地表长距离运输"
		_:
			return "为护盾单位预留承载余量"


func _build_surface() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_mode_surfaces.clear()
	_catalog_count = 0

	var background := ColorRect.new()
	background.name = "Backdrop"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("0A1016")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.name = "BenchMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.set_meta("weather_layout_contract", true)
	add_child(margin)

	var content := VBoxContainer.new()
	content.name = "BenchContent"
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	_build_header(content)
	_build_status_rail(content)
	_build_catalog(content)
	_build_modes(content)


func _build_header(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 38
	parent.add_child(row)
	var title := Label.new()
	title.text = "Weather v1 Presentation Bench"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("F3F7F9"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	_jump_status = Label.new()
	_jump_status.text = "world_effective_us 9876543210"
	_jump_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_jump_status.add_theme_font_size_override("font_size", 12)
	_jump_status.add_theme_color_override("font_color", Color("9FB3BD"))
	row.add_child(_jump_status)


func _build_status_rail(parent: VBoxContainer) -> void:
	var clear_view := _forecast_vm.compose(fixture_source("clear"))
	var rail := HBoxContainer.new()
	rail.name = "StateRail"
	rail.custom_minimum_size.y = 34
	rail.add_theme_constant_override("separation", 8)
	parent.add_child(rail)
	_add_status_chip(rail, "CLEAR", clear_view["summary"]["headline"], Color("65B99A"))
	_add_status_chip(rail, "QUEUED", "极寒期 · 极冠区 · 07:00", Color("88B8FF"))
	_add_status_chip(rail, "SOURCES", "natural / monster / card", Color("D6A8FF"))


func _build_catalog(parent: VBoxContainer) -> void:
	var catalog := GridContainer.new()
	catalog.name = "WeatherCatalog"
	catalog.columns = 6
	catalog.custom_minimum_size.y = 66
	catalog.add_theme_constant_override("h_separation", 7)
	parent.add_child(catalog)
	for raw_definition: Variant in definitions_fixture():
		var definition := raw_definition as Dictionary
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", _panel_style(Color.from_string(str(definition["accent_hex"]), Color.WHITE), 0.1, 4))
		catalog.add_child(panel)
		var label := Label.new()
		label.text = "%s  %s\n%s" % [_icon_text(definition["icon_key"]), definition["display_name"], definition["pattern_key"]]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color("E7EEF2"))
		panel.add_child(label)
		_catalog_count += 1


func _build_modes(parent: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.name = "MotionModes"
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	parent.add_child(grid)
	_build_mode_surface(grid, "full", "FULL MOTION", "active + queued")
	_build_mode_surface(grid, "reduced", "REDUCED MOTION", "forecast")
	_build_mode_surface(grid, "off", "MOTION OFF", "fading")


func _build_mode_surface(parent: GridContainer, fixture_id: String, title_text: String, phase_text: String) -> void:
	var surface := VBoxContainer.new()
	surface.name = "Mode_%s" % fixture_id.capitalize()
	surface.custom_minimum_size.x = 360
	surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	surface.add_theme_constant_override("separation", 6)
	surface.set_meta("weather_layout_contract", true)
	parent.add_child(surface)
	_mode_surfaces.append(surface)

	var heading := HBoxContainer.new()
	heading.custom_minimum_size.y = 24
	surface.add_child(heading)
	var title := Label.new()
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color("F3F7F9"))
	heading.add_child(title)
	var phase := Label.new()
	phase.text = phase_text
	phase.add_theme_font_size_override("font_size", 11)
	phase.add_theme_color_override("font_color", Color("9FB3BD"))
	heading.add_child(phase)

	var source := fixture_source(fixture_id)
	var forecast := _forecast_vm.compose(source)
	var overlay_model := _overlay_vm.compose(forecast)
	var overlay_frame := PanelContainer.new()
	overlay_frame.name = "OverlayFrame_%s" % fixture_id
	overlay_frame.custom_minimum_size.y = 205
	overlay_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_frame.add_theme_stylebox_override("panel", _panel_style(Color("48606A"), 0.08, 4))
	overlay_frame.set_meta("weather_layout_contract", true)
	surface.add_child(overlay_frame)
	var overlay := MAP_OVERLAY_SCENE.instantiate() as Control
	overlay.name = "Overlay_%s" % fixture_id
	overlay_frame.add_child(overlay)
	overlay.call("set_overlay_view_model", overlay_model)
	overlay.call("set_region_layout", _layout_for_fixture(fixture_id))
	overlay.call("set_motion_mode", fixture_id)

	var strip := FORECAST_STRIP_SCENE.instantiate() as Control
	strip.name = "ForecastStrip_%s" % fixture_id
	strip.set_meta("weather_layout_contract", true)
	surface.add_child(strip)
	strip.call("set_view_model", forecast)
	strip.call("set_motion_mode", fixture_id)
	strip.connect("region_jump_requested", _on_region_jump_requested.bind(fixture_id))

	var primary_event := (forecast["events"] as Array)[0] as Dictionary
	_record_telemetry("overlay_rendered", "map_overlay", primary_event, fixture_id)
	_record_telemetry("forecast_rendered", "forecast_strip", primary_event, fixture_id)


func _add_status_chip(parent: HBoxContainer, key_text: String, value_text: String, accent: Color) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(accent, 0.08, 4))
	parent.add_child(panel)
	var label := Label.new()
	label.text = "%s  %s" % [key_text, value_text]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("DDE8EC"))
	panel.add_child(label)


func _layout_for_fixture(fixture_id: String) -> Dictionary:
	match fixture_id:
		"full":
			return {0: Vector2(0.18, 0.28), 1: Vector2(0.39, 0.62), 2: Vector2(0.61, 0.27), 5: Vector2(0.82, 0.6)}
		"reduced":
			return {3: Vector2(0.24, 0.3), 4: Vector2(0.5, 0.64), 6: Vector2(0.76, 0.3)}
		_:
			return {7: Vector2(0.3, 0.4), 8: Vector2(0.7, 0.4)}


func _on_region_jump_requested(region_index: int, fixture_id: String) -> void:
	_jump_status.text = "jump request · region %d · %s" % [region_index, fixture_id]
	var forecast := _forecast_vm.compose(fixture_source(fixture_id))
	var event := (forecast["events"] as Array)[0] as Dictionary
	_record_telemetry("region_jump_requested", "forecast_strip", event, fixture_id, region_index, "keyboard", "accepted")


func _record_telemetry(event_type: String, surface: String, event: Dictionary, motion_mode: String, region_index: int = -1, input_kind: String = "none", result: String = "shown") -> void:
	_telemetry.record_event({
		"schema_version": "weather_telemetry_event.v1",
		"event_type": event_type,
		"world_effective_us": 9_876_543_210,
		"surface": surface,
		"definition_id": event["definition_id"],
		"phase": event["phase"],
		"region_index": region_index,
		"source_revision": 42,
		"motion_mode": motion_mode,
		"input_kind": input_kind,
		"result": result,
	})


func _panel_style(accent: Color, alpha: float, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent, alpha)
	style.border_color = Color(accent, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 6.0
	style.content_margin_top = 5.0
	style.content_margin_right = 6.0
	style.content_margin_bottom = 5.0
	return style


func _pump_frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw


func _has_visible_pixels(image: Image) -> bool:
	if image.is_empty():
		return false
	var samples := 0
	var varied := 0
	var first := image.get_pixel(0, 0)
	var step_x := maxi(1, int(image.get_width() / 32))
	var step_y := maxi(1, int(image.get_height() / 20))
	for x: int in range(0, image.get_width(), step_x):
		for y: int in range(0, image.get_height(), step_y):
			samples += 1
			var pixel := image.get_pixel(x, y)
			if absf(pixel.r - first.r) + absf(pixel.g - first.g) + absf(pixel.b - first.b) + absf(pixel.a - first.a) > 0.04:
				varied += 1
	return samples > 0 and varied > samples / 30


static func _icon_text(icon_key: String) -> String:
	match icon_key:
		"ion_bolt": return "ION"
		"gravity_wave": return "G"
		"spore": return "SPORE"
		"crystal": return "CRY"
		"snowflake": return "ICE"
		"solar": return "SOL"
	return "WX"
