extends SceneTree

const Support := preload("res://tests/v074_planet_test_support.gd")
const Adapter := preload("res://scripts/presentation/v074/v074_planet_presentation_adapter_v1.gd")
const PlanetScene := preload("res://scenes/ui/PlanetMapView.tscn")


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
	view.queue_free()
	await process_frame
	Support.print_result("V074_PLANET_MAP_VIEW_TEST", checks, failures, self)
