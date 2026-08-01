extends SceneTree

const REVIEW_SCENE_PATH := "res://scenes/tools/V072StarterBootstrapReview.tscn"
const REVIEW_SCRIPT_PATH := (
	"res://scripts/v072_simulation/v072_starter_bootstrap_review.gd"
)
const SIMULATOR_SCRIPT_PATH := (
	"res://scripts/v072_simulation/v072_deterministic_simulator.gd"
)
const REQUIRED_STATE_IDS := [
	"zero_six_color_assets",
	"deterministic_five_starter_hand",
	"starter_badge",
	"starter_zero_cost",
	"standard_l1_cost_one",
	"zero_asset_lock_gate",
	"starter_discard_reshuffle_identity",
	"starter_standard_l1_merge",
	"standard_l2_cost_two",
	"first_gdp_snapshot",
	"first_nonzero_asset_refresh",
	"standard_l1_affordability_transition",
]
const FORBIDDEN_SOURCE_TOKENS := [
	"GameRuntimeCoordinator",
	"GameSessionRuntimeController",
	"RandomNumberGenerator.new(",
	"RunRngService",
	"to_save_data",
	"apply_save_data",
	"/root/Main",
	"get_tree().current_scene",
	"assets/third_party/",
	"res://third_party/",
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
	await _test_scene_at_size(Vector2i(1280, 720))
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
			"Review excludes production or external token: %s" % token)
	_expect(source.contains("card.badge.starter") \
		and source.contains("card.frame.normal") \
		and source.contains("icon.asset.life") \
		and source.contains("ui.panel.primary"),
		"Review uses stable commercial-art semantic keys, including Starter badge")
	_expect(not source.contains("http://") and not source.contains("https://"),
		"Review introduces no external asset source")
	for path in PRODUCTION_SCAN_PATHS:
		_expect(not _source(path).contains("V072StarterBootstrapReview"),
			"production path does not connect the V0.7.2 Review: %s" % path)


