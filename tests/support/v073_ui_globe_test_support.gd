extends RefCounted

const MAIN_SCENE := "res://scenes/main.tscn"
const MAP_SCENE := "res://scenes/ui/PlanetMapView.tscn"
const Geometry := preload("res://scripts/presentation/v073/v073_procedural_region_geometry_v1.gd")
const Adapter := preload("res://scripts/presentation/v073/v073_planet_presentation_adapter_v1.gd")
const ResponsiveLayout := preload("res://scripts/ui/v073/v073_responsive_table_layout_v2.gd")
const LayoutAudit := preload("res://scripts/ui/v073/v073_ui_layout_collision_audit_v1.gd")
const Baseline := preload("res://scripts/playtest/v073_human_baseline_profile.gd")
const RuntimeContextQuery := preload(
	"res://scripts/v075_runtime/game_runtime_context_query.gd"
)
const FIXED_SEED := 900626424


static func run_case(tree: SceneTree, case_id: String) -> Dictionary:
	var state := {"checks": 0, "failures": []}
	match case_id:
		"planet_presentation_adapter":
			_case_planet_presentation_adapter(state)
		"procedural_region_geometry":
			_case_procedural_region_geometry(state)
		"region_geometry_seed_determinism":
			_case_region_geometry_seed_determinism(state)
		"planet_map_snapshot_connection":
			await _case_planet_map_snapshot_connection(tree, state)
		"planet_drag_rotation":
			await _case_planet_drag_rotation(tree, state)
		"planet_zoom":
			await _case_planet_zoom(tree, state)
		"planet_double_click_focus":
			await _case_planet_double_click_focus(tree, state)
		"planet_backside_occlusion":
			await _case_planet_backside_occlusion(tree, state)
		"planet_region_hit":
			await _case_planet_region_hit(tree, state)
		"map_target_binding":
			await _case_map_target_binding(tree, state)
		"map_region_popup":
			await _case_map_region_popup(tree, state)
		"map_no_gameplay_mutation":
			await _case_map_no_gameplay_mutation(tree, state)
		"responsive_table_layout":
			_case_responsive_table_layout(state)
		"ui_rect_collision_audit":
			await _case_ui_rect_collision_audit(tree, state)
		"header_overflow":
			await _case_header_overflow(tree, state)
		"coach_safe_placement":
			await _case_coach_safe_placement(tree, state)
		"marker_safe_placement":
			await _case_marker_safe_placement(tree, state)
		"card_hover_containment":
			await _case_card_hover_containment(tree, state)
		"playtest_telemetry_regression":
			await _case_playtest_telemetry_regression(tree, state)
		"human_baseline_profile_regression":
			_case_human_baseline_profile_regression(state)
		_:
			_expect(state, false, "unknown case: %s" % case_id)
	return state


static func _case_planet_presentation_adapter(state: Dictionary) -> void:
	var adapter := Adapter.new()
	var projection := _sample_projection(FIXED_SEED)
	var snapshot := adapter.build_map_snapshot(
		FIXED_SEED,
		projection,
		"dbg.player.local.card.1",
		"region.alpha"
	)
	_expect(state, snapshot != null, "adapter returns a typed MapPresentationSnapshot")
	if snapshot == null:
		return
	_expect(state, snapshot.districts.size() == 6, "adapter projects six public regions")
	_expect(state, snapshot.geometry_fingerprint.length() == 64, "adapter exposes geometry fingerprint")
	_expect(state, snapshot.presentation_seed == FIXED_SEED, "adapter keeps presentation seed")
	_expect(state, snapshot.selected_district == 0, "adapter maps selected region")
	_expect(state, snapshot.city_markers.size() == 1, "adapter projects public facility facts")
	var debug := adapter.debug_snapshot(FIXED_SEED)
	for field in ["gameplay_owner_count", "save_owner_count", "rng_owner_count", "gameplay_rng_draw_count"]:
		_expect(state, int(debug.get(field, -1)) == 0, "adapter %s stays zero" % field)
	_expect(state, int(debug.get("connection_count", 0)) == 1, "adapter has one production connection")


