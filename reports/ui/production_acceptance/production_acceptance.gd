extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const REPORT_DIR := "res://reports/ui/production_acceptance"
const CAPTURE_SIZE := Vector2i(1280, 720)
const CAPTURE_FILES := {
	"first_run_core_table": "01_first_run_core_table_1280x720.png",
	"weather_forecast": "02_weather_forecast_1280x720.png",
	"weather_active": "03_weather_active_1280x720.png",
	"weather_dual": "04_weather_dual_1280x720.png",
	"economy_scrolled": "05_economy_scrolled_1280x720.png",
	"economy_reopened": "06_economy_reopened_1280x720.png",
	"table_modules": "07_card_track_inspector_player_board_1280x720.png",
}

var _failures: Array[String] = []
var _captures: Dictionary = {}
var _capture_images: Dictionary = {}
var _weather_states: Dictionary = {}
var _economy_scroll: Dictionary = {}
var _module_gate: Dictionary = {}
var _qa_override: Dictionary = {}
var _save_before: Dictionary = {}
var _save_after: Dictionary = {}
var _runtime_environment: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_prepare_report_dir()
	_configure_capture_window()
	_runtime_environment = _runtime_environment_snapshot()
	var default_save_path := OS.get_environment("SPACE_SYNDICATE_DEFAULT_SAVE_PATH")
	_save_before = _file_fingerprint(default_save_path)

	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("main_scene_load", "res://scenes/main.tscn did not load as PackedScene")
		await _finish(null)
		return

	var main := packed.instantiate()
	if main == null:
		_fail("main_scene_instantiate", "res://scenes/main.tscn did not instantiate")
		await _finish(null)
		return

	_install_qa_save_override(main)
	get_root().add_child(main)
	get_root().size = CAPTURE_SIZE
	await _pump_frames(14)
	_verify_main_entered_tree(main)

	main.set("configured_player_count", 4)
	main.set("configured_ai_player_count", 3)
	main.set("configured_role_indices", [0, 1, 2, 3])
	main.set("configured_starter_monster_indices", [0, 1, 2, 3])
	main.call("_new_game")
	main.call("_close_menu")
	await _pump_frames(18)
	main.set("time_scale", 0.0)
	main.call("_refresh_ui")
	await _pump_frames(8)

	_record_core_table_state(main)
	await _capture("first_run_core_table")
	await _capture_weather_states(main)
	await _capture_economy_reopen(main)
	await _capture_live_table_modules(main)
	_write_scene_tree(main)
	await _finish(main)


func _prepare_report_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_DIR))


func _configure_capture_window() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(CAPTURE_SIZE)
	var screen_count := DisplayServer.get_screen_count()
	var screen_index := 1 if screen_count > 1 else 0
	DisplayServer.window_set_current_screen(screen_index)
	var screen_origin := DisplayServer.screen_get_position(screen_index)
	DisplayServer.window_set_position(screen_origin + Vector2i(20, 20))
	get_root().size = CAPTURE_SIZE


func _runtime_environment_snapshot() -> Dictionary:
	var version := Engine.get_version_info()
	var adapter_name := ""
	var adapter_vendor := ""
	var rendering_driver := ""
	if RenderingServer.has_method("get_video_adapter_name"):
		adapter_name = String(RenderingServer.call("get_video_adapter_name"))
	if RenderingServer.has_method("get_video_adapter_vendor"):
		adapter_vendor = String(RenderingServer.call("get_video_adapter_vendor"))
	if RenderingServer.has_method("get_current_rendering_driver_name"):
		rendering_driver = String(RenderingServer.call("get_current_rendering_driver_name"))
	return {
		"engine": String(version.get("string", "unknown")),
		"engine_major": int(version.get("major", 0)),
		"engine_minor": int(version.get("minor", 0)),
		"display_server": DisplayServer.get_name(),
		"rendering_driver": rendering_driver,
		"video_adapter": adapter_name,
		"video_vendor": adapter_vendor,
		"viewport": [CAPTURE_SIZE.x, CAPTURE_SIZE.y],
		"screen_count": DisplayServer.get_screen_count(),
		"source_revision": OS.get_environment("SPACE_SYNDICATE_SOURCE_REVISION"),
		"main_scene": MAIN_SCENE_PATH,
		"isolated_user_data": ProjectSettings.globalize_path("user://"),
		"command_line": OS.get_cmdline_args(),
	}


