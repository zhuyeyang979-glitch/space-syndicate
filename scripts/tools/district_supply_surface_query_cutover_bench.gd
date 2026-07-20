extends Node

const SESSION_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const QA_SAVE_PATH := "user://test_runs/district_supply_surface_query_cutover_bench.save"
const HUMAN_CASH_SENTINEL := 4317
const RIVAL_CASH_SENTINEL := 987654321
const RIVAL_HAND_SENTINEL := "DISTRICT_SUPPLY_BENCH_RIVAL_HAND"
const RIVAL_OWNER_SENTINEL := "DISTRICT_SUPPLY_BENCH_RIVAL_OWNER"

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	get_tree().root.size = Vector2i(1600, 960)
	var start: Dictionary = await SESSION_DRIVER.start_configured_session(
		get_tree(),
		{
			"player_count": 3,
			"ai_player_count": 2,
			"challenge_depth": 1,
			"role_indices": [0, 1, 2],
			"starter_monster_indices": [0, 1, 2],
		},
		QA_SAVE_PATH,
		"district-supply-surface-query-cutover-bench"
	)
	var app_root := start.get("main_root") as Node
	var coordinator := start.get("coordinator") as GameRuntimeCoordinator
	_check(
		bool(start.get("started", false)) and app_root != null and coordinator != null,
		"production_session_started"
	)
	if app_root == null or coordinator == null or not bool(start.get("started", false)):
		_cleanup_and_finish(app_root)
		return
	coordinator.pause_session()
	await _wait_frames(2)

	var query := coordinator.get_node_or_null("DistrictSupplyViewerQueryPort") as DistrictSupplyViewerQueryPort
	var presentation := coordinator.card_supply_presentation_state()
	var query_ports := coordinator.get_node_or_null("TablePresentationQueryPorts") as TablePresentationQueryPorts
	var region_supply := coordinator.get_node_or_null("RegionSupplyRuntimeController") as RegionSupplyRuntimeController
	var pricing := coordinator.get_node_or_null("CardMarketPricingRuntimeController") as CardMarketPricingRuntimeController
	var inventory := coordinator.get_node_or_null("CardInventoryRuntimeService") as CardInventoryRuntimeService
	var screen := app_root.find_child("RuntimeGameScreen", true, false) as SpaceSyndicateGameScreen
	var overlay := screen.get_node_or_null("OverlayLayer") as SpaceSyndicateOverlayLayer if screen != null else null
	_check(query != null and presentation != null and query_ports != null, "scene_owned_query_composed")
	_check(region_supply != null and pricing != null and inventory != null, "authoritative_owners_composed")
	_check(screen != null and overlay != null, "typed_overlay_target_composed")
	if query == null or presentation == null or query_ports == null \
		or region_supply == null or pricing == null or inventory == null \
		or screen == null or overlay == null:
		_cleanup_and_finish(app_root)
		return

	var world := coordinator.world_session_state()
	var district_index := _first_rack_district(world, region_supply)
	_check(world != null and world.players.size() == 3, "three_seat_runtime_world_ready")
	_check(district_index >= 0, "authoritative_public_rack_ready")
	if world == null or district_index < 0:
		_cleanup_and_finish(app_root)
		return

	var human := (world.players[0] as Dictionary).duplicate(true)
	human["cash"] = HUMAN_CASH_SENTINEL
	world.players[0] = human
	presentation.open_district = district_index
	presentation.open_player = 0
	var district: Dictionary = world.districts[district_index] if world.districts[district_index] is Dictionary else {}
	var rack := region_supply.public_rack_snapshot(str(district.get("region_id", "")))
	var rack_rows: Array = rack.get("regions", []) if rack.get("regions", []) is Array else []
	var rack_revision := str((rack_rows[0] as Dictionary).get("rack_revision", "")) \
		if not rack_rows.is_empty() and rack_rows[0] is Dictionary else ""
	coordinator.open_district_purchase_window(0, district_index, {"supply_revision": rack_revision})

	var context := query_ports.viewer_context()
	var supply_before := region_supply.to_save_data()
	var pricing_before := pricing.debug_snapshot()
	var inventory_before := inventory.debug_snapshot()
	var presentation_before := presentation.snapshot()
	var private_surface := query.snapshot_for_viewer(0)
	_check(supply_before == region_supply.to_save_data(), "query_preserves_supply_and_rng_state")
	_check(pricing_before == pricing.debug_snapshot(), "query_does_not_create_quote")
	_check(inventory_before == inventory.debug_snapshot(), "query_does_not_mutate_inventory")
	_check(presentation_before == presentation.snapshot(), "query_does_not_mutate_presentation_selection")
	_check(
		bool(private_surface.get("visible", false))
			and str(private_surface.get("visibility_scope", "")) == "viewer_private",
		"local_viewer_receives_private_surface"
	)
	_check(
		int(private_surface.get("viewer_index", -1)) == 0
			and int(private_surface.get("authorization_revision", 0)) == context.authorization_revision,
		"private_surface_binds_viewer_authorization"
	)
	var private_text := JSON.stringify(private_surface)
	_check(private_text.contains("%d" % HUMAN_CASH_SENTINEL), "private_surface_contains_local_cash")
	_check(
		not private_text.contains("quote_fingerprint")
			and not private_text.contains("quote_id")
			and not private_text.contains("supply_revision"),
		"private_surface_strips_quote_and_supply_credentials"
	)
	_check(
		overlay.apply_district_supply_presentation(private_surface, 0, context.authorization_revision),
		"typed_overlay_accepts_private_surface"
	)
	var private_target := overlay.district_supply_presentation_target_snapshot()
	_check(
		bool(private_target.get("visible", false))
			and str(private_target.get("last_visibility_scope", "")) == "viewer_private",
		"typed_overlay_renders_private_scope"
	)

	var rival := (world.players[1] as Dictionary).duplicate(true)
	rival["cash"] = RIVAL_CASH_SENTINEL
	rival["cash_cents"] = RIVAL_CASH_SENTINEL * 100
	rival["slots"] = [{"name": RIVAL_HAND_SENTINEL, "kind": "private_test"}]
	rival["true_owner"] = RIVAL_OWNER_SENTINEL
	world.players[1] = rival
	presentation.open_player = 1
	var public_surface := query.snapshot_for_viewer(0)
	var public_snapshot: Dictionary = public_surface.get("snapshot", {}) \
		if public_surface.get("snapshot", {}) is Dictionary else {}
	var public_text := JSON.stringify(public_surface)
	_check(
		str(public_surface.get("visibility_scope", "")) == "public"
			and str(public_snapshot.get("visibility_scope", "")) == "public",
		"rival_surface_is_public_browse_scope"
	)
	_check(
		not public_text.contains(str(RIVAL_CASH_SENTINEL))
			and not public_text.contains(RIVAL_HAND_SENTINEL)
			and not public_text.contains(RIVAL_OWNER_SENTINEL),
		"public_surface_redacts_rival_private_state"
	)
	_check(_cards_are_browse_only(public_snapshot), "public_cards_are_non_actionable")
	_check(
		overlay.apply_district_supply_presentation(public_surface, 0, context.authorization_revision),
		"typed_overlay_accepts_public_surface"
	)
	var public_target := overlay.district_supply_presentation_target_snapshot()
	_check(
		bool(public_target.get("visible", false))
			and str(public_target.get("last_visibility_scope", "")) == "public",
		"typed_overlay_renders_public_scope"
	)

	var query_debug := query.debug_snapshot()
	_check(
		int(query_debug.get("private_snapshot_count", 0)) == 1
			and int(query_debug.get("public_snapshot_count", 0)) == 1,
		"query_records_one_private_and_one_public_projection"
	)
	_check(
		not bool(query_debug.get("references_main", true))
			and not bool(query_debug.get("mutates_gameplay", true))
			and not bool(query_debug.get("opens_market_quote", true))
			and not bool(query_debug.get("reads_future_supply_bag", true)),
		"query_declares_read_only_non_main_boundary"
	)
	_cleanup_and_finish(app_root)


