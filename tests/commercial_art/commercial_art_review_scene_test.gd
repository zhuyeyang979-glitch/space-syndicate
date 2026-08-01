extends SceneTree

const REVIEW_SCENE_PATH := "res://scenes/tools/CommercialArtIntegrationReview.tscn"
const REVIEW_SCRIPT_PATH := "res://scripts/tools/commercial_art_integration_review.gd"
const BADGE_SCRIPT_PATH := "res://scripts/tools/commercial_art_review_asset_badge.gd"
const PLANET_COMPONENT_PATH := "res://scenes/tools/commercial_art/components/planet/CommercialPlanetReviewComponent.tscn"
const PRODUCTION_SCAN_PATHS: Array[String] = [
	"res://scenes/main.tscn",
	"res://scripts/main.gd",
	"res://scenes/ui/GameScreen.tscn",
	"res://scenes/ui/table/PlayerCardDock.tscn",
	"res://scenes/ui/PlanetBoard.tscn",
	"res://scenes/ui/PlanetMapView.tscn",
]
const FORBIDDEN_REVIEW_SOURCE_TOKENS: Array[String] = [
	"assets/third_party/commercial/",
	"GameRuntimeCoordinator",
	"GameSessionRuntimeController",
	"RandomNumberGenerator.new(",
	"RunRngService",
	"FileAccess.open(",
	"to_save_data",
	"apply_save_data",
	"/root/Main",
	"get_tree().current_scene",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_static_boundary()
	await _test_scene_at_size(Vector2i(1366, 768))
	await _test_scene_at_size(Vector2i(1920, 1080))
	_finish()


func _test_static_boundary() -> void:
	for path in [REVIEW_SCENE_PATH, REVIEW_SCRIPT_PATH, BADGE_SCRIPT_PATH, PLANET_COMPONENT_PATH]:
		_expect(ResourceLoader.exists(path) or FileAccess.file_exists(path), "review dependency exists: %s" % path)
	var review_source := _source(REVIEW_SCENE_PATH) + "\n" + _source(REVIEW_SCRIPT_PATH) + "\n" + _source(BADGE_SCRIPT_PATH)
	for token in FORBIDDEN_REVIEW_SOURCE_TOKENS:
		_expect(not review_source.contains(token), "review source excludes authority/vendor token: %s" % token)
	_expect(review_source.contains("CardIllustrationCatalogResource") == false \
		and review_source.contains("resource_for_asset_key") \
		and review_source.contains("presentation_key_for_card") \
		and review_source.contains("texture_for_key"),
		"review uses the catalog API boundary without a second catalog class")
	_expect(_source(REVIEW_SCENE_PATH).contains(PLANET_COMPONENT_PATH),
		"review scene reuses the Agent3 planet Review component")
	for path in PRODUCTION_SCAN_PATHS:
		_expect(not _source(path).contains("CommercialArtIntegrationReview"),
			"production path does not connect the Review scene: %s" % path)


func _test_scene_at_size(viewport_size: Vector2i) -> void:
	root.size = viewport_size
	var packed := load(REVIEW_SCENE_PATH) as PackedScene
	_expect(packed != null, "Review scene parse-loads at %dx%d" % [viewport_size.x, viewport_size.y])
	if packed == null:
		return
	var review := packed.instantiate() as Control
	_expect(review != null and review.get_script() != null \
		and review.has_method("debug_snapshot") \
		and review.has_method("set_interaction_preview_state") \
		and review.has_method("preview_audio_asset"),
		"Review scene instantiates with its required script API")
	if review == null:
		return
	if review.get_script() == null or not review.has_method("debug_snapshot") \
			or not review.has_method("set_interaction_preview_state") \
			or not review.has_method("preview_audio_asset"):
		review.queue_free()
		return
	root.add_child(review)
	review.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	var snapshot := review.call("debug_snapshot") as Dictionary
	_expect(str(snapshot.get("review_id", "")) == "commercial_art.integration.review.v1" \
		and bool(snapshot.get("presentation_only", false)),
		"Review identifies itself as presentation-only")
	_expect(int(snapshot.get("required_asset_key_count", -1)) == 42 \
		and int(snapshot.get("resolved_asset_key_count", -1)) + int(snapshot.get("missing_asset_key_count", -1)) == 42,
		"exactly 42 stable asset keys resolve or receive an explicit missing gate")
	_expect(int(snapshot.get("six_color_icon_count", -1)) == 6 \
		and int(snapshot.get("card_frame_and_back_count", -1)) == 4 \
		and int(snapshot.get("interaction_state_count", -1)) == 6,
		"six-color, card frame/back, and interaction state coverage is complete")
	_expect(int(snapshot.get("facility_slot_count", -1)) == 4 \
		and int(snapshot.get("monster_slot_count", -1)) == 6 \
		and int(snapshot.get("military_slot_count", -1)) == 4 \
		and int(snapshot.get("shipping_slot_count", -1)) == 3,
		"facility, monster, military, and shipping Review coverage is complete")
	_expect(int(snapshot.get("font_sample_count", -1)) == 3 \
		and int(snapshot.get("audio_control_count", -1)) == 10 \
		and int(snapshot.get("credits_section_count", -1)) == 4 \
		and int(snapshot.get("credits_entry_count", -1)) == 15 \
		and int(snapshot.get("credits_placeholder_count", -1)) == 0 \
		and bool(snapshot.get("credits_data_ready", false)),
		"font, audio control, and canonical Credits coverage is complete")
	_expect(not bool(snapshot.get("creates_session", true)) \
		and not bool(snapshot.get("writes_save", true)) \
		and int(snapshot.get("rng_draw_count", -1)) == 0 \
		and int(snapshot.get("gameplay_mutation_count", -1)) == 0 \
		and int(snapshot.get("production_connection_count", -1)) == 0 \
		and int(snapshot.get("main_reference_count", -1)) == 0,
		"Review creates no Session, Save, RNG, gameplay mutation, production connection, or Main reference")
	var planet := snapshot.get("planet", {}) as Dictionary
	_expect(bool(planet.get("presentation_only", false)) \
		and bool(planet.get("planet_opaque", false)) \
		and is_equal_approx(float(planet.get("planet_alpha", 0.0)), 1.0) \
		and bool(planet.get("back_face_culling", false)) \
		and bool(planet.get("depth_test", false)) \
		and int(planet.get("backside_region_marker_visible_count", -1)) == 0 \
		and int(planet.get("backside_facility_visible_count", -1)) == 0 \
		and int(planet.get("outer_orbit_decoration_count", -1)) == 0,
		"reused planet component proves opacity, depth, backside culling, and no outer orbit")
	_expect(is_equal_approx(float(planet.get("zoom_min", 0.0)), 0.72) \
		and is_equal_approx(float(planet.get("zoom_max", 0.0)), 1.85) \
		and is_equal_approx(float(planet.get("zoom_step", 0.0)), 0.08) \
		and not bool(planet.get("camera_state_persisted", true)),
		"planet zoom contract is presentation-local and exact")
	_expect(bool(review.call("set_interaction_preview_state", "hover")), "hover preview state applies")
	await create_timer(0.14).timeout
	var hover_snapshot := review.call("debug_snapshot") as Dictionary
	_expect(str(hover_snapshot.get("active_interaction_state", "")) == "hover", "hover state is observable without gameplay mutation")
	_expect(bool(review.call("set_interaction_preview_state", "drag")), "drag preview state applies")
	await create_timer(0.13).timeout
	var drag_snapshot := review.call("debug_snapshot") as Dictionary
	_expect(str(drag_snapshot.get("active_interaction_state", "")) == "drag" \
		and int(drag_snapshot.get("rng_draw_count", -1)) == 0,
		"drag preview remains presentation-only and RNG-free")
	_expect(not bool(review.call("preview_audio_asset", "audio.unlisted")),
		"audio preview fails closed for an unlisted/missing stable key")
	var scroll := review.get_node_or_null("SafeMargin/ReviewRows/ReviewScroll") as ScrollContainer
	var sections := review.get_node_or_null("SafeMargin/ReviewRows/ReviewScroll/Sections") as Control
	var logical_viewport_size := root.get_visible_rect().size
	var layout_ready := review.size.x >= logical_viewport_size.x - 1.0 \
		and review.size.y >= logical_viewport_size.y - 1.0 \
		and scroll != null and scroll.size.x > 0.0 and scroll.size.y > 0.0 \
		and sections != null and sections.size.x > 0.0 \
		and sections.get_combined_minimum_size().y > scroll.size.y
	var sections_min := sections.get_combined_minimum_size() if sections != null else Vector2.ZERO
	var scroll_size := scroll.size if scroll != null else Vector2.ZERO
	_expect(layout_ready,
		"Review uses a nonzero responsive scroll layout at %dx%d | logical=%s review=%s scroll=%s sections=%s min=%s" % [
			viewport_size.x, viewport_size.y, logical_viewport_size, review.size, scroll_size,
			sections.size if sections != null else Vector2.ZERO, sections_min,
		])
	root.remove_child(review)
	review.queue_free()
	await process_frame


func _source(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("COMMERCIAL_ART_REVIEW_SCENE_TEST: %s" % message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("COMMERCIAL_ART_REVIEW_SCENE_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	if not _failures.is_empty():
		print("COMMERCIAL_ART_REVIEW_SCENE_TEST|first_failure=%s" % _failures[0])
	quit(_failures.size())