static func _case_procedural_region_geometry(state: Dictionary) -> void:
	var geometry := Geometry.build(FIXED_SEED)
	var districts := geometry.get("districts", []) as Array
	var audit := Geometry.audit(districts)
	_expect(state, districts.size() == 6, "geometry creates six regions")
	_expect(state, int(audit.get("region_count", 0)) == 6, "audit sees six regions")
	_expect(state, int(audit.get("region_id_duplicate_count", -1)) == 0, "region IDs are unique")
	_expect(state, int(audit.get("geometry_nonfinite_count", -1)) == 0, "geometry is finite")
	_expect(state, int(audit.get("polygon_self_intersection_count", -1)) == 0, "polygons do not self-intersect")
	for district_variant in districts:
		var district := district_variant as Dictionary
		_expect(state, (district.get("polygon", []) as Array).size() >= 3, "%s has a polygon" % str(district.get("region_id", "")))


static func _case_region_geometry_seed_determinism(state: Dictionary) -> void:
	var first := Geometry.build(FIXED_SEED)
	var repeated := Geometry.build(FIXED_SEED)
	var different := Geometry.build(FIXED_SEED + 1)
	_expect(state, str(first.get("fingerprint", "")) == str(repeated.get("fingerprint", "")), "same seed has identical geometry")
	_expect(state, first.get("districts", []) == repeated.get("districts", []), "same seed has byte-equivalent facts")
	_expect(state, str(first.get("fingerprint", "")) != str(different.get("fingerprint", "")), "different seed changes geometry")
	_expect(state, int(first.get("gameplay_rng_draw_count", -1)) == 0, "presentation geometry consumes no gameplay RNG")


static func _case_planet_map_snapshot_connection(tree: SceneTree, state: Dictionary) -> void:
	var context := await _main_context(tree, Vector2i(1600, 960), 4)
	if not _context_ready(state, context, "production main starts"):
		return
	var acceptance := _acceptance(context)
	_expect(state, int(acceptance.get("map_presentation_connection_count", 0)) == 1, "one map presentation adapter is connected")
	_expect(state, int(acceptance.get("map_presentation_apply_count", 0)) >= 1, "production snapshot reaches map")
	_expect(state, not bool(acceptance.get("planet_placeholder_active", true)), "placeholder is disabled after match start")
	_expect(state, int(acceptance.get("procedural_region_count", 0)) == 6, "production map receives six regions")
	await _cleanup_context(tree, context)


static func _case_planet_drag_rotation(tree: SceneTree, state: Dictionary) -> void:
	var context := await _map_context(tree)
	if context.is_empty():
		_expect(state, false, "map scene loads")
		return
	var map := context.get("map") as Control
	var before := map.call("get_projection_debug_snapshot") as Dictionary
	var rebuild_before := int((map.call("get_sceneization_debug_snapshot") as Dictionary).get("geometry_rebuild_count", -1))
	_send_drag(map, Vector2(310, 340), Vector2(430, 300))
	for _frame in range(3):
		await tree.process_frame
	var after := map.call("get_projection_debug_snapshot") as Dictionary
	var rebuild_after := int((map.call("get_sceneization_debug_snapshot") as Dictionary).get("geometry_rebuild_count", -2))
	_expect(state, int(after.get("drag_interaction_count", 0)) > int(before.get("drag_interaction_count", 0)), "drag increments interaction count")
	_expect(state, after.get("view_center_m", Vector2.ZERO) != before.get("view_center_m", Vector2.ZERO), "drag rotates camera center")
	_expect(state, rebuild_after == rebuild_before, "rotation does not rebuild geometry")
	_expect(state, int(after.get("camera_gameplay_mutation_count", -1)) == 0, "drag does not mutate gameplay")
	await _cleanup_context(tree, context)


