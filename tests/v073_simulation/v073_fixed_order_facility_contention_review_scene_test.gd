extends SceneTree

const REVIEW_SCENE_PATH := (
	"res://scenes/tools/V073FixedOrderFacilityContentionReview.tscn"
)
const REVIEW_SCRIPT_PATH := (
	"res://scripts/v073_simulation/v073_fixed_order_facility_contention_review.gd"
)
const CORE_SCRIPT_PATH := (
	"res://scripts/v07_semantic/v073_fixed_order_facility_contention_core.gd"
)
const CATALOG_PATH := (
	"res://resources/presentation/alpha01_card_illustration_catalog.tres"
)
const REQUIRED_STATE_IDS := [
	"fixed_four_player_order",
	"layered_local_queues",
	"anonymous_global_queue",
	"shared_life_factory_target",
	"earlier_build_success",
	"later_build_fizzle",
	"full_asset_refund",
	"card_to_discard",
	"action_slot_consumed",
	"no_build_mode_conversion",
	"public_owner_anonymity",
	"auction_absent",
	"cash_order_mutation_absent",
	"save_restore_order_parity",
	"save_restore_fizzle_parity",
]
const EXPECTED_ACTION_ORDER := [
	"action.review.b1",
	"action.review.a1",
	"action.review.c1",
	"action.review.d1",
	"action.review.b2",
	"action.review.a2",
	"action.review.d2",
	"action.review.b3",
	"action.review.d3",
]
const FORBIDDEN_SOURCE_TOKENS := [
	"GameRuntimeCoordinator",
	"GameSessionRuntimeController",
	"RandomNumberGenerator.new(",
	"RunRngService",
	"V06SaveOwnerRegistry",
	"/root/Main",
	"get_tree().current_scene",
	"assets/third_party/",
	"res://third_party/",
	"V073InitiativeAuctionCore",
	"InitiativeBidIntent",
	"InitiativeBidReservation",
	"InitiativeAuctionReceipt",
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
	for path in [REVIEW_SCENE_PATH, REVIEW_SCRIPT_PATH, CORE_SCRIPT_PATH, CATALOG_PATH]:
		_expect(
			ResourceLoader.exists(path) or FileAccess.file_exists(path),
			"detached Review dependency exists: %s" % path
		)
	var source := _source(REVIEW_SCENE_PATH) + "\n" + _source(REVIEW_SCRIPT_PATH)
	for token in FORBIDDEN_SOURCE_TOKENS:
		_expect(not source.contains(token), "Review excludes %s" % token)
	_expect(
		source.contains("ui.panel.primary")
			and source.contains("card.frame.normal")
			and source.contains("icon.board.lock")
			and source.contains("icon.board.discard_pile")
			and source.contains("icon.asset.life"),
		"Review uses existing commercial-art semantic keys"
	)
	_expect(
		not _source("res://scenes/main.tscn").contains(
			"V073FixedOrderFacilityContentionReview"
		)
			and not _source("res://scripts/main.gd").contains(
				"v073_fixed_order_facility_contention_review"
			),
		"Review has no production Main wiring"
	)
	var catalog_keys := _packed_string_array(
		_source(CATALOG_PATH),
		"stable_asset_keys"
	)
	for asset_key in [
		"ui.panel.primary",
		"card.frame.normal",
		"icon.board.lock",
		"icon.board.discard_pile",
		"icon.board.shuffle",
		"icon.asset.life",
	]:
		_expect(catalog_keys.has(asset_key), "catalog registers %s" % asset_key)


func _test_scene_at_size(viewport_size: Vector2i) -> void:
	root.content_scale_size = viewport_size
	root.size = viewport_size
	var packed := load(REVIEW_SCENE_PATH) as PackedScene
	_expect(packed != null, "Review scene loads at %dx%d" % [viewport_size.x, viewport_size.y])
	if packed == null:
		return
	var review := packed.instantiate() as Control
	root.add_child(review)
	await process_frame
	await process_frame
	var snapshot := review.call("debug_snapshot") as Dictionary
	_expect(
		snapshot.get("review_id") == "v073.fixed_order_facility_contention.review.v1"
			and snapshot.get("constitution_id") == "space_syndicate.v073.complete"
			and snapshot.get("ruleset_id") == "v0.7.3"
			and snapshot.get("profile_id")
				== "V073_STARTER_FREE_FIXED_ORDER_CONTENTION",
		"Review binds the frozen V0.7.3 identity"
	)
	_expect(
		snapshot.get("detached_reference_only") == true
			and snapshot.get("production_runtime_connected") == false
			and int(snapshot.get("production_connection_count", -1)) == 0
			and int(snapshot.get("v06_mutation_count", -1)) == 0
			and int(snapshot.get("dual_write_count", -1)) == 0
			and int(snapshot.get("main_reference_count", -1)) == 0,
		"Review remains detached with zero production, V0.6, dual-write, or Main links"
	)
	_expect(
		snapshot.get("resolution_order_mode") == "fixed_hidden_round_robin"
			and snapshot.get("resolution_order_source")
				== "frozen_hidden_lead_order_at_batch_lock"
			and int(snapshot.get("resolution_order_writer_count", 0)) == 1
			and int(snapshot.get("resolution_order_modifier_count", -1)) == 0,
		"Review has one fixed order writer and no modifier"
	)
	_expect(
		snapshot.get("frozen_batch_turn_order")
			== ["player.b", "player.a", "player.c", "player.d"]
			and snapshot.get("player_local_queue_sizes") == {
				"player.a": 2,
				"player.b": 3,
				"player.c": 1,
				"player.d": 3,
			},
		"four players retain the expected fixed order and one-to-three local cards"
	)
	_expect(
		snapshot.get("authority_action_order") == EXPECTED_ACTION_ORDER
			and snapshot.get("local_action_index_sequence")
				== [0, 0, 0, 0, 1, 1, 1, 2, 2],
		"global queue is built one card per player in local-action layers"
	)
	var public_queue := snapshot.get("anonymous_global_queue", []) as Array
	_expect(
		int(snapshot.get("anonymous_global_queue_count", 0)) == 9
			and public_queue.size() == 9
			and int(snapshot.get("public_queue_owner_field_count", -1)) == 0
			and snapshot.get("complete_hidden_order_disclosed") == false,
		"public queue remains anonymous and does not disclose the hidden order"
	)
	for entry_variant in public_queue:
		var entry := entry_variant as Dictionary
		_expect(
			not entry.has("actor_id")
				and not entry.has("owner_id")
				and not entry.has("player_id")
				and not entry.has("seat_id"),
			"anonymous queue row has no direct owner field"
		)
	_expect(
		snapshot.get("contested_slot_id") == "slot.region.alpha.factory.life"
			and snapshot.get("facility_action_mode") == "BUILD_NEW",
		"both contenders prebind the exact region/type/industry BUILD_NEW slot"
	)
	_expect(
		snapshot.get("earlier_build_accepted") == true
			and snapshot.get("earlier_build_outcome") == "facility_action_resolved"
			and snapshot.get("earlier_facility_created") == true,
		"earlier fixed-order BUILD_NEW creates the Life factory"
	)
	_expect(
		snapshot.get("later_build_accepted") == true
			and snapshot.get("later_build_outcome") == "facility_action_fizzled"
			and snapshot.get("later_build_reason")
				== "facility_target_invalid_slot_occupied"
			and snapshot.get("later_public_reason")
				== "facility_slot_occupied_by_earlier_action",
		"later BUILD_NEW Fizzles with the typed occupied-slot reason"
	)
	_expect(
		snapshot.get("fizzle_asset_reservation_released") == true
			and int(snapshot.get("fizzle_life_asset_release", -1)) == 1
			and snapshot.get("fizzle_card_destination") == "discard"
			and snapshot.get("fizzle_action_slot_refunded") == false,
		"Fizzle refunds assets, discards the card, and consumes the action slot"
	)
	_expect(
		snapshot.get("target_reselected") == false
			and snapshot.get("fizzle_facility_created") == false
			and snapshot.get("fizzle_facility_upgraded") == false
			and snapshot.get("fizzle_facility_repaired") == false
			and int(snapshot.get("build_to_upgrade_auto_conversion_count", -1)) == 0
			and int(snapshot.get("build_to_repair_auto_conversion_count", -1)) == 0,
		"failed BUILD neither reselects nor converts into upgrade or repair"
	)
	_expect(
		int(snapshot.get("initiative_auction_core_count", -1)) == 0
			and int(snapshot.get("initiative_bid_save_field_count", -1)) == 0
			and int(snapshot.get("initiative_bid_ui_surface_count", -1)) == 0
			and int(snapshot.get("ai_initiative_bid_policy_count", -1)) == 0
			and int(snapshot.get("initiative_cash_spent", -1)) == 0
			and snapshot.get("cash_can_change_resolution_order") == false,
		"Review has zero bidding Core, Save, UI, AI, or cash effects"
	)
	_expect(
		snapshot.get("save_state_created") == true
			and snapshot.get("restore_green") == true
			and snapshot.get("save_restore_final_fingerprint_parity") == true
			and snapshot.get("final_resolution_status") == "resolved"
			and int(snapshot.get("final_resolution_receipt_count", 0)) == 9
			and snapshot.get("all_receipts_exact_once") == true
			and int(snapshot.get("contention_fizzle_receipt_count", 0)) == 1,
		"Save/Restore preserves order and produces one exact-once contention Fizzle"
	)
	_expect(
		int(snapshot.get("missing_asset_key_count", -1)) == 0
			and int(snapshot.get("external_asset_source_count", -1)) == 0,
		"Review uses only registered local commercial-art keys"
	)
	_expect(
		snapshot.get("human_fun_proven") == false
			and snapshot.get("human_test_required") == true,
		"Review does not claim human fun"
	)
	var displayed := snapshot.get("displayed_state_ids", []) as Array
	_expect(
		int(snapshot.get("required_state_count", 0)) == REQUIRED_STATE_IDS.size()
			and int(snapshot.get("displayed_state_count", 0)) == REQUIRED_STATE_IDS.size(),
		"Review displays the complete V0.7.3 contention state set"
	)
	for state_id in REQUIRED_STATE_IDS:
		_expect(displayed.has(state_id), "Review displays state: %s" % state_id)
	var metadata_count := 0
	var catalog_keys := _packed_string_array(_source(CATALOG_PATH), "stable_asset_keys")
	for node in _all_descendants(review):
		if not node.has_meta("asset_key"):
			continue
		metadata_count += 1
		var asset_key := str(node.get_meta("asset_key"))
		_expect(
			catalog_keys.has(asset_key)
				and not asset_key.contains("/")
				and not asset_key.contains("\\")
				and not asset_key.contains("third_party"),
			"visual node uses registered stable key: %s" % asset_key
		)
	_expect(metadata_count == 25, "every review tile has one stable asset key")
	for node in _all_descendants(review):
		if node is Label:
			var visible_text := (node as Label).text.to_lower()
			_expect(
				not visible_text.contains("bid") and not visible_text.contains("auction"),
				"Review renders no bidding or auction surface"
			)
	var scroll := review.get_node_or_null("SafeMargin/Rows/ReviewScroll") as ScrollContainer
	var sections := review.get_node_or_null(
		"SafeMargin/Rows/ReviewScroll/Sections"
	) as Control
	var layout_ready := (
		review.size.x >= viewport_size.x - 1.0
		and review.size.y >= viewport_size.y - 1.0
		and scroll != null and scroll.size.x > 0.0 and scroll.size.y > 0.0
		and sections != null and sections.size.x > 0.0
		and sections.get_combined_minimum_size().y > 0.0
		and sections.size.x <= scroll.size.x + 2.0
	)
	_expect(
		layout_ready,
		"Review keeps a non-overlapping scroll layout at %dx%d" % [
			viewport_size.x,
			viewport_size.y,
		]
	)
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


func _packed_string_array(source: String, assignment: String) -> Array[String]:
	var prefix := "%s = PackedStringArray(" % assignment
	var start := source.find(prefix)
	if start < 0:
		return []
	start += prefix.length()
	var finish := source.find(")", start)
	if finish < start:
		return []
	var parsed: Variant = JSON.parse_string("[%s]" % source.substr(start, finish - start))
	var result: Array[String] = []
	if parsed is Array:
		for value in parsed as Array:
			result.append(str(value))
	return result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("V073_FIXED_ORDER_CONTENTION_REVIEW_TEST: %s" % message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V073_FIXED_ORDER_CONTENTION_REVIEW_TEST|status=%s|checks=%d|failures=%d" % [
		status,
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		print("V073_FIXED_ORDER_CONTENTION_REVIEW_TEST|first_failure=%s" % _failures[0])
	quit(_failures.size())
