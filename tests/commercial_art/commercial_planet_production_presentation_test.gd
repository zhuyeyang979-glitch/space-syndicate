extends SceneTree

const MAP_SCENE := "res://scenes/ui/PlanetMapView.tscn"
const PLANET_BOARD_SCRIPT := "res://scripts/ui/planet_board.gd"
const MENU_PLANET_ART_SCRIPT := "res://scripts/ui/menu_planet_art.gd"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1366, 768)
	var map := (load(MAP_SCENE) as PackedScene).instantiate() as SpaceSyndicatePlanetMapView
	map.set_anchors_preset(Control.PRESET_TOP_LEFT)
	map.size = Vector2(720, 720)
	root.add_child(map)
	await process_frame
	var projection := map.get_projection_debug_snapshot()
	_expect(is_equal_approx(float(projection.get("zoom_min", 0.0)), 0.72) \
		and is_equal_approx(float(projection.get("zoom_max", 0.0)), 1.85) \
		and is_equal_approx(float(projection.get("zoom_step", 0.0)), 0.08), "production planet zoom uses the fixed commercial bounds and step")
	_expect(not bool(projection.get("camera_state_persisted", true)), "planet camera state remains presentation-only")

	var backdrop := map.get_node("BackdropLayer/PlanetGlobeBackdrop")
	var backdrop_debug := backdrop.call("debug_snapshot") as Dictionary
	_expect(bool(backdrop_debug.get("planet_opaque", false)) \
		and is_equal_approx(float(backdrop_debug.get("planet_alpha", 0.0)), 1.0) \
		and is_equal_approx(float(backdrop_debug.get("night_brightness", 0.0)), 0.50), "production backdrop is opaque with a readable night side")
	_expect(int(backdrop_debug.get("outer_orbit_decoration_count", -1)) == 0, "production backdrop draws no outer table ring")

	var guide := map.get_node("OrbitLayer/PlanetOrbitGuide")
	var guide_debug := guide.call("debug_snapshot") as Dictionary
	_expect(int(guide_debug.get("outer_orbit_decoration_count", -1)) == 0 \
		and int(guide_debug.get("latitude_line_count", -1)) == 0 \
		and int(guide_debug.get("longitude_curve_count", -1)) == 0, "legacy orbit and graticule decoration is retired")
	var render_model_source := FileAccess.get_file_as_string("res://scripts/ui/map/planet_map_render_model.gd")
	var globe_source := FileAccess.get_file_as_string("res://scripts/ui/map/planet_globe_backdrop.gd")
	var board_source := FileAccess.get_file_as_string(PLANET_BOARD_SCRIPT)
	var menu_planet_source := FileAccess.get_file_as_string(MENU_PLANET_ART_SCRIPT)
	_expect(render_model_source.contains("func _orbit_rings") \
		and not render_model_source.contains("radius * 1.12") \
		and not globe_source.contains("func _draw_table_ring"), "no old orbit geometry remains in the production render path")
	_expect(not board_source.contains("_draw_stage_orbit_lanes") \
		and not board_source.contains("STAGE_ORBIT_LANE_COUNT") \
		and not board_source.contains("STAGE_EDGE_TICK_COUNT"), "production table stage draws no outer orbit lanes, ticks, or beacons")
	_expect(not menu_planet_source.contains("_draw_orbits") \
		and not menu_planet_source.contains("ORBIT_COUNT") \
		and not menu_planet_source.contains("for i in range(8)"), "production main menu draws no outer orbit lanes or eight-seat dots")

	map.set_map(
		[
			{"name": "Front", "center": Vector2(700.0, 475.0), "polygon": []},
			{"name": "Back", "center": Vector2(0.0, 475.0), "polygon": []},
		],
		1400.0,
		950.0,
		-1,
		[Color("#35d0c5"), Color("#ff00ff")],
		[],
		[],
		[],
		[
			{"name": "Front monster", "position": Vector2(700.0, 475.0)},
			{"name": "Back monster", "position": Vector2(0.0, 475.0)},
		],
		[
			{"tag": "F", "position": Vector2(700.0, 475.0)},
			{"tag": "B", "position": Vector2(0.0, 475.0)},
		]
	)
	await process_frame
	await process_frame
	var sceneized := map.get_sceneized_child_snapshot()
	_expect(
		int(sceneized.get("district_node_count", -1)) == 1
			and int(sceneized.get("city_marker_count", -1)) == 1
			and int(sceneized.get("monster_token_count", -1)) == 1,
		"production sceneized overlays retain frontside markers and cull backside markers"
	)

	map.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures.append(label)
		push_error("[FAIL] %s" % label)


func _finish() -> void:
	print("COMMERCIAL_PLANET_PRODUCTION_PRESENTATION checks=%d failures=%d" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