static func _case_planet_zoom(tree: SceneTree, state: Dictionary) -> void:
	var context := await _map_context(tree)
	if context.is_empty():
		_expect(state, false, "map scene loads")
		return
	var map := context.get("map") as Control
	var before := map.call("get_projection_debug_snapshot") as Dictionary
	_send_wheel(map, MOUSE_BUTTON_WHEEL_UP, Vector2(360, 360))
	_send_wheel(map, MOUSE_BUTTON_WHEEL_DOWN, Vector2(360, 360))
	for _frame in range(2):
		await tree.process_frame
	var after := map.call("get_projection_debug_snapshot") as Dictionary
	_expect(state, int(after.get("zoom_interaction_count", 0)) >= int(before.get("zoom_interaction_count", 0)) + 2, "wheel input registers zoom")
	var target_zoom := float(after.get("target_view_zoom", 0.0))
	_expect(state, target_zoom >= float(after.get("zoom_min", 1.0)), "zoom stays above minimum")
	_expect(state, target_zoom <= float(after.get("zoom_max", 0.0)), "zoom stays below maximum")
	_expect(state, int(after.get("camera_rng_draw_delta", -1)) == 0, "zoom consumes no RNG")
	await _cleanup_context(tree, context)


static func _case_planet_double_click_focus(tree: SceneTree, state: Dictionary) -> void:
	var context := await _map_context(tree)
	if context.is_empty():
		_expect(state, false, "map scene loads")
		return
	var map := context.get("map") as Control
	var visible := _first_visible_region(map)
	_expect(state, int(visible.get("index", -1)) >= 0, "a frontside region is available")
	if int(visible.get("index", -1)) >= 0:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = visible.get("position", Vector2.ZERO)
		event.global_position = event.position
		event.pressed = true
		event.double_click = true
		map.call("_gui_input", event)
		await tree.process_frame
		var debug := map.call("get_projection_debug_snapshot") as Dictionary
		_expect(state, int(debug.get("focus_target_district", -1)) == int(visible.get("index", -2)), "double-click binds focus target")
		_expect(state, bool(debug.get("focus_rotation_active", false)), "double-click starts smooth focus rotation")
	await _cleanup_context(tree, context)


static func _case_planet_backside_occlusion(tree: SceneTree, state: Dictionary) -> void:
	var context := await _map_context(tree)
	if context.is_empty():
		_expect(state, false, "map scene loads")
		return
	var map := context.get("map") as Control
	var front_count := 0
	var backside_count := 0
	for index in range(6):
		var position := map.call("get_district_control_position", index) as Vector2
		if position.x < 0.0:
			backside_count += 1
		else:
			front_count += 1
			_expect(state, int(map.call("get_district_at_control_position", position)) == index, "frontside region %d remains hittable" % index)
	_expect(state, front_count > 0, "frontside regions are visible")
	_expect(state, backside_count > 0, "backside regions are occluded")
	_expect(state, int(map.call("get_district_at_control_position", Vector2(-1, -1))) == -1, "outside and hidden coordinates cannot hit")
	await _cleanup_context(tree, context)


static func _case_planet_region_hit(tree: SceneTree, state: Dictionary) -> void:
	var context := await _map_context(tree)
	if context.is_empty():
		_expect(state, false, "map scene loads")
		return
	var map := context.get("map") as Control
	var visible := _first_visible_region(map)
	var index := int(visible.get("index", -1))
	var position := visible.get("position", Vector2(-1, -1)) as Vector2
	_expect(state, index >= 0, "visible region is found")
	if index >= 0:
		_expect(state, int(map.call("get_district_at_control_position", position)) == index, "projected region center hit-tests to its region")
		_expect(state, int(map.call("get_district_at_control_position", Vector2(map.size.x + 10, map.size.y + 10))) == -1, "out-of-bounds input is rejected")
	await _cleanup_context(tree, context)


