extends SceneTree

const COMPONENT_SCENE_PATH := "res://scenes/tools/commercial_art/components/planet/CommercialPlanetReviewComponent.tscn"
const BODY_SHADER_PATH := "res://assets/third_party/commercial/planet/naejimer_planet_generator/processed/space_syndicate_planet_body.gdshader"
const CLOUD_SHADER_PATH := "res://assets/third_party/commercial/planet/naejimer_planet_generator/processed/space_syndicate_planet_clouds.gdshader"
const ATMOSPHERE_SHADER_PATH := "res://assets/third_party/commercial/planet/naejimer_planet_generator/processed/space_syndicate_planet_atmosphere.gdshader"
const VFX_MAP_PATH := "res://assets/third_party/commercial/vfx/commercial_vfx_event_map_v1.json"

const MATERIAL_PATHS := [
	"res://assets/third_party/commercial/materials/ambientcg/MetalPlates013/metal_plates_013_material.tres",
	"res://assets/third_party/commercial/materials/ambientcg/PaintedMetal007/painted_metal_007_material.tres",
	"res://assets/third_party/commercial/materials/ambientcg/SheetMetal003/sheet_metal_003_material.tres",
	"res://assets/third_party/commercial/materials/ambientcg/NightSkyHDRI001/night_sky_hdri_001_2k_sky.tres",
]

const SOURCE_EVIDENCE_PATHS := [
	"res://assets/third_party/commercial/planet/naejimer_planet_generator/LICENSE",
	"res://assets/third_party/commercial/planet/naejimer_planet_generator/SOURCE.md",
	"res://assets/third_party/commercial/materials/ambientcg/LICENSE.md",
	"res://assets/third_party/commercial/vfx/kenney_particle_pack/LICENSE.txt",
	"res://assets/third_party/commercial/vfx/kenney_particle_pack/SOURCE.md",
	"res://assets/third_party/commercial/vfx/kenney_smoke_particles/LICENSE.txt",
	"res://assets/third_party/commercial/vfx/kenney_smoke_particles/SOURCE.md",
]

const EXPECTED_EVENT_IDS := [
	"asset.refresh",
	"card.lock",
	"card.merge",
	"commodity.claim",
	"normal_card.purchase",
	"settlement.complete",
]

