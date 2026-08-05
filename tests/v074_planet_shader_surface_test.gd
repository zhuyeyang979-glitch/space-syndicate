extends SceneTree

const Support := preload("res://tests/v074_planet_test_support.gd")
const Adapter := preload("res://scripts/presentation/v074/v074_planet_presentation_adapter_v1.gd")
const PlanetScene := preload("res://scenes/ui/PlanetMapView.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array = []
	var checks := 0
	var receipt := Support.build_receipt(24, "COMPLEX")
	var payload := Adapter.new().build_map_view_payload(receipt, Support.public_projection(receipt))
	var view := PlanetScene.instantiate() as Control
	root.add_child(view)
	view.size = Vector2(1100.0, 720.0)
	view.call("apply_v074_map_view_payload", payload)
	await process_frame
	await process_frame
	var backdrop := view.get_node("BackdropLayer/PlanetGlobeBackdrop") as Control
	var first := backdrop.call("debug_snapshot") as Dictionary
	checks += 1
	Support.add_failure(failures, bool(first.get("authoritative_terrain_mask_ready", false)), "authoritative terrain mask not ready")
	checks += 1
	Support.add_failure(failures, bool(first.get("terrain_relief", false)) and bool(first.get("ocean_depth_shading", false)), "relief or ocean depth missing")
	checks += 1
	Support.add_failure(failures, bool(first.get("coastline_visual_alignment", false)), "coastline not aligned to authoritative mask")
	checks += 1
	Support.add_failure(failures, int(first.get("flat_texture_dependency_count", -1)) == 0 and not bool(first.get("static_texture_only_mode", true)), "static texture fallback active")
	var rebuild_count := int(first.get("terrain_mask_rebuild_count", -1))
	view.call("_pan_view", Vector2(120.0, 0.0))
	view.call("_update_sceneized_projection_nodes")
	await process_frame
	var second := backdrop.call("debug_snapshot") as Dictionary
	checks += 1
	Support.add_failure(failures, int(second.get("terrain_mask_rebuild_count", -2)) == rebuild_count, "rotation rebuilt terrain mask")
	checks += 1
	Support.add_failure(failures, bool(second.get("surface_rotates_with_camera", false)) and bool(second.get("solar_terminator", false)), "camera or solar shader contract missing")
	checks += 1
	Support.add_failure(failures, ResourceLoader.exists("res://shaders/v074_planet_surface.gdshader"), "V074 shader resource missing")
	view.queue_free()
	await process_frame
	Support.print_result("V074_PLANET_SHADER_SURFACE_TEST", checks, failures, self)