static func _case_map_target_binding(tree: SceneTree, state: Dictionary) -> void:
	var context := await _main_context(tree, Vector2i(1600, 960), 4)
	if not _context_ready(state, context, "production main starts"):
		return
	var flow := context.get("flow") as Node
	var screen := context.get("screen") as Control
	var snapshot := flow.call("local_snapshot") as Dictionary
	var hand := (((snapshot.get("personal_dbg", {}) as Dictionary).get("facts", {}) as Dictionary).get("hand", []) as Array)
	_expect(state, not hand.is_empty(), "local hand is available")
	if not hand.is_empty():
		var selected := hand[0] as Dictionary
		screen.call("_on_hand_card_activated", selected)
		var target_region := ""
		for option_variant in snapshot.get("legal_actions", []) as Array:
			var option := option_variant as Dictionary
			if str(option.get("card_instance_id", "")) == str(selected.get("instance_id", "")):
				target_region = str(option.get("target_region_id", ""))
				break
		var region_index := Geometry.REGION_IDS.find(target_region)
		_expect(state, region_index >= 0, "selected card has a legal region")
		if region_index >= 0:
			screen.call("_on_planet_district_selected", region_index)
			for _frame in range(3):
				await tree.process_frame
			var acceptance := _acceptance(context)
			_expect(state, int(acceptance.get("map_target_binding_count", 0)) == 1, "map selection binds typed card.queue target")
			_expect(state, int(acceptance.get("invalid_action_count", -1)) == 0, "map target binding remains valid")
	await _cleanup_context(tree, context)


static func _case_map_region_popup(tree: SceneTree, state: Dictionary) -> void:
	var context := await _main_context(tree, Vector2i(1600, 960), 4)
	if not _context_ready(state, context, "production main starts"):
		return
	var screen := context.get("screen") as Control
	screen.call("_on_planet_district_selected", 0)
	await tree.process_frame
	var acceptance := _acceptance(context)
	_expect(state, bool(acceptance.get("region_popup_visible", false)), "map click opens Region Popup without selected card")
	_expect(state, bool(acceptance.get("region_popup_opened_from_map", false)), "popup records map as source")
	_expect(state, int(acceptance.get("map_region_selection_count", 0)) == 1, "map region selection is counted once")
	await _cleanup_context(tree, context)


static func _case_map_no_gameplay_mutation(tree: SceneTree, state: Dictionary) -> void:
	var context := await _main_context(tree, Vector2i(1600, 960), 4)
	if not _context_ready(state, context, "production main starts"):
		return
	var flow := context.get("flow") as Node
	var screen := context.get("screen") as Control
	var before := flow.call("local_snapshot") as Dictionary
	var before_gameplay := before.duplicate(true)
	before_gameplay.erase("submission_seconds_remaining")
	var board := screen.find_child("PlanetBoard", true, false)
	var map := board.call("get_embedded_map_view") as Control
	var rebuild_before := int((map.call("get_sceneization_debug_snapshot") as Dictionary).get("geometry_rebuild_count", -1))
	_send_drag(map, Vector2(300, 330), Vector2(420, 300))
	_send_wheel(map, MOUSE_BUTTON_WHEEL_UP, Vector2(360, 360))
	map.call("reset_to_planet_overview")
	for _frame in range(3):
		await tree.process_frame
	var after := flow.call("local_snapshot") as Dictionary
	var after_gameplay := after.duplicate(true)
	after_gameplay.erase("submission_seconds_remaining")
	var debug := map.call("get_projection_debug_snapshot") as Dictionary
	var rebuild_after := int((map.call("get_sceneization_debug_snapshot") as Dictionary).get("geometry_rebuild_count", -2))
	_expect(state, before_gameplay == after_gameplay, "camera input leaves stable gameplay projection unchanged")
	_expect(state, int(debug.get("camera_gameplay_mutation_count", -1)) == 0, "camera gameplay mutation count stays zero")
	_expect(state, int(debug.get("camera_rng_draw_delta", -1)) == 0, "camera RNG delta stays zero")
	_expect(state, rebuild_after == rebuild_before, "camera input does not rebuild geometry")
	await _cleanup_context(tree, context)