const EXPECTED_SEQUENCE_IDS := [
	"combat.explosion",
	"combat.flash",
	"facility.black_smoke",
	"facility.white_puff",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_source_and_license_evidence()
	_test_material_and_shader_resources()
	_test_vfx_contract()
	await _test_planet_component()
	_test_production_boundary()
	_finish()


func _test_source_and_license_evidence() -> void:
	for path_variant: Variant in SOURCE_EVIDENCE_PATHS:
		var path := str(path_variant)
		_expect(FileAccess.file_exists(path), "%s is retained" % path)
	var mit_text := FileAccess.get_file_as_string(SOURCE_EVIDENCE_PATHS[0])
	var ambient_text := FileAccess.get_file_as_string(SOURCE_EVIDENCE_PATHS[2])
	var particle_license := FileAccess.get_file_as_string(SOURCE_EVIDENCE_PATHS[3])
	var smoke_license := FileAccess.get_file_as_string(SOURCE_EVIDENCE_PATHS[5])
	_expect(mit_text.contains("MIT License") and mit_text.contains("Copyright (c) 2023"), "Naejimer MIT text is retained verbatim")
	_expect(ambient_text.contains("CC0") and ambient_text.contains("MetalPlates013") and ambient_text.contains("NightSkyHDRI001"), "ambientCG CC0 evidence covers all four selected assets")
	_expect(particle_license.contains("Creative Commons Zero") and smoke_license.contains("License (CC0)"), "both Kenney package licenses attest CC0")


func _test_material_and_shader_resources() -> void:
	for path_variant: Variant in MATERIAL_PATHS:
		var path := str(path_variant)
		_expect(ResourceLoader.exists(path) and load(path) != null, "%s loads" % path)
	for path in [BODY_SHADER_PATH, CLOUD_SHADER_PATH, ATMOSPHERE_SHADER_PATH]:
		_expect(ResourceLoader.exists(path) and load(path) is Shader, "%s loads as a shader" % path)
	var body_source := FileAccess.get_file_as_string(BODY_SHADER_PATH)
	var cloud_source := FileAccess.get_file_as_string(CLOUD_SHADER_PATH)
	var atmosphere_source := FileAccess.get_file_as_string(ATMOSPHERE_SHADER_PATH)
	_expect(body_source.contains("cull_back") and body_source.contains("depth_draw_opaque") and body_source.contains("ALPHA = 1.0"), "planet body is opaque with back-face culling and opaque depth writes")
	_expect(body_source.contains("night_brightness") and body_source.contains("0.50") and body_source.contains("day_brightness"), "planet shader fixes a clear 1.0 day and 0.50 night presentation ratio")
	_expect(not body_source.contains("depth_test_disabled") and not cloud_source.contains("depth_test_disabled") and not atmosphere_source.contains("depth_test_disabled"), "all planet layers preserve depth testing")
	_expect(cloud_source.contains("max_alpha") and atmosphere_source.contains("edge_alpha"), "cloud and atmosphere opacity are explicitly bounded")
	var source_shader_dir := "res://assets/third_party/commercial/planet/naejimer_planet_generator/source"
	var source_shader_count := 0
	for shader_name in ["body.gdshader", "clouds.gdshader", "atmosphere.gdshader"]:
		if FileAccess.file_exists("%s/%s" % [source_shader_dir, shader_name]):
			source_shader_count += 1
	_expect(source_shader_count == 3, "only the three required upstream planet shaders are retained")


func _test_vfx_contract() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(VFX_MAP_PATH))
	_expect(parsed is Dictionary, "commercial VFX event map is strict JSON")
	if not (parsed is Dictionary):
		return
	var payload := parsed as Dictionary
	_expect(bool(payload.get("presentation_only", false)) and not bool(payload.get("rules_rng_consumed", true)), "VFX remains presentation-only and consumes no rules RNG")
	_expect(int(payload.get("max_concurrent_transparent_emitters", 0)) == 12, "transparent emitter population has a fixed global cap")
	var event_ids: Array[String] = []
	for event_variant: Variant in payload.get("events", []):
		var event := event_variant as Dictionary
		event_ids.append(str(event.get("event_id", "")))
		var texture_path := str(event.get("texture_path", ""))
		_expect(FileAccess.file_exists(texture_path), "%s uses an integrated local texture" % str(event.get("event_id", "")))
	event_ids.sort()
	_expect(event_ids == EXPECTED_EVENT_IDS, "six required particle events have one deterministic texture each")
	var sequence_ids: Array[String] = []
	for sequence_variant: Variant in payload.get("sequences", []):
		var sequence := sequence_variant as Dictionary
		sequence_ids.append(str(sequence.get("sequence_id", "")))
		var directory := DirAccess.open(str(sequence.get("directory", "")))
		var frame_count := 0
		if directory != null:
			directory.list_dir_begin()
			var file_name := directory.get_next()
			while not file_name.is_empty():
				if not directory.current_is_dir() and file_name.get_extension().to_lower() == "png":
					frame_count += 1
				file_name = directory.get_next()
			directory.list_dir_end()
		_expect(frame_count == int(sequence.get("frame_count", -1)), "%s retains exactly its declared sparse frame set" % str(sequence.get("sequence_id", "")))
	sequence_ids.sort()
	_expect(sequence_ids == EXPECTED_SEQUENCE_IDS, "smoke and combat sequences are a closed four-family set")