func _test_scene_at_size(viewport_size: Vector2i) -> void:
	root.size = viewport_size
	var packed := load(REVIEW_SCENE_PATH) as PackedScene
	_expect(packed != null,
		"Review parse-loads at %dx%d" % [viewport_size.x, viewport_size.y])
	if packed == null:
		return
	var review := packed.instantiate() as Control
	_expect(review != null \
		and review.has_method("debug_snapshot") \
		and review.has_method("advance_bootstrap_preview") \
		and review.has_method("cycle_starter_card") \
		and review.has_method("merge_starter_with_standard"),
		"Review exposes detached bootstrap inspection controls")
	if review == null or not review.has_method("debug_snapshot"):
		if review != null:
			review.queue_free()
		return
	root.add_child(review)
	review.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	var snapshot := review.call("debug_snapshot") as Dictionary
	_expect(str(snapshot.get("review_id", "")) \
		== "v072.starter_bootstrap.review.v1" \
		and str(snapshot.get("constitution_id", "")) \
			== "space_syndicate.v072.complete" \
		and str(snapshot.get("ruleset_id", "")) == "v0.7.2" \
		and str(snapshot.get("constitution_status", "")) \
			== "FROZEN_HIGHEST_TARGET_CONSTITUTION" \
		and str(snapshot.get("approved_profile_id", "")) \
			== "V072_STARTER_FREE_FAST" \
		and str(snapshot.get("approved_profile_fingerprint", "")) \
			== "b8f684ab92b06fa44671c38d041ff08b9c1ea7c2950b094705e19192f0a70f48",
		"Review binds the approved V0.7.2 highest-target profile")
	_expect(bool(snapshot.get("detached_reference_only", false)) \
		and not bool(snapshot.get("production_runtime_connected", true)) \
		and int(snapshot.get("production_connection_count", -1)) == 0 \
		and int(snapshot.get("main_reference_count", -1)) == 0 \
		and int(snapshot.get("gameplay_mutation_count", -1)) == 0 \
		and int(snapshot.get("production_save_write_count", -1)) == 0 \
		and int(snapshot.get("production_rng_draw_count", -1)) == 0 \
		and int(snapshot.get("external_asset_source_count", -1)) == 0,
		"Review has zero production, Main, Save, RNG, and external-asset effects")
	_expect(not bool(snapshot.get("human_fun_proven", true)) \
		and bool(snapshot.get("human_test_required", false)),
		"Review preserves the human-test requirement")

	var assets := snapshot.get("initial_assets", {}) as Dictionary
	var remainders := snapshot.get("initial_fixed_remainders", {}) as Dictionary
	var all_zero := assets.size() == 6 and remainders.size() == 6
	for color in ["life", "energy", "industry", "technology", "commerce", "shipping"]:
		all_zero = all_zero \
			and int(assets.get(color, -1)) == 0 \
			and int(remainders.get(color, -1)) == 0
	_expect(bool(snapshot.get("asset_owner_exists_at_genesis", false)) \
		and bool(snapshot.get("asset_pool_initialized", false)) \
		and not bool(snapshot.get("asset_pool_absent", true)) \
		and all_zero \
		and str(snapshot.get("asset_ui_value", "")) == "0/6",
		"six-color Asset Owner exists with six initialized zero balances and remainders")

	var opening_ids := snapshot.get("opening_hand_definition_ids", []) as Array
	var unique_ids: Array = []
	for definition_id in opening_ids:
		if not unique_ids.has(definition_id):
			unique_ids.append(definition_id)
	_expect(int(snapshot.get("opening_hand_count", 0)) == 5 \
		and int(snapshot.get("opening_hand_starter_count", 0)) == 5 \
		and int(snapshot.get("opening_asset_affordable_count", 0)) == 5 \
		and int(snapshot.get("opening_legal_target_count", 0)) >= 1 \
		and unique_ids.size() == 5,
		"fixed shuffle presents five unique, affordable, legal Starter cards")
	for definition_id in opening_ids:
		_expect(str(definition_id).begins_with("starter.facility.") \
			and str(definition_id).ends_with(".rank_1"),
			"opening card uses a stable Starter definition: %s" % definition_id)
	_expect(str(snapshot.get("starter_badge_asset_key", "")) \
		== "card.badge.starter" \
		and bool(snapshot.get("starter_badge_key_used", false)) \
		and (snapshot.get("semantic_asset_keys_used", []) as Array).has(
			"card.badge.starter"
		), "Starter presentation uses the stable card.badge.starter semantic key")

	_expect(str(snapshot.get("starter_origin_class", "")) == "starter_bootstrap" \
		and str(snapshot.get("starter_asset_cost_profile", "")) \
			== "starter_zero_asset" \
		and int(snapshot.get("starter_asset_cost", -1)) == 0 \
		and bool(snapshot.get("starter_lock_accepted_at_zero_assets", false)) \
		and str(snapshot.get("standard_l1_origin_class", "")) == "standard" \
		and int(snapshot.get("standard_l1_asset_cost", -1)) == 1 \
		and not bool(snapshot.get("standard_l1_lock_accepted_at_zero_assets", true)),
		"Review distinguishes free Starter from paid standard L1 at zero assets")
	_expect(int(snapshot.get("starter_track_spawn_count", -1)) == 0 \
		and int(snapshot.get("starter_creation_after_genesis_count", -1)) == 0,
		"Review creates no post-genesis or track Starter")

	var cycle := review.call("cycle_starter_card") as Dictionary
	_expect(bool(cycle.get("valid", false)) \
		and str(cycle.get("origin_class", "")) == "starter_bootstrap" \
		and str(cycle.get("asset_cost_profile", "")) == "starter_zero_asset" \
		and int(cycle.get("asset_cost_after_reshuffle", -1)) == 0 \
		and bool(cycle.get("starter_badge_after_reshuffle", false)),
		"Starter remains free and badged after discard and reshuffle")
	var merge := review.call("merge_starter_with_standard") as Dictionary
	var output := merge.get("output", {}) as Dictionary
	_expect(bool(merge.get("accepted", false)) \
		and bool(merge.get("starter_privilege_consumed", false)) \
		and str(output.get("definition_id", "")) \
			== "facility.factory.life.rank_2" \
		and str(output.get("origin_class", "")) == "standard" \
		and int(output.get("primary_asset_cost", -1)) == 2 \
		and not bool(output.get("starter_badge", true)) \
		and int(snapshot.get("starter_privilege_inheritance_count", -1)) == 0,
		"voluntary cross merge consumes free privilege and emits paid standard L2")

	_expect(int(snapshot.get("preview_batch", 0)) == 1 \
		and int(snapshot.get("first_gdp_snapshot", -1)) == 0 \
		and int(snapshot.get("life_assets", -1)) == 0 \
		and not bool(snapshot.get("standard_l1_affordable_now", true)),
		"opening preview starts at zero GDP-derived assets with standard L1 locked")
	_expect(bool(review.call("advance_bootstrap_preview")),
		"detached bootstrap preview advances to the first economic refresh")
	var refreshed := review.call("debug_snapshot") as Dictionary
	_expect(int(refreshed.get("preview_batch", 0)) == 2 \
		and int(refreshed.get("first_gdp_snapshot", 0)) == 1 \
		and int(refreshed.get("first_nonzero_asset_refresh_batch", 0)) == 2 \
		and int(refreshed.get("life_assets", 0)) == 1 \
		and bool(refreshed.get("standard_l1_affordable_now", false)),
		"real Starter GDP projection yields first asset and unlocks standard L1 at batch 2")

	var displayed := refreshed.get("displayed_state_ids", []) as Array
	_expect(int(refreshed.get("required_state_count", 0)) == REQUIRED_STATE_IDS.size() \
		and int(refreshed.get("displayed_state_count", 0)) == REQUIRED_STATE_IDS.size(),
		"Review displays the complete V0.7.2 bootstrap state set")
	for state_id in REQUIRED_STATE_IDS:
		_expect(displayed.has(state_id), "Review displays state: %s" % state_id)

	var asset_metadata_count := 0
	var starter_badge_metadata_count := 0
	for node in _all_descendants(review):
		if not node.has_meta("asset_key"):
			continue
		asset_metadata_count += 1
		var asset_key := str(node.get_meta("asset_key"))
		starter_badge_metadata_count += 1 if asset_key == "card.badge.starter" else 0
		_expect(not asset_key.is_empty() \
			and not asset_key.contains("/") \
			and not asset_key.contains("\\") \
			and not asset_key.contains("third_party"),
			"visual node uses a stable semantic asset key: %s" % asset_key)
	_expect(asset_metadata_count >= 20 and starter_badge_metadata_count == 5,
		"Review surfaces stable metadata and one Starter badge for every opening card")

	var scroll := review.get_node_or_null("SafeMargin/Rows/ReviewScroll") as ScrollContainer
	var sections := review.get_node_or_null(
		"SafeMargin/Rows/ReviewScroll/Sections"
	) as Control
	var logical_size := root.get_visible_rect().size
	var layout_ready := review.size.x >= logical_size.x - 1.0 \
		and review.size.y >= logical_size.y - 1.0 \
		and scroll != null and scroll.size.x > 0.0 and scroll.size.y > 0.0 \
		and sections != null and sections.size.x > 0.0 \
		and sections.get_combined_minimum_size().y > 0.0 \
		and sections.size.x <= scroll.size.x + 2.0
	_expect(layout_ready,
		"Review keeps a non-overlapping scroll layout at %dx%d" % [
			viewport_size.x,
			viewport_size.y,
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
	push_error("V072_STARTER_BOOTSTRAP_REVIEW_TEST: %s" % message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V072_STARTER_BOOTSTRAP_REVIEW_TEST|status=%s|checks=%d|failures=%d" % [
		status,
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		print("V072_STARTER_BOOTSTRAP_REVIEW_TEST|first_failure=%s" % _failures[0])
	quit(_failures.size())