static func _case_responsive_table_layout(state: Dictionary) -> void:
	var compact := ResponsiveLayout.profile_for(Vector2(1366, 768), 4)
	var regular := ResponsiveLayout.profile_for(Vector2(1600, 960), 4)
	var wide := ResponsiveLayout.profile_for(Vector2(1920, 1080), 8)
	_expect(state, str(compact.get("mode", "")) == ResponsiveLayout.COMPACT_DESKTOP, "1366x768 selects compact")
	_expect(state, float(compact.get("planet_stage_height", 0.0)) >= 220.0, "compact planet stage is at least 220px")
	_expect(state, str(regular.get("mode", "")) == ResponsiveLayout.REGULAR_DESKTOP, "1600x960 selects regular")
	_expect(state, float(regular.get("planet_stage_height", 0.0)) >= 340.0, "regular planet stage is at least 340px")
	_expect(state, str(wide.get("mode", "")) == ResponsiveLayout.WIDE_DESKTOP, "1920x1080 selects wide")
	_expect(state, float(wide.get("planet_stage_height", 0.0)) >= 460.0, "wide planet stage is at least 460px")
	_expect(state, float(wide.get("roster_width", 0.0)) > float(regular.get("roster_width", 0.0)), "8P wide roster receives more width")


static func _case_ui_rect_collision_audit(tree: SceneTree, state: Dictionary) -> void:
	for row in [[Vector2i(1366, 768), 4], [Vector2i(1600, 960), 4], [Vector2i(1920, 1080), 8]]:
		var context := await _main_context(tree, row[0] as Vector2i, int(row[1]))
		if not _context_ready(
			state,
			context,
			"%s production main starts" % str(row[0])
		):
			continue
		var audit := (_acceptance(context).get("ui_layout_collision_audit", {}) as Dictionary)
		_expect(state, str(audit.get("schema", "")) == LayoutAudit.SCHEMA, "%s uses collision audit V1" % str(row[0]))
		for field in [
			"unintended_major_panel_intersection_count",
			"interactive_control_occlusion_count",
			"target_panel_dock_overlap_count",
			"roster_planet_overlap_count",
			"planet_draw_outside_stage_count",
		]:
			_expect(state, int(audit.get(field, -1)) == 0, "%s %s is zero" % [str(row[0]), field])
		var screen := context.get("screen") as Control
		var board := screen.find_child("PlanetBoard", true, false)
		var map := board.call("get_embedded_map_view") as Control if board != null else null
		_expect(state, map != null, "%s production planet map exists" % str(row[0]))
		if map != null:
			map.call("zoom_to_local_projection")
			await tree.create_timer(0.36).timeout
			for _frame in range(3):
				await tree.process_frame
			var sceneized := map.call("get_sceneization_debug_snapshot") as Dictionary
			_expect(
				state,
				int(sceneized.get("district_label_intersection_count", -1)) == 0,
				"%s local projection district labels do not intersect" % str(row[0])
			)
			screen.call("_update_acceptance_state")
			var post_interaction_audit := (_acceptance(context).get("ui_layout_collision_audit", {}) as Dictionary)
			_expect(
				state,
				int(post_interaction_audit.get("interactive_control_occlusion_count", -1)) == 0,
				"%s post-interaction controls do not overlap: %s" % [
					str(row[0]),
					JSON.stringify(post_interaction_audit.get("interactive_intersections", [])),
				]
			)
		await _cleanup_context(tree, context)


static func _case_header_overflow(tree: SceneTree, state: Dictionary) -> void:
	for size in [Vector2i(1366, 768), Vector2i(1600, 960), Vector2i(1920, 1080)]:
		var context := await _main_context(tree, size, 4)
		if not _context_ready(
			state,
			context,
			"%s production main starts" % str(size)
		):
			continue
		var acceptance := _acceptance(context)
		for field in ["header_overflow_count", "header_text_clip_count", "header_interactive_control_overlap_count"]:
			_expect(state, int(acceptance.get(field, -1)) == 0, "%s %s is zero" % [str(size), field])
		var notice := (context.get("screen") as Control).find_child("SaveNotice", true, false) as Label
		_expect(state, notice != null and notice.visible and notice.size.y >= 20.0, "%s Save boundary remains readable" % str(size))
		await _cleanup_context(tree, context)


