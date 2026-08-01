extends SceneTree

const REVIEW_SCENE_PATH := "res://scenes/tools/V071RuleConsistencyReview.tscn"
const REVIEW_SCRIPT_PATH := (
	"res://scripts/v071_simulation/v071_rule_consistency_review.gd"
)
const SIMULATOR_SCRIPT_PATH := (
	"res://scripts/v071_simulation/v071_deterministic_simulator.gd"
)
const REQUIRED_STATE_IDS := [
	"unified_track",
	"locked_replacement",
	"lead_batch_timer",
	"color_cycle_batch_timer",
	"player_private_lead_notice",
	"ai_private_lead_notice",
	"personal_dbg_zones",
	"minimum_five_merge_rejection",
	"commodity_batch_availability",
	"invalid_target_refund_receipt",
	"six_color_refresh_cap",
	"maintenance_timeout",
	"anonymous_resolution",
	"victory_pending_tail",
]
const FORBIDDEN_SOURCE_TOKENS := [
	"GameRuntimeCoordinator",
	"GameSessionRuntimeController",
	"RandomNumberGenerator.new(",
	"RunRngService",
	"FileAccess.open(",
	"to_save_data",
	"apply_save_data",
	"/root/Main",
	"get_tree().current_scene",
	"assets/third_party/",
]
const PRODUCTION_SCAN_PATHS := [
	"res://scenes/main.tscn",
	"res://scripts/main.gd",
	"res://scenes/runtime/GameRuntimeCoordinator.tscn",
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
	for path in [REVIEW_SCENE_PATH, REVIEW_SCRIPT_PATH, SIMULATOR_SCRIPT_PATH]:
		_expect(ResourceLoader.exists(path) or FileAccess.file_exists(path),
			"detached Review dependency exists: %s" % path)
	var source := _source(REVIEW_SCENE_PATH) + "\n" \
		+ _source(REVIEW_SCRIPT_PATH) + "\n" \
		+ _source(SIMULATOR_SCRIPT_PATH)
	for token in FORBIDDEN_SOURCE_TOKENS:
		_expect(not source.contains(token),
			"Review and simulator exclude production/vendor token: %s" % token)
	_expect(source.contains("resource_for_asset_key") \
		and source.contains("icon.asset.life") \
		and source.contains("card.frame.normal") \
		and source.contains("card.frame.commodity"),
		"Review consumes stable semantic asset keys through the existing Catalog API")
	_expect(not source.contains("res://third_party/") \
		and not source.contains("quaternius") \
		and not source.contains("kenney"),
		"Review contains no third-party path or filename")
	for path in PRODUCTION_SCAN_PATHS:
		_expect(not _source(path).contains("V071RuleConsistencyReview"),
			"production path does not connect the V0.7.1 Review: %s" % path)


func _test_scene_at_size(viewport_size: Vector2i) -> void:
	root.size = viewport_size
	var packed := load(REVIEW_SCENE_PATH) as PackedScene
	_expect(packed != null, "Review parse-loads at %dx%d" % [viewport_size.x, viewport_size.y])
	if packed == null:
		return
	var review := packed.instantiate() as Control
	_expect(review != null and review.has_method("debug_snapshot") \
		and review.has_method("select_profile") \
		and review.has_method("select_player_count") \
		and review.has_method("advance_preview_batch"),
		"Review exposes its detached inspection API")
	if review == null or not review.has_method("debug_snapshot"):
		if review != null:
			review.queue_free()
		return
	root.add_child(review)
	review.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	var snapshot := review.call("debug_snapshot") as Dictionary
	_expect(str(snapshot.get("review_id", "")) == "v071.rule_consistency.review.v1" \
		and str(snapshot.get("candidate_status", "")) \
			== "CANDIDATE_NOT_HIGHEST_AUTHORITY" \
		and bool(snapshot.get("detached_reference_only", false)),
		"Review declares detached candidate authority status")
	_expect(not bool(snapshot.get("production_runtime_connected", true)) \
		and int(snapshot.get("production_connection_count", -1)) == 0 \
		and int(snapshot.get("main_reference_count", -1)) == 0 \
		and int(snapshot.get("gameplay_mutation_count", -1)) == 0 \
		and int(snapshot.get("save_write_count", -1)) == 0 \
		and int(snapshot.get("production_rng_draw_count", -1)) == 0,
		"Review has zero production, Main, gameplay, Save, and production-RNG effects")
	_expect(not bool(snapshot.get("human_fun_proven", true)) \
		and bool(snapshot.get("human_test_still_required", false)),
		"Review preserves the human-test requirement")
	_expect(bool(snapshot.get("catalog_key_registry_ready", false)) \
		and int(snapshot.get("required_asset_key_count", 0)) == 25 \
		and int(snapshot.get("registered_asset_key_count", -1)) == 25 \
		and int(snapshot.get("missing_asset_key_count", -1)) == 0,
		"all 25 stable keys are registered by the existing Catalog")
	_expect(int(snapshot.get("resolved_asset_key_count", -1)) \
		+ int(snapshot.get("fallback_visual_count", -1)) == 25 \
		and int(snapshot.get("unresolved_resource_count", -1)) \
			== int(snapshot.get("fallback_visual_count", -2)),
		"each registered key has either an imported resource or a local visual fallback")
	_expect(int(snapshot.get("external_asset_source_count", -1)) == 0,
		"Review adds no external asset source")
	var displayed := snapshot.get("displayed_state_ids", []) as Array
	_expect(int(snapshot.get("required_state_count", 0)) == REQUIRED_STATE_IDS.size() \
		and int(snapshot.get("displayed_state_count", 0)) == REQUIRED_STATE_IDS.size(),
		"Review displays the full required state set")
	for state_id in REQUIRED_STATE_IDS:
		_expect(displayed.has(state_id), "Review displays state: %s" % state_id)
	_expect(not bool(snapshot.get("track_replacement_claimable_same_tick", true)) \
		and int(snapshot.get("normal_deck_minimum_total_card_count", 0)) == 5 \
		and int(snapshot.get("normal_track_spawn_level", 0)) == 1 \
		and int(snapshot.get("commodity_track_spawn_level", 0)) == 1,
		"Review exposes replacement lock, minimum five, and level-one supply")
	_expect(bool(snapshot.get("player_self_is_current_lead", false)) \
		and str(snapshot.get("player_self_influence_class", "")) == "double" \
		and bool(snapshot.get("ai_self_is_current_lead", false)) \
		and str(snapshot.get("ai_self_influence_class", "")) == "double",
		"Player and AI receive semantically equal own-lead facts")
	_expect(int(snapshot.get("ai_other_lead_identity_exposure_count", -1)) == 0 \
		and int(snapshot.get("hidden_order_exposure_count", -1)) == 0 \
		and int(snapshot.get("anonymous_resolution_owner_identity_exposure_count", -1)) == 0,
		"AI and public resolution expose no other lead or hidden order")
	_expect(not bool(snapshot.get("solar_render_is_core_owner", true)),
		"Review presentation never owns solar rules")

	_expect(bool(review.call("select_profile", "V071_CANDIDATE_B_STRATEGIC")) \
		and bool(review.call("select_player_count", 8)),
		"Review switches profiles and player counts without a match")
	var before_batch := int((review.call("debug_snapshot") as Dictionary).get(
		"completed_batch_count", 0
	))
	_expect(bool(review.call("advance_preview_batch")),
		"Review advances its local presentation cursor")
	var after_snapshot := review.call("debug_snapshot") as Dictionary
	_expect(int(after_snapshot.get("completed_batch_count", 0)) == before_batch + 1 \
		and str(after_snapshot.get("selected_profile_id", "")) \
			== "V071_CANDIDATE_B_STRATEGIC" \
		and int(after_snapshot.get("selected_player_count", 0)) == 8,
		"local cursor update preserves selected profile/player count")

	var asset_metadata_count := 0
	for node in _all_descendants(review):
		if not node.has_meta("asset_key"):
			continue
		asset_metadata_count += 1
		var asset_key := str(node.get_meta("asset_key"))
		_expect(not asset_key.is_empty() \
			and not asset_key.contains("/") \
			and not asset_key.contains("\\") \
			and not asset_key.contains("third_party"),
			"visual node uses stable asset key: %s" % asset_key)
	_expect(asset_metadata_count >= 22,
		"Review surfaces stable asset-key metadata across its visual states")

	var scroll := review.get_node_or_null("SafeMargin/Rows/ReviewScroll") as ScrollContainer
	var sections := review.get_node_or_null(
		"SafeMargin/Rows/ReviewScroll/Sections"
	) as Control
	var logical_viewport_size := root.get_visible_rect().size
	var layout_ready := review.size.x >= logical_viewport_size.x - 1.0 \
		and review.size.y >= logical_viewport_size.y - 1.0 \
		and scroll != null and scroll.size.x > 0.0 and scroll.size.y > 0.0 \
		and sections != null and sections.size.x > 0.0 \
		and sections.get_combined_minimum_size().y > 0.0 \
		and sections.size.x <= scroll.size.x + 2.0
	_expect(layout_ready,
		"Review uses a non-overlapping scroll layout at %dx%d | logical=%s review=%s scroll=%s sections=%s minimum=%s" % [
			viewport_size.x,
			viewport_size.y,
			logical_viewport_size,
			review.size,
			scroll.size if scroll != null else Vector2.ZERO,
			sections.size if sections != null else Vector2.ZERO,
			sections.get_combined_minimum_size() if sections != null else Vector2.ZERO,
		])
	root.remove_child(review)
	review.queue_free()
	await process_frame


func _all_descendants(root_node: Node) -> Array[Node]:
	var result: Array[Node] = []
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child: Node in current.get_children():
			result.append(child)
			pending.append(child)
	return result


func _source(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("V071_RULE_CONSISTENCY_REVIEW_TEST: %s" % message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V071_RULE_CONSISTENCY_REVIEW_TEST|status=%s|checks=%d|failures=%d" % [
		status,
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		print("V071_RULE_CONSISTENCY_REVIEW_TEST|first_failure=%s" % _failures[0])
	quit(_failures.size())