func _install_qa_save_override(main: Node) -> void:
	var qa_save_path := OS.get_environment("SPACE_SYNDICATE_QA_SAVE_PATH")
	var before_enter_tree := not main.is_inside_tree()
	var property_available := _node_has_property(main, "run_save_path")
	if property_available:
		main.set("run_save_path", qa_save_path)
	var installed_value := String(main.get("run_save_path")) if property_available else ""
	var installed := before_enter_tree and property_available and qa_save_path != "" and installed_value == qa_save_path
	_qa_override = {
		"installed": installed,
		"installed_before_main_entered_tree": before_enter_tree,
		"property_available": property_available,
		"qa_save_path": qa_save_path,
		"installed_value": installed_value,
		"main_inside_tree_at_install": main.is_inside_tree(),
		"isolated_user_data": ProjectSettings.globalize_path("user://"),
	}
	if not installed:
		_fail("qa_save_override", "independent run_save_path was not installed before Main entered the tree")


func _verify_main_entered_tree(main: Node) -> void:
	_qa_override["main_entered_tree_after_install"] = main.is_inside_tree()
	_qa_override["value_after_ready"] = String(main.get("run_save_path")) if _node_has_property(main, "run_save_path") else ""
	if not main.is_inside_tree():
		_fail("main_tree", "Main did not enter the SceneTree")
	if String(_qa_override.get("value_after_ready", "")) != String(_qa_override.get("qa_save_path", "")):
		_fail("qa_save_override_ready", "Main changed the QA run_save_path during _ready")


func _record_core_table_state(main: Node) -> void:
	var players: Array = main.get("players") if main.get("players") is Array else []
	var districts: Array = main.get("districts") if main.get("districts") is Array else []
	var core := {
		"players": players.size(),
		"districts": districts.size(),
		"selected_player": int(main.get("selected_player")),
		"selected_district": int(main.get("selected_district")),
		"menu_closed": not _named_control_visible(main, "MenuOverlay"),
		"runtime_game_screen_visible": _named_control_visible(main, "RuntimeGameScreen"),
		"first_run_coach_visible": _named_control_visible(main, "FirstRunCoach"),
		"forecast_present": not (main.get("weather_forecast") as Dictionary).is_empty(),
		"active_weather_count": (main.get("active_weather_zones") as Array).size(),
	}
	_runtime_environment["core_table"] = core
	if players.size() != 4 or districts.is_empty():
		_fail("core_table_state", "new game did not create four players and a production district set")
	if not bool(core.get("menu_closed", false)) or not bool(core.get("runtime_game_screen_visible", false)):
		_fail("core_table_visibility", "core table was not fully visible after closing the menu")


func _capture_weather_states(main: Node) -> void:
	main.call("_refresh_ui")
	await _pump_frames(6)
	_weather_states["forecast"] = _weather_state_snapshot(main, "production _new_game forecast")
	_assert_weather_state("forecast", _weather_states["forecast"] as Dictionary, true, false)
	await _capture("weather_forecast")

	var current_forecast: Dictionary = (main.get("weather_forecast") as Dictionary).duplicate(true)
	if current_forecast.is_empty():
		_fail("weather_transition", "new game did not expose a forecast to activate")
		return
	main.set("game_time", float(current_forecast.get("starts_at", main.get("game_time"))) + 0.01)
	main.call("_update_weather_system", 0.0)
	var generated_next_forecast: Dictionary = (main.get("weather_forecast") as Dictionary).duplicate(true)
	var active_zones: Array = main.get("active_weather_zones") as Array
	if active_zones.is_empty():
		_fail("weather_transition", "production weather transition did not create an active zone")

	# Hold the production-generated next forecast for one capture so the active-only label is reviewable.
	main.set("weather_forecast", {})
	main.call("_refresh_ui")
	await _pump_frames(6)
	_weather_states["active"] = _weather_state_snapshot(main, "production activation; next forecast held for one QA frame")
	_assert_weather_state("active", _weather_states["active"] as Dictionary, false, true)
	await _capture("weather_active")

	main.set("weather_forecast", generated_next_forecast)
	main.call("_refresh_ui")
	await _pump_frames(6)
	_weather_states["dual"] = _weather_state_snapshot(main, "same active zone plus production-generated next forecast")
	_assert_weather_state("dual", _weather_states["dual"] as Dictionary, true, true)
	await _capture("weather_dual")
	_add_weather_pixel_differences(main)