static func _case_coach_safe_placement(tree: SceneTree, state: Dictionary) -> void:
	for size in [Vector2i(1366, 768), Vector2i(1600, 960), Vector2i(1920, 1080)]:
		var context := await _main_context(tree, size, 4)
		if not _context_ready(
			state,
			context,
			"%s production main starts" % str(size)
		):
			continue
		for _frame in range(3):
			await tree.process_frame
		var screen := context.get("screen") as Control
		var coach := screen.get_node_or_null("V073PlaytestCoachMarks")
		var callout := coach.find_child("CoachCallout", true, false) as Control
		var target_panel := screen.find_child("TargetPanel", true, false) as Control
		_expect(state, callout != null and target_panel != null, "%s Coach and TargetRail are present" % str(size))
		for mark_index in range(14):
			for _frame in range(2):
				await tree.process_frame
			var debug := coach.call("debug_snapshot") as Dictionary
			_expect(state, int(debug.get("mark_count", 0)) == 14, "coach count stays fourteen")
			for field in ["offscreen_count", "target_occlusion_count", "primary_input_block_count", "map_center_occlusion_count"]:
				_expect(state, int(debug.get(field, -1)) == 0, "%s coach %s is zero at mark %d" % [str(size), field, mark_index + 1])
			_expect(
				state,
				not callout.get_global_rect().intersects(target_panel.get_global_rect()),
				"%s Coach avoids TargetRail at mark %d" % [str(size), mark_index + 1]
			)
			if mark_index < 13:
				coach.call("_advance")
		await _cleanup_context(tree, context)


static func _case_marker_safe_placement(tree: SceneTree, state: Dictionary) -> void:
	for size in [Vector2i(1366, 768), Vector2i(1600, 960), Vector2i(1920, 1080)]:
		var context := await _main_context(tree, size, 4)
		if not _context_ready(
			state,
			context,
			"%s production main starts" % str(size)
		):
			continue
		var marker := (context.get("screen") as Control).find_child("V073PlaytestMarkerPanel", true, false)
		marker.call("set_temporarily_hidden", false)
		marker.call("apply_safe_layout", Vector2(size), str(_acceptance(context).get("responsive_layout_mode", "")), 92.0)
		await tree.process_frame
		var debug := marker.call("debug_snapshot") as Dictionary
		_expect(state, bool(debug.get("collapsed", false)), "%s marker defaults collapsed" % str(size))
		_expect(state, int(debug.get("header_width_consumption", -1)) == 0, "%s marker consumes no header width" % str(size))
		_expect(state, int(debug.get("offscreen_count", -1)) == 0, "%s marker stays onscreen" % str(size))
		_expect(state, int(debug.get("primary_input_block_count", -1)) == 0, "%s marker blocks no primary input" % str(size))
		await _cleanup_context(tree, context)


static func _case_card_hover_containment(tree: SceneTree, state: Dictionary) -> void:
	var context := await _main_context(tree, Vector2i(1366, 768), 4)
	if not _context_ready(state, context, "production main starts"):
		return
	var screen := context.get("screen") as Control
	var hand_scroll := screen.find_child("HandScroll", true, false) as ScrollContainer
	var track_scroll := screen.find_child("TrackScroll", true, false) as ScrollContainer
	_expect(state, hand_scroll != null and hand_scroll.clip_contents, "Hand Dock hover is clipped to its ScrollContainer")
	_expect(state, track_scroll != null and track_scroll.clip_contents, "Track hover is clipped to its ScrollContainer")
	var cards := screen.find_children("*", "V073SampleCardButton", true, false)
	_expect(state, cards.size() >= 5, "production UI renders interactive cards")
	for card_variant in cards:
		var card := card_variant as Control
		_expect(state, card.custom_minimum_size.x > 0.0 and card.custom_minimum_size.y > 0.0, "hover card keeps stable dimensions")
	await _cleanup_context(tree, context)


