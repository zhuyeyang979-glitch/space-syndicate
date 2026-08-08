extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const CombatSurfaceBench := preload(
	"res://scripts/tools/v075/v075_combat_player_surface_bench.gd"
)
const ProjectionAdapter := preload(
	"res://scripts/v075/player/v075_combat_projection_adapter.gd"
)

const FIXED_SEED := 900626424
const ALLOWED_SIZES := {
	"1366x768": Vector2i(1366, 768),
	"1600x960": Vector2i(1600, 960),
	"1920x1080": Vector2i(1920, 1080),
}
const PRIVATE_IDENTITY_KEYS := {
	"card_action_binding": true,
	"authority_lineage_fingerprint": true,
	"immutable_identity_fingerprint": true,
	"lifecycle_evidence_fingerprint": true,
	"binding_fingerprint": true,
	"source_card_instance_id": true,
	"source_card_definition_id": true,
}

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if _has_argument("--parse-only"):
		print(
			"V075_RESPONSIVE_VIEWPORT_HEADED_CAPTURE|status=PASS|case=parse-only|checks=0|failures=0"
		)
		quit(0)
		return
	var case_label := _argument_value("--case-label")
	if case_label.is_empty():
		case_label = _argument_value("--expected-client-size")
	var requested_size := ALLOWED_SIZES.get(case_label, Vector2i.ZERO) as Vector2i
	var expected_head_sha := _argument_value("--expected-head-sha")
	var expected_tree_sha := _argument_value("--expected-tree-sha")
	var capture_path := _argument_value("--capture-output")
	var receipt_path := _argument_value("--capture-receipt")
	var ready_path := _argument_value("--window-probe-ready")
	var ack_path := _argument_value("--window-probe-ack")
	var probe_nonce := _argument_value("--window-probe-nonce")
	var expected_client_size := _argument_value("--expected-client-size")

	_expect(ALLOWED_SIZES.has(case_label), "capture size is one of the three fixed desktop cases")
	_expect(expected_client_size == case_label, "runner and driver request the same client size")
	_expect(_is_sha1(expected_head_sha), "expected HEAD SHA is explicit")
	_expect(_is_sha1(expected_tree_sha), "expected tree SHA is explicit")
	_expect(not capture_path.is_empty(), "absolute capture output path is supplied")
	_expect(not receipt_path.is_empty(), "absolute capture receipt path is supplied")
	_expect(not ready_path.is_empty(), "runner-owned ready path is supplied")
	_expect(not ack_path.is_empty(), "runner-owned acknowledgement path is supplied")
	_expect(not probe_nonce.is_empty(), "window probe nonce is supplied")
	_expect(DisplayServer.get_name() != "headless", "capture process uses a headed display server")

	var production_content_scale_size := root.content_scale_size
	if requested_size != Vector2i.ZERO and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(requested_size)
	await _settle_frames(8)

	var main := MainScene.instantiate() as Control
	_expect(main != null, "production main scene instantiates")
	if main != null:
		root.add_child(main)
	await _settle_frames(8)

	var composition := main.get_node_or_null("V075RuntimeComposition") if main != null else null
	var screen := main.get_node_or_null("V075GameScreen") as Control if main != null else null
	var surface := (
		screen.find_child("CombatSurface", true, false) as Control
		if screen != null
		else null
	)
	_expect(
		composition != null and screen != null and surface != null,
		"main -> V075 composition -> V075 screen -> real combat surface is intact"
	)

	var seed_input := screen.find_child("SeedInput", true, false) as LineEdit if screen != null else null
	var start_button := (
		screen.find_child("StartConfiguredButton", true, false) as Button
		if screen != null
		else null
	)
	_expect(seed_input != null and start_button != null, "production new-game controls are reachable")
	if seed_input != null and start_button != null:
		seed_input.text = str(FIXED_SEED)
		start_button.pressed.emit()
	await _settle_frames(10)

	var collapse_button := (
		screen.find_child("CollapseButton", true, false) as Button
		if screen != null
		else null
	)
	_expect(collapse_button != null, "real combat collapse button is reachable")
	if collapse_button != null and screen != null:
		var before := screen.call("combat_debug_snapshot") as Dictionary
		if bool(before.get("overlay_collapsed", true)):
			collapse_button.pressed.emit()
	await _settle_frames(6)

	var owner_projection := CombatSurfaceBench.make_projection("player.local")
	var projection_adapter := ProjectionAdapter.new()
	var owner_privacy := projection_adapter.privacy_report(owner_projection)
	var rival_projection := projection_adapter.project_for_viewer(
		CombatSurfaceBench.make_authority_snapshot(),
		"player.ai.1"
	)
	var rival_privacy := projection_adapter.privacy_report(rival_projection)
	var rival_private_identity_leak_count := _private_identity_key_count(rival_projection)
	_expect(bool(owner_privacy.get("valid", false)), "typed owner projection passes privacy validation")
	_expect(bool(rival_privacy.get("valid", false)), "real rival projection passes privacy validation")
	_expect(rival_private_identity_leak_count == 0, "rival projection exposes no owner-private card identity")
	if screen != null:
		screen.call(
			"apply_combat_projection",
			owner_projection,
			"monster.tech.local.01"
		)
	await _settle_frames(8)
	var military_options := owner_projection.get("military_task_options", []) as Array
	var military_panel := (
		surface.find_child("MilitaryPanel", true, false)
		if surface != null
		else null
	)
	var military_selection_fixture_count := 0
	if military_panel != null:
		for option_variant in military_options:
			if option_variant is Dictionary:
				var option := option_variant as Dictionary
				if bool(military_panel.call(
					"select_option_id",
					str(option.get("task_kind", "")),
					str(option.get("option_id", ""))
				)):
					military_selection_fixture_count += 1
	_expect(
		military_selection_fixture_count == 2,
		"headed presentation fixture selects both typed military options through the panel API"
	)
	await _settle_frames(3)

	var root_scroll := screen.get_node_or_null("RootMargin") as ScrollContainer if screen != null else null
	var overlay := screen.find_child("V075CombatOverlay", true, false) as Control if screen != null else null
	if root_scroll != null and overlay != null:
		root_scroll.ensure_control_visible(overlay)
	await _settle_frames(4)
	if screen != null:
		screen.call("_resolve_combat_layout")
	await _settle_frames(6)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

	var audit := screen.call("v075_responsive_geometry_audit") as Dictionary if screen != null else {}
	var combat_debug := screen.call("combat_debug_snapshot") as Dictionary if screen != null else {}
	var surface_debug := surface.call("debug_snapshot") as Dictionary if surface != null else {}
	var skill_debug := surface_debug.get("owner_skill_dock", {}) as Dictionary
	var military_debug := surface_debug.get("military_panel", {}) as Dictionary
	var military_option_ids: Array[String] = []
	for option_variant in military_options:
		if option_variant is Dictionary:
			var option_id := str((option_variant as Dictionary).get("option_id", ""))
			if not option_id.is_empty():
				military_option_ids.append(option_id)
	var distinct_military_option_ids := military_option_ids.duplicate()
	distinct_military_option_ids.sort()
	if distinct_military_option_ids.size() == 2 \
		and distinct_military_option_ids[0] == distinct_military_option_ids[1]:
		distinct_military_option_ids.resize(1)
	var military_button_bindings := (
		military_debug.get("button_presentation_bindings", {}) as Dictionary
	)
	var military_presentation_green := (
		_presentation_binding_green(
			military_button_bindings.get("assault_region", {}) as Dictionary
		)
		and _presentation_binding_green(
			military_button_bindings.get("assault_monster", {}) as Dictionary
		)
	)
	var military_option_identity_green := (
		military_option_ids.size() == 2
		and distinct_military_option_ids.size() == 2
	)
	var expected_layout_mode := _expected_layout_mode(requested_size.x)
	var population_green := (
		bool(surface_debug.get("viewer_is_owner", false))
		and int(skill_debug.get("skill_card_count", 0)) == 4
		and int(skill_debug.get("rendered_cost_pip_count", 0)) > 0
		and int(surface_debug.get("military_task_button_count", 0)) == 2
		and int(military_debug.get("option_menu_item_count", 0)) == 2
		and int(military_debug.get("invalid_option_count", 1)) == 0
		and int(military_debug.get("presentation_binding_failure_count", 1)) == 0
		and military_option_identity_green
		and military_presentation_green
		and military_selection_fixture_count == 2
	)
	_expect(population_green, "headed production surface shows four skills and two typed military options")
	_expect(bool(combat_debug.get("overlay_visible", false)), "combat overlay is visible")
	_expect(bool(combat_debug.get("surface_visible", false)), "combat surface is expanded")
	_expect(
		str(audit.get("geometry_source", "")) == "instantiated_production_controls",
		"geometry comes from instantiated production controls"
	)
	_expect(str(audit.get("layout_mode", "")) == expected_layout_mode, "physical width selects the expected responsive mode")
	_expect(bool(audit.get("panel_width_green", false)), "combat panel width fits its real safe area")
	_expect(int(audit.get("panel_viewport_overflow_count", 1)) == 0, "combat panel has no viewport overflow")
	_expect(int(audit.get("panel_safe_area_overflow_count", 1)) == 0, "combat panel has no safe-area overflow")
	_expect(int(audit.get("primary_planet_occlusion_count", 1)) == 0, "combat panel does not occlude the primary planet interaction")
	_expect(int(audit.get("asset_reserve_lane_overlap_count", 1)) == 0, "combat panel does not cover the asset reserve lane")
	_expect(int(audit.get("ui_child_collision_count", 1)) == 0, "combat controls have no child collision")
	_expect(
		int(audit.get("ui_child_unreachable_clipped_control_count", 1)) == 0,
		"combat controls have no unreachable clipped child"
	)

	var root_window_size := Vector2i(root.size)
	var display_window_size := DisplayServer.window_get_size()
	var render_backing_texture_size := Vector2i(root.get_texture().get_size())
	var pre_capture_image := root.get_texture().get_image()
	var render_backing_image_size := (
		pre_capture_image.get_size()
		if pre_capture_image != null and not pre_capture_image.is_empty()
		else Vector2i.ZERO
	)
	_expect(root.content_scale_size == production_content_scale_size, "capture leaves production content_scale_size unchanged")
	_expect(root_window_size == requested_size, "root Window size equals requested client size")
	_expect(display_window_size == requested_size, "DisplayServer window size equals requested client size")

	var native_hwnd := 0
	if DisplayServer.get_name() != "headless":
		native_hwnd = int(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
	var ready_payload := {
		"schema": "space_syndicate.v075.headed_viewport_ready.v1",
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"process_id": OS.get_process_id(),
		"expected_client_size": case_label,
		"probe_nonce": probe_nonce,
		"capture_path": capture_path,
		"native_hwnd_decimal": native_hwnd,
		"requested_client_size": _size_data(requested_size),
		"actual_runtime_viewport_kind": "main_window_client",
		"actual_runtime_viewport_api": "SceneTree.root.size(Window.size)",
		"actual_runtime_viewport_size": _size_data(root_window_size),
		"runtime_viewport_size": _size_data(root_window_size),
		"root_window_size": _size_data(root_window_size),
		"display_server_window_size": _size_data(display_window_size),
		"render_backing_texture_size": _size_data(render_backing_texture_size),
		"render_backing_image_size": _size_data(render_backing_image_size),
		"content_scale_size": _size_data(root.content_scale_size),
		"root_visible_rect_size": _vector2_data(root.get_visible_rect().size),
		"screen_viewport_rect_size": (
			_vector2_data(screen.get_viewport_rect().size)
			if screen != null
			else _vector2_data(Vector2.ZERO)
		),
		"expected_head_sha": expected_head_sha,
		"expected_tree_sha": expected_tree_sha,
		"layout_mode": str(audit.get("layout_mode", "")),
		"expected_layout_mode": expected_layout_mode,
	}
	if not _write_json_atomic(ready_path, ready_payload):
		_failures.append("ready payload could not be written")

	var ack_payload := await _wait_for_ack(ack_path, probe_nonce, 30000)
	_expect(not ack_payload.is_empty(), "external Win32 client probe acknowledgement arrives")
	var ready_sha256 := FileAccess.get_sha256(ready_path) if FileAccess.file_exists(ready_path) else ""
	if not ack_payload.is_empty():
		_expect(str(ack_payload.get("status", "")) == "PASS", "external client probe passes")
		_expect(int(ack_payload.get("process_id", 0)) == OS.get_process_id(), "external probe is bound to this Godot PID")
		_expect(str(ack_payload.get("expected_client_size", "")) == case_label, "external probe uses the requested size")
		_expect(int(ack_payload.get("client_width", 0)) == requested_size.x, "Win32 client width equals the request")
		_expect(int(ack_payload.get("client_height", 0)) == requested_size.y, "Win32 client height equals the request")
		_expect(str(ack_payload.get("ready_sha256", "")) == ready_sha256, "ack binds the immutable ready payload")
		_expect(str(ack_payload.get("probe_nonce", "")) == probe_nonce, "ack binds the per-run probe nonce")
		_expect(str(ack_payload.get("client_capture_path", "")) == capture_path, "external probe writes the declared capture path")
		_expect(int(ack_payload.get("client_capture_width", 0)) == requested_size.x, "external client capture width equals the request")
		_expect(int(ack_payload.get("client_capture_height", 0)) == requested_size.y, "external client capture height equals the request")
		_expect(int(ack_payload.get("pre_capture_client_width", 0)) == requested_size.x, "Win32 client width remains exact immediately before capture")
		_expect(int(ack_payload.get("pre_capture_client_height", 0)) == requested_size.y, "Win32 client height remains exact immediately before capture")
		_expect(int(ack_payload.get("post_capture_client_width", 0)) == requested_size.x, "Win32 client width remains exact immediately after capture")
		_expect(int(ack_payload.get("post_capture_client_height", 0)) == requested_size.y, "Win32 client height remains exact immediately after capture")
		_expect(int(ack_payload.get("post_capture_exact_sample_count", 0)) == 3, "Win32 client remains exact for three post-capture samples")
		_expect(
			native_hwnd == 0 or int(str(ack_payload.get("hwnd_decimal", "0"))) == native_hwnd,
			"Godot and external probe bind the same native window"
		)
	await process_frame
	var post_capture_runtime_viewport_size := Vector2i(root.size)
	var post_capture_display_window_size := DisplayServer.window_get_size()
	var post_capture_render_backing_texture_size := Vector2i(
		root.get_texture().get_size()
	)
	_expect(
		post_capture_runtime_viewport_size == requested_size,
		"runtime Window viewport remains exact after external capture"
	)
	_expect(
		post_capture_display_window_size == requested_size,
		"DisplayServer window remains exact after external capture"
	)

	var image := Image.load_from_file(capture_path) if FileAccess.file_exists(capture_path) else null
	var captured_image_size := (
		image.get_size()
		if image != null and not image.is_empty()
		else Vector2i.ZERO
	)
	_expect(captured_image_size == requested_size, "external client PNG remains exact-size without resampling")
	_expect(FileAccess.file_exists(capture_path), "exact-size client PNG is saved outside the worktree")
	if FileAccess.file_exists(capture_path) and not ack_payload.is_empty():
		_expect(
			FileAccess.get_sha256(capture_path) == str(ack_payload.get("client_capture_sha256", "")),
			"client PNG hash matches the external window probe acknowledgement"
		)

	var receipt := {
		"schema": "space_syndicate.v075.headed_responsive_capture.v1",
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"case_label": case_label,
		"checks": _checks,
		"failures": _failures.duplicate(),
		"expected_head_sha": expected_head_sha,
		"expected_tree_sha": expected_tree_sha,
		"staging_mode": "typed_test_projection",
		"evidence_scope": "HEADED_RESPONSIVE_PRESENTATION_PREFLIGHT",
		"presentation_fixture_apply_count": 1,
		"natural_runtime_state": false,
		"gameplay_acceptance": false,
		"test_fixture_wired_into_production": false,
		"production_composition_mutation_count": 0,
		"requested_client_size": _size_data(requested_size),
		"actual_runtime_viewport_kind": "main_window_client",
		"actual_runtime_viewport_api": "SceneTree.root.size(Window.size)",
		"actual_runtime_viewport_size": _size_data(root_window_size),
		"runtime_viewport_size": _size_data(root_window_size),
		"root_window_size": _size_data(root_window_size),
		"display_server_window_size": _size_data(display_window_size),
		"render_backing_texture_size": _size_data(render_backing_texture_size),
		"render_backing_image_size": _size_data(render_backing_image_size),
		"post_capture_runtime_viewport_size": _size_data(
			post_capture_runtime_viewport_size
		),
		"post_capture_display_server_window_size": _size_data(
			post_capture_display_window_size
		),
		"post_capture_render_backing_texture_size": _size_data(
			post_capture_render_backing_texture_size
		),
		"diagnostic_coordinate_spaces": {
			"acceptance_equality_required": false,
			"logical_canvas_visible_rect_size": _vector2_data(
				root.get_visible_rect().size
			),
			"render_target_texture_size": _size_data(
				render_backing_texture_size
			),
			"post_capture_render_target_texture_size": _size_data(
				post_capture_render_backing_texture_size
			),
		},
		"captured_image_size": _size_data(captured_image_size),
		"content_scale_size": _size_data(root.content_scale_size),
		"content_scale_size_unchanged": root.content_scale_size == production_content_scale_size,
		"root_visible_rect_size": _vector2_data(root.get_visible_rect().size),
		"screen_viewport_rect_size": (
			_vector2_data(screen.get_viewport_rect().size)
			if screen != null
			else _vector2_data(Vector2.ZERO)
		),
		"godot_pid": OS.get_process_id(),
		"native_hwnd_decimal": str(native_hwnd),
		"production_scene_path": "res://scenes/main.tscn",
		"composition_node_path": str(composition.get_path()) if composition != null else "",
		"screen_node_path": str(screen.get_path()) if screen != null else "",
		"combat_surface_node_path": str(surface.get_path()) if surface != null else "",
		"layout_mode": str(audit.get("layout_mode", "")),
		"expected_layout_mode": expected_layout_mode,
		"geometry_audit": _geometry_audit_data(audit),
		"population_green": population_green,
		"skill_card_count": int(skill_debug.get("skill_card_count", 0)),
		"rendered_cost_pip_count": int(skill_debug.get("rendered_cost_pip_count", 0)),
		"military_task_button_count": int(surface_debug.get("military_task_button_count", 0)),
		"military_option_menu_item_count": int(military_debug.get("option_menu_item_count", 0)),
		"military_option_ids": military_option_ids,
		"military_option_identity_green": military_option_identity_green,
		"military_selection_fixture_count": military_selection_fixture_count,
		"military_button_presentation_bindings": military_button_bindings.duplicate(true),
		"military_presentation_green": military_presentation_green,
		"military_presentation_binding_failure_count": int(military_debug.get("presentation_binding_failure_count", 0)),
		"rival_private_card_identity_leak_count": rival_private_identity_leak_count,
		"owner_projection_privacy_green": bool(owner_privacy.get("valid", false)),
		"rival_projection_privacy_green": bool(rival_privacy.get("valid", false)),
		"probe_nonce": probe_nonce,
		"ready_path": ready_path,
		"ready_sha256": ready_sha256,
		"ack_path": ack_path,
		"ack_payload": ack_payload,
		"png_path": capture_path,
		"png_bytes": FileAccess.get_file_as_bytes(capture_path).size() if FileAccess.file_exists(capture_path) else 0,
		"png_sha256": FileAccess.get_sha256(capture_path) if FileAccess.file_exists(capture_path) else "",
	}
	if not _write_json_atomic(receipt_path, receipt):
		_failures.append("capture receipt could not be written")
		receipt["status"] = "FAIL"
	var final_status := "PASS" if _failures.is_empty() else "FAIL"
	print(
		"V075_RESPONSIVE_VIEWPORT_HEADED_CAPTURE|status=%s|case=%s|checks=%d|failures=%d"
			% [final_status, case_label, _checks, _failures.size()]
	)
	if main != null:
		main.queue_free()
	await _settle_frames(2)
	quit(0 if _failures.is_empty() else 1)


func _geometry_audit_data(audit: Dictionary) -> Dictionary:
	var result := {}
	for key in [
		"geometry_source",
		"layout_mode",
		"responsive_physical_width",
		"panel_width_green",
		"combat_surface_content_origin_green",
		"root_scroll_accessible",
		"panel_viewport_overflow_count",
		"panel_safe_area_overflow_count",
		"primary_planet_occlusion_count",
		"track_panel_overlap_count",
		"dock_panel_overlap_count",
		"asset_reserve_lane_overlap_count",
		"ui_child_collision_count",
		"ui_child_unreachable_clipped_control_count",
		"private_grid_columns",
		"combat_surface_host_vertical_scroll_range",
	]:
		result[key] = audit.get(key)
	for key in ["panel_rect", "combat_surface_host_rect", "combat_surface_content_rect"]:
		var rect := audit.get(key, Rect2()) as Rect2
		result[key] = _rect_data(rect)
	return result


func _wait_for_ack(path: String, nonce: String, timeout_msec: int) -> Dictionary:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				var payload := parsed as Dictionary
				# The runner binds ack to ready SHA and PID. Nonce remains in the
				# immutable ready payload and is independently checked by the wrapper.
				if str(payload.get("probe_nonce", "")) == nonce:
					return payload
		await create_timer(0.05).timeout
	return {}


func _presentation_binding_green(binding: Dictionary) -> bool:
	return (
		not str(binding.get("card_definition_id", "")).is_empty()
		and not str(binding.get("presentation_asset_key", "")).is_empty()
		and not str(binding.get("resource_path", "")).is_empty()
		and bool(binding.get("texture_bound", false))
		and str(binding.get("texture_resource_path", ""))
			== str(binding.get("resource_path", ""))
	)


func _write_json_atomic(path: String, payload: Dictionary) -> bool:
	if path.is_empty():
		return false
	var parent := path.get_base_dir()
	if not parent.is_empty():
		DirAccess.make_dir_recursive_absolute(parent)
	var temporary_path := "%s.%d.tmp" % [path, OS.get_process_id()]
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(temporary_path, path) == OK


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_args():
		var text := str(argument)
		if text.begins_with("%s=" % prefix):
			return text.trim_prefix("%s=" % prefix)
	return ""


func _has_argument(expected: String) -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) == expected:
			return true
	return false


func _private_identity_key_count(value: Variant) -> int:
	if value is Dictionary:
		var count := 0
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if PRIVATE_IDENTITY_KEYS.has(key):
				count += 1
			count += _private_identity_key_count((value as Dictionary).get(key_variant))
		return count
	if value is Array:
		var count := 0
		for item in value as Array:
			count += _private_identity_key_count(item)
		return count
	return 0


func _expected_layout_mode(width: int) -> String:
	if width < 720:
		return "NARROW"
	if width < 1480:
		return "COMPACT"
	return "REGULAR"


func _is_sha1(value: String) -> bool:
	return value.length() == 40 and value.to_lower().is_valid_hex_number(false)


func _size_data(value: Vector2i) -> Dictionary:
	return {"width": value.x, "height": value.y}


func _vector2_data(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _rect_data(value: Rect2) -> Dictionary:
	return {
		"x": value.position.x,
		"y": value.position.y,
		"width": value.size.x,
		"height": value.size.y,
	}


func _settle_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition and not _failures.has(message):
		_failures.append(message)