func _weather_state_snapshot(main: Node, staging: String) -> Dictionary:
	var forecast: Dictionary = (main.get("weather_forecast") as Dictionary).duplicate(true)
	var active: Array = (main.get("active_weather_zones") as Array).duplicate(true)
	return {
		"staging": staging,
		"forecast_present": not forecast.is_empty(),
		"active_count": active.size(),
		"forecast_id": int(forecast.get("id", -1)),
		"forecast_type": String(forecast.get("type", "")),
		"active_types": active.map(func(entry: Variant) -> String: return String((entry as Dictionary).get("type", ""))),
		"active_label": _label_text(main, "WeatherActiveLabel"),
		"forecast_label": _label_text(main, "WeatherForecastLabel"),
		"impact_label": _label_text(main, "WeatherImpactLabel"),
	}


func _assert_weather_state(name: String, state: Dictionary, expect_forecast: bool, expect_active: bool) -> void:
	var forecast_ok := bool(state.get("forecast_present", false)) == expect_forecast
	var active_ok := (int(state.get("active_count", 0)) > 0) == expect_active
	var active_label := String(state.get("active_label", ""))
	var forecast_label := String(state.get("forecast_label", ""))
	var impact_label := String(state.get("impact_label", ""))
	var labels_ok := active_label.begins_with("现在：") and forecast_label.begins_with("预报：") and impact_label.begins_with("影响：")
	state["pass"] = forecast_ok and active_ok and labels_ok
	if not bool(state.get("pass", false)):
		_fail("weather_%s" % name, "weather state did not match forecast=%s active=%s labels=%s" % [expect_forecast, expect_active, labels_ok])


func _add_weather_pixel_differences(main: Node) -> void:
	var panel := main.get("weather_forecast_panel") as Control
	if panel == null:
		panel = main.find_child("WeatherForecastBar", true, false) as Control
	if panel == null:
		_fail("weather_pixel_crop", "production WeatherForecastBar was unavailable")
		return
	var pixel_rect := _control_pixel_rect(panel)
	var forecast_image := _capture_images.get("weather_forecast", null) as Image
	var active_image := _capture_images.get("weather_active", null) as Image
	var dual_image := _capture_images.get("weather_dual", null) as Image
	var forecast_active_diff := _image_difference(forecast_image, active_image, pixel_rect)
	var active_dual_diff := _image_difference(active_image, dual_image, pixel_rect)
	var pixel_difference_pass := forecast_active_diff >= 0.001 and active_dual_diff >= 0.0005
	_runtime_environment["weather_pixel_difference"] = {
		"logical_rect": _rect_to_dictionary(panel.get_global_rect()),
		"pixel_rect": _rect_to_dictionary(pixel_rect),
		"forecast_to_active_mean_rgb_delta": forecast_active_diff,
		"active_to_dual_mean_rgb_delta": active_dual_diff,
		"pass": pixel_difference_pass,
	}
	if not pixel_difference_pass:
		_fail("weather_pixel_difference", "weather states did not produce distinct pixels in the production weather panel")