static func _case_playtest_telemetry_regression(tree: SceneTree, state: Dictionary) -> void:
	var context := await _main_context(tree, Vector2i(1600, 960), 4)
	if not _context_ready(state, context, "production main starts"):
		return
	var telemetry := context.get("telemetry") as Node
	_expect(state, telemetry != null, "telemetry service remains connected")
	if telemetry != null:
		var debug := telemetry.call("debug_snapshot") as Dictionary
		for field in [
			"gameplay_owner_count",
			"save_owner_count",
			"rng_owner_count",
			"world_mutation_count",
			"player_mutation_count",
			"rng_draw_delta",
			"world_time_delta",
			"hidden_info_field_count",
		]:
			_expect(state, int(debug.get(field, -1)) == 0, "telemetry %s stays zero" % field)
	_expect(state, str(_acceptance(context).get("region_geometry_fingerprint", "")).length() == 64, "telemetry coexists with map fingerprint")
	await _cleanup_context(tree, context)


static func _case_human_baseline_profile_regression(state: Dictionary) -> void:
	var snapshot := Baseline.snapshot()
	_expect(state, str(snapshot.get("ruleset_id", "")) == "v0.7.3", "baseline stays on V0.7.3")
	_expect(state, str(snapshot.get("profile_id", "")) == "v073_human_baseline_01", "baseline profile ID stays frozen")
	_expect(state, Baseline.PROFILE_FINGERPRINT == "d696623d8cb3371d08c8870189927a53e48212ca30e9f276bc81b6491b01fbd2", "baseline fingerprint is unchanged")
	_expect(state, Baseline.PROFILE_FINGERPRINT_INPUT.sha256_text().to_lower() == Baseline.PROFILE_FINGERPRINT, "baseline canonical input matches fingerprint")
	_expect(state, int(snapshot.get("production_balance_value_change_count", -1)) == 0, "production balance change count stays zero")


static func _main_context(tree: SceneTree, viewport_size: Vector2i, player_count: int) -> Dictionary:
	tree.root.size = viewport_size
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		return _failed_main_context("main_root_missing")
	var application := packed.instantiate()
	if application == null:
		return _failed_main_context("main_root_missing")
	tree.root.add_child(application)
	for _frame in range(3):
		await tree.process_frame
	var query := RuntimeContextQuery.from_application(application)
	var preflight := query.call("snapshot") as Dictionary
	if str(preflight.get("reason_code", "")) != "runtime_not_active":
		await _discard_main_application(tree, application)
		return _failed_main_context(
			str(preflight.get("reason_code", "runtime_composition_missing")),
			preflight
		)
	var flow := query.call("runtime_composition") as Node
	var screen := query.call("game_screen") as Control
	var intent := flow.call("issue_intent", "new_game.start", {
		"player_count": player_count,
		"seed": FIXED_SEED,
	}) as Dictionary
	var receipt := flow.call("submit_intent", intent) as Dictionary
	if not bool(receipt.get("accepted", false)):
		await _discard_main_application(tree, application)
		return _failed_main_context("runtime_not_active", {
			"receipt": receipt.duplicate(true),
		})
	screen.call("apply_snapshot", flow.call("local_snapshot") as Dictionary)
	for _frame in range(4):
		await tree.process_frame
	var context_snapshot := query.call("snapshot") as Dictionary
	if not bool(context_snapshot.get("ready", false)):
		var query_diagnostics := {
			"query": context_snapshot.duplicate(true),
			"identity": flow.call("identity_snapshot") as Dictionary,
			"composition": flow.call("debug_snapshot") as Dictionary,
			"screen": screen.call("debug_snapshot") as Dictionary,
			"telemetry": query.call("telemetry_service").call(
				"debug_snapshot"
			) as Dictionary,
		}
		await _discard_main_application(tree, application)
		return _failed_main_context(
			str(context_snapshot.get("reason_code", "runtime_not_active")),
			query_diagnostics
		)
	return {
		"ready": true,
		"reason_code": "ready",
		"application": application,
		"flow": flow,
		"screen": screen,
		"telemetry": query.call("telemetry_service") as Node,
		"runtime_context": context_snapshot,
	}


static func _failed_main_context(
	reason_code: String,
	detail: Dictionary = {}
) -> Dictionary:
	return {
		"ready": false,
		"reason_code": reason_code,
		"runtime_context": detail.duplicate(true),
	}


