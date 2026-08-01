extends SceneTree

const REPORT_PATH := "res://reports/asset_intake/presentation_catalog_boundary_agent6.json"
const CATALOG_RESOURCE_SCRIPT := "res://scripts/presentation/card_illustration_catalog_resource.gd"
const CATALOG_SERVICE_SCRIPT := "res://scripts/presentation/card_illustration_catalog.gd"
const CATALOG_RESOURCE := "res://resources/presentation/alpha01_card_illustration_catalog.tres"
const CATALOG_SCENE := "res://scenes/runtime/CardIllustrationCatalog.tscn"
const CONTENT_MANIFEST_SCRIPT := "res://resources/content/alpha01/alpha01_content_manifest.gd"
const CONTENT_MANIFEST_RESOURCE := "res://resources/content/alpha01/alpha01_content_manifest.tres"
const AUDIO_REGISTRY_SCRIPT := "res://scripts/audio/audio_event_registry.gd"
const AUDIO_EVENT_MAP := "res://data/audio/audio_event_map.json"
const DOCK_SCRIPT := "res://scripts/ui/table/player_card_dock.gd"
const DOCK_SCENE := "res://scenes/ui/table/PlayerCardDock.tscn"
const DOCK_PROJECTION := "res://scripts/presentation/player_card_dock_projection_v1.gd"
const GAME_SCREEN_SCRIPT := "res://scripts/ui/game_screen.gd"
const GAME_SCREEN_SCENE := "res://scenes/ui/GameScreen.tscn"
const PLANET_BOARD_SCRIPT := "res://scripts/ui/planet_board.gd"
const PLANET_BOARD_SCENE := "res://scenes/ui/PlanetBoard.tscn"
const PLANET_MAP_SCRIPT := "res://scripts/ui/planet_map_view.gd"
const PLANET_MAP_SCENE := "res://scenes/ui/PlanetMapView.tscn"
const PLANET_GLOBE_SCRIPT := "res://scripts/ui/map/planet_globe_backdrop.gd"
const SOLAR_CAMERA_SCRIPT := "res://scripts/ui/map/planet_solar_camera_controller.gd"
const GAME_THEME := "res://themes/GameTheme.tres"
const MENU_ROOT_SCRIPT := "res://scripts/ui/menu_root_lobby.gd"
const MENU_OVERLAY_SCRIPT := "res://scripts/ui/menu_overlay.gd"
const V07_REFERENCE_BENCH := "res://scenes/tools/SharedCommodityTrackThreeLayerSemanticsBench.tscn"

