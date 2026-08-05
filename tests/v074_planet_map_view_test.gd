extends SceneTree

const Support := preload("res://tests/v074_planet_test_support.gd")
const Adapter := preload("res://scripts/presentation/v074/v074_planet_presentation_adapter_v1.gd")
const PlanetScene := preload("res://scenes/ui/PlanetMapView.tscn")
const PolygonScene := preload("res://scenes/ui/map/PlanetDistrictPolygon.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array = []
	var checks := 0
	var receipt := Support.build_receipt(16, "STANDARD")
	var payload := Adapter.new().build_map_view_payload(receipt, Support.public_projection(receipt))
	var view := PlanetScene.instantiate() as Control
	root.add_child(view)
	view.size = Vector2(1000.0, 650.0)
	view.set("programmatic_focus_animation_enabled", false)
	var polygon := PolygonScene.instantiate() as Control
	var valid_concave_polygon := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(6.0, 0.0),
		Vector2(6.0, 5.0),
		Vector2(3.0, 2.0),
		Vector2(0.0, 5.0),
	])
	var invalid_self_intersecting_polygon := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(6.0, 0.0),
		Vector2(1.0, 4.0),
		Vector2(5.0, 5.0),
		Vector2(0.0, 2.0),
	])
	checks += 1
	Support.add_failure(
		failures,
		bool(polygon.call("_can_fill_polygon", valid_concave_polygon)),
		"valid concave projection was rejected by the fill guard"
	)
	checks += 1
	Support.add_failure(
		failures,
		not bool(polygon.call(
			"_can_fill_polygon",
			invalid_self_intersecting_polygon
		)),
		"self-intersecting projection reached CanvasItem triangulation"
	)
	polygon.free()
	var applied := bool(view.call("apply_v074_map_view_payload", payload))
	await process_frame
	await process_frame
	checks += 1
	Support.add_failure(failures, applied, "authoritative payload did not apply")
	checks += 1
	Support.add_failure(failures, int(view.get("districts").size()) == 16, "view district count mismatch")
	view.call("focus_district", 0, false)
	await process_frame
	var center := view.call("get_district_control_position", 0) as Vector2
	var hit := int(view.call("get_district_at_control_position", center))
	checks += 1
	Support.add_failure(failures, hit == 0, "authoritative microcell hit test missed focused region")
	view.call("focus_district", 2, false)
	view.call("_update_sceneized_projection_nodes")
	await process_frame
	var warehouse_front_position := view.call(
		"get_district_control_position",
		2
	) as Vector2
	var warehouse_marker_rows := view.get("city_markers") as Array
	checks += 1
	Support.add_failure(
		failures,
		warehouse_marker_rows.size() > 2
		and str((warehouse_marker_rows[2] as Dictionary).get("facility_type", "")) == "warehouse",
		"warehouse marker fixture is not bound to region 2"
	)
	var preflip_debug := view.call("v074_planet_debug_snapshot") as Dictionary
	var half_turn_pixels := float(preflip_debug.get("globe_radius", 0.0)) * PI
	view.call("_pan_view", Vector2(half_turn_pixels, 0.0))
	view.call("_update_sceneized_projection_nodes")
	await process_frame
	var warehouse_backside_position := view.call(
		"get_district_control_position",
		2
	) as Vector2
	checks += 1
	Support.add_failure(
		failures,
		warehouse_backside_position.x < 0.0 and warehouse_backside_position.y < 0.0,
		"backside warehouse region still exposes a control position"
	)
	var backside_hit := int(view.call(
		"get_district_at_control_position",
		warehouse_front_position
	))
	checks += 1
	Support.add_failure(
		failures,
		backside_hit != 2,
		"backside warehouse region accepted a front-surface hit"
	)
	var district_nodes := view.get("_sceneized_district_nodes") as Array
	checks += 1
	Support.add_failure(
		failures,
		district_nodes.size() > 2
		and not bool((district_nodes[2] as Control).visible),
		"backside district label remains visible"
	)
	var facility_nodes := view.get("_sceneized_city_marker_nodes") as Array
	checks += 1
	Support.add_failure(
		failures,
		facility_nodes.size() > 2
		and not bool((facility_nodes[2] as Control).visible),
		"backside warehouse marker remains visible"
	)
	view.call("_pan_view", Vector2(-half_turn_pixels, 0.0))
	view.call("_update_sceneized_projection_nodes")
	await process_frame
	var before := view.call("v074_planet_debug_snapshot") as Dictionary
	view.call("_pan_view", Vector2(86.0, -24.0))
	view.call("_update_sceneized_projection_nodes")
	await process_frame
	var after := view.call("v074_planet_debug_snapshot") as Dictionary
	checks += 1
	Support.add_failure(failures, int(after.get("authoritative_geometry_rebuild_count", -1)) == int(before.get("authoritative_geometry_rebuild_count", -2)), "camera rotation rebuilt authoritative geometry")
	checks += 1
	Support.add_failure(failures, int(after.get("lod_projection_update_count", 0)) > int(before.get("lod_projection_update_count", 0)), "camera rotation did not refresh projection LOD")
	view.call("zoom_to_local_projection")
	var zoom_snapshot := view.call("get_projection_debug_snapshot") as Dictionary
	checks += 1
	Support.add_failure(failures, float(zoom_snapshot.get("target_view_zoom", 0.0)) > 0.9, "local zoom target unavailable")
	view.call("reset_to_planet_overview")
	var reset_snapshot := view.call("get_projection_debug_snapshot") as Dictionary
	checks += 1
	Support.add_failure(failures, is_equal_approx(float(reset_snapshot.get("target_view_zoom", 0.0)), 0.72), "overview reset unavailable")
	var outside_hit := int(view.call("get_district_at_control_position", Vector2(-20.0, -20.0)))
	checks += 1
	Support.add_failure(failures, outside_hit == -1, "outside/backside input accepted")
	var debug := view.call("v074_planet_debug_snapshot") as Dictionary
	checks += 1
	Support.add_failure(failures, int(debug.get("camera_gameplay_mutation_count", -1)) == 0 and int(debug.get("camera_rng_draw_delta", -1)) == 0, "camera mutated gameplay")
	checks += 1
	Support.add_failure(
		failures,
		bool(debug.get("authoritative_globe_projection_locked", false)),
		"authoritative V0.7.4 surface escaped globe projection"
	)
	var radius := float(debug.get("globe_radius", 0.0))
	checks += 1
	Support.add_failure(
		failures,
		radius >= minf(view.size.x, view.size.y) * 0.42
		and radius <= minf(view.size.x, view.size.y) * 0.486,
		"authoritative globe zoom escaped bounded stage radius"
	)
	view.queue_free()
	await process_frame
	Support.print_result("V074_PLANET_MAP_VIEW_TEST", checks, failures, self)