static func _context_ready(
	state: Dictionary,
	context: Dictionary,
	message: String
) -> bool:
	var ready := bool(context.get("ready", false))
	_expect(
		state,
		ready,
		"%s: %s" % [message, str(context.get("reason_code", "unknown"))]
	)
	return ready


static func _discard_main_application(
	tree: SceneTree,
	application: Node
) -> void:
	if is_instance_valid(application):
		application.queue_free()
	for _frame in range(2):
		await tree.process_frame


static func _map_context(tree: SceneTree) -> Dictionary:
	tree.root.size = Vector2i(720, 720)
	var packed := load(MAP_SCENE) as PackedScene
	if packed == null:
		return {}
	var host := Control.new()
	host.name = "MapTestHost"
	host.size = Vector2(720, 720)
	tree.root.add_child(host)
	var map := packed.instantiate() as Control
	host.add_child(map)
	map.position = Vector2.ZERO
	map.size = Vector2(720, 720)
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for _frame in range(2):
		await tree.process_frame
	var geometry := Geometry.build(FIXED_SEED)
	map.call(
		"set_map",
		geometry.get("districts", []) as Array,
		float(geometry.get("width_m", 1400.0)),
		float(geometry.get("height_m", 950.0)),
		-1,
		Adapter.PALETTE
	)
	map.call("set_presentation_identity", FIXED_SEED, str(geometry.get("fingerprint", "")))
	for _frame in range(3):
		await tree.process_frame
	return {
		"application": host,
		"map": map,
	}


static func _cleanup_context(tree: SceneTree, context: Dictionary) -> void:
	var application := context.get("application") as Node
	if application != null and is_instance_valid(application):
		application.queue_free()
	for _frame in range(2):
		await tree.process_frame


static func _acceptance(context: Dictionary) -> Dictionary:
	var screen := context.get("screen") as Control
	screen.call("_update_acceptance_state")
	return (screen.get("acceptance_state") as Dictionary).duplicate(true)


static func _sample_projection(seed: int) -> Dictionary:
	var solar: Array = []
	for index in range(Geometry.REGION_IDS.size()):
		solar.append({
			"region_id": Geometry.REGION_IDS[index],
			"sunlit": index < 3,
			"facility_efficiency_multiplier": 2.0 if index < 3 else 1.0,
		})
	return {
		"ruleset_id": "v0.7.3",
		"presentation_match_seed": seed,
		"batch_number": 1,
		"roster": [{"is_local_player": true, "public_order_index": 0}],
		"region_solar": solar,
		"legal_actions": [{
			"card_instance_id": "dbg.player.local.card.1",
			"target_region_id": "region.alpha",
		}],
		"facility_contention": {
			"public_facility_slots": [{
				"occupancy": "occupied",
				"facility_type": "factory",
				"industry_id": "life",
				"region_id": "region.alpha",
				"rank": 1,
			}],
		},
		"monster_public_facts": [],
		"military_public_facts": [],
		"public_routes": [],
	}


static func _first_visible_region(map: Control) -> Dictionary:
	for index in range(6):
		var position := map.call("get_district_control_position", index) as Vector2
		if position.x >= 0.0 and position.y >= 0.0:
			return {"index": index, "position": position}
	return {}


static func _send_drag(map: Control, start: Vector2, finish: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = start
	press.global_position = start
	press.pressed = true
	map.call("_gui_input", press)
	var motion := InputEventMouseMotion.new()
	motion.position = finish
	motion.global_position = finish
	motion.relative = finish - start
	motion.screen_relative = motion.relative
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	map.call("_gui_input", motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = finish
	release.global_position = finish
	release.pressed = false
	map.call("_gui_input", release)


static func _send_wheel(map: Control, button_index: MouseButton, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.position = position
	event.global_position = position
	event.pressed = true
	map.call("_gui_input", event)


static func _expect(state: Dictionary, condition: bool, message: String) -> void:
	state["checks"] = int(state.get("checks", 0)) + 1
	if not condition:
		(state.get("failures", []) as Array).append(message)