func _first_rack_district(world: WorldSessionState, region_supply: RegionSupplyRuntimeController) -> int:
	if world == null:
		return -1
	for district_index in range(world.districts.size()):
		var district: Dictionary = world.districts[district_index] if world.districts[district_index] is Dictionary else {}
		var rack := region_supply.public_rack_snapshot(str(district.get("region_id", "")))
		var rows: Array = rack.get("regions", []) if rack.get("regions", []) is Array else []
		if not rows.is_empty() and rows[0] is Dictionary:
			var slots: Array = (rows[0] as Dictionary).get("slots", []) \
				if (rows[0] as Dictionary).get("slots", []) is Array else []
			if not slots.is_empty():
				return district_index
	return -1


func _cards_are_browse_only(snapshot: Dictionary) -> bool:
	var cards: Array = snapshot.get("cards", []) if snapshot.get("cards", []) is Array else []
	if cards.is_empty():
		return false
	for card_variant in cards:
		if not (card_variant is Dictionary):
			return false
		var card := card_variant as Dictionary
		var preview: Dictionary = card.get("preview", {}) if card.get("preview", {}) is Dictionary else {}
		if bool(card.get("actionable", true)) \
			or str(card.get("state_text", "")) != "仅浏览" \
			or bool(preview.get("buy_enabled", true)):
			return false
	return true


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _stop_audio(root_node: Node) -> void:
	if root_node == null:
		return
	for node in root_node.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("DISTRICT_SUPPLY_SURFACE_QUERY_CUTOVER_BENCH_FAIL|%s" % label)


func _cleanup_and_finish(app_root: Node) -> void:
	_stop_audio(app_root)
	if app_root != null:
		app_root.queue_free()
	await _wait_frames(2)
	if _failures.is_empty():
		print("DISTRICT_SUPPLY_SURFACE_QUERY_CUTOVER_BENCH|status=PASS|checks=%d|failures=0" % _checks)
		# Keep the production Bench alive briefly so Godot MCP can inspect and stop it.
		await get_tree().create_timer(5.0).timeout
		get_tree().quit(0)
		return
	print("DISTRICT_SUPPLY_SURFACE_QUERY_CUTOVER_BENCH|status=FAIL|checks=%d|failures=%d|details=%s" % [
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	await get_tree().create_timer(5.0).timeout
	get_tree().quit(1)