func _capture_economy_reopen(main: Node) -> void:
	main.call("_open_economy_overview_menu")
	await _pump_frames(12)
	var scroll := main.get("menu_content_scroll") as ScrollContainer
	if scroll == null:
		_fail("economy_scroll", "MenuContentScroll was unavailable")
		return
	var bar := scroll.get_v_scroll_bar()
	var max_scroll := maxi(0, int(floor(bar.max_value - bar.page))) if bar != null else 0
	var target := maxi(1, int(round(float(max_scroll) * 0.62)))
	scroll.scroll_vertical = target
	await _pump_frames(6)
	var before_close := int(scroll.scroll_vertical)
	await _capture("economy_scrolled")

	main.call("_close_menu")
	await _pump_frames(5)
	main.call("_open_economy_overview_menu")
	await _pump_frames(12)
	var reopened_scroll := int(scroll.scroll_vertical)
	await _capture("economy_reopened")

	var expected_reset_to_top := max_scroll > 0 and before_close > 0 and reopened_scroll <= 2
	_economy_scroll = {
		"contract": "reopening economy overview starts at the top",
		"max_scroll": max_scroll,
		"requested_before_close": target,
		"actual_before_close": before_close,
		"actual_after_reopen": reopened_scroll,
		"menu_title_after_reopen": _label_text(main, "MenuTitleLabel"),
		"pass": expected_reset_to_top,
	}
	if not expected_reset_to_top:
		_fail("economy_reopen_scroll", "economy overview did not scroll before close and reset to top after reopen")
	var before_image := _capture_images.get("economy_scrolled", null) as Image
	var reopened_image := _capture_images.get("economy_reopened", null) as Image
	_economy_scroll["full_frame_mean_rgb_delta"] = _image_difference(before_image, reopened_image, Rect2(Vector2.ZERO, Vector2(CAPTURE_SIZE)))
	main.call("_close_menu")
	await _pump_frames(6)


func _capture_live_table_modules(main: Node) -> void:
	main.set("selected_player", 0)
	var players: Array = (main.get("players") as Array).duplicate(true)
	if players.is_empty():
		_fail("live_card_track", "no player was available for a real starter-card play")
		return
	var player: Dictionary = (players[0] as Dictionary).duplicate(true)
	player["action_cooldown"] = 0.0
	players[0] = player
	main.set("players", players)
	main.set("time_scale", 1.0)
	main.call("_use_skill", 0)
	main.set("time_scale", 0.0)
	main.call("_dismiss_opening_guide")
	main.call("_sync_runtime_game_screen", true)
	await _pump_frames(8)

	var entries: Array = main.call("_runtime_card_track_snapshot_source") as Array
	var real_entry: Dictionary = {}
	for entry_variant in entries:
		if entry_variant is Dictionary and int((entry_variant as Dictionary).get("resolution_id", -1)) >= 0:
			real_entry = entry_variant as Dictionary
			break
	if real_entry.is_empty():
		_fail("live_card_track", "production _use_skill(0) did not place the real starter card on the card track")
	else:
		main.call("_focus_card_resolution_track_entry", int(real_entry.get("resolution_id", -1)))
		main.call("_sync_runtime_game_screen", true)
		await _pump_frames(8)

	await _capture("table_modules")
	_module_gate = {
		"source": "production _new_game -> _use_skill(0) -> _focus_card_resolution_track_entry",
		"card_track_entries": entries.size(),
		"selected_resolution_id": int(main.get("selected_card_resolution_id")),
		"queued_cards": (main.get("card_resolution_queue") as Array).size(),
		"active_card_present": not (main.get("active_card_resolution") as Dictionary).is_empty(),
		"auto_monsters": (main.get("auto_monsters") as Array).size(),
		"fabricated_city_monster_route_state": false,
		"nodes": {},
	}
	var image := _capture_images.get("table_modules", null) as Image
	for node_name in ["PublicTrack", "RightInspector", "PlayerBoard"]:
		var node := main.find_child(node_name, true, false) as Control
		var result := _control_frame_gate(node, image)
		(_module_gate["nodes"] as Dictionary)[node_name] = result
		if not bool(result.get("pass", false)):
			_fail("module_%s" % node_name, "%s was not a complete, visible, nonblank frame at 1280x720" % node_name)
	_module_gate["pass"] = _dictionary_children_pass(_module_gate["nodes"] as Dictionary)


