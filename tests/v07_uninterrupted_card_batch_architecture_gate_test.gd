extends SceneTree

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var main_scene := FileAccess.get_file_as_string("res://scenes/main.tscn")
	var surface_source := FileAccess.get_file_as_string("res://scripts/ui/v07/v07_contextual_table_surface.gd")
	var surface_scene := FileAccess.get_file_as_string("res://scenes/ui/v07/V07ContextualTableSurface.tscn")
	var reference_stage_scene := FileAccess.get_file_as_string("res://scenes/ui/v07/V07ReferencePlanetStage.tscn")
	var reference_map_scene := FileAccess.get_file_as_string("res://scenes/ui/v07/V07ReferencePlanetMapView.tscn")
	var reference_map_source := FileAccess.get_file_as_string("res://scripts/ui/v07/v07_reference_planet_map_view.gd")
	var reference_backdrop_source := FileAccess.get_file_as_string("res://scripts/ui/v07/v07_reference_planet_backdrop.gd")
	var reference_guide_source := FileAccess.get_file_as_string("res://scripts/ui/v07/v07_reference_planet_guide.gd")
	var bench_scene := FileAccess.get_file_as_string("res://scenes/tools/V07UninterruptedCardBatchContextualTableBench.tscn")

	_expect(not main_source.contains("V07ContextualTableSurface") and not main_source.contains("card_batch_v07"), "V0.7 reference foundation adds no Main responsibility or fallback")
	_expect(not main_scene.contains("V07ContextualTableSurface") and not main_scene.contains("V07UninterruptedCardBatch"), "V0.7 reference foundation does not enter production composition")
	_expect(surface_scene.contains("res://scenes/ui/v07/V07ReferencePlanetStage.tscn"), "contextual table owns a reference-only planet stage")
	_expect(not surface_scene.contains("res://scenes/ui/PlanetBoard.tscn") and not surface_scene.contains("RoleSeatLayerHost"), "reference surface no longer loads the production board or seat host")
	_expect(reference_stage_scene.contains("V07ReferencePlanetMapView.tscn") and not reference_stage_scene.contains("PlanetBoard.tscn"), "reference stage mounts its own map composition without PlanetBoard")
	_expect(reference_map_scene.contains("res://scripts/ui/v07/v07_reference_planet_map_view.gd") and reference_map_scene.contains("legacy_draw_fallback_enabled = false"), "reference map mounts its locked visual boundary with no legacy draw fallback")
	_expect(reference_map_source.contains("extends \"res://scripts/ui/planet_map_view.gd\"") and reference_map_source.contains("func _draw()") and reference_map_source.contains("legacy_draw_fallback_enabled = false"), "reference map inherits real input/projection and re-locks the fallback before every draw")
	_expect(not reference_map_scene.contains("RoleSeatLayerHost") and not reference_map_scene.contains("BackSeatLayer") and not reference_map_scene.contains("FrontSeatLayer"), "reference map contains zero left or right seat layers")
	_expect(not reference_map_scene.contains("res://scenes/ui/map/PlanetGlobeBackdrop.tscn") and not reference_map_scene.contains("res://scenes/ui/map/PlanetOrbitGuide.tscn"), "reference map does not load production underlays with positional decoration")
	_expect(not reference_map_scene.contains("PublicPlayerSeatSnapshot") and not reference_map_scene.contains("RoleSeatFallback") and not reference_map_scene.contains("PlayerSeatPortraitSkin"), "reference map has no transitive production player-position contract")
	_expect(not reference_backdrop_source.contains("SEAT_DECORATION_ANGLES") and not reference_backdrop_source.contains("set_seat_decoration_visibility"), "reference backdrop contains no positional player-decoration contract")
	_expect(not reference_guide_source.contains("range(0, 8)") and reference_guide_source.contains("radial_spoke_count\": 0"), "reference guide contains no eight-direction player spokes")
	_expect(not surface_scene.contains("Counter") and not surface_scene.contains("RightFixedRegion"), "V0.7 table scene contains no counter or permanent right rack node")
	_expect(surface_scene.contains("RegionSupplyPopup") and surface_scene.contains("CardResolutionOverlay") and surface_scene.contains("PlayerCardDock"), "contextual popup, transient resolution, and three-pool dock are editable scene nodes")
	_expect(surface_source.contains("RESOLUTION_PHASES") and surface_source.contains("ignored_gameplay_input_count"), "player target records and rejects resolution-time gameplay input")
	_expect(not surface_source.contains("CounterResponseWindowV06") and not surface_source.contains("CounterStack"), "new V0.7 player surface has no V0.6 counter dependency")
	_expect(bench_scene.contains("V07ContextualTableSurface.tscn"), "production-wiring Bench composes the real contextual table surface")

	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V07_UNINTERRUPTED_CARD_BATCH_ARCHITECTURE_GATE_TEST|status=%s|checks=%d|failures=%d|new_main_responsibility_count=0|new_main_caller_count=0|new_main_fallback_count=0" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("V07_UNINTERRUPTED_CARD_BATCH_ARCHITECTURE_GATE_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