func _test_planet_component() -> void:
	var packed := load(COMPONENT_SCENE_PATH) as PackedScene
	_expect(packed != null, "commercial planet review component loads")
	if packed == null:
		return
	var component := packed.instantiate() as SubViewportContainer
	_expect(component != null, "commercial planet review component instantiates")
	if component == null:
		return
	component.set_anchors_preset(Control.PRESET_TOP_LEFT)
	component.size = Vector2(960.0, 640.0)
	root.add_child(component)
	await process_frame
	await process_frame
	var snapshot := component.call("debug_snapshot") as Dictionary
	_expect(bool(snapshot.get("presentation_only", false)) and bool(snapshot.get("planet_opaque", false)) and is_equal_approx(float(snapshot.get("planet_alpha", 0.0)), 1.0), "review planet is an opaque presentation-only surface")
	_expect(bool(snapshot.get("back_face_culling", false)) and bool(snapshot.get("depth_test", false)), "review planet enables back-face culling and depth testing")
	_expect(is_equal_approx(float(snapshot.get("day_brightness", 0.0)), 1.0) and float(snapshot.get("night_brightness", 0.0)) >= 0.45 and float(snapshot.get("night_brightness", 0.0)) <= 0.55, "day and night brightness meet the fixed presentation range")
	_expect(int(snapshot.get("frontside_region_marker_visible_count", 0)) == 1 and int(snapshot.get("backside_region_marker_visible_count", -1)) == 0, "backside region markers are culled")
	_expect(int(snapshot.get("frontside_facility_visible_count", 0)) == 1 and int(snapshot.get("backside_facility_visible_count", -1)) == 0, "backside facility proxies are culled while the front proxy remains visible")
	_expect(int(snapshot.get("outer_orbit_decoration_count", -1)) == 0, "review component adds no outer orbit decoration")
	_expect(is_equal_approx(float(snapshot.get("zoom_min", 0.0)), 0.72) and is_equal_approx(float(snapshot.get("zoom_max", 0.0)), 1.85) and is_equal_approx(float(snapshot.get("zoom_step", 0.0)), 0.08), "zoom range and wheel step match the fixed contract")
	component.call("set_zoom_immediate", 99.0)
	_expect(is_equal_approx(float((component.call("debug_snapshot") as Dictionary).get("current_zoom", 0.0)), 1.85), "zoom clamps to 1.85")
	component.call("set_zoom_immediate", -4.0)
	_expect(is_equal_approx(float((component.call("debug_snapshot") as Dictionary).get("current_zoom", 0.0)), 0.72), "zoom clamps to 0.72")
	component.call("set_zoom_immediate", 1.0)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	component.call("_gui_input", wheel)
	var wheel_snapshot := component.call("debug_snapshot") as Dictionary
	_expect(is_equal_approx(float(wheel_snapshot.get("target_zoom", 0.0)), 1.08), "mouse wheel advances zoom by exactly 0.08")
	component.call("reset_view")
	component.call("_process", 1.0)
	_expect(is_equal_approx(float((component.call("debug_snapshot") as Dictionary).get("current_zoom", 0.0)), 1.0), "default view reset returns to zoom 1.0")
	component.call("set_solar_turn_normalized", 0.25)
	var solar_snapshot := component.call("debug_snapshot") as Dictionary
	_expect((solar_snapshot.get("sun_direction_world", Vector3.ZERO) as Vector3).is_normalized(), "public solar presentation can drive a normalized light direction without changing rules")
	_expect(not component.has_method("to_save_data") and not component.has_method("apply_save_data") and not bool(snapshot.get("camera_state_persisted", true)), "camera presentation state has no Save contract")
	component.queue_free()
	await process_frame


func _test_production_boundary() -> void:
	var component_source := FileAccess.get_file_as_string("res://scripts/presentation/commercial_art/planet/commercial_planet_review_component.gd")
	var scene_source := FileAccess.get_file_as_string(COMPONENT_SCENE_PATH)
	for forbidden in ["GameRuntimeCoordinator", "V06SaveOwnerRegistry", "RulesRng", "scripts/main.gd", "scenes/main.tscn", "PlanetBoard.tscn", "PlanetMapView.tscn"]:
		_expect(not component_source.contains(forbidden) and not scene_source.contains(forbidden), "component excludes production authority reference %s" % forbidden)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("COMMERCIAL PLANET ASSET CONTRACT: %s" % label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("COMMERCIAL_PLANET_ASSET_CONTRACT_TEST|status=%s|checks=%d|failures=%d|details=%s" % [status, _checks, _failures.size(), JSON.stringify(_failures)])
	quit(0 if _failures.is_empty() else 1)