func _capture(key: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("capture_%s" % key, "viewport image was empty; headed renderer required")
		return
	var file_name := String(CAPTURE_FILES.get(key, "%s.png" % key))
	var absolute_path := ProjectSettings.globalize_path("%s/%s" % [REPORT_DIR, file_name])
	var error := image.save_png(absolute_path)
	if error != OK:
		_fail("capture_%s" % key, "save_png failed with code %d" % error)
		return
	var metrics := _image_metrics(image, Rect2(Vector2.ZERO, Vector2(image.get_size())), 4)
	var gate_pass := image.get_width() == CAPTURE_SIZE.x \
		and image.get_height() == CAPTURE_SIZE.y \
		and float(metrics.get("luminance_stddev", 0.0)) >= 0.08 \
		and int(metrics.get("color_buckets", 0)) >= 64 \
		and float(metrics.get("opaque_ratio", 0.0)) >= 0.99 \
		and float(metrics.get("near_black_ratio", 1.0)) <= 0.08
	_captures[key] = {
		"file": file_name,
		"absolute_path": absolute_path,
		"sha256": FileAccess.get_sha256(absolute_path),
		"metrics": metrics,
		"pass": gate_pass,
	}
	_capture_images[key] = image
	if not gate_pass:
		_fail("pixel_%s" % key, "full-frame pixel gate failed for %s" % file_name)


func _control_frame_gate(control: Control, image: Image) -> Dictionary:
	if control == null:
		return {"pass": false, "reason": "node_missing"}
	var logical_rect := control.get_global_rect()
	var pixel_rect := _control_pixel_rect(control)
	var inside := pixel_rect.position.x >= -0.5 \
		and pixel_rect.position.y >= -0.5 \
		and pixel_rect.end.x <= float(CAPTURE_SIZE.x) + 0.5 \
		and pixel_rect.end.y <= float(CAPTURE_SIZE.y) + 0.5
	var metrics := _image_metrics(image, pixel_rect, 2)
	var nonblank := float(metrics.get("luminance_stddev", 0.0)) >= 0.025 and int(metrics.get("color_buckets", 0)) >= 12
	return {
		"path": String(control.get_path()),
		"visible": control.visible,
		"visible_in_tree": control.is_visible_in_tree(),
		"logical_rect": _rect_to_dictionary(logical_rect),
		"pixel_rect": _rect_to_dictionary(pixel_rect),
		"inside_viewport": inside,
		"pixel_metrics": metrics,
		"pass": control.is_visible_in_tree() and inside and pixel_rect.size.x >= 40.0 and pixel_rect.size.y >= 20.0 and nonblank,
	}


func _control_pixel_rect(control: Control) -> Rect2:
	var logical_rect := control.get_global_rect()
	var final_transform := control.get_viewport().get_final_transform()
	var points := [
		final_transform * logical_rect.position,
		final_transform * Vector2(logical_rect.end.x, logical_rect.position.y),
		final_transform * logical_rect.end,
		final_transform * Vector2(logical_rect.position.x, logical_rect.end.y),
	]
	var minimum: Vector2 = points[0]
	var maximum: Vector2 = points[0]
	for point_variant in points:
		var point: Vector2 = point_variant
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


func _image_metrics(image: Image, requested_rect: Rect2, sample_step: int) -> Dictionary:
	if image == null or image.is_empty():
		return {"samples": 0, "luminance_stddev": 0.0, "color_buckets": 0, "opaque_ratio": 0.0}
	var bounds := Rect2i(Vector2i.ZERO, image.get_size())
	var requested := Rect2i(
		Vector2i(int(floor(requested_rect.position.x)), int(floor(requested_rect.position.y))),
		Vector2i(maxi(0, int(ceil(requested_rect.size.x))), maxi(0, int(ceil(requested_rect.size.y))))
	)
	var rect := requested.intersection(bounds)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return {"samples": 0, "luminance_stddev": 0.0, "color_buckets": 0, "opaque_ratio": 0.0}
	var count := 0
	var luminance_sum := 0.0
	var luminance_square_sum := 0.0
	var opaque := 0
	var near_black := 0
	var buckets := {}
	var step := maxi(1, sample_step)
	for y in range(rect.position.y, rect.end.y, step):
		for x in range(rect.position.x, rect.end.x, step):
			var color := image.get_pixel(x, y)
			var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			luminance_sum += luminance
			luminance_square_sum += luminance * luminance
			if color.a >= 0.99:
				opaque += 1
			if maxf(color.r, maxf(color.g, color.b)) <= 0.004:
				near_black += 1
			var bucket := (int(color.r * 15.0) << 8) | (int(color.g * 15.0) << 4) | int(color.b * 15.0)
			buckets[bucket] = true
			count += 1
	var mean := luminance_sum / float(maxi(1, count))
	var variance := maxf(0.0, luminance_square_sum / float(maxi(1, count)) - mean * mean)
	return {
		"rect": _rect_to_dictionary(Rect2(rect)),
		"sample_step": step,
		"samples": count,
		"luminance_mean": mean,
		"luminance_stddev": sqrt(variance),
		"color_buckets": buckets.size(),
		"opaque_ratio": float(opaque) / float(maxi(1, count)),
		"near_black_ratio": float(near_black) / float(maxi(1, count)),
	}


func _image_difference(first: Image, second: Image, requested_rect: Rect2) -> float:
	if first == null or second == null or first.is_empty() or second.is_empty() or first.get_size() != second.get_size():
		return 0.0
	var bounds := Rect2i(Vector2i.ZERO, first.get_size())
	var requested := Rect2i(
		Vector2i(int(floor(requested_rect.position.x)), int(floor(requested_rect.position.y))),
		Vector2i(maxi(0, int(ceil(requested_rect.size.x))), maxi(0, int(ceil(requested_rect.size.y))))
	)
	var rect := requested.intersection(bounds)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return 0.0
	var total := 0.0
	var count := 0
	for y in range(rect.position.y, rect.end.y, 2):
		for x in range(rect.position.x, rect.end.x, 2):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			total += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
			count += 1
	return total / float(maxi(1, count))


func _write_scene_tree(main: Node) -> void:
	var nodes: Array = []
	_append_scene_nodes(main, nodes)
	var payload := {
		"main_scene": MAIN_SCENE_PATH,
		"capture": String(CAPTURE_FILES.get("table_modules", "")),
		"viewport": [CAPTURE_SIZE.x, CAPTURE_SIZE.y],
		"node_count": nodes.size(),
		"nodes": nodes,
	}
	_write_json("scene_tree.json", payload)


func _append_scene_nodes(node: Node, result: Array) -> void:
	var entry := {
		"path": String(node.get_path()),
		"name": String(node.name),
		"class": node.get_class(),
		"inside_tree": node.is_inside_tree(),
	}
	var script: Variant = node.get_script()
	if script is Script:
		entry["script"] = String((script as Script).resource_path)
	if node is CanvasItem:
		entry["visible"] = (node as CanvasItem).visible
		entry["visible_in_tree"] = (node as CanvasItem).is_visible_in_tree()
	if node is Control:
		var control := node as Control
		entry["logical_rect"] = _rect_to_dictionary(control.get_global_rect())
		entry["pixel_rect"] = _rect_to_dictionary(_control_pixel_rect(control))
		entry["clip_contents"] = control.clip_contents
		entry["mouse_filter"] = int(control.mouse_filter)
	if node is Label:
		entry["text"] = _limited_text((node as Label).text, 180)
	elif node is Button:
		entry["text"] = _limited_text((node as Button).text, 180)
		entry["disabled"] = (node as Button).disabled
	result.append(entry)
	for child in node.get_children():
		_append_scene_nodes(child, result)


func _finish(main: Node) -> void:
	var main_freed := true
	if main != null and is_instance_valid(main):
		if main.get_parent() != null:
			main.get_parent().remove_child(main)
		main.queue_free()
		await _pump_frames(8)
		main_freed = not is_instance_valid(main)
	if not main_freed:
		_fail("clean_stop", "Main remained alive after queue_free and eight process frames")

	_save_after = _file_fingerprint(OS.get_environment("SPACE_SYNDICATE_DEFAULT_SAVE_PATH"))
	var save_unchanged := _save_before == _save_after
	if not save_unchanged:
		_fail("default_save_integrity", "default save metadata or SHA256 changed during isolated QA run")
	var save_integrity := {
		"path": OS.get_environment("SPACE_SYNDICATE_DEFAULT_SAVE_PATH"),
		"before": _save_before,
		"after": _save_after,
		"metadata_and_sha256_unchanged": save_unchanged,
		"pass": save_unchanged,
	}
	_write_json("save_integrity.json", save_integrity)

	_runtime_environment["clean_stop"] = {
		"main_queue_freed": main_freed,
		"scene_tree_root_child_count": get_root().get_child_count(),
		"ready_to_quit": true,
	}
	_write_json("runtime_environment.json", _runtime_environment)
	_write_json("pixel_gate.json", {
		"capture_size": [CAPTURE_SIZE.x, CAPTURE_SIZE.y],
		"captures": _captures,
		"weather_difference": _runtime_environment.get("weather_pixel_difference", {}),
		"module_gate": _module_gate,
		"pass": _captures_all_pass() and bool(_module_gate.get("pass", false)) and bool((_runtime_environment.get("weather_pixel_difference", {}) as Dictionary).get("pass", false)),
	})
	_write_json("acceptance_results.json", {
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"main_scene": MAIN_SCENE_PATH,
		"capture_size": [CAPTURE_SIZE.x, CAPTURE_SIZE.y],
		"runtime_environment": _runtime_environment,
		"qa_save_override": _qa_override,
		"save_integrity": save_integrity,
		"core_table": _runtime_environment.get("core_table", {}),
		"weather_states": _weather_states,
		"economy_scroll": _economy_scroll,
		"module_gate": _module_gate,
		"captures": _captures,
		"failures": _failures,
	})

	print("PRODUCTION_ACCEPTANCE_STATUS=%s" % ("PASS" if _failures.is_empty() else "FAIL"))
	print("PRODUCTION_ACCEPTANCE_CLEAN_STOP_READY=true")
	print("PRODUCTION_ACCEPTANCE_REPORT_DIR=%s" % ProjectSettings.globalize_path(REPORT_DIR))
	quit(0 if _failures.is_empty() else 1)


func _captures_all_pass() -> bool:
	if _captures.size() != CAPTURE_FILES.size():
		return false
	for value in _captures.values():
		if not bool((value as Dictionary).get("pass", false)):
			return false
	return true


func _dictionary_children_pass(values: Dictionary) -> bool:
	if values.is_empty():
		return false
	for value in values.values():
		if not bool((value as Dictionary).get("pass", false)):
			return false
	return true


func _file_fingerprint(path: String) -> Dictionary:
	var exists := path != "" and FileAccess.file_exists(path)
	var length := 0
	if exists:
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			length = file.get_length()
			file.close()
	return {
		"path": path,
		"exists": exists,
		"length": length,
		"modified_unix": FileAccess.get_modified_time(path) if exists else 0,
		"sha256": FileAccess.get_sha256(path) if exists else "",
	}


func _write_json(file_name: String, payload: Variant) -> void:
	var absolute_path := ProjectSettings.globalize_path("%s/%s" % [REPORT_DIR, file_name])
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		_fail("write_%s" % file_name, "could not open report file for writing")
		return
	file.store_string(JSON.stringify(payload, "  ", false))
	file.store_line("")
	file.close()


func _node_has_property(node: Object, property_name: String) -> bool:
	for property_variant in node.get_property_list():
		var property: Dictionary = property_variant if property_variant is Dictionary else {}
		if String(property.get("name", "")) == property_name:
			return true
	return false


func _named_control_visible(root_node: Node, node_name: String) -> bool:
	var control := root_node.find_child(node_name, true, false) as Control
	return control != null and control.is_visible_in_tree()


func _label_text(root_node: Node, node_name: String) -> String:
	var label := root_node.find_child(node_name, true, false) as Label
	return label.text if label != null else ""


func _rect_to_dictionary(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y,
		"right": rect.end.x,
		"bottom": rect.end.y,
	}


func _limited_text(value: String, limit: int) -> String:
	var flattened := value.replace("\r", " ").replace("\n", " ").strip_edges()
	return flattened if flattened.length() <= limit else "%s..." % flattened.substr(0, limit - 3)


func _pump_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await process_frame


func _fail(code: String, detail: String) -> void:
	var message := "%s: %s" % [code, detail]
	_failures.append(message)
	printerr("PRODUCTION_ACCEPTANCE_FAILURE %s" % message)