const REQUIRED_PRIMARY_KEYS: Array[String] = [
	"ui.panel.primary",
	"ui.panel.popup",
	"ui.button.primary",
	"icon.asset.life",
	"icon.asset.energy",
	"icon.asset.industry",
	"icon.asset.technology",
	"icon.asset.commerce",
	"icon.asset.shipping",
	"card.frame.normal",
	"card.frame.commodity",
	"card.frame.bound_action",
	"card.back.normal",
	"model.facility.factory.base",
	"model.facility.market.base",
	"model.facility.warehouse.base",
	"model.facility.starport.base",
	"model.monster.life",
	"model.monster.energy",
	"model.monster.industry",
	"model.monster.technology",
	"model.monster.commerce",
	"model.monster.shipping",
	"model.military.tier1",
	"model.military.tier2",
	"model.military.tier3",
	"model.military.tier4",
	"model.shipping.route_marker",
	"model.shipping.convoy",
	"model.shipping.starport_showcase",
	"audio.ui.hover",
	"audio.ui.confirm",
	"audio.card.lock",
	"audio.card.merge",
	"audio.asset.refresh",
	"music.menu",
	"music.gameplay",
	"music.crisis",
	"music.military",
	"font.body.zh",
	"font.body.ja",
	"font.display",
]
const REQUIRED_REFERENCE_FEATURES: Array[String] = [
	"six_color_asset_current_reserved_cost_shortage_ratio_and_settlement_values",
	"unified_card_track",
	"normal_dbg_draw_pile_and_discard_pile",
	"five_action_local_queue_ordering",
	"asset_reservation_and_lock_feedback",
	"anonymous_resolution_queue",
]
const PRODUCTION_V07_SCAN_PATHS: Array[String] = [
	"res://scenes/main.tscn",
	"res://scenes/ui/GameScreen.tscn",
	"res://scripts/main.gd",
	"res://scripts/ui/game_screen.gd",
	"res://scenes/runtime/GameRuntimeCoordinator.tscn",
	"res://scripts/runtime/game_runtime_coordinator.gd",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var report := _load_json(REPORT_PATH)
	_expect(not report.is_empty(), "machine-readable boundary report loads")
	if report.is_empty():
		_finish()
		return
	_test_report_contract(report)
	_test_existing_catalog_owner()
	_test_neighbor_owner_boundaries()
	_test_player_card_dock_boundary()
	_test_planet_presentation_boundary()
	_test_v07_reference_boundary(report)
	_test_menu_theme_boundary(report)
	_finish()


func _test_report_contract(report: Dictionary) -> void:
	_expect(int(report.get("schema_version", 0)) == 1 \
		and bool(report.get("audit_only", false)) \
		and not bool(report.get("network_access_used", true)) \
		and int(report.get("web_asset_search_count", -1)) == 0 \
		and int(report.get("asset_download_count", -1)) == 0,
		"report is an offline audit with no asset intake side effect")
	var runtime := _dictionary(report.get("runtime_boundary"))
	_expect(str(runtime.get("current_production_runtime_ruleset", "")) == "v0.6" \
		and str(runtime.get("target_development_constitution", "")) == "v0.7" \
		and bool(runtime.get("v07_semantic_kernel_on_main", false)) \
		and not bool(runtime.get("v07_player_presentation_connected_to_production", true)) \
		and not bool(runtime.get("full_v0_7_runtime_cutover", true)),
		"report states the truthful V0.6 production and isolated V0.7 kernel boundary")
	var owner := _dictionary(report.get("canonical_owner_decision"))
	_expect(str(owner.get("canonical_owner_id", "")) == "CardIllustrationCatalogResource" \
		and str(owner.get("service_owner_id", "")) == "CardIllustrationCatalog" \
		and str(owner.get("strategy", "")) == "extend_in_place_keep_compatibility_api" \
		and not bool(owner.get("second_catalog_allowed", true)),
		"one existing catalog is selected for in-place extension")
	var rows := _dictionary_rows(report.get("stable_asset_key_wiring"))
	var row_by_key: Dictionary = {}
	for row in rows:
		var key := str(row.get("asset_key", ""))
		_expect(not key.is_empty() and not row_by_key.has(key), "primary stable key is nonempty and unique: %s" % key)
		row_by_key[key] = row
		_expect(str(row.get("catalog_owner", "")) == "CardIllustrationCatalogResource",
			"%s resolves through the canonical owner" % key)
		_expect(not key.begins_with("res://") and not key.contains("\\") and key == key.to_lower(),
			"%s is an opaque normalized key rather than a resource path" % key)
	for key in REQUIRED_PRIMARY_KEYS:
		_expect(row_by_key.has(key), "report routes required primary key %s" % key)
	var supporting_keys: Dictionary = {}
	for group in _dictionary_rows(report.get("supporting_key_groups")):
		_expect(str(group.get("catalog_owner", "")) == "CardIllustrationCatalogResource",
			"supporting group %s uses the canonical owner" % str(group.get("group_id", "")))
		for key_variant in _array(group.get("asset_keys")):
			var key := str(key_variant)
			_expect(not row_by_key.has(key) and not supporting_keys.has(key),
				"supporting stable key is unique: %s" % key)
			supporting_keys[key] = true
	var reference_features: Dictionary = {}
	for row in _dictionary_rows(report.get("review_reference_only_connections")):
		reference_features[str(row.get("feature", ""))] = true
	for feature in REQUIRED_REFERENCE_FEATURES:
		_expect(reference_features.has(feature), "%s is explicitly Review/Reference-only" % feature)
	var invariants := _dictionary(report.get("architecture_invariants"))
	_expect(int(invariants.get("presentation_asset_catalog_owner_count", 0)) == 1 \
		and int(invariants.get("second_presentation_asset_catalog_count", -1)) == 0 \
		and int(invariants.get("runtime_network_asset_dependency_count", -1)) == 0 \
		and int(invariants.get("presentation_rng_draw_count", -1)) == 0 \
		and int(invariants.get("new_main_responsibility_count", -1)) == 0,
		"report freezes one local presentation owner with no network, RNG, or Main responsibility")


func _test_existing_catalog_owner() -> void:
	for path in [CATALOG_RESOURCE_SCRIPT, CATALOG_SERVICE_SCRIPT, CATALOG_RESOURCE, CATALOG_SCENE]:
		_expect(FileAccess.file_exists(path), "existing catalog artifact exists: %s" % path)
	var resource_source := _source(CATALOG_RESOURCE_SCRIPT)
	var service_source := _source(CATALOG_SERVICE_SCRIPT)
	var resource_text := _source(CATALOG_RESOURCE)
	var scene_text := _source(CATALOG_SCENE)
	_expect(resource_source.contains("class_name CardIllustrationCatalogResource") \
		and resource_source.contains("presentation_keys") \
		and resource_source.contains("rendered_textures") \
		and resource_source.contains("func texture_for_key") \
		and resource_source.contains("func presentation_profile_for_key"),
		"existing typed resource owns opaque presentation-key resource resolution")
	_expect(service_source.contains("class_name CardIllustrationCatalog") \
		and service_source.contains("\"read_only\": true") \
		and service_source.contains("\"presentation_only\": true") \
		and service_source.contains("\"mutates_gameplay\": false") \
		and service_source.contains("\"reads_main\": false"),
		"catalog service is explicitly read-only and presentation-only")
	_expect(resource_text.contains("script_class=\"CardIllustrationCatalogResource\"") \
		and scene_text.contains("res://resources/presentation/alpha01_card_illustration_catalog.tres"),
		"one scene binds the existing typed catalog resource")
	var presentation_catalog_class_count := 0
	for path in _gd_files_under("res://scripts/presentation"):
		var text := _source(path)
		presentation_catalog_class_count += text.count("class_name CardIllustrationCatalogResource")
	_expect(presentation_catalog_class_count == 1,
		"exactly one CardIllustrationCatalogResource class exists before extension")


func _test_neighbor_owner_boundaries() -> void:
	var manifest_source := _source(CONTENT_MANIFEST_SCRIPT) + "\n" + _source(CONTENT_MANIFEST_RESOURCE)
	_expect(not manifest_source.contains("assets/third_party") \
		and not manifest_source.contains("selected_commercial") \
		and not manifest_source.contains("presentation_keys") \
		and not manifest_source.contains("AudioStream") \
		and not manifest_source.contains("FontFile"),
		"Alpha content selection remains separate from commercial presentation resources")
	var audio_source := _source(AUDIO_REGISTRY_SCRIPT)
	var audio_map := _load_json(AUDIO_EVENT_MAP)
	_expect(audio_source.contains("class_name AudioEventRegistry") \
		and audio_source.contains("event_definition") \
		and audio_source.contains("supported_event_ids"),
		"AudioEventRegistry remains the event router")
	var audio_paths := 0
	for value_variant in audio_map.values():
		if value_variant is Dictionary:
			audio_paths += JSON.stringify(value_variant).count("res://")
	_expect(not audio_map.is_empty() and audio_paths == 0,
		"current audio router contains no direct resource paths or second asset catalog")


func _test_player_card_dock_boundary() -> void:
	var dock_source := _source(DOCK_SCRIPT)
	var dock_scene := _source(DOCK_SCENE)
	var projection_source := _source(DOCK_PROJECTION)
	var screen_source := _source(GAME_SCREEN_SCRIPT)
	var screen_scene := _source(GAME_SCREEN_SCENE)
	_expect(dock_scene.count("PlayerCardDock") >= 1 \
		and screen_scene.count("PlayerCardDock.tscn") == 1,
		"production owns exactly one PlayerCardDock surface")
	_expect(dock_source.count("game_action_offer_requested.emit") == 1 \
		and screen_source.count("player_card_dock.game_action_offer_requested.connect") == 1,
		"PlayerCardDock retains one Action Spine offer route")
	_expect(not dock_source.contains("/root/Main") \
		and not dock_source.contains("RandomNumberGenerator") \
		and not dock_source.contains("FileAccess.open") \
		and not dock_scene.contains("HandRack.tscn") \
		and not screen_scene.contains("HandRack.tscn"),
		"production Dock has no Main, RNG, Save, or retired HandRack fallback")
	_expect(projection_source.contains("CAPACITY_MODE_SHARED_V06") \
		and projection_source.contains("CAPACITY_MODE_INDEPENDENT_V07") \
		and projection_source.contains("RUNTIME_RULESET_V06") \
		and projection_source.contains("RUNTIME_RULESET_V07"),
		"typed Dock schema distinguishes V0.6 and V0.7 without claiming a V0.7 cutover")


func _test_planet_presentation_boundary() -> void:
	for path in [PLANET_BOARD_SCRIPT, PLANET_BOARD_SCENE, PLANET_MAP_SCRIPT, PLANET_MAP_SCENE, PLANET_GLOBE_SCRIPT, SOLAR_CAMERA_SCRIPT]:
		_expect(FileAccess.file_exists(path), "planet presentation artifact exists: %s" % path)
	var scene_source := _source(PLANET_MAP_SCENE)
	var map_source := _source(PLANET_MAP_SCRIPT)
	var globe_source := _source(PLANET_GLOBE_SCRIPT)
	var camera_source := _source(SOLAR_CAMERA_SCRIPT)
	_expect(scene_source.contains("PlanetGlobeBackdrop.tscn") \
		and scene_source.contains("PlanetOrbitGuide.tscn") \
		and scene_source.contains("PlanetSolarCameraController.tscn"),
		"audit identifies current globe, orbit decoration, and camera presentation nodes")
	_expect(globe_source.contains("\"planet_opaque\": true") \
		and globe_source.contains("\"planet_alpha\": 1.0") \
		and globe_source.contains("\"outer_orbit_decoration_count\": 0") \
		and globe_source.contains("ocean.a = 1.0") \
		and not globe_source.contains("_draw_table_ring"),
		"audit enforces an opaque planet with zero outer-orbit decoration")
	_expect(map_source.contains("set_solar_presentation_snapshot") \
		and camera_source.contains("consumes_public_snapshot_only") \
		and camera_source.contains("\"owns_save_state\": false") \
		and not camera_source.contains("RandomNumberGenerator.new("),
		"planet camera consumes public presentation data and owns no Save or RNG")


func _test_v07_reference_boundary(report: Dictionary) -> void:
	var reference := _dictionary(report.get("v07_reference_observation"))
	_expect(not bool(reference.get("existing_visual_reference_presentation_found", true)) \
		and str(reference.get("existing_reference_semantics_bench", "")) == V07_REFERENCE_BENCH,
		"report distinguishes the semantics bench from a visual production projection")
	var bench_source := _source(V07_REFERENCE_BENCH)
	_expect(bench_source.contains("shared_commodity_track_three_layer_semantics_bench.gd"),
		"V0.7 reference bench remains an isolated tool scene")
	var production_v07_import_count := 0
	for path in PRODUCTION_V07_SCAN_PATHS:
		production_v07_import_count += _source(path).count("res://scripts/v07_semantic/")
	_expect(production_v07_import_count == 0,
		"production Main, coordinator, and GameScreen have zero V0.7 semantic imports")


func _test_menu_theme_boundary(report: Dictionary) -> void:
	_expect(FileAccess.file_exists(GAME_THEME) \
		and _source(GAME_SCREEN_SCENE).contains("res://themes/GameTheme.tres"),
		"GameTheme is the existing production theme consumer")
	var menu_source := (_source(MENU_ROOT_SCRIPT) + "\n" + _source(MENU_OVERLAY_SCRIPT)).to_lower()
	_expect(not menu_source.contains("third-party assets") \
		and not menu_source.contains("licenses") \
		and not menu_source.contains("credits"),
		"audit truthfully records that no Credits/license surface exists yet")
	var gaps := _dictionary_rows(report.get("observed_gaps"))
	var has_credits_gap := false
	for gap in gaps:
		if str(gap.get("gap_id", "")) == "credits_surface_absent":
			has_credits_gap = true
	_expect(has_credits_gap, "report turns the absent Credits surface into an explicit second-phase action")


func _gd_files_under(root_path: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(root_path)
	if directory == null:
		return result
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if not directory.current_is_dir() and name.ends_with(".gd"):
			result.append("%s/%s" % [root_path, name])
		name = directory.get_next()
	directory.list_dir_end()
	return result


func _source(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(_source(path))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _dictionary_rows(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for row_variant in value as Array:
		if row_variant is Dictionary:
			result.append((row_variant as Dictionary).duplicate(true))
	return result


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("COMMERCIAL_ART_ARCHITECTURE_PREFLIGHT: %s" % message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("COMMERCIAL_ART_ARCHITECTURE_PREFLIGHT|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	if not _failures.is_empty():
		print("COMMERCIAL_ART_ARCHITECTURE_PREFLIGHT|first_failure=%s" % _failures[0])
	quit(_failures.size())
